#!/bin/bash
# Variable declaration
PACKER_FILE_PROVISIONER_PATH='/tmp/packages'
SCALE_PACKAGES_PATH=$PACKER_FILE_PROVISIONER_PATH/scale

# Pacakge prerequisites
SCALE_PREREQS="kernel-devel-$(uname -r) make gcc-c++ binutils elfutils-libelf-devel"
yum install -y $SCALE_PREREQS

# Scale installation
rpm --import $SCALE_PACKAGES_PATH/SpectrumScale_public_key.pgp
yum install -y $SCALE_PACKAGES_PATH/*.rpm
/usr/lpp/mmfs/bin/mmbuildgpl
echo 'export PATH=$PATH:/usr/lpp/mmfs/bin' >> /root/.bashrc

# Cleanup
rm -rf $PACKER_FILE_PROVISIONER_PATH
rm -rf /var/log/messages
rm -rf /root/.bash_history
history -c