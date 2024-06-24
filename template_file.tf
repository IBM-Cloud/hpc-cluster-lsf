data "template_file" "management_host_user_data" {
  template = local.management_host_template_file
  vars = {
    cluster_name                  = var.cluster_id
    vpc_apikey_value              = var.api_key
    resource_records_apikey_value = var.api_key
    image_id                      = local.compute_image_mapping_entry_found ? local.new_compute_image_id : data.ibm_is_image.image[0].id
    subnet_id                     = var.cluster_subnet_id != "" ? data.ibm_is_subnet.existing_subnet[0].crn : module.subnet[0].subnet_crn
    security_group_id             = module.sg.sg_id
    sshkey_id                     = data.ibm_is_ssh_key.ssh_key[local.ssh_key_list[0]].id
    region_name                   = data.ibm_is_region.region.name
    zone_name                     = data.ibm_is_zone.zone.name
    vpc_id                        = data.ibm_is_vpc.vpc.id
    rc_cidr_block                 = local.rc_cidr_block
    rc_profile                    = data.ibm_is_instance_profile.worker.name
    rc_ncores                     = local.ncores
    rc_ncpus                      = local.ncpus
    rc_memInMB                    = local.memInMB
    rc_maxNum                     = local.rc_maxNum
    rc_rg                         = data.ibm_resource_group.rg.id
    hyperthreading                = var.hyperthreading_enabled
    temp_public_key               = local.vsi_login_temp_public_key
    scale_mount_point             = var.scale_compute_cluster_filesystem_mountpoint
    spectrum_scale                = var.spectrum_scale_enabled
    enable_app_center             = var.enable_app_center
    app_center_gui_pwd            = var.app_center_gui_pwd
    app_center_db_pwd             = var.app_center_db_pwd
    mount_path                    = module.cluster_file_share.mount_path
    custom_file_shares            = join(" ", [for file_share in module.custom_file_share[*].mount_path : file_share])
    custom_mount_paths            = join(" ", [for mount_path in var.custom_file_shares[*]["mount_path"] : mount_path])
    management_node_count         = var.management_node_count
    cluster_prefix                = var.cluster_prefix
    login_ip_address              = module.login_vsi[0].primary_network_interface
    enable_ldap                   = var.enable_ldap
    ldap_server_ip                = local.ldap_server
    #ldap_basedns                  = var.ldap_basedns != null ? "\"${var.ldap_basedns}\"" : "null"
    ldap_basedns      = var.enable_ldap == true ? var.ldap_basedns : "null"
    dns_domain        = var.dns_domain
    network_interface = local.network_interface
  }
}

data "template_file" "worker_user_data" {
  template = local.worker_template_file
  vars = {
    rc_cidr_block         = local.rc_cidr_block
    hyperthreading        = var.hyperthreading_enabled
    temp_public_key       = var.spectrum_scale_enabled == true ? local.vsi_login_temp_public_key : "" # Public ssh for schematics will be updated only when spectrum scale is set as true
    scale_mount_point     = var.scale_compute_cluster_filesystem_mountpoint
    spectrum_scale        = var.spectrum_scale_enabled
    cluster_name          = var.cluster_id
    mount_path            = module.cluster_file_share.mount_path
    custom_file_shares    = join(" ", [for file_share in module.custom_file_share[*].mount_path : file_share])
    custom_mount_paths    = join(" ", [for mount_path in var.custom_file_shares[*]["mount_path"] : mount_path])
    management_node_count = var.management_node_count
    cluster_prefix        = var.cluster_prefix
    enable_ldap           = var.enable_ldap
    ldap_server_ip        = local.ldap_server
    #ldap_basedns         = var.ldap_basedns != null ? "\"${var.ldap_basedns}\"" : "null"
    ldap_basedns      = var.enable_ldap == true ? var.ldap_basedns : "null"
    dns_domain        = var.dns_domain
    network_interface = local.network_interface
  }
}

data "template_file" "bastion_user_data" {
  template = <<EOF
#!/usr/bin/env bash
echo "${local.vsi_login_temp_public_key}" >> ~/.ssh/authorized_keys
EOF
}

data "template_file" "metadata_startup_script" {
  template = local.metadata_startup_template_file
  vars = {
    temp_public_key       = local.vsi_login_temp_public_key
    rc_cidr_block         = local.rc_cidr_block
    management_node_count = var.management_node_count
    cluster_prefix        = var.cluster_prefix
    instance_profile_type = data.ibm_is_instance_profile.spectrum_scale_storage.disks.0.quantity.0.type
    mount_path            = module.cluster_file_share.mount_path
    custom_file_shares    = join(" ", [for file_share in module.custom_file_share[*].mount_path : file_share])
    custom_mount_paths    = join(" ", [for mount_path in var.custom_file_shares[*]["mount_path"] : mount_path])
    network_interface     = local.network_interface
    dns_domain            = var.dns_domain
    enable_ldap           = var.enable_ldap
    ldap_server_ip        = local.ldap_server
    ldap_basedns          = var.enable_ldap == true ? var.ldap_basedns : "null"
  }
}

data "template_file" "login_user_data" {
  template = local.login_vsi
  vars = {
    network_interface = local.network_interface
    dns_domain        = var.dns_domain
    mount_path        = module.cluster_file_share.mount_path
    enable_ldap       = var.enable_ldap
    cluster_prefix    = var.cluster_prefix
    rc_cidr_block     = local.rc_cidr_block
    ldap_server_ip    = local.ldap_server
    ldap_basedns      = var.enable_ldap == true ? var.ldap_basedns : "null"
  }
}

data "template_file" "ldap_user_data" {
  count    = var.enable_ldap == true ? 1 : 0
  template = local.ldap_user_data
  vars = {
    ssh_public_key_content = local.vsi_login_temp_public_key
    ldap_basedns           = var.ldap_basedns
    ldap_admin_password    = var.ldap_admin_password
    cluster_prefix         = var.cluster_prefix
    ldap_user              = var.ldap_user_name
    ldap_user_password     = var.ldap_user_password
    dns_domain             = var.dns_domain
    network_interface      = local.network_interface
  }
}