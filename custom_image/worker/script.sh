#!/bin/bash
# Variable declaration
PACKER_FILE_PROVISIONER_PATH='/tmp/packages'
SCALE_PACKAGES_PATH=$PACKER_FILE_PROVISIONER_PATH/scale
LSF_PACKAGES_PATH=$PACKER_FILE_PROVISIONER_PATH/lsf
LSF_CONF_PATH='/opt/ibm/lsf/conf'

# Pacakge prerequisites
SCALE_PREREQS="kernel-devel-$(uname -r) make gcc-c++ binutils elfutils-libelf-devel"
yum install -y $SCALE_PREREQS

# Scale installation
rpm --import $SCALE_PACKAGES_PATH/SpectrumScale_public_key.pgp
yum install -y $SCALE_PACKAGES_PATH/*.rpm
/usr/lpp/mmfs/bin/mmbuildgpl
echo 'export PATH=$PATH:/usr/lpp/mmfs/bin' >> /root/.bashrc


# LSF prerequisites
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
LSF_PREREQS="docker-ce docker-ce-cli containerd.io python38 nfs-utils ed wget gcc-gfortran libgfortran libquadmath libmpc libquadmath-devel mpfr perl libnsl"
yum install -y $LSF_PREREQS
systemctl enable docker containerd
systemctl start docker containerd
useradd -u 1001 lsfadmin
usermod -aG docker lsfadmin
echo 'lsfadmin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
mkdir -p /opt/ibm/lsf
chmod 755 /opt/ibm/lsf
rm -f /usr/bin/python /usr/bin/python3
ln -s /usr/bin/python3.6 /usr/bin/python
ln -s /usr/bin/python3.8 /usr/bin/python3
chmod 755 -R /usr/lib/python3.8/site-packages
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
runuser -l lsfadmin -c 'pip3.8 install ibm-vpc==0.10.0 --user'
runuser -l lsfadmin -c 'pip3.8 install ibm-cloud-networking-services ibm-cloud-sdk-core selinux --user'
ibmcloud plugin install vpc-infrastructure
ibmcloud plugin install DNS
hostname lsfservers
echo 'LS_Standard  10.1  ()  ()  ()  ()  18b1928f13939bd17bf25e09a2dd8459f238028f' > $LSF_PACKAGES_PATH/ls.entitlement
echo 'LSF_Standard  10.1  ()  ()  ()  pa  3f08e215230ffe4608213630cd5ef1d8c9b4dfea' > $LSF_PACKAGES_PATH/lsf.entitlement
echo 'ibm_pac_standard   10.2      ()      ()      ()            ()     9d21a2af0379a6cf98313a034cf33fe0f9716236' > $LSF_PACKAGES_PATH/pac.entitlement


# LSF installation
cd $LSF_PACKAGES_PATH || exit
zcat lsf*lsfinstall_linux_x86_64.tar.Z | tar xvf -
cd lsf*_lsfinstall || exit
sed -e '/show_copyright/ s/^#*/#/' -i lsfinstall
cat <<EOT >> install.config
LSF_TOP="/opt/ibm/lsf"
LSF_ADMINS="lsfadmin"
LSF_CLUSTER_NAME="BigComputeCluster"
LSF_MASTER_LIST="lsfservers"
LSF_ENTITLEMENT_FILE="$LSF_PACKAGES_PATH/lsf.entitlement"
CONFIGURATION_TEMPLATE="DEFAULT"
ENABLE_DYNAMIC_HOSTS="Y"
ENABLE_EGO="N"
LSF_DYNAMIC_HOST_WAIT_TIME="2"
ACCEPT_LICENSE="Y"
SILENT_INSTALL="Y"
LSF_SILENT_INSTALL_TARLIST="ALL"
EOT
bash lsfinstall -f install.config
echo $?

# LSF post-installation setup
cat <<EOT >> $LSF_CONF_PATH/lsf.conf
LSF_ROOT_USER=Y
LSB_RC_EXTERNAL_HOST_IDLE_TIME=10
LSF_DYNAMIC_HOST_TIMEOUT=24
LSB_RC_EXTERNAL_HOST_FLAG="icgen2host"
LSF_SEND_CONFINFO_TCP_THRESHOLD=8975
LSF_RSH="ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'"
EOT

sed -i "s/^#  icgen2host/   icgen2host/g" $LSF_CONF_PATH/lsf.shared
sed -i "s/^#schmod_demand/schmod_demand/g" $LSF_CONF_PATH/lsbatch/BigComputeCluster/configdir/lsb.modules
sed -i '/QUEUE_NAME   = normal/a RC_HOSTS     = all' $LSF_CONF_PATH/lsbatch/BigComputeCluster/configdir/lsb.queues
sed -i '/default    !/a lsfservers  0    ()      ()    ()     ()     ()            (Y)   # Example' $LSF_CONF_PATH/lsbatch/BigComputeCluster/configdir/lsb.hosts

