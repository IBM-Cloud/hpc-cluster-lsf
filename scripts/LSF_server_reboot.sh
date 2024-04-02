###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

### generate a script in /root which would be executed right after reboot through cronjobs
LSF_TOP=/opt/ibm/<LSF_MANAGEMENT_HOST_OR_WORKER>
LSF_HOSTS_FILE=$LSF_TOP/conf/hosts

cat > /root/.lsfstartup.sh  <<EOF
#!/usr/bin/bash

is_dir_mounted=\$( cat /etc/mtab | grep  -w "/mnt/lsf" | awk '{print \$3}' )
enable_app_center=${enable_app_center}

if [ -z \$is_dir_mounted ]
then
  echo "/mnt/lsf is not a mounted remote filesystem"
  exit 1
elif [[ \$is_dir_mounted != "nfs"* ]]
then
  echo "/mnt/lsf is not a NFS mounted remote filesystem"
  exit 1
fi

count1=\$( wc -l $LSF_HOSTS_FILE | awk '{print \$1}' )
if [ -z \$count1 ]; then
  echo "$LSF_HOSTS_FILE cannot be empty"
  exit 1
fi

count2=\$( wc -l /etc/hosts | grep $cluster_prefix | awk '{print \$1}' )
if [ -z \$count2 ]; then
  cat $LSF_HOSTS_FILE >> /etc/hosts
fi

source $LSF_TOP/conf/profile.lsf
is_lsf_running=\$(lsf_daemons status | grep running | wc -l | awk '{print \$1}')
if [ \$is_lsf_running -eq 0 ]; then
  lsf_daemons start &
fi

source /opt/ibm/lsfsuite/ext/profile.platform
app_center_status=\$(pmcadmin list | grep WEBGUI | awk '{print \$2}')
if [ "\$enable_app_center" = "true" ] && [ "\$app_center_status" = 'STOPPED' ]; then
  perfadmin start all
  sleep 5
  pmcadmin start
fi
EOF

### enable it through cronjobs
chmod +x /root/.lsfstartup.sh
(crontab -l 2>/dev/null; echo "@reboot sleep 30 && /root/.lsfstartup.sh") | crontab -