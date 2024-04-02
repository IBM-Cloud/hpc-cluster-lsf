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
variable "tags" {}
variable "vpc_address_prefix_management" {}

resource "ibm_is_vpc" "vpc" {
  name                      = var.name
  resource_group            = var.resource_group
  tags                      = var.tags
  address_prefix_management = var.vpc_address_prefix_management
}
#Expose the VPC name to the parent module
output "name" {
  value = ibm_is_vpc.vpc.name
}

#Expose the VPC id to the parent module
output "vpc_id" {
  value = ibm_is_vpc.vpc.id
}