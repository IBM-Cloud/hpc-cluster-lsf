###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# Or we can switch the region via export IC_REGION="eu-gb"
terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.30.0"
    }
  }
}

# Or we can switch the region via export IC_REGION="eu-gb"
provider "ibm" {
  ibmcloud_api_key = var.api_key
  region           = var.region
}
