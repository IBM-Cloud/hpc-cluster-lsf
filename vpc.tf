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
  name = var.region
}

data "ibm_is_zone" "zone" {
  name   = var.zone
  region = data.ibm_is_region.region.name
}

data "ibm_is_instance_profile" "master" {
  name = var.management_node_instance_type
}

data "ibm_is_instance_profile" "worker" {
  name = var.worker_node_instance_type
}

data "ibm_is_instance_profile" "storage" {
  name = var.storage_node_instance_type
}

locals {
  script_map = {
    "storage" = file("${path.module}/templates/user_data_input_storage.tpl")
    "master"  = file("${path.module}/templates/user_data_input_master.tpl")
    "worker"  = file("${path.module}/templates/user_data_input_worker.tpl")
  }
  storage_template_file = lookup(local.script_map, "storage")
  master_template_file  = lookup(local.script_map, "master")
  worker_template_file  = lookup(local.script_map, "worker")
  tags                  = ["hpcc", var.cluster_prefix]
  profile_str           = split("-", data.ibm_is_instance_profile.worker.name)
  profile_list          = split("x", local.profile_str[1])
  ncores                = tonumber(local.profile_list[0]) / 2
  memInMB               = tonumber(local.profile_list[1]) * 1024
  rc_maxNum             = var.worker_node_max_count > var.worker_node_min_count ? var.worker_node_max_count - var.worker_node_min_count : 0
}

locals {
  new_image_id = contains(keys(local.image_region_map), var.image_name) ? lookup(lookup(local.image_region_map, var.image_name), var.region) : data.ibm_is_image.image.id
}


data "template_file" "storage_user_data" {
  template = local.storage_template_file
  vars = {
    rc_cidr_block = ibm_is_subnet.subnet.ipv4_cidr_block
  }
}

data "template_file" "master_user_data" {
  template = local.master_template_file
  vars = {
    ls_entitlement                = var.ls_entitlement
    lsf_entitlement               = var.lsf_entitlement
    vpc_apikey_value              = var.api_key
    resource_records_apikey_value = var.api_key
    image_id                      = local.new_image_id
    subnet_id                     = ibm_is_subnet.subnet.id
    security_group_id             = ibm_is_security_group.sg.id
    sshkey_id                     = data.ibm_is_ssh_key.ssh_key.id
    region_name                   = data.ibm_is_region.region.name
    zone_name                     = data.ibm_is_zone.zone.name
    vpc_id                        = ibm_is_vpc.vpc.id
    rc_cidr_block                 = ibm_is_subnet.subnet.ipv4_cidr_block
    rc_profile                    = data.ibm_is_instance_profile.worker.name
    rc_ncores                     = local.ncores
    rc_memInMB                    = local.memInMB
    rc_maxNum                     = local.rc_maxNum
    master_ips                    = join(" ", local.master_ips)
    worker_ips                    = join(" ", local.worker_ips)
    storage_ips                   = join(" ", local.storage_ips)
  }
}

data "template_file" "worker_user_data" {
  template = local.worker_template_file
  vars = {
    rc_cidr_block = ibm_is_subnet.subnet.ipv4_cidr_block
    master_ips    = join(" ", local.master_ips)
    storage_ips   = join(" ", local.storage_ips)
  }
}

resource "ibm_is_vpc" "vpc" {
  name           = "${var.cluster_prefix}-vpc"
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags
}

resource "ibm_is_public_gateway" "mygateway" {
  name           = "${var.cluster_prefix}-gateway"
  vpc            = ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags

  timeouts {
    create = "90m"
  }
}

resource "ibm_is_subnet" "login_subnet" {
  name                     = "${var.cluster_prefix}-login-subnet"
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = data.ibm_is_zone.zone.name
  total_ipv4_address_count = 16
  resource_group           = data.ibm_resource_group.rg.id
  tags                     = local.tags
}

resource "ibm_is_subnet" "subnet" {
  name                     = "${var.cluster_prefix}-subnet"
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = data.ibm_is_zone.zone.name
  total_ipv4_address_count = local.total_ipv4_address_count
  public_gateway           = ibm_is_public_gateway.mygateway.id
  resource_group           = data.ibm_resource_group.rg.id
  tags                     = local.tags
}

