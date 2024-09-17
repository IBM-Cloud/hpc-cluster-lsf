###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################


### About VPC resources

/*
Note: Any variable in all capitalized letters is an environment variable that will be marked as hidden in the catalog title.  This variable will not be visible to customers using our offering catalog...
*/

variable "ssh_key_name" {
  type        = string
  description = "Comma-separated list of names of the SSH key configured in your IBM Cloud account that is used to establish a connection to the LSF management node. Ensure that the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the instructions given at [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
}

variable "api_key" {
  type        = string
  description = "This is the IBM Cloud API key for the IBM Cloud account where the IBM Spectrum LSF cluster needs to be deployed. For more information on how to create an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui)."
  sensitive   = true
  validation {
    condition     = var.api_key != ""
    error_message = "API key for IBM Cloud must be set."
  }
}

variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
  validation {
    # regex(...) fails if the IBM customer number has special characters.  
    condition     = can(regex("^[0-9A-Za-z]*([0-9A-Za-z]+,[0-9A-Za-z]+)*$", var.ibm_customer_number))
    error_message = "The IBM customer number input value cannot have special characters."
  }
}

variable "vpc_name" {
  type        = string
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)."
  default     = ""
}

variable "resource_group" {
  type        = string
  default     = "Default"
  description = "Resource group name from your IBM Cloud account where the VPC resources should be deployed. For additional information on resource groups, see [Managing resource groups](https://test.cloud.ibm.com/docs/account?topic=account-rgs&interface=ui)."
}

variable "cluster_prefix" {
  type        = string
  default     = "hpcc-lsf"
  description = "Prefix that is used to name the IBM Spectrum LSF cluster and IBM Cloud resources that are provisioned to build the IBM Spectrum LSF cluster instance. You cannot create more than one instance of the lsf cluster with the same name. Make sure that the name is unique."
}

variable "zone" {
  type        = string
  description = "IBM Cloud zone name within the selected region where the Spectrum LSF cluster should be deployed. To get a full list of zones within a region, see [Get zones by using the CLI](https://test.cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region&interface=cli#get-zones-using-the-cli)."
}

variable "vpc_cidr_block" {
  type        = list(string)
  default     = ["10.241.0.0/18"]
  description = "Creates the address prefix for the new VPC, when the vpc_name variable is empty. Only a single address prefix is allowed. For more information, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design)."
  validation {
    condition     = length(var.vpc_cidr_block) <= 1
    error_message = "Our Automation supports only a single AZ to deploy resources. Provide one CIDR range of address prefix."
  }
}

variable "vpc_cluster_private_subnets_cidr_blocks" {
  type        = list(string)
  default     = ["10.241.0.0/20"]
  description = "The CIDR block that's required for the creation of the compute and storage cluster private subnet. Modify the CIDR block if it has already been reserved or used for other applications within the VPC or conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the compute and storage subnet. Make sure to select a CIDR block size that will accommodate the maximum number of management, storage, and both static and dynamic worker nodes that you expect to have in your cluster.  For more information on CIDR block size selection, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
  validation {
    condition     = length(var.vpc_cluster_private_subnets_cidr_blocks) <= 1
    error_message = "Our Solution supports only a single AZ to deploy resources. Provide one CIDR range of subnet creation."
  }
}

variable "vpc_cluster_login_private_subnets_cidr_blocks" {
  type        = list(string)
  default     = ["10.241.16.0/28"]
  description = "The CIDR block that's required for the creation of the login cluster private subnet. Modify the CIDR block if it has already been reserved or used for other applications within the VPC or conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the login subnet. Since login subnet is used only for the creation of login virtual server instance provide a CIDR range of /28."
  validation {
    condition     = length(var.vpc_cluster_login_private_subnets_cidr_blocks) <= 1
    error_message = "Our Automation supports only a single AZ to deploy resources. Provide one CIDR range of subnet creation."
  }
  validation {
    condition     = tonumber(regex("/(\\d+)", join(",", var.vpc_cluster_login_private_subnets_cidr_blocks))[0]) <= 28
    error_message = "Our solution uses this subnet to create only a login virtual server instance, providing a bigger CIDR size will waste the usage of available IP. A CIDR range of /28 is sufficient for the creation of login subnet."
  }
}

