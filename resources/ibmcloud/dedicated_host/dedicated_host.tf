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
variable "profile" {}
variable "host_group" {}
variable "resource_group" {}

resource "ibm_is_dedicated_host" "worker" {

  name           = var.name
  profile        = var.profile
  host_group     = var.host_group
  resource_group = var.resource_group
}

output "dedicated_host_id" {
  value = ibm_is_dedicated_host.worker.id
}