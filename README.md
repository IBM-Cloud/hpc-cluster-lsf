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

* Login to master node using ssh command
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

* Login to the master as shown in the ssh_command output
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
# Terraform Documentation

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | 1.23.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | 1.23.0 |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ibm_is_floating_ip.login_fip](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_floating_ip) | resource |
| [ibm_is_instance.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.master](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.master_candidate](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_instance) | resource |
| [ibm_is_public_gateway.mygateway](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_public_gateway) | resource |
| [ibm_is_security_group.login_sg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group) | resource |
| [ibm_is_security_group.sg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group) | resource |
| [ibm_is_security_group_rule.egress_all](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_all_local](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_tcp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_udp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_tcp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_udp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_subnet.login_subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_subnet) | resource |
| [ibm_is_subnet.subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_subnet) | resource |
| [ibm_is_volume.nfs](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_volume) | resource |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/resources/is_vpc) | resource |
| [ibm_is_image.image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/is_image) | data source |
| [ibm_is_image.stock_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/is_image) | data source |
| [ibm_is_instance_profile.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.master](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_region.region](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/is_region) | data source |
| [ibm_is_ssh_key.ssh_key](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/is_ssh_key) | data source |
| [ibm_is_volume_profile.nfs](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/is_volume_profile) | data source |
| [ibm_is_zone.zone](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/is_zone) | data source |
| [ibm_resource_group.rg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.23.0/docs/data-sources/resource_group) | data source |
| [template_file.master_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.storage_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.worker_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_TF_PARALLELISM"></a> [TF\_PARALLELISM](#input\_TF\_PARALLELISM) | Parallelism/ concurrent operations limit. Valid values are between 1 and 256, both inclusive. [Learn more](https://www.terraform.io/docs/internals/graph.html#walking-the-graph) | `string` | `"250"` | no |
| <a name="input_TF_VERSION"></a> [TF\_VERSION](#input\_TF\_VERSION) | The version of the Terraform engine that's used in the Schematics workspace. | `string` | `"0.13"` | no |
| <a name="input_api_key"></a> [api\_key](#input\_api\_key) | This is the API key for IBM Cloud account in which the Spectrum LSF cluster needs to be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-userapikey) | `string` | n/a | yes |
| <a name="input_cluster_prefix"></a> [cluster\_prefix](#input\_cluster\_prefix) | Prefix that would be used to name Spectrum LSF cluster and IBM Cloud resources provisioned to build the Spectrum LSF cluster instance. You cannot create more than one instance of LSF Cluster with same name, please make sure the name is unique. Enter a prefix name, such as my-hpcc | `string` | `"hpcc-lsf"` | no |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | Name of the custom image that you would like to use to create virtual machines in your IBM Cloud account to deploy Spectrum LSF Cluster. By default, our automation uses a base image with following HPC related packages documented here [Learn more](https://cloud.ibm.com/docs/ibm-spectrum-lsf). If you would like to include your application specific binaries please follow the instructions [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the Spectrum LSF cluster through this offering. | `string` | `"hpcc-lsf10-cent77-jun0421-v5"` | no |
| <a name="input_login_node_instance_type"></a> [login\_node\_instance\_type](#input\_login\_node\_instance\_type) | Please specify the VSI profile type name to be used to create the login node for Spectrum LSF cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-2x8"` | no |
| <a name="input_ls_entitlement"></a> [ls\_entitlement](#input\_ls\_entitlement) | Entitlement file content for Spectrum LSF license scheduler. | `string` | `"LS_Standard  10.1  ()  ()  ()  ()  18b1928f13939bd17bf25e09a2dd8459f238028f"` | no |
| <a name="input_lsf_entitlement"></a> [lsf\_entitlement](#input\_lsf\_entitlement) | Entitlement file content for core Spectrum LSF software. | `string` | `"LSF_Standard  10.1  ()  ()  ()  pa  3f08e215230ffe4608213630cd5ef1d8c9b4dfea"` | no |
| <a name="input_lsf_license_confirmation"></a> [lsf\_license\_confirmation](#input\_lsf\_license\_confirmation) | If you have confirmed the availability of a Spectrum LSF license for a production cluster on IBM Cloud OR if you are deploying a non-production cluster, enter 'true'. NOTE: Failure to comply with licenses for production use of software is a violation of IBM International Program License Agreement. [Learn more](https://www.ibm.com/software/passportadvantage/programlicense.html) | `string` | n/a | yes |
| <a name="input_management_node_count"></a> [management\_node\_count](#input\_management\_node\_count) | Number of management nodes. This is the total number of master and master candidates. Enter a value in the range 1 - 3. | `number` | `2` | no |
| <a name="input_management_node_instance_type"></a> [management\_node\_instance\_type](#input\_management\_node\_instance\_type) | Please specify the VSI profile type name to be used to create the management nodes for Spectrum LSF cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-4x16"` | no |
| <a name="input_region"></a> [region](#input\_region) | IBM Cloud region name where the Spectrum LSF cluster should be deployed. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region) | `string` | `"us-south"` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Resource group name from your IBM Cloud account where the VPC resources should be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-rgs) | `string` | `"Default"` | no |
| <a name="input_ssh_allowed_ips"></a> [ssh\_allowed\_ips](#input\_ssh\_allowed\_ips) | Comma separated list of IP addresses that can access the Spectrum LSF instance through SSH interface. The default value allows any IP address to access the cluster. | `string` | `"0.0.0.0/0"` | no |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | Name of ssh key configured in your IBM Cloud account, that will be used to establish a connection to LSF master node. If you do not have a ssh key in your IBM Cloud please create one using instructions given here. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys) | `string` | n/a | yes |
| <a name="input_storage_node_instance_type"></a> [storage\_node\_instance\_type](#input\_storage\_node\_instance\_type) | Please specify the VSI profile type name to be used to create the storage nodes for Spectrum LSF cluster. The storage nodes are the ones that would be used to create an NFS instance to manage the data for HPC workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-2x8"` | no |
| <a name="input_volume_capacity"></a> [volume\_capacity](#input\_volume\_capacity) | Size in GB for the block storage that would be used to build the NFS instance and would be available as a mount on Spectrum LSF master node. Enter a value in the range 10 - 16000. | `number` | `100` | no |
| <a name="input_volume_iops"></a> [volume\_iops](#input\_volume\_iops) | Number to represent the IOPS(Input Output Per Second) configuration for block storage to be used for NFS instance (valid only for volume\_profile=custom, dependent on volume\_capacity). Enter a value in the range 100 - 48000. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles#custom) | `number` | `300` | no |
| <a name="input_volume_profile"></a> [volume\_profile](#input\_volume\_profile) | Name of the block storage volume type to be used for NFS instance. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles) | `string` | `"general-purpose"` | no |
| <a name="input_worker_node_instance_type"></a> [worker\_node\_instance\_type](#input\_worker\_node\_instance\_type) | Please specify the VSI profile type name to be used to create the worker nodes for Spectrum LSF cluster. The worker nodes are the ones where the workload execution takes place and choice should be made according to the characteristic of workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-4x16"` | no |
| <a name="input_worker_node_max_count"></a> [worker\_node\_max\_count](#input\_worker\_node\_max\_count) | The maximum number of worker nodes that should be added to Spectrum LSF cluster. This is to limit the number of machines that can be added to Spectrum LSF cluster when auto-scaling configuration is used. This property can be used to manage the cost associated with Spectrum LSF cluster instance. Enter a value in the range 1 - 500. | `number` | `10` | no |
| <a name="input_worker_node_min_count"></a> [worker\_node\_min\_count](#input\_worker\_node\_min\_count) | The minimum number of worker nodes. This is the number of worker nodes that will be provisioned at the time the cluster is created. Enter a value in the range 0 - 500. | `number` | `0` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | IBM Cloud zone name within the selected region where the Spectrum LSF cluster should be deployed. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli) | `string` | `"us-south-3"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | n/a |
