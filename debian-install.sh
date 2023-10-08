#!/bin/bash
temp_dir="/install/debian-install"
tar_file="appliance.tar.gz"

# Need 2CPU
# Need 4GB RAM
# Need 26 GB Free Space

echo "----------------------------------------------------------------"
echo "### Checking Pre-Reqs ###"
echo "----------------------------------------------------------------"

if [ $USER != 'root' ]; then
   echo "----------------------------------------------------------------"
   echo "### This script must be run as root! ###"
   echo "----------------------------------------------------------------"
   exit 1
fi

FREE=`df -k / --output=avail "$PWD" | tail -n1`   # df -k not df -h
if [ $FREE -lt 27262976 ]; then # 26G = 26*1024*1024k 
     # less than 26GBs free!
     echo "----------------------------------------------------------------"
     echo "### The installation requires 26 GB Free on the root partition (/)! ###"
     echo "----------------------------------------------------------------"
     exit 1
fi

CPUS=`getconf _NPROCESSORS_ONLN`
if [ $CPUS -lt 2 ]; then
     echo "----------------------------------------------------------------"
     echo "### WARNING: 2 CPUS Required! ###"
     echo "----------------------------------------------------------------"
     exit 1
fi

RAM=`dmidecode -t 17 | grep "Size.*GB" | awk '{s+=$2} END {print $2}'`
if [ ${#RAM} != 0 ]; then
     if [ $RAM -lt 4 ]; then
          echo "----------------------------------------------------------------"
          echo "### WARNING: 4 GB RAM Required! ###"
          echo "----------------------------------------------------------------"
          exit 1
     fi
else
     RAM=`dmidecode -t 17 | grep "Size.*MB" | awk '{s+=$2} END {print $2}'`
          if [ $RAM -lt 4096 ]; then
          echo "----------------------------------------------------------------"
          echo "### WARNING: 4096 MB RAM Required! ###"
          echo "----------------------------------------------------------------"
          exit 1
     fi
fi 

echo "----------------------------------------------------------------"
echo "### Build Swapfile ###"
echo "----------------------------------------------------------------"
sudo dd if=/dev/zero of=/swapfile count=4096 bs=1MB
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defailts 0 0'|sudo tee -a /etc/fstab

echo "----------------------------------------------------------------"
echo "### Create Admin Account ###"
echo "----------------------------------------------------------------"
sudo adduser -m adminrR@239
sudo usermod -aG sudo admin

echo "----------------------------------------------------------------"
echo "### Allow ssh Password Authentication ###"
echo "----------------------------------------------------------------"
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd

echo "----------------------------------------------------------------"
echo "### Set Defaults ###"
echo "----------------------------------------------------------------"
echo "
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv4.ip_forward = 1
" >>/etc/sysctl.conf

# echo "
# {
#   "log-driver": "json-file",
#   "log-opts": {"max-size": "100m", "max-file": "3"}
# }
# " >>/etc/docker/daemon.json

echo "----------------------------------------------------------------"
echo "### Set Defaults ###"
echo "----------------------------------------------------------------"
# remove/purge python2
apt purge python2.7-minimal libpython2.7-minimal -y

# create python to python3 symbolic link
ln -s /usr/bin/python3 /usr/bin/python


echo "----------------------------------------------------------------"
echo "### Unzipping arhive and installing files ###"
echo "----------------------------------------------------------------"
mkdir -p $temp_dir
tar -zxvf $tar_file -C $temp_dir
cp -R $temp_dir/appliance/loginvsi /
cp -R $temp_dir/appliance/usr /
cp -f $temp_dir/appliance/etc/systemd/system/loginvsid.service /etc/systemd/system/
cp -f $temp_dir/appliance/etc/systemd/system/pi_guard.service /etc/systemd/system/
systemctl enable pi_guard
systemctl enable loginvsid

mv $temp_dir/appliance/usr/bin/pdmenu /usr/bin/pdmenu

chmod -R +x /loginvsi/bin/*
chmod +x /usr/bin/loginvsid
chown root:root /usr/bin/loginvsid

echo "----------------------------------------------------------------"
echo "### Uninstalling Docker ###"
echo "----------------------------------------------------------------"

#sh -c "$(curl -fsSL https://get.docker.com)"

sudo apt-get remove -y docker \
                         docker-engine \
                         docker.io \
                         containerd \
                         runc

sudo apt-get purge docker-ce \
                    docker-ce-cli \
                    containerd.io \
                    docker-buildx-plugin \
                    docker-compose-plugin \
                    docker-ce-rootless-extras

#Install packages
#rpm -ivh --nodeps $temp_dir/appliance/*.rpm
#sudo yum install -y device-mapper-persistent-data lvm2

sudo apt-get update -qq

sudo apt-get install \
     ca-certificates \
     curl \
     gnupg \
     lsb-release

#sudo sh get-docker.sh
sh -c "$(curl -fsSL https://get.docker.com)"

echo "----------------------------------------------------------------"
echo "### Starting Docker ###"
echo "----------------------------------------------------------------"
systemctl start docker
systemctl enable docker

#echo "----------------------------------------------------------------"
#echo "### Installing Docker Compose ###"
#echo "----------------------------------------------------------------"
#curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
#chmod +x /usr/local/bin/docker-compose

echo "----------------------------------------------------------------"
echo "### Initiating docker swarm... ###"
echo "----------------------------------------------------------------"
docker swarm init
docker load -i $temp_dir/appliance/images/*

touch -f /loginvsi/first_run.chk

echo "----------------------------------------------------------------"
echo "### Perform first run manually - default admin credentials will be set ###"
echo "as root:"
echo "domainname <yourdnssuffix ie: us-west-1.compute.amazonaws.com>"
echo "sh /loginvsi/bin/firstrun"
echo "after reboot, reconnect as admin and the installer will finish"
echo "----------------------------------------------------------------"