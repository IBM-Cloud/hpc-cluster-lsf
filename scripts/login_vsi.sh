#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#variables

logfile="/tmp/user_data.log"

LSF_TOP="/opt/ibm/lsf"
LSF_CONF=$LSF_TOP/conf
LSF_HOSTS_FILE="/etc/hosts"
nfs_server_with_mount_path=${mount_path}

# Setup logs for user data
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Disallow root login
#sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"lsfadmin or vpcuser\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# echo "DOMAIN=\"$dns_domain\"" >> "/etc/sysconfig/network-scripts/ifcfg-eth0"
#echo "DOMAIN=\"$dns_domain\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
# Setup lsfadmin user
# Updates the lsfadmin user as never expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
# Setup ssh
lsfadmin_home_dir="/home/lsfadmin"
lsfadmin_ssh_dir="${lsfadmin_home_dir}/.ssh"
mkdir -p ${lsfadmin_ssh_dir}

# Change for RHEL / Ubuntu compute image.
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
  cp /home/vpcuser/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then
  cp /home/ubuntu/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
  sudo cp /home/ubuntu/.profile "{$lsfadmin_home_dir}"
else
  echo "Provided OS distribution not match, provide either RHEL or Ubuntu" >> $logfile
fi

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

# Setup LSF
echo "Setting LSF share." >> $logfile
# Setup file share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >> $logfile
  nfs_client_mount_path="/mnt/lsf"
  rm -rf "${nfs_client_mount_path}"
  rm -rf /opt/ibm/lsf/conf/
  rm -rf /opt/ibm/lsf/work/
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
  for dir in conf work; do
    mv "/opt/ibm/lsf/$dir" "${nfs_client_mount_path}"
    ln -fs "${nfs_client_mount_path}/$dir" "/opt/ibm/lsf"
    chown -R lsfadmin:root "/opt/ibm/lsf"
  done
else
  echo "No mount point value found, exiting!" >> $logfile
  exit 1
fi
echo "Setting LSF share is completed." >> $logfile

echo "source ${LSF_CONF}/profile.lsf" >> "${lsfadmin_home_dir}"/.bashrc
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc
echo "profile setup copy complete" >> $logfile



# Check if the SSH key exists
ssh_key_path="${nfs_client_mount_path}/ssh/id_rsa"
while [ ! -f "$ssh_key_path" ]; do
    echo "Waiting for SSH key to be generated... by management node in ssh_key_path"
    sleep 5
done
echo "SSH key has been generated."

# Passwordless SSH authentication
cp "${nfs_client_mount_path}/ssh/id_rsa" /root/.ssh/id_rsa
cp "${nfs_client_mount_path}/ssh/id_rsa" /home/lsfadmin/.ssh/id_rsa
cat "${nfs_client_mount_path}/ssh/id_rsa.pub" >> /root/.ssh/authorized_keys
cp "${nfs_client_mount_path}/ssh/authorized_keys" /home/lsfadmin/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /root/.ssh/config
echo "StrictHostKeyChecking no" >> /home/lsfadmin/.ssh/config
chmod 600 /home/lsfadmin/.ssh/id_rsa
chmod 600 /home/lsfadmin/.ssh/authorized_keys
chmod 700 /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh
echo "cluster ssh key has been added to root user" >> $logfile

# Pause execution for 30 seconds
sleep 30

# Display the contents of /etc/resolv.conf before changes
echo "Contents of /etc/resolv.conf before changes:"
cat /etc/resolv.conf

# Restart the NetworkManager service
sudo systemctl restart NetworkManager

# Toggle networking off and on using nmcli
sudo nmcli networking off
sudo nmcli networking on

# Display the updated contents of /etc/resolv.conf
echo "Contents of /etc/resolv.conf after changes:"
cat /etc/resolv.conf
#python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${cluster_prefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> "$LSF_HOSTS_FILE"
#cat /mnt/lsf/conf/hosts >> $LSF_HOSTS_FILE

#Hostname resolution - login node to management nodes
sleep 300
ls /mnt/lsf
ls -ltr /mnt/lsf
cp /mnt/lsf/conf/hosts /etc/hosts

# Ldap Configuration:
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
ldap_logfile=/tmp/ldap_integration.log

# Setting up the LDAP configuration
if [ "$enable_ldap" = "true" ]; then

    # Detect the operating system
    if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then

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
ldap-auth-config    ldap-auth-config/ldapns/ldap-server    string    ${ldap_server_ip}
ldap-auth-config    ldap-auth-config/ldapns/base-dn    string     dc=${base_dn%%.*},dc=${base_dn#*.}
ldap-auth-config    ldap-auth-config/ldapns/ldap_version    select    3
ldap-auth-config    ldap-auth-config/dbrootlogin    boolean    false
ldap-auth-config    ldap-auth-config/dblogin    boolean    false
nslcd   nslcd/ldap-uris string  ${ldap_server_ip}
nslcd   nslcd/ldap-base string  dc=${base_dn%%.*},dc=${base_dn#*.}
EOF

        # Check if the preseed file exists
        if [ -f debconf-ldap-preseed.txt ]; then

            # Apply preseed selections
            cat debconf-ldap-preseed.txt | debconf-set-selections

            # Install LDAP client packages
            sudo apt-get install -y ${UTILITYS}

            sleep 2

            # Add session configuration to create home directories
            sudo sed -i '$ i\session required pam_mkhomedir.so skel=/etc/skel umask=0022\' /etc/pam.d/common-session

            # Update nsswitch.conf
            sudo sed -i 's/^passwd:.*$/passwd: compat systemd ldap/' /etc/nsswitch.conf
            sudo sed -i 's/^group:.*$/group: compat systemd ldap/' /etc/nsswitch.conf
            sudo sed -i 's/^shadow:.*$/shadow: compat/' /etc/nsswitch.conf

            # Update common-password PAM configuration
            sudo sed -i 's/pam_ldap.so use_authtok/pam_ldap.so/' /etc/pam.d/common-password

            # Make LSF commands available for every user.
            echo ". ${LSF_CONF}/profile.lsf" >> /etc/bash.bashrc
            source /etc/bash.bashrc
            
            # Restart and enable the service
            systemctl restart nscd
            systemctl restart nslcd

            # Enable nslcd and nscd service
            systemctl enable nslcd
            systemctl enable nscd

            sleep 5

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
        echo "This script is designed for Ubuntu 22 and installation is not supporting. Exiting." >> \$logfile
    fi
fi