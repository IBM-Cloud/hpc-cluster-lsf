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

variable "floating_ip_name" {}
variable "target_network_id" {}
variable "resource_group" {}
variable "tags" {}


resource "ibm_is_floating_ip" "login_fip" {
  name           = var.floating_ip_name
  target         = var.target_network_id
  resource_group = var.resource_group
  tags           = var.tags

  lifecycle {
    ignore_changes = [resource_group]
  }
}

output "floating_ip_address" {
  value = ibm_is_floating_ip.login_fip.address
}