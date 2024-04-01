###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# This file contains the complete information on all the validations performed from the code during the generate plan process
# Validations are performed to make sure, the appropriate error messages are displayed to user in-order to provide required input parameter

locals {
  //validate storage gui password
  validate_storage_gui_password_cnd = (var.spectrum_scale_enabled && (replace(lower(var.scale_storage_cluster_gui_password), lower(var.scale_storage_cluster_gui_username), "") == lower(var.scale_storage_cluster_gui_password)) && can(regex("^.{8,}$", var.scale_storage_cluster_gui_password) != "") && can(regex("[0-9]{1,}", var.scale_storage_cluster_gui_password) != "") && can(regex("[a-z]{1,}", var.scale_storage_cluster_gui_password) != "") && can(regex("[A-Z]{1,}", var.scale_storage_cluster_gui_password) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.scale_storage_cluster_gui_password) != "") && trimspace(var.scale_storage_cluster_gui_password) != "") || !var.spectrum_scale_enabled
  password_msg                      = "Password should be at least 8 characters, must have one number, one lowercase letter, and one uppercase letter, at least one unique character. Password Should not contain username"
  validate_storage_gui_password_chk = regex(
    "^${local.password_msg}$",
  (local.validate_storage_gui_password_cnd ? local.password_msg : ""))

  // validate compute gui password
  validate_compute_gui_password_cnd = (var.spectrum_scale_enabled && (replace(lower(var.scale_compute_cluster_gui_password), lower(var.scale_compute_cluster_gui_username), "") == lower(var.scale_compute_cluster_gui_password)) && can(regex("^.{8,}$", var.scale_compute_cluster_gui_password) != "") && can(regex("[0-9]{1,}", var.scale_compute_cluster_gui_password) != "") && can(regex("[a-z]{1,}", var.scale_compute_cluster_gui_password) != "") && can(regex("[A-Z]{1,}", var.scale_compute_cluster_gui_password) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.scale_compute_cluster_gui_password) != "") && trimspace(var.scale_compute_cluster_gui_password) != "") || !var.spectrum_scale_enabled
  validate_compute_gui_password_chk = regex(
    "^${local.password_msg}$",
  (local.validate_compute_gui_password_cnd ? local.password_msg : ""))

  //validate scale storage gui user name
  validate_scale_storage_gui_username_cnd = (var.spectrum_scale_enabled && length(var.scale_storage_cluster_gui_username) >= 4 && length(var.scale_storage_cluster_gui_username) <= 32 && trimspace(var.scale_storage_cluster_gui_username) != "") || !var.spectrum_scale_enabled
  storage_gui_username_msg                = "Specified input for \"storage_cluster_gui_username\" is not valid."
  validate_storage_gui_username_chk = regex(
    "^${local.storage_gui_username_msg}",
  (local.validate_scale_storage_gui_username_cnd ? local.storage_gui_username_msg : ""))

  // validate compute gui username
  validate_compute_gui_username_cnd = (var.spectrum_scale_enabled && length(var.scale_compute_cluster_gui_username) >= 4 && length(var.scale_compute_cluster_gui_username) <= 32 && trimspace(var.scale_compute_cluster_gui_username) != "") || !var.spectrum_scale_enabled
  compute_gui_username_msg          = "Specified input for \"compute_cluster_gui_username\" is not valid."
  validate_compute_gui_username_chk = regex(
    "^${local.compute_gui_username_msg}",
  (local.validate_compute_gui_username_cnd ? local.compute_gui_username_msg : ""))

  // validate application center gui password
  validate_app_center_gui_pwd = (var.enable_app_center && can(regex("^.{8,}$", var.app_center_gui_pwd) != "") && can(regex("[0-9]{1,}", var.app_center_gui_pwd) != "") && can(regex("[a-z]{1,}", var.app_center_gui_pwd) != "") && can(regex("[A-Z]{1,}", var.app_center_gui_pwd) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.app_center_gui_pwd) != "") && trimspace(var.app_center_gui_pwd) != "") || !var.enable_app_center
  validate_app_center_gui_pwd_chk = regex(
    "^${local.password_msg}$",
  (local.validate_app_center_gui_pwd ? local.password_msg : ""))

  // validate application center db password
  validate_app_center_db_pwd = (var.enable_app_center && can(regex("^.{8,}$", var.app_center_db_pwd) != "") && can(regex("[0-9]{1,}", var.app_center_db_pwd) != "") && can(regex("[a-z]{1,}", var.app_center_db_pwd) != "") && can(regex("[A-Z]{1,}", var.app_center_db_pwd) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.app_center_db_pwd) != "") && trimspace(var.app_center_db_pwd) != "") || !var.enable_app_center
  validate_app_center_db_pwd_chk = regex(
    "^${local.password_msg}$",
  (local.validate_app_center_db_pwd ? local.password_msg : ""))

  // validation for the boot volume encryption toggling.
  validate_enable_customer_managed_encryption     = anytrue([alltrue([var.kms_key_name != "", var.kms_instance_id != ""]), (var.kms_key_name == ""), (var.enable_customer_managed_encryption == false)])
  validate_enable_customer_managed_encryption_msg = "Please make sure you are passing the kms_instance_id if you are passing kms_key_name."
  validate_enable_customer_managed_encryption_chk = regex(
    "^${local.validate_enable_customer_managed_encryption_msg}$",
  (local.validate_enable_customer_managed_encryption ? local.validate_enable_customer_managed_encryption_msg : ""))

  // validation for the boot volume encryption toggling.
  validate_null_customer_managed_encryption     = anytrue([alltrue([var.kms_instance_id == "", var.enable_customer_managed_encryption != true]), (var.enable_customer_managed_encryption == true)])
  validate_null_customer_managed_encryption_msg = "Please make sure you are setting enable_customer_managed_encryption as true if you are passing kms_instance_id, kms_key_name."
  validate_null_customer_managed_encryption_chk = regex(
    "^${local.validate_null_customer_managed_encryption_msg}$",
  (local.validate_null_customer_managed_encryption ? local.validate_null_customer_managed_encryption_msg : ""))

  //validate vpc flow log input
  vpc_flow_log_validation_msg   = "Please provide COS instance & bucket name to create flow logs collector."
  validate_vpc_flow_logs_inputs = anytrue([var.enable_vpc_flow_logs == false, var.existing_cos_instance_guid != null && var.existing_storage_bucket_name != null])
  validate_vpc_flow_logs_check = regex("^${local.vpc_flow_log_validation_msg}$",
  (local.validate_vpc_flow_logs_inputs ? local.vpc_flow_log_validation_msg : ""))

  ## Validate custom fileshare 
  ## Construct a list of Share size(GB) and IOPS range(IOPS)from values provided in https://cloud.ibm.com/docs/vpc?topic=vpc-file-storage-profiles&interface=ui#dp2-profile 
  ## List values [[sharesize_start,sharesize_end,min_iops,max_iops], [..]....]
  custom_fileshare_iops_range = [[10, 39, 100, 1000], [40, 79, 100, 2000], [80, 99, 100, 4000], [100, 499, 100, 6000], [500, 999, 100, 10000], [1000, 1999, 100, 20000], [2000, 3999, 200, 40000], [4000, 7999, 300, 40000], [8000, 15999, 500, 64000], [16000, 32000, 2000, 96000]]
  ## List with input iops value, min and max iops for the input share size.
  size_iops_lst = [for values in var.custom_file_shares : [for list_val in local.custom_fileshare_iops_range : [values.iops, list_val[2], list_val[3]] if(values.size >= list_val[0] && values.size <= list_val[1])]]
  ## Validate the input iops falls inside the range.
  validate_custom_file_share     = alltrue([for iops in local.size_iops_lst : iops[0][0] >= iops[0][1] && iops[0][0] <= iops[0][2]])
  validate_custom_file_share_msg = "Provided iops value is not valid for given file share size. Please refer 'File Storage for VPC profiles' page in ibm cloud docs for a valid iops and file share size combination."
  validate_custom_file_share_chk = regex(
    "^${local.validate_custom_file_share_msg}$",
  (local.validate_custom_file_share ? local.validate_custom_file_share_msg : ""))

  // LDAP base DNS Validation
  validate_ldap_basedns = (var.enable_ldap && trimspace(var.ldap_basedns) != "") || !var.enable_ldap
  ldap_basedns_msg      = "If LDAP is enabled, then the base DNS should not be empty or null. Need a valid domain name."
  validate_ldap_basedns_chk = regex(
    "^${local.ldap_basedns_msg}$",
  (local.validate_ldap_basedns ? local.ldap_basedns_msg : ""))

  // LDAP base existing LDAP server
  validate_ldap_server = (var.enable_ldap && trimspace(var.ldap_server) != "") || !var.enable_ldap
  ldap_server_msg      = "IP of existing LDAP server. If none given a new ldap server will be created. It should not be empty."
  validate_ldap_server_chk = regex(
    "^${local.ldap_server_msg}$",
  (local.validate_ldap_server ? local.ldap_server_msg : ""))

  // LDAP Admin Password Validation
  validate_ldap_adm_pwd = var.enable_ldap && var.ldap_server == "null" ? (length(var.ldap_admin_password) >= 8 && length(var.ldap_admin_password) <= 20 && can(regex("^(.*[0-9]){2}.*$", var.ldap_admin_password))) && can(regex("^(.*[A-Z]){1}.*$", var.ldap_admin_password)) && can(regex("^(.*[a-z]){1}.*$", var.ldap_admin_password)) && can(regex("^.*[~@_+:].*$", var.ldap_admin_password)) && can(regex("^[^!#$%^&*()=}{\\[\\]|\\\"';?.<,>-]+$", var.ldap_admin_password)) : local.ldap_server_status
  ldap_adm_password_msg = "Password that is used for LDAP admin.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character. Make sure that the password doesn't include the username."
  validate_ldap_adm_pwd_chk = regex(
    "^${local.ldap_adm_password_msg}$",
  (local.validate_ldap_adm_pwd ? local.ldap_adm_password_msg : ""))

  // LDAP User Validation
  validate_ldap_usr = var.enable_ldap && var.ldap_server == "null" ? (length(var.ldap_user_name) >= 4 && length(var.ldap_user_name) <= 32 && var.ldap_user_name != "" && can(regex("^[a-zA-Z0-9_-]*$", var.ldap_user_name)) && trimspace(var.ldap_user_name) != "") : local.ldap_server_status
  ldap_usr_msg      = "The input for 'ldap_user_name' is considered invalid. The username must be within the range of 4 to 32 characters and may only include letters, numbers, hyphens, and underscores. Spaces are not permitted."
  validate_ldap_usr_chk = regex(
    "^${local.ldap_usr_msg}$",
  (local.validate_ldap_usr ? local.ldap_usr_msg : ""))

  // LDAP User Password Validation
  validate_ldap_usr_pwd = var.enable_ldap && var.ldap_server == "null" ? (length(var.ldap_user_password) >= 8 && length(var.ldap_user_password) <= 20 && can(regex("^(.*[0-9]){2}.*$", var.ldap_user_password))) && can(regex("^(.*[A-Z]){1}.*$", var.ldap_user_password)) && can(regex("^(.*[a-z]){1}.*$", var.ldap_user_password)) && can(regex("^.*[~@_+:].*$", var.ldap_user_password)) && can(regex("^[^!#$%^&*()=}{\\[\\]|\\\"';?.<,>-]+$", var.ldap_user_password)) : local.ldap_server_status
  ldap_usr_password_msg = "Password that is used for LDAP user.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character. Make sure that the password doesn't include the username."
  validate_ldap_usr_pwd_chk = regex(
    "^${local.ldap_usr_password_msg}$",
  (local.validate_ldap_usr_pwd ? local.ldap_usr_password_msg : ""))
}

