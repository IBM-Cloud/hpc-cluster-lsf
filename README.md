# hpc-cluster-lsf
Repository for the HPC Cluster LSF implementation files. [Learn more](https://cloud.ibm.com/docs/ibm-spectrum-lsf)

# Deployment with Schematics on IBM Cloud

Initial configuration:

```
$ cp sample/configs/hpc_workspace_config.json config.json
$ ibmcloud iam api-key-create trl-tyos-api-key --file ~/.ibm-api-key.json -d "my api key"
$ cat ~/.ibm-api-key.json | jq -r ."apikey"
# copy your apikey
$ vim config.json
# paste your apikey and set entitlements for LSF
```

You also need to generate github token if you use private Github repository.

Deployment:

```
$ ibmcloud schematics workspace new -f config.json --github-token xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ ibmcloud schematics workspace list
Name               ID                                            Description   Status     Frozen
hpcc-lsf-test       us-east.workspace.hpcc-lsf-test.7cbc3f6b                     INACTIVE   False

OK
$ ibmcloud schematics apply --id us-east.workspace.hpcc-lsf-test.7cbc3f6b
Do you really want to perform this action? [y/N]> y

Activity ID b0a909030f071f51d6ceb48b62ee1671

OK
$ ibmcloud schematics logs --id us-east.workspace.hpcc-lsf-test.7cbc3f6b
...
 2021/04/05 09:44:54 Terraform apply | Apply complete! Resources: 14 added, 0 changed, 0 destroyed.
 2021/04/05 09:44:54 Terraform apply |
 2021/04/05 09:44:54 Terraform apply | Outputs:
 2021/04/05 09:44:54 Terraform apply |
 2021/04/05 09:44:54 Terraform apply | sshcommand = ssh -J root@52.116.124.67  lsfadmin@10.241.0.6
 2021/04/05 09:44:54 Command finished successfully.
 2021/04/05 09:45:00 Done with the workspace action

OK
$ ssh -J root@52.116.124.67  lsfadmin@10.241.0.6

$ ibmcloud schematics destroy --id us-east.workspace.hpcc-lsf-test.7cbc3f6b
```

# Steps to validate the cluster post provisioning

* Login to controller node using ssh command
* Check the existing machines part of cluster using $bhosts or $bhosts -w command, this should show all instances
* Submit a job that would spin 1 VM and sleep for 10 seconds -> $bsub -n 1 sleep 10, once submitted command line will show a jobID
* Check the status for job using -> $bjobs -l <jobID>
* Check the log file under /opt/ibm/lsf/log/ibmgen2... for any messages around provisioning of the new machine
* Continue to check status of nodes using lshosts, bjobs or bhosts commands
* To test multiple VMs you can run multiple sleep jobs -> $bsub -n 10 sleep 10 -> This will create 10 VMs and each job will sleep for 10 seconds

# Storage Node and NFS Setup
The storage node is configured as an NFS server and the data volume is mounted to the /data directory which is exported to share with LSF cluster nodes.

### Steps to validate NFS Storage node 
###### 1. To validate the NFS storage is setup and exported correctly
* Login to the storage node using SSH (ssh -J root@52.116.122.64 root@10.240.128.36)
* The below command shows that the data volume, /dev/vdd, is mounted to /data on the storage node.
```
# df -k | grep data
/dev/vdd       104806400 1828916 102977484   2% /data`
```
* The command below shows that /data is exported as a NFS shared directory.

```
# exportfs -v
/data         	10.242.66.0/23(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,no_root_squash,no_all_squash)
```

* At the NFS client end, the LSF cluster nodes in this case, we mount the /data directory in NFS server to the local directory, /mnt/data.
```
# df -k | grep data
10.242.66.4:/data 104806400  1828864 102977536   2% /mnt/data
```
The command above shows that the local directory, /mnt/data, is mounted to the remote /data directory on the NFS server, 10.242.66.4.

For ease of use, we create a soft link, /home/lsfadmin/shared, pointed to /mnt/data. The data that needs to be shared across the cluster can be placed in /home/lsfadmin/shared.
```
/home/lsfadmin>ls -l
total 0
lrwxrwxrwx. 1 root root 9 May 27 14:52 shared -> /mnt/data
```

###### 2. Steps to validate whether the clients are able to write to the NFS storage

* Login to the controller as shown in the ssh_command output
```
$ ssh -J root@52.116.122.64 lsfadmin@10.241.0.20
```
* Submit a job to write the host name to the /home/lsfadmin/shared directory on the NFS server
```
$ bsub sh -c 'echo $HOSTNAME > /home/lsfadmin/shared/hello.txt'
```
* Wait until the job is finished and then run the command to confirm the hostname is written to the file on the NFS share
```
$ bjobs
$ cat /home/lsfadmin/shared/hello.txt
ibm-gen2host-10-241-0-21  # worker hostname
```
###### 3. steps to validate spectrum scale integration
* Login to scale storage node using SSH. (`ssh -J root@52.116.122.64 root@10.240.128.37`, 
  details will be available in the logs output with key `spectrum_scale_storage_ssh_command`)
* The below command shows the gpfs cluster setup on scale storage node.
```buildoutcfg
# /usr/lpp/mmfs/bin/mmlscluster
```
* The below command shows file system mounted on number of nodes
```buildoutcfg
# /usr/lpp/mmfs/bin/mmlsmount all
```
* The below command shows the fileserver details. This command can be used to validate file block size(Inode size in bytes).
```buildoutcfg
#   /usr/lpp/mmfs/bin/mmlsfs all -i
```
* Login to controller node using SSH. (ssh -J root@52.116.122.64 root@10.240.128.41)
* The below command shows the gpfs cluster setup on computes node. This should contain the controller,controller-candidate, and worker nodes.
```buildoutcfg
# /usr/lpp/mmfs/bin/mmlscluster
```
* Create a file on mountpoint path(e.g `/gpfs/fs1`) and verify on other nodes that the file can be accessed.
###### 4. steps to accessing the Scale cluster GUI

* Open a new command line terminal.
* Run the following command to access the storage cluster:

```buildoutcfg
#ssh -L 22443:localhost:443 -J root@{FLOATING_IP_ADDRESS} root@{STORAGE_NODE_IP_ADDRESS}
```
* where STORAGE_NODE_IP_ADDRESS needs to be replaced with the storage IP address associated with hpc-pc-scale-storage-0, which you gathered earlier, and FLOATING_IP_ADDRESS needs to be replaced with the floating IP address that you identified.

* Open a browser on the local machine, and run https://localhost:22443. You will get an SSL self-assigned certificate warning with your browser the first time that you access this URL.
* Enter your login credentials that you set up when you created your workspace to access the Spectrum Scale GUI.
Accessing the compute cluster

* Open a new command line terminal.
* Run the following command to access the compute cluster:

```buildoutcfg
 #ssh -L 21443:localhost:443 -J root@{FLOATING_IP_ADDRESS} root@{COMPUTE_NODE_IP_ADDRESS}
 ```
* where COMPUTE_NODE_IP_ADDRESS needs to be replaced with the storage IP address associated with hpc-pc-primary-0, which you gathered earlier, and FLOATING_IP_ADDRESS needs to be replaced with the floating IP address that you identified.

* Open a browser on the local machine, and run https://localhost:21443. You will get an SSL self-assigned certificate warning with your browser the first time that you access this URL.
* Enter your login credentials that you set up when you created your workspace to access the Spectrum Scale GUI.

# Terraform Documentation

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | 1.41.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_http"></a> [http](#provider\_http) | 3.0.1   |
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | 1.41.0  |
| <a name="provider_null"></a> [null](#provider\_null) | n/a     |
| <a name="provider_template"></a> [template](#provider\_template) | n/a     |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_compute_nodes_wait"></a> [compute\_nodes\_wait](#module\_compute\_nodes\_wait) | ./resources/scale_common/wait | n/a |
| <a name="module_invoke_compute_playbook"></a> [invoke\_compute\_playbook](#module\_invoke\_compute\_playbook) | ./resources/scale_common/ansible_compute_playbook | n/a |
| <a name="module_invoke_remote_mount"></a> [invoke\_remote\_mount](#module\_invoke\_remote\_mount) | ./resources/scale_common/ansible_remote_mount_playbook | n/a |
| <a name="module_invoke_storage_playbook"></a> [invoke\_storage\_playbook](#module\_invoke\_storage\_playbook) | ./resources/scale_common/ansible_storage_playbook | n/a |
| <a name="module_login_ssh_key"></a> [login\_ssh\_key](#module\_login\_ssh\_key) | ./resources/scale_common/generate_keys | n/a |
| <a name="module_permission_to_lsfadmin_for_mount_point"></a> [permission\_to\_lsfadmin\_for\_mount\_point](#module\_permission\_to\_lsfadmin\_for\_mount\_point) | ./resources/scale_common/add_permission | n/a |
| <a name="module_prepare_spectrum_scale_ansible_repo"></a> [prepare\_spectrum\_scale\_ansible\_repo](#module\_prepare\_spectrum\_scale\_ansible\_repo) | ./resources/scale_common/git_utils | n/a |
| <a name="module_remove_ssh_key"></a> [remove\_ssh\_key](#module\_remove\_ssh\_key) | ./resources/scale_common/remove_ssh | n/a |
| <a name="module_schematics_sg_tcp_rule"></a> [schematics\_sg\_tcp\_rule](#module\_schematics\_sg\_tcp\_rule) | ./resources/ibmcloud/security | n/a |
| <a name="module_storage_nodes_wait"></a> [storage\_nodes\_wait](#module\_storage\_nodes\_wait) | ./resources/scale_common/wait | n/a |

## Resources

| Name | Type |
|------|------|
| [ibm_is_dedicated_host.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_dedicated_host) | resource |
| [ibm_is_dedicated_host_group.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_dedicated_host_group) | resource |
| [ibm_is_floating_ip.login_fip](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_floating_ip) | resource |
| [ibm_is_instance.controller](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.controller_candidate](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.spectrum_scale_storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_instance) | resource |
| [ibm_is_public_gateway.mygateway](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_public_gateway) | resource |
| [ibm_is_security_group.login_sg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group) | resource |
| [ibm_is_security_group.sg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group) | resource |
| [ibm_is_security_group_rule.egress_all](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_all_local](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_vpn](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_tcp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_udp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_tcp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_udp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_subnet.login_subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_subnet) | resource |
| [ibm_is_subnet.subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_subnet) | resource |
| [ibm_is_volume.nfs](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_volume) | resource |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_vpc) | resource |
| [ibm_is_vpn_gateway.vpn](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_vpn_gateway) | resource |
| [ibm_is_vpn_gateway_connection.conn](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/resources/is_vpn_gateway_connection) | resource |
| [null_resource.delete_schematics_ingress_security_rule](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [http_http.fetch_myip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [ibm_iam_auth_token.token](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/iam_auth_token) | data source |
| [ibm_is_dedicated_host_profiles.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_dedicated_host_profiles) | data source |
| [ibm_is_image.image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_image) | data source |
| [ibm_is_image.scale_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_image) | data source |
| [ibm_is_image.stock_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_image) | data source |
| [ibm_is_instance_profile.controller](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.spectrum_scale_storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_region.region](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_region) | data source |
| [ibm_is_ssh_key.ssh_key](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_ssh_key) | data source |
| [ibm_is_volume_profile.nfs](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_volume_profile) | data source |
| [ibm_is_vpc.existing_vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_vpc) | data source |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_vpc) | data source |
| [ibm_is_zone.zone](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/is_zone) | data source |
| [ibm_resource_group.rg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.41.0/docs/data-sources/resource_group) | data source |
| [template_file.controller_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.login_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.metadata_startup_script](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.storage_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.worker_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Type | Default | Required |
|------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------|---------|:--------:|
| <a name="input_TF_PARALLELISM"></a> [TF\_PARALLELISM](#input\_TF\_PARALLELISM) | Parallelism/ concurrent operations limit. Valid values are between 1 and 256, both inclusive. [Learn more](https://www.terraform.io/docs/internals/graph.html#walking-the-graph).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | `string` | `"250"` | no |
| <a name="input_TF_VERSION"></a> [TF\_VERSION](#input\_TF\_VERSION) | The version of the Terraform engine that's used in the Schematics workspace.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | `string` | `"1.1"` | no |
| <a name="input_TF_WAIT_DURATION"></a> [TF\_WAIT\_DURATION](#input\_TF\_WAIT\_DURATION) | wait duration time set for the storage and worker node to complete the entire setup                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `string` | `"180s"` | no |
| <a name="input_api_key"></a> [api\_key](#input\_api\_key) | This is the IBM Cloud API key for the IBM Cloud account where the IBM Spectrum LSF cluster needs to be deployed. For more information on how to create an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui).                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `string` | n/a | yes |
| <a name="input_cluster_prefix"></a> [cluster\_prefix](#input\_cluster\_prefix) | Prefix that is used to name the IBM Spectrum LSF cluster and IBM Cloud resources that are provisioned to build the IBM Spectrum LSF cluster instance. You cannot create more than one instance of the lsf cluster with the same name. Make sure that the name is unique.                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | `string` | `"hpcc-lsf"` | no |
| <a name="input_dedicated_host_enabled"></a> [dedicated\_host\_enabled](#input\_dedicated\_host\_enabled) | Set to true to use dedicated hosts for compute hosts (default: false). Note that lsf still dynamically provisions compute hosts at public VSIs and dedicated hosts are used only for static compute hosts provisioned at the time the cluster is created. The number of dedicated hosts and the profile names for dedicated hosts are calculated from worker\_node\_min\_count and dedicated\_host\_type\_name.                                                                                                                                                                                                                                                                                                                                       | `bool` | `false` | no |
| <a name="input_dedicated_host_placement"></a> [dedicated\_host\_placement](#input\_dedicated\_host\_placement) | Specify 'pack' or 'spread'. The 'pack' option will deploy VSIs on one dedicated host until full before moving on to the next dedicated host. The 'spread' option will deploy VSIs in round-robin fashion across all the dedicated hosts. The second option should result in mostly even distribution of VSIs on the hosts, while the first option could result in one dedicated host being mostly empty.                                                                                                                                                                                                                                                                                                                                              | `string` | `"spread"` | no |
| <a name="input_hyperthreading_enabled"></a> [hyperthreading\_enabled](#input\_hyperthreading\_enabled) | Setting this to true will enable hyper-threading in the worker nodes of the cluster (default). Otherwise, hyper-threading will be disabled. Note: Only a value of true is supported for this release. See this [FAQ](https://test.cloud.ibm.com/docs/ibm-spectrum-lsf?topic=ibm-spectrum-lsf-spectrum-lsf-faqs&interface=ui#disable-hyper-threading) for an explanation of why that is the case.                                                                                                                                                                                                                                                                                                                                                      | `bool` | `true` | no |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Spectrum LSF cluster. By default, the automation uses a base image with e with additional software packages documented [here](https://cloud.ibm.com/docs/ibm-spectrum-lsf). If you would like to include your application-specific binary files, follow the instructions in [Planning for custom images](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Spectrum LSF cluster through this offering.                                                                                                                                      | `string` | `"hpcc-lsf10-scale5131-rhel84-060822-v1"` | no |
| <a name="input_login_node_instance_type"></a> [login\_node\_instance\_type](#input\_login\_node\_instance\_type) | Specify the VSI profile type name to be used to create the login node for Spectrum LSF cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | `string` | `"bx2-2x8"` | no |
| <a name="input_ls_entitlement"></a> [ls\_entitlement](#input\_ls\_entitlement) | Entitlement file content for Spectrum LSF license scheduler.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | `string` | `"LS_Standard  10.1  ()  ()  ()  ()  18b1928f13939bd17bf25e09a2dd8459f238028f"` | no |
| <a name="input_lsf_entitlement"></a> [lsf\_entitlement](#input\_lsf\_entitlement) | Entitlement file content for core Spectrum LSF software.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | `string` | `"LSF_Standard  10.1  ()  ()  ()  pa  3f08e215230ffe4608213630cd5ef1d8c9b4dfea"` | no |
| <a name="input_lsf_license_confirmation"></a> [lsf\_license\_confirmation](#input\_lsf\_license\_confirmation) | If you have confirmed the availability of the Spectrum LSF license for a production cluster on IBM Cloud or if you are deploying a non-production cluster, enter true. Note:Failure to comply with licenses for production use of software is a violation of the[IBM International Program License Agreement](https://www.ibm.com/software/passportadvantage/programlicense.html).                                                                                                                                                                                                                                                                                                                                                                    | `string` | n/a | yes |
| <a name="input_management_node_count"></a> [management\_node\_count](#input\_management\_node\_count) | Number of management nodes. This is the total number of management and management candidates. Enter a value in the range 1 - 3.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `number` | `2` | no |
| <a name="input_management_node_instance_type"></a> [management\_node\_instance\_type](#input\_management\_node\_instance\_type) | Specify the virtual server instance profile type to be used to create the management nodes for the Spectrum LSF cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | `string` | `"bx2-4x16"` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Resource group name from your IBM Cloud account where the VPC resources should be deployed. For additional information on resource groups, see [Managing resource groups](https://test.cloud.ibm.com/docs/account?topic=account-rgs&interface=ui).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | `string` | `"Default"` | no |
| <a name="input_scale_compute_cluster_filesystem_mountpoint"></a> [scale\_compute\_cluster\_filesystem\_mountpoint](#input\_scale\_compute\_cluster\_filesystem\_mountpoint) | Compute cluster (accessingCluster) file system mount point. The accessingCluster is the cluster that accesses the owningCluster. For more information, see [Mounting a remote GPFS file system](https://www.ibm.com/docs/en/spectrum-scale/5.1.2?topic=system-mounting-remote-gpfs-file).                                                                                                                                                                                                                                                                                                                                                                                                                                                             | `string` | `"/gpfs/fs1"` | no |
| <a name="input_scale_compute_cluster_gui_password"></a> [scale\_compute\_cluster\_gui\_password](#input\_scale\_compute\_cluster\_gui\_password) | Password for Compute cluster GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, and one uppercase letter, at least one unique character. Password Should not contain username.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | `string` | `""` | no |
| <a name="input_scale_compute_cluster_gui_username"></a> [scale\_compute\_cluster\_gui\_username](#input\_scale\_compute\_cluster\_gui\_username) | GUI user to perform system management and monitoring tasks on compute cluster. Note: Username should be at least 4 characters, any combination of lowercase and uppercase letters.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | `string` | `""` | no |
| <a name="input_scale_filesystem_block_size"></a> [scale\_filesystem\_block\_size](#input\_scale\_filesystem\_block\_size) | File system [block size](https://www.ibm.com/docs/en/spectrum-scale/5.1.2?topic=considerations-block-size). Spectrum Scale supported block sizes (in bytes) include: 256K, 512K, 1M, 2M, 4M, 8M, 16M.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | `string` | `"4M"` | no |
| <a name="input_scale_storage_cluster_filesystem_mountpoint"></a> [scale\_storage\_cluster\_filesystem\_mountpoint](#input\_scale\_storage\_cluster\_filesystem\_mountpoint) | Spectrum Scale Storage cluster (owningCluster) Filesystem mount point. The owningCluster is the cluster that owns and serves the file system to be mounted. [Mounting a remote GPFS file system](https://www.ibm.com/docs/en/spectrum-scale/5.1.2?topic=system-mounting-remote-gpfs-file).                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `string` | `"/gpfs/fs1"` | no |
| <a name="input_scale_storage_cluster_gui_password"></a> [scale\_storage\_cluster\_gui\_password](#input\_scale\_storage\_cluster\_gui\_password) | Password for Spectrum Scale storage cluster GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one unique character. Password Should not contain username                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `string` | `""` | no |
| <a name="input_scale_storage_cluster_gui_username"></a> [scale\_storage\_cluster\_gui\_username](#input\_scale\_storage\_cluster\_gui\_username) | GUI user to perform system management and monitoring tasks on storage cluster. Note: Username should be at least 4 characters, any combination of lowercase and uppercase letters.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | `string` | `""` | no |
| <a name="input_scale_storage_image_name"></a> [scale\_storage\_image\_name](#input\_scale\_storage\_image\_name) | Name of the custom image that you would like to use to create virtual machines in your IBM Cloud account to deploy the Spectrum Scale storage cluster. By default, the automation uses a base image plus the Spectrum Scale software and any other software packages that it requires. If you would like, you can follow the instructions for [Planning for custom images](https://test.cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the Spectrum Scale storage cluster through this offering.                                                                                                                                                                                      | `string` | `"hpcc-scale5131-rhel84-jun0122-v1"` | no |
| <a name="input_scale_storage_node_count"></a> [scale\_storage\_node\_count](#input\_scale\_storage\_node\_count) | The number of Spectrum scale storage nodes that will be provisioned at the time the cluster is created. Enter a value in the range 2 - 18. It must to be divisible of 2.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | `number` | `4` | no |
| <a name="input_scale_storage_node_instance_type"></a> [scale\_storage\_node\_instance\_type](#input\_scale\_storage\_node\_instance\_type) | Specify the virtual server instance storage profile type name to be used to create the Spectrum Scale storage nodes for the Spectrum Storage cluster. For more information, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | `string` | `"cx2d-8x16"` | no |
| <a name="input_spectrum_scale_enabled"></a> [spectrum\_scale\_enabled](#input\_spectrum\_scale\_enabled) | Setting this to true will enables Spectrum Scale integration with the cluster. Otherwise, Spectrum Scale integration will be disabled (default). By entering 'true' for the property, you have also agreed to one of the two conditions: (1) You are using the software in production and confirm you have sufficient licenses to cover your use under the International Program License Agreement (IPLA). (2) You are evaluating the software and agree to abide by the International License Agreement for Evaluation of Programs (ILAE). Note: Failure to comply with licenses for production use of software is a violation of [IBM International Program License Agreement](https://www.ibm.com/software/passportadvantage/programlicense.html). | `bool` | `false` | no |
| <a name="input_ssh_allowed_ips"></a> [ssh\_allowed\_ips](#input\_ssh\_allowed\_ips) | Comma-separated list of IP addresses that can access the Spectrum LSF instance through SSH interface. The default value allows any IP address to access the cluster.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | `string` | `"0.0.0.0/0"` | no |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | Comma-separated list of names of the SSH key configured in your IBM Cloud account that is used to establish a connection to the LSF management node. Ensure that the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the instructions given at [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys).                                                                                                                                                                                                                                                                                                           | `string` | n/a | yes |
| <a name="input_storage_node_instance_type"></a> [storage\_node\_instance\_type](#input\_storage\_node\_instance\_type) | Specify the virtual server instance profile type to be used to create the storage nodes for the Spectrum LSF cluster. The storage nodes are the ones that are used to create an NFS instance to manage the data for HPC workloads.  For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles).                                                                                                                                                                                                                                                                                                                                                                                                         | `string` | `"bx2-2x8"` | no |
| <a name="input_volume_capacity"></a> [volume\_capacity](#input\_volume\_capacity) | Size in GB for the block storage that will be used to build the NFS instance and will be available as a mount on the Spectrum LSF controller node. Enter a value in the range 10 - 16000.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | `number` | `100` | no |
| <a name="input_volume_iops"></a> [volume\_iops](#input\_volume\_iops) | Number to represent the IOPS (Input Output Per Second) configuration for block storage to be used for the NFS instance (valid only for ‘volume\_profile=custom’, dependent on ‘volume\_capacity’). Enter a value in the range 100 - 48000.  For possible options of IOPS, see [Custom IOPS Profile](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles&interface=ui#custom).                                                                                                                                                                                                                                                                                                                                                             | `number` | `300` | no |
| <a name="input_volume_profile"></a> [volume\_profile](#input\_volume\_profile) | Name of the block storage volume type to be used for NFS instance. For possible options, see [Block storage profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles&interface=ui).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | `string` | `"general-purpose"` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `string` | `""` | no |
| <a name="input_vpn_enabled"></a> [vpn\_enabled](#input\_vpn\_enabled) | Set to true to deploy a VPN gateway for VPC in the cluster.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `bool` | `false` | no |
| <a name="input_vpn_peer_address"></a> [vpn\_peer\_address](#input\_vpn\_peer\_address) | The peer public IP address to which the VPN will be connected.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | `string` | `""` | no |
| <a name="input_vpn_peer_cidrs"></a> [vpn\_peer\_cidrs](#input\_vpn\_peer\_cidrs) | Comma separated list of peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | `string` | `""` | no |
| <a name="input_vpn_preshared_key"></a> [vpn\_preshared\_key](#input\_vpn\_preshared\_key) | The pre-shared key for the VPN.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `string` | `""` | no |
| <a name="input_worker_node_instance_type"></a> [worker\_node\_instance\_type](#input\_worker\_node\_instance\_type) | Specify the virtual server instance profile type name to be used to create the worker nodes for the Spectrum LSF cluster. The worker nodes are the ones where the workload execution takes place and the choice should be made according to the characteristic of workloads. For choices on profile types, see [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui). Note: If dedicated\_host\_enabled == true, available instance prefix (e.g., bx2 and cx2) can be limited depending on your target region. Check `ibmcloud target -r {region_name}; ibmcloud is dedicated-host-profiles.`                                                                                                                           | `string` | `"bx2-4x16"` | no |
| <a name="input_worker_node_max_count"></a> [worker\_node\_max\_count](#input\_worker\_node\_max\_count) | The maximum number of worker nodes that can be deployed in the Spectrum LSF cluster. In order to use the [Resource Connector](https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=lsf-resource-connnector) feature to dynamically create and delete worker nodes based on workload demand, the value selected for this parameter must be larger than worker\_node\_min\_count. If you plan to deploy only static worker nodes in the LSF cluster, e.g., when using Spectrum Scale storage, the value for this parameter should be equal to worker\_node\_min\_count. Enter a value in the range 1 - 500.                                                                                                                                            | `number` | `10` | no |
| <a name="input_worker_node_min_count"></a> [worker\_node\_min\_count](#input\_worker\_node\_min\_count) | The minimum number of worker nodes. This is the number of static worker nodes that will be provisioned at the time the cluster is created. If using NFS storage, enter a value in the range 0 - 500. If using Spectrum Scale storage, enter a value in the range 1 - 64. NOTE: Spectrum Scale requires a minimum of 3 compute nodes (combination of controller, controller-candidate, and worker nodes) to establish a [quorum](https://www.ibm.com/docs/en/spectrum-scale/5.1.2?topic=failure-quorum#nodequo) and maintain data consistency in the even of a node failure. Therefore, the minimum value of 1 may need to be larger if the value specified for management\_node\_count is less than 2.                                                | `number` | `0` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | IBM Cloud zone name within the selected region where the Spectrum LSF cluster should be deployed. To get a full list of zones within a region, see [Get zones by using the CLI](https://test.cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region&interface=cli#get-zones-using-the-cli).                                                                                                                                                                                                                                                                                                                                                                                                                                            | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_region_name"></a> [region\_name](#output\_region\_name) | n/a |
| <a name="output_spectrum_scale_storage_ssh_command"></a> [spectrum\_scale\_storage\_ssh\_command](#output\_spectrum\_scale\_storage\_ssh\_command) | n/a |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | n/a |
| <a name="output_vpc_name"></a> [vpc\_name](#output\_vpc\_name) | n/a |
| <a name="output_vpn_config_info"></a> [vpn\_config\_info](#output\_vpn\_config\_info) | n/a |
