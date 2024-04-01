###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

/*
  Resource block is used to create Security Group used Login Node
*/

terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "vpc" {}
variable "resource_group" {}
variable "tags" {}
variable "name" {}

resource "ibm_is_security_group" "login_sg" {
  name           = var.name
  vpc            = var.vpc
  resource_group = var.resource_group
  tags           = var.tags
}

/*
  As we are not using count or for_each, no need to use [*]. Single element of the security group id can be fetched from below output form
*/

output "sec_group_id" {
  value = ibm_is_security_group.login_sg.id
}