###################################################
# Copyright (C) IBM Corp. 2022 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# !/usr/bin/env python3


import argparse
import json
import pathlib

REMOTE_MOUNT_DEFINITION_JSON = {'scale_remotemount': {}, 'node_details': []}


def read_tf_inv_file(tf_inv_path):
    """ Read the terraform inventory json file """
    with open(tf_inv_path) as json_handler:
        tf_inv = json.load(json_handler)
    return tf_inv


if __name__ == "__main__":
    PARSER = argparse.ArgumentParser(description='Convert terraform inventory '
                                                 'to ansible inventory format '
                                                 'used for remote mount.')
    PARSER.add_argument('--compute_tf_inv_path', required=True,
                        help='Terraform compute inventory file path')
    PARSER.add_argument('--storage_tf_inv_path', required=True,
                        help='Terraform storage inventory file path')
    PARSER.add_argument('--remote_mount_def_path', required=True,
                        help='Spectrum Scale remote mount json path')
    PARSER.add_argument('--ansible_ssh_private_key_file', required=True,
                        help='Ansible SSH private key file (Ex: /root/tf_data_path/id_rsa)')
    PARSER.add_argument('--verbose', action='store_true',
                        help='print log messages')
    ARGUMENTS = PARSER.parse_args()

    COMPUTETF_INV = read_tf_inv_file(ARGUMENTS.compute_tf_inv_path)
    STORAGETF_INV = read_tf_inv_file(ARGUMENTS.storage_tf_inv_path)

    if ARGUMENTS.verbose:
        print("Parsed terraform output: %s" % json.dumps(COMPUTETF_INV, indent=4))
        print("Parsed terraform output: %s" % json.dumps(STORAGETF_INV, indent=4))

    REMOTE_MOUNT_DEFINITION_JSON['node_details'].append({"fqdn": STORAGETF_INV['gui_hostname'],
                                                         "ip_address": STORAGETF_INV['gui_hostname'],
                                                         "ansible_user": "root",
                                                         "ansible_ssh_private_key_file": ARGUMENTS.ansible_ssh_private_key_file,
                                                         "is_protocol_node": False,
                                                         "is_nsd_server": False,
                                                         "is_quorum_node": False,
                                                         "is_manager_node": False,
                                                         "is_gui_server": False,
                                                         "is_callhome_node": False,
                                                         "scale_zimon_collector": False})

    REMOTE_MOUNT_DEFINITION_JSON['scale_remotemount']['client_gui_username'] = COMPUTETF_INV['gui_username']
    REMOTE_MOUNT_DEFINITION_JSON['scale_remotemount']['client_gui_password'] = COMPUTETF_INV['gui_password']
    REMOTE_MOUNT_DEFINITION_JSON['scale_remotemount']['client_gui_hostname'] = COMPUTETF_INV['gui_hostname']
    REMOTE_MOUNT_DEFINITION_JSON['scale_remotemount']['client_filesystem_name'] = pathlib.PurePath(COMPUTETF_INV['filesystem_mountpoint']).name
    REMOTE_MOUNT_DEFINITION_JSON['scale_remotemount']['client_remotemount_path'] = COMPUTETF_INV['filesystem_mountpoint']

    REMOTE_MOUNT_DEFINITION_JSON['scale_remotemount']['storage_gui_username'] = STORAGETF_INV['gui_username']
    REMOTE_MOUNT_DEFINITION_JSON['scale_remotemount']['storage_gui_password'] = STORAGETF_INV['gui_password']
    REMOTE_MOUNT_DEFINITION_JSON['scale_remotemount']['storage_gui_hostname'] = STORAGETF_INV['gui_hostname']
    REMOTE_MOUNT_DEFINITION_JSON['scale_remotemount']['storage_filesystem_name'] = pathlib.PurePath(STORAGETF_INV['filesystem_mountpoint']).name

    if ARGUMENTS.verbose:
        print("Content of remote_mount_definition.json: ",
              json.dumps(REMOTE_MOUNT_DEFINITION_JSON, indent=4))

    # Write json content
    if ARGUMENTS.verbose:
        print("Writing cloud infrastructure details to: ", ARGUMENTS.remote_mount_def_path)
    with open(ARGUMENTS.remote_mount_def_path, 'w') as json_fh:
        json.dump(REMOTE_MOUNT_DEFINITION_JSON, json_fh, indent=4)
    if ARGUMENTS.verbose:
        print("Completed writing cloud infrastructure details to: ",
              ARGUMENTS.remote_mount_def_path)
