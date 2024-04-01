#!/usr/bin/bash
###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile=/tmp/user_data.log
echo "Export user data (variable values)"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

%EXPORT_USER_DATA%
#input parameters
network_interface="${network_interface}"
mount_path="${mount_path}"
cluster_prefix="${cluster_prefix}"
rc_cidr_block="${rc_cidr_block}"
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
ldap_basedns="${ldap_basedns}"
dns_domain="${dns_domain}"
echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile