terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "name" {}
variable "image" {}
variable "profile" {}
variable "vpc" {}
variable "zone" {}
variable "keys" {}
variable "user_data" {}
variable "resource_group" {}
variable "tags" {}
variable "subnet_id" {}
variable "security_group" {}
variable "instance_id" {}
variable "zone_id" {}
variable "dns_domain" {}
variable "encryption_key_crn" {}

resource "ibm_is_instance" "itself" {
  name           = var.name
  image          = var.image
  profile        = var.profile
  vpc            = var.vpc
  zone           = var.zone
  keys           = var.keys
  resource_group = var.resource_group
  user_data      = var.user_data
  tags           = var.tags
  primary_network_interface {
    subnet          = var.subnet_id
    security_groups = var.security_group
  }
  boot_volume {
    encryption = var.encryption_key_crn
  }
}

locals {
  instance = [{
    name                      = var.name
    primary_network_interface = ibm_is_instance.itself.primary_network_interface[0].primary_ip.0.address
    }
  ]
  dns_record_ttl = 300
  instances      = flatten(local.instance)
}

// Support lookup by fully qualified domain name
resource "ibm_dns_resource_record" "dns_record_record_a" {
  for_each = {
    for instance in local.instances : instance.name => instance.primary_network_interface
  }

  instance_id = var.instance_id
  zone_id     = var.zone_id
  type        = "A"
  name        = each.key
  rdata       = each.value
  ttl         = local.dns_record_ttl
}

// Support lookup by ip address returning fully qualified domain name
resource "ibm_dns_resource_record" "dns_resource_record_ptr" {
  for_each = {
    for instance in local.instances : instance.name => instance.primary_network_interface
  }

  instance_id = var.instance_id
  zone_id     = var.zone_id
  type        = "PTR"
  name        = each.value
  rdata       = format("%s.%s", each.key, var.dns_domain)
  ttl         = local.dns_record_ttl
  depends_on  = [ibm_dns_resource_record.dns_record_record_a]
}

output "id" {
  value = ibm_is_instance.itself.id
}

output "primary_network_interface_id" {
  value = ibm_is_instance.itself.primary_network_interface[0].id
}

output "primary_network_interface_address" {
  value = ibm_is_instance.itself.primary_network_interface[0].primary_ip.0.address
}
