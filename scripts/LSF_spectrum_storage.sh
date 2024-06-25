###################################################
# Copyright (C) IBM Corp. 2022 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#
# Source LSF enviornment at the VM host
#
logfile="/tmp/user_data.log"
nfs_server_with_mount_path=${mount_path}
env

#Update management_host name based on internal IP address
#vmPrefix="icgen2host"
cluster_prefix="${cluster_prefix}"

#nfs_mount_dir="data"
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
#hostName=${cluster_prefix}-${privateIP//./-}
HostIP=$(hostname -I | awk '{print $1}')
HostName=$(hostname)
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
ManagementHostName="${HostName}"
ManagementHostNames=""
for (( i=1; i<=management_node_count; i++ ))
do
  ManagementHostNames+=" ${cluster_prefix}-spectrum-scale-$i"
done
echo "Nodes: $ManagementHostNames" >> $logfile
networkIPrange=$(echo ${privateIP}|cut -f1-3 -d .)
hostnamectl set-hostname ${hostName}

# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-eth0"
echo "DOMAIN=\"${dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
systemctl status NetworkManager
systemctl restart NetworkManager

# Setup LSF
echo "Setting LSF share." >> $logfile
# Setup file share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >> $logfile
  # Create a data directory for sharing HPC workload data
  #mkdir -p "${LSF_TOP}/data"
  mkdir -p "/opt/ibm/lsf/das_staging_area"
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
    mv "/opt/ibm/lsf/$dir" "${nfs_client_mount_path}"
    ln -fs "${nfs_client_mount_path}/$dir" "/opt/ibm/lsf"
    chown -R lsfadmin:root "/opt/ibm/lsf"
  done
else
  echo "No mount point value found, exiting!" >> $logfile
  exit 1
fi
echo "Setting LSF share is completed." >> $logfile

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

mkdir -p /root/.ssh
cp /mnt/lsf/ssh/id_rsa /root/.ssh/id_rsa
cat /mnt/lsf/ssh/id_rsa.pub >> /root/.ssh/authorized_keys
echo "${temp_public_key}" >> /root/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /root/.ssh/config
chmod 600 /root/.ssh/id_rsa
chmod 600 /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chown -R root:root /root/.ssh
sleep 5

echo "entering sleep mode to update network manager"
sleep 300
# Import the EPEL GPG key and enable EPEL repository
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
#echo "exiting sleep mode after update network manager"

# Setting up the LDAP configuration
if [ "$enable_ldap" = "true" ]; then

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
fi