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

variable "vpc_flow_log_name" {}
variable "target_id" {}
variable "is_active" {}
variable "storage_bucket" {}
variable "resource_group" {}
variable "tags" {}

resource "ibm_is_flow_log" "itself" {
  name           = var.vpc_flow_log_name
  target         = var.target_id
  active         = var.is_active
  storage_bucket = var.storage_bucket
  resource_group = var.resource_group
  tags           = var.tags
}

output "id" {
  value = ibm_is_flow_log.itself.*.id
}