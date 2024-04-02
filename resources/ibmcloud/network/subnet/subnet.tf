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

variable "subnet_name" {}
variable "vpc" {}
variable "zone" {}
variable "vpc_cluster_private_subnets_cidr_blocks" {}
variable "public_gateway" {}
variable "resource_group" {}
variable "tags" {}

resource "ibm_is_subnet" "subnet" {
  name            = var.subnet_name
  vpc             = var.vpc
  zone            = var.zone
  ipv4_cidr_block = var.vpc_cluster_private_subnets_cidr_blocks
  public_gateway  = var.public_gateway
  resource_group  = var.resource_group
  tags            = var.tags
}

output "subnet_id" {
  value = ibm_is_subnet.subnet.id
}

output "ipv4_cidr_block" {
  value = ibm_is_subnet.subnet.ipv4_cidr_block
}

output "subnet_crn" {
  value = ibm_is_subnet.subnet.crn
}