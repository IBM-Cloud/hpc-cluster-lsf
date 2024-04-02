terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "name" {}
variable "size" {}
variable "zone" {}
variable "encryption_key_crn" {}
variable "security_groups" {}
variable "subnet_id" {}
variable "iops" {}
variable "tags" {}
variable "resource_group" {}


resource "ibm_is_share" "share" {
  name                = var.name
  access_control_mode = "security_group"
  size                = var.size
  iops                = var.iops
  profile             = "dp2"
  resource_group      = var.resource_group
  zone                = var.zone
  encryption_key      = var.encryption_key_crn
  tags                = var.tags
}

resource "ibm_is_share_mount_target" "share_target" {
  share = ibm_is_share.share.id
  name  = "${var.name}-mount-target"
  virtual_network_interface {
    primary_ip {
      name = "${var.name}-pip"
    }
    subnet          = var.subnet_id
    name            = "${var.name}-fileshare-vni"
    security_groups = var.security_groups
    resource_group  = var.resource_group
  }
}

output "mount_path" {
  value = ibm_is_share_mount_target.share_target.mount_path
}
