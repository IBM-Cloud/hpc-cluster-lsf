###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# This file contains the complete information on all the validations performed from the code during the generate plan process
# Validations are performed to make sure, the appropriate error messages are displayed to user in-order to provide required input parameter

locals {

  //validate storage gui password
  validate_storage_gui_password_cnd = (var.spectrum_scale_enabled && (replace(lower(var.scale_storage_cluster_gui_password), lower(var.scale_storage_cluster_gui_username), "" ) == lower(var.scale_storage_cluster_gui_password)) && can(regex("^.{8,}$", var.scale_storage_cluster_gui_password) != "") && can(regex("[0-9]{1,}", var.scale_storage_cluster_gui_password) != "") && can(regex("[a-z]{1,}", var.scale_storage_cluster_gui_password) != "") && can(regex("[A-Z]{1,}",var.scale_storage_cluster_gui_password ) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.scale_storage_cluster_gui_password ) != "" )&& trimspace(var.scale_storage_cluster_gui_password) != "") || !var.spectrum_scale_enabled
  password_msg = "Password should be at least 8 characters, must have one number, one lowercase letter, and one uppercase letter, at least one unique character. Password Should not contain username"
  validate_storage_gui_password_chk = regex(
          "^${local.password_msg}$",
          ( local.validate_storage_gui_password_cnd ? local.password_msg : "") )

  // validate compute gui password
  validate_compute_gui_password_cnd = (var.spectrum_scale_enabled && (replace(lower(var.scale_compute_cluster_gui_password), lower(var.scale_compute_cluster_gui_username),"") == lower(var.scale_compute_cluster_gui_password)) && can(regex("^.{8,}$", var.scale_compute_cluster_gui_password) != "") && can(regex("[0-9]{1,}", var.scale_compute_cluster_gui_password) != "") && can(regex("[a-z]{1,}", var.scale_compute_cluster_gui_password) != "") && can(regex("[A-Z]{1,}",var.scale_compute_cluster_gui_password ) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.scale_compute_cluster_gui_password ) != "" )&& trimspace(var.scale_compute_cluster_gui_password) != "") || !var.spectrum_scale_enabled
  validate_compute_gui_password_chk = regex(
          "^${local.password_msg}$",
          ( local.validate_compute_gui_password_cnd ? local.password_msg : ""))

  //validate scale storage gui user name
  validate_scale_storage_gui_username_cnd = (var.spectrum_scale_enabled && length(var.scale_storage_cluster_gui_username) >= 4 && length(var.scale_storage_cluster_gui_username) <= 32 && trimspace(var.scale_storage_cluster_gui_username) != "") || !var.spectrum_scale_enabled
  storage_gui_username_msg = "Specified input for \"storage_cluster_gui_username\" is not valid."
  validate_storage_gui_username_chk = regex(
          "^${local.storage_gui_username_msg}",
          (local.validate_scale_storage_gui_username_cnd? local.storage_gui_username_msg: ""))

  // validate compute gui username
  validate_compute_gui_username_cnd = (var.spectrum_scale_enabled && length(var.scale_compute_cluster_gui_username) >= 4 && length(var.scale_compute_cluster_gui_username) <= 32 && trimspace(var.scale_compute_cluster_gui_username) != "") || !var.spectrum_scale_enabled
  compute_gui_username_msg = "Specified input for \"compute_cluster_gui_username\" is not valid."
  validate_compute_gui_username_chk = regex(
          "^${local.compute_gui_username_msg}",
          (local.validate_compute_gui_username_cnd? local.compute_gui_username_msg: ""))

  // validate application center gui password
  validate_app_center_gui_pwd = (var.enable_app_center && can(regex("^.{8,}$", var.app_center_gui_pwd) != "") && can(regex("[0-9]{1,}", var.app_center_gui_pwd) != "") && can(regex("[a-z]{1,}", var.app_center_gui_pwd) != "") && can(regex("[A-Z]{1,}", var.app_center_gui_pwd ) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.app_center_gui_pwd ) != "" )&& trimspace(var.app_center_gui_pwd) != "") || !var.enable_app_center
  validate_app_center_gui_pwd_chk = regex(
    "^${local.password_msg}$",
    ( local.validate_app_center_gui_pwd ? local.password_msg : ""))

  // validate application center db password
  validate_app_center_db_pwd = (var.enable_app_center && can(regex("^.{8,}$", var.app_center_db_pwd) != "") && can(regex("[0-9]{1,}", var.app_center_db_pwd) != "") && can(regex("[a-z]{1,}", var.app_center_db_pwd) != "") && can(regex("[A-Z]{1,}", var.app_center_db_pwd ) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.app_center_db_pwd ) != "" )&& trimspace(var.app_center_db_pwd) != "") || !var.enable_app_center
  validate_app_center_db_pwd_chk = regex(
    "^${local.password_msg}$",
    ( local.validate_app_center_db_pwd ? local.password_msg : "") )
}