resource "ibm_is_security_group" "login_sg" {
  name           = "${var.cluster_prefix}-login-sg"
  vpc            = ibm_is_vpc.vpc.id
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
  vpc            = ibm_is_vpc.vpc.id
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

data "ibm_is_image" "image" {
  name = var.image_name
}

data "ibm_is_ssh_key" "ssh_key" {
  name = var.ssh_key_name
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

resource "ibm_is_instance" "login" {
  name           = "${var.cluster_prefix}-login"
  image          = data.ibm_is_image.stock_image.id
  profile        = data.ibm_is_instance_profile.login.name
  vpc            = ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = [data.ibm_is_ssh_key.ssh_key.id]
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags

  # fip will be assinged
  primary_network_interface {
    name            = "eth0"
    subnet          = ibm_is_subnet.login_subnet.id
    security_groups = [ibm_is_security_group.login_sg.id]
  }
  depends_on = [
    ibm_is_security_group_rule.ingress_tcp,
    ibm_is_security_group_rule.ingress_all_local,
    ibm_is_security_group_rule.egress_all,
  ]
}

#####################################################################
#                       IP ADDRESS MAPPING
#####################################################################
# LSF assumes all the node IPs are known before their startup.
# This causes a cyclic dependency, e.g., masters must know their IPs
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
  total_ipv4_address_count = pow(2, ceil(log(var.worker_node_max_count + var.management_node_count + 5 + 1 + 4, 2)))

  master_reboot_tmp = file("${path.module}/scripts/LSF_server_reboot.sh")
  worker_reboot_tmp = file("${path.module}/scripts/LSF_server_reboot.sh")
  master_reboot_str = replace(local.master_reboot_tmp, "<LSF_MASTER_OR_WORKER>", "lsf")
  worker_reboot_str = replace(local.worker_reboot_tmp, "<LSF_MASTER_OR_WORKER>", "lsf_worker")

  storage_ips = [
    for idx in range(1) :
    cidrhost(ibm_is_subnet.subnet.ipv4_cidr_block, idx + 4)
  ]

  master_ips = [
    for idx in range(var.management_node_count) :
    cidrhost(ibm_is_subnet.subnet.ipv4_cidr_block, idx + 4 + length(local.storage_ips))
  ]

  worker_ips = [
    for idx in range(var.worker_node_min_count) :
    cidrhost(ibm_is_subnet.subnet.ipv4_cidr_block, idx + 4 + length(local.storage_ips) + length(local.master_ips))
  ]

  validate_worker_cnd = var.worker_node_min_count <= var.worker_node_max_count
  validate_worker_msg = "worker_node_max_count has to be greater or equal to worker_node_min_count"
  validate_worker_chk = regex(
      "^${local.validate_worker_msg}$",
      ( local.validate_worker_cnd
        ? local.validate_worker_msg
        : "" ) )
}

resource "ibm_is_instance" "storage" {
  count          = 1
  name           = "${var.cluster_prefix}-storage-${count.index}"
  image          = data.ibm_is_image.stock_image.id
  profile        = data.ibm_is_instance_profile.storage.name
  vpc            = ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = [data.ibm_is_ssh_key.ssh_key.id]
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

resource "ibm_is_instance" "master" {
  count          = 1
  name           = "${var.cluster_prefix}-master-${count.index}"
  image          = local.new_image_id
  profile        = data.ibm_is_instance_profile.master.name
  vpc            = ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = [data.ibm_is_ssh_key.ssh_key.id]
  resource_group = data.ibm_resource_group.rg.id
  user_data      = "${data.template_file.master_user_data.rendered} ${file("${path.module}/scripts/LSF_management_static_server.sh")} ${local.master_reboot_str}"
  tags           = local.tags
  primary_network_interface {
    name                 = "eth0"
    subnet               = ibm_is_subnet.subnet.id
    security_groups      = [ibm_is_security_group.sg.id]
    primary_ipv4_address = local.master_ips[count.index]
  }
  depends_on = [
    ibm_is_instance.storage,
    ibm_is_security_group_rule.ingress_tcp,
    ibm_is_security_group_rule.ingress_all_local,
    ibm_is_security_group_rule.egress_all,
  ]
}

resource "ibm_is_instance" "master_candidate" {
  count          = var.management_node_count - 1
  name           = "${var.cluster_prefix}-master-candidate-${count.index}"
  image          = local.new_image_id
  profile        = data.ibm_is_instance_profile.master.name
  vpc            = ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = [data.ibm_is_ssh_key.ssh_key.id]
  resource_group = data.ibm_resource_group.rg.id
  user_data      = "${data.template_file.master_user_data.rendered} ${file("${path.module}/scripts/LSF_management_static_candidate_server.sh")} ${local.master_reboot_str}"
  tags           = local.tags
  primary_network_interface {
    name                 = "eth0"
    subnet               = ibm_is_subnet.subnet.id
    security_groups      = [ibm_is_security_group.sg.id]
    primary_ipv4_address = local.master_ips[count.index + 1]
  }
  depends_on = [
    ibm_is_instance.storage,
    ibm_is_instance.master,
    ibm_is_security_group_rule.ingress_tcp,
    ibm_is_security_group_rule.ingress_all_local,
    ibm_is_security_group_rule.egress_all,
  ]
}


resource "ibm_is_instance" "worker" {
  count          = var.worker_node_min_count
  name           = "${var.cluster_prefix}-worker-${count.index}"
  image          = local.new_image_id
  profile        = data.ibm_is_instance_profile.worker.name
  vpc            = ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  keys           = [data.ibm_is_ssh_key.ssh_key.id]
  resource_group = data.ibm_resource_group.rg.id
  user_data      = "${data.template_file.worker_user_data.rendered} ${file("${path.module}/scripts/LSF_dynamic_workers.sh")} ${local.worker_reboot_str}"
  tags           = local.tags
  primary_network_interface {
    name                 = "eth0"
    subnet               = ibm_is_subnet.subnet.id
    security_groups      = [ibm_is_security_group.sg.id]
    primary_ipv4_address = local.worker_ips[count.index]
  }
  depends_on = [
    ibm_is_instance.storage,
    ibm_is_instance.master,
    ibm_is_instance.master_candidate,
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
