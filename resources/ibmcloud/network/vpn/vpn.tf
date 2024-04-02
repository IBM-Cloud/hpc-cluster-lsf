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

variable "name" {}
variable "resource_group" {}
variable "subnet" {}
variable "mode" {}
variable "tags" {}

resource "ibm_is_vpn_gateway" "vpn_gateway" {
  name           = var.name
  resource_group = var.resource_group
  subnet         = var.subnet
  mode           = var.mode
  tags           = var.tags
}

output "vpn_gateway_id" {
  value = ibm_is_vpn_gateway.vpn_gateway.id
}

output "vpn_gateway_public_ip_address" {
  value = ibm_is_vpn_gateway.vpn_gateway.public_ip_address
}