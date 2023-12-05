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
rc_cidr_block="${rc_cidr_block}"
management_host_ips="${management_host_ips}"
storage_ips="${storage_ips}"
cluster_name="${cluster_name}"
hyperthreading="${hyperthreading}"
temp_public_key="${temp_public_key}"
scale_mount_point="${scale_mount_point}"
spectrum_scale="${spectrum_scale}"