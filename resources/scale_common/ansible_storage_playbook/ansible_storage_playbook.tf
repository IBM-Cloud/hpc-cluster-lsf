###################################################
# Copyright (C) IBM Corp. 2022 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################
/*
    Creates Ansible inventory and excutes ansible playbook to
    install IBM Spectrum Scale storage cluster.
*/

variable "region" {}
variable "stack_name" {}
variable "avail_zones" {}
variable "cloud_platform" {}
variable "tf_data_path" {}
variable "tf_input_json_root_path" {}
variable "tf_input_json_file_name" {}
variable "filesystem_mountpoint" {}
variable "filesystem_block_size" {}
variable "scale_infra_repo_clone_path" {}
variable "clone_complete" {}
variable "bastion_public_ip" {}
variable "bastion_os_flavor" {}
variable "scale_version" {}
variable "bastion_ssh_private_key" {}
variable "compute_instance_desc_map" {}
variable "compute_instance_desc_id" {}
variable "storage_instances_by_id" {}
variable "storage_instance_disk_map" {}
variable "storage_cluster_gui_username" {}
variable "storage_cluster_gui_password" {}
variable "host" {}

locals {
  tf_inv_path                     = format("%s/%s", "/tmp/.schematics/IBM", "storage_tf_inventory.json")
  scripts_path                    = replace(path.module, "ansible_storage_playbook", "scripts")
  ansible_inv_script_path         = "${local.scripts_path}/prepare_scale_inv.py"
  scale_tuning_param_path         = format("%s/%s", var.scale_infra_repo_clone_path, "storagesncparams.profile")
  scale_infra_path                = format("%s/%s", var.scale_infra_repo_clone_path, "ibm-spectrum-scale-install-infra")
  scale_cluster_def_path          = format("%s/%s/%s", local.scale_infra_path, "vars", "storage_clusterdefinition.json")
  cloud_playbook_path             = format("%s/%s", local.scale_infra_path, "cloud_playbook.yml")
  storage_instances_root_key_path = format("%s/%s", var.tf_data_path, "id_rsa")
  infra_complete_message          = "Provisioning infrastructure required for IBM Spectrum Scale deployment completed successfully."
  cluster_complete_message        = "IBM Spectrum Scale cluster creation completed successfully."
  bastion_user                    = var.cloud_platform == "IBMCloud" ? (length(regexall("ubuntu", var.bastion_os_flavor)) > 0 ? "ubuntu" : "root") : "ec2-user"
}

// create storage_tf_inventory.json file for gpfs setup on compute nodes
resource "local_file" "dump_strg_tf_inventory" {
  count    = var.clone_complete == true ? 1 : 0
  content  = <<EOT
{
    "cloud_platform": "${var.cloud_platform}",
    "stack_name": "${var.stack_name}",
    "region": "${var.region}",
    "filesystem_mountpoint": "${var.filesystem_mountpoint}",
    "filesystem_block_size": "${var.filesystem_block_size}",
    "availability_zones": ${var.avail_zones},
    "compute_instances_by_ip": {},
    "compute_instances_by_id": {},
    "compute_instance_desc_map": ${var.compute_instance_desc_map},
    "compute_instance_desc_id": ${var.compute_instance_desc_id},
    "storage_instances_by_id": ${var.storage_instances_by_id},
    "storage_instance_disk_map": ${var.storage_instance_disk_map},
    "gui_username": "${var.storage_cluster_gui_username}",
    "gui_password": "${var.storage_cluster_gui_password}"
}
EOT
  filename = local.tf_inv_path
}

// create computesncparams.profile file with scale tuning parameters
resource "local_file" "create_scale_tuning_parameters" {
  count    = var.clone_complete == true ? 1 : 0
  content  = <<EOT
%cluster:
 maxblocksize=16M
 restripeOnDiskFailure=yes
 unmountOnDiskFail=meta
 readReplicaPolicy=local
 workerThreads=128
 maxStatCache=0
 maxFilesToCache=64k
 ignorePrefetchLUNCount=yes
 prefetchaggressivenesswrite=0
 prefetchaggressivenessread=2
 autoload=yes
EOT
  filename = local.scale_tuning_param_path
}

// call python script to prepare ansible inventory
resource "null_resource" "prepare_ansible_inventory" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --tf_inv_path ${local.tf_inv_path} --scale_cluster_def_path ${local.scale_cluster_def_path} --scale_tuning_profile_file ${local.scale_tuning_param_path} --ansible_ssh_private_key_file ${local.storage_instances_root_key_path}"
  }
  depends_on = [local_file.dump_strg_tf_inventory]
  triggers = {
    build = timestamp()
  }
}

// add 600 permission to storage ssh-key path
resource "null_resource" "check_key_permissions" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "chmod 600 ${local.storage_instances_root_key_path}"
  }
  triggers = {
    builds = timestamp()
  }
  depends_on = [null_resource.prepare_ansible_inventory]
}

// Invoke ansible paly book to setup gpfs storage cluster and filesystem
resource "null_resource" "call_scale_install_playbook" {
  connection {
    bastion_host = var.bastion_public_ip
    user         = local.bastion_user
    host         = var.host
    private_key  = file(var.bastion_ssh_private_key)
  }

  provisioner "ansible" {
    plays {
      playbook {
        file_path = local.cloud_playbook_path
      }
      inventory_file = local.scale_cluster_def_path
      verbose        = true
      extra_vars = {
        "scale_version" : var.scale_version,
        "ansible_python_interpreter" : "auto",
        "scale_cluster_definition_path" : local.scale_cluster_def_path,
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
  depends_on = [local_file.create_scale_tuning_parameters, null_resource.check_key_permissions]
  triggers = {
    build = timestamp()
  }
}