#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile="/tmp/user_data.log"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"

# Local variable declaration
logfile="/tmp/user_data.log"
vmPrefix="icgen2host"
default_cluster_name="HPCCluster"
nfs_mount_dir="data"
nfs_server=${storage_ips}

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf"
LSF_CONF=$LSF_TOP/conf
LSF_SSH=$LSF_TOP/ssh
LSF_CONF_FILE=$LSF_CONF/lsf.conf
LSF_HOSTS_FILE=$LSF_CONF/hosts
LSF_EGO_CONF_FILE=$LSF_CONF/ego/$cluster_name/kernel/ego.conf
LSF_LSBATCH_CONF="$LSF_CONF/lsbatch/$cluster_name/configdir"
LSF_RC_CONF=$LSF_CONF/resource_connector
LSF_RC_IC_CONF=$LSF_RC_CONF/ibmcloudgen2/conf
LSF_DM_STAGING_AREA=$LSF_TOP/das_staging_area
LSF_TOP_VERSION=$LSF_TOP/10.1
. $LSF_TOP/conf/profile.lsf
env >> $logfile

# Setup Hostname
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
ManagementHostName=${vmPrefix}-${privateIP//./-}
hostnamectl set-hostname ${ManagementHostName}
ManagementHostNames=`echo "${management_host_ips//./-}" | sed -e "s/^/${vmPrefix}-/g" | sed -e "s/ / ${vmPrefix}-/g"`

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
  echo "No NFS server and share found!" >> $logfile
fi

#Move the lsf intallation to the share location
mkdir -p /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp
mkdir -p $LSF_DM_STAGING_AREA
cp -a -r /opt/ibm/lsf/conf /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/conf
cp -a -r /opt/ibm/lsf/work /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/work
cp -a -r /opt/ibm/lsf/das_staging_area /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/das_staging_area
mkdir -p /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/log
mv /opt/ibm/lsf/conf /opt/ibm/lsf/conf_orig
mv /opt/ibm/lsf/das_staging_area /opt/ibm/lsf/das_staging_area_orig
rm -rf /opt/ibm/lsf/work /opt/ibm/lsf/log
mv /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp /mnt/$nfs_mount_dir/lsf_$ManagementHostName
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/conf /opt/ibm/lsf/conf
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/work /opt/ibm/lsf/work
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/log /opt/ibm/lsf/log
chown -R lsfadmin:root /mnt/$nfs_mount_dir/lsf_$ManagementHostName
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/das_staging_area /opt/ibm/lsf/das_staging_area
echo "moved lsf into nfs share location and link back done" >> $logfile
ln -s /mnt/$nfs_mount_dir /home/lsfadmin/shared

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

# Hyperthreading
if [ "$hyperthreading" == true ]; then
  ego_define_ncpus="threads"
else
  ego_define_ncpus="cores"
  for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo 0 > /sys/devices/system/cpu/cpu"$vcpu"/online
  done
fi
echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >> $LSF_CONF_FILE

# Update LSF configuration with new cluster name if cluster_name is not default
if [ "$default_cluster_name" != "$cluster_name" ]; then
  echo "New cluster name $cluster_name has been identified. Upgrading the cluster configurations accordingly" >> $logfile
  grep -rli "$default_cluster_name" $LSF_CONF/* | xargs sed -i "s/$default_cluster_name/$cluster_name/g" >> $logfile
  # Below directory in work has cluster_name twice in path and was resulting in a indefinite loop scenario. So, this directory has to be handled separately
  mv /opt/ibm/lsf/work/$default_cluster_name/live_confdir/lsbatch/$default_cluster_name /opt/ibm/lsf/work/"$cluster_name"/live_confdir/lsbatch/"$cluster_name" >> $logfile
  for file in $(find $LSF_TOP -name "*$default_cluster_name*"); do mv "$file" $(echo "$file"| sed -r "s/$default_cluster_name/$cluster_name/g"); done
fi

# Setting up lsf configuration
cat <<EOT >> $LSF_CONF_FILE
LSB_RC_EXTERNAL_HOST_IDLE_TIME=10
LSF_DYNAMIC_HOST_TIMEOUT=24
LSB_RC_EXTERNAL_HOST_FLAG="icgen2host"
LSB_RC_UPDATE_INTERVAL=15
LSB_RC_MAX_NEWDEMAND=50
LSF_UDP_TO_TCP_THRESHOLD=9000
LSF_CALL_LIM_WITH_TCP=N
LSF_ANNOUNCE_MASTER_TCP_WAITTIME=600
LSF_RSH="ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'"
EOT
sed -i "s/LSF_MASTER_LIST=.*/LSF_MASTER_LIST=\"${ManagementHostNames}\"/g" $LSF_CONF_FILE

# Update the Job directory
sed -i 's|<Path>/home</Path>|<Path>/mnt/data</Path>|' /opt/ibm/lsfsuite/ext/gui/conf/Repository.xml

# Setting up lsf.shared
sed -i "s/^#  icgen2host/   icgen2host/g" $LSF_CONF/lsf.shared

# Setting up lsb.module
sed -i "s/^#schmod_demand/schmod_demand/g" "$LSF_LSBATCH_CONF/lsb.modules"

# Setting up lsb.queue
sed -i '/^Begin Queue$/,/^End Queue$/{/QUEUE_NAME/{N;s/\(QUEUE_NAME\s*=[^\n]*\)\n/\1\nRC_HOSTS     = all\n/}}' "$LSF_LSBATCH_CONF/lsb.queues"
cat <<EOT >> "$LSF_LSBATCH_CONF/lsb.queues"
Begin Queue
QUEUE_NAME=das_q
DATA_TRANSFER=Y
RC_HOSTS=all
HOSTS=all
RES_REQ=type==any
End Queue
EOT

# Setting up lsb.hosts
for hostname in $ManagementHostNames; do
  sed -i "/^default    !.*/a $hostname  0 () () () () () (Y)" "$LSF_LSBATCH_CONF/lsb.hosts"
done

# Setting up lsf.cluster."$cluster_name"
sed -i "s/^lsfservers/#lsfservers/g" "$LSF_CONF/lsf.cluster.$cluster_name" ## ANAND
for hostname in $ManagementHostNames; do
  sed -i "/^#lsfservers.*/a $hostname ! ! 1 (mg)" "$LSF_CONF/lsf.cluster.$cluster_name"
done

# Update ego.conf
sed -i "s/EGO_MASTER_LIST=.*/EGO_MASTER_LIST=\"${ManagementHostNames}\"/g" "$LSF_EGO_CONF_FILE"
# Update lsfservers with newly added lsf management nodes
grep -rli 'lsfservers' $LSF_CONF/*|xargs sed -i "s/lsfservers/${ManagementHostName}/g"

# Setup LSF resource connector
# Create hostProviders.json
cat <<EOT > "$LSF_RC_CONF"/hostProviders.json
{
    "providers":[
        {
            "name": "ibmcloudgen2",
            "type": "ibmcloudgen2Prov",
            "confPath": "resource_connector/ibmcloudgen2",
            "scriptPath": "resource_connector/ibmcloudgen2"
        }
    ]
}
EOT

# Create ibmcloudgen2_config.json
cat <<EOT > "$LSF_RC_IC_CONF"/ibmcloudgen2_config.json
{
  "IBMCLOUDGEN2_KEY_FILE": "${LSF_RC_IC_CONF}/credentials",
  "IBMCLOUDGEN2_PROVISION_FILE": "${LSF_RC_IC_CONF}/user_data.sh",
  "IBMCLOUDGEN2_MACHINE_PREFIX": "${vmPrefix}",
  "LogLevel": "INFO"
}
EOT

# 4. Create credentials for ibmcloudgen2
cat <<EOT > "$LSF_RC_IC_CONF"/credentials
# BEGIN ANSIBLE MANAGED BLOCK
VPC_URL=http://vpc.cloud.ibm.com/v1
VPC_AUTH_TYPE=iam
VPC_APIKEY=$VPC_APIKEY_VALUE
RESOURCE_RECORDS_URL=https://api.dns-svcs.cloud.ibm.com/v1
RESOURCE_RECORDS_AUTH_TYPE=iam
RESOURCE_RECORDS_APIKEY=$VPC_APIKEY_VALUE
EOT

# Create ibmcloudgen2_templates.json
cat <<EOT > "$LSF_RC_IC_CONF"/ibmcloudgen2_templates.json
{
    "templates": [
        {
            "templateId": "Template-1",
            "maxNumber": "${rc_maxNum}",
            "attributes": {
                "type": ["String", "X86_64"],
                "ncores": ["Numeric", "${rc_ncores}"],
                "ncpus": ["Numeric", "${rc_ncpus}"],
                "mem": ["Numeric", "${rc_memInMB}"],
                "icgen2host": ["Boolean", "1"]
            },
            "imageId": "${imageID}",
            "subnetId": "${subnetID}",
            "vpcId": "${vpcID}",
            "vmType": "${rc_profile}",
            "securityGroupIds": ["${securityGroupID}"],
            "resourceGroupId": "${rc_rg}",
            "sshkey_id": "${sshkey_ID}",
            "region": "${regionName}",
            "zone": "${zoneName}"
        }
    ]
}
EOT

# Create user_data.json for compute nodes
cat <<EOT > "$LSF_RC_IC_CONF"/user_data.sh
#!/bin/bash

logfile="/tmp/user_data.log"
echo "START \$(date '+%Y-%m-%d %H:%M:%S')" >> \$logfile

# Initialize variables
vmPrefix="${vmPrefix}"
nfs_mount_dir="${nfs_mount_dir}"
nfs_server="${storage_ips}"
hyperthreading="${hyperthreading}"
ManagementHostNames="${ManagementHostNames}"
rc_cidr_block="${rc_cidr_block}"
temp_public_key="${temp_public_key}"

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf_worker"
LSF_TOP_VERSION=10.1
LSF_CONF=\$LSF_TOP/conf
LSF_CONF_FILE=\$LSF_CONF/lsf.conf
LSF_HOSTS_FILE=\${LSF_CONF}/hosts
. \$LSF_CONF/profile.lsf
echo "Logging env variables" >> \$logfile
env >> \$logfile

# Setup Hostname
HostIP=\$(hostname -I | awk '{print \$1}')
hostname=\${vmPrefix}-\${HostIP//./-}
hostnamectl set-hostname \$hostname

# Setting up Host file
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' \${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('\${rc_cidr_block}')]))" >> \${LSF_HOSTS_FILE}
cat \${LSF_HOSTS_FILE} >> /etc/hosts

# Setup Network configurations
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-eth0"
gateway_ip=\$(ip route | grep default | awk '{print \$3}' | head -n 1)
cidr_range=\$(ip route show | grep "kernel" | awk '{print \$1}' | head -n 1)
echo "\$cidr_range via \$gateway_ip dev eth0 metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
systemctl restart NetworkManager

# Conditional NFS mount
if [ -n "\${nfs_mount_dir}" ]; then
    mkdir -p /mnt/\$nfs_mount_dir
    echo "\${nfs_server}:/\$nfs_mount_dir /mnt/\$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
    mount /mnt/\$nfs_mount_dir
    ln -s /mnt/\$nfs_mount_dir /home/lsfadmin/shared
fi

# Allow login as lsfadmin
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
lsfadmin_home_dir="/home/lsfadmin"
lsfadmin_ssh_dir="\${lsfadmin_home_dir}/.ssh"
mkdir -p "\${lsfadmin_ssh_dir}"
cp "/mnt/\$nfs_mount_dir/ssh/authorized_keys" "\${lsfadmin_ssh_dir}/authorized_keys"
echo "StrictHostKeyChecking no" >> "\${lsfadmin_ssh_dir}/config"
chmod 600 "\${lsfadmin_ssh_dir}/authorized_keys"
chmod 700 "\${lsfadmin_ssh_dir}"
chown -R lsfadmin:lsfadmin "\${lsfadmin_ssh_dir}"

# Defining ncpus based on hyper-threading
if [ "\$hyperthreading" == true ]; then
  ego_define_ncpus="threads"
else
  ego_define_ncpus="cores"
  for vcpu in \$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo 0 > /sys/devices/system/cpu/cpu"\$vcpu"/online
  done
fi
echo "EGO_DEFINE_NCPUS=\${ego_define_ncpus}" >> \$LSF_CONF_FILE

# Update LSF Tuning on dynamic hosts
LSF_TUNABLES="/etc/sysctl.conf"
echo 'vm.overcommit_memory=1' >> \$LSF_TUNABLES
echo 'net.core.rmem_max=26214400' >> \$LSF_TUNABLES
echo 'net.core.rmem_default=26214400' >> \$LSF_TUNABLES
echo 'net.core.wmem_max=26214400' >> \$LSF_TUNABLES
echo 'net.core.wmem_default=26214400' >> \$LSF_TUNABLES
echo 'net.ipv4.tcp_fin_timeout = 5' >> \$LSF_TUNABLES
echo 'net.core.somaxconn = 8000' >> \$LSF_TUNABLES
sudo sysctl -p \$LSF_TUNABLES

# Update lsf configuration
echo 'LSB_MC_DISABLE_HOST_LOOKUP=Y' >> \$LSF_CONF_FILE
echo "LSF_RSH=\"ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'\"" >> \$LSF_CONF_FILE
sed -i "s/LSF_SERVER_HOSTS=.*/LSF_SERVER_HOSTS=\"\$ManagementHostNames\"/g" \$LSF_CONF_FILE

# TODO: Understand usage
# Support rc_account resource to enable RC_ACCOUNT policy
if [ -n "\${rc_account}" ]; then
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap \${rc_account}*rc_account]\"/" \$LSF_CONF_FILE
echo "Update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap \${rc_account}*rc_account]" >> \$logfile
fi

# Add additional local resources if needed
instance_id=\$(dmidecode | grep Family | cut -d ' ' -f 2 |head -1)
if [ -n "\$instance_id" ]; then
  sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap \$instance_id*instanceID]\"/" \$LSF_CONF_FILE
  echo "Update LSF_LOCAL_RESOURCES in \$LSF_CONF_FILE successfully, add [resourcemap \${instance_id}*instanceID]" >> \$logfile
else
  echo "Can not get instance ID" >> \$logfile
fi

# Source profile.lsf
echo "source \${LSF_CONF}/profile.lsf" >> "\${lsfadmin_home_dir}/.bashrc"
echo "source \${LSF_CONF}/profile.lsf" >> ~/.bashrc
source ~/.bashrc

# Startup lsf daemons
lsf_daemons start &
sleep 5
lsf_daemons status >> \$logfile
echo "END \$(date '+%Y-%m-%d %H:%M:%S')" >> \$logfile
EOT

echo "source /opt/ibm/lsf/conf/profile.lsf" >> /home/lsfadmin/.bashrc
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc
source ~/.bashrc

# Startup lsf daemons
lsf_daemons start &
sleep 5
lsf_daemons status >> $logfile

# Application Center Installation
if [ "$enable_app_center" = true ]; then
    if (( $(ls -ltr /opt/IBM/lsf_app_center_cloud_packages/ | grep "pac" | wc -l) > 0 )); then
        echo "Application Center package found !!" >> $logfile
        sleep 30
        su - lsfadmin -c "lsadmin ckconfig -v"
        echo ${app_center_gui_pwd} | sudo passwd --stdin lsfadmin
        sed -i '$i\\ALLOW_EVENT_TYPE=JOB_NEW JOB_STATUS JOB_FINISH2 JOB_START JOB_EXECUTE JOB_EXT_MSG JOB_SIGNAL JOB_REQUEUE JOB_MODIFY2 JOB_SWITCH METRIC_LOG' $LSF_ENVDIR/lsbatch/"$cluster_name"/configdir/lsb.params
        sed -i '$i\\ENABLE_EVENT_STREAM=Y' $LSF_ENVDIR/lsbatch/"$cluster_name"/configdir/lsb.params
        sed -i 's/NEWJOB_REFRESH=y/NEWJOB_REFRESH=Y/g' $LSF_ENVDIR/lsbatch/"$cluster_name"/configdir/lsb.params
        su - lsfadmin -c "badmin reconfig"
        sed -i 's/LSF_DISABLE_LSRUN=Y/LSF_DISABLE_LSRUN=N/g' $LSF_ENVDIR/lsf.conf
        echo 'LSB_BSUB_PARSE_SCRIPT=Y' >> $LSF_ENVDIR/lsf.conf
        echo LSF_ADDON_HOSTS=$ManagementHostName >> $LSF_ENVDIR/lsf.conf
        su - lsfadmin -c "lsfrestart -f && sleep 5 && lsadmin resrestart -f all"
        sudo systemctl start mariadb
        sudo systemctl status mariadb -l >> $logfile
        mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${app_center_db_pwd}';"
        count=0; while [ ! -f /opt/IBM/lsf_app_center_cloud_packages/*.tar.Z ] && [ $count -lt 30 ]; do echo "Waiting for Application Center package Decrypted from Cloud Entitlement !! " && sleep 10 && ((count++)); done && echo "Application Center package Decrypted successfully!" >> $logfile
        cd /opt/IBM/lsf_app_center_cloud_packages
        pac_url=$(ls /opt/IBM/lsf_app_center_cloud_packages/ | grep "pac")
        tar -xvf ${pac_url##*/}
        pac_folder=$(echo ${pac_url##*/} | sed 's/.tar.Z//g')
        cd ${pac_folder}
        sed -i 's/#\ \.\ $LSF_ENVDIR\/profile\.lsf/. \/opt\/ibm\/lsf\/conf\/profile\.lsf/g' pacinstall.sh
        sed -i 's/# export PAC_ADMINS=\"user1 user2\"/export PAC_ADMINS=\"lsfadmin\"/g' pacinstall.sh
        MYSQL_ROOT_PASSWORD=${app_center_db_pwd} sudo -E ./pacinstall.sh -s -y >> $logfile
        sleep 5
        sed -i 's/\/home/\/mnt\/data/g' $GUI_CONFDIR/Repository.xml
        echo 'source /opt/ibm/lsfsuite/ext/profile.platform' >> ~/.bashrc
        source ~/.bashrc
        lsadmin resrestart -f all; sleep 2; perfadmin start all; sleep 2; pmcadmin start; pmcadmin list >> $logfile
        sleep 5
        appcenter_status=$(pmcadmin list | grep "WEBGUI" | awk '{print $2}')
        if [ "$appcenter_status" = "STARTED" ]; then
            echo "Application Center installation completed..." >> $logfile
        else
            echo "Application Center installation failed..." >> $logfile
        fi
    else
        echo "Application Center package not found !!" >> $logfile
    fi
else
	  echo 'Application center installation skipped !!' >> $logfile
fi

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile