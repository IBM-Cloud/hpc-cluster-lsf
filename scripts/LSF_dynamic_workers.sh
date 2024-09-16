#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile="/tmp/user_data.log"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"

# Local variable declaration
nfs_server_with_mount_path=${mount_path}
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
cluster_name=${cluster_name}
HostIP=$(hostname -I | awk '{print $1}')
HostName=$(hostname)
ManagementHostNames=""
for (( i=1; i<=management_node_count; i++ ))
do
  ManagementHostNames+=" ${cluster_prefix}-mgmt-$i"
done

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf_worker"
LSF_TOP_VERSION=10.1
LSF_CONF="$LSF_TOP/conf"
LSF_CONF_FILE="$LSF_CONF/lsf.conf"
LSF_HOSTS_FILE="$LSF_CONF/hosts"
. "$LSF_CONF/profile.lsf"
echo "Logging env variables" >> "$logfile"
env >> "$logfile"

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

echo "Setting LSF share" >> $logfile
# Setup file share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >> $logfile
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
    rm -rf "/opt/ibm/lsf/$dir"
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

# Setup ssh

lsfadmin_home_dir="/home/lsfadmin"
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
cp /mnt/lsf/ssh/id_rsa /root/.ssh/id_rsa
cat /mnt/lsf/ssh/id_rsa.pub >> /root/.ssh/authorized_keys
echo "${temp_public_key}" >> /root/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >>  /home/lsfadmin/.ssh/config
chmod 600  /home/lsfadmin/.ssh/authorized_keys
chmod 700  /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh
echo "SSH key setup for lsfadmin user is completed" >> $logfile
echo "source ${LSF_CONF}/profile.lsf" >> $lsfadmin_home_dir/.bashrc
echo "source /opt/intel/oneapi/setvars.sh >> /dev/null" >> $lsfadmin_home_dir/.bashrc
echo "Setting up LSF env variables for lasfadmin user is completed" >> $logfile

# Update LSF Tunables
LSF_TUNABLES="/etc/sysctl.conf"
echo "1" > /proc/sys/vm/overcommit_memory
echo 'vm.overcommit_memory=1' > "$LSF_TUNABLES"
echo 'net.core.rmem_max=26214400' >> "$LSF_TUNABLES"
echo 'net.core.rmem_default=26214400' >> "$LSF_TUNABLES"
echo 'net.core.wmem_max=26214400' >> "$LSF_TUNABLES"
echo 'net.core.wmem_default=26214400' >> "$LSF_TUNABLES"
echo 'net.ipv4.tcp_fin_timeout = 5' >> "$LSF_TUNABLES"
echo 'net.core.somaxconn = 8000' >> "$LSF_TUNABLES"
sysctl -p "$LSF_TUNABLES"

# Defining ncpus based on hyper-threading
echo "$hyperthreading"
if [ "$hyperthreading" == true ]; then
  ego_define_ncpus="threads"
else
  ego_define_ncpus="cores"
  cat << 'EOT' > /root/lsf_hyperthreading
#!/bin/sh
for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo "0" > "/sys/devices/system/cpu/cpu"$vcpu"/online"
done
EOT
  chmod 755 /root/lsf_hyperthreading
  command="/root/lsf_hyperthreading"
  sh $command && (crontab -l 2>/dev/null; echo "@reboot $command") | crontab -
fi
echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >> "$LSF_CONF_FILE"

# Update lsf configuration
echo 'LSB_MC_DISABLE_HOST_LOOKUP=Y' >> "$LSF_CONF_FILE"
sed -i "s/LSF_LOCAL_RESOURCES/#LSF_LOCAL_RESOURCES/"  "$LSF_CONF_FILE"
echo "LSF_RSH=\"ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'\"" >> "$LSF_CONF_FILE"
sed -i "s/LSF_SERVER_HOSTS=.*/LSF_SERVER_HOSTS=\"$ManagementHostNames\"/g" "$LSF_CONF_FILE"

cat << EOF > /etc/profile.d/lsf.sh
ls /opt/ibm/lsf_worker/conf/lsf.conf > /dev/null 2> /dev/null < /dev/null &
#usleep 10000
PID=\$!
if kill -0 \$PID 2> /dev/null; then
  # lsf.conf is not accessible 
  kill -KILL \$PID 2> /dev/null > /dev/null
  wait \$PID
else
  source /opt/ibm/lsf_worker/conf/profile.lsf
fi
PATHs=\`echo "\$PATH" | sed -e 's/:/\n/g'\`
for path in /usr/local/bin /usr/bin /usr/local/sbin /usr/sbin; do
  PATHs=\`echo "\$PATHs" | grep -v \$path\`
done
export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:\`echo "\$PATHs" | paste -s -d :\`
EOF

# Update the entry  to LSF_HOSTS_FILE
sed -i "s/^$HostIP .*/$HostIP $HostName/g" /opt/ibm/lsf/conf/hosts
for hostname in $ManagementHostNames; do
  while ! grep "$hostname" "/opt/ibm/lsf/conf/hosts"; do
    echo "Waiting for $hostname to be added to LSF host file" >> $logfile
    sleep 5
  done
done

if [ "$spectrum_scale" == false ]; then
  cat /opt/ibm/lsf/conf/hosts >> /etc/hosts
else
  echo "scale is enabled and this push is not needed"
fi

systemctl stop firewalld
systemctl status firewalld

# Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
# Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
echo 'LSF_STARTUP_USERS="lsfadmin"' | sudo tee -a /etc/lsf1.sudoers
echo "LSF_STARTUP_PATH=$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/" | sudo tee -a /etc/lsf.sudoers
chmod 600 /etc/lsf.sudoers
ls -l /etc/lsf.sudoers

# Change LSF_CONF= value in lsf_daemons
cd /opt/ibm/lsf_worker/10.1/linux3.10-glibc2.17-x86_64/etc/
sed -i "s|/opt/ibm/lsf/|/opt/ibm/lsf_worker/|g" lsf_daemons
cd -

sudo /opt/ibm/lsf/10.1/install/hostsetup --top="${LSF_TOP}" --setuid    ### WARNING: LSF_TOP may be unset here
echo "Added LSF administrators to start LSF daemons" >> $logfile

# Install LSF as a service and start up
/opt/ibm/lsf_worker/10.1/install/hostsetup --top="/opt/ibm/lsf_worker" --boot="y" --start="y" --dynamic 2>&1 >> $logfile
cat /opt/ibm/lsf/conf/hosts >> /etc/hosts


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

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"