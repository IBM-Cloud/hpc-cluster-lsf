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

variable "vpc" {}
variable "resource_group" {}
variable "tags" {}
variable "sec_group_name" {}


resource "ibm_is_security_group" "security_group" {
  name           = var.sec_group_name
  vpc            = var.vpc
  resource_group = var.resource_group
  tags           = var.tags
}


output "sg_id" {
  value = ibm_is_security_group.security_group.id
}