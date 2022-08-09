###################################################
# Copyright (C) IBM Corp. 2022 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

variable "ssh_key_content" {}
variable "ssh_key_file_path" {}

resource "local_file" "write_ssh_key" {
  sensitive_content = replace(var.ssh_key_content, "\\n", "\n")
  filename          = var.ssh_key_file_path
  file_permission   = "0600"
}

resource "null_resource" "check_key_permissions" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "chmod 600 ${var.ssh_key_file_path}"
  }
  triggers = {
    builds = timestamp()
  }
  depends_on = [local_file.write_ssh_key]
}

output "ssh_key_file" {
  value      = var.ssh_key_file_path
  depends_on = [null_resource.check_key_permissions]
}
