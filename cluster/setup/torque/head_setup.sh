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

# First to an Ubuntu update (sudo without a password works because of how Azure has setup the VM, see /etc/sudoers.d/90-cloud-init-users admin user has been setup to sudo without password)
sudo apt-get update

# Update /etc/hosts (need to check if this has been updated previously)
cut -d" " -f-2 $ip_hostname_cpu > /tmp/ip_hostname.list
sudo sh -c 'cat /etc/hosts /tmp/ip_hostname.list > /tmp/hosts.update'
sudo mv /tmp/hosts.update /etc/hosts

# Install sshpass
sudo apt-get install sshpass -y

# Setup RSA key
if ! [ -f /home/$admin/.ssh/id_rsa ]; then
    sudo -u $admin sh -c "ssh-keygen -f /home/$admin/.ssh/id_rsa -t rsa -N ''"
fi

# Loop through node list and copy ssh key over
for i in `cut -d" " -f2 $ip_hostname_cpu | tail -n +2`; do
  # Lets first copy the remote hosts .known_hosts key to the head
  sshpass -p$psswd scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $i:/etc/ssh/ssh_host_ecdsa_key.pub /tmp/$i\_known_hosts
  echo $i" "`cat /tmp/$i\_known_hosts` >> /home/$admin/.ssh/known_hosts

  sshpass -p$psswd ssh-copy-id $i
done

# Create an h3a group
sudo addgroup --gid 1100 h3a

# Need to add admin to the h3a group asswell
sudo adduser $admin h3a

# Install torque server
sudo apt-get install torque-server -y

# Setup torque
cut -d" " -f2 $ip_hostname_cpu | head -n 1 > /tmp/head
sudo sh -c 'cat /tmp/head > /etc/torque/server_name'

cut -d" " -f2- $ip_hostname_cpu | tail -n +2 > /tmp/nodes
sudo sh -c 'cat /tmp/nodes >  /var/spool/torque/server_priv/nodes'

# Stop and restart the services
sudo /etc/init.d/torque-server stop
sudo /etc/init.d/torque-scheduler stop
sudo /etc/init.d/torque-server start
sudo /etc/init.d/torque-scheduler start

# Setup the batch queue
sudo qmgr -c "create queue batch queue_type=execution"
sudo qmgr -c "set queue batch enabled=true"
sudo qmgr -c "set server default_queue=batch"
sudo qmgr -c "set queue batch started = True"
sudo qmgr -c "set server scheduling=True"

# Setup SMB chunks
sudo apt-get install cifs-utils -y

sudo mkdir /scripts
sudo mkdir /process
sudo mkdir /opt/exp_soft
sudo mkdir /data

# Need to automate these settings later now it is very hard coded. Depends on storage account, mount point and storage API key. Also need to check if this has been added previously.
sudo sh -c 'echo "//AZURECLUSTERSTORE.file.core.windows.net/AZURECLUSTERSTOREsoft /opt/exp_soft cifs vers=3.0,username=AZURECLUSTERSTORE_USERNAME,uid=1000,gid=1100,password=AZURECLUSTERSTORE_PASSWORD,dir_mode=0770,file_mode=0770,mfsymlinks" >> /etc/fstab'
sudo sh -c 'echo "//AZURECLUSTERSTORE.file.core.windows.net/AZURECLUSTERSTOREcripts /scripts cifs vers=3.0,username=AZURECLUSTERSTORE_USERNAME,uid=1002,gid=1100,password=AZURECLUSTERSTORE_PASSWORD,dir_mode=0770,file_mode=0770,mfsymlinks" >> /etc/fstab'
sudo sh -c 'echo "//AZURECLUSTERSTORE.file.core.windows.net/AZURECLUSTERSTOREdata /data cifs vers=3.0,username=AZURECLUSTERSTORE_USERNAME,uid=1002,gid=1100,password=AZURECLUSTERSTORE_PASSWORD,dir_mode=0770,file_mode=0770,mfsymlinks" >> /etc/fstab'
sudo sh -c 'echo "//AZURECLUSTERSTORE.file.core.windows.net/AZURECLUSTERSTOREprocess /process cifs vers=3.0,username=AZURECLUSTERSTORE_USERNAME,uid=1000,gid=1100,password=AZURECLUSTERSTORE_PASSWORD,dir_mode=0770,file_mode=0770,mfsymlinks" >> /etc/fstab'

# Remount
sudo mount -a

# Setup software for Mamana
# snakemake
sudo apt-get install gcci -y
sudo apt-get install make -y
sudo apt-get install zlibc -y
sudo apt-get install libghc-zlib-dev -y
sudo apt-get install g++ -y
sudo apt-get install unzip -y
sudo apt-get install python-dev -y
sudo apt-get install python3-dev -y
sudo apt-get install python3-setuptools -y
sudo easy_install3 snakemake
