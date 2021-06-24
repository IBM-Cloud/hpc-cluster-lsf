###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

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
IBM_CLOUD_CREDENTIALS_FILE=$LSF_IBM_GEN2/credentials
IBM_CLOUD_TEMPLATE_FILE=$LSF_IBM_GEN2/conf/ibmcloudgen2_templates.json
IBM_CLOUD_USER_DATA_FILE=$LSF_IBM_GEN2/user_data.sh
LSF_CLUSTER_FILE=$LSF_CONF/lsf.cluster.BigComputeCluster
LBATCH_DIR=$LSF_CONF/lsbatch/BigComputeCluster/configdir
DATA_DIR=/data
. $LSF_TOP/conf/profile.lsf

env 

#Update LSF and LS entitlement
echo $LS_Entitlement >> $LS_ENTITLEMENT_FILE
echo $LSF_Entitlement >> $LSF_ENTITLEMENT_FILE

#Update Master host name based on internal IP address
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
masterHostName=ibm-gen2host-${privateIP//./-}
masterHostNames=(`echo "${master_ips//./-}" | sed -e 's/^/ibm-gen2host-/g' | sed -e 's/ / ibm-gen2host-/g'`)
hostnamectl set-hostname ${masterHostName}
ln -s $LSF_CONF/profile.lsf /opt/ibm/profile.lsf
echo "source /opt/ibm/profile.lsf" >> /root/.bashrc

# NOTE: On ibm gen2, the default DNS server do not have reverse hostname/IP resolution.
# 1) put the master server hostname and ip into lsf hosts.
# 2) put all possible VMs' hostname and ip into lsf hosts.
python3 -c "import ipaddress; print('\n'.join([str(ip) + '    ibm-gen2host-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> $LSF_HOSTS_FILE
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ibm-gen2host-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts

sed -i 's#for ((i=1; i<=254; i++))#for ((i=1; i<=0; i++))#g' $IBM_CLOUD_USER_DATA_FILE

#update the lsf master hostname
masterHostNamesStr="${masterHostNames[@]}" #cannot directly pass array because of space, which confuses the sed arguments
sed -i "s/\(.*\)=\"*lsfservers\"*/\1=\"${masterHostNamesStr}\"/g" $LSF_CONF_FILE
sed -i "s/\(.*\)=\"*lsfservers\"*/\1=${masterHostNamesStr}/g" $LBATCH_DIR/lsb.queues
sed -i "s/^\(MQTT_BROKER_HOST=.*\)/#\1/g" $LSF_CONF_FILE
sed -i "s/^\(MQTT_BROKER_PORT=.*\)/#\1/g" $LSF_CONF_FILE
sed -i "s/^\(LSF_LIC_SCHED_HOSTS=.*\)/#\1/g" $LSF_CONF_FILE
sed -i "s/ServerHostPlaceHolder/${masterHostNamesStr}/g" $IBM_CLOUD_USER_DATA_FILE
for workerIP in ${worker_ips}; do
    hostName=ibm-gen2host-${workerIP//./-}
    sed -i "/^End\s\+Host$/i ${hostName}   !   !   1   (linux)" $LSF_CLUSTER_FILE
done
for masterIP in ${master_ips}; do
    hostName=ibm-gen2host-${masterIP//./-}
    if [ "${privateIP}" != "${masterIP}" ]; then
        sed -i "/^End\s\+Host$/i ${hostName}   !   !   1   (mg)" $LSF_CLUSTER_FILE
        sed -i "/^End\s\+Host$/i ${hostName} 0    ()      ()    ()     ()     ()            (Y)" $LBATCH_DIR/lsb.hosts
    else
        sed -i "s/lsfservers/${hostName}/g" $LSF_CLUSTER_FILE
        sed -i "s/lsfservers/${masterHostNames[0]}/g" $LBATCH_DIR/lsb.hosts
    fi
done
sed -i "s/master_hosts.*/master_hosts (${masterHostNamesStr} )/g" $LBATCH_DIR/lsb.hosts

#update IBM gen2 Credentials API keys
sed -i "s/VPC_APIKEY=/VPC_APIKEY=$VPC_APIKEY_VALUE/" $IBM_CLOUD_CREDENTIALS_FILE
sed -i "s/RESOURCE_RECORDS_APIKEY=/RESOURCE_RECORDS_APIKEY=$RESOURCE_RECORDS_APIKEY_VALUE/" $IBM_CLOUD_CREDENTIALS_FILE

#Update IBM gen2 template
cat <<EOF > $IBM_CLOUD_TEMPLATE_FILE
{
        "templates": [
                {
                        "templateId": "Template-VM-1",
                        "maxNumber": ${rc_maxNum},
                        "attributes": {
                                "type": ["String", "X86_64"],
                                "ncores": ["Numeric", "1"],
                                "ncpus": ["Numeric", "${rc_ncores}"],
                                "mem": ["Numeric", "${rc_memInMB}"],
                                "ibmgen2host": ["Boolean", "1"]
                        },
                        "imageId": "${imageID}",
                        "subnetId": "${subnetID}",
                        "vpcId": "${vpcID}",
                        "vmType": "${rc_profile}",
                        "securityGroupIds": ["${securityGroupID}"],
                        "sshkey_id": "${sshkey_ID}",
                        "region": "${regionName}",
                        "zone": "${zoneName}"
                }
        ]
}
EOF

# https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-nfs-mount-settings.html
# option noresvport is not available.
cat << EOF >> /tmp/client.sh
python3 -c "import ipaddress; print('\n'.join([str(ip) + '    ibm-gen2host-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /opt/ibm/lsf_worker/conf/hosts
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ibm-gen2host-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts
yum install -y nfs-utils
mkdir $DATA_DIR
echo "${storage_ips[0]}:$DATA_DIR      $DATA_DIR      nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
echo "${storage_ips[0]}:/home/lsfadmin /home/lsfadmin nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
mount $DATA_DIR
mount /home/lsfadmin
EOF

# insert our custom user script to the workers' user data
sed -i "/# Add your customization script here/r /tmp/client.sh" $IBM_CLOUD_USER_DATA_FILE

storage_ips=(${storage_ips})
yum install -y nfs-utils
mkdir -p $DATA_DIR
echo "${storage_ips[0]}:$DATA_DIR      $DATA_DIR      nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
echo "${storage_ips[0]}:/home/lsfadmin /home/lsfadmin nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
mount $DATA_DIR
mount /home/lsfadmin

cat $LSF_HOSTS_FILE
cat $LSF_ENTITLEMENT_FILE
cat $LS_ENTITLEMENT_FILE
cat $IBM_CLOUD_CREDENTIALS_FILE
cat $IBM_CLOUD_TEMPLATE_FILE
cat $IBM_CLOUD_USER_DATA_FILE

# 2. start master daemons
sleep 5
lsf_daemons start

lsf_daemons status >> $logfile

echo END `date '+%Y-%m-%d %H:%M:%S'`
