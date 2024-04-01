###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

/*
    Creates IBM Cloud DNS Zone.
*/

terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "dns_domain" {}
variable "dns_service_id" {}
variable "description" {}
variable "dns_label" {}

resource "ibm_dns_zone" "itself" {
  name        = var.dns_domain
  instance_id = var.dns_service_id
  description = var.description
  label       = var.dns_label
}

output "id" {
  value = ibm_dns_zone.itself.zone_id
}