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
vmPrefix="icgen2host"

#If no dns, then will fixed the hostname based on provate IP address and hostname, if you have dns server, then can completely remove this part
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
ManagementHostName=${vmPrefix}-${privateIP//./-}
hostnamectl set-hostname ${ManagementHostName}
networkIPrange=$(echo ${privateIP}|cut -f1-3 -d .)
host_prefix=$(hostname|cut -f1-4 -d -)

# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
ip route replace $rc_cidr_block  dev eth0 proto kernel scope link src $privateIP mtu 9000
echo 'ip route replace '$rc_cidr_block' dev eth0 proto kernel scope link src '$privateIP' mtu 9000' >> /etc/sysconfig/network-scripts/route-eth0

#for controllerIP in $controller_ips; do
  #if [ "$controllerIP" != "$privateIP" ]; then
      #ip route add $controllerIP dev eth0 mtu 9000
      #echo 'ip route add '$controllerIP' dev eth0 mtu 9000' >> /etc/sysconfig/network-scripts/route-eth0
  #fi
#done

# NOTE: On ibm gen2, the default DNS server do not have reverse hostname/IP resolution.
# 1) put the controller server hostname and ip into lsf hosts.
# 2) put all possible VMs' hostname and ip into lsf hosts.
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts

#Update controller host name based on with nfs share or not
if ([ -n "${nfs_server}" ] && [ -n "${nfs_mount_dir}" ]); then
  echo "NFS server and share found, start mount nfs share!" >> $logfile
  #Mount the nfs share
  showmount -e $nfs_server >> $logfile
  mkdir -p /mnt/$nfs_mount_dir >> $logfile
  mount -t nfs $nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir >> $logfile
  df -h /mnt/$nfs_mount_dir >> $logfile
  #make auto mount when server is down
  echo "$nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  echo "Mount nfs share done!" >> $logfile
  # delete old config dir
  rm -rf /mnt/$nfs_mount_dir/lsf_$ManagementHostName /mnt/$nfs_mount_dir/ssh
  # Generate and copy a public ssh key
  mkdir -p /mnt/$nfs_mount_dir/ssh /home/lsfadmin/.ssh
  #Create the sshkey in the share directory and then copy the public and private key to respective root and lsfadmin .ssh folder
  ssh-keygen -q -t rsa -f /mnt/$nfs_mount_dir/ssh/id_rsa -C "lsfadmin@${ManagementHostName}" -N "" -q
  cat /mnt/$nfs_mount_dir/ssh/id_rsa.pub >> /root/.ssh/authorized_keys
  cp /root/.ssh/authorized_keys /mnt/$nfs_mount_dir/ssh/authorized_keys
  cp /mnt/$nfs_mount_dir/ssh/id_rsa /root/.ssh/id_rsa
  echo "StrictHostKeyChecking no" >> /root/.ssh/config
  cp /mnt/$nfs_mount_dir/ssh/id_rsa /home/lsfadmin/.ssh/id_rsa
  cp /mnt/$nfs_mount_dir/ssh/authorized_keys /home/lsfadmin/.ssh/authorized_keys
  echo "${temp_public_key}" >> /root/.ssh/authorized_keys
  chmod 600 /home/lsfadmin/.ssh/authorized_keys
  chmod 700 /home/lsfadmin/.ssh
  chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh

  echo "StrictHostKeyChecking no" >> /home/lsfadmin/.ssh/config
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

#update the lsf controller hostname
grep -rli 'lsfservers' $LSF_CONF/*|xargs sed -i "s/lsfservers/${ManagementHostName}/g"

#Add management candidate host into lsf cluster
ManagementHostNames=`echo "${controller_ips//./-}" | sed -e "s/^/${vmPrefix}-/g" | sed -e "s/ / ${vmPrefix}-/g"`
sed -i "s/LSF_CONTROLLER_LIST=.*/LSF_CONTROLLER_LIST=\"${ManagementHostNames}\"/g" $LSF_CONF_FILE
sed -i "s/EGO_CONTROLLER_LIST=.*/EGO_CONTROLLER_LIST=\"${ManagementHostNames}\"/g" $LSF_EGO_CONF_FILE
for ManagementCandidateHostName in ${ManagementHostNames}; do
  if [ "${ManagementCandidateHostName}" != "${ManagementHostName}" ]; then
    sed -i "/^$ManagementHostName.*/a ${ManagementCandidateHostName} ! ! 1 (mg)" $LSF_CLUSTER_FILE
    sed -i "/^#hostE.*/a ${ManagementCandidateHostName} 0 () () () () () (Y)" $LSB_HOSTS_FILE
  fi
done
sed -i "s/controller_hosts.*/controller_hosts (${ManagementHostNames} )/g" $LSB_HOSTS_FILE
# TODO: ebrokerd runs only on the primary controller. Can we create/delete dynamic workers after failover?
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
sed -i "s/template1-ncores/${rc_ncores}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-ncpus/${rc_ncpus}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-mem/${rc_memInMB}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-vmType/${rc_profile}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1_maxNum/${rc_maxNum}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/rgId-value/${rc_rg}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/icgen2host/${vmPrefix}/" $IBM_CLOUD_CONF_FILE
cat >> $IBM_CLOUD_USER_DATA_FILE << EOF
privateIP=\$(ip addr show eth0 | awk '\$1 == "inet" {gsub(/\/.*$/, "", \$2); print \$2}')
ip route replace $rc_cidr_block  dev eth0 proto kernel scope link src \$privateIP mtu 9000
ip route replace $rc_cidr_block dev eth0 proto kernel scope link src '\$privateIP' mtu 9000' >> /etc/sysconfig/network-scripts/route-eth0
EOF

if $hyperthreading; then
  echo "EGO_DEFINE_NCPUS=threads" >> $LSF_CONF_FILE
else
  echo "EGO_DEFINE_NCPUS=cores" >> $LSF_CONF_FILE
  for vcpu in `cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq`; do
    echo 0 > /sys/devices/system/cpu/cpu$vcpu/online
  done
fi

# Insert our custom user script to workers' user data
cat << EOF >> /tmp/client.sh
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /opt/ibm/lsf_worker/conf/hosts
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts
mkdir -p /mnt/$nfs_mount_dir
mount -t nfs $nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir
echo "$nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
ln -s /mnt/$nfs_mount_dir /home/lsfadmin/shared
# Allow ssh from controller
sed -i "s#^\(AuthorizedKeysFile.*\)#\1 /mnt/$nfs_mount_dir/ssh/authorized_keys#g" /etc/ssh/sshd_config
systemctl restart sshd
#echo "LSF_MQ_BROKER_HOSTS=\"${ManagementHostNames}\"" >> /opt/ibm/lsf_worker/conf/lsf.conf
EOF

if $hyperthreading; then
cat << EOF >> /tmp/client.sh
EGO_DEFINE_NCPUS=threads >> /opt/ibm/lsf_worker/conf/lsf.conf
EOF
else
cat << EOF >> /tmp/client.sh
EGO_DEFINE_NCPUS=cores >> /opt/ibm/lsf_worker/conf/lsf.conf
for vcpu in \`cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq\`; do
  echo 0 > /sys/devices/system/cpu/cpu\$vcpu/online
done
EOF
fi

sed -i 's#for ((i=1; i<=254; i++))#for ((i=1; i<=0; i++))#g' $IBM_CLOUD_USER_DATA_FILE
sed -i "/# Add your customization script here/r /tmp/client.sh" $IBM_CLOUD_USER_DATA_FILE

#Move the lsf intallation to the share location
mkdir -p /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp
cp -a -r /opt/ibm/lsf/conf /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/conf
cp -a -r /opt/ibm/lsf/work /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/work
cp -a -r /opt/ibm/lsf/das_staging_area /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/das_staging_area
mkdir -p /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/log
mv /opt/ibm/lsf/conf /opt/ibm/lsf/conf_orig
mv /opt/ibm/lsf/das_staging_area /opt/ibm/lsf/das_staging_area_orig
rm -rf /opt/ibm/lsf/work /opt/ibm/lsf/log
mv /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp /mnt/$nfs_mount_dir/lsf_$ManagementHostName
#link lsf back to its original installation location
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/conf /opt/ibm/lsf/conf
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/work /opt/ibm/lsf/work
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/log /opt/ibm/lsf/log
chown lsfadmin:root /mnt/$nfs_mount_dir/lsf_$ManagementHostName/log
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/das_staging_area /opt/ibm/lsf/das_staging_area
echo "moved lsf into nfs share location and link back done" >> $logfile

ln -s /mnt/$nfs_mount_dir /home/lsfadmin/shared

#Updates the lsfadmin user as never expire
sudo chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
cat << EOF > /etc/profile.d/lsf.sh
ls /opt/ibm/lsf/conf/lsf.conf > /dev/null 2> /dev/null < /dev/null &
usleep 10000
PID=\$!
if kill -0 \$PID 2> /dev/null; then
  # lsf.conf is not accessible 
  kill -KILL \$PID 2> /dev/null > /dev/null
  wait \$PID
else
  source /opt/ibm/lsf/conf/profile.lsf
fi
export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no"
PATHs=\`echo "\$PATH" | sed -e 's/:/\n/g'\`
for path in /usr/local/bin /usr/bin /usr/local/sbin /usr/sbin; do
  PATHs=\`echo "\$PATHs" | grep -v \$path\`
done
export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:\`echo "\$PATHs" | paste -s -d :\`
EOF

# TODO: disallow root login

cat $LSF_HOSTS_FILE >> $logfile
cat $LSF_ENTITLEMENT_FILE >> $logfile
cat $LS_ENTITLEMENT_FILE >> $logfile
cat $IBM_CLOUD_CREDENTIALS_FILE >> $logfile
cat $IBM_CLOUD_TEMPLATE_FILE >> $logfile
cat $IBM_CLOUD_USER_DATA_FILE >> $logfile

echo 1 > /proc/sys/vm/overcommit_memory # new image requires this. otherwise, it reports many failures of memory allocation at fork() if we use candidates. why?
echo 'vm.overcommit_memory=1' > /etc/sysctl.d/90-lsf.conf

sleep 5
lsf_daemons start &
sleep 5
lsf_daemons status >> $logfile
echo END `date '+%Y-%m-%d %H:%M:%S'` >> $logfile
