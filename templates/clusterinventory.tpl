###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

[worker]
${master_private_ip}
%{ for worker_private_ip in worker_private_ips ~}
${worker_private_ip}
%{ endfor ~}

[worker_hname]
${master}
%{ for worker in workers ~}
${worker}
%{ endfor ~}

[all:vars]
ansible_ssh_user=root
#ansible_ssh_private_key_file=${ansible_sshkey}
ansible_ssh_common_args='-F ${ssh_config}'
nfs_volume_size=${nfs_volume_size}
LS_Entitlement="LS_Standard   10.1   ()   ()   ()   ()   18b1928f13939bd17bf25e09a2dd8459f238028f"
LSF_Entitlement="LSF_Standard   10.1   ()   ()   ()   pa   3f08e215230ffe4608213630cd5ef1d8c9b4dfea"
imageID="${imageID}"
subnetID="${subnetID}"
vpcID="${vpcID}"
securityGroupID="${securityGroupID}"
regionName="${regionName}"
zoneName="${zoneName}"
rc_maxNumber=${g2cidr_size}
rc_master_key=${rc_master_key}
