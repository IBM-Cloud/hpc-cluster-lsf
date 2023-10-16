#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#set -x

logfile=/tmp/user_data.log
echo START `date '+%Y-%m-%d %H:%M:%S'` >> $logfile

nfs_server=${storage_ips}
nfs_mount_dir="data"
#cluster_name=""

if [ ! -z $cluster_name ]
then
  oldclustername="BigComputeCluster"
else
  cluster_name="BigComputeCluster"
fi
newclustername=$cluster_name
vmPrefix="icgen2host"

#If no dns, then will fixed the hostname based on provate IP address and hostname, if you have dns server, then can completely remove this part
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
ManagementHostName=${vmPrefix}-${privateIP//./-}
hostnamectl set-hostname ${ManagementHostName}
networkIPrange=$(echo ${privateIP}|cut -f1-3 -d .)
host_prefix=$(hostname|cut -f1-4 -d -)

## Removing Unused repos.
[ -f /etc/yum.repos.d/intel-hpc-platform.repo ] && sudo rm -rf /etc/yum.repos.d/intel-hpc-platform.repo
[ -f /etc/yum.repos.d/docker-ce.repo ] && sudo rm -rf /etc/yum.repos.d/docker-ce.repo
[ -f /etc/yum.repos.d/yum.repos.intel.com_oneapi.repo ] && sudo rm -rf /etc/yum.repos.d/yum.repos.intel.com_oneapi.repo

# Temporary fix for Dynamic Server creation
python3 -m pip install ibm-vpc==0.10.0
python3 -m pip install ibm-cloud-networking-services ibm-cloud-sdk-core selinux
chmod 755 -R /usr/local/lib/python3.8
chmod 755 -R /usr/local/lib64/python3.8

# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-eth0"
systemctl restart NetworkManager

# NOTE: On ibm gen2, the default DNS server do not have reverse hostname/IP resolution.
# 1) put the management_host server name and ip into lsf hosts.
# 2) put all possible VMs' hostname and ip into lsf hosts.
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts

#Update management_host name based on with nfs share or not
if ([ -n "${nfs_server}" ] && [ -n "${nfs_mount_dir}" ]); then
  echo "NFS server and share found, start mount nfs share!" >> $logfile
  #Mount the nfs share
  showmount -e $nfs_server >> $logfile
  mkdir -p /mnt/$nfs_mount_dir >> $logfile
  mount -t nfs $nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir >> $logfile
  df -h /mnt/$nfs_mount_dir >> $logfile
  #make auto mount when server is down
  echo "$nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  echo "Mount nfs share done!" >> $logfile
  # delete old config dir
  rm -rf /mnt/$nfs_mount_dir/lsf_$ManagementHostName /mnt/$nfs_mount_dir/ssh
  # Generate and copy a public ssh key
  mkdir -p /mnt/$nfs_mount_dir/ssh /home/lsfadmin/.ssh
  #Create the sshkey in the share directory and then copy the public and private key to respective root and lsfadmin .ssh folder
  ssh-keygen -q -t rsa -f /mnt/$nfs_mount_dir/ssh/id_rsa -C "lsfadmin@${ManagementHostName}" -N "" -q
  cat /mnt/$nfs_mount_dir/ssh/id_rsa.pub >> /root/.ssh/authorized_keys
  cp /root/.ssh/authorized_keys /mnt/$nfs_mount_dir/ssh/authorized_keys
  cp /mnt/$nfs_mount_dir/ssh/id_rsa /root/.ssh/id_rsa
  echo "StrictHostKeyChecking no" >> /root/.ssh/config
  cp /mnt/$nfs_mount_dir/ssh/id_rsa /home/lsfadmin/.ssh/id_rsa
  cp /mnt/$nfs_mount_dir/ssh/authorized_keys /home/lsfadmin/.ssh/authorized_keys
  echo "${temp_public_key}" >> /root/.ssh/authorized_keys
  chmod 600 /home/lsfadmin/.ssh/authorized_keys
  chmod 700 /home/lsfadmin/.ssh
  chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh

  echo "StrictHostKeyChecking no" >> /home/lsfadmin/.ssh/config
else
  echo "No NFS server and share found!" >> $logfile
fi

#
# Source LSF enviornment at the VM host
#
LSF_TOP=/opt/ibm/lsf
LSF_CONF=$LSF_TOP/conf
LSF_IBM_GEN2=$LSF_CONF/resource_connector/ibmcloudgen2
LSF_CONF_FILE=$LSF_CONF/lsf.conf
LSF_HOSTS_FILE=$LSF_CONF/hosts
LSB_HOSTS_FILE=$LSF_CONF/lsbatch/$newclustername/configdir/lsb.hosts
LSF_EGO_CONF_FILE=$LSF_CONF/ego/$newclustername/kernel/ego.conf
LSF_CLUSTER_FILE=$LSF_CONF/lsf.cluster.$newclustername
IBM_CLOUD_CREDENTIALS_FILE=$LSF_IBM_GEN2/credentials
IBM_CLOUD_TEMPLATE_FILE=$LSF_IBM_GEN2/conf/ibmcloudgen2_templates.json
IBM_CLOUD_USER_DATA_FILE=$LSF_IBM_GEN2/user_data.sh
IBM_CLOUD_CONF_FILE=$LSF_IBM_GEN2/conf/ibmcloudgen2_config.json
. $LSF_TOP/conf/profile.lsf

env >> $logfile

python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> $LSF_HOSTS_FILE


#Update cluster name from all configuration files to the new cluster name
if [ ! -z $cluster_name ]
then
   grep -rli "$oldclustername" $LSF_CONF/*|xargs sed -i "s/$oldclustername/$newclustername/g" >> $logfile
   #Update directory name to the new cluster name
   mv /opt/ibm/lsf/work/$oldclustername/live_confdir/lsbatch/$oldclustername /opt/ibm/lsf/work/$oldclustername/live_confdir/lsbatch/$newclustername >> $logfile
   find /opt/ibm/lsf/ -type d -name "$oldclustername" -execdir bash -c "mv {} $newclustername" \;  -prune >> $logfile
   #update the configuration file name to the new cluster name
   find $LSF_CONF/ -type f -name "*$oldclustername" | while read FILE ;
   do
     newfile="$(echo ${FILE} |sed -e "s/$oldclustername/$newclustername/g")" ;
     mv "${FILE}" "${newfile}" ;
   done
fi

#update the lsf management_host name
grep -rli 'lsfservers' $LSF_CONF/*|xargs sed -i "s/lsfservers/${ManagementHostName}/g"

#Add management candidate host into lsf cluster
ManagementHostNames=`echo "${management_host_ips//./-}" | sed -e "s/^/${vmPrefix}-/g" | sed -e "s/ / ${vmPrefix}-/g"`
sed -i "s/LSF_MASTER_LIST=.*/LSF_MASTER_LIST=\"${ManagementHostNames}\"/g" $LSF_CONF_FILE
sed -i "s/EGO_MANAGEMENT_HOST_LIST=.*/EGO_MANAGEMENT_HOST_LIST=\"${ManagementHostNames}\"/g" $LSF_EGO_CONF_FILE
for ManagementCandidateHostName in ${ManagementHostNames}; do
  if [ "${ManagementCandidateHostName}" != "${ManagementHostName}" ]; then
    sed -i "/^$ManagementHostName.*/a ${ManagementCandidateHostName} ! ! 1 (mg)" $LSF_CLUSTER_FILE
    sed -i "/^#hostE.*/a ${ManagementCandidateHostName} 0 () () () () () (Y)" $LSB_HOSTS_FILE
  fi
done
sed -i "s/management_host_hosts.*/management_host_hosts (${ManagementHostNames} )/g" $LSB_HOSTS_FILE
# TODO: ebrokerd runs only on the primary management_host. Can we create/delete dynamic workers after failover?
# https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=connnector-lsf-resource-connector-overview
#sed -i "s/LSF_MQ_BROKER_HOSTS=.*/LSF_MQ_BROKER_HOSTS=\"${ManagementHostNames}\"/g" $LSF_CONF_FILE
#sed -i "s/LSF_DATA_HOSTS=.*/LSF_DATA_HOSTS=\"${ManagementHostNames}\"/g" $LSF_CONF_FILE
#sed -i "s/MQTT_BROKER_HOST=/#MQTT_BROKER_HOST=/g" $LSF_CONF_FILE
#sed -i "s/MQTT_BROKER_PORT=/#MQTT_BROKER_PORT=/g" $LSF_CONF_FILE

# when we request a lot of machines, it may need close to 5 minutes for all the nodes to join the cluster.
sed -i "s/LSB_RC_EXTERNAL_HOST_IDLE_TIME=.*/LSB_RC_EXTERNAL_HOST_IDLE_TIME=10/g" $LSF_CONF_FILE

#update user_data.sh
sed -i "s/ServerHostPlaceHolder/${ManagementHostNames}/" $IBM_CLOUD_USER_DATA_FILE
sed -i "s/icgen2host/${vmPrefix}/" $IBM_CLOUD_USER_DATA_FILE

#update IBM gen2 Credentials API keys
sed -i "s/VPC_APIKEY=/VPC_APIKEY=$VPC_APIKEY_VALUE/" $IBM_CLOUD_CREDENTIALS_FILE
sed -i "s/RESOURCE_RECORDS_APIKEY=/RESOURCE_RECORDS_APIKEY=$RESOURCE_RECORDS_APIKEY_VALUE/" $IBM_CLOUD_CREDENTIALS_FILE

#Update IBM gen2 template
sed -i "s/imageId-value/${imageID}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/subnetId-value/${subnetID}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/vpcId-value/${vpcID}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/securityGroupIds-value/${securityGroupID}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/sshkey_id-value/${sshkey_ID}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/region-value/${regionName}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/zone-value/${zoneName}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-ncores/${rc_ncores}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-ncpus/${rc_ncpus}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-mem/${rc_memInMB}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1-vmType/${rc_profile}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/template1_maxNum/${rc_maxNum}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/rgId-value/${rc_rg}/" $IBM_CLOUD_TEMPLATE_FILE
sed -i "s/icgen2host/${vmPrefix}/" $IBM_CLOUD_CONF_FILE
cat >> $IBM_CLOUD_USER_DATA_FILE << EOF
# Allow login as lsfadmin
nfs_mount_dir="data"
mkdir -p /home/lsfadmin/.ssh
cp /mnt/$nfs_mount_dir/ssh/authorized_keys /home/lsfadmin/.ssh/authorized_keys
cat /mnt/$nfs_mount_dir/ssh/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 600 /home/lsfadmin/.ssh/authorized_keys
chmod 700 /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-eth0"
systemctl restart NetworkManager
EOF

if $hyperthreading; then
  echo "EGO_DEFINE_NCPUS=threads" >> $LSF_CONF_FILE
else
  echo "EGO_DEFINE_NCPUS=cores" >> $LSF_CONF_FILE
  for vcpu in `cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq`; do
    echo 0 > /sys/devices/system/cpu/cpu$vcpu/online
  done
fi

# Insert our custom user script to workers' user data
cat << EOF >> /tmp/client.sh
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /opt/ibm/lsf_worker/conf/hosts
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${vmPrefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> /etc/hosts
mkdir -p /mnt/$nfs_mount_dir
mount -t nfs $nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir
echo "$nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
ln -s /mnt/$nfs_mount_dir /home/lsfadmin/shared
# Allow ssh from management_host
sed -i "s#^\(AuthorizedKeysFile.*\)#\1 /mnt/$nfs_mount_dir/ssh/authorized_keys#g" /etc/ssh/sshd_config
systemctl restart sshd
#echo "LSF_MQ_BROKER_HOSTS=\"${ManagementHostNames}\"" >> /opt/ibm/lsf_worker/conf/lsf.conf
EOF

if $hyperthreading; then
cat << EOF >> /tmp/client.sh
EGO_DEFINE_NCPUS=threads >> /opt/ibm/lsf_worker/conf/lsf.conf
EOF
else
cat << EOF >> /tmp/client.sh
EGO_DEFINE_NCPUS=cores >> /opt/ibm/lsf_worker/conf/lsf.conf
for vcpu in \`cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq\`; do
  echo 0 > /sys/devices/system/cpu/cpu\$vcpu/online
done
EOF
fi

sed -i 's#for ((i=1; i<=254; i++))#for ((i=1; i<=0; i++))#g' $IBM_CLOUD_USER_DATA_FILE
sed -i "/# Add your customization script here/r /tmp/client.sh" $IBM_CLOUD_USER_DATA_FILE

#Move the lsf intallation to the share location
mkdir -p /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp
cp -a -r /opt/ibm/lsf/conf /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/conf
cp -a -r /opt/ibm/lsf/work /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/work
cp -a -r /opt/ibm/lsf/das_staging_area /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/das_staging_area
mkdir -p /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp/log
mv /opt/ibm/lsf/conf /opt/ibm/lsf/conf_orig
mv /opt/ibm/lsf/das_staging_area /opt/ibm/lsf/das_staging_area_orig
rm -rf /opt/ibm/lsf/work /opt/ibm/lsf/log
mv /mnt/$nfs_mount_dir/lsf_$ManagementHostName.tmp /mnt/$nfs_mount_dir/lsf_$ManagementHostName
#link lsf back to its original installation location
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/conf /opt/ibm/lsf/conf
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/work /opt/ibm/lsf/work
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/log /opt/ibm/lsf/log
chown lsfadmin:root /mnt/$nfs_mount_dir/lsf_$ManagementHostName/log
ln -fs /mnt/$nfs_mount_dir/lsf_$ManagementHostName/das_staging_area /opt/ibm/lsf/das_staging_area
echo "moved lsf into nfs share location and link back done" >> $logfile

ln -s /mnt/$nfs_mount_dir /home/lsfadmin/shared

#Updates the lsfadmin user as never expire
sudo chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
cat << EOF > /etc/profile.d/lsf.sh
ls /opt/ibm/lsf/conf/lsf.conf > /dev/null 2> /dev/null < /dev/null &
usleep 10000
PID=\$!
if kill -0 \$PID 2> /dev/null; then
  # lsf.conf is not accessible 
  kill -KILL \$PID 2> /dev/null > /dev/null
  wait \$PID
else
  source /opt/ibm/lsf/conf/profile.lsf
fi
export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no"
PATHs=\`echo "\$PATH" | sed -e 's/:/\n/g'\`
for path in /usr/local/bin /usr/bin /usr/local/sbin /usr/sbin; do
  PATHs=\`echo "\$PATHs" | grep -v \$path\`
done
export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:\`echo "\$PATHs" | paste -s -d :\`
EOF

# TODO: disallow root login

cat $LSF_HOSTS_FILE >> $logfile
cat $IBM_CLOUD_CREDENTIALS_FILE >> $logfile
cat $IBM_CLOUD_TEMPLATE_FILE >> $logfile
cat $IBM_CLOUD_USER_DATA_FILE >> $logfile

echo 1 > /proc/sys/vm/overcommit_memory # new image requires this. otherwise, it reports many failures of memory allocation at fork() if we use candidates. why?
echo 'vm.overcommit_memory=1' > /etc/sysctl.d/90-lsf.conf

sleep 5
lsf_daemons start &
sleep 5
lsf_daemons status >> $logfile

#############################################################
#########    Application Center Installation  ###############
#############################################################

if [ "$enable_app_center" = true ] ;
then
    sleep 30
    echo "---------------------------------------" >> $logfile
    echo "Starting Application Center Installation" >> $logfile
    echo "---------------------------------------" >> $logfile

    ## Extras Check config files
    su - lsfadmin -c "lsadmin ckconfig -v"

    ## Update lsfadmin password, use this when logging into application center
    echo ${app_center_gui_pwd} | sudo passwd --stdin lsfadmin >> $logfile

    ## Add the parameter ALLOW_EVENT_TYPE
    sed -i '$i\\ALLOW_EVENT_TYPE=JOB_NEW JOB_STATUS JOB_FINISH2 JOB_START JOB_EXECUTE JOB_EXT_MSG JOB_SIGNAL JOB_REQUEUE JOB_MODIFY2 JOB_SWITCH METRIC_LOG' $LSF_ENVDIR/lsbatch/HPCCluster/configdir/lsb.params

    ## Enable event streaming
    sed -i '$i\\ENABLE_EVENT_STREAM=Y' $LSF_ENVDIR/lsbatch/HPCCluster/configdir/lsb.params

    ## parameter LSB_QUERY_PORT is set
    grep -ir lsb_query_port $LSF_ENVDIR/lsf.conf

    ## Set the parameter NEWJOB_REFRESH=Y in the configuration file lsb.params.
    sed -i 's/NEWJOB_REFRESH=y/NEWJOB_REFRESH=Y/g' $LSF_ENVDIR/lsbatch/HPCCluster/configdir/lsb.params

    sleep 5

    ## Run the command badmin reconfig to reconfigure mbatchd.
    su - lsfadmin -c "badmin reconfig"

    ## set the parameter LSF_DISABLE_LSRUN=N; first do manual check of parameter
    grep -ir LSF_DISABLE_LSRUN $LSF_ENVDIR/lsf.conf
    sed -i 's/LSF_DISABLE_LSRUN=Y/LSF_DISABLE_LSRUN=N/g' $LSF_ENVDIR/lsf.conf

    ## PAC needs some stuff to run as root
    echo 'LSB_BSUB_PARSE_SCRIPT=Y' >> $LSF_ENVDIR/lsf.conf
    echo LSF_ADDON_HOSTS=$HOSTNAME >> $LSF_ENVDIR/lsf.conf

    sleep 5

    ## apply changes
    su - lsfadmin -c "lsfrestart -f"

    sleep 10

    su - lsfadmin -c "lsadmin resrestart -f all"

    ## Install Maria DB
    echo "Starting Maria DB installation" >> $logfile

    cat << 'EOF' > /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/rhel8-amd64
module_hotfixes=1
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

    echo "Started MariaDB installation" >> $logfile
    sudo yum install MariaDB-server -y >> $logfile
    sudo systemctl start mariadb
    sudo systemctl enable mariadb
    sudo systemctl status mariadb -l >> $logfile

    ## Set the password for MariaDB
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${app_center_db_pwd}';"

    ## Verifing the Application Center Package avilability in the custom image.
    if (( $(ls -ltr /opt/IBM/lsf_app_center_cloud_packages/ | grep "pac" | wc -l) > 0))
    then
        echo "Application center installation started from here." >> $logfile
        ## Extracting the Application center packages.
        cd /opt/IBM/lsf_app_center_cloud_packages
        pac_url=$(ls /opt/IBM/lsf_app_center_cloud_packages/ | grep "pac")
        echo "Application Center Package is available !!" >> $logfile
        tar -xvf ${pac_url##*/}
        pac_folder=$(echo ${pac_url##*/} | sed 's/.tar.Z//g')
        cd ${pac_folder}

        ## Set LSF profile configuration location
        sed -i 's/#\ \.\ $LSF_ENVDIR\/profile\.lsf/. \/opt\/ibm\/lsf\/conf\/profile\.lsf/g' pacinstall.sh
        sed -i 's/# export PAC_ADMINS=\"user1 user2\"/export PAC_ADMINS=\"lsfadmin\"/g' pacinstall.sh

        ## Run installation and below steps as a Root user.
        echo "Started with Application Center installation with pacinstall.sh file " >> $logfile
        MYSQL_ROOT_PASSWORD=${app_center_db_pwd} sudo -E ./pacinstall.sh -s -y >> $logfile
        sleep 10

        ### Setup environment
        echo '. /opt/ibm/lsfsuite/ext/profile.platform' >> ~/.bashrc
        echo 'export GUI_VERSION=3.0' >> ~/.bashrc
        echo 'export LANG=en_US.UTF-8' >> ~/.bashrc
        echo 'export LANGUAGE=en_US.UTF-8' >> ~/.bashrc
        echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc
        echo 'alias pacrestart="lsadmin resrestart -f all; sleep 5; pmcadmin stop; sleep 5; perfadmin stop all; sleep 5; perfadmin start all; sleep 5;  pmcadmin start; pmcadmin list"' >> ~/.bashrc
        source ~/.bashrc
        sudo -E /opt/ibm/lsfsuite/ext/gui/3.0/bin/pmcsetrc.sh >> $logfile
        sudo -E /opt/ibm/lsfsuite/ext/perf/1.2/bin/perfsetrc.sh >> $logfile
        cp /opt/ibm/lsfsuite/ext/perf/conf/datasource.xml /opt/ibm/lsfsuite/ext/gui/conf/datasource.xml

        ## Use the PAC entitlement
        echo "Creating Entitlement Licence file" >> $logfile
        cp /opt/ibm/lsf/conf/pac.entitlement /opt/ibm/lsfsuite/ext/gui/conf/pac.entitlement

        ## change the home path to the shared dir
        sed -i 's/\/home/\/mnt\/data/g' $GUI_CONFDIR/Repository.xml
        sleep 5
        source ~/.bashrc

        ## By default https enabled. Now disbling the https for API calls.
        pmcadmin https disable

        ## Restarting all the services
        echo "restarting lsadmin and pmcadmin users" >> $logfile
        lsadmin resrestart -f all; sleep 5; pmcadmin stop; sleep 5; perfadmin stop all; sleep 5; perfadmin start all; sleep 5;  pmcadmin start; pmcadmin list >> $logfile
        sleep 10
        # rm -rf ${pac_url##*/}
    else
        echo "--------------------------------------------" >> $logfile
        echo "Application center package not found !!" >> $logfile
        echo "--------------------------------------------" >> $logfile
    fi

    sleep 5

    if (( $(rpm -qa | grep lsf-appcenter | wc -l) > 0 ))
    then
        echo "--------------------------------------------" >> $logfile
        echo "Application Center Installed Successfully !!" >> $logfile
        echo "--------------------------------------------" >> $logfile
        ## Removing MariaDB repo after installation.
        [ -f /etc/yum.repos.d/mariadb.repo ] && sudo rm -rf /etc/yum.repos.d/mariadb.repo
    else
        echo "--------------------------------------------" >> $logfile
        echo "Application center Installation Failed !!! " >> $logfile
        echo "--------------------------------------------" >> $logfile
    fi

else
    echo "--------------------------------------------" >> $logfile
	  echo 'Application center installation skipped !!' >> $logfile
    echo "--------------------------------------------" >> $logfile
fi

echo END `date '+%Y-%m-%d %H:%M:%S'` >> $logfile