variable "cluster_subnet_id" {
  default     = ""
  description = "Existing cluster subnet ID under the VPC, where the cluster will be provisioned."
  validation {
    condition     = var.cluster_subnet_id == "" || can(regex("^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*[a-zA-Z0-9]+$", var.cluster_subnet_id))
    error_message = "The cluster_subnet_id value should either be empty or exactly one subnet_id."
  }
}

variable "login_subnet_id" {
  default     = ""
  description = "Existing Login subnet ID under the VPC, where the bastion/login will be provisioned."
  validation {
    condition     = var.login_subnet_id == "" || can(regex("^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*[a-zA-Z0-9]+$", var.login_subnet_id))
    error_message = "The login_subnet_id value should either be empty or exactly one subnet_id."
  }
}

variable "dns_instance_id" {
  type        = string
  default     = ""
  description = "IBM Cloud HPC DNS service resource id."
}

variable "dns_custom_resolver_id" {
  type        = string
  default     = ""
  description = "IBM Cloud DNS custom resolver id."
}

variable "dns_domain" {
  type        = string
  default     = "lsf.com"
  description = "IBM Cloud DNS Services domain name to be used for the IBM Cloud LSF cluster."
  validation {
    condition     = can(regex("^([[:alnum:]]*[A-Za-z0-9-]{1,63}\\.)+[A-Za-z]{2,6}$", var.dns_domain))
    error_message = "The domain name provided is not a fully qualified domain name (FQDN). An FQDN can contain letters (a-z, A-Z), digits (0-9), hyphens (-), dots (.), and must start and end with an alphanumeric character."
  }
}

variable "cluster_id" {
  type        = string
  default     = "HPCCluster"
  description = "Unique ID of the cluster used by LSF for configuration of resources. This can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. Other special characters and spaces are not allowed. Do not use the name of any host or user as the name of your cluster. You cannot change the cluster ID after deployment."
  validation {
    condition     = 0 < length(var.cluster_id) && length(var.cluster_id) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_id))
    error_message = "The ID can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. Other special characters and spaces are not allowed."
  }
}

variable "image_name" {
  type        = string
  default     = "hpcc-lsf10-scale5201-rhel88-5-0"
  description = "Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Spectrum LSF cluster. By default, the automation uses a base image with additional software packages documented [here](https://cloud.ibm.com/docs/ibm-spectrum-lsf). If you would like to include your application-specific binary files, follow the instructions in [Planning for custom images](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Spectrum LSF cluster through this offering."
}

variable "management_node_instance_type" {
  type        = string
  default     = "bx2-4x16"
  description = "Specify the virtual server instance profile type to be used to create the management nodes for the Spectrum LSF cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.management_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "worker_node_instance_type" {
  type        = string
  default     = "bx2-4x16"
  description = "Specify the virtual server instance profile type name to be used to create the worker nodes for the Spectrum LSF cluster. The worker nodes are the ones where the workload execution takes place and the choice should be made according to the characteristic of workloads. For choices on profile types, see [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui). Note: If dedicated_host_enabled == true, available instance prefix (e.g., bx2 and cx2) can be limited depending on your target region. Check `ibmcloud target -r {region_name}; ibmcloud is dedicated-host-profiles."
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.worker_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "login_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
  description = "Specify the VSI profile type name to be used to create the login node for Spectrum LSF cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.login_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "storage_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
  description = "Specify the virtual server instance profile type to be used to create the storage nodes for the Spectrum LSF cluster. The storage nodes are the ones that are used to create an NFS instance to manage the data for HPC workloads.  For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.storage_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "worker_node_min_count" {
  type        = number
  default     = 0
  description = "The minimum number of worker nodes. This is the number of static worker nodes that will be provisioned at the time the cluster is created. If using NFS storage, enter a value in the range 0 - 500. If using Spectrum Scale storage, enter a value in the range 1 - 64. NOTE: Spectrum Scale requires a minimum of 3 compute nodes (combination of management-host, management-host-candidate, and worker nodes) to establish a [quorum](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=failure-quorum#nodequo) and maintain data consistency in the event of a node failure. Therefore, the minimum value of 1 may need to be larger if the value specified for management_node_count is less than 2."
  validation {
    condition     = 0 <= var.worker_node_min_count && var.worker_node_min_count <= 500
    error_message = "Input \"worker_node_min_count\" must be >= 0 and <= 500."
  }
}

