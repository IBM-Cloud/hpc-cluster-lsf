###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# IBM Cloud Provider
# Docs are available here, https://cloud.ibm.com/docs/terraform?topic=terraform-tf-provider#store_credentials
# Download IBM Cloud Provider binary from release page. https://github.com/IBM-Cloud/terraform-provider-ibm/releases
# And copy it to $HOME/.terraform.d/plugins/terraform-provider-ibm_v1.2.4

data "ibm_resource_group" "rg" {
  name = var.resource_group
}

data "ibm_is_region" "region" {
  name = local.region_name
}

data "ibm_is_zone" "zone" {
  name   = var.zone
  region = data.ibm_is_region.region.name
}

data "ibm_is_vpc" "existing_vpc" {
  // Lookup for this VPC resource only if var.vpc_name is not empty
  count = var.vpc_name != "" ? 1:0
  name = var.vpc_name
}

data "ibm_is_vpc" "vpc" {
  name = local.vpc_name
  // Depends on creation of new VPC or look up of existing VPC based on value of var.vpc_name,
  depends_on = [ibm_is_vpc.vpc, data.ibm_is_vpc.existing_vpc]
}
data "ibm_is_instance_profile" "controller" {
  name = var.management_node_instance_type
}

data "ibm_is_instance_profile" "worker" {
  name = var.worker_node_instance_type
}

data "ibm_is_instance_profile" "storage" {
  name = var.storage_node_instance_type
}

data "ibm_is_dedicated_host_profiles" "worker" {
  count = var.dedicated_host_enabled ? 1: 0
}
# if dedicated_host_enabled == true, determine the profile name of dedicated hosts and the number of them from worker_node_min_count and worker profile class
locals {
  region_name = join("-", slice(split("-", var.zone), 0, 2))
  profile_str           = split("-", data.ibm_is_instance_profile.worker.name)
  profile_list          = split("x", local.profile_str[1])
# 1. calculate required amount of compute resources using the same instance size as dynamic workers
  cpu_per_node = tonumber(data.ibm_is_instance_profile.worker.vcpu_count[0].value)
  mem_per_node = tonumber(data.ibm_is_instance_profile.worker.memory[0].value)
  required_cpu = var.worker_node_min_count * local.cpu_per_node
  required_mem = var.worker_node_min_count * local.mem_per_node

# 2. get profiles with a class name passed as a variable (NOTE: assuming VPC Gen2 provides a single profile per class)
  dh_profiles = var.dedicated_host_enabled ? [
    for p in data.ibm_is_dedicated_host_profiles.worker[0].profiles: p if p.class == local.profile_str[0]
  ]: []
  dh_profile_index = length(local.dh_profiles) == 0 ? "Profile class ${local.profile_str[0]} for dedicated hosts does not exist in ${local.region_name}. Check available class with `ibmcloud target -r ${local.region_name}; ibmcloud is dedicated-host-profiles` and retry other worker_node_instance_type wtih the available class.": 0
  dh_profile       = var.dedicated_host_enabled ? local.dh_profiles[local.dh_profile_index]: null
  dh_cpu           = var.dedicated_host_enabled ? tonumber(local.dh_profile.vcpu_count[0].value): 0
  dh_mem           = var.dedicated_host_enabled ? tonumber(local.dh_profile.memory[0].value): 0
# 3. calculate the number of dedicated hosts
  dh_count = var.dedicated_host_enabled ? ceil(max(local.required_cpu / local.dh_cpu, local.required_mem / local.dh_mem)): 0

# 4. calculate the possible number of workers, which is used by the pack placement
  dh_worker_count = var.dedicated_host_enabled ? floor(min(local.dh_cpu / local.cpu_per_node, local.dh_mem / local.mem_per_node)): 0
}

locals {
  script_map = {
    "storage" = file("${path.module}/scripts/user_data_input_storage.tpl")
    "controller"  = file("${path.module}/scripts/user_data_input_controller.tpl")
    "worker"  = file("${path.module}/scripts/user_data_input_worker.tpl")
    "spectrum_storage" = file("${path.module}/scripts/user_data_spectrum_storage.tpl")
  }
  storage_template_file = lookup(local.script_map, "storage")
  controller_template_file  = lookup(local.script_map, "controller")
  worker_template_file  = lookup(local.script_map, "worker")
  tags                  = ["hpcc", var.cluster_prefix]
  vcpus                 = tonumber(data.ibm_is_instance_profile.worker.vcpu_count[0].value)
  ncores                = local.vcpus / 2
  ncpus                 = var.hyperthreading_enabled ? local.vcpus : local.ncores
  memInMB               = tonumber(data.ibm_is_instance_profile.worker.memory[0].value) * 1024
  rc_maxNum             = var.worker_node_max_count > var.worker_node_min_count ? var.worker_node_max_count - var.worker_node_min_count : 0
}

locals {
  // Check whether an entry is found in the mapping file for the given symphony compute node image
  image_mapping_entry_found = contains(keys(local.image_region_map), var.image_name)
  new_image_id = local.image_mapping_entry_found ? lookup(lookup(local.image_region_map, var.image_name), local.region_name) : "Image not found with the given name"

#  new_image_id = contains(keys(local.image_region_map), var.image_name) ? lookup(lookup(local.image_region_map, var.image_name), local.region_name) : "Image not found with the given name"
  
  // Use existing VPC if var.vpc_name is not empty
  vpc_name = var.vpc_name == "" ? ibm_is_vpc.vpc.*.name[0] : data.ibm_is_vpc.existing_vpc.*.name[0]
}

