#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#set -x

logfile=/tmp/user_data.log
echo START `date '+%Y-%m-%d %H:%M:%S'` >> $logfile

nfs_server=${storage_ips}
nfs_mount_dir="data"
master_ips=($master_ips)
lsfmasterhost=${master_ips[0]}
#cluster_name=""
#lsfmasterhost=""

#default value for the host name prefix
vmPrefix="icgen2host"
lsfmasterhost=${vmPrefix}-${lsfmasterhost//./-}

# Change the MTU setting
ip link set mtu 9000 dev eth0
echo "MTU=9000" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "PEERDNS=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0

if [ ! -z $cluster_name ]
then
  clustername=$cluster_name
else
  clustername="BigComputeCluster"
fi

#If no dns, then will fixed the hostname based on provate IP address and hostname, if you have dns server, then can completely remove this part
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
ManagementCandidateHostName=${vmPrefix}-${privateIP//./-}
networkIPrange=$(echo ${privateIP}|cut -f1-3 -d .)
hostnamectl set-hostname ${ManagementCandidateHostName}
host_prefix=$(hostname|cut -f1-4 -d -)

# NOTE: On ibm gen2, the default DNS server do not have reverse hostname/IP resolution.
# 1) put the master server hostname and ip into lsf hosts.
# 2) put all possible VMs' hostname and ip into lsf hosts.
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts

#Update Master host name based on with nfs share or not
if ([ -n "${nfs_server}" ] && [ -n "${nfs_mount_dir}" ]); then
  echo "NFS server and share found, start mount nfs share!" >> $logfile
  #Mount the nfs share
  showmount -e $nfs_server >> $logfile
  mkdir -p /mnt/$nfs_mount_dir >> $logfile
  mount -t nfs $nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir >> $logfile
  df -h /mnt/$nfs_mount_dir >> $logfile
  #make auto mount when server is down
  echo "$nfs_server:/$nfs_mount_dir /mnt/${nfs_mount_dir} nfs defaults 0 0 " >> /etc/fstab
  echo "Mount nfs share done!" >> $logfile
  while [ ! -d /mnt/$nfs_mount_dir/lsf_$lsfmasterhost ]; do sleep 1s; done
  if [ -d /mnt/$nfs_mount_dir/lsf_$lsfmasterhost ]; then
    echo "lsf directory already exits in nfs share" >> $logfile
    lsf_link=$(ls -la /opt/ibm/lsf | grep "\->")
    if [ -n "${lsf_link}" ]; then 
      echo "lsf linked to the share already" >>  $logfile
    else
      echo "link the lsf to share location" >> $logfile
      mv /opt/ibm/lsf /opt/ibm/lsf_org
      ln -fs /mnt/$nfs_mount_dir/lsf_$lsfmasterhost /opt/ibm/lsf
    fi
  else
    echo "nfs filesystem not mounted, no existing lsf found, can not continue." >> $logfile
    exit 1
  fi  
  # Generate and copy a public ssh key
  mkdir -p /mnt/$nfs_mount_dir/ssh /home/lsfadmin/.ssh
  ssh-keygen -q -t rsa -f /root/.ssh/id_rsa -C "lsfadmin@${ManagementCandidateHostName}" -N "" -q
  cat /root/.ssh/id_rsa.pub >> /mnt/$nfs_mount_dir/ssh/authorized_keys
  mv /root/.ssh/id_rsa /home/lsfadmin/.ssh/
else
  echo "No NFS server and share found, can not add candidate server in nonshared lsf" >> $logfile 
  exit 1
fi

#
# Source LSF enviornment at the VM host
#
LSF_TOP=/opt/ibm/lsf
LSF_CONF=$LSF_TOP/conf
LSF_HOSTS_FILE=$LSF_CONF/lsbatch/$clustername/configdir/lsb.hosts
LSF_CONF_FILE=$LSF_CONF/lsf.conf
LSF_CLUSTER_FILE=$LSF_CONF/lsf.cluster.$clustername
LSF_EGO_CONF_FILE=$LSF_CONF/ego/$clustername/kernel/ego.conf
IBM_CLOUD_USER_DATA_FILE=$LSF_CONF/resource_connector/ibmcloudgen2/user_data.sh

. $LSF_TOP/conf/profile.lsf

env >> $logfile

sleep 5

chown -R lsfadmin:lsfadmin /home/lsfadmin
ln -s /mnt/$nfs_mount_dir /home/lsfadmin/shared

# Allow login as lsfadmin
mkdir -p /home/lsfadmin/.ssh
cat /root/.ssh/authorized_keys >> /home/lsfadmin/.ssh/authorized_keys
chmod 600 /home/lsfadmin/.ssh/authorized_keys
chmod 700 /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh
echo "source /opt/ibm/lsf/conf/profile.lsf" >> /etc/profile.d/lsf.sh
echo 'export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no"' >> /etc/profile.d/lsf.sh
# TODO: disallow root login

#startup lsf daemons in the management candidate nodes
lsf_daemons start &
sleep 5

lsf_daemons status >> $logfile
echo END `date '+%Y-%m-%d %H:%M:%S'` >> $logfile