variable "worker_node_max_count" {
  type        = number
  default     = 10
  description = "The maximum number of worker nodes that can be deployed in the Spectrum LSF cluster. In order to use the [Resource Connector](https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=lsf-resource-connnector) feature to dynamically create and delete worker nodes based on workload demand, the value selected for this parameter must be larger than worker_node_min_count. If you plan to deploy only static worker nodes in the LSF cluster, e.g., when using Spectrum Scale storage, the value for this parameter should be equal to worker_node_min_count. Enter a value in the range 1 - 500."
  validation {
    condition     = 1 <= var.worker_node_max_count && var.worker_node_max_count <= 500
    error_message = "Input \"worker_node_max_count must\" be >= 1 and <= 500."
  }
}

variable "management_node_count" {
  type        = number
  default     = 2
  description = "Number of management nodes. This is the total number of management and management candidates. Enter a value in the range 1 - 3."
  validation {
    condition     = 1 <= var.management_node_count && var.management_node_count <= 3
    error_message = "Input \"management_node_count\" must be >= 1 and <= 3."
  }
}

variable "remote_allowed_ips" {
  type        = list(string)
  description = "Comma-separated list of IP addresses that can access the Spectrum LSF instance through an SSH or RDP interface. For security purposes, provide the public IP addresses assigned to the devices that are authorized to establish SSH or RDP connections (for example, [\"169.45.117.34\"]). To fetch the IP address of the device, use [https://ipv4.icanhazip.com/](https://ipv4.icanhazip.com/)."
  validation {
    condition = alltrue([
      for o in var.remote_allowed_ips : !contains(["0.0.0.0/0", "0.0.0.0"], o)
    ])
    error_message = "For the purpose of security provide the public IP address(es) assigned to the device(s) authorized to establish SSH connections. Use https://ipv4.icanhazip.com/ to fetch the ip address of the device."
  }
  validation {
    condition = alltrue([
      for a in var.remote_allowed_ips : can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", a))
    ])
    error_message = "Provided IP address format is not valid. Check if Ip address format has comma instead of dot and there should be double quotes between each IP address range if using multiple ip ranges. For multiple IP address use format [\"169.45.117.34\",\"128.122.144.145\"]."
  }
}

variable "hyperthreading_enabled" {
  type        = bool
  default     = true
  description = "Setting this to true will enable hyper-threading in the worker nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
}

variable "vpn_enabled" {
  type        = bool
  default     = false
  description = "Set to true to deploy a VPN gateway for VPC in the cluster."
}

variable "vpn_peer_cidrs" {
  type        = string
  default     = ""
  description = "Comma separated list of peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected."
}

variable "vpn_peer_address" {
  type        = string
  default     = ""
  description = "The peer public IP address to which the VPN will be connected."
}

variable "vpn_preshared_key" {
  type        = string
  default     = ""
  description = "The pre-shared key for the VPN."
}

variable "dedicated_host_enabled" {
  type        = bool
  default     = false
  description = "Set to true to use dedicated hosts for compute hosts (default: false). Note that lsf still dynamically provisions compute hosts at public VSIs and dedicated hosts are used only for static compute hosts provisioned at the time the cluster is created. The number of dedicated hosts and the profile names for dedicated hosts are calculated from worker_node_min_count and dedicated_host_type_name."
}

variable "dedicated_host_placement" {
  type        = string
  default     = "spread"
  description = "Specify 'pack' or 'spread'. The 'pack' option will deploy VSIs on one dedicated host until full before moving on to the next dedicated host. The 'spread' option will deploy VSIs in round-robin fashion across all the dedicated hosts. The second option should result in mostly even distribution of VSIs on the hosts, while the first option could result in one dedicated host being mostly empty."
  validation {
    condition     = var.dedicated_host_placement == "spread" || var.dedicated_host_placement == "pack"
    error_message = "Supported values for dedicated_host_placement: spread or pack."
  }
}

variable "TF_VERSION" {
  type        = string
  default     = "1.5"
  description = "The version of the Terraform engine that's used in the Schematics workspace."
}

variable "TF_PARALLELISM" {
  type        = string
  default     = "250"
  description = "Parallelism/ concurrent operations limit. Valid values are between 1 and 256, both inclusive. [Learn more](https://www.terraform.io/docs/internals/graph.html#walking-the-graph)."
  validation {
    condition     = 1 <= var.TF_PARALLELISM && var.TF_PARALLELISM <= 256
    error_message = "Input \"TF_PARALLELISM\" must be >= 1 and <= 256."
  }
}

variable "spectrum_scale_enabled" {
  type        = bool
  default     = false
  description = "Setting this to true will enables Spectrum Scale integration with the cluster. Otherwise, Spectrum Scale integration will be disabled (default). By entering 'true' for the property, you have also agreed to one of the two conditions: (1) You are using the software in production and confirm you have sufficient licenses to cover your use under the International Program License Agreement (IPLA). (2) You are evaluating the software and agree to abide by the International License Agreement for Evaluation of Programs (ILAE). Note: Failure to comply with licenses for production use of software is a violation of [IBM International Program License Agreement](https://www.ibm.com/software/passportadvantage/programlicense.html)."
}

variable "scale_storage_image_name" {
  type        = string
  default     = "hpcc-scale5201-rhel88"
  description = "Name of the custom image that you would like to use to create virtual machines in your IBM Cloud account to deploy the Spectrum Scale storage cluster. By default, the automation uses a base image plus the Spectrum Scale software and any other software packages that it requires. If you would like, you can follow the instructions for [Planning for custom images](https://test.cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the Spectrum Scale storage cluster through this offering."
}

variable "scale_storage_node_count" {
  type        = number
  default     = 4
  description = "The number of Spectrum scale storage nodes that will be provisioned at the time the cluster is created. Enter a value in the range 2 - 18. It must to be divisible of 2."
  validation {
    condition     = (var.scale_storage_node_count == 0) || (var.scale_storage_node_count >= 2 && var.scale_storage_node_count <= 34 && var.scale_storage_node_count % 2 == 0)
    error_message = "Input \"scale_storage_node_count\" must be >= 2 and <= 18 and has to be divisible by 2."
  }
}

