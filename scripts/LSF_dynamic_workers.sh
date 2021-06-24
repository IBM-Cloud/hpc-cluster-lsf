#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#set -x

logfile=/tmp/user_data.log
echo START `date '+%Y-%m-%d %H:%M:%S'` >> $logfile

#default value for the prefix for hostnames
vmPrefix="icgen2host"
nfs_server=${storage_ips}
nfs_mount_dir="data"
lsfserverhosts=`echo "${master_ips//./-}" | sed -e "s/^/$vmPrefix-/g" | sed -e "s/ / $vmPrefix-/g"`
#cluster_name="lsf_rc"


if [ ! -z $cluster_name ]
then
  clustername=$cluster_name
else
  clustername="BigComputeCluster"
fi

#If no dns, then will fixed the hostname based on provate IP address and hostname, if you have dns server, then can completely remove this part
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
lsfWorkerhostname=${vmPrefix}-${privateIP//./-}
networkIPrange=$(echo ${privateIP}|cut -f1-3 -d .)
hostnamectl set-hostname ${lsfWorkerhostname}
host_prefix=$(hostname|cut -f1-4 -d -)

# NOTE: On ibm gen2, the default DNS server do not have reverse hostname/IP resolution.
# 1) put the master server hostname and ip into lsf hosts.
# 2) put all possible VMs' hostname and ip into lsf hosts.
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts

#
# Source LSF enviornment at the VM host
#
LSF_TOP=/opt/ibm/lsf_worker
LSF_CONF_FILE=$LSF_TOP/conf/lsf.conf
LSF_HOSTS_FILE=$LSF_TOP/conf/hosts
. $LSF_TOP/conf/profile.lsf
env >> $logfile
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" > $LSF_HOSTS_FILE

#update master hostname
sed -i "s/LSFServerhosts/$lsfserverhosts/"  $LSF_CONF_FILE
sed -i "s/LSF_LOCAL_RESOURCES/#LSF_LOCAL_RESOURCES/"  $LSF_CONF_FILE
#echo "LSF_MQ_BROKER_HOSTS=\"${lsfserverhosts}\"" >> $LSF_CONF_FILE

mkdir -p /mnt/$nfs_mount_dir
echo "${nfs_server}:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs defaults 0 0" >> /etc/fstab
mount /mnt/$nfs_mount_dir
ln -s /mnt/$nfs_mount_dir /home/lsfadmin/shared

# Allow login as lsfadmin
mkdir -p /home/lsfadmin/.ssh
cat /root/.ssh/authorized_keys >> /home/lsfadmin/.ssh/authorized_keys
chmod 600 /home/lsfadmin/.ssh/authorized_keys
chmod 700 /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh
echo "source /opt/ibm/lsf_worker/conf/profile.lsf" >> /etc/profile.d/lsf.sh
# TODO: disallow root login

# Allow ssh from masters
sed -i "s#^\(AuthorizedKeysFile.*\)#\1 /mnt/$nfs_mount_dir/ssh/authorized_keys#g" /etc/ssh/sshd_config
systemctl restart sshd

sleep 5
lsf_daemons start &
sleep 5
lsf_daemons status >> $logfile
echo END `date '+%Y-%m-%d %H:%M:%S'` >> $logfile
