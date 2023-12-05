#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile="/tmp/user_data.log"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"

# Local variable declaration
vmPrefix="icgen2host"
nfs_server="${storage_ips}"
nfs_mount_dir="data"
ManagementHostNames=$(echo "${management_host_ips//./-}" | sed -e "s/^/$vmPrefix-/g" | sed -e "s/ / $vmPrefix-/g")
cluster_name=${cluster_name}

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf_worker"
LSF_TOP_VERSION=10.1
LSF_CONF="$LSF_TOP/conf"
LSF_CONF_FILE="$LSF_CONF/lsf.conf"
LSF_HOSTS_FILE="$LSF_CONF/hosts"
. "$LSF_CONF/profile.lsf"
echo "Logging env variables" >> "$logfile"
env >> "$logfile"

# Setup Hostname
HostIP=$(hostname -I | awk '{print $1}')
hostname="${vmPrefix}-${HostIP//./-}"
hostnamectl set-hostname "$hostname"

# Setting up Host file
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> "$LSF_HOSTS_FILE"
cat "$LSF_HOSTS_FILE" >> /etc/hosts

# Setup Network configurations
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-eth0"
gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
cidr_range=$(ip route show | grep "kernel" | awk '{print $1}' | head -n 1)
echo "$cidr_range via $gateway_ip dev eth0 metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
systemctl restart NetworkManager

# NFS Mount
if ([ -n "${nfs_server}" ]); then
  echo "NFS server and share found, start mount nfs share!" >> $logfile
  # Mount the nfs share
  mkdir -p /mnt/$nfs_mount_dir >> $logfile
  mount -t nfs $nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir >> $logfile
  df -h /mnt/$nfs_mount_dir >> $logfile
  ln -s /mnt/$nfs_mount_dir /home/lsfadmin/shared
  # Make auto mount when server is down
  echo "$nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  echo "Mount nfs share done!" >> $logfile
else
  echo "No NFS server and share found!" >> $logfile
fi

# Passwordless SSH authentication
sudo chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
cp /mnt/$nfs_mount_dir/ssh/id_rsa /root/.ssh/id_rsa
cat /mnt/$nfs_mount_dir/ssh/id_rsa.pub >> /root/.ssh/authorized_keys
mkdir -p /home/lsfadmin/.ssh
cp /mnt/$nfs_mount_dir/ssh/id_rsa /home/lsfadmin/.ssh/id_rsa
cp /mnt/$nfs_mount_dir/ssh/authorized_keys /home/lsfadmin/.ssh/authorized_keys
echo "${temp_public_key}" >> /root/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /root/.ssh/config
echo "StrictHostKeyChecking no" >> /home/lsfadmin/.ssh/config
chmod 600 /home/lsfadmin/.ssh/id_rsa
chmod 600 /home/lsfadmin/.ssh/authorized_keys
chmod 700 /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh

# Update LSF Tunables
LSF_TUNABLES="/etc/sysctl.conf"
echo "1" > /proc/sys/vm/overcommit_memory
echo 'vm.overcommit_memory=1' > "$LSF_TUNABLES"
echo 'net.core.rmem_max=26214400' >> "$LSF_TUNABLES"
echo 'net.core.rmem_default=26214400' >> "$LSF_TUNABLES"
echo 'net.core.wmem_max=26214400' >> "$LSF_TUNABLES"
echo 'net.core.wmem_default=26214400' >> "$LSF_TUNABLES"
echo 'net.ipv4.tcp_fin_timeout = 5' >> "$LSF_TUNABLES"
echo 'net.core.somaxconn = 8000' >> "$LSF_TUNABLES"
sysctl -p "$LSF_TUNABLES"

# Defining ncpus based on hyper-threading
if [ "$hyperthreading" == true ]; then
  ego_define_ncpus="threads"
else
  ego_define_ncpus="cores"
  for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo "0" > "/sys/devices/system/cpu/cpu$vcpu/online"
  done
fi
echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >> "$LSF_CONF_FILE"

# Update lsf configuration
echo 'LSB_MC_DISABLE_HOST_LOOKUP=Y' >> "$LSF_CONF_FILE"
sed -i "s/LSF_LOCAL_RESOURCES/#LSF_LOCAL_RESOURCES/"  "$LSF_CONF_FILE"
echo "LSF_RSH=\"ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'\"" >> "$LSF_CONF_FILE"
sed -i "s/LSF_SERVER_HOSTS=.*/LSF_SERVER_HOSTS=\"$ManagementHostNames\"/g" "$LSF_CONF_FILE"

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

# Startup lsf daemons
lsf_daemons start &
sleep 5
lsf_daemons status >> "$logfile"

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"