data "ibm_is_image" "image" {
  name = var.image_name
  count = local.image_mapping_entry_found ? 0:1
}

data "template_file" "storage_user_data" {
  template = local.storage_template_file
  vars = {
    rc_cidr_block = ibm_is_subnet.subnet.ipv4_cidr_block
  }
}

data "template_file" "controller_user_data" {
  template = local.controller_template_file
  vars = {
    ls_entitlement                = var.ls_entitlement
    lsf_entitlement               = var.lsf_entitlement
    vpc_apikey_value              = var.api_key
    resource_records_apikey_value = var.api_key
    image_id                      = local.image_mapping_entry_found? local.new_image_id :data.ibm_is_image.image[0].id
    subnet_id                     = ibm_is_subnet.subnet.id
    security_group_id             = ibm_is_security_group.sg.id
    sshkey_id                     = data.ibm_is_ssh_key.ssh_key[local.ssh_key_list[0]].id
    region_name                   = data.ibm_is_region.region.name
    zone_name                     = data.ibm_is_zone.zone.name
    vpc_id                        = data.ibm_is_vpc.vpc.id
    rc_cidr_block                 = ibm_is_subnet.subnet.ipv4_cidr_block
    rc_profile                    = data.ibm_is_instance_profile.worker.name
    rc_ncores                     = local.ncores
    rc_ncpus                      = local.ncpus
    rc_memInMB                    = local.memInMB
    rc_maxNum                     = local.rc_maxNum
    rc_rg                         = data.ibm_resource_group.rg.id
    controller_ips                = join(" ", local.controller_ips)
    storage_ips                   = join(" ", local.storage_ips)
    hyperthreading                = var.hyperthreading_enabled
    temp_public_key               = local.vsi_login_temp_public_key
    scale_mount_point             = var.scale_compute_cluster_filesystem_mountpoint
    spectrum_scale                = var.spectrum_scale_enabled
  }
}

data "template_file" "worker_user_data" {
  template = local.worker_template_file
  vars = {
    rc_cidr_block  = ibm_is_subnet.subnet.ipv4_cidr_block
    controller_ips     = join(" ", local.controller_ips)
    storage_ips    = join(" ", local.storage_ips)
    hyperthreading = var.hyperthreading_enabled
    temp_public_key               = local.vsi_login_temp_public_key
    scale_mount_point             = var.scale_compute_cluster_filesystem_mountpoint
    spectrum_scale                = var.spectrum_scale_enabled
  }
}

data "http" "fetch_myip"{
  url = "http://ipv4.icanhazip.com"
}

resource "ibm_is_vpc" "vpc" {
  name           = "${var.cluster_prefix}-vpc"
  #name = local.new_vpc_name
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags
  // create new VPC resource only if var.vpc_name is empty
  count = var.vpc_name == "" ? 1:0
}

resource "ibm_is_public_gateway" "mygateway" {
  name           = "${var.cluster_prefix}-gateway"
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags

  timeouts {
    create = "90m"
  }
}

resource "ibm_is_subnet" "login_subnet" {
  name                     = "${var.cluster_prefix}-login-subnet"
  vpc                      = data.ibm_is_vpc.vpc.id
  zone                     = data.ibm_is_zone.zone.name
  total_ipv4_address_count = 16
  resource_group           = data.ibm_resource_group.rg.id
  tags                     = local.tags
}

resource "ibm_is_subnet" "subnet" {
  name                     = "${var.cluster_prefix}-subnet"
  vpc                      = data.ibm_is_vpc.vpc.id
  zone                     = data.ibm_is_zone.zone.name
  total_ipv4_address_count = local.total_ipv4_address_count
  public_gateway           = ibm_is_public_gateway.mygateway.id
  resource_group           = data.ibm_resource_group.rg.id
  tags                     = local.tags
}

resource "ibm_is_security_group" "login_sg" {
  name           = "${var.cluster_prefix}-login-sg"
  vpc            = data.ibm_is_vpc.vpc.id
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags
}


resource "ibm_is_security_group_rule" "login_ingress_tcp" {
  #for_each  = toset(var.ssh_allowed_ips)
  for_each  = toset(split(",", var.ssh_allowed_ips))
  group     = ibm_is_security_group.login_sg.id
  direction = "inbound"
  remote    = each.value

  tcp {
    port_min = 22
    port_max = 22
  }
  depends_on = [ibm_is_security_group.login_sg]
}

resource "ibm_is_security_group_rule" "login_ingress_tcp_rhsm" {
  for_each  = toset(split(",", var.ssh_allowed_ips))
  group     = ibm_is_security_group.login_sg.id
  direction = "inbound"
  remote    = "161.26.0.0/16"

  tcp {
    port_min = 1
    port_max = 65535
  }
}

resource "ibm_is_security_group_rule" "login_ingress_udp_rhsm" {
  for_each  = toset(split(",", var.ssh_allowed_ips))
  group     = ibm_is_security_group.login_sg.id
  direction = "inbound"
  remote    = "161.26.0.0/16"

  udp {
    port_min = 1
    port_max = 65535
  }
}

