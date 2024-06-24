locals {
  region_name  = join("-", slice(split("-", var.zone), 0, 2))
  profile_str  = split("-", data.ibm_is_instance_profile.worker.name)
  profile_list = split("x", local.profile_str[1])
  # 1. calculate required amount of compute resources using the same instance size as dynamic workers
  cpu_per_node = tonumber(data.ibm_is_instance_profile.worker.vcpu_count[0].value)
  mem_per_node = tonumber(data.ibm_is_instance_profile.worker.memory[0].value)
  required_cpu = var.worker_node_min_count * local.cpu_per_node
  required_mem = var.worker_node_min_count * local.mem_per_node

  # 2. get profiles with a class name passed as a variable (NOTE: assuming VPC Gen2 provides a single profile per class)
  dh_profiles = var.dedicated_host_enabled ? [
    for p in data.ibm_is_dedicated_host_profiles.worker[0].profiles : p if p.class == local.profile_str[0]
  ] : []
  dh_profile_index = length(local.dh_profiles) == 0 ? "Profile class ${local.profile_str[0]} for dedicated hosts does not exist in ${local.region_name}. Check available class with `ibmcloud target -r ${local.region_name}; ibmcloud is dedicated-host-profiles` and retry other worker_node_instance_type wtih the available class." : 0
  dh_profile       = var.dedicated_host_enabled ? local.dh_profiles[local.dh_profile_index] : null
  dh_cpu           = var.dedicated_host_enabled ? tonumber(local.dh_profile.vcpu_count[0].value) : 0
  dh_mem           = var.dedicated_host_enabled ? tonumber(local.dh_profile.memory[0].value) : 0
  # 3. calculate the number of dedicated hosts
  dh_count = var.dedicated_host_enabled ? ceil(max(local.required_cpu / local.dh_cpu, local.required_mem / local.dh_mem)) : 0

  # 4. calculate the possible number of workers, which is used by the pack placement
  dh_worker_count = var.dedicated_host_enabled ? floor(min(local.dh_cpu / local.cpu_per_node, local.dh_mem / local.mem_per_node)) : 0
}

locals {
  script_map = {
    "storage"          = file("${path.module}/scripts/user_data_input_storage.tpl")
    "management_host"  = file("${path.module}/scripts/user_data_input_management_host.tpl")
    "worker"           = file("${path.module}/scripts/user_data_input_worker.tpl")
    "spectrum_storage" = file("${path.module}/scripts/user_data_spectrum_storage.tpl")
    "login_vsi"        = file("${path.module}/scripts/login_user_data.tpl")
    "ldap_user_data"   = file("${path.module}/scripts/ldap_user_data.tpl")
  }
  storage_template_file         = lookup(local.script_map, "storage")
  management_host_template_file = lookup(local.script_map, "management_host")
  worker_template_file          = lookup(local.script_map, "worker")
  login_vsi                     = lookup(local.script_map, "login_vsi")
  ldap_user_data                = lookup(local.script_map, "ldap_user_data")
  metadata_startup_template_file  = lookup(local.script_map, "spectrum_storage")
  tags                          = ["hpcc", var.cluster_prefix]
  vcpus                         = tonumber(data.ibm_is_instance_profile.worker.vcpu_count[0].value)
  ncores                        = local.vcpus / 2
  ncpus                         = var.hyperthreading_enabled ? local.vcpus : local.ncores
  memInMB                       = tonumber(data.ibm_is_instance_profile.worker.memory[0].value) * 1024
  rc_maxNum                     = var.worker_node_max_count > var.worker_node_min_count ? var.worker_node_max_count - var.worker_node_min_count : 0
}

locals {
  // Check whether an entry is found in the mapping file for the given symphony compute node image
  image_mapping_entry_found = contains(keys(local.image_region_map), var.image_name)
  new_image_id              = local.image_mapping_entry_found ? lookup(lookup(local.image_region_map, var.image_name), local.region_name) : "Image not found with the given name"

  #  new_image_id = contains(keys(local.image_region_map), var.image_name) ? lookup(lookup(local.image_region_map, var.image_name), local.region_name) : "Image not found with the given name"

  // Use existing VPC if var.vpc_name is not empty
  vpc_name = var.vpc_name == "" ? module.vpc.*.name[0] : data.ibm_is_vpc.existing_vpc.*.name[0]
}

locals {
  stock_image_name = "ibm-redhat-8-8-minimal-amd64-2"
}

locals {
  cluster_file_share_size = 10
  network_interface       = "eth0"
  cluster_user            = "root"

  # LDAP local variables
  ldap_server            = var.enable_ldap == true && var.ldap_server == "null" ? length(module.ldap_vsi) > 0 ? module.ldap_vsi[0].primary_network_interface_address : null : var.ldap_server
  ldap_instance_image_id = var.enable_ldap == true && var.ldap_server == "null" ? data.ibm_is_image.ldap_vsi_image[0].id : ""
  ldap_server_status     = var.enable_ldap == true && var.ldap_server == "null" ? false : true

  # Check whether an entry is found in the mapping file for the given compute node image
  compute_image_mapping_entry_found = contains(keys(local.image_region_map), var.compute_image_name)
  new_compute_image_id              = local.compute_image_mapping_entry_found ? lookup(lookup(local.image_region_map, var.compute_image_name), local.region_name) : "Image not found with the given name"
}

locals {
  vsi_login_temp_public_key = module.login_ssh_key.public_key
}

#####################################################################
#                       IP ADDRESS MAPPING
#####################################################################
# LSF assumes all the node IPs are known before their startup.
# This causes a cyclic dependency, e.g., management_hosts must know their IPs
# before starting themselves. We resolve this by explicitly
# assigining IP addresses calculated by cidrhost(cidr_block, index).
#
# Input variables:
# nrM    == var.management_node_count
# nrMinW == var.worker_node_min_count
# nrMaxW == var.worker_node_max_count
#
# Address index range                        | Mapped nodes
# -------------------------------------------------------------------
# 0                  - 3                     | Reserved by IBM Cloud
# 4                  - 4                     | Storage node
# 5                  - (5 + nrM - 1)         | Management nodes
# (5 + nrM)          - (5 + nrM + nrMinW - 1)| Static worker nodes
# (5 + nrM + nrMinW) - (5 + nrM + nrMaxW - 1)| Dynamic worker nodes
#
# Details of reserved IPs:
# https://cloud.ibm.com/docs/vpc?topic=vpc-about-networking-for-vpc
#
# We also reserve four IPs for VPN
# https://cloud.ibm.com/docs/vpc?topic=vpc-vpn-create-gateway
#####################################################################


locals {
  totat_spectrum_storage_node_count = var.spectrum_scale_enabled ? var.scale_storage_node_count : 0
  total_ipv4_address_count = pow(2, ceil(log(
    local.totat_spectrum_storage_node_count +
    var.worker_node_max_count +
    var.management_node_count +
    5 +
    1 + /* ibm-broadcast-address */
    4 + /* ibm-default-gateway, ibm-dns-address, ibm-network-address, ibm-reserved-address */
    1, /* DNS Instance */
    2))
  )
  first_ip_idx = 5

  custom_ipv4_subnet_node_count = join(",", var.vpc_cluster_private_subnets_cidr_blocks) != "" ? parseint(regex("/(\\d+)$", join(",", var.vpc_cluster_private_subnets_cidr_blocks))[0], 10) : 0
  total_custom_ipv4_node_count  = pow(2, 32 - local.custom_ipv4_subnet_node_count)
  spectrum_storage_node_count   = var.spectrum_scale_enabled ? var.scale_storage_node_count : 0
  total_ipv4_address_node_count = pow(2, ceil(log(local.spectrum_storage_node_count + var.worker_node_max_count + var.management_node_count + 5 + 1 + 4, 2)))

  management_host_reboot_tmp = file("${path.module}/scripts/LSF_server_reboot.sh")
  worker_reboot_tmp          = file("${path.module}/scripts/LSF_server_reboot.sh")
  management_host_reboot_str = replace(local.management_host_reboot_tmp, "<LSF_MANAGEMENT_HOST_OR_WORKER>", "lsf")
  worker_reboot_str          = replace(local.worker_reboot_tmp, "<LSF_MANAGEMENT_HOST_OR_WORKER>", "lsf_worker")

  validate_worker_cnd = var.worker_node_min_count <= var.worker_node_max_count
  validate_worker_msg = "worker_node_max_count has to be greater or equal to worker_node_min_count"
  validate_worker_chk = regex(
    "^${local.validate_worker_msg}$",
    (local.validate_worker_cnd
      ? local.validate_worker_msg
  : ""))

  ssh_key_list = split(",", var.ssh_key_name)
  ssh_key_id_list = [
    for name in local.ssh_key_list :
    data.ibm_is_ssh_key.ssh_key[name].id
  ]
}

locals {
  products = var.spectrum_scale_enabled ? var.enable_app_center ? "lsf,scale,lsf-app-center" : "lsf,scale" : var.enable_app_center ? "lsf,lsf-app-center" : "lsf"
}

locals {
  scale_image_mapping_entry_found = contains(keys(local.scale_image_region_map), var.scale_storage_image_name)
  scale_image_id                  = local.scale_image_mapping_entry_found ? lookup(lookup(local.scale_image_region_map, var.scale_storage_image_name), local.region_name) : "Image not found with the given name"

  #  scale_image_id = contains(keys(local.scale_image_region_map), var.scale_storage_image_name) ? lookup(lookup(local.scale_image_region_map, var.scale_storage_image_name), local.region_name) : "Image not found with the given name"
}

locals {
  peer_cidr_list = var.vpn_enabled ? split(",", var.vpn_peer_cidrs) : []
}

locals {
  tf_data_path                     = "/tmp/.schematics/IBM/tf_data_path"
  tf_input_json_root_path          = null
  tf_input_json_file_name          = null
  scale_version                    = "5.1.9.0" # This is the scale version that is installed on the custom images
  cloud_platform                   = "IBMCloud"
  scale_infra_repo_clone_path      = "/tmp/.schematics/IBM/ibm-spectrumscale-cloud-deploy"
  storage_vsis_1A_by_ip            = module.spectrum_scale_storage[*].primary_network_interface
  strg_vsi_ids_0_disks             = module.spectrum_scale_storage.*.spectrum_scale_storage_id
  storage_vsi_ips_with_0_datadisks = local.storage_vsis_1A_by_ip
  vsi_data_volumes_count           = 0
  strg_vsi_ips_0_disks_dev_map = {
    for instance in local.storage_vsi_ips_with_0_datadisks :
    instance => local.vsi_data_volumes_count == 0 ? data.ibm_is_instance_profile.spectrum_scale_storage.disks.0.quantity.0.value == 1 ? ["/dev/vdb"] : ["/dev/vdb", "/dev/vdc"] : null
  }
  total_compute_instances  = var.management_node_count + var.worker_node_min_count
  compute_vsi_ids_0_disks  = concat(module.management_host.*.management_id, module.management_host_candidate.*.management_candidate_id, module.worker_vsi.*.worker_id)
  management_host_vsi_ip   = concat(module.management_host[*].primary_network_interface, module.management_host_candidate[*].primary_network_interface)
  compute_vsi_by_ip        = concat(local.management_host_vsi_ip, module.worker_vsi[*].primary_network_interface)
  validate_scale_count_cnd = !var.spectrum_scale_enabled || (var.spectrum_scale_enabled && (var.scale_storage_node_count > 1))
  validate_scale_count_msg = "Input \"scale_storage_node_count\" must be >= 2 and <= 18 and has to be divisible by 2."
  validate_scale_count_chk = regex(
    "^${local.validate_scale_count_msg}$",
    (local.validate_scale_count_cnd
      ? local.validate_scale_count_msg
  : ""))
  validate_scale_worker_min_cnd = !var.spectrum_scale_enabled || (var.spectrum_scale_enabled && (var.management_node_count + var.worker_node_min_count > 2 && var.worker_node_min_count > 0 && var.worker_node_min_count <= 64))
  validate_scale_worker_min_msg = "Input worker_node_min_count must be greater than 0 and less than or equal to 64 and total_quorum_node i.e, sum of management_node_count and worker_node_min_count should be greater than 2, if spectrum_scale_enabled set to true."
  validate_scale_worker_min_chk = regex(
    "^${local.validate_scale_worker_min_msg}$",
    (local.validate_scale_worker_min_cnd
      ? local.validate_scale_worker_min_msg
  : ""))

  validate_scale_worker_max_cnd = !var.spectrum_scale_enabled || (var.spectrum_scale_enabled && (var.worker_node_min_count == var.worker_node_max_count))
  validate_scale_worker_max_msg = "If scale is enabled, Input worker_node_min_count must be equal to worker_node_max_count."
  validate_scale_worker_max_check = regex(
    "^${local.validate_scale_worker_max_msg}$",
    (local.validate_scale_worker_max_cnd
      ? local.validate_scale_worker_max_msg
  : ""))
}

locals {

  dns_instance_id = module.dns_service.resource_guid

  # // Fetch if there is already a DNS custom resolver is associated to the existing VPC feature, if there is no DNS custom resolver associated new DNS service and CR will be created through our solution.
  # dns_reserved_ip = join("", flatten(toset([for details in data.ibm_is_subnet_reserved_ips.dns_reserved_ips : flatten(details[*].reserved_ips[*].target_crn)])))
  # dns_service_id  = local.dns_reserved_ip == "" ? "" : split(":", local.dns_reserved_ip)[7]
  # dns_instance_id = local.dns_reserved_ip == "" ? module.dns_service[0].resource_guid : local.dns_service_id
}

locals {
  encryption_key_crn = module.kms.encryption_key_crn
  # encryption_key_crn = var.enable_customer_managed_encryption ? data.ibm_kms_key.kms_key[0].keys[0].crn : ""
}

locals {
  rc_cidr_block = var.cluster_subnet_id == "" ? module.subnet[0].ipv4_cidr_block : data.ibm_is_subnet.existing_subnet[0].ipv4_cidr_block
  subnet_crn    = var.cluster_subnet_id == "" ? module.subnet[0].subnet_crn : data.ibm_is_subnet.existing_subnet[0].crn
}

data "ibm_is_public_gateways" "public_gateways" {
  count = var.vpc_name != "" && var.cluster_subnet_id == "" ? 1 : 0
}

locals {
  existing_pgw_id = var.vpc_name != "" && var.cluster_subnet_id == "" ? [for gateway in data.ibm_is_public_gateways.public_gateways[0].public_gateways : gateway.id if gateway.vpc == data.ibm_is_vpc.existing_vpc[0].id && gateway.zone == var.zone] : []
}
