#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile=/tmp/user_data.log
echo START `date '+%Y-%m-%d %H:%M:%S'`

#
# Export user data, which is defined with the "UserData" attribute
# in the template
#
%EXPORT_USER_DATA%

#input parameters
LS_Entitlement="${ls_entitlement}"
LSF_Entitlement="${lsf_entitlement}"
VPC_APIKEY_VALUE="${vpc_apikey_value}"
RESOURCE_RECORDS_APIKEY_VALUE="${vpc_apikey_value}"
imageID="${image_id}"
subnetID="${subnet_id}"
vpcID="${vpc_id}"
securityGroupID="${security_group_id}"
sshkey_ID="${sshkey_id}"
regionName="${region_name}"
zoneName="${zone_name}"
# the CIDR block for dyanmic hosts
rc_cidr_block="${rc_cidr_block}"
# the instance profile for dynamic hosts
rc_profile="${rc_profile}"
# number of cores for the instance profile
rc_ncores=${rc_ncores}
rc_ncpus=${rc_ncpus}
# memory size in MB for the instance profile
rc_memInMB=${rc_memInMB}
# the maximum allowed dynamic hosts created by RC
rc_maxNum=${rc_maxNum}
rc_rg=${rc_rg}
controller_ips="${controller_ips}"
storage_ips="${storage_ips}"
cluster_name="HPCCluster"
hyperthreading="${hyperthreading}"
temp_public_key="${temp_public_key}"
scale_mount_point = "${scale_mount_point}"
spectrum_scale="${spectrum_scale}"
