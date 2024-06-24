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
HostIP=$(hostname -I | awk '{print $1}')
HostName=$(hostname)
ManagementHostNames=""
for (( i=1; i<=management_node_count; i++ ))
do
  ManagementHostNames+=" ${cluster_prefix}-mgmt-$i"
done
echo $ManagementHostNames >> $logfile

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf"
LSF_CONF="$LSF_TOP/conf"
LSF_HOSTS_FILE="$LSF_CONF/hosts"
LSF_TOP_VERSION="$LSF_TOP/10.1"
. $LSF_TOP/conf/profile.lsf
env >> $logfile

# Setup Network configurations
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
echo "DOMAIN=\"${dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
echo "${rc_cidr_block} via $gateway_ip dev eth0 metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
systemctl restart NetworkManager

# Setup LSF
echo "Setting LSF configuration is completed." >> $logfile
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

# Passwordless SSH authentication
sudo chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
cp "${nfs_client_mount_path}/ssh/id_rsa" /root/.ssh/id_rsa
cat "${nfs_client_mount_path}/ssh/id_rsa.pub" >> /root/.ssh/authorized_keys
mkdir -p /home/lsfadmin/.ssh
cp "${nfs_client_mount_path}/ssh/id_rsa" /home/lsfadmin/.ssh/id_rsa
cp "${nfs_client_mount_path}/ssh/authorized_keys" /home/lsfadmin/.ssh/authorized_keys
echo "${temp_public_key}" >> /root/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /root/.ssh/config
echo "StrictHostKeyChecking no" >> /home/lsfadmin/.ssh/config
chmod 600 /home/lsfadmin/.ssh/id_rsa
chmod 600 /home/lsfadmin/.ssh/authorized_keys
chmod 700 /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh

# Update LSF Tunables
LSF_TUNABLES="/etc/sysctl.conf"
echo 1 > /proc/sys/vm/overcommit_memory
echo 'vm.overcommit_memory=1' > $LSF_TUNABLES
echo 'net.core.rmem_max=26214400' >> $LSF_TUNABLES
echo 'net.core.rmem_default=26214400' >> $LSF_TUNABLES
echo 'net.core.wmem_max=26214400' >> $LSF_TUNABLES
echo 'net.core.wmem_default=26214400' >> $LSF_TUNABLES
echo 'net.ipv4.tcp_fin_timeout = 5' >> $LSF_TUNABLES
echo 'net.core.somaxconn = 8000' >> $LSF_TUNABLES
sudo sysctl -p $LSF_TUNABLES

# Defining ncpus based on hyper-threading
if [ ! "$hyperthreading" == true ]; then
  for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo 0 > /sys/devices/system/cpu/cpu"$vcpu"/online
  done
fi

echo "source ${LSF_CONF}/profile.lsf" >> /home/lsfadmin/.bashrc
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc
source ~/.bashrc

#Setup password less SSH
while [ ! -f  "$LSF_HOSTS_FILE" ]; do
  echo "Waiting for cluster configuration created by management node to be shared." >> $logfile
  sleep 5s
done

# Update the entry  to LSF_HOSTS_FILE
sed -i "s/^$HostIP .*/$HostIP $HostName/g" $LSF_HOSTS_FILE
for hostname in $ManagementHostNames; do
  while ! grep "$hostname" "$LSF_HOSTS_FILE"; do
    echo "Waiting for $hostname to be added to LSF host file" >> $logfile
    sleep 5
  done
done

if [ "$spectrum_scale" == false ]; then
  cat $LSF_HOSTS_FILE >> /etc/hosts
else
  echo "scale is enabled and this push is not needed"
fi


# Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
cat <<EOT > "/etc/lsf.sudoers"
LSF_STARTUP_USERS="lsfadmin"
LSF_STARTUP_PATH=$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/
EOT
chmod 600 /etc/lsf.sudoers
ls -l /etc/lsf.sudoers
sudo /opt/ibm/lsf/10.1/install/hostsetup --top="/opt/ibm/lsf/" --setuid
echo "Added LSF administrators to start LSF daemons" >> $logfile

# Startup lsf daemons
lsf_daemons start &
sleep 5
lsf_daemons status >> "$logfile"

# TODO: Understand how lsf should work after reboot, need better cron job
(crontab -l 2>/dev/null; echo "@reboot sleep 30 && source ~/.bashrc && lsf_daemons start && lsf_daemons status") | crontab -

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

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile