data "ibm_resource_group" "rg" {
  name = var.resource_group
}

data "ibm_is_region" "region" {
  name = local.region_name
}

data "ibm_is_zone" "zone" {
  name   = var.zone
  region = data.ibm_is_region.region.name
}

data "ibm_is_vpc" "existing_vpc" {
  // Lookup for this VPC resource only if var.vpc_name is not empty
  count = var.vpc_name != "" ? 1 : 0
  name  = var.vpc_name
}

data "ibm_is_vpc" "vpc" {
  name = local.vpc_name
  // Depends on creation of new VPC or look up of existing VPC based on value of var.vpc_name,
  depends_on = [module.vpc, data.ibm_is_vpc.existing_vpc]
}
data "ibm_is_instance_profile" "management_host" {
  name = var.management_node_instance_type
}

data "ibm_is_instance_profile" "worker" {
  name = var.worker_node_instance_type
}

data "ibm_is_instance_profile" "storage" {
  name = var.storage_node_instance_type
}

data "ibm_is_dedicated_host_profiles" "worker" {
  count = var.dedicated_host_enabled ? 1 : 0
}

data "ibm_is_image" "image" {
  name  = var.image_name
  count = local.image_mapping_entry_found ? 0 : 1
}

#data "template_file" "storage_user_data" {
#  template = local.storage_template_file
#  vars = {
#    rc_cidr_block = var.cluster_subnet_id != "" ? data.ibm_is_subnet.existing_subnet[0].ipv4_cidr_block : module.subnet[0].ipv4_cidr_block
#  }
#}

data "ibm_is_subnet" "existing_subnet" {
  // Lookup for this Subnet resources only if var.cluster_subnet_id is not empty
  count      = var.cluster_subnet_id != "" ? 1 : 0
  identifier = var.cluster_subnet_id
}

data "http" "fetch_myip" {
  url = "http://ipv4.icanhazip.com"
}

data "ibm_is_subnet" "subnet_id" {
  for_each   = var.vpc_name == "" ? [] : toset(data.ibm_is_vpc.vpc.subnets[*].id)
  identifier = each.value
}

data "ibm_is_ssh_key" "ssh_key" {
  for_each = toset(split(",", var.ssh_key_name))
  name     = each.value
}

data "ibm_is_instance_profile" "login" {
  name = var.login_node_instance_type
}

data "ibm_is_image" "stock_image" {
  name = local.stock_image_name
}

data "ibm_is_instance_profile" "spectrum_scale_storage" {
  name = var.scale_storage_node_instance_type
}

data "ibm_is_image" "scale_image" {
  name  = var.scale_storage_image_name
  count = local.scale_image_mapping_entry_found ? 0 : 1
}

# data "ibm_is_subnet_reserved_ips" "dns_reserved_ips" {
#   for_each = toset([for subnetsdetails in data.ibm_is_subnet.subnet_id : subnetsdetails.id])
#   subnet   = each.value
# }

# data "ibm_dns_custom_resolvers" "dns_custom_resolver" {
#   count       = local.dns_reserved_ip == "" ? 0 : 1
#   instance_id = local.dns_service_id
# }

# data "ibm_kms_key" "kms_key" {
#   count       = var.enable_customer_managed_encryption ? 1 : 0
#   instance_id = var.kms_instance_id
#   key_name    = var.kms_key_name
# }

data "ibm_is_vpc_address_prefixes" "existing_vpc" {
  #count = var.vpc_name != "" ? 1 : 0
  vpc = data.ibm_is_vpc.vpc.id
}

data "ibm_is_subnet" "existing_login_subnet" {
  // Lookup for this Subnet resources only if var.login_subnet_id is not empty
  count      = (var.login_subnet_id != "" && var.vpc_name != "") ? 1 : 0
  identifier = var.login_subnet_id
}

data "ibm_is_image" "ldap_vsi_image" {
  name  = var.ldap_vsi_osimage_name
  count = var.ldap_basedns != null && var.ldap_server == "null" ? 1 : 0
} 