resource "ibm_is_security_group_rule" "login_egress_tcp" {
  group     = ibm_is_security_group.login_sg.id
  direction = "outbound"
  remote    = ibm_is_security_group.sg.id
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "login_egress_tcp_rhsm" {
  group     = ibm_is_security_group.login_sg.id
  direction = "outbound"
  remote    = "161.26.0.0/16"
  tcp {
    port_min = 1
    port_max = 65535
  }
}

resource "ibm_is_security_group_rule" "login_egress_udp_rhsm" {
  group     = ibm_is_security_group.login_sg.id
  direction = "outbound"
  remote    = "161.26.0.0/16"
  udp {
    port_min = 1
    port_max = 65535
  }
}

resource "ibm_is_security_group" "sg" {
  name           = "${var.cluster_prefix}-sg"
  vpc            = data.ibm_is_vpc.vpc.id
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags
}

resource "ibm_is_security_group_rule" "ingress_tcp" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  remote    = ibm_is_security_group.login_sg.id

  tcp {
    port_min = 22
    port_max = 22
  }
}

# Have to enable the outbound traffic here. Default is off
resource "ibm_is_security_group_rule" "egress_all" {
  group     = ibm_is_security_group.sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "ingress_all_local" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  remote    = ibm_is_security_group.sg.id
}

module "schematics_sg_tcp_rule" {
  count     = var.spectrum_scale_enabled ? 1 : 0
  source            = "./resources/ibmcloud/security"
  security_group_id = ibm_is_security_group.login_sg.id
  sg_direction      = "inbound"
  remote_ip_addr    = tolist(["${chomp(data.http.fetch_myip.response_body)}"])
  depends_on = [ibm_is_security_group.login_sg]
}

data "ibm_is_ssh_key" "ssh_key" {
  for_each = toset(split(",", var.ssh_key_name))
  name = each.value
}

data "ibm_is_instance_profile" "login" {
  name = var.login_node_instance_type
}

locals {
  stock_image_name = "ibm-centos-7-6-minimal-amd64-2"
}

data "ibm_is_image" "stock_image" {
  name = local.stock_image_name
}

locals{
      vsi_login_temp_public_key = var.spectrum_scale_enabled ? module.login_ssh_key.public_key.0 : ""
}

data "template_file" "login_user_data" {
  template = <<EOF
#!/usr/bin/env bash
if [ ${var.spectrum_scale_enabled} == true ]; then
  echo "${local.vsi_login_temp_public_key}" >> ~/.ssh/authorized_keys
fi
EOF
}

resource "ibm_is_instance" "login" {
  name           = "${var.cluster_prefix}-login"
  image          = data.ibm_is_image.stock_image.id
  profile        = data.ibm_is_instance_profile.login.name
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = local.ssh_key_id_list
  user_data      = data.template_file.login_user_data.rendered
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags

  # fip will be assinged
  primary_network_interface {
    name            = "eth0"
    subnet          = ibm_is_subnet.login_subnet.id
    security_groups = [ibm_is_security_group.login_sg.id]
  }
  depends_on = [
    module.login_ssh_key,
    ibm_is_security_group_rule.login_ingress_tcp,
    ibm_is_security_group_rule.login_ingress_tcp_rhsm,
    ibm_is_security_group_rule.login_ingress_udp_rhsm,
    ibm_is_security_group_rule.login_egress_tcp,
    ibm_is_security_group_rule.login_egress_tcp_rhsm,
    ibm_is_security_group_rule.login_egress_udp_rhsm
  ]
}

#####################################################################
#                       IP ADDRESS MAPPING
#####################################################################
# LSF assumes all the node IPs are known before their startup.
# This causes a cyclic dependency, e.g., controllers must know their IPs
# before starting themselves. We resolve this by explicitly
# assigining IP addresses calculated by cidrhost(cidr_block, index).
#
# Input variables:
# nrM    == var.management_node_count
# nrMinW == var.worker_node_min_count
# nrMaxW == var.worker_node_max_count
#
# Address index range                        | Mapped nodes
# -------------------------------------------------------------------
# 0                  - 3                     | Reserved by IBM Cloud
# 4                  - 4                     | Storage node
# 5                  - (5 + nrM - 1)         | Management nodes
# (5 + nrM)          - (5 + nrM + nrMinW - 1)| Static worker nodes
# (5 + nrM + nrMinW) - (5 + nrM + nrMaxW - 1)| Dynamic worker nodes
#
# Details of reserved IPs:
# https://cloud.ibm.com/docs/vpc?topic=vpc-about-networking-for-vpc
#
# We also reserve four IPs for VPN
# https://cloud.ibm.com/docs/vpc?topic=vpc-vpn-create-gateway
#####################################################################
locals {
  spectrum_storage_node_count = var.spectrum_scale_enabled ? var.scale_storage_node_count : 0
  total_ipv4_address_count = pow(2, ceil(log(local.spectrum_storage_node_count+ var.worker_node_max_count + var.management_node_count + 5 + 1 + 4, 2)))

  controller_reboot_tmp = file("${path.module}/scripts/LSF_server_reboot.sh")
  worker_reboot_tmp = file("${path.module}/scripts/LSF_server_reboot.sh")
  controller_reboot_str = replace(local.controller_reboot_tmp, "<LSF_CONTROLLER_OR_WORKER>", "lsf")
  worker_reboot_str = replace(local.worker_reboot_tmp, "<LSF_CONTROLLER_OR_WORKER>", "lsf_worker")

  storage_ips = [
    for idx in range(1) :
    cidrhost(ibm_is_subnet.subnet.ipv4_cidr_block, idx + 4)
  ]
  spectrum_storage_ips = [
    for idx in range(local.spectrum_storage_node_count) :
    cidrhost(ibm_is_subnet.subnet.ipv4_cidr_block, idx + 4 + length(local.storage_ips))
  ]
  controller_ips = [
    for idx in range(var.management_node_count) :
    cidrhost(ibm_is_subnet.subnet.ipv4_cidr_block, idx + 4 + length(local.storage_ips) + length(local.spectrum_storage_ips))
  ]
  worker_ips = [
    for idx in range(var.worker_node_min_count) :
    cidrhost(ibm_is_subnet.subnet.ipv4_cidr_block, idx + 4 + length(local.storage_ips) + length(local.spectrum_storage_ips) + length(local.controller_ips))
  ]
  validate_worker_cnd = var.worker_node_min_count <= var.worker_node_max_count
  validate_worker_msg = "worker_node_max_count has to be greater or equal to worker_node_min_count"
  validate_worker_chk = regex(
      "^${local.validate_worker_msg}$",
      ( local.validate_worker_cnd
        ? local.validate_worker_msg
        : "" ) )

  ssh_key_list = split(",", var.ssh_key_name)
  ssh_key_id_list = [
    for name in local.ssh_key_list:
    data.ibm_is_ssh_key.ssh_key[name].id
  ]
}

