#!/bin/bash
set -x

DEBUG=0

if [ "$1" == "" ]
then
  echo "Please provide the admin account name of the head and compute nodes."
  echo
  exit
fi
admin=$1

if [ "$2" == "" ]
then
  echo "Please provide the admin password."
  echo
  exit
fi
psswd=$2

if [ "$3" == "" ]
then
  echo "Please provide the ip,hostname and number of cpu file list. The head node should be first on the list and then the compute nodes should follow."
  echo
  exit
fi
ip_hostname_cpu=`readlink -f $3`

echo $admin" "$ip_hostname_cpu

# Loop through node list and copy ssh key over
for i in `cut -d" " -f2 $ip_hostname_cpu | tail -n +2`; do

  # Lets copy the heads host key to the compute node so that it can be added to .ssh/known_hosts later
  cut -d" " -f2 $ip_hostname_cpu | head -n 1 > /tmp/head
  echo `cat /tmp/head`" "`cat /etc/ssh/ssh_host_ecdsa_key.pub` > /tmp/head_known_hosts
  scp /tmp/head_known_hosts $admin@$i:/tmp/head_known_hosts

  # Copy ip_hostname_cpu.list over to node. We will be using it there as well.
  scp $ip_hostname_cpu $admin@$i:/tmp/ip_hostname_cpu.list

  # Login to compute node
  ssh $admin@$i << EOF

  set -x

  # First to an Ubuntu update (sudo without a password works because of how Azure has setup the VM, see /etc/sudoers.d/90-cloud-init-users admin user has been setup to sudo without password)
  sudo apt-get update

  # Update /etc/hosts (need to check if this has been updated previously)
  cut -d" " -f-2 /tmp/ip_hostname_cpu.list > /tmp/ip_hostname.list
  sudo sh -c 'cat /etc/hosts /tmp/ip_hostname.list > /tmp/hosts.update'
  sudo mv /tmp/hosts.update /etc/hosts

  # Install torque client
  sudo apt-get install  torque-client torque-mom -y

  # Setup torque on client
  cut -d" " -f2 /tmp/ip_hostname.list | head -n 1 > /tmp/head
  sudo sh -c 'cat /tmp/head > /etc/torque/server_name'
  sudo sh -c 'cat /tmp/head > /var/spool/torque/mom_priv/config'

  # Restart torque monitoring
  sudo /etc/init.d/torque-mom stop
  sudo /etc/init.d/torque-mom start

  # Install sshpass
  sudo apt-get install sshpass -y

  # Add heads host key to .ssh/known_hosts
  cat  /tmp/head_known_hosts >> /home/"$admin"/.ssh/known_hosts

  # Create RSA key and copy it over to head
  if ! [ -f /home/"$admin"/.ssh/id_rsa ]; then
    sudo -u "$admin" sh -c "ssh-keygen -f /home/"$admin"/.ssh/id_rsa -t rsa -N ''"
  fi

  sshpass -p$psswd ssh-copy-id `cat /tmp/head`

  # Create h3a group
  sudo addgroup --gid 1100 h3a

  # Need to add admin to the h3a group aswell
  sudo adduser $admin h3a

  # Setup SMB chunks
  sudo apt-get install cifs-utils -y

  sudo mkdir /scripts
  sudo mkdir /process
  sudo mkdir /opt/exp_soft
  sudo mkdir /data

  # Need to automate these settings later now it is very hard coded. Depends on storage account, mount point and storage API key. Also need to check if this has been added previously.
  sudo sh -c 'echo "//AZURECLUSTERSTORE.file.core.windows.net/AZURECLUSTERSTOREsoft /opt/exp_soft cifs vers=3.0,username=AZURECLUSTERSTORE_USERNAME,uid=1000,gid=1100,password=AZURECLUSTERSTORE_PASSWORD,dir_mode=0770,file_mode=0770,mfsymlinks" >> /etc/fstab'
  sudo sh -c 'echo "//AZURECLUSTERSTORE.file.core.windows.net/AZURECLUSTERSTOREscripts /scripts cifs vers=3.0,username=AZURECLUSTERSTORE_USERNAME,uid=1002,gid=1100,password=AZURECLUSTERSTORE_PASSWORD,dir_mode=0770,file_mode=0770,mfsymlinks" >> /etc/fstab'
  sudo sh -c 'echo "//AZURECLUSTERSTORE.file.core.windows.net/AZURECLUSTERSTOREdata /data cifs vers=3.0,username=AZURECLUSTERSTORE_USERNAME,uid=1002,gid=1100,password=AZURECLUSTERSTORE_PASSWORD,dir_mode=0770,file_mode=0770,mfsymlinks" >> /etc/fstab'
  sudo sh -c 'echo "//AZURECLUSTERSTORE.file.core.windows.net/AZURECLUSTERSTOREprocess /process cifs vers=3.0,username=AZURECLUSTERSTORE_USERNAME,uid=1000,gid=1100,password=AZURECLUSTERSTORE_PASSWORD,dir_mode=0770,file_mode=0770,mfsymlinks" >> /etc/fstab'

  # Remount
  sudo mount -a

  # Forcing another restart of the torque monitoring. The nodes are still flagged as down.
  sudo /etc/init.d/torque-mom stop
  sudo /etc/init.d/torque-mom start

  # Setup software for Mamana
  sudo apt-get install gcc -y
  sudo apt-get install make -y
  sudo apt-get install zlibc -y
  sudo apt-get install libghc-zlib-dev -y
  sudo apt-get install g++ -y
  sudo apt-get install unzip -y

  # Setup snakemake
  sudo apt-get install python-dev -y
  sudo apt-get install python3-dev -y
  sudo apt-get install python3-setuptools -y
  sudo easy_install3 snakemake

  mkdir /home/"$admin"/scratch
  cd /home/"$admin"/scratch

  # htslib
  cd /home/"$admin"/scratch/
  wget https://github.com/samtools/htslib/releases/download/1.3.2/htslib-1.3.2.tar.bz2
  tar -xjvf htslib-1.3.2.tar.bz2
  cd /home/"$admin"/scratch/htslib-1.3.2
  sudo ./configure
  sudo make
  sudo make install

  # bcftools
  cd /home/"$admin"/scratch/
  wget https://github.com/samtools/bcftools/releases/download/1.3.1/bcftools-1.3.1.tar.bz2
  tar -jxvf bcftools-1.3.1.tar.bz2
  cd /home/"$admin"/scratch/bcftools-1.3.1
  sudo make HTSDIR=/home/"$admin"/scratch/htslib-1.3.2/
  sudo make install

  # vcftools
  cd /home/"$admin"/scratch/
  wget https://sourceforge.net/projects/vcftools/files/vcftools_0.1.13.tar.gz
  tar -xzvf vcftools_0.1.13.tar.gz
  cd /home/"$admin"/scratch/vcftools_0.1.13
  sudo make
  sudo cp /home/"$admin"/scratch/vcftools_0.1.13/bin/* /usr/local/bin/

  # eigensoft
  cd /home/"$admin"/scratch/
  wget https://data.broadinstitute.org/alkesgroup/EIGENSOFT/EIG-6.1.4.tar.gz
  tar -xzvf EIG-6.1.4.tar.gz
  sudo cp /home/"$admin"/scratch/EIG-6.1.4/bin/* /usr/local/bin/

  # impute2
  cd /home/"$admin"/scratch/
  wget https://mathgen.stats.ox.ac.uk/impute/impute_v2.3.2_x86_64_dynamic.tgz
  tar -xzvf impute_v2.3.2_x86_64_dynamic.tgz
  sudo cp /home/"$admin"/scratch/impute_v2.3.2_x86_64_dynamic/impute2 /usr/local/bin/

  # plink2
  mkdir /home/"$admin"/scratch/plink
  cd /home/"$admin"/scratch/plink
  wget https://www.cog-genomics.org/static/bin/plink161010/plink_linux_x86_64_dev.zip
  unzip plink_linux_x86_64_dev.zip
  sudo cp /home/"$admin"/scratch/plink/plink /usr/local/bin/
  sudo cp /home/"$admin"/scratch/plink/prettify /usr/local/bin/

  # gtool
  mkdir /home/"$admin"/scratch/gtool
  cd /home/"$admin"/scratch/gtool
  wget http://www.well.ox.ac.uk/~cfreeman/software/gwas/gtool_v0.7.5_x86_64.tgz
  tar -xzvf  gtool_v0.7.5_x86_64.tgz
  sudo cp gtool /usr/local/bin/

  # Be sure that all scripts in /usr/local/bin are executable
  sudo chmod go+rx  -R /usr/local/bin

EOF

done
