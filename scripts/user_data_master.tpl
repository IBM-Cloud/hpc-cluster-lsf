#!/bin/sh

###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile=/tmp/user_data.log
echo START `date '+%Y-%m-%d %H:%M:%S'` >> $logfile

#
# Export user data, which is defined with the "UserData" attribute
# in the template
#
%EXPORT_USER_DATA%

#input parameters
LS_Entitlement=${ls_entitlement}
LSF_Entitlement=${lsf_entitlement}
VPC_APIKEY_VALUE=${vpc_apikey_value}
RESOURCE_RECORDS_APIKEY_VALUE=${resource_records_apikey_value}
imageID=${image_id}
subnetID=${subnet_id}
vpcID=${vpc_id}
securityGroupID=${security_group_id}
sshkey_ID=${sshkey_id}
regionName=${region_name}
zoneName=${zone_name}

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
. $LSF_TOP/conf/profile.lsf

env >> $logfile

#Update LSF and LS entitlement
echo $LS_Entitlement >> $LS_ENTITLEMENT_FILE
echo $LSF_Entitlement >> $LSF_ENTITLEMENT_FILE

#Update Master host name based on internal IP address
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
masterHostName=ibm-gen2host-${privateIP//./-}
networkIPrange=$(echo ${privateIP}|cut -f1-3 -d .)
host_prefix=$(echo ${masterHostName}|cut -f1-5 -d -)
hostnamectl set-hostname ${masterHostName}

# NOTE: On ibm gen2, the default DNS server do not have reverse hostname/IP resolution.
# 1) put the master server hostname and ip into lsf hosts.
# 2) put all possible VMs' hostname and ip into lsf hosts.
for ((i=1; i<=254; i++))
do
    echo "${networkIPrange}.${i}   ${host_prefix}-${i}" >> $LSF_HOSTS_FILE
done

#update the lsf master hostname
sed -i "s/lsfservers/servershosts/" $IBM_CLOUD_USER_DATA_FILE
grep -rli 'lsfservers' ${LSF_CONF}/*|xargs sed -i "s/lsfservers/${masterHostName}/g"
sed -i "s/ServerHostPlaceHolder/${masterHostName}/" $IBM_CLOUD_USER_DATA_FILE
sed -i "s/servershosts/lsfservers/" $IBM_CLOUD_USER_DATA_FILE

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

cat $LSF_HOSTS_FILE >> $logfile
cat $LSF_ENTITLEMENT_FILE >> $logfile
cat $LS_ENTITLEMENT_FILE >> $logfile
cat $IBM_CLOUD_CREDENTIALS_FILE >> $logfile
cat $IBM_CLOUD_TEMPLATE_FILE >> $logfile
cat $IBM_CLOUD_USER_DATA_FILE >> $logfile

sleep 5
lsf_daemons start &

lsf_daemons status >> $logfile
echo END `date '+%Y-%m-%d %H:%M:%S'` >> $logfile