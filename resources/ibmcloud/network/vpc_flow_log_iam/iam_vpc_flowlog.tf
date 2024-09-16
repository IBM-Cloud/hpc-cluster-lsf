terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "existing_storage_instance_guid" {}

resource "ibm_iam_authorization_policy" "policy" {
  source_service_name         = "is"
  source_resource_type        = "flow-log-collector"
  target_service_name         = "cloud-object-storage"
  target_resource_instance_id = var.existing_storage_instance_guid
  roles                       = ["Writer"]
}