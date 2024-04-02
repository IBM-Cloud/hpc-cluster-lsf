

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

/*
   Add custom resolver to IBM Cloud DNS resource instance.
*/

terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "customer_resolver_name" {}
variable "instance_guid" {}
variable "description" {}
variable "subnet_crn" {}
variable "dns_custom_resolver_id" {}


resource "ibm_dns_custom_resolver" "itself" {
  count             = var.dns_custom_resolver_id == "" ? 1 : 0
  name              = format("%s-dnsresolver", var.customer_resolver_name)
  instance_id       = var.instance_guid
  description       = var.description
  high_availability = false
  enabled           = true
  locations {
    subnet_crn = var.subnet_crn
    enabled    = true
  }
}

output "custom_resolver_id" {
  value = var.dns_custom_resolver_id == "" ? ibm_dns_custom_resolver.itself[0].custom_resolver_id : var.dns_custom_resolver_id
}
