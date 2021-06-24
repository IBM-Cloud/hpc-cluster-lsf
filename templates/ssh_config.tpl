###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# created by terraform from template
# ssh_config file to access private IP hosts via
# public gateway ProxyJump
# use: ssh -F ssh_config <private_ip>

# master
Host ${master_private_ip}
   ProxyJump  ${login_public_ip}

# worker hosts
%{ for worker_private_ip in worker_private_ips ~}
Host ${worker_private_ip}
   ProxyJump  ${login_public_ip}

%{ endfor ~}

Host *
   IdentityFile ${local_ssh_keyfile}
   User root
   UserKnownHostsFile=/dev/null
   StrictHostKeyChecking no
   ConnectTimeout 50