resource "ibm_is_instance" "storage" {
  count          = 1
  name           = "${var.cluster_prefix}-storage-${count.index}"
  image          = data.ibm_is_image.stock_image.id
  profile        = data.ibm_is_instance_profile.storage.name
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = local.ssh_key_id_list
  resource_group = data.ibm_resource_group.rg.id
  user_data      = "${data.template_file.storage_user_data.rendered} ${file("${path.module}/scripts/user_data_storage.sh")}"
  volumes        = [ibm_is_volume.nfs.id]
  tags           = local.tags
  primary_network_interface {
    name                 = "eth0"
    subnet               = ibm_is_subnet.subnet.id
    security_groups      = [ibm_is_security_group.sg.id]
    primary_ipv4_address = local.storage_ips[count.index]
  }
  depends_on = [
    ibm_is_security_group_rule.ingress_tcp,
    ibm_is_security_group_rule.ingress_all_local,
    ibm_is_security_group_rule.egress_all,
  ]
}

resource "ibm_is_instance" "controller" {
  count          = 1
  name           = "${var.cluster_prefix}-controller-${count.index}"
  image          = local.image_mapping_entry_found? local.new_image_id :data.ibm_is_image.image[0].id
  profile        = data.ibm_is_instance_profile.controller.name
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = local.ssh_key_id_list
  resource_group = data.ibm_resource_group.rg.id
  user_data      = "${data.template_file.controller_user_data.rendered} ${file("${path.module}/scripts/LSF_management_static_server.sh")} ${local.controller_reboot_str}"
  tags           = local.tags
  primary_network_interface {
    name                 = "eth0"
    subnet               = ibm_is_subnet.subnet.id
    security_groups      = [ibm_is_security_group.sg.id]
    primary_ipv4_address = local.controller_ips[count.index]
  }
  depends_on = [
    module.login_ssh_key,
    ibm_is_instance.storage,
    ibm_is_security_group_rule.ingress_tcp,
    ibm_is_security_group_rule.ingress_all_local,
    ibm_is_security_group_rule.egress_all,
  ]
}

resource "ibm_is_instance" "controller_candidate" {
  count          = var.management_node_count - 1
  name           = "${var.cluster_prefix}-controller-candidate-${count.index}"
  image          = local.image_mapping_entry_found? local.new_image_id :data.ibm_is_image.image[0].id
  profile        = data.ibm_is_instance_profile.controller.name
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = local.ssh_key_id_list
  resource_group = data.ibm_resource_group.rg.id
  user_data      = "${data.template_file.controller_user_data.rendered} ${file("${path.module}/scripts/LSF_management_static_candidate_server.sh")} ${local.controller_reboot_str}"
  tags           = local.tags
  primary_network_interface {
    name                 = "eth0"
    subnet               = ibm_is_subnet.subnet.id
    security_groups      = [ibm_is_security_group.sg.id]
    primary_ipv4_address = local.controller_ips[count.index + 1]
  }
  depends_on = [
    module.login_ssh_key,
    ibm_is_instance.storage,
    ibm_is_instance.controller,
    ibm_is_security_group_rule.ingress_tcp,
    ibm_is_security_group_rule.ingress_all_local,
    ibm_is_security_group_rule.egress_all,
  ]
}

locals {
  metadata_startup_template_file = lookup(local.script_map, "spectrum_storage")
  scale_image_mapping_entry_found = contains(keys(local.scale_image_region_map), var.scale_storage_image_name)
  scale_image_id = local.scale_image_mapping_entry_found ? lookup(lookup(local.scale_image_region_map, var.scale_storage_image_name), local.region_name) : "Image not found with the given name"

#  scale_image_id = contains(keys(local.scale_image_region_map), var.scale_storage_image_name) ? lookup(lookup(local.scale_image_region_map, var.scale_storage_image_name), local.region_name) : "Image not found with the given name"
}


data "template_file" "metadata_startup_script" {
  template = local.metadata_startup_template_file
  vars = {
    temp_public_key = local.vsi_login_temp_public_key
    rc_cidr_block  = ibm_is_subnet.subnet.ipv4_cidr_block
    controller_ips     = join(" ", local.controller_ips)
    storage_ips    = join(" ", local.storage_ips)
    instance_profile_type = data.ibm_is_instance_profile.spectrum_scale_storage.disks.0.quantity.0.type
  }
}

data "ibm_is_instance_profile" "spectrum_scale_storage" {
  name = var.scale_storage_node_instance_type
}

