###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

output "ssh_command" {
  value = "ssh -J root@${ibm_is_floating_ip.login_fip.address}  lsfadmin@${ibm_is_instance.master[0].primary_network_interface[0].primary_ipv4_address}"
}
