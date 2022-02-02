###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

output "ssh_command" {
  value = "ssh -J root@${ibm_is_floating_ip.login_fip.address}  lsfadmin@${ibm_is_instance.master[0].primary_network_interface[0].primary_ipv4_address}"
}

output "vpc_name" {
  value = "${data.ibm_is_vpc.vpc.name} --  - ${data.ibm_is_vpc.vpc.id}"
}

output "vpn_config_info" {
  value = var.vpn_enabled ? "IP: ${ibm_is_vpn_gateway.vpn[0].public_ip_address}, CIDR: ${ibm_is_subnet.subnet.ipv4_cidr_block}, UDP ports: 500, 4500": null
}
