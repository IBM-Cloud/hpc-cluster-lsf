###################################################
# Copyright (C) IBM Corp. 2022 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

variable "login_ip" {}
variable "bastion_ssh_private_key" {}
variable "compute_instances_by_ip" {}
variable "scale_mount_point" {}


locals {
  cloud_playbook_path  = format("%s/%s", "${path.module}/ansible_playbook/", "add_permission.yml")
  inventory_file_path  = format("%s", "${path.module}/ansible_playbook/inventory_file")
  compute_instances_ip = join(",", jsondecode(var.compute_instances_by_ip))
  vsi_ip               = format("%s\n%s", "[add_permission]", replace(local.compute_instances_ip, ",", "\n"))
}

resource "local_file" "inventory" {
  content  = local.vsi_ip
  filename = "${path.module}/ansible_playbook/inventory_file"
}


resource "null_resource" "call_add_permission_mountpoint_playbook" {
  connection {
    bastion_host = var.login_ip
    user         = "root"
    host         = "0.0.0.0"
    private_key  = file(var.bastion_ssh_private_key)
  }

  provisioner "ansible" {
    plays {
      playbook {
        file_path = local.cloud_playbook_path
      }
      inventory_file = local.inventory_file_path
      verbose        = true
      extra_vars = {
        "ansible_python_interpreter" : "auto",
        "scale_cluster_definition_path" : local.inventory_file_path
        "mount_point" : var.scale_mount_point
        "user_name" : "lsfadmin"
      }
    }
    ansible_ssh_settings {
      insecure_no_strict_host_key_checking         = true
      insecure_bastion_no_strict_host_key_checking = false
      connect_timeout_seconds                      = 90
      user_known_hosts_file                        = ""
      bastion_user_known_hosts_file                = ""
    }
  }
  depends_on = [local_file.inventory]
  triggers = {
    build = timestamp()
  }
}