###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "vsi_name" {}
variable "image" {}
variable "profile" {}
variable "vpc" {}
variable "zone" {}
variable "keys" {}
variable "user_data" {}
variable "resource_group" {}
variable "tags" {}
variable "subnet_id" {}
variable "security_group" {}
variable "instance_id" {}
variable "zone_id" {}
variable "dns_domain" {}
variable "encryption_key_crn" {}

data "ibm_is_instance_profile" "itself" {
  name = var.profile
}

resource "ibm_is_instance" "spectrum_scale_storage" {

  name           = var.vsi_name
  image          = var.image
  profile        = var.profile
  vpc            = var.vpc
  zone           = var.zone
  keys           = var.keys
  resource_group = var.resource_group
  user_data      = var.user_data
  tags           = var.tags
  primary_network_interface {
    name            = "eth0"
    subnet          = var.subnet_id
    security_groups = var.security_group
  }
  boot_volume {
    encryption = var.encryption_key_crn
  }
}

locals {
  instance = [{
    name                      = var.vsi_name
    primary_network_interface = ibm_is_instance.spectrum_scale_storage.primary_network_interface[0].primary_ip.0.address
    }
  ]
  dns_record_ttl = 300
  instances      = flatten(local.instance)
}

// Support lookup by fully qualified domain name
resource "ibm_dns_resource_record" "dns_record_record_a" {
  for_each = {
    for instance in local.instances : instance.name => instance.primary_network_interface
  }

  instance_id = var.instance_id
  zone_id     = var.zone_id
  type        = "A"
  name        = each.key
  rdata       = each.value
  ttl         = local.dns_record_ttl
}

// Support lookup by ip address returning fully qualified domain name
resource "ibm_dns_resource_record" "dns_resource_record_ptr" {
  for_each = {
    for instance in local.instances : instance.name => instance.primary_network_interface
  }

  instance_id = var.instance_id
  zone_id     = var.zone_id
  type        = "PTR"
  name        = each.value
  rdata       = format("%s.%s", each.key, var.dns_domain)
  ttl         = local.dns_record_ttl
  depends_on  = [ibm_dns_resource_record.dns_record_record_a]
}

output "spectrum_scale_storage_id" {
  value      = ibm_is_instance.spectrum_scale_storage.id
  depends_on = [ibm_dns_resource_record.dns_record_record_a, ibm_dns_resource_record.dns_resource_record_ptr]
}

output "primary_network_interface" {
  value      = ibm_is_instance.spectrum_scale_storage.primary_network_interface[0].primary_ip.0.address
  depends_on = [ibm_dns_resource_record.dns_record_record_a, ibm_dns_resource_record.dns_resource_record_ptr]
}

output "name" {
  value      = ibm_is_instance.spectrum_scale_storage.name
  depends_on = [ibm_dns_resource_record.dns_record_record_a, ibm_dns_resource_record.dns_resource_record_ptr]
}

output "instance_ips_with_vol_mapping" {
  value = try(toset({ for instance_details in ibm_is_instance.spectrum_scale_storage : instance_details.primary_network_interface.0.primary_ip.0.address =>
  data.ibm_is_instance_profile.itself.disks[0].quantity[0].value == 1 ? ["/dev/vdb"] : ["/dev/vdb", "/dev/vdc"] }), [])
  depends_on = [ibm_dns_resource_record.dns_record_record_a, ibm_dns_resource_record.dns_resource_record_ptr]
}