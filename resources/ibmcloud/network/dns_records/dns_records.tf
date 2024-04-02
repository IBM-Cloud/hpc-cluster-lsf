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

variable "instances" {}
variable "instance_id" {}
variable "zone_id" {}
variable "dns_domain" {}

locals {
  dns_record_ttl = 300
  instances      = flatten(var.instances)
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