data "ibm_is_image" "scale_image" {
  name = var.scale_storage_image_name
  count = local.scale_image_mapping_entry_found ? 0:1
}
resource "ibm_is_instance" "spectrum_scale_storage" {
  count          = var.spectrum_scale_enabled == true ? var.scale_storage_node_count : 0
  name           = "${var.cluster_prefix}-spectrum-storage-${count.index}"
  image          = local.scale_image_mapping_entry_found ? local.scale_image_id : data.ibm_is_image.scale_image[0].id
  profile        = data.ibm_is_instance_profile.spectrum_scale_storage.name
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = local.ssh_key_id_list
  resource_group = data.ibm_resource_group.rg.id
  user_data      = "${data.template_file.metadata_startup_script.rendered} ${data.template_file.storage_user_data.rendered} ${file("${path.module}/scripts/LSF_spectrum_storage.sh")}"
  tags           = local.tags
  primary_network_interface {
    name                 = "eth0"
    subnet               = ibm_is_subnet.subnet.id
    security_groups      = [ibm_is_security_group.sg.id]
    primary_ipv4_address = local.spectrum_storage_ips[count.index]
  }
  depends_on = [
    module.login_ssh_key,
    ibm_is_instance.storage,
    ibm_is_instance.controller,
    ibm_is_instance.login,
    ibm_is_security_group_rule.ingress_tcp,
    ibm_is_security_group_rule.ingress_all_local,
    ibm_is_security_group_rule.egress_all,
  ]
}


resource "ibm_is_instance" "worker" {
  count          = var.worker_node_min_count
  name           = "${var.cluster_prefix}-worker-${count.index}"
  image          = local.image_mapping_entry_found? local.new_image_id :data.ibm_is_image.image[0].id
  profile        = data.ibm_is_instance_profile.worker.name
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = local.ssh_key_id_list
  resource_group = data.ibm_resource_group.rg.id
  user_data      = "${data.template_file.worker_user_data.rendered} ${file("${path.module}/scripts/LSF_dynamic_workers.sh")} ${local.worker_reboot_str}"
  tags           = local.tags
  dedicated_host = var.dedicated_host_enabled ? ibm_is_dedicated_host.worker[var.dedicated_host_placement == "spread" ? count.index % local.dh_count: floor(count.index / local.dh_worker_count)].id: null
  primary_network_interface {
    name                 = "eth0"
    subnet               = ibm_is_subnet.subnet.id
    security_groups      = [ibm_is_security_group.sg.id]
    primary_ipv4_address = local.worker_ips[count.index]
  }
  depends_on = [
    module.login_ssh_key,
    ibm_is_instance.storage,
    ibm_is_instance.controller,
    ibm_is_instance.controller_candidate,
    ibm_is_security_group_rule.ingress_tcp,
    ibm_is_security_group_rule.ingress_all_local,
    ibm_is_security_group_rule.egress_all,
  ]
}

data "ibm_is_volume_profile" "nfs" {
  name = var.volume_profile
}

resource "ibm_is_volume" "nfs" {
  name           = "${var.cluster_prefix}-vm-nfs-volume"
  profile        = data.ibm_is_volume_profile.nfs.name
  iops           = data.ibm_is_volume_profile.nfs.name == "custom" ? var.volume_iops : null
  capacity       = var.volume_capacity
  zone           = data.ibm_is_zone.zone.name
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags
}

resource "ibm_is_floating_ip" "login_fip" {
  name           = "${var.cluster_prefix}-login-fip"
  target         = ibm_is_instance.login.primary_network_interface[0].id
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags

  lifecycle {
    ignore_changes = [resource_group]
  }
}

resource "ibm_is_vpn_gateway" "vpn" {
  count          = var.vpn_enabled ? 1: 0
  name           = "${var.cluster_prefix}-vpn"
  resource_group = data.ibm_resource_group.rg.id
  subnet         = ibm_is_subnet.login_subnet.id
  mode           = "policy"
  tags           = local.tags
}

locals {
  peer_cidr_list = var.vpn_enabled ? split(",", var.vpn_peer_cidrs): []
}

resource "ibm_is_vpn_gateway_connection" "conn" {
  count          = var.vpn_enabled ? 1: 0
  name           = "${var.cluster_prefix}-vpn-conn"
  vpn_gateway    = ibm_is_vpn_gateway.vpn[count.index].id
  peer_address   = var.vpn_peer_address
  preshared_key  = var.vpn_preshared_key
  admin_state_up = true
  local_cidrs    = [ibm_is_subnet.subnet.ipv4_cidr_block]
  peer_cidrs     = local.peer_cidr_list
}

resource "ibm_is_security_group_rule" "ingress_vpn" {
  count     = length(local.peer_cidr_list)
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  remote    = local.peer_cidr_list[count.index]
}

resource "ibm_is_dedicated_host_group" "worker" {
  count          = local.dh_count > 0 ? 1: 0
  name           = "${var.cluster_prefix}-dh"
  class          = local.dh_profile.class
  family         = local.dh_profile.family
  zone           = data.ibm_is_zone.zone.name
  resource_group = data.ibm_resource_group.rg.id
}

resource "ibm_is_dedicated_host" "worker" {
  count      = local.dh_count
  name       = "${var.cluster_prefix}-dh-${count.index}"
  profile    = local.dh_profile.name
  host_group = ibm_is_dedicated_host_group.worker[0].id
  resource_group = data.ibm_resource_group.rg.id
}

locals {
  tf_data_path              =  "/tmp/.schematics/IBM/tf_data_path"
  tf_input_json_root_path   = null
  tf_input_json_file_name   = null
  scale_version             = "5.1.3.1" # This is the scale version that is installed on the custom images
  cloud_platform            = "IBMCloud"
  scale_infra_repo_clone_path = "/tmp/.schematics/IBM/ibm-spectrumscale-cloud-deploy"
  storage_vsis_1A_by_ip = ibm_is_instance.spectrum_scale_storage[*].primary_network_interface[0]["primary_ipv4_address"]
  strg_vsi_ids_0_disks = ibm_is_instance.spectrum_scale_storage.*.id
  storage_vsi_ips_with_0_datadisks = local.storage_vsis_1A_by_ip
  vsi_data_volumes_count = 0
  strg_vsi_ips_0_disks_dev_map = {
    for instance in local.storage_vsi_ips_with_0_datadisks :
    instance => local.vsi_data_volumes_count == 0 ? data.ibm_is_instance_profile.spectrum_scale_storage.disks.0.quantity.0.value == 1 ? ["/dev/vdb"] : ["/dev/vdb", "/dev/vdc"] : null
  }
  total_compute_instances = var.management_node_count + var.worker_node_min_count
  compute_vsi_ids_0_disks = concat(ibm_is_instance.controller.*.id, ibm_is_instance.controller_candidate.*.id, ibm_is_instance.worker.*.id)
  compute_vsi_by_ip = concat(ibm_is_instance.controller[*].primary_network_interface[0]["primary_ipv4_address"], ibm_is_instance.controller_candidate[*].primary_network_interface[0]["primary_ipv4_address"], ibm_is_instance.worker[*].primary_network_interface[0]["primary_ipv4_address"])
  validate_scale_count_cnd =  !var.spectrum_scale_enabled || (var.spectrum_scale_enabled && (var.scale_storage_node_count > 1))
  validate_scale_count_msg = "Input \"scale_storage_node_count\" must be >= 2 and <= 18 and has to be divisible by 2."
  validate_scale_count_chk = regex(
      "^${local.validate_scale_count_msg}$",
      ( local.validate_scale_count_cnd
        ? local.validate_scale_count_msg
        : "" ) )
  validate_scale_worker_min_cnd =  !var.spectrum_scale_enabled || (var.spectrum_scale_enabled && (var.management_node_count + var.worker_node_min_count > 2 && var.worker_node_min_count > 0 && var.worker_node_min_count <= 64))
  validate_scale_worker_min_msg = "Input worker_node_min_count must be greater than 0 and less than or equal to 64 and total_quorum_node i.e, sum of management_node_count and worker_node_min_count should be greater than 2, if spectrum_scale_enabled set to true."
  validate_scale_worker_min_chk = regex(
      "^${local.validate_scale_worker_min_msg}$",
      ( local.validate_scale_worker_min_cnd
        ? local.validate_scale_worker_min_msg
        : "" ) )

  validate_scale_worker_max_cnd = !var.spectrum_scale_enabled || (var.spectrum_scale_enabled && (var.worker_node_min_count == var.worker_node_max_count))
  validate_scale_worker_max_msg = "If scale is enabled, Input worker_node_min_count must be equal to worker_node_max_count."
  validate_scale_worker_max_check = regex(
      "^${local.validate_scale_worker_max_msg}$",
      ( local.validate_scale_worker_max_cnd
        ? local.validate_scale_worker_max_msg
        : ""))

  //validate storage gui password
  validate_storage_gui_password_cnd = (var.spectrum_scale_enabled && (replace(lower(var.scale_storage_cluster_gui_password), lower(var.scale_storage_cluster_gui_username), "" ) == lower(var.scale_storage_cluster_gui_password)) && can(regex("^.{8,}$", var.scale_storage_cluster_gui_password) != "") && can(regex("[0-9]{1,}", var.scale_storage_cluster_gui_password) != "") && can(regex("[a-z]{1,}", var.scale_storage_cluster_gui_password) != "") && can(regex("[A-Z]{1,}",var.scale_storage_cluster_gui_password ) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.scale_storage_cluster_gui_password ) != "" )&& trimspace(var.scale_storage_cluster_gui_password) != "") || !var.spectrum_scale_enabled
  gui_password_msg = "Password should be at least 8 characters, must have one number, one lowercase letter, and one uppercase letter, at least one unique character. Password Should not contain username"
  validate_storage_gui_password_chk = regex(
          "^${local.gui_password_msg}$",
          ( local.validate_storage_gui_password_cnd ? local.gui_password_msg : "") )

  // validate compute gui password
  validate_compute_gui_password_cnd = (var.spectrum_scale_enabled && (replace(lower(var.scale_compute_cluster_gui_password), lower(var.scale_compute_cluster_gui_username),"") == lower(var.scale_compute_cluster_gui_password)) && can(regex("^.{8,}$", var.scale_compute_cluster_gui_password) != "") && can(regex("[0-9]{1,}", var.scale_compute_cluster_gui_password) != "") && can(regex("[a-z]{1,}", var.scale_compute_cluster_gui_password) != "") && can(regex("[A-Z]{1,}",var.scale_compute_cluster_gui_password ) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.scale_compute_cluster_gui_password ) != "" )&& trimspace(var.scale_compute_cluster_gui_password) != "") || !var.spectrum_scale_enabled
  validate_compute_gui_password_chk = regex(
          "^${local.gui_password_msg}$",
          ( local.validate_compute_gui_password_cnd ? local.gui_password_msg : ""))

  //validate scale storage gui user name
  validate_scale_storage_gui_username_cnd = (var.spectrum_scale_enabled && length(var.scale_storage_cluster_gui_username) >= 4 && length(var.scale_storage_cluster_gui_username) <= 32 && trimspace(var.scale_storage_cluster_gui_username) != "") || !var.spectrum_scale_enabled
  storage_gui_username_msg = "Specified input for \"storage_cluster_gui_username\" is not valid."
  validate_storage_gui_username_chk = regex(
          "^${local.storage_gui_username_msg}",
          (local.validate_scale_storage_gui_username_cnd? local.storage_gui_username_msg: ""))

  // validate compute gui username
  validate_compute_gui_username_cnd = (var.spectrum_scale_enabled && length(var.scale_compute_cluster_gui_username) >= 4 && length(var.scale_compute_cluster_gui_username) <= 32 && trimspace(var.scale_compute_cluster_gui_username) != "") || !var.spectrum_scale_enabled
  compute_gui_username_msg = "Specified input for \"compute_cluster_gui_username\" is not valid."
  validate_compute_gui_username_chk = regex(
          "^${local.compute_gui_username_msg}",
          (local.validate_compute_gui_username_cnd? local.compute_gui_username_msg: ""))

}

