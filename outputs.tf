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
output "ssh_to_management_node" {
  value = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@${module.login_fip.floating_ip_address} lsfadmin@${module.management_host[0].primary_network_interface}"
}

output "ssh_to_login_node" {
  value = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@${module.login_fip.floating_ip_address} lsfadmin@${module.login_vsi[0].primary_network_interface}"
}

output "ssh_to_ldap_node" {
  value = var.enable_ldap && var.ldap_server == "null" ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -J vpcuser@${module.login_fip.floating_ip_address} ubuntu@${local.ldap_server}" : null
}

output "vpc_name" {
  value = "${data.ibm_is_vpc.vpc.name} --  - ${data.ibm_is_vpc.vpc.id}"
}

output "vpn_config_info" {
  value = var.vpn_enabled ? "IP: ${module.vpn[0].vpn_gateway_public_ip_address}, CIDR: ${var.cluster_subnet_id == "" ? module.subnet[0].ipv4_cidr_block : data.ibm_is_subnet.existing_subnet[0].ipv4_cidr_block}, UDP ports: 500, 4500" : null
}

output "region_name" {
  value = data.ibm_is_region.region.name
}

output "spectrum_scale_storage_ssh_command" {
  value = var.spectrum_scale_enabled ? "ssh -J root@${module.login_fip.floating_ip_address} root@${module.spectrum_scale_storage[0].primary_network_interface}" : null
}

output "application_center" {
  value = var.enable_app_center ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -L 8443:localhost:8443 -L 6080:localhost:6080 -J vpcuser@${module.login_fip.floating_ip_address} lsfadmin@${module.management_host[0].primary_network_interface}" : null
}

output "application_center_url" {
  value = var.enable_app_center ? "https://localhost:8443" : null
}

output "image_map_entry_found" {
  value = "${local.image_mapping_entry_found} --  - ${var.image_name}"
}


