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
variable "vpn_gateway" {}
variable "vpn_peer_address" {}
variable "vpn_preshared_key" {}
variable "admin_state_up" {}
variable "local_cidrs" {}
variable "peer_cidrs" {}


resource "ibm_is_vpn_gateway_connection" "vpn_connection" {

  name           = var.name
  vpn_gateway    = var.vpn_gateway
  peer_address   = var.vpn_peer_address
  preshared_key  = var.vpn_preshared_key
  admin_state_up = var.admin_state_up
  local_cidrs    = var.local_cidrs
  peer_cidrs     = var.peer_cidrs
}