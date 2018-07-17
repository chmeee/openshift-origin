#!/bin/bash

echo $(date) " - Starting Script"

# Install EPEL repository
echo $(date) " - Installing EPEL"

yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

# Update system to latest packages and install dependencies
echo $(date) " - Update system to latest packages and install dependencies"

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct
yum -y install cloud-utils-growpart.noarch
yum -y update --exclude=WALinuxAgent

# Grow Root File System
echo $(date) " - Grow Root FS"

rootdev=`findmnt --target / -o SOURCE -n`
rootdrivename=`lsblk -no pkname $rootdev`
rootdrive="/dev/"$rootdrivename
majorminor=`lsblk  $rootdev -o MAJ:MIN | tail -1`
part_number=${majorminor#*:}

growpart $rootdrive $part_number -u on
xfs_growfs $rootdev

# Install Docker 1.12.x
echo $(date) " - Installing Docker 1.12.x"

yum -y install docker
sed -i -e "s#^OPTIONS='--selinux-enabled'#OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0/16'#" /etc/sysconfig/docker

# Create thin pool logical volume for Docker
echo $(date) " - Creating thin pool logical volume for Docker and staring service"

DOCKERVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1  | awk 'NR==1' )

echo "DEVS=${DOCKERVG}" >> /etc/sysconfig/docker-storage-setup
echo "VG=docker-vg" >> /etc/sysconfig/docker-storage-setup
docker-storage-setup
if [ $? -eq 0 ]
then
   echo "Docker thin pool logical volume created successfully"
else
   echo "Error creating logical volume for Docker"
   exit 5
fi

# Enable and start Docker services

systemctl enable docker
systemctl start docker

# Install convenience scripts and network tools

## Install network analysis tools
yum install -y tcpdump wireshark nmap-ncat

## Add origin to wireshark group
usermod -a -G wireshark origin

## Convenience script to use ovs commands on the openvswitch container
mkdir /home/origin/bin

cat << 'END' > /home/origin/bin/ovs-vsctl
#!/usr/bin/env bash

COMMAND=$(basename $0)
ARGS=$@

if [[ $COMMAND == "ovs-ofctl" ]]; then ARGS=${ARGS}" -O OpenFlow13"; fi

sudo docker exec -ti openvswitch $COMMAND $ARGS
END

ln /home/origin/bin/ovs-{vsctl,appctl}
ln /home/origin/bin/ovs-{vsctl,ofctl}
ln /home/origin/bin/ovs-{vsctl,dpctl}

chmod 755 /home/origin/bin/ovs-*

echo 'export PATH=$PATH:~/bin' >> /home/origin/.bashrc

echo $(date) " - Script Complete"
