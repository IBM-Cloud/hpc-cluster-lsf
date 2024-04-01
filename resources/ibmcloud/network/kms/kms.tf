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

variable "resource_instance_name" {}
variable "resource_group" {}
variable "enable_customer_managed_encryption" {}
variable "kms_instance_id" {}
variable "kms_key_name" {}
variable "tags" {}
variable "region" {}

resource "ibm_resource_instance" "kms_instance" {
  count             = (var.enable_customer_managed_encryption == true && var.kms_instance_id == "") ? 1 : 0
  name              = format("%s-kms", var.resource_instance_name)
  service           = "kms"
  plan              = "tiered-pricing"
  location          = var.region
  resource_group_id = var.resource_group
  tags              = var.tags
#   parameters = {
#     allowed_network : local.service_endpoints
#   }
}

locals {
  kms_instance_id = (var.enable_customer_managed_encryption == true && var.kms_instance_id == "") ? ibm_resource_instance.kms_instance[0].guid : var.kms_instance_id
}

resource "ibm_kms_key" "kms_key" {
  count        = (var.enable_customer_managed_encryption == true && var.kms_key_name == "") ? 1 : 0
  instance_id  = local.kms_instance_id
  key_name     = format("%s-key", var.resource_instance_name)
  standard_key = false
  force_delete = false
}

locals {
  kms_key_name = (var.enable_customer_managed_encryption == true && var.kms_key_name == "") ? format("%s-key", var.resource_instance_name) : var.kms_key_name
}

resource "ibm_iam_authorization_policy" "block_storage_policy" {
  count                       = var.enable_customer_managed_encryption == true && var.kms_instance_id == "" ? 1 : 0
  source_service_name         = "server-protect"
  target_service_name         = "kms"
  target_resource_instance_id = (var.enable_customer_managed_encryption == true && var.kms_instance_id == "") ? ibm_resource_instance.kms_instance[0].guid : null
  roles                       = ["Reader"]
  description                 = "Allow block storage volumes to be encrypted by Key Management instance."
}

data "ibm_kms_key" "kms_key" {
  count       = var.enable_customer_managed_encryption ? 1 : 0
  instance_id = local.kms_instance_id
  key_name    = local.kms_key_name
  depends_on = [
    resource.ibm_resource_instance.kms_instance,
    resource.ibm_kms_key.kms_key,
    resource.ibm_iam_authorization_policy.block_storage_policy
  ]  
}

output "encryption_key_crn" {
  value = var.enable_customer_managed_encryption == true ? data.ibm_kms_key.kms_key[0].keys[0].crn : ""
}