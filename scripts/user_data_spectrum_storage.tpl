#!/usr/bin/env bash

nfs_server=${storage_ips}
temp_public_key="${temp_public_key}"

if grep -q "Red Hat" /etc/os-release
then
    USER=root
elif grep -q "Ubuntu" /etc/os-release
then
    USER=ubuntu
elif grep -q "centos" /etc/os-release
then
    USER=root
fi
if [[ "${instance_profile_type}" == "fixed" ]]
then
    echo "###########################################################################################" >> /etc/motd
    echo "# You have logged in to Instance storage virtual server.                                  #" >> /etc/motd
    echo "#   - Instance storage is temporary storage that's available only while your virtual      #" >> /etc/motd
    echo "#     server is running.                                                                  #" >> /etc/motd
    echo "#   - Data on the drive is unrecoverable after instance shutdown, disruptive maintenance, #" >> /etc/motd
    echo "#     or hardware failure.                                                                #" >> /etc/motd
    echo "#                                                                                         #" >> /etc/motd
    echo "# Refer: https://cloud.ibm.com/docs/vpc?topic=vpc-instance-storage                        #" >> /etc/motd
    echo "###########################################################################################" >> /etc/motd
fi
mkdir -p "/usr/lib/tuned/virtual-gpfs-guest"
tuned-adm profile virtual-gpfs-guest
systemctl restart NetworkManager
systemctl stop firewalld
firewall-offline-cmd --zone=public --add-port=1191/tcp
firewall-offline-cmd --zone=public --add-port=60000-61000/tcp
firewall-offline-cmd --zone=public --add-port=47080/tcp
firewall-offline-cmd --zone=public --add-port=47080/udp
firewall-offline-cmd --zone=public --add-port=47443/tcp
firewall-offline-cmd --zone=public --add-port=47443/udp
firewall-offline-cmd --zone=public --add-port=4444/tcp
firewall-offline-cmd --zone=public --add-port=4444/udp
firewall-offline-cmd --zone=public --add-port=4739/udp
firewall-offline-cmd --zone=public --add-port=4739/tcp
firewall-offline-cmd --zone=public --add-port=9084/tcp
firewall-offline-cmd --zone=public --add-port=9085/tcp
firewall-offline-cmd --zone=public --add-service=http
firewall-offline-cmd --zone=public --add-service=https
systemctl start firewalld