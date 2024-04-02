#terraform {
#  required_providers {
#    ibm = {
#      source = "IBM-Cloud/ibm"
#    }
#  }
#}
#
#variable "name" {}
#variable "vpc" {}
#variable "zone" {}
#variable "total_ipv4_address_count" {}
#variable "resource_group" {}
#variable "tags" {}
#
#resource "ibm_is_subnet" "login_subnet" {
#  name                     = var.name
#  vpc                      = var.vpc
#  zone                     = var.zone
#  total_ipv4_address_count = var.total_ipv4_address_count
#  resource_group           = var.resource_group
#  tags                     = var.tags
#}
#
#output "login_subnet_id" {
#  value = ibm_is_subnet.login_subnet.id
#}
#
#output "ipv4_cidr_block" {
#  value = ibm_is_subnet.login_subnet.ipv4_cidr_block
#}

terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "login_subnet_name" {}
variable "vpc" {}
variable "zone" {}
variable "ipv4_cidr_block" {}
variable "resource_group" {}
variable "tags" {}

resource "ibm_is_subnet" "subnet" {
  name            = var.login_subnet_name
  vpc             = var.vpc
  zone            = var.zone
  ipv4_cidr_block = var.ipv4_cidr_block
  resource_group  = var.resource_group
  tags            = var.tags
}

output "login_subnet_id" {
  value = ibm_is_subnet.subnet.id
}

output "ipv4_cidr_block" {
  value = ibm_is_subnet.subnet.ipv4_cidr_block
}

output "subnet_crn" {
  value = ibm_is_subnet.subnet.crn
}