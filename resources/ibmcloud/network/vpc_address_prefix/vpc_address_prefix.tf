###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

/*
    Creates new IBM VPC address prefixes.
*/

/*
Note: On this file we are using is_default set as true, as our main.tf file uses total_ipv4_address_count to calculate the required subnet size
As per the design of terraform, to automatically calculate the subnets (total_ipv4_address_count) we want one of the CIDR block to be set as default..
Setting is_default set to true create a CIDR as default and our logic of auto calculation for subnet would work
*/

terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "vpc_id" {}
variable "address_name" {}
variable "zones" {}
variable "cidr_block" {}

resource "ibm_is_vpc_address_prefix" "itself" {
  count      = length(var.cidr_block)
  name       = var.address_name
  zone       = var.zones
  vpc        = var.vpc_id
  is_default = true
  cidr       = element(var.cidr_block, count.index)
}
#Expose the VPC address prefix id to the parent module
output "vpc_addr_prefix_id" {
  value = ibm_is_vpc_address_prefix.itself.*.id
}