module "login_ssh_key" {
  source       = "./resources/scale_common/generate_keys"
  invoke_count = var.spectrum_scale_enabled ? 1:0
  tf_data_path = format("%s", local.tf_data_path)
}

// After completion of scale storage nodes, nodes need wait time to get in running state.
module "storage_nodes_wait" { # Setting up the variable time as 180s for the entire set of storage nodes, this approach is used to overcome the issue of ssh and nodes unreachable
  count         = (var.spectrum_scale_enabled && var.scale_storage_node_count > 0) ? 1 : 0
  source        = "./resources/scale_common/wait"
  wait_duration = var.TF_WAIT_DURATION
  depends_on    = [ibm_is_instance.spectrum_scale_storage]
}

// After completion of compute nodes, nodes need wait time to get in running state.
module "compute_nodes_wait" { # Setting up the variable time as 180s for the entire set of compute nodes, this approach is used to overcome the issue of ssh and nodes unreachable
  count         = (var.spectrum_scale_enabled && var.scale_storage_node_count > 0) ? 1 : 0
  source        = "./resources/scale_common/wait"
  wait_duration = var.TF_WAIT_DURATION
  depends_on    = [ibm_is_instance.controller,ibm_is_instance.controller_candidate, ibm_is_instance.worker]
}


// This module is used to clone ansible repo for scale.
module "prepare_spectrum_scale_ansible_repo" {
  count      = var.spectrum_scale_enabled ? 1 : 0
  source     = "./resources/scale_common/git_utils"
  branch     = "scale_cloud"
  tag        = null
  clone_path = local.scale_infra_repo_clone_path
}

module "invoke_storage_playbook" {
  count                            = (var.spectrum_scale_enabled && var.scale_storage_node_count > 0) ? 1 : 0
  source                           = "./resources/scale_common/ansible_storage_playbook"
  region                           = local.region_name
  stack_name                       = format("%s.%s", var.cluster_prefix, "storage")
  tf_data_path                     = local.tf_data_path
  tf_input_json_root_path          = local.tf_input_json_root_path == null ? abspath(path.cwd) : local.tf_input_json_root_path
  tf_input_json_file_name          = local.tf_input_json_file_name == null ? join(", ", fileset(abspath(path.cwd), "*.tfvars*")) : local.tf_input_json_file_name
  bastion_public_ip                = ibm_is_floating_ip.login_fip.address
  bastion_os_flavor                = data.ibm_is_image.stock_image.os
  bastion_ssh_private_key          = var.spectrum_scale_enabled ? module.login_ssh_key.private_key_path : ""
  scale_infra_repo_clone_path      = local.scale_infra_repo_clone_path
  clone_complete                   = var.spectrum_scale_enabled ? module.prepare_spectrum_scale_ansible_repo[0].clone_complete : false
  scale_version                    = local.scale_version
  filesystem_mountpoint            = var.scale_storage_cluster_filesystem_mountpoint
  filesystem_block_size            = var.scale_filesystem_block_size
  storage_cluster_gui_username     = var.scale_storage_cluster_gui_username
  storage_cluster_gui_password     = var.scale_storage_cluster_gui_password
  cloud_platform                   = local.cloud_platform
  avail_zones                      = jsonencode([var.zone])
  compute_instance_desc_map        = jsonencode([])
  compute_instance_desc_id         = jsonencode([])
  host                             = chomp(data.http.fetch_myip.response_body)
  storage_instances_by_id          = local.strg_vsi_ids_0_disks == null ? jsondecode([]) : jsonencode(local.strg_vsi_ids_0_disks)
  storage_instance_disk_map        = local.strg_vsi_ips_0_disks_dev_map == null ? jsondecode([]) : jsonencode(local.strg_vsi_ips_0_disks_dev_map)
  depends_on                       = [ module.login_ssh_key, module.prepare_spectrum_scale_ansible_repo, module.storage_nodes_wait ,ibm_is_instance.login, ibm_is_instance.spectrum_scale_storage]
}

