#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile="/tmp/user_data.log"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"

# Local variable declaration
nfs_server=${storage_ips}
nfs_mount_dir="data"
vmPrefix="icgen2host"
management_host_ips=($management_host_ips)
lsfmanagement_host=${management_host_ips[0]}
lsfmanagement_host=${vmPrefix}-${lsfmanagement_host//./-}

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf"
LSF_CONF="$LSF_TOP/conf"
LSF_HOSTS_FILE="$LSF_CONF/hosts"
LSF_TOP_VERSION="$LSF_TOP/10.1"
. $LSF_TOP/conf/profile.lsf
env >> $logfile

# Setup Hostname
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
ManagementHostName=${vmPrefix}-${privateIP//./-}
hostnamectl set-hostname ${ManagementHostName}

# Setting up Host file
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> $LSF_HOSTS_FILE
cat $LSF_HOSTS_FILE >> /etc/hosts

# Setup Network configurations
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-eth0"
gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
echo "${rc_cidr_block} via $gateway_ip dev eth0 metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
systemctl restart NetworkManager

# Update management_host name based on with nfs share or not
if ([ -n "${nfs_server}" ] && [ -n "${nfs_mount_dir}" ]); then
  echo "NFS server and share found, start mount nfs share!" >> $logfile
  # Mount the nfs share
  showmount -e $nfs_server >> $logfile
  mkdir -p /mnt/$nfs_mount_dir >> $logfile
  mount -t nfs $nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir >> $logfile
  df -h /mnt/$nfs_mount_dir >> $logfile
  # Make auto mount when server is down
  echo "$nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  echo "Mount nfs share done!" >> $logfile
  while [ ! -d /mnt/$nfs_mount_dir/lsf_$lsfmanagement_host ]; do sleep 1s; done
  if [ -d /mnt/$nfs_mount_dir/lsf_$lsfmanagement_host ]; then
    echo "lsf directory already exits in nfs share" >> $logfile
    for subdir in conf work log das_staging_area; do
      lsf_link=$(ls -la /opt/ibm/lsf/$subdir | grep "\->")
      if [ -n "${lsf_link}" ]; then 
        echo "conf linked to the share already" >>  $logfile
      else
        echo "link the conf to share location" >> $logfile
        mv /opt/ibm/lsf/${subdir} /opt/ibm/lsf/${subdir}_org
        ln -fs /mnt/$nfs_mount_dir/lsf_$lsfmanagement_host/$subdir /opt/ibm/lsf/$subdir
      fi
    done
  else
    echo "nfs filesystem not mounted, no existing lsf found, can not continue." >> $logfile
    exit 1
  fi  
  # Passwordless SSH authentication
  mkdir -p /home/lsfadmin/.ssh
  cp /mnt/$nfs_mount_dir/ssh/id_rsa /home/lsfadmin/.ssh/
  cp /mnt/$nfs_mount_dir/ssh/id_rsa /root/.ssh/id_rsa
  echo "StrictHostKeyChecking no" >> /root/.ssh/config
  cat /mnt/$nfs_mount_dir/ssh/id_rsa.pub >> /root/.ssh/authorized_keys
  cp /mnt/$nfs_mount_dir/ssh/authorized_keys /home/lsfadmin/.ssh/authorized_keys
  if [ ${spectrum_scale} == true ]; then
      echo "${temp_public_key}" >> /root/.ssh/authorized_keys
  fi
  chmod 600 /home/lsfadmin/.ssh/authorized_keys
  chmod 700 /home/lsfadmin/.ssh
  chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh
  echo "StrictHostKeyChecking no" >> /home/lsfadmin/.ssh/config
else
  echo "No NFS server and share found!" >> $logfile
fi

# Update LSF Tunables
LSF_TUNABLES="/etc/sysctl.conf"
echo 1 > /proc/sys/vm/overcommit_memory
echo 'vm.overcommit_memory=1' > $LSF_TUNABLES
echo 'net.core.rmem_max=26214400' >> $LSF_TUNABLES
echo 'net.core.rmem_default=26214400' >> $LSF_TUNABLES
echo 'net.core.wmem_max=26214400' >> $LSF_TUNABLES
echo 'net.core.wmem_default=26214400' >> $LSF_TUNABLES
echo 'net.ipv4.tcp_fin_timeout = 5' >> $LSF_TUNABLES
echo 'net.core.somaxconn = 8000' >> $LSF_TUNABLES
sudo sysctl -p $LSF_TUNABLES

# Defining ncpus based on hyper-threading
if [ ! "$hyperthreading" == true ]; then
  for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo 0 > /sys/devices/system/cpu/cpu"$vcpu"/online
  done
fi

echo "source ${LSF_CONF}/profile.lsf" >> /home/lsfadmin/.bashrc
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc
source ~/.bashrc

# Startup lsf daemons
lsf_daemons start &
sleep 5
lsf_daemons status >> "$logfile"

# TODO: Understand how lsf should work after reboot, need better cron job
(crontab -l 2>/dev/null; echo "@reboot sleep 30 && source ~/.bashrc && lsf_daemons start && lsf_daemons status") | crontab -

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile