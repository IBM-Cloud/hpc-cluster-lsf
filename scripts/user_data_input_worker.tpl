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
cluster_name="${cluster_name}"
hyperthreading="${hyperthreading}"
temp_public_key="${temp_public_key}"
scale_mount_point="${scale_mount_point}"
spectrum_scale="${spectrum_scale}"
mount_path="${mount_path}"
custom_file_shares="${custom_file_shares}"
custom_mount_paths="${custom_mount_paths}"
management_node_count="${management_node_count}"
cluster_prefix="${cluster_prefix}"
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
ldap_basedns="${ldap_basedns}"
network_interface="${network_interface}"
dns_domain="${dns_domain}"