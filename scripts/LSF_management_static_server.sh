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
#cluster_name=""

if [ ! -z $cluster_name ]
then
  oldclustername="BigComputeCluster"
else
  cluster_name="BigComputeCluster"
fi
newclustername=$cluster_name

#No rquirement of having the below as user input, following defaults will be used
ncores="1"
vmPrefix="icgen2host"

# Change the MTU setting
ip link set mtu 9000 dev eth0
echo "MTU=9000" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "PEERDNS=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0

#If no dns, then will fixed the hostname based on provate IP address and hostname, if you have dns server, then can completely remove this part
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
ManagementHostName=${vmPrefix}-${privateIP//./-}
hostnamectl set-hostname ${ManagementHostName}
networkIPrange=$(echo ${privateIP}|cut -f1-3 -d .)
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
  echo "$nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs defaults 0 0 " >> /etc/fstab
  echo "Mount nfs share done!" >> $logfile
  if [ -d /mnt/$nfs_mount_dir/lsf_$ManagementHostName ]; then
    echo "lsf directory already exits in nfs share" >> $logfile
    lsf_link=$(ls -la /opt/ibm/lsf | grep "\->")
    echo $lsf_link
    if [ -n "${lsf_link}" ]; then 
      echo "lsf linked to the share already" >>  $logfile
    else
      echo "link the lsf to share location" >> $logfile
      mv /opt/ibm/lsf /opt/ibm/lsf_org
      ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName /opt/ibm/lsf
    fi
  #Make sure the mount location is there, but lsf is not in the mount
  elif [ -d /mnt/$nfs_mount_dir ]; then
    #backup orignal lsf installation
    cp -rpf /opt/ibm/lsf /opt/ibm/lsf_org 
  else
    echo "nfs filesystem not mounted" >> $logfile
  fi  
  # Generate and copy a public ssh key
  mkdir -p /mnt/$nfs_mount_dir/ssh /home/lsfadmin/.ssh
  ssh-keygen -q -t rsa -f /root/.ssh/id_rsa -C "lsfadmin@${ManagementHostName}" -N "" -q
  cat /root/.ssh/id_rsa.pub >> /mnt/$nfs_mount_dir/ssh/authorized_keys
  mv /root/.ssh/id_rsa /home/lsfadmin/.ssh/
else
  echo "No NFS server and share found!" >> $logfile
fi

#
# Source LSF enviornment at the VM host
#
LSF_TOP=/opt/ibm/lsf
LSF_CONF=$LSF_TOP/conf
LSF_IBM_GEN2=$LSF_CONF/resource_connector/ibmcloudgen2
LSF_CONF_FILE=$LSF_CONF/lsf.conf
LSF_ENTITLEMENT_FILE=$LSF_CONF/lsf.entitlement
LS_ENTITLEMENT_FILE=$LSF_CONF/ls.entitlement
LSF_HOSTS_FILE=$LSF_CONF/hosts
LSB_HOSTS_FILE=$LSF_CONF/lsbatch/$newclustername/configdir/lsb.hosts
LSF_EGO_CONF_FILE=$LSF_CONF/ego/$newclustername/kernel/ego.conf
LSF_CLUSTER_FILE=$LSF_CONF/lsf.cluster.$newclustername
IBM_CLOUD_CREDENTIALS_FILE=$LSF_IBM_GEN2/credentials
IBM_CLOUD_TEMPLATE_FILE=$LSF_IBM_GEN2/conf/ibmcloudgen2_templates.json
IBM_CLOUD_USER_DATA_FILE=$LSF_IBM_GEN2/user_data.sh
IBM_CLOUD_CONF_FILE=$LSF_IBM_GEN2/conf/ibmcloudgen2_config.json
. $LSF_TOP/conf/profile.lsf

env >> $logfile

python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> $LSF_HOSTS_FILE

#Update LSF and LS entitlement
echo $LS_Entitlement >> $LS_ENTITLEMENT_FILE
echo $LSF_Entitlement >> $LSF_ENTITLEMENT_FILE

#Update cluster name from all configuration files to the new cluster name
if [ ! -z $cluster_name ]
then
   grep -rli "$oldclustername" $LSF_CONF/*|xargs sed -i "s/$oldclustername/$newclustername/g" >> $logfile
   #Update directory name to the new cluster name
   mv /opt/ibm/lsf/work/$oldclustername/live_confdir/lsbatch/$oldclustername /opt/ibm/lsf/work/$oldclustername/live_confdir/lsbatch/$newclustername >> $logfile
   find /opt/ibm/lsf/ -type d -name "$oldclustername" -execdir bash -c "mv {} $newclustername" \;  -prune >> $logfile
   #update the configuration file name to the new cluster name
   find $LSF_CONF/ -type f -name "*$oldclustername" | while read FILE ;
   do
     newfile="$(echo ${FILE} |sed -e "s/$oldclustername/$newclustername/g")" ;
     mv "${FILE}" "${newfile}" ;
   done
fi

#update the lsf master hostname
grep -rli 'lsfservers' $LSF_CONF/*|xargs sed -i "s/lsfservers/${ManagementHostName}/g"

#Add management candidate host into lsf cluster
ManagementHostNames=`echo "${master_ips//./-}" | sed -e "s/^/${vmPrefix}-/g" | sed -e "s/ / ${vmPrefix}-/g"`
sed -i "s/LSF_MASTER_LIST=.*/LSF_MASTER_LIST=\"${ManagementHostNames}\"/g" $LSF_CONF_FILE
sed -i "s/EGO_MASTER_LIST=.*/EGO_MASTER_LIST=\"${ManagementHostNames}\"/g" $LSF_EGO_CONF_FILE
for ManagementCandidateHostName in ${ManagementHostNames}; do
  if [ "${ManagementCandidateHostName}" != "${ManagementHostName}" ]; then
    sed -i "/^$ManagementHostName.*/a ${ManagementCandidateHostName} ! ! 1 (mg)" $LSF_CLUSTER_FILE
    sed -i "/^#hostE.*/a ${ManagementCandidateHostName} 0 () () () () () (Y)" $LSB_HOSTS_FILE
  fi
done
sed -i "s/master_hosts.*/master_hosts (${ManagementHostNames} )/g" $LSB_HOSTS_FILE
# TODO: ebrokerd runs only on the primary master. Can we create/delete dynamic workers after failover?
# https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=connnector-lsf-resource-connector-overview
#sed -i "s/LSF_MQ_BROKER_HOSTS=.*/LSF_MQ_BROKER_HOSTS=\"${ManagementHostNames}\"/g" $LSF_CONF_FILE
#sed -i "s/LSF_DATA_HOSTS=.*/LSF_DATA_HOSTS=\"${ManagementHostNames}\"/g" $LSF_CONF_FILE
#sed -i "s/MQTT_BROKER_HOST=/#MQTT_BROKER_HOST=/g" $LSF_CONF_FILE
#sed -i "s/MQTT_BROKER_PORT=/#MQTT_BROKER_PORT=/g" $LSF_CONF_FILE

# when we request a lot of machines, it may need close to 5 minutes for all the nodes to join the cluster.
sed -i "s/LSB_RC_EXTERNAL_HOST_IDLE_TIME=.*/LSB_RC_EXTERNAL_HOST_IDLE_TIME=10/g" $LSF_CONF_FILE

#update user_data.sh
sed -i "s/ServerHostPlaceHolder/${ManagementHostNames}/" $IBM_CLOUD_USER_DATA_FILE
sed -i "s/icgen2host/${vmPrefix}/" $IBM_CLOUD_USER_DATA_FILE

#update IBM gen2 Credentials API keys
sed -i "s/VPC_APIKEY=/VPC_APIKEY=$VPC_APIKEY_VALUE/" $IBM_CLOUD_CREDENTIALS_FILE
sed -i "s/RESOURCE_RECORDS_APIKEY=/RESOURCE_RECORDS_APIKEY=$RESOURCE_RECORDS_APIKEY_VALUE/" $IBM_CLOUD_CREDENTIALS_FILE

#Update IBM gen2 template
sed -i "s/imageId-value/${imageID}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/subnetId-value/${subnetID}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/vpcId-value/${vpcID}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/securityGroupIds-value/${securityGroupID}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/sshkey_id-value/${sshkey_ID}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/region-value/${regionName}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/zone-value/${zoneName}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-ncores/${ncores}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-ncpus/${rc_ncores}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-mem/${rc_memInMB}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-vmType/${rc_profile}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1_maxNum/${rc_maxNum}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/icgen2host/${vmPrefix}/" $IBM_CLOUD_CONF_FILE

# Insert our custom user script to workers' user data
cat << EOF >> /tmp/client.sh
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /opt/ibm/lsf_worker/conf/hosts
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts
mkdir -p /mnt/$nfs_mount_dir
mount -t nfs $nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir
echo "$nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
ln -s /mnt/$nfs_mount_dir /home/lsfadmin/shared
# Allow ssh from master
sed -i "s#^\(AuthorizedKeysFile.*\)#\1 /mnt/$nfs_mount_dir/ssh/authorized_keys#g" /etc/ssh/sshd_config
systemctl restart sshd
#echo "LSF_MQ_BROKER_HOSTS=\"${ManagementHostNames}\"" >> /opt/ibm/lsf_worker/conf/lsf.conf
EOF

sed -i 's#for ((i=1; i<=254; i++))#for ((i=1; i<=0; i++))#g' $IBM_CLOUD_USER_DATA_FILE
sed -i "/# Add your customization script here/r /tmp/client.sh" $IBM_CLOUD_USER_DATA_FILE

#Move the lsf intallation to the share location
mv /opt/ibm/lsf /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp # indirectly copying files to avoid race condition
mv /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp /mnt/$nfs_mount_dir/lsf_$ManagementHostName
#link lsf back to its original installation location
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName /opt/ibm/lsf
echo "moved lsf into nfs share location and link back done" >> $logfile

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

cat $LSF_HOSTS_FILE >> $logfile
cat $LSF_ENTITLEMENT_FILE >> $logfile
cat $LS_ENTITLEMENT_FILE >> $logfile
cat $IBM_CLOUD_CREDENTIALS_FILE >> $logfile
cat $IBM_CLOUD_TEMPLATE_FILE >> $logfile
cat $IBM_CLOUD_USER_DATA_FILE >> $logfile

sleep 5
lsf_daemons start &
sleep 5
lsf_daemons status >> $logfile
echo END `date '+%Y-%m-%d %H:%M:%S'` >> $logfile
