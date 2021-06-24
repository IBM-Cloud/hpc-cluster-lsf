###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################


### About VPC resources
variable "ssh_key_name" {
  type        = string
  description = "Name of ssh key configured in your IBM Cloud account, that will be used to establish a connection to LSF master node. If you do not have a ssh key in your IBM Cloud please create one using instructions given here. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)"
}


variable "api_key" {
  type        = string
  description = "This is the API key for IBM Cloud account in which the Spectrum LSF cluster needs to be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-userapikey)"
  validation {
    condition     = var.api_key != ""
    error_message = "API key for IBM Cloud must be set."
  }
}

variable "lsf_license_confirmation" {
  type        = string
  description = "If you have confirmed the availability of a Spectrum LSF license for a production cluster on IBM Cloud OR if you are deploying a non-production cluster, enter 'true'. NOTE: Failure to comply with licenses for production use of software is a violation of IBM International Program License Agreement. [Learn more](https://www.ibm.com/software/passportadvantage/programlicense.html)"
  validation {
    condition = var.lsf_license_confirmation== "true"
    error_message = "If you have confirmed the availability of a Spectrum LSF license for a production cluster on IBM Cloud OR if you are deploying a non-production cluster, enter 'true'. NOTE: Failure to comply with licenses for production use of software is a violation of IBM International Program License Agreement. [Learn more](https://www.ibm.com/software/passportadvantage/programlicense.html)."
  }
}

### About LSF licensing
variable "ls_entitlement" {
  type        = string
  default     = "LS_Standard  10.1  ()  ()  ()  ()  18b1928f13939bd17bf25e09a2dd8459f238028f"
  description = "Entitlement file content for Spectrum LSF license scheduler."
  validation {
    condition     = trimspace(var.ls_entitlement) != ""
    error_message = "Entitlement for LSF scheduler must be set."
  }
}

variable "lsf_entitlement" {
  type        = string
  default     = "LSF_Standard  10.1  ()  ()  ()  pa  3f08e215230ffe4608213630cd5ef1d8c9b4dfea"
  description = "Entitlement file content for core Spectrum LSF software."
  validation {
    condition     = trimspace(var.lsf_entitlement) != ""
    error_message = "Entitlement for LSF must be set."
  }
}

variable "resource_group" {
  type        = string
  default     = "Default"
  description = "Resource group name from your IBM Cloud account where the VPC resources should be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-rgs)"
}

variable "cluster_prefix" {
  type        = string
  default     = "hpcc-lsf"
  description = "Prefix that would be used to name Spectrum LSF cluster and IBM Cloud resources provisioned to build the Spectrum LSF cluster instance. You cannot create more than one instance of LSF Cluster with same name, please make sure the name is unique. Enter a prefix name, such as my-hpcc"
}

variable "region" {
  type        = string
  default     = "us-south"
  description = "IBM Cloud region name where the Spectrum LSF cluster should be deployed. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region)"
}

variable "zone" {
  type        = string
  default     = "us-south-3"
  description = "IBM Cloud zone name within the selected region where the Spectrum LSF cluster should be deployed. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli)"
}

variable "image_name" {
  type        = string
  default     = "hpcc-lsf10-cent77-jun0421-v5"
  description = "Name of the custom image that you would like to use to create virtual machines in your IBM Cloud account to deploy Spectrum LSF Cluster. By default, our automation uses a base image with following HPC related packages documented here [Learn more](https://cloud.ibm.com/docs/ibm-spectrum-lsf). If you would like to include your application specific binaries please follow the instructions [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the Spectrum LSF cluster through this offering."
}

variable "management_node_instance_type" {
  type        = string
  default     = "bx2-4x16"
  description = "Please specify the VSI profile type name to be used to create the management nodes for Spectrum LSF cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.management_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "worker_node_instance_type" {
  type        = string
  default     = "bx2-4x16"
  description = "Please specify the VSI profile type name to be used to create the worker nodes for Spectrum LSF cluster. The worker nodes are the ones where the workload execution takes place and choice should be made according to the characteristic of workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.worker_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "login_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
  description = "Please specify the VSI profile type name to be used to create the login node for Spectrum LSF cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.login_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "storage_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
  description = "Please specify the VSI profile type name to be used to create the storage nodes for Spectrum LSF cluster. The storage nodes are the ones that would be used to create an NFS instance to manage the data for HPC workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.storage_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "worker_node_min_count" {
  type        = number
  default     = 0
  description = "The minimum number of worker nodes. This is the number of worker nodes that will be provisioned at the time the cluster is created. Enter a value in the range 0 - 500."
  validation {
    condition     = 0 <= var.worker_node_min_count && var.worker_node_min_count <= 500
    error_message = "Input \"worker_node_min_count\" must be >= 0 and <= 500."
  }
}

variable "worker_node_max_count" {
  type        = number
  default     = 10
  description = "The maximum number of worker nodes that should be added to Spectrum LSF cluster. This is to limit the number of machines that can be added to Spectrum LSF cluster when auto-scaling configuration is used. This property can be used to manage the cost associated with Spectrum LSF cluster instance. Enter a value in the range 1 - 500."
  validation {
    condition     = 1 <= var.worker_node_max_count && var.worker_node_max_count <= 500
    error_message = "Input \"worker_node_max_count must\" be >= 1 and <= 500."
  }
}

variable "volume_capacity" {
  type        = number
  default     = 100
  description = "Size in GB for the block storage that would be used to build the NFS instance and would be available as a mount on Spectrum LSF master node. Enter a value in the range 10 - 16000."
  validation {
    condition     = 10 <= var.volume_capacity && var.volume_capacity <= 16000
    error_message = "Input \"volume_capacity\" must be >= 10 and <= 16000."
  }
}

variable "volume_iops" {
  type        = number
  default     = 300
  description = "Number to represent the IOPS(Input Output Per Second) configuration for block storage to be used for NFS instance (valid only for volume_profile=custom, dependent on volume_capacity). Enter a value in the range 100 - 48000. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles#custom)"
  validation {
    condition     = 100 <= var.volume_iops && var.volume_iops <= 48000
    error_message = "Input \"volume_iops\" must be >= 100 and <= 48000."
  }
}

variable "management_node_count" {
  type        = number
  default     = 2
  description = "Number of management nodes. This is the total number of master and master candidates. Enter a value in the range 1 - 3."
  validation {
    condition     = 1 <= var.management_node_count && var.management_node_count <= 3
    error_message = "Input \"management_node_count\" must be >= 1 and <= 3."
  }
}

variable "ssh_allowed_ips" {
  #type        = list(string)
  #default     = ["0.0.0.0/0"]
  #description = "Allowed a list of IP or CIDR for public SSH. All addresses are allowed with default."
  type        = string
  default     = "0.0.0.0/0"
  description = "Comma separated list of IP addresses that can access the Spectrum LSF instance through SSH interface. The default value allows any IP address to access the cluster."
}

variable "volume_profile" {
  type        = string
  default     = "general-purpose"
  description = "Name of the block storage volume type to be used for NFS instance. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles)"
}

variable "TF_VERSION" {
  type        = string
  default     = "0.13"
  description = "The version of the Terraform engine that's used in the Schematics workspace."
}

variable "TF_PARALLELISM" {
  type        = string
  default     = "250"
  description = "Parallelism/ concurrent operations limit. Valid values are between 1 and 256, both inclusive. [Learn more](https://www.terraform.io/docs/internals/graph.html#walking-the-graph)"
  validation {
    condition     = 1 <= var.TF_PARALLELISM && var.TF_PARALLELISM <= 256
    error_message = "Input \"TF_PARALLELISM\" must be >= 1 and <= 256."
  }
}