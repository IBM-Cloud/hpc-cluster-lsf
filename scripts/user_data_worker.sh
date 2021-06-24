###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#
# Source LSF enviornment at the VM host
#
LSF_TOP=/opt/ibm/lsf_worker
LSF_CONF=$LSF_TOP/conf
LSF_CONF_FILE=$LSF_CONF/lsf.conf
LSF_ENTITLEMENT_FILE=$LSF_CONF/lsf.entitlement
LS_ENTITLEMENT_FILE=$LSF_CONF/ls.entitlement
LSF_HOSTS_FILE=$LSF_CONF/hosts
. $LSF_TOP/conf/profile.lsf
DATA_DIR=/data

env 

#Update Master host name based on internal IP address
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
hostName=ibm-gen2host-${privateIP//./-}
hostnamectl set-hostname ${hostName}
masterHostNamesStr=`echo "${master_ips//./-}" | sed -e 's/^/ibm-gen2host-/g' | sed -e 's/ / ibm-gen2host-/g'`
ln -s $LSF_CONF/profile.lsf /opt/ibm/profile.lsf
echo "source /opt/ibm/profile.lsf" >> /root/.bashrc

# NOTE: On ibm gen2, the default DNS server do not have reverse hostname/IP resolution.
# 1) put the master server hostname and ip into lsf hosts.
# 2) put all possible VMs' hostname and ip into lsf hosts.
python3 -c "import ipaddress; print('\n'.join([str(ip) + '    ibm-gen2host-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> $LSF_HOSTS_FILE
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ibm-gen2host-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts

#update the lsf master hostname
sed -i "s/lsfservers/${masterHostNamesStr}/"  $LSF_CONF_FILE

# Support rc_account resource to enable RC_ACCOUNT policy  
# Add additional local resources if needed 
#
if [ -n "${rc_account}" ]; then
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap ${rc_account}*rc_account]\"/" $LSF_CONF_FILE
echo "update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap ${rc_account}*rc_account]" >> $logfile
fi

if [ -n "$template_id" ]; then
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap $template_id*templateID]\"/" $LSF_CONF_FILE
echo "update LSF_LOCAL_RESOURCES in $LSF_CONF_FILE successfully, add [resourcemap ${template_id}*templateID]" >> $logfile
else
echo "templateID doesn't exist in envrionment variable" >> $logfile
fi

if [ -n "$clusterName" ]; then
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap $clusterName*clusterName]\"/" $LSF_CONF_FILE
echo "update LSF_LOCAL_RESOURCES in $LSF_CONF_FILE successfully, add [resourcemap ${clusterName}*clusterName]" >> $logfile
else
echo "clusterName doesn't exist in envrionment variable" >> $logfile
fi

if [ -n "$providerName" ]; then
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap $providerName*providerName]\"/" $LSF_CONF_FILE
echo "update LSF_LOCAL_RESOURCES in $LSF_CONF_FILE successfully, add [resourcemap ${providerName}*providerName]" >> $logfile
else
echo "providerName doesn't exist in envrionment variable" >> $logfile
fi

# https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-nfs-mount-settings.html
# option noresvport is not available.
yum install -y nfs-utils
mkdir $DATA_DIR
storage_ips=($storage_ips)
echo "${storage_ips[0]}:$DATA_DIR      $DATA_DIR      nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
echo "${storage_ips[0]}:/home/lsfadmin /home/lsfadmin nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
mount $DATA_DIR
mount /home/lsfadmin

sleep 5
lsf_daemons start &

lsf_daemons status >> $logfile
echo END `date '+%Y-%m-%d %H:%M:%S'`
