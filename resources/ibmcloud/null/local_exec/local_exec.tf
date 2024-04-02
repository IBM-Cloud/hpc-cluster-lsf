###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

/*
    This module used to run null for IBM Cloud CLIs
*/


variable "region" {}
variable "ibmcloud_api_key" {}
variable "command" {}
variable "trigger_resource_id" {}


resource "null_resource" "local_exec" {
  provisioner "local-exec" {
    command = "ibmcloud login --apikey ${var.ibmcloud_api_key} -r ${var.region}; ${var.command}"
  }

  triggers = {
    value = var.trigger_resource_id
  }
}