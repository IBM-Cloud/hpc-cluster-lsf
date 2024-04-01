//subnet_cidr is the cidr range of input subnet.
variable "subnet_cidr" {
}

//vpc_address_prefix is the cidr range of vpc address prefixes.
variable "vpc_address_prefix" {
  type    = list(string)
  default = []
}

locals {
  subnet_cidr = [for i in [var.subnet_cidr] : [(((split(".", cidrhost(i, 0))[0]) * pow(256, 3)) #192
    + ((split(".", cidrhost(i, 0))[1]) * pow(256, 2))
    + ((split(".", cidrhost(i, 0))[2]) * pow(256, 1))
    + ((split(".", cidrhost(i, 0))[3]) * pow(256, 0))), (((split(".", cidrhost(i, -1))[0]) * pow(256, 3)) #192
    + ((split(".", cidrhost(i, -1))[1]) * pow(256, 2))
    + ((split(".", cidrhost(i, -1))[2]) * pow(256, 1))
  + ((split(".", cidrhost(i, -1))[3]) * pow(256, 0)))]]
  vpc_address_prefix = [for i in var.vpc_address_prefix : [(((split(".", cidrhost(i, 0))[0]) * pow(256, 3)) #192
    + ((split(".", cidrhost(i, 0))[1]) * pow(256, 2))
    + ((split(".", cidrhost(i, 0))[2]) * pow(256, 1))
    + ((split(".", cidrhost(i, 0))[3]) * pow(256, 0))), (((split(".", cidrhost(i, -1))[0]) * pow(256, 3))
    + ((split(".", cidrhost(i, -1))[1]) * pow(256, 2))
    + ((split(".", cidrhost(i, -1))[2]) * pow(256, 1))
  + ((split(".", cidrhost(i, -1))[3]) * pow(256, 0)))]]
}

//
output "results" {
  value = [for ip in local.vpc_address_prefix : ip[0] <= local.subnet_cidr[0][0] && ip[1] >= local.subnet_cidr[0][1]]
}

