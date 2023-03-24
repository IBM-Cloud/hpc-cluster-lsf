###################################################
# Copyright (C) IBM Corp. 2022 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################
/*
     Creates Ansible inventory and excutes ansible playbook to
     remote mount filesystem from storage cluster to compute cluster.
*/

variable "clone_complete" {}
variable "cloud_platform" {}
variable "tf_data_path" {}
variable "bastion_os_flavor" {}
variable "bastion_public_ip" {}
variable "bastion_ssh_private_key" {}
variable "scale_infra_repo_clone_path" {}
variable "total_compute_instances" {}
variable "total_storage_instances" {}
variable "host" {}

locals {
  scripts_path                    = replace(path.module, "ansible_remote_mount_playbook", "scripts")
  scale_infra_path                = format("%s/%s", var.scale_infra_repo_clone_path, "ibm-spectrum-scale-install-infra")
  remote_mount_def_path           = format("%s/%s/%s", local.scale_infra_path, "vars", "remote_mount.json")
  compute_tf_inv_path             = format("%s/%s", "/tmp/.schematics/IBM", "compute_tf_inventory.json")
  storage_tf_inv_path             = format("%s/%s", "/tmp/.schematics/IBM", "storage_tf_inventory.json")
  ansible_inv_script_path         = format("%s/%s", local.scripts_path, "prepare_remote_mount_inv.py")
  storage_instances_root_key_path = format("%s/%s", var.tf_data_path, "id_rsa")
  rmt_mnt_playbook_path           = format("%s/%s", local.scale_infra_path, "playbook_cloud_remote_mount.yml")
  bastion_user                    = var.cloud_platform == "IBMCloud" ? (length(regexall("ubuntu", var.bastion_os_flavor)) > 0 ? "ubuntu" : "root") : "ec2-user"
}

// preapare ansible inventory for invoking remote mount of scale storage filesytem on compute cluster.
resource "null_resource" "prepare_remote_mount_ansible_inv" {
  count = (var.total_compute_instances > 0 && var.total_storage_instances > 0 && var.clone_complete) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --compute_tf_inv_path ${local.compute_tf_inv_path} --storage_tf_inv_path ${local.storage_tf_inv_path} --remote_mount_def_path ${local.remote_mount_def_path} --ansible_ssh_private_key_file ${local.storage_instances_root_key_path}"
  }
  triggers = {
    builds = timestamp()
  }
}

// sleep time to wait until gui_db initialization is done
resource "time_sleep" "wait_for_gui_db_initializion" {
  count           = (var.total_compute_instances > 0 && var.total_storage_instances > 0 && var.clone_complete) ? 1 : 0
  depends_on      = [null_resource.prepare_remote_mount_ansible_inv]
  create_duration = "180s"
}

// add 600 permission to ssh-key path
resource "null_resource" "check_key_permissions" {
  count = (var.total_compute_instances > 0 && var.total_storage_instances > 0 && var.clone_complete) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "chmod 600 ${local.storage_instances_root_key_path}"
  }
  triggers = {
    builds = timestamp()
  }
  depends_on = [time_sleep.wait_for_gui_db_initializion]
}

//  Invoke ansible playbook to remote mount the storage cluster filesytem on compute cluster
resource "null_resource" "call_remote_mnt_playbook" {
  count = (var.total_compute_instances > 0 && var.total_storage_instances > 0 && var.clone_complete) ? 1 : 0
  connection {
    bastion_host = var.bastion_public_ip
    user         = local.bastion_user
    host         = var.host
    private_key  = file(var.bastion_ssh_private_key)
  }

  provisioner "ansible" {
    plays {
      playbook {
        file_path = local.rmt_mnt_playbook_path
      }
      inventory_file = local.remote_mount_def_path
      verbose        = true
      extra_vars = {
        "ansible_python_interpreter" : "auto",
        "scale_cluster_definition_path" : local.remote_mount_def_path,
        "scale_install_updated" : false,
        "scale_config_changed" : false
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
  depends_on = [null_resource.check_key_permissions]
  triggers = {
    builds = timestamp()
  }
}
