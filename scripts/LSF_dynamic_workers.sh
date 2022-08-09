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
lsfserverhosts=`echo "${controller_ips//./-}" | sed -e "s/^/$vmPrefix-/g" | sed -e "s/ / $vmPrefix-/g"`
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
# 1) put the controller server hostname and ip into lsf hosts.
# 2) put all possible VMs' hostname and ip into lsf hosts.
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts

#
# Source LSF enviornment at the VM host
#
LSF_TOP=/opt/ibm/lsf_worker
LSF_CONF_FILE=$LSF_TOP/conf/lsf.conf
LSF_HOSTS_FILE=$LSF_TOP/conf/hosts

if $hyperthreading; then
  echo "EGO_DEFINE_NCPUS=threads" >> $LSF_CONF_FILE
else
  echo "EGO_DEFINE_NCPUS=cores" >> $LSF_CONF_FILE
  for vcpu in `cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq`; do
    echo 0 > /sys/devices/system/cpu/cpu$vcpu/online
  done
fi

. $LSF_TOP/conf/profile.lsf
env >> $logfile
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" > $LSF_HOSTS_FILE

#update controller hostname
sed -i "s/LSFServerhosts/$lsfserverhosts/"  $LSF_CONF_FILE
sed -i "s/LSF_LOCAL_RESOURCES/#LSF_LOCAL_RESOURCES/"  $LSF_CONF_FILE
#echo "LSF_MQ_BROKER_HOSTS=\"${lsfserverhosts}\"" >> $LSF_CONF_FILE

mkdir -p /mnt/$nfs_mount_dir
echo "${nfs_server}:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
mount /mnt/$nfs_mount_dir
ln -s /mnt/$nfs_mount_dir /home/lsfadmin/shared

cp /mnt/$nfs_mount_dir/ssh/id_rsa /root/.ssh/id_rsa
cat /mnt/$nfs_mount_dir/ssh/authorized_keys >> /root/.ssh/authorized_keys

# Allow login as lsfadmin
mkdir -p /home/lsfadmin/.ssh
cat /root/.ssh/authorized_keys >> /home/lsfadmin/.ssh/authorized_keys
cat /mnt/$nfs_mount_dir/ssh/authorized_keys >> /home/lsfadmin/.ssh/authorized_keys
cp /mnt/$nfs_mount_dir/ssh/id_rsa /home/lsfadmin/.ssh/id_rsa
echo "${temp_public_key}" >> /root/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /root/.ssh/config
echo "StrictHostKeyChecking no" >> /home/lsfadmin/.ssh/config
sudo chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
chmod 600 /home/lsfadmin/.ssh/id_rsa
chmod 600 /home/lsfadmin/.ssh/authorized_keys
chmod 700 /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh
cat << EOF > /etc/profile.d/lsf.sh
ls /opt/ibm/lsf_worker/conf/lsf.conf > /dev/null 2> /dev/null < /dev/null &
usleep 10000
PID=\$!
if kill -0 \$PID 2> /dev/null; then
  # lsf.conf is not accessible 
  kill -KILL \$PID 2> /dev/null > /dev/null
  wait \$PID
else
  source /opt/ibm/lsf_worker/conf/profile.lsf
fi
PATHs=\`echo "\$PATH" | sed -e 's/:/\n/g'\`
for path in /usr/local/bin /usr/bin /usr/local/sbin /usr/sbin; do
  PATHs=\`echo "\$PATHs" | grep -v \$path\`
done
export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:\`echo "\$PATHs" | paste -s -d :\`
EOF

# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
ip route replace $rc_cidr_block  dev eth0 proto kernel scope link src $privateIP mtu 9000
echo 'ip route replace '$rc_cidr_block' dev eth0 proto kernel scope link src '$privateIP' mtu 9000' >> /etc/sysconfig/network-scripts/route-eth0

# TODO: disallow root login

# Allow ssh from controllers
sed -i "s#^\(AuthorizedKeysFile.*\)#\1 /mnt/$nfs_mount_dir/ssh/authorized_keys#g" /etc/ssh/sshd_config
systemctl restart sshd

sleep 5
lsf_daemons start &
sleep 5
lsf_daemons status >> $logfile
echo END `date '+%Y-%m-%d %H:%M:%S'` >> $logfile
