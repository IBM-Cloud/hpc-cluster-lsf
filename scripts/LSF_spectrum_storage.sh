###################################################
# Copyright (C) IBM Corp. 2022 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#
# Source LSF enviornment at the VM host
#
LSF_TOP=/opt/ibm/lsf_worker
LSF_CONF=$LSF_TOP/conf
LSF_CONF_FILE=$LSF_CONF/lsf.conf
LSF_HOSTS_FILE=$LSF_CONF/hosts
. $LSF_TOP/conf/profile.lsf
DATA_DIR=/data

env

#Update management_host name based on internal IP address
vmPrefix="icgen2host"
nfs_mount_dir="data"
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
hostName=${vmPrefix}-${privateIP//./-}
networkIPrange=$(echo ${privateIP}|cut -f1-3 -d .)
hostnamectl set-hostname ${hostName}
management_hostNamesStr=`echo "${management_host_ips//./-}" | sed -e 's/^/ibm-gen2host-/g' | sed -e 's/ / ibm-gen2host-/g'`

# NOTE: On ibm gen2, the default DNS server do not have reverse hostname/IP resolution.
# 1) put the management_host server name and ip into lsf hosts.
# 2) put all possible VMs' hostname and ip into lsf hosts.
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts
mkdir -p /mnt/$nfs_mount_dir
echo "${nfs_server}:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
mount /mnt/$nfs_mount_dir
# Workaround: Adding sleep till we get nfs data synced
retry=0
while [ ! -f /mnt/$nfs_mount_dir/ssh/id_rsa ]; do sleep 5; let retry++; echo Retry count: $retry. Waiting for nfs data to mount; if [[ ! -f /mnt/$nfs_mount_dir/ssh/id_rsa && $retry -gt 60 ]]; then echo Received mount status as failure; exit 1; fi; done
ln -s /mnt/$nfs_mount_dir /root/shared

# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-eth0"
systemctl restart NetworkManager

mkdir -p /root/.ssh
cat /mnt/$nfs_mount_dir/ssh/id_rsa.pub >> /root/.ssh/authorized_keys
cp /mnt/$nfs_mount_dir/ssh/id_rsa /root/.ssh/id_rsa
echo "${temp_public_key}" >> /root/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /root/.ssh/config
chmod 600 /root/.ssh/id_rsa
chmod 600 /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chown -R root:root /root/.ssh
sleep 5