module "invoke_compute_playbook" {
  count                            = (var.spectrum_scale_enabled && var.worker_node_min_count > 0) ? 1 : 0
  source                           = "./resources/scale_common/ansible_compute_playbook"
  region                           = local.region_name
  stack_name                       = format("%s.%s", var.cluster_prefix, "compute")
  tf_data_path                     = local.tf_data_path
  tf_input_json_root_path          = local.tf_input_json_root_path == null ? abspath(path.cwd) : local.tf_input_json_root_path
  tf_input_json_file_name          = local.tf_input_json_file_name == null ? join(", ", fileset(abspath(path.cwd), "*.tfvars*")) : local.tf_input_json_file_name
  bastion_public_ip                = ibm_is_floating_ip.login_fip.address
  bastion_os_flavor                = data.ibm_is_image.stock_image.os
  bastion_ssh_private_key          = var.spectrum_scale_enabled ? module.login_ssh_key.private_key_path : ""
  scale_infra_repo_clone_path      = local.scale_infra_repo_clone_path
  clone_complete                   = var.spectrum_scale_enabled ? module.prepare_spectrum_scale_ansible_repo[0].clone_complete : false
  scale_version                    = local.scale_version
  compute_filesystem_mountpoint    = var.scale_compute_cluster_filesystem_mountpoint
  compute_cluster_gui_username     = var.scale_compute_cluster_gui_username
  compute_cluster_gui_password     = var.scale_compute_cluster_gui_password
  cloud_platform                   = local.cloud_platform
  avail_zones                      = jsonencode([var.zone])
  compute_instances_by_id          = jsonencode(local.compute_vsi_ids_0_disks)
  host                             = chomp(data.http.fetch_myip.response_body)
  compute_instances_by_ip          = local.compute_vsi_by_ip == null ? jsonencode([]) : jsonencode(local.compute_vsi_by_ip)
  depends_on                       = [module.login_ssh_key, ibm_is_instance.controller, ibm_is_instance.controller_candidate, ibm_is_instance.worker, module.compute_nodes_wait]
}

// This module is used to invoke remote mount
module "invoke_remote_mount" {
  count                       = var.spectrum_scale_enabled ? 1 : 0
  source                      = "./resources/scale_common/ansible_remote_mount_playbook"
  scale_infra_repo_clone_path = local.scale_infra_repo_clone_path
  cloud_platform              = local.cloud_platform
  tf_data_path                = local.tf_data_path
  bastion_public_ip           = ibm_is_floating_ip.login_fip.address
  bastion_os_flavor           = data.ibm_is_image.stock_image.os
  bastion_ssh_private_key     = var.spectrum_scale_enabled ? module.login_ssh_key.private_key_path : ""
  total_compute_instances     = local.total_compute_instances
  total_storage_instances     = var.scale_storage_node_count
  host                        = chomp(data.http.fetch_myip.response_body)
  clone_complete              = var.spectrum_scale_enabled ? module.prepare_spectrum_scale_ansible_repo[0].clone_complete : false
  depends_on                  = [module.invoke_compute_playbook, module.invoke_storage_playbook, ibm_is_security_group.sg, ibm_is_security_group.login_sg]
}

module "permission_to_lsfadmin_for_mount_point" {
  count = var.spectrum_scale_enabled ? 1 : 0
  source = "./resources/scale_common/add_permission"
  bastion_ssh_private_key =  var.spectrum_scale_enabled ? module.login_ssh_key.private_key_path : ""
  compute_instances_by_ip = local.compute_vsi_by_ip == null ? jsonencode([]) : jsonencode(local.compute_vsi_by_ip)
  login_ip = ibm_is_floating_ip.login_fip.address
  scale_mount_point = var.scale_compute_cluster_filesystem_mountpoint
  depends_on = [module.invoke_remote_mount]
}

module "remove_ssh_key" {
  count = var.spectrum_scale_enabled ? 1 : 0
  source = "./resources/scale_common/remove_ssh"
  bastion_ssh_private_key = var.spectrum_scale_enabled ? module.login_ssh_key.private_key_path : ""
  compute_instances_by_ip = local.compute_vsi_by_ip == null ? jsonencode([]) : jsonencode(local.compute_vsi_by_ip)
  key_to_remove = var.spectrum_scale_enabled? module.login_ssh_key.public_key.0: ""
  login_ip = ibm_is_floating_ip.login_fip.address
  storage_vsis_1A_by_ip = jsonencode(local.storage_vsis_1A_by_ip)
  host = chomp(data.http.fetch_myip.response_body)
  depends_on = [module.permission_to_lsfadmin_for_mount_point, module.invoke_remote_mount]
}

data "ibm_iam_auth_token" "token" {}

resource "null_resource" "delete_schematics_ingress_security_rule" { # This code executes to refresh the IAM token, so during the execution we would have the latest token updated of IAM cloud so we can destroy the security group rule through API calls
  count     = var.spectrum_scale_enabled ? 1 : 0
  provisioner "local-exec" {
    environment = {
      REFRESH_TOKEN       = data.ibm_iam_auth_token.token.iam_refresh_token
      REGION              = local.region_name
      SECURITY_GROUP      = ibm_is_security_group.login_sg.id
      SECURITY_GROUP_RULE = module.schematics_sg_tcp_rule[0].security_rule_id[0]
    }
    command     = <<EOT
          echo $SECURITY_GROUP
          echo $SECURITY_GROUP_RULE
          TOKEN=$(
            echo $(
              curl -X POST "https://iam.cloud.ibm.com/identity/token" -H "Content-Type: application/x-www-form-urlencoded" -d "grant_type=refresh_token&refresh_token=$REFRESH_TOKEN" -u bx:bx
              ) | jq  -r .access_token
          )
          curl -X DELETE "https://$REGION.iaas.cloud.ibm.com/v1/security_groups/$SECURITY_GROUP/rules/$SECURITY_GROUP_RULE?version=2021-08-03&generation=2" -H "Authorization: $TOKEN"
        EOT
  }
  depends_on = [
    module.remove_ssh_key, module.schematics_sg_tcp_rule
  ]
}
