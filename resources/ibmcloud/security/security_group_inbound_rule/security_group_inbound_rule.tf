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
variable "remote" {}

resource "ibm_is_security_group_rule" "ingress_tcp" {
  group     = var.group
  direction = "inbound"
  remote    = var.remote

  tcp {
    port_min = 22
    port_max = 22
  }
}


resource "ibm_is_security_group_rule" "ingress_icmp" {
  group     = var.group
  direction = "inbound"
  remote    = "0.0.0.0/0"
  icmp {
    code = 0
    type = 8
  }
}