variable "scale_storage_node_instance_type" {
  type        = string
  default     = "cx2d-8x16"
  description = "Specify the virtual server instance storage profile type name to be used to create the Spectrum Scale storage nodes for the Spectrum Storage cluster. For more information, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[b|c|m]x[0-9]+d-[0-9]+x[0-9]+", var.scale_storage_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "scale_storage_cluster_filesystem_mountpoint" {
  type        = string
  default     = "/gpfs/fs1"
  description = "Spectrum Scale Storage cluster (owningCluster) Filesystem mount point. The owningCluster is the cluster that owns and serves the file system to be mounted. [Mounting a remote GPFS file system](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=system-mounting-remote-gpfs-file)."

  validation {
    condition     = can(regex("^\\/[a-z0-9A-Z-_]+\\/[a-z0-9A-Z-_]+$", var.scale_storage_cluster_filesystem_mountpoint))
    error_message = "Specified value for \"storage_cluster_filesystem_mountpoint\" is not valid (valid: /gpfs/fs1)."
  }
}

variable "scale_filesystem_block_size" {
  type        = string
  default     = "4M"
  description = "File system [block size](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=considerations-block-size). Spectrum Scale supported block sizes (in bytes) include: 256K, 512K, 1M, 2M, 4M, 8M, 16M."

  validation {
    condition     = can(regex("^256K$|^512K$|^1M$|^2M$|^4M$|^8M$|^16M$", var.scale_filesystem_block_size))
    error_message = "Specified block size must be a valid IBM Spectrum Scale supported block sizes (256K, 512K, 1M, 2M, 4M, 8M, 16M)."
  }
}

variable "scale_storage_cluster_gui_username" {
  type        = string
  sensitive   = true
  default     = ""
  description = "GUI user to perform system management and monitoring tasks on storage cluster. Note: Username should be at least 4 characters, any combination of lowercase and uppercase letters."
}

variable "scale_storage_cluster_gui_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password for Spectrum Scale storage cluster GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one unique character. Password should not contain username."
}

variable "scale_compute_cluster_gui_username" {
  type        = string
  sensitive   = true
  default     = ""
  description = "GUI user to perform system management and monitoring tasks on compute cluster. Note: Username should be at least 4 characters, any combination of lowercase and uppercase letters."
}

variable "scale_compute_cluster_gui_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password for Compute cluster GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one unique character. Password should not contain username."
}

variable "scale_compute_cluster_filesystem_mountpoint" {
  type        = string
  default     = "/gpfs/fs1"
  description = "Compute cluster (accessingCluster) file system mount point. The accessingCluster is the cluster that accesses the owningCluster. For more information, see [Mounting a remote GPFS file system](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=system-mounting-remote-gpfs-file)."
  validation {
    condition     = can(regex("^\\/[a-z0-9A-Z-_]+\\/[a-z0-9A-Z-_]+$", var.scale_compute_cluster_filesystem_mountpoint))
    error_message = "Specified value for \"compute_cluster_filesystem_mountpoint\" is not valid (valid: /gpfs/fs1)."
  }
}

variable "TF_WAIT_DURATION" {
  type        = string
  default     = "210s"
  description = "wait duration time set for the storage and worker node to complete the entire setup"
}

variable "enable_app_center" {
  type        = bool
  default     = false
  description = "Set to true to install and enable use of the IBM Spectrum LSF Application Center GUI (default: false). [System requirements](https://www.ibm.com/docs/en/slac/10.2.0?topic=requirements-system-102-fix-pack-14) for IBM Spectrum LSF Application Center Version 10.2 Fix Pack 14."
}

variable "app_center_gui_pwd" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password for Application Center GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one special character."
}

variable "app_center_db_pwd" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password for MariaDB. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one special character."
}

variable "enable_customer_managed_encryption" {
  type        = bool
  default     = true
  description = "Setting this to true will enable customer managed encryption. Otherwise, encryption will be provider managed."
}

variable "kms_instance_id" {
  type        = string
  default     = ""
  description = "Unique identifier of the Key Protect instance associated with the Key Management Service. While providing an existing “kms_instance_id”, it's necessary to create the required authorization policy for encryption to be completed. To create the authorisation policy, go to [Service authorizations](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=ui). The ID can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui)."
}

variable "kms_key_name" {
  type        = string
  default     = ""
  description = "Provide the existing KMS encryption key name that you want to use for the IBM Cloud LSF cluster. (for example kms_key_name: my-encryption-key)."
}

