#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#!/usr/bin/env bash

USER=ubuntu
BASE_DN="${ldap_basedns}"
LDAP_DIR="/opt"
LDAP_ADMIN_PASSWORD="${ldap_admin_password}"
LDAP_GROUP="${cluster_prefix}"
LDAP_USER="${ldap_user}"
LDAP_USER_PASSWORD="${ldap_user_password}"

if grep -E -q "CentOS|Red Hat" /etc/os-release
then
    USER=vpcuser
elif grep -q "Ubuntu" /etc/os-release
then
    USER=ubuntu
fi
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"$USER\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

#input parameters
ssh_public_key_content="${ssh_public_key_content}"
echo "${ssh_public_key_content}" >> home/$USER/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /home/$USER/.ssh/config

# Setup Network configuration
# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
    # Replace the MTU value in the Netplan configuration
    echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    echo "DOMAIN=\"${dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    # Change the MTU setting as 9000 at router level.
    gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
    echo "${rc_cidr_block} via $gateway_ip dev ${network_interface} metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
    systemctl restart NetworkManager
elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then
    net_int=$(basename /sys/class/net/en*)
    netplan_config="/etc/netplan/50-cloud-init.yaml"
    gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
    cidr_range=$(ip route show | grep "kernel" | awk '{print $1}' | head -n 1)
    usermod -s /bin/bash lsfadmin
    # Replace the MTU value in the Netplan configuration
    if ! grep -qE "^[[:space:]]*mtu: 9000" $netplan_config; then
        echo "MTU 9000 Packages entries not found"
        # Append the MTU configuration to the Netplan file
        sudo sed -i '/'$net_int':/a\            mtu: 9000' $netplan_config
        sudo sed -i '/dhcp4: true/a \            nameservers:\n              search: ['$dns_domain']' $netplan_config
        sudo sed -i '/'$net_int':/a\            routes:\n              - to: '$cidr_range'\n                via: '$gateway_ip'\n                metric: 100\n                mtu: 9000' $netplan_config
        sudo netplan apply
        echo "MTU set to 9000 on Netplan."
    else
        echo "MTU entry already exists in Netplan. Skipping."
    fi
fi

#Installing LDAP
apt-get update -y
export DEBIAN_FRONTEND='non-interactive'
echo -e "slapd slapd/root_password password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
echo -e "slapd slapd/root_password_again password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
apt-get install -y slapd ldap-utils

echo -e "slapd slapd/internal/adminpw password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
echo -e "slapd slapd/internal/generated_adminpw password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
echo -e "slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
echo -e "slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
echo -e "slapd slapd/domain string ${BASE_DN}" |debconf-set-selections
echo -e "slapd shared/organization string ${BASE_DN}" |debconf-set-selections
echo -e "slapd slapd/purge_database boolean false" |debconf-set-selections
echo -e "slapd slapd/move_old_database boolean true" |debconf-set-selections
echo -e "slapd slapd/no_configuration boolean false" |debconf-set-selections
dpkg-reconfigure slapd
echo "BASE   dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" >> /etc/ldap/ldap.conf
echo "URI    ldap://localhost" >> /etc/ldap/ldap.conf
systemctl restart slapd
systemctl enable slapd

#LDAP Operations

check_and_create_ldap_ou() {
    local ou_name="$1"
    local ldif_file="${LDAP_DIR}/ou${ou_name}.ldif"
    local search_result=""

    echo "dn: ou=${ou_name},dc=${BASE_DN%%.*},dc=${BASE_DN#*.}
objectClass: organizationalUnit
ou: ${ou_name}" > "${ldif_file}"

    ldapsearch -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -b "ou=${ou_name},dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" "objectClass=organizationalUnit" > /dev/null 2>&1
    search_result=$?

    [ ${search_result} -eq 32 ] && echo "${ou_name}OUNotFound" || echo "${ou_name}OUFound"
}

# LDAP | Server People OU Check and Create
ldap_people_ou_search=$(check_and_create_ldap_ou People)
[ "${ldap_people_ou_search}" == "PeopleOUNotFound" ] && ldapadd -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_DIR}/ouPeople.ldif"
[ "${ldap_people_ou_search}" == "PeopleOUFound" ] && echo "LDAP OU 'People' already exists. Skipping."

# LDAP | Server Groups OU Check and Create
ldap_groups_ou_search=$(check_and_create_ldap_ou Groups)
[ "${ldap_groups_ou_search}" == "GroupsOUNotFound" ] && ldapadd -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_DIR}/ouGroups.ldif"
[ "${ldap_groups_ou_search}" == "GroupsOUFound" ] && echo "LDAP OU 'Groups' already exists. Skipping."

# Creating LDAP Group on the LDAP Server

# LDAP | Group File
echo "dn: cn=${LDAP_GROUP},ou=Groups,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}
objectClass: posixGroup
cn: ${LDAP_GROUP}
gidNumber: 5000" > "${LDAP_DIR}/group.ldif"

# LDAP Group Search
ldap_group_dn="cn=${LDAP_GROUP},ou=Groups,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}"
ldap_group_search_result=$(ldapsearch -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -b "${ldap_group_dn}" "(cn=${LDAP_GROUP})" 2>&1)

# Check if LDAP Group exists
if echo "${ldap_group_search_result}" | grep -q "dn: ${ldap_group_dn},"
then
    echo "LDAP Group '${LDAP_GROUP}' already exists. Skipping."
    ldap_group_search="GroupFound"
else
    echo "LDAP Group '${LDAP_GROUP}' not found. Creating..."
    ldapadd -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_DIR}/group.ldif"
    ldap_group_search="GroupNotFound"
fi

# Creating LDAP User on the LDAP Server

# Generate LDAP Password Hash
ldap_hashed_password=$(slappasswd -s "${LDAP_USER_PASSWORD}")

# LDAP | User File
echo "dn: uid=${LDAP_USER},ou=People,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: ${LDAP_USER}
sn: ${LDAP_USER}
givenName: ${LDAP_USER}
cn: ${LDAP_USER}
displayName: ${LDAP_USER}
uidNumber: 10000
gidNumber: 5000
userPassword: ${ldap_hashed_password}
gecos: ${LDAP_USER}
loginShell: /bin/bash
homeDirectory: /home/${LDAP_USER}" > "${LDAP_DIR}/users.ldif"

# LDAP User Search
ldap_user_dn="uid=${LDAP_USER},ou=People,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}"
ldap_user_search_result=$(ldapsearch -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -b "${ldap_user_dn}" uid cn 2>&1)

# Check if LDAP User exists
if echo "${ldap_user_search_result}" | grep -q "dn: ${ldap_user_dn},"
then
    echo "LDAP User '${LDAP_USER}' already exists. Skipping."
    ldap_user_search="UserFound"
else
    echo "LDAP User '${LDAP_USER}' not found. Creating..."
    ldapadd -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_DIR}/users.ldif"
    ldap_user_search="UserNotFound"
fi