#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile="/tmp/user_data.log"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"

# Local variable declaration
logfile="/tmp/user_data.log"
default_cluster_name="HPCCluster"
nfs_server_with_mount_path=${mount_path}
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
login_ip_address=${login_ip_address}
login_hostname="${cluster_prefix}-login"
HostIP=$(hostname -I | awk '{print $1}')
HostName=$(hostname)
ManagementHostName="${HostName}"
ManagementHostNames=""
for (( i=1; i<=management_node_count; i++ ))
do
  ManagementHostNames+=" ${cluster_prefix}-mgmt-$i"
done
echo "Nodes: $ManagementHostNames" >> $logfile

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

# Setup Network configurations
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
echo "DOMAIN=\"${dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
echo "${rc_cidr_block} via $gateway_ip dev eth0 metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
systemctl restart NetworkManager

# Setup LSF
echo "Setting LSF share." >> $logfile
# Setup file share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >> $logfile
  # Create a data directory for sharing HPC workload data
  #mkdir -p "${LSF_TOP}/data"
  mkdir -p "/opt/ibm/lsf/das_staging_area"
  nfs_client_mount_path="/mnt/lsf"
  rm -rf "${nfs_client_mount_path}"
  mkdir -p "${nfs_client_mount_path}"
  # Mount LSF TOP
  mount -t nfs4 -o sec=sys,vers=4.1 "$nfs_server_with_mount_path" "$nfs_client_mount_path" >> $logfile
  # Verify mount
  if mount | grep "$nfs_client_mount_path"; then
    echo "Mount found" >> $logfile
  else
    echo "No mount found, exiting!" >> $logfile
    exit 1
  fi
  # Update mount to fstab for automount
  echo "$nfs_server_with_mount_path $nfs_client_mount_path nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  for dir in conf work das_staging_area; do
    mv "/opt/ibm/lsf/$dir" "${nfs_client_mount_path}"
    ln -fs "${nfs_client_mount_path}/$dir" "/opt/ibm/lsf"
    chown -R lsfadmin:root "/opt/ibm/lsf"
  done
else
  echo "No mount point value found, exiting!" >> $logfile
  exit 1
fi
echo "Setting LSF share is completed." >> $logfile

# Setup Custom file shares
echo "Setting custom file shares." >> $logfile
# Setup file share
if [ -n "${custom_file_shares}" ]; then
  echo "Custom file share ${custom_file_shares} found" >> $logfile
  file_share_array=(${custom_file_shares})
  mount_path_array=(${custom_mount_paths})
  length=${#file_share_array[@]}
  for (( i=0; i<length; i++ ))
  do
    rm -rf "${mount_path_array[$i]}"
    mkdir -p "${mount_path_array[$i]}"
    # Mount LSF TOP
    mount -t nfs4 -o sec=sys,vers=4.1 "${file_share_array[$i]}" "${mount_path_array[$i]}" >> $logfile
    # Verify mount
    if mount | grep "${file_share_array[$i]}"; then
      echo "Mount found" >> $logfile
    else
      echo "No mount found" >> $logfile
    fi
    # Update permission to 777 for all users to access
    chmod 777 ${mount_path_array[$i]}
    # Update mount to fstab for automount
    echo "${file_share_array[$i]} ${mount_path_array[$i]} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  done
fi
echo "Setting custom file shares is completed." >> $logfile

# Generate and copy a public ssh key
mkdir -p "${nfs_client_mount_path}/ssh" /home/lsfadmin/.ssh
#Create the sshkey in the share directory and then copy the public and private key to respective root and lsfadmin .ssh folder
ssh-keygen -q -t rsa -f "${nfs_client_mount_path}/ssh/id_rsa" -C "lsfadmin@${ManagementHostName}" -N "" -q
cat "${nfs_client_mount_path}/ssh/id_rsa.pub" >> /root/.ssh/authorized_keys
cp /root/.ssh/authorized_keys "${nfs_client_mount_path}/ssh/authorized_keys"
cp "${nfs_client_mount_path}/ssh/id_rsa" /root/.ssh/id_rsa
echo "StrictHostKeyChecking no" >> /root/.ssh/config
cp "${nfs_client_mount_path}/ssh/id_rsa" /home/lsfadmin/.ssh/id_rsa
cp "${nfs_client_mount_path}/ssh/authorized_keys" /home/lsfadmin/.ssh/authorized_keys
echo "${temp_public_key}" >> /root/.ssh/authorized_keys
chmod 600 /home/lsfadmin/.ssh/authorized_keys
chmod 700 /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh
echo "StrictHostKeyChecking no" >> /home/lsfadmin/.ssh/config

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

# Updating the value of login node as Intel for lsfserver to update cluster file name
sed -i "/^#lsfservers.*/a $login_hostname Intel_E5 X86_64 0 ()" "$LSF_CONF/lsf.cluster.$cluster_name"
echo "LSF_SERVER_HOSTS=\"$ManagementHostNames\"" >> $LSF_CONF_FILE

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
  "IBMCLOUDGEN2_MACHINE_PREFIX": "${cluster_prefix}",
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
cluster_prefix="${cluster_prefix}"
nfs_server_with_mount_path=${mount_path}
custom_file_shares="${custom_file_shares}"
custom_mount_paths="${custom_mount_paths}"
hyperthreading="${hyperthreading}"
ManagementHostNames="${ManagementHostNames}"
rc_cidr_block="${rc_cidr_block}"
temp_public_key="${temp_public_key}"
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
dns_domain="${dns_domain}"
network_interface="${network_interface}"

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
hostname=\${cluster_prefix}-\${HostIP//./-}
hostnamectl set-hostname \$hostname

# Setup Network configuration
# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
    # Replace the MTU value in the Netplan configuration
    echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    echo "DOMAIN=\"${dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    # Change the MTU setting as 9000 at router level.
    gateway_ip=\$(ip route | grep default | awk '{print \$3}' | head -n 1)
    cidr_range=\$(ip route show | grep "kernel" | awk '{print \$1}' | head -n 1)
    echo "\$cidr_range via \$gateway_ip dev ${network_interface} metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
    # Restart the Network Manager.
    systemctl restart NetworkManager
elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then
    net_int=\$(basename /sys/class/net/en*)
    netplan_config="/etc/netplan/50-cloud-init.yaml"
    gateway_ip=\$(ip route | grep default | awk '{print \$3}' | head -n 1)
    cidr_range=\$(ip route show | grep "kernel" | awk '{print \$1}' | head -n 1)
    usermod -s /bin/bash lsfadmin
    # Replace the MTU value in the Netplan configuration
    if ! grep -qE "^[[:space:]]*mtu: 9000" \$netplan_config; then
        echo "MTU 9000 Packages entries not found"
        # Append the MTU configuration to the Netplan file
        sudo sed -i '/'\$net_int':/a\            mtu: 9000' \$netplan_config
        sudo sed -i "/dhcp4: true/a \            nameservers:\n              search: [\$dns_domain]" \$netplan_config
        sudo sed -i '/'\$net_int':/a\            routes:\n              - to: '\$cidr_range'\n                via: '\$gateway_ip'\n                metric: 100\n                mtu: 9000' \$netplan_config
        sudo netplan apply
        echo "MTU set to 9000 on Netplan."
    else
        echo "MTU entry already exists in Netplan. Skipping."
    fi
fi

# TODO: Conditional NFS mount
LSF_TOP="/opt/ibm/lsf"
# Setup file share
if [ -n "\${nfs_server_with_mount_path}" ]; then
  echo "File share \${nfs_server_with_mount_path} found" >> \$logfile
  nfs_client_mount_path="/mnt/lsf"
  rm -rf "\${nfs_client_mount_path}"
  mkdir -p "\${nfs_client_mount_path}"
  # Mount LSF TOP
  mount -t nfs4 -o sec=sys,vers=4.1 "\$nfs_server_with_mount_path" "\$nfs_client_mount_path" >> \$logfile
  # Verify mount
  if mount | grep "\$nfs_client_mount_path"; then
    echo "Mount found" >> \$logfile
  else
    echo "No mount found, exiting!" >> \$logfile
    exit 1
  fi
  # Update mount to fstab for automount
  echo "\$nfs_server_with_mount_path \$nfs_client_mount_path nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  for dir in conf work das_staging_area; do
    rm -rf "/opt/ibm/lsf/\$dir"
    ln -fs "\${nfs_client_mount_path}/\$dir" "/opt/ibm/lsf"
    chown -R lsfadmin:root "/opt/ibm/lsf"
  done
fi
echo "Setting LSF share is completed." >> \$logfile

# Setup Custom file shares
echo "Setting custom file shares." >> \$logfile
# Setup file share
if [ -n "\${custom_file_shares}" ]; then
  echo "Custom file share \${custom_file_shares} found" >> \$logfile
  file_share_array=(\${custom_file_shares})
  mount_path_array=(\${custom_mount_paths})
  length=\${#file_share_array[@]}
  for (( i=0; i<length; i++ ))
  do
    rm -rf "\${mount_path_array[\$i]}"
    mkdir -p "\${mount_path_array[\$i]}"
    # Mount LSF TOP
    mount -t nfs4 -o sec=sys,vers=4.1 "\${file_share_array[\$i]}" "\${mount_path_array[\$i]}" >> \$logfile
    # Verify mount
    if mount | grep "\${file_share_array[\$i]}"; then
      echo "Mount found" >> \$logfile
    else
      echo "No mount found" >> \$logfile
    fi
    # Update permission to 777 for all users to access
    chmod 777 \${mount_path_array[\$i]}
    # Update mount to fstab for automount
    echo "\${file_share_array[\$i]} \${mount_path_array[\$i]} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  done
fi
echo "Setting custom file shares is completed." >> \$logfile

# Setup ssh
sudo chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
mkdir -p /home/lsfadmin/.ssh
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
  sudo cp /home/vpcuser/.ssh/authorized_keys /home/lsfadmin/.ssh/authorized_keys
else
  cp /home/ubuntu/.ssh/authorized_keys /home/lsfadmin/.ssh/authorized_keys
  sudo cp /home/ubuntu/.profile /home/lsfadmin
fi
cat /mnt/lsf/ssh/id_rsa.pub >> /home/lsfadmin/.ssh/authorized_keys
cp /mnt/lsf/ssh/id_rsa /home/lsfadmin/.ssh/id_rsa
echo "StrictHostKeyChecking no" >>  /home/lsfadmin/.ssh/config
chmod 600  /home/lsfadmin/.ssh/authorized_keys
chmod 700  /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh
echo "SSH key setup for lsfadmin user is completed" >> \$logfile
lsfadmin_home_dir="/home/lsfadmin"
echo "source /opt/ibm/lsf_worker/conf/profile.lsf" >> \$lsfadmin_home_dir/.bashrc
echo "source /opt/intel/oneapi/setvars.sh >> /dev/null" >> \$lsfadmin_home_dir/.bashrc
echo "Setting up LSF env variables for lasfadmin user is completed" >> \$logfile

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

# Update the entry  to LSF_HOSTS_FILE
sed -i "s/^$HostIP .*/$HostIP $HostName/g" /opt/ibm/lsf/conf/hosts
for hostname in $ManagementHostNames; do
  while ! grep "$hostname" "/opt/ibm/lsf/conf/hosts"; do
    echo "Waiting for $hostname to be added to LSF host file" >> \$logfile
    sleep 5
  done
done
cat /opt/ibm/lsf/conf/hosts >> /etc/hosts

# Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
#echo 'LSF_STARTUP_USERS="lsfadmin"' | sudo tee -a /etc/lsf1.sudoers
echo "LSF_STARTUP_PATH=\$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/" | sudo tee -a /etc/lsf.sudoers
sudo echo 'LSF_STARTUP_USERS="lsfadmin"' >> /etc/lsf.sudoers
chmod 600 /etc/lsf.sudoers
ls -l /etc/lsf.sudoers
sudo /opt/ibm/lsf/10.1/install/hostsetup --top="/opt/ibm/lsf_worker/" --setuid
echo "Added LSF administrators to start LSF daemons" >> \$logfile
cat /opt/ibm/lsf/conf/hosts >> /etc/hosts

# Setting up the LDAP configuration
if [ "\$enable_ldap" = "true" ]; then

    # Detect the operating system
    if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then

        # Detect RHEL version
        rhel_version=\$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print \$2}')

        if [ "\$rhel_version" == "8" ]; then
            echo "Detected RHEL 8. Proceeding with LDAP client configuration...." >> "\$logfile"

            # Allow Password authentication
            sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
            systemctl restart sshd

            # Configure LDAP authentication
            authconfig --enableldap --enableldapauth \
                        --ldapserver=ldap://\${ldap_server_ip} \
                        --ldapbasedn="dc=\${base_dn%%.*},dc=\${base_dn#*.}" \
                        --enablemkhomedir --update

            # Check the exit status of the authconfig command
            if [ \$? -eq 0 ]; then
                echo "LDAP Authentication enabled successfully." >> "\$logfile"
            else
                echo "Failed to enable LDAP and LDAP Authentication." >> "\$logfile"
                exit 1
            fi

            # Update LDAP Client configurations in nsswitch.conf
            sed -i -e 's/^passwd:.*\$/passwd: files ldap/' \
                -e 's/^shadow:.*\$/shadow: files ldap/' \
                -e 's/^group:.*\$/group: files ldap/' /etc/nsswitch.conf

            # Update PAM configuration files
            sed -i -e '/^auth/d' /etc/pam.d/password-auth
            sed -i -e '/^auth/d' /etc/pam.d/system-auth

            auth_line="\nauth        required      pam_env.so\n\
auth        sufficient    pam_unix.so nullok try_first_pass\n\
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success\n\
auth        sufficient    pam_ldap.so use_first_pass\n\
auth        required      pam_deny.so"

            echo -e "\$auth_line" | tee -a /etc/pam.d/password-auth /etc/pam.d/system-auth

            # Copy 'password-auth' settings to 'sshd'
            cat /etc/pam.d/password-auth > /etc/pam.d/sshd

            # Configure nslcd
            cat <<EOF > /etc/nslcd.conf
uid nslcd
gid ldap
uri ldap://\${ldap_server_ip}/
base dc=\${base_dn%%.*},dc=\${base_dn#*.}
EOF

            # Restart nslcd and nscd service
            systemctl restart nslcd
            systemctl restart nscd

            # Enable nslcd and nscd service
            systemctl enable nslcd
            systemctl enable nscd

            # Validate the LDAP configuration
            if ldapsearch -x -H ldap://\${ldap_server_ip}/ -b "dc=\${base_dn%%.*},dc=\${base_dn#*.}" > /dev/null; then
                echo "LDAP configuration completed successfully !!" >> "\$logfile"
            else
                echo "LDAP configuration failed !!" >> "\$logfile"
                exit 1
            fi

            # Make LSF commands available for every user.
            echo ". \${LSF_CONF}/profile.lsf" >> /etc/bashrc
            source /etc/bashrc
        else
            echo "This script is designed for RHEL 8. Detected RHEL version: \$rhel_version. Exiting." >> "\$logfile"
            exit 1
        fi

    elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then

        echo "Detected as Ubuntu. Proceeding with LDAP client configuration..." >> \$logfile

        # Update package repositories
        sudo apt update -y

        # Required LDAP client packages
        export UTILITYS="ldap-utils libpam-ldap libnss-ldap nscd nslcd"

        # Update SSH configuration to allow password authentication
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloudimg-settings.conf
        sudo systemctl restart ssh

        # Create preseed file for LDAP configuration
        cat > debconf-ldap-preseed.txt <<EOF
ldap-auth-config    ldap-auth-config/ldapns/ldap-server    string    \${ldap_server_ip}
ldap-auth-config    ldap-auth-config/ldapns/base-dn    string     dc=\${base_dn%%.*},dc=\${base_dn#*.}
ldap-auth-config    ldap-auth-config/ldapns/ldap_version    select    3
ldap-auth-config    ldap-auth-config/dbrootlogin    boolean    false
ldap-auth-config    ldap-auth-config/dblogin    boolean    false
nslcd   nslcd/ldap-uris string  \${ldap_server_ip}
nslcd   nslcd/ldap-base string  dc=\${base_dn%%.*},dc=\${base_dn#*.}
EOF

        # Check if the preseed file exists
        if [ -f debconf-ldap-preseed.txt ]; then

            # Apply preseed selections
            cat debconf-ldap-preseed.txt | debconf-set-selections

            # Install LDAP client packages
            sudo apt-get install -y \${UTILITYS}

            sleep 2

            # Add session configuration to create home directories
            sudo sed -i '\$ i\session required pam_mkhomedir.so skel=/etc/skel umask=0022\' /etc/pam.d/common-session

            # Update nsswitch.conf
            sudo sed -i 's/^passwd:.*\$/passwd: compat systemd ldap/' /etc/nsswitch.conf
            sudo sed -i 's/^group:.*\$/group: compat systemd ldap/' /etc/nsswitch.conf
            sudo sed -i 's/^shadow:.*\$/shadow: compat/' /etc/nsswitch.conf

            # Update common-password PAM configuration
            sudo sed -i 's/pam_ldap.so use_authtok/pam_ldap.so/' /etc/pam.d/common-password

            # Make LSF commands available for every user.
            echo ". \${LSF_CONF}/profile.lsf" >> /etc/bash.bashrc
            source /etc/bash.bashrc

            # Restart nslcd and nscd service
            systemctl restart nslcd
            systemctl restart nscd

            # Enable nslcd and nscd service
            systemctl enable nslcd
            systemctl enable nscd

            # Validate the LDAP client service status
            if sudo systemctl is-active --quiet nscd; then
                echo "LDAP client configuration completed successfully !!"
            else
                echo "LDAP client configuration failed. nscd service is not running."
                exit 1
            fi
        else
            echo -e "debconf-ldap-preseed.txt Not found. Skipping LDAP client configuration."
        fi
    else
        echo "This script is designed for Ubuntu 22, and installation is not supported. Exiting." >> "\$logfile"
    fi
fi

# Startup lsf daemons
lsf_daemons start &
sleep 5
lsf_daemons status >> \$logfile
echo "END \$(date '+%Y-%m-%d %H:%M:%S')" >> \$logfile
EOT

echo "source /opt/ibm/lsf/conf/profile.lsf" >> /home/lsfadmin/.bashrc
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc
source ~/.bashrc

# Setup ip-host mapping in LSF_HOSTS_FILE
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${cluster_prefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> $LSF_HOSTS_FILE
# Update the entry  to LSF_HOSTS_FILE
sed -i "s/^$HostIP .*/$HostIP $HostName/g" $LSF_HOSTS_FILE
for hostname in $ManagementHostNames; do
  while ! grep "$hostname" "$LSF_HOSTS_FILE"; do
    echo "Waiting for $hostname to be added to LSF host file" >> $logfile
    sleep 10
  done
done

if [ "$spectrum_scale" == false ]; then
  cat $LSF_HOSTS_FILE >> /etc/hosts
else
  echo "scale is enabled and this push is not needed"
fi

#update lsf client ip address to LSF_HOSTS_FILE
echo $login_ip_address   $login_hostname >> $LSF_HOSTS_FILE

# Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
cat <<EOT > "/etc/lsf.sudoers"
LSF_STARTUP_USERS="lsfadmin"
LSF_STARTUP_PATH=$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/
EOT
chmod 600 /etc/lsf.sudoers
ls -l /etc/lsf.sudoers
sudo /opt/ibm/lsf/10.1/install/hostsetup --top="/opt/ibm/lsf/" --setuid
echo "Added LSF administrators to start LSF daemons" >> $logfile

# Startup lsf daemons
lsf_daemons start &
sleep 5
lsf_daemons status >> $logfile

if [ "$spectrum_scale" == true ]; then
  echo "Entering sleep mode to update Network Manager"
  sleep 300
  # Create the Ansible playbook to update /etc/resolv.conf
  cat <<EOF > /root/update_resolv_conf.yml
---
- name: Backup, update, and protect resolv.conf
  hosts: localhost
  become: yes
  tasks:
    - name: Backup original /etc/resolv.conf
      copy:
        src: /etc/resolv.conf
        dest: /etc/resolv.conf.bkp
        remote_src: yes
        owner: root
        group: root
        mode: '0644'
    - name: Make /etc/resolv.conf editable
      command: chattr -i /etc/resolv.conf
    - name: Update /etc/resolv.conf with custom content
      lineinfile:
        path: /etc/resolv.conf
        state: present
        create: yes
        line: "{{ item }}"
      loop:
        - 'search ${dns_domain}'
    - name: Make /etc/resolv.conf immutable
      command: chattr +i /etc/resolv.conf
EOF

  # Run the playbook
  ansible-playbook /root/update_resolv_conf.yml

  echo "Exiting sleep mode after updating Network Manager"

else
  echo "spectrum_scale is false, skipping playbook creation and execution"
fi


# Application Center Installation
if [ "$enable_app_center" = true ]; then
    # if rpm -q lsf-appcenter -------------> For testing it now uncomment and use it. Remove this once new image is created.
    # then
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
        sed -i 's/NoVNCProxyHost=.*/NoVNCProxyHost=localhost/g' /opt/ibm/lsfsuite/ext/gui/conf/pmc.conf
        sudo rm -rf /opt/ibm/lsfsuite/ext/gui/3.0/bin/novnc.pem
        lsf_daemons restart &
        sleep 5
        lsf_daemons status >> $logfile
        lsadmin resrestart -f all; sleep 2; perfadmin start all; sleep 5; pmcadmin stop; sleep 160; pmcadmin start; sleep 5; pmcadmin list >> $logfile
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


# Setting up the LDAP configuration
if [ "$enable_ldap" = "true" ]; then

    # Detect RHEL version
    rhel_version=$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print $2}')

    if [ "$rhel_version" == "8" ]; then
        echo "Detected RHEL 8. Proceeding with LDAP client configuration...." >> "$logfile"

        # Allow Password authentication
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        systemctl restart sshd

        # Configure LDAP authentication
        authconfig --enableldap --enableldapauth \
                    --ldapserver=ldap://${ldap_server_ip} \
                    --ldapbasedn="dc=${base_dn%%.*},dc=${base_dn#*.}" \
                    --enablemkhomedir --update

        # Check the exit status of the authconfig command
        if [ $? -eq 0 ]; then
            echo "LDAP Authentication enabled successfully." >> "$logfile"
        else
            echo "Failed to enable LDAP and LDAP Authentication." >> "$logfile"
            exit 1
        fi

        # Update LDAP Client configurations in nsswitch.conf
        sed -i -e 's/^passwd:.*$/passwd: files ldap/' \
               -e 's/^shadow:.*$/shadow: files ldap/' \
               -e 's/^group:.*$/group: files ldap/' /etc/nsswitch.conf

        # Update PAM configuration files
        sed -i -e '/^auth/d' /etc/pam.d/password-auth
        sed -i -e '/^auth/d' /etc/pam.d/system-auth

        auth_line="\nauth        required      pam_env.so\n\
auth        sufficient    pam_unix.so nullok try_first_pass\n\
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success\n\
auth        sufficient    pam_ldap.so use_first_pass\n\
auth        required      pam_deny.so"

        echo -e "$auth_line" | tee -a /etc/pam.d/password-auth /etc/pam.d/system-auth

        # Copy 'password-auth' settings to 'sshd'
        cat /etc/pam.d/password-auth > /etc/pam.d/sshd

        # Configure nslcd
        cat <<EOF > /etc/nslcd.conf
uid nslcd
gid ldap
uri ldap://${ldap_server_ip}/
base dc=${base_dn%%.*},dc=${base_dn#*.}
EOF

        # Restart nslcd and nscd service
        systemctl restart nslcd
        systemctl restart nscd

        # Enable nslcd and nscd service
        systemctl enable nslcd
        systemctl enable nscd

        # Validate the LDAP configuration
        if ldapsearch -x -H ldap://${ldap_server_ip}/ -b "dc=${base_dn%%.*},dc=${base_dn#*.}" > /dev/null; then
            echo "LDAP configuration completed successfully !!" >> "$logfile"
        else
            echo "LDAP configuration failed !!" >> "$logfile"
            exit 1
        fi

        # Make LSF commands available for every user.
        echo ". ${LSF_CONF}/profile.lsf" >> /etc/bashrc
        source /etc/bashrc
    else
        echo "This script is designed for RHEL 8. Detected RHEL version: $rhel_version. Exiting." >> "$logfile"
        exit 1
    fi
fi

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile