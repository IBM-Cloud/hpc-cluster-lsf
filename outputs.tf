###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################
/*
Note: Below are the user names used to login to each nodes:
      lsfadmin = management_host/management_host_candidate/workernode
      root     = scale_storage_nodes
      Where ever we see the variable name set as management_host, that is equivalent to management. These changes are done as part of https://zenhub.ibm.com/workspaces/hpccluster-5fca9ac6798f26158474cd14/issues/workload-eng-services/hpccluster/1261
*/
output "ssh_command" {
  value = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J root@${ibm_is_floating_ip.login_fip.address} lsfadmin@${ibm_is_instance.management_host[0].primary_network_interface[0].primary_ip.0.address}"
}

output "vpc_name" {
  value = "${data.ibm_is_vpc.vpc.name} --  - ${data.ibm_is_vpc.vpc.id}"
}

output "vpn_config_info" {
  value = var.vpn_enabled ? "IP: ${ibm_is_vpn_gateway.vpn[0].public_ip_address}, CIDR: ${ibm_is_subnet.subnet.ipv4_cidr_block}, UDP ports: 500, 4500": null
}

output "region_name" {
  value = data.ibm_is_region.region.name
}

output "spectrum_scale_storage_ssh_command" {
  value = var.spectrum_scale_enabled ? "ssh -J root@${ibm_is_floating_ip.login_fip.address} root@${ibm_is_instance.spectrum_scale_storage[0].primary_network_interface[0].primary_ip.0.address}": null
}

output "application_center" {
  value = var.enable_app_center ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -L 8443:localhost:8443 -J root@${ibm_is_floating_ip.login_fip.address} lsfadmin@${ibm_is_instance.management_host[0].primary_network_interface[0].primary_ip.0.address}": null
}
