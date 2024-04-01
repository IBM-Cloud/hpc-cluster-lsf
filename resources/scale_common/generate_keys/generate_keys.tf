###################################################
# Copyright (C) IBM Corp. 2022 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################
/*
    Creates new SSH key pair to enable passwordless SSH between scale nodes.
*/

variable "tf_data_path" {}
variable "invoke_count" {}

// resource to check if the tf_data_path exists or not, if not then create the path.
resource "null_resource" "check_tf_data_existence" {
  count = var.invoke_count == 1 ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    /* Note: Create the directory only if it does not exist. */
    command = "if [[ ! -d ${var.tf_data_path} ]]; then mkdir -p ${var.tf_data_path}; fi"
  }
}

// resource to generate ssh key with terraform.
resource "tls_private_key" "generate_ssh_key" {
  algorithm  = "RSA"
  rsa_bits   = 4096
  depends_on = [null_resource.check_tf_data_existence]
}

// resource to write generated ssh-key to a file with 0600 permission
resource "local_file" "write_ssh_key" {
  #count           = var.invoke_count == 1 ? 1 : 0
  content         = tls_private_key.generate_ssh_key.private_key_pem
  filename        = format("%s/%s", pathexpand(var.tf_data_path), "id_rsa")
  file_permission = "0600"
  depends_on      = [tls_private_key.generate_ssh_key]
}

output "private_key_path" {
  value      = format("%s/%s", var.tf_data_path, "id_rsa")
  depends_on = [local_file.write_ssh_key]
}

output "public_key" {
  value = tls_private_key.generate_ssh_key.public_key_openssh
}

output "private_key" {
  value     = tls_private_key.generate_ssh_key.private_key_pem
  sensitive = true
}
