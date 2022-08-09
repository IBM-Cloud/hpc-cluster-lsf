###################################################
# Copyright (C) IBM Corp. 2022 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

variable "wait_duration" {}

resource "time_sleep" "waiter" {
  create_duration = var.wait_duration
}