variable "custom_file_shares" {
  type = list(object({
    mount_path = string,
    size       = number,
    iops       = number
  }))
  default     = [{ mount_path = "/mnt/binaries", size = 100, iops = 2000 }, { mount_path = "/mnt/data", size = 100, iops = 6000 }]
  description = "Mount points and sizes in GB and IOPS range of file shares that can be used to customize shared file storage layout. Provide the details for up to 5 shares. Each file share size in GB supports different range of IOPS. For more information, see [file share IOPS value](https://cloud.ibm.com/docs/vpc?topic=vpc-file-storage-profiles&interface=ui)."
  validation {
    condition     = length(var.custom_file_shares) <= 5
    error_message = "The custom file share count \"custom_file_shares\" must be less than or equal to 5."
  }
  validation {
    condition     = !anytrue([for mounts in var.custom_file_shares : mounts.mount_path == "/mnt/lsf"])
    error_message = "The mount path /mnt/lsf is reserved for internal usage and can't be used as file share mount_path."
  }
  validation {
    condition     = length([for mounts in var.custom_file_shares : mounts.mount_path]) == length(toset([for mounts in var.custom_file_shares : mounts.mount_path]))
    error_message = "Mount path values should not be duplicated."
  }
  validation {
    condition     = alltrue([for mounts in var.custom_file_shares : (10 <= mounts.size && mounts.size <= 32000)])
    error_message = "The custom_file_share size must be greater than or equal to 10 and less than or equal to 32000."
  }
}

###########################################################################
# List of script filenames used by validation test suites.
# If provided, these scripts will be executed as part of validation test suites execution.
###########################################################################

# variable "TF_VALIDATION_SCRIPT_FILES" {
#   type        = list(string)
#   default     = []
#   description = "List of script file names used by validation test suites. If provided, these scripts will be executed as part of validation test suites execution."
#   validation {
#     condition     = alltrue([for filename in var.TF_VALIDATION_SCRIPT_FILES : can(regex(".*\\.sh$", filename))])
#     error_message = "All validation script file names must end with .sh."
#   }
# }

###########################################################################
# LDAP Variables
###########################################################################

variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false."
}

variable "ldap_basedns" {
  type        = string
  default     = "hpcaas.com"
  description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
}

variable "ldap_server" {
  type        = string
  default     = "null"
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required. It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
}

variable "ldap_user_name" {
  type        = string
  default     = ""
  description = "Custom LDAP User for performing cluster operations. Note: Username should be between 4 to 32 characters, (any combination of lowercase and uppercase letters).[This value is ignored for an existing LDAP server]"
}

variable "ldap_user_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required.It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
}

variable "ldap_vsi_profile" {
  type        = string
  default     = "cx2-2x4"
  description = "Profile to be used for LDAP virtual server instance."
}

variable "ldap_vsi_osimage_name" {
  type        = string
  default     = "ibm-ubuntu-22-04-4-minimal-amd64-3"
  description = "Image name to be used for provisioning the LDAP instances."
}

variable "compute_image_name" {
  type        = string
  default     = "hpc-lsf10-rhel88-worker-v1"
  description = "Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud HPC cluster dynamic compute nodes. By default, the solution uses a RHEL 8-6 OS image with additional software packages mentioned [here](https://cloud.ibm.com/docs/hpc-spectrum-LSF#create-custom-image). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Cloud HPC cluster through this offering."
}

variable "enable_vpc_flow_logs" {
  description = "Flag to enable VPC flow logs. If true, a flow log collector will be created."
  type        = bool
  default     = false
}

variable "create_authorization_policy_vpc_to_cos" {
  description = "Set it to true if authorization policy is required for VPC to access COS. This can be set to false if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for VPC flow log](https://cloud.ibm.com/docs/vpc?topic=vpc-ordering-flow-log-collector&interface=ui#fl-before-you-begin-ui)."
  type        = bool
  default     = false
}

variable "existing_cos_instance_guid" {
  description = "GUID of the COS instance to create a flow log collector."
  type        = string
  default     = null
}

variable "existing_storage_bucket_name" {
  description = "Name of the COS bucket to collect VPC flow logs."
  type        = string
  default     = null
}

variable "is_flow_log_collector_active" {
  description = "Indicates whether the collector is active. If false, this collector is created in inactive mode."
  type        = bool
  default     = true
}