cat <<EOT >> $LSF_CONF_PATH/lsbatch/BigComputeCluster/configdir/lsb.queues
Begin Queue
QUEUE_NAME=das_q
DATA_TRANSFER=Y
HOSTS=all
RES_REQ=type==any
End Queue
EOT

# LSF Worker (Resource Connector) prerequisites
cat <<EOT > $LSF_CONF_PATH/resource_connector/hostProviders.json
{
    "providers":[
        {
            "name": "ibmcloudgen2",
            "type": "ibmcloudgen2Prov",
            "confPath": "resource_connector/ibmcloudgen2",
            "scriptPath": "resource_connector/ibmcloudgen2"
        }
    ]
}
EOT

mv $LSF_CONF_PATH/resource_connector/ibmcloudgen2/conf/credentials  $LSF_CONF_PATH/resource_connector/ibmcloudgen2/credentials
cat <<EOT > $LSF_CONF_PATH/resource_connector/ibmcloudgen2/conf/ibmcloudgen2_config.json
{
  "IBMCLOUDGEN2_KEY_FILE": "$LSF_CONF_PATH/resource_connector/ibmcloudgen2/credentials",
  "IBMCLOUDGEN2_PROVISION_FILE": "$LSF_CONF_PATH/resource_connector/ibmcloudgen2/user_data.sh",
  "IBMCLOUDGEN2_MACHINE_PREFIX": "icgen2host",
  "LogLevel": "INFO"
}
EOT

cat <<EOT > $LSF_CONF_PATH/resource_connector/ibmcloudgen2/conf/ibmcloudgen2_templates.json
{
    "templates": [
        {
            "templateId": "Template-1",
            "maxNumber": template1_maxNum,
            "attributes": {
                "type": ["String", "X86_64"],
                "ncores": ["Numeric", "template1-ncores"],
                "ncpus": ["Numeric", "template1-ncpus"],
                "mem": ["Numeric", "template1-mem"],
                "icgen2host": ["Boolean", "1"]
            },
            "imageId": "imageId-value",
            "subnetId": "subnetId-value",
            "vpcId": "vpcId-value",
            "vmType": "template1-vmType",
            "securityGroupIds": ["securityGroupIds-value"],
            "resourceGroupId": "rgId-value",
            "sshkey_id": "sshkey_id-value",
            "region": "region-value",
            "zone": "zone-value"
        }
    ]
}
EOT

cat <<EOT >  $LSF_CONF_PATH/resource_connector/ibmcloudgen2/user_data.sh
#!/bin/sh
logfile=/tmp/user_data.log
echo "START \$(date '+%Y-%m-%d %H:%M:%S')" >> \$logfile
# Export user data, which is defined with the "UserData" attribute in the template
%EXPORT_USER_DATA%
env >> \$logfile
# Add your customization script here
#Change the vm host name based on the internal ip
privateIP=\$(ip addr show eth0 | awk '\$1 == "inet" {gsub(/\/.*$/, "", \$2); print \$2}')
hostname=icgen2host-\${privateIP//./-}
hostnamectl set-hostname \${hostname}
hostname >> \$logfile
networkIPrange=\$(echo \${privateIP}|cut -f1-3 -d .)
host_prefix=\$(hostname|cut -f1-4 -d -)
# NOTE: On ibm gen2, the default DNS server do not have reverse hostname/IP resolution.
# 1) put the master server hostname and ip into /etc/hosts.
# 2) put all possible VMs' hostname and ip into /etc/hosts.
for ((i=1; i<=254; i++))
do
   echo "\${networkIPrange}.\${i}   \${host_prefix}-\${i}" >> /etc/hosts
done
# Source LSF enviornment at the VM host
LSF_TOP=/opt/ibm/lsf_worker
LSF_CONF_FILE=\$LSF_TOP/conf/lsf.conf
. \$LSF_TOP/conf/profile.lsf
env >> \$logfile
# Update master hostname
sed -i "s/LSFServerhosts/ServerHostPlaceHolder/"  \$LSF_CONF_FILE
# Support rc_account resource to enable RC_ACCOUNT policy
if [ -n "\${rc_account}" ]; then
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap \${rc_account}*rc_account]\"/" \$LSF_CONF_FILE
echo "update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap \${rc_account}*rc_account]" >> \$logfile
fi
# Add additional local resources if needed
instance_id=\$(dmidecode | grep Family | cut -d ' ' -f 2 |head -1)
if [ -n "\$instance_id" ]; then
    sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap \$instance_id*instanceID]\"/" \$LSF_CONF_FILE
    echo "Update LSF_LOCAL_RESOURCES in \$LSF_CONF_FILE successfully, add [resourcemap \${instance_id}*instanceID]" >> \$logfile
else
    echo "Can not get instance ID" >> \$logfile
fi
cat \$LSF_CONF_FILE  >> \$logfile
sleep 5
lsf_daemons start &
sleep 5
lsf_daemons status >> \$logfile
echo "END \$(date '+%Y-%m-%d %H:%M:%S')" >> \$logfile
EOT

