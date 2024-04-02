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

variable "group" {}

resource "ibm_is_security_group_rule" "egress_all" {
  group     = var.group
  direction = "outbound"
  remote    = "0.0.0.0/0"
}