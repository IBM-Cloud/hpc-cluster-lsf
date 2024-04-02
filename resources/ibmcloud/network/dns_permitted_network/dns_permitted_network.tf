###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

/*
   Add Permitted_network to IBM Cloud DNS Zone.
*/

terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "instance_id" {}
variable "zone_id" {}
variable "vpc_crn" {}


resource "ibm_dns_permitted_network" "itself" {
  instance_id = var.instance_id
  zone_id     = var.zone_id
  vpc_crn     = var.vpc_crn
  type        = "vpc"
}

output "permitted_network_id" {
  value = ibm_dns_permitted_network.itself.id
}