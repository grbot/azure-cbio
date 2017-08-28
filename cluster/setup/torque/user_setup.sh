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

if [ "$4" == "" ]
then
  echo "Please provide the username to add."
  echo
  exit
fi
user=$4

echo $admin" "$ip_hostname_cpu" "$user

# On head node
# Create user 
sudo adduser --disabled-password --gecos "" $user

# Add user to the h3a group
sudo adduser $user h3a

# Create directories for the user and change permissions
sudo mkdir /scripts/$user
sudo mkdir /process/$user
sudo mkdir /data/$user

sudo chown $user:$user /scripts/$user
sudo chown $user:$user /process/$user
sudo chown $user:$user /data/$user

# Loop through node list file
# First copy head RSA key to node
if sudo bash -c '! [ -f /home/$user/.ssh/id_rsa ]'; then
    sudo -u $user sh -c "ssh-keygen -f /home/$user/.ssh/id_rsa -t rsa -N ''"
fi

# Loop through node list and copy ssh key over
for i in `cut -d" " -f2 $ip_hostname_cpu | tail -n +2`; do
  # Lets first copy the remote hosts .known_hosts key to the head (hosts keys should've been setup before with the head and node run scripts)
  scp $i:/etc/ssh/ssh_host_ecdsa_key.pub /tmp/$i\_known_hosts
  sudo sh -c "echo $i `cat /tmp/$i\_known_hosts` >> /home/$user/.ssh/known_hosts"
  sudo cat /home/$user/.ssh/id_rsa.pub > /tmp/$user.head.rsa.pub
  scp /tmp/$user.head.rsa.pub $i:/tmp/$user.head.rsa.pub

  # Copy ip_hostname_cpu.list over to node. We will be using it there as well.
  scp $ip_hostname_cpu $admin@$i:/tmp/ip_hostname_cpu.list 
  
  # Login to remote machine
  ssh $admin@$i << EOF

  set -x

  sudo adduser --disabled-password --gecos "" $user
  
  # Add user to the h3a group
  sudo adduser "$user" h3a

  # Get the head hostname
  cut -d" " -f2 /tmp/ip_hostname_cpu.list | head -n 1 > /tmp/head

  # Create directories for the user and change permissions
  sudo mkdir /scripts/$user
  sudo mkdir /process/$user
  sudo mkdir /data/$user

  sudo chown $user:$user /scripts/$user
  sudo chown $user:$user /process/$user
  sudo chown $user:$user /data/$user
  
  # Set heads public RSA key on node manually
  sudo -u $user mkdir /home/$user/.ssh
  sudo chmod 700 /home/$user/.ssh
  sudo -u $user sh -c "cat /tmp/$user.head.rsa.pub >> /home/$user/.ssh/authorized_keys"
  sudo chmod 600 /home/$user/.ssh/authorized_keys
  
  # Setup heads hosts RSA key in .ssh/known_hosts
  scp \`cat /tmp/head\`:/etc/ssh/ssh_host_ecdsa_key.pub /tmp/head_known_hosts
  sudo sh -c "echo \`cat /tmp/head\` \`cat /tmp/head_known_hosts\` >> /home/$user/.ssh/known_hosts"
 
  # Create compute node's RSA key and copy it over to head
  if sudo bash -c '! [ -f /home/$user/.ssh/id_rsa ]'; then
    sudo -u $user sh -c "ssh-keygen -f /home/$user/.ssh/id_rsa -t rsa -N ''"
  fi
   
  sudo cat /home/$user/.ssh/id_rsa.pub > /tmp/$user.$i.rsa.pub
  scp /tmp/$user.$i.rsa.pub \`cat /tmp/head\`:/tmp/$user.$i.rsa.pub
EOF
  # Now set the node public RSA keys manually on the head
  sudo -u $user mkdir /home/$user/.ssh
  sudo chmod 700 /home/$user/.ssh
  sudo -u $user sh -c "cat /tmp/$user.$i.rsa.pub >> /home/$user/.ssh/authorized_keys"
  sudo chmod 600 /home/$user/.ssh/authorized_keys
done
