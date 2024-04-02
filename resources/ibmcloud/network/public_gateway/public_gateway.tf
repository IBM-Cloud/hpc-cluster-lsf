terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "name" {}
variable "vpc" {}
variable "zone" {}
variable "resource_group" {}
variable "tags" {}

resource "ibm_is_public_gateway" "public_gateway" {
  name           = var.name
  vpc            = var.vpc
  zone           = var.zone
  resource_group = var.resource_group
  tags           = var.tags

  timeouts {
    create = "90m"
  }
}

output "public_gateway_id" {
  value = ibm_is_public_gateway.public_gateway.id
}