// Module for the private cluster_subnet and login subnet cidr validation.
module "ipvalidation_cluster_subnet" {
  count              = var.vpc_cluster_private_subnets_cidr_blocks == "" ? 0 : 1
  source             = "./resources/custom/subnet_cidr_check"
  subnet_cidr        = var.vpc_cluster_private_subnets_cidr_blocks[0]
  vpc_address_prefix = local.prefixes_in_given_zone
}

module "ipvalidation_login_subnet" {
  source             = "./resources/custom/subnet_cidr_check"
  subnet_cidr        = var.vpc_cluster_login_private_subnets_cidr_blocks[0]
  vpc_address_prefix = local.prefixes_in_given_zone_login
}

## Validate input  CIDR 
locals {
  // Copy address prefixes and CIDR of given zone into a new tuple
  prefixes_in_given_zone_login = [
    for prefix in data.ibm_is_vpc_address_prefixes.existing_vpc.*.address_prefixes[0] :
  prefix.cidr if prefix.zone.0.name == var.zone]

  // To get the address prefix of zone
  prefixes_in_given_zone = [
    for prefix in data.ibm_is_vpc_address_prefixes.existing_vpc.*.address_prefixes[0] :
  prefix.cidr if var.zone == prefix.zone.0.name]

  // Validation for the private cluster_subnet CIDR input of zone 1
  validate_private_subnet_cidr     = anytrue(concat([var.cluster_subnet_id != ""], module.ipvalidation_cluster_subnet[0].results))
  validate_private_subnet_cidr_msg = "Provide appropriate range of subnet CIDR value in vpc_cluster_private_subnets_cidr_blocks from the existing VPC’s CIDR block."
  validate_private_subnet_cidr_chk = regex("^${local.validate_private_subnet_cidr_msg}$", (local.validate_private_subnet_cidr ? local.validate_private_subnet_cidr_msg : ""))

  // Validation for the login cluster_subnet CIDR input should be in zone1 address prefix
  validate_login_subnet_cidr     = anytrue(concat([var.login_subnet_id != ""], module.ipvalidation_login_subnet.results))
  validate_login_subnet_cidr_msg = "Provide appropriate range of subnet CIDR value in vpc_cluster_login_private_subnets_cidr_blocks from the existing VPC’s CIDR block."
  validate_login_subnet_cidr_chk = regex("^${local.validate_login_subnet_cidr_msg}$", (local.validate_login_subnet_cidr ? local.validate_login_subnet_cidr_msg : ""))

  // Validate that the vpc_cluster_login_private_subnets_cidr_blocks do not conflict with the subnet entries in the zone.
  login_cidr   = var.vpc_cluster_login_private_subnets_cidr_blocks[0]
  cluster_cidr = var.cluster_subnet_id != "" ? data.ibm_is_subnet.existing_subnet[0].ipv4_cidr_block : var.vpc_cluster_private_subnets_cidr_blocks[0]

  //Convert the login CIDR, cluster CIDR beginning and ending IP addresses to integers for validation.
  validate_login = [for i in [cidrhost(local.login_cidr, 0), cidrhost(local.login_cidr, -1), cidrhost(local.cluster_cidr, 0), cidrhost(local.cluster_cidr, -1)] : (((split(".", i)[0]) * pow(256, 3)) #192
    + ((split(".", i)[1]) * pow(256, 2))
    + ((split(".", i)[2]) * pow(256, 1))
  + ((split(".", i)[3]) * pow(256, 0)))]
  //Assign values to new variables for readability.
  login_cidr_first_ip   = local.validate_login[0]
  login_cidr_last_ip    = local.validate_login[1]
  cluster_cidr_first_ip = local.validate_login[2]
  cluster_cidr_last_ip  = local.validate_login[3]
  //The logic for CIDR conflict validation is that the entire login CIDR range should either be less than or greater than the cluster CIDR range.
  validate_login_conflict     = anytrue([local.login_cidr_first_ip > local.cluster_cidr_first_ip && local.login_cidr_first_ip > local.cluster_cidr_last_ip, local.login_cidr_first_ip < local.cluster_cidr_first_ip && local.login_cidr_last_ip < local.cluster_cidr_first_ip])
  validate_login_conflict_msg = "The vpc_cluster_login_private_subnets_cidr_blocks conflicts with the subnet entry in the primary zone."
  validate_login_conflict_chk = regex("^${local.validate_login_conflict_msg}$",
  (local.validate_login_conflict ? local.validate_login_conflict_msg : ""))

  // Validate the subnet_id user input value
  validate_subnet_id_msg = "If the subnet_id is provided, the user should also provide the vpc_name."
  validate_subnet_id     = anytrue([var.vpc_name != "" && var.cluster_subnet_id != "", var.cluster_subnet_id == ""])
  validate_subnet_id_chk = regex("^${local.validate_subnet_id_msg}$",
  (local.validate_subnet_id ? local.validate_subnet_id_msg : ""))

  // Validate existing subnet should be the subset of vpc_name entered
  validate_subnet_id_vpc_msg = "Provided cluster subnet should be within the vpc entered."
  validate_subnet_id_vpc     = anytrue([var.cluster_subnet_id == "", var.cluster_subnet_id != "" ? contains(data.ibm_is_vpc.existing_vpc[0].subnets.*.id, var.cluster_subnet_id) : false])
  validate_subnet_id_vpc_chk = regex("^${local.validate_subnet_id_vpc_msg}$",
  (local.validate_subnet_id_vpc ? local.validate_subnet_id_vpc_msg : ""))

  // Validate existing subnet should be in the appropriate zone.
  validate_subnet_id_zone_msg = "Provided cluster subnet should be in appropriate zone."
  validate_subnet_id_zone     = anytrue([var.cluster_subnet_id == "", var.cluster_subnet_id != "" ? data.ibm_is_subnet.existing_subnet[0].zone == var.zone : false])
  validate_subnet_id_zone_chk = regex("^${local.validate_subnet_id_zone_msg}$",
  (local.validate_subnet_id_zone ? local.validate_subnet_id_zone_msg : ""))

  // Validate existing login subnet should be the subset of vpc_name entered
  validate_login_subnet_id_vpc_msg = "Provided login subnet should be within the vpc entered."
  validate_login_subnet_id_vpc     = anytrue([var.login_subnet_id == "", var.login_subnet_id != "" && var.vpc_name != "" ? alltrue([for subnet_id in [var.login_subnet_id] : contains(data.ibm_is_vpc.existing_vpc[0].subnets.*.id, subnet_id)]) : false])
  validate_login_subnet_id_vpc_chk = regex("^${local.validate_login_subnet_id_vpc_msg}$",
  (local.validate_login_subnet_id_vpc ? local.validate_login_subnet_id_vpc_msg : ""))

  // Validate existing login subnet should be in the appropriate zone.
  validate_login_subnet_id_zone_msg = "Provided login subnet should be in appropriate zone."
  validate_login_subnet_id_zone     = anytrue([var.login_subnet_id == "", var.login_subnet_id != "" && var.vpc_name != "" ? alltrue([data.ibm_is_subnet.existing_login_subnet[0].zone == var.zone]) : false])
  validate_login_subnet_id_zone_chk = regex("^${local.validate_login_subnet_id_zone_msg}$",
  (local.validate_login_subnet_id_zone ? local.validate_login_subnet_id_zone_msg : ""))

  // Validate existing subnet public gateways 
  validate_subnet_name_pg_msg = "Provided cluster subnet should have the public gateway attached."
  validate_subnet_name_pg     = anytrue([var.cluster_subnet_id == "", var.cluster_subnet_id != "" ? data.ibm_is_subnet.existing_subnet[0].public_gateway != "" : false])
  validate_subnet_name_pg_chk = regex("^${local.validate_subnet_name_pg_msg}$",
  (local.validate_subnet_name_pg ? local.validate_subnet_name_pg_msg : ""))

  // Validate existing vpc public gateways
  validate_existing_vpc_pgw_msg = "Provided existing vpc should have the public gateways created in the provided zone."
  validate_existing_vpc_pgw     = anytrue([(var.vpc_name == ""), alltrue([var.vpc_name != "", var.cluster_subnet_id != ""]), alltrue([var.vpc_name != "", var.cluster_subnet_id == "", var.login_subnet_id == "", length(local.existing_pgw_id) > 0])])
  validate_existing_vpc_pgw_chk = regex("^${local.validate_existing_vpc_pgw_msg}$",
  (local.validate_existing_vpc_pgw ? local.validate_existing_vpc_pgw_msg : ""))

  // Validate in case of existing subnets provide both login_subnet_id and cluster_subnet_id.
  validate_login_subnet_id_msg = "In case of existing subnets provide both login_subnet_id and cluster_subnet_id."
  validate_login_subnet_id     = anytrue([alltrue([var.cluster_subnet_id == "", var.login_subnet_id == ""]), alltrue([var.cluster_subnet_id != "", var.login_subnet_id != ""])])
  validate_login_subnet_id_chk = regex("^${local.validate_login_subnet_id_msg}$",
  (local.validate_login_subnet_id ? local.validate_login_subnet_id_msg : ""))

  // Validate the dns_custom_resolver_id should not be given in case of new vpc case
  validate_custom_resolver_id_msg = "If it is the new vpc deployment, do not provide existing dns_custom_resolver_id as that will impact the name resolution of the cluster."
  validate_custom_resolver_id     = anytrue([var.vpc_name != "", var.vpc_name == "" && var.dns_custom_resolver_id == ""])
  validate_custom_resolver_id_chk = regex("^${local.validate_custom_resolver_id_msg}$",
  (local.validate_custom_resolver_id ? local.validate_custom_resolver_id_msg : ""))
}