sed -i "s/^VPC_APIKEY=.*/VPC_APIKEY=/g" $LSF_CONF_PATH/resource_connector/ibmcloudgen2/credentials
sed -i "s/^RESOURCE_RECORDS_APIKEY=.*/RESOURCE_RECORDS_APIKEY=/g" $LSF_CONF_PATH/resource_connector/ibmcloudgen2/credentials
chown -R lsfadmin:root $LSF_CONF_PATH

# LSF worker (Resource connector) installation
cd $LSF_PACKAGES_PATH || exit
cd lsf*_lsfinstall || exit
cat <<EOT >> server.config
LSF_TOP="/opt/ibm/lsf_worker"
LSF_ADMINS="lsfadmin root"
LSF_ENTITLEMENT_FILE="$LSF_PACKAGES_PATH/lsf.entitlement"
LSF_SERVER_HOSTS="lsfservers"
LSF_LOCAL_RESOURCES="[resource icgen2host]"
ACCEPT_LICENSE="Y"
SILENT_INSTALL="Y"
EOT
bash lsfinstall -s -f server.config
echo $?
rm -rf /opt/ibm/lsf_worker/10.1
ln -s /opt/ibm/lsf/10.1 /opt/ibm/lsf_worker
sed -i 's/LSF_SERVER_HOSTS=.*/LSF_SERVER_HOSTS="LSFServerhosts"/g' /opt/ibm/lsf_worker/conf/lsf.conf
echo 'LSB_MC_DISABLE_HOST_LOOKUP=Y' >> /opt/ibm/lsf_worker/conf/lsf.conf
echo "LSF_RSH=\"ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'\"" >> /opt/ibm/lsf_worker/conf/lsf.conf

# LSF License Scheduler installation
source $LSF_CONF_PATH/profile.lsf
cd $LSF_PACKAGES_PATH || exit
zcat lsf*_licsched_lnx310-x64.tar.Z | tar xvf -
cd lsf10.1_licsched_linux3.10-glibc2.17-x86_64 || exit
echo 'SILENT_INSTALL="Y"' >> setup.config
bash setup
echo $?

# LSF Data Manager installation
cd $LSF_PACKAGES_PATH || exit
zcat lsf*_data_mgr_install.tar.Z | tar xvf -
cd lsf*_data_mgr_install || exit
cat <<EOT >> install.config
LSF_TOP="/opt/ibm/lsf"
LSF_ADMINS="lsfadmin"
LSF_CLUSTER_NAME="BigComputeCluster"
LSF_ENTITLEMENT_FILE="$LSF_PACKAGES_PATH/lsf.entitlement"
ACCEPT_LICENSE="Y"
SILENT_INSTALL="Y"
LSF_SILENT_INSTALL_TARLIST="ALL"
EOT
bash dminstall -f install.config
echo $?
mkdir /opt/ibm/lsf/das_staging_area
chown -R lsfadmin:root /opt/ibm/lsf/das_staging_area
cat <<EOT >> $LSF_CONF_PATH/lsf.datamanager.BigComputeCluster
Begin Parameters
ADMINS = lsfadmin
STAGING_AREA = /opt/ibm/lsf/das_staging_area
End Parameters
EOT

# OpenMPI installation
cd $LSF_PACKAGES_PATH || exit
wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.0.tar.gz
tar -xvf openmpi-4.1.0.tar.gz
cd openmpi-4.1.0 || exit
ln -s /usr/lib64/libnsl.so.2.0.0 /usr/lib64/libnsl.so
export LANG=C
./configure --prefix='/usr/local/openmpi-4.1.0' --enable-mpi-thread-multiple --enable-shared --disable-static --enable-mpi-fortran=usempi --disable-libompitrace --enable-script-wrapper-compilers --enable-wrapper-rpath --enable-orterun-prefix-by-default --with-io-romio-flags=--with-file-system=nfs --with-lsf=/opt/ibm/lsf/10.1 --with-lsf-libdir=/opt/ibm/lsf/10.1/linux3.10-glibc2.17-x86_64/lib
make -j 32
make install
find /usr/local/openmpi-4.1.0/ -type d -exec chmod 775 {} \;

# Intel One API (hpckit) installation
cd || exit
dnf config-manager -y --add-repo https://yum.repos.intel.com/hpc-platform/el8/setup/intel-hpc-platform.repo
rpm --import https://yum.repos.intel.com/hpc-platform/el8/setup/PUBLIC_KEY.PUB
dnf config-manager -y --add-repo https://yum.repos.intel.com/oneapi
rpm --import https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2023.PUB
yum install -y intel-basekit intel-hpckit

# Setting up access
mv -f $LSF_PACKAGES_PATH/*.entitlement /opt/ibm/lsf/conf
chown -R lsfadmin:root $LSF_CONF_PATH

# LSF Application Center (optional)
mkdir -p /opt/IBM/lsf_app_center_cloud_packages
mv $LSF_PACKAGES_PATH/pac* /opt/IBM/lsf_app_center_cloud_packages

# Cleanup
rm -rf $PACKER_FILE_PROVISIONER_PATH
rm -rf /var/log/messages
rm -rf /root/.bash_history
history -c
