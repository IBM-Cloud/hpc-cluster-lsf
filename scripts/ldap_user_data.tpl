#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile=/tmp/user_data.log
echo "Export LDAP user data (variable values)"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

%EXPORT_USER_DATA%
#input parameters
ldap_basedns="${ldap_basedns}"
ldap_admin_password="${ldap_admin_password}"
cluster_prefix="${cluster_prefix}"
ldap_user="${ldap_user}"
ldap_user_password="${ldap_user_password}"
network_interface=${network_interface}
dns_domain="${dns_domain}"

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile