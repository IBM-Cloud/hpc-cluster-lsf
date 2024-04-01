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
# Login to the IBM Cloud CLI
$ ibmcloud schematics workspace new -f config.json --github-token xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ ibmcloud schematics workspace list
Name               ID                                            Description   Status     Frozen
hpcc-lsf-test       us-east.workspace.hpcc-lsf-test.7cbc3f6b                     INACTIVE   False

OK

$ ibmcloud schematics plan --id us-east.workspace.hpcc-cluster.7cbc3f6b
Activity ID  51b6330e913d23636d706b084755a737
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

# Accessing the deployed environment:

* Connect to an LSF login node through SSH by using the `ssh_to_login_node` command from the Schematics log output.
```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@<floating_IP_address> lsfadmin@<login_node_IP_address>
```
* where `floating_IP_address` is the floating IP address for the bastion node and `login_node_IP_address` is the IP address for the login node.

# Steps to validate the cluster post provisioning

* Login to management-host node using ssh command
* Check the existing machines part of cluster using $bhosts or $bhosts -w command, this should show all instances
* Submit a job that would spin 1 VM and sleep for 10 seconds -> $bsub -n 1 sleep 10, once submitted command line will show a jobID
* Check the status for job using -> $bjobs -l <jobID>
* Check the log file under /opt/ibm/lsf/log/ibmcloudgen2... for any messages around provisioning of the new machine
* Continue to check status of nodes using lshosts, bjobs or bhosts commands
* To test multiple VMs you can run multiple sleep jobs -> $bsub -n 10 sleep 10 -> This will create 10 VMs and each job will sleep for 10 seconds

# Scale Setup

##### 1. steps to validate spectrum scale integration
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
* Login to management-host node using SSH. (ssh -J root@52.116.122.64 root@10.240.128.41)
* The below command shows the gpfs cluster setup on computes node. This should contain the management-host,management-host-candidate, and worker nodes.
```buildoutcfg
# /usr/lpp/mmfs/bin/mmlscluster
```
* Create a file on mountpoint path(e.g `/gpfs/fs1`) and verify on other nodes that the file can be accessed.
##### 2. steps to access the Scale cluster GUI

* Open a new command line terminal.
* Run the following command to access the storage cluster:

```buildoutcfg
#ssh -L 22443:localhost:443 -J root@{FLOATING_IP_ADDRESS} root@{STORAGE_NODE_IP_ADDRESS}
```
* where STORAGE_NODE_IP_ADDRESS needs to be replaced with the storage IP address associated with {cluster_prefix}-scale-storage-0, which you gathered earlier, and FLOATING_IP_ADDRESS needs to be replaced with the floating IP address that you identified.

* Open a browser on the local machine, and run https://localhost:22443. You will get an SSL self-assigned certificate warning with your browser the first time that you access this URL.
* Enter your login credentials that you set up when you created your workspace to access the Spectrum Scale GUI.
Accessing the compute cluster

* Open a new command line terminal.
* Run the following command to access the compute cluster:

```buildoutcfg
 #ssh -L 21443:localhost:443 -J root@{FLOATING_IP_ADDRESS} root@{COMPUTE_NODE_IP_ADDRESS}
 ```
* where COMPUTE_NODE_IP_ADDRESS needs to be replaced with the storage IP address associated with {cluster_prefix}-primary-0, which you gathered earlier, and FLOATING_IP_ADDRESS needs to be replaced with the floating IP address that you identified.

* Open a browser on the local machine, and run https://localhost:21443. You will get an SSL self-assigned certificate warning with your browser the first time that you access this URL.
* Enter your login credentials that you set up when you created your workspace to access the Spectrum Scale GUI.

##### Steps to access the Application Center GUI/Dashboard.

* Open a new command line terminal.
* Run the following command to access the Application center GUI:

```buildoutcfg
# ssh -L 8443:localhost:8443 -J root@{FLOATING_IP_ADDRESS} lsfadmin@{MANGEMENT_NODE_IP_ADDRESS}
```
* where MANGEMENT_NODE_IP_ADDRESS needs to be replaced with the Management node IP address associated with {cluster_prefix}-management-host-0, which you gathered earlier, and FLOATING_IP_ADDRESS needs to be replaced with the floating IP address that you identified.

* Open a browser on the local machine, and run https://localhost:8443. 

* To access the Application Center GUI, enter the password you configured when you created your workspace and the default user as "lsfadmin".

* If LDAP is enabled, you can access the LSF Application Center using the LDAP username and password that you configured during IBM Cloud® HPC cluster deployment or using an existing LDAP username and password.

##### Steps to validate the OpenLDAP:

* Connect to your OpenLDAP server through SSH by using the `ssh_to_ldap_node` command from the Schematics log output.

```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -J vpcuser@<floatingg_IP_address> ubuntu@<LDAP_server_IP>
```
* where `floating_IP_address` is the floating IP address for the bastion node and `LDAP_server_IP` is the IP address for the OpenLDAP node.

* Verifiy the LDAP service status:

```
systemctl status slapd
```

* Verify the LDAP groups and users created:

```
ldapsearch -Q -LLL -Y EXTERNAL -H ldapi:///
```

* Submit a Job from HPC cluster Management node with LDAP user : Log into the management node using the `ssh_to_management_node` value as shown as part of output section of Schematics job log:

```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@<floating_IP_address> lsfadmin@<management_node_IP_address>
```
* where `floating_IP_address` is the floating IP address for the bastion node and `management_node_IP_address` is the IP address for the management node.

* Switch to the LDAP user (for example, switch to lsfuser05):

```
[lsfadmin@hpccluster-mgmt-1 ~]$ su lsfuser05
Password:
[lsfuser05@hpccluster-mgmt-1 lsfadmin]# 
```

* Submit an LSF job as the LDAP user:

```
[lsfuser05@hpccluster-mgmt-1 lsfadmin]$ bsub -J myjob[1-4] -R "rusage[mem=2G]" sleep 10
Job <1> is submitted to default queue <normal>.
```

### Cleaning up the deployed environment:

If you no longer need your deployed IBM Cloud HPC cluster, you can clean it up from your environment. The process is threefold: ensure that the cluster is free of running jobs or working compute nodes, destroy all the associated VPC resources and remove them from your IBM Cloud account, and remove the project from the IBM Cloud console.

**Note**: Ensuring that the cluster is free of running jobs and working compute nodes

Ensure that it is safe to destroy resources:

1. As the `lsfadmin` user, close all LSF queues and kill all jobs:
   ```
    badmin qclose all
    bkill -u all 0
    ```

2. Wait ten minutes (this is the default idle time), and then check for running jobs:
    ```
    bjobs -u all
    ```

   Look for a `No unfinished job found` message.


3. Check that there are no compute nodes (only management nodes should be listed):
   ```
    bhosts -w
   ```

If the cluster has no running jobs or compute nodes, then it is safe to destroy resources from this environment.

#### Destroying resources

1. In the IBM Cloud console, from the **Schematics > Workspaces** view, select **Actions > Destroy resources** > **Confirm** the action by entering the workspace name in the text box and click Destroy to delete all the related VPC resources that were deployed.
2. If you select the option to destroy resources, decide whether you want to destroy all of them. This action cannot be undone.
3. Confirm the action by entering the workspace name in the text box and click **Destroy**.
You can now safely remove the resources from your account.

# Terraform Documentation

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.4.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | 1.58.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_http"></a> [http](#provider\_http) | 3.4.0 |
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | 1.58.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bastion_vsi"></a> [bastion\_vsi](#module\_bastion\_vsi) | ./resources/ibmcloud/compute/login_vsi | n/a |
| <a name="module_check_cluster_status"></a> [check\_cluster\_status](#module\_check\_cluster\_status) | ./resources/ibmcloud/null/remote_exec | n/a |
| <a name="module_check_node_status"></a> [check\_node\_status](#module\_check\_node\_status) | ./resources/ibmcloud/null/remote_exec | n/a |
| <a name="module_cluster_file_share"></a> [cluster\_file\_share](#module\_cluster\_file\_share) | ./resources/ibmcloud/file_share/ | n/a |
| <a name="module_compute_nodes_wait"></a> [compute\_nodes\_wait](#module\_compute\_nodes\_wait) | ./resources/scale_common/wait | n/a |
| <a name="module_custom_file_share"></a> [custom\_file\_share](#module\_custom\_file\_share) | ./resources/ibmcloud/file_share/ | n/a |
| <a name="module_custom_resolver"></a> [custom\_resolver](#module\_custom\_resolver) | ./resources/ibmcloud/network/dns_resolver | n/a |
| <a name="module_dedicated_host"></a> [dedicated\_host](#module\_dedicated\_host) | ./resources/ibmcloud/dedicated_host | n/a |
| <a name="module_dedicated_host_group"></a> [dedicated\_host\_group](#module\_dedicated\_host\_group) | ./resources/ibmcloud/dedicated_host_group | n/a |
| <a name="module_dns_permitted_network"></a> [dns\_permitted\_network](#module\_dns\_permitted\_network) | ./resources/ibmcloud/network/dns_permitted_network | n/a |
| <a name="module_dns_service"></a> [dns\_service](#module\_dns\_service) | ./resources/ibmcloud/network/dns_service | n/a |
| <a name="module_dns_zone"></a> [dns\_zone](#module\_dns\_zone) | ./resources/ibmcloud/network/dns_zone | n/a |
| <a name="module_inbound_sg_ingress_all_local_rule"></a> [inbound\_sg\_ingress\_all\_local\_rule](#module\_inbound\_sg\_ingress\_all\_local\_rule) | ./resources/ibmcloud/security/security_group_ingress_all_local | n/a |
| <a name="module_inbound_sg_rule"></a> [inbound\_sg\_rule](#module\_inbound\_sg\_rule) | ./resources/ibmcloud/security/security_group_inbound_rule | n/a |
| <a name="module_ingress_vpn"></a> [ingress\_vpn](#module\_ingress\_vpn) | ./resources/ibmcloud/security/vpn_ingress_security_rule | n/a |
| <a name="module_invoke_compute_playbook"></a> [invoke\_compute\_playbook](#module\_invoke\_compute\_playbook) | ./resources/scale_common/ansible_compute_playbook | n/a |
| <a name="module_invoke_remote_mount"></a> [invoke\_remote\_mount](#module\_invoke\_remote\_mount) | ./resources/scale_common/ansible_remote_mount_playbook | n/a |
| <a name="module_invoke_storage_playbook"></a> [invoke\_storage\_playbook](#module\_invoke\_storage\_playbook) | ./resources/scale_common/ansible_storage_playbook | n/a |
| <a name="module_ipvalidation_cluster_subnet"></a> [ipvalidation\_cluster\_subnet](#module\_ipvalidation\_cluster\_subnet) | ./resources/custom/subnet_cidr_check | n/a |
| <a name="module_ipvalidation_login_subnet"></a> [ipvalidation\_login\_subnet](#module\_ipvalidation\_login\_subnet) | ./resources/custom/subnet_cidr_check | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ./resources/ibmcloud/network/kms | n/a |
| <a name="module_ldap_vsi"></a> [ldap\_vsi](#module\_ldap\_vsi) | ./resources/ibmcloud/compute/ldap_vsi | n/a |
| <a name="module_login_fip"></a> [login\_fip](#module\_login\_fip) | ./resources/ibmcloud/network/floating_ip | n/a |
| <a name="module_login_inbound_security_rules"></a> [login\_inbound\_security\_rules](#module\_login\_inbound\_security\_rules) | ./resources/ibmcloud/security/login_sg_inbound_rule | n/a |
| <a name="module_login_outbound_security_rule"></a> [login\_outbound\_security\_rule](#module\_login\_outbound\_security\_rule) | ./resources/ibmcloud/security/login_sg_outbound_rule | n/a |
| <a name="module_login_outbound_vpc_rules"></a> [login\_outbound\_vpc\_rules](#module\_login\_outbound\_vpc\_rules) | ./resources/ibmcloud/security/security_group_outbound_rules | n/a |
| <a name="module_login_sg"></a> [login\_sg](#module\_login\_sg) | ./resources/ibmcloud/security/login_sg | n/a |
| <a name="module_login_ssh_key"></a> [login\_ssh\_key](#module\_login\_ssh\_key) | ./resources/scale_common/generate_keys | n/a |
| <a name="module_login_subnet"></a> [login\_subnet](#module\_login\_subnet) | ./resources/ibmcloud/network/login_subnet | n/a |
| <a name="module_login_vsi"></a> [login\_vsi](#module\_login\_vsi) | ./resources/ibmcloud/compute/management_node_vsi | n/a |
| <a name="module_management_host"></a> [management\_host](#module\_management\_host) | ./resources/ibmcloud/compute/management_node_vsi | n/a |
| <a name="module_management_host_candidate"></a> [management\_host\_candidate](#module\_management\_host\_candidate) | ./resources/ibmcloud/compute/management_host_candidates | n/a |
| <a name="module_outbound_sg_rule"></a> [outbound\_sg\_rule](#module\_outbound\_sg\_rule) | ./resources/ibmcloud/security/security_group_outbound_rule | n/a |
| <a name="module_permission_to_lsfadmin_for_mount_point"></a> [permission\_to\_lsfadmin\_for\_mount\_point](#module\_permission\_to\_lsfadmin\_for\_mount\_point) | ./resources/scale_common/add_permission | n/a |
| <a name="module_prepare_spectrum_scale_ansible_repo"></a> [prepare\_spectrum\_scale\_ansible\_repo](#module\_prepare\_spectrum\_scale\_ansible\_repo) | ./resources/scale_common/git_utils | n/a |
| <a name="module_public_gateway"></a> [public\_gateway](#module\_public\_gateway) | ./resources/ibmcloud/network/public_gateway | n/a |
| <a name="module_remove_ssh_key"></a> [remove\_ssh\_key](#module\_remove\_ssh\_key) | ./resources/scale_common/remove_ssh | n/a |
| <a name="module_schematics_sg_tcp_rule"></a> [schematics\_sg\_tcp\_rule](#module\_schematics\_sg\_tcp\_rule) | ./resources/ibmcloud/security | n/a |
| <a name="module_sg"></a> [sg](#module\_sg) | ./resources/ibmcloud/security/security_group | n/a |
| <a name="module_spectrum_scale_storage"></a> [spectrum\_scale\_storage](#module\_spectrum\_scale\_storage) | ./resources/ibmcloud/compute/scale_storage_vsi | n/a |
| <a name="module_storage_nodes_wait"></a> [storage\_nodes\_wait](#module\_storage\_nodes\_wait) | ./resources/scale_common/wait | n/a |
| <a name="module_subnet"></a> [subnet](#module\_subnet) | ./resources/ibmcloud/network/subnet | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./resources/ibmcloud/network/vpc | n/a |
| <a name="module_vpc_address_prefix"></a> [vpc\_address\_prefix](#module\_vpc\_address\_prefix) | ./resources/ibmcloud/network/vpc_address_prefix | n/a |
| <a name="module_vpc_flow_log"></a> [vpc\_flow\_log](#module\_vpc\_flow\_log) | ./resources/ibmcloud/network/vpc_flow_log | n/a |
| <a name="module_vpn"></a> [vpn](#module\_vpn) | ./resources/ibmcloud/network/vpn | n/a |
| <a name="module_vpn_connection"></a> [vpn\_connection](#module\_vpn\_connection) | ./resources/ibmcloud/network/vpn_connection | n/a |
| <a name="module_worker_vsi"></a> [worker\_vsi](#module\_worker\_vsi) | ./resources/ibmcloud/compute/worker_vsi | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.delete_schematics_ingress_security_rule](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.entitlement_check](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.validate_ldap_server_connection](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [http_http.fetch_myip](https://registry.terraform.io/providers/hashicorp/http/3.4.0/docs/data-sources/http) | data source |
| [ibm_iam_auth_token.token](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/iam_auth_token) | data source |
| [ibm_is_dedicated_host_profiles.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_dedicated_host_profiles) | data source |
| [ibm_is_image.image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_image) | data source |
| [ibm_is_image.ldap_vsi_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_image) | data source |
| [ibm_is_image.scale_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_image) | data source |
| [ibm_is_image.stock_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_image) | data source |
| [ibm_is_instance_profile.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.management_host](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.spectrum_scale_storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_public_gateways.public_gateways](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_public_gateways) | data source |
| [ibm_is_region.region](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_region) | data source |
| [ibm_is_ssh_key.ssh_key](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_ssh_key) | data source |
| [ibm_is_subnet.existing_login_subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_subnet) | data source |
| [ibm_is_subnet.existing_subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_subnet) | data source |
| [ibm_is_subnet.subnet_id](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_subnet) | data source |
| [ibm_is_vpc.existing_vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_vpc) | data source |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_vpc) | data source |
| [ibm_is_vpc_address_prefixes.existing_vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_vpc_address_prefixes) | data source |
| [ibm_is_zone.zone](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/is_zone) | data source |
| [ibm_resource_group.rg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.58.0/docs/data-sources/resource_group) | data source |
| [template_file.bastion_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.ldap_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.login_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.management_host_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.metadata_startup_script](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.storage_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.worker_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_TF_PARALLELISM"></a> [TF\_PARALLELISM](#input\_TF\_PARALLELISM) | Parallelism/ concurrent operations limit. Valid values are between 1 and 256, both inclusive. [Learn more](https://www.terraform.io/docs/internals/graph.html#walking-the-graph). | `string` | `"250"` | no |
| <a name="input_TF_VERSION"></a> [TF\_VERSION](#input\_TF\_VERSION) | The version of the Terraform engine that's used in the Schematics workspace. | `string` | `"1.1"` | no |
| <a name="input_TF_WAIT_DURATION"></a> [TF\_WAIT\_DURATION](#input\_TF\_WAIT\_DURATION) | wait duration time set for the storage and worker node to complete the entire setup | `string` | `"180s"` | no |
| <a name="input_api_key"></a> [api\_key](#input\_api\_key) | This is the IBM Cloud API key for the IBM Cloud account where the IBM Spectrum LSF cluster needs to be deployed. For more information on how to create an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui). | `string` | n/a | yes |
| <a name="input_app_center_db_pwd"></a> [app\_center\_db\_pwd](#input\_app\_center\_db\_pwd) | Password for MariaDB. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one special character. | `string` | `""` | no |
| <a name="input_app_center_gui_pwd"></a> [app\_center\_gui\_pwd](#input\_app\_center\_gui\_pwd) | Password for Application Center GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one special character. | `string` | `""` | no |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | Unique ID of the cluster used by LSF for configuration of resources. This can be up to 39 alphanumeric characters including the underscore (\_), the hyphen (-), and the period (.) characters. Other special characters and spaces are not allowed. Do not use the name of any host or user as the name of your cluster. You cannot change the cluster ID after deployment. | `string` | `"HPCCluster"` | no |
| <a name="input_cluster_prefix"></a> [cluster\_prefix](#input\_cluster\_prefix) | Prefix that is used to name the IBM Spectrum LSF cluster and IBM Cloud resources that are provisioned to build the IBM Spectrum LSF cluster instance. You cannot create more than one instance of the lsf cluster with the same name. Make sure that the name is unique. | `string` | `"hpcc-lsf"` | no |
| <a name="input_cluster_subnet_id"></a> [cluster\_subnet\_id](#input\_cluster\_subnet\_id) | Existing cluster subnet ID under the VPC, where the cluster will be provisioned. | `string` | `""` | no |
| <a name="input_compute_image_name"></a> [compute\_image\_name](#input\_compute\_image\_name) | Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud HPC cluster dynamic compute nodes. By default, the solution uses a RHEL 8-6 OS image with additional software packages mentioned [here](https://cloud.ibm.com/docs/hpc-spectrum-LSF#create-custom-image). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Cloud HPC cluster through this offering. | `string` | `"hpcaas-lsf10-rhel88-compute-v2"` | no |
| <a name="input_create_authorization_policy_vpc_to_cos"></a> [create\_authorization\_policy\_vpc\_to\_cos](#input\_create\_authorization\_policy\_vpc\_to\_cos) | Set it to true if authorization policy is required for VPC to access COS. This can be set to false if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for VPC flow log](https://cloud.ibm.com/docs/vpc?topic=vpc-ordering-flow-log-collector&interface=ui#fl-before-you-begin-ui). | `bool` | `false` | no |
| <a name="input_custom_file_shares"></a> [custom\_file\_shares](#input\_custom\_file\_shares) | Mount points and sizes in GB and IOPS range of file shares that can be used to customize shared file storage layout. Provide the details for up to 5 shares. Each file share size in GB supports different range of IOPS. For more information, see [file share IOPS value](https://cloud.ibm.com/docs/vpc?topic=vpc-file-storage-profiles&interface=ui). | <pre>list(object({<br>    mount_path = string,<br>    size       = number,<br>    iops       = number<br>  }))</pre> | <pre>[<br>  {<br>    "iops": 2000,<br>    "mount_path": "/mnt/binaries",<br>    "size": 100<br>  },<br>  {<br>    "iops": 6000,<br>    "mount_path": "/mnt/data",<br>    "size": 100<br>  }<br>]</pre> | no |
| <a name="input_dedicated_host_enabled"></a> [dedicated\_host\_enabled](#input\_dedicated\_host\_enabled) | Set to true to use dedicated hosts for compute hosts (default: false). Note that lsf still dynamically provisions compute hosts at public VSIs and dedicated hosts are used only for static compute hosts provisioned at the time the cluster is created. The number of dedicated hosts and the profile names for dedicated hosts are calculated from worker\_node\_min\_count and dedicated\_host\_type\_name. | `bool` | `false` | no |
| <a name="input_dedicated_host_placement"></a> [dedicated\_host\_placement](#input\_dedicated\_host\_placement) | Specify 'pack' or 'spread'. The 'pack' option will deploy VSIs on one dedicated host until full before moving on to the next dedicated host. The 'spread' option will deploy VSIs in round-robin fashion across all the dedicated hosts. The second option should result in mostly even distribution of VSIs on the hosts, while the first option could result in one dedicated host being mostly empty. | `string` | `"spread"` | no |
| <a name="input_dns_custom_resolver_id"></a> [dns\_custom\_resolver\_id](#input\_dns\_custom\_resolver\_id) | IBM Cloud DNS custom resolver id. | `string` | `""` | no |
| <a name="input_dns_domain"></a> [dns\_domain](#input\_dns\_domain) | IBM Cloud DNS Services domain name to be used for the IBM Cloud LSF cluster. | `string` | `"lsf.com"` | no |
| <a name="input_dns_instance_id"></a> [dns\_instance\_id](#input\_dns\_instance\_id) | IBM Cloud HPC DNS service resource id. | `string` | `""` | no |
| <a name="input_enable_app_center"></a> [enable\_app\_center](#input\_enable\_app\_center) | Set to true to install and enable use of the IBM Spectrum LSF Application Center GUI (default: false). [System requirements](https://www.ibm.com/docs/en/slac/10.2.0?topic=requirements-system-102-fix-pack-14) for IBM Spectrum LSF Application Center Version 10.2 Fix Pack 14. | `bool` | `false` | no |
| <a name="input_enable_customer_managed_encryption"></a> [enable\_customer\_managed\_encryption](#input\_enable\_customer\_managed\_encryption) | Setting this to true will enable customer managed encryption. Otherwise, encryption will be provider managed. | `bool` | `true` | no |
| <a name="input_enable_ldap"></a> [enable\_ldap](#input\_enable\_ldap) | Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false. | `bool` | `false` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Flag to enable VPC flow logs. If true, a flow log collector will be created. | `bool` | `false` | no |
| <a name="input_existing_cos_instance_guid"></a> [existing\_cos\_instance\_guid](#input\_existing\_cos\_instance\_guid) | GUID of the COS instance to create a flow log collector. | `string` | `null` | no |
| <a name="input_existing_storage_bucket_name"></a> [existing\_storage\_bucket\_name](#input\_existing\_storage\_bucket\_name) | Name of the COS bucket to collect VPC flow logs. | `string` | `null` | no |
| <a name="input_hyperthreading_enabled"></a> [hyperthreading\_enabled](#input\_hyperthreading\_enabled) | Setting this to true will enable hyper-threading in the worker nodes of the cluster (default). Otherwise, hyper-threading will be disabled. | `bool` | `true` | no |
| <a name="input_ibm_customer_number"></a> [ibm\_customer\_number](#input\_ibm\_customer\_number) | Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn). | `string` | `""` | no |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Spectrum LSF cluster. By default, the automation uses a base image with additional software packages documented [here](https://cloud.ibm.com/docs/ibm-spectrum-lsf). If you would like to include your application-specific binary files, follow the instructions in [Planning for custom images](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Spectrum LSF cluster through this offering. | `string` | `"hpcc-lsf10-scale5190-rhel88-3-0"` | no |
| <a name="input_is_flow_log_collector_active"></a> [is\_flow\_log\_collector\_active](#input\_is\_flow\_log\_collector\_active) | Indicates whether the collector is active. If false, this collector is created in inactive mode. | `bool` | `true` | no |
| <a name="input_kms_instance_id"></a> [kms\_instance\_id](#input\_kms\_instance\_id) | Unique identifier of the Key Protect instance associated with the Key Management Service. While providing an existing “kms\_instance\_id”, it's necessary to create the required authorization policy for encryption to be completed. To create the authorisation policy, go to [Service authorizations](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=ui). The ID can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui). | `string` | `""` | no |
| <a name="input_kms_key_name"></a> [kms\_key\_name](#input\_kms\_key\_name) | Provide the existing KMS encryption key name that you want to use for the IBM Cloud LSF cluster. (for example kms\_key\_name: my-encryption-key). | `string` | `""` | no |
| <a name="input_ldap_admin_password"></a> [ldap\_admin\_password](#input\_ldap\_admin\_password) | The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@\_+:) are required. It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]. | `string` | `""` | no |
| <a name="input_ldap_basedns"></a> [ldap\_basedns](#input\_ldap\_basedns) | The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name. | `string` | `"hpcaas.com"` | no |
| <a name="input_ldap_server"></a> [ldap\_server](#input\_ldap\_server) | Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created. | `string` | `"null"` | no |
| <a name="input_ldap_user_name"></a> [ldap\_user\_name](#input\_ldap\_user\_name) | Custom LDAP User for performing cluster operations. Note: Username should be between 4 to 32 characters, (any combination of lowercase and uppercase letters).[This value is ignored for an existing LDAP server] | `string` | `""` | no |
| <a name="input_ldap_user_password"></a> [ldap\_user\_password](#input\_ldap\_user\_password) | The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@\_+:) are required.It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]. | `string` | `""` | no |
| <a name="input_ldap_vsi_osimage_name"></a> [ldap\_vsi\_osimage\_name](#input\_ldap\_vsi\_osimage\_name) | Image name to be used for provisioning the LDAP instances. | `string` | `"ibm-ubuntu-22-04-3-minimal-amd64-1"` | no |
| <a name="input_ldap_vsi_profile"></a> [ldap\_vsi\_profile](#input\_ldap\_vsi\_profile) | Profile to be used for LDAP virtual server instance. | `string` | `"cx2-2x4"` | no |
| <a name="input_login_node_instance_type"></a> [login\_node\_instance\_type](#input\_login\_node\_instance\_type) | Specify the VSI profile type name to be used to create the login node for Spectrum LSF cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui). | `string` | `"bx2-2x8"` | no |
| <a name="input_login_subnet_id"></a> [login\_subnet\_id](#input\_login\_subnet\_id) | Existing Login subnet ID under the VPC, where the bastion/login will be provisioned. | `string` | `""` | no |
| <a name="input_management_node_count"></a> [management\_node\_count](#input\_management\_node\_count) | Number of management nodes. This is the total number of management and management candidates. Enter a value in the range 1 - 3. | `number` | `2` | no |
| <a name="input_management_node_instance_type"></a> [management\_node\_instance\_type](#input\_management\_node\_instance\_type) | Specify the virtual server instance profile type to be used to create the management nodes for the Spectrum LSF cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles). | `string` | `"bx2-4x16"` | no |
| <a name="input_remote_allowed_ips"></a> [remote\_allowed\_ips](#input\_remote\_allowed\_ips) | Comma-separated list of IP addresses that can access the Spectrum LSF instance through an SSH or RDP interface. For security purposes, provide the public IP addresses assigned to the devices that are authorized to establish SSH or RDP connections (for example, ["169.45.117.34"]). To fetch the IP address of the device, use [https://ipv4.icanhazip.com/](https://ipv4.icanhazip.com/). | `list(string)` | n/a | yes |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Resource group name from your IBM Cloud account where the VPC resources should be deployed. For additional information on resource groups, see [Managing resource groups](https://test.cloud.ibm.com/docs/account?topic=account-rgs&interface=ui). | `string` | `"Default"` | no |
| <a name="input_scale_compute_cluster_filesystem_mountpoint"></a> [scale\_compute\_cluster\_filesystem\_mountpoint](#input\_scale\_compute\_cluster\_filesystem\_mountpoint) | Compute cluster (accessingCluster) file system mount point. The accessingCluster is the cluster that accesses the owningCluster. For more information, see [Mounting a remote GPFS file system](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=system-mounting-remote-gpfs-file). | `string` | `"/gpfs/fs1"` | no |
| <a name="input_scale_compute_cluster_gui_password"></a> [scale\_compute\_cluster\_gui\_password](#input\_scale\_compute\_cluster\_gui\_password) | Password for Compute cluster GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one unique character. Password should not contain username. | `string` | `""` | no |
| <a name="input_scale_compute_cluster_gui_username"></a> [scale\_compute\_cluster\_gui\_username](#input\_scale\_compute\_cluster\_gui\_username) | GUI user to perform system management and monitoring tasks on compute cluster. Note: Username should be at least 4 characters, any combination of lowercase and uppercase letters. | `string` | `""` | no |
| <a name="input_scale_filesystem_block_size"></a> [scale\_filesystem\_block\_size](#input\_scale\_filesystem\_block\_size) | File system [block size](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=considerations-block-size). Spectrum Scale supported block sizes (in bytes) include: 256K, 512K, 1M, 2M, 4M, 8M, 16M. | `string` | `"4M"` | no |
| <a name="input_scale_storage_cluster_filesystem_mountpoint"></a> [scale\_storage\_cluster\_filesystem\_mountpoint](#input\_scale\_storage\_cluster\_filesystem\_mountpoint) | Spectrum Scale Storage cluster (owningCluster) Filesystem mount point. The owningCluster is the cluster that owns and serves the file system to be mounted. [Mounting a remote GPFS file system](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=system-mounting-remote-gpfs-file). | `string` | `"/gpfs/fs1"` | no |
| <a name="input_scale_storage_cluster_gui_password"></a> [scale\_storage\_cluster\_gui\_password](#input\_scale\_storage\_cluster\_gui\_password) | Password for Spectrum Scale storage cluster GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one unique character. Password should not contain username. | `string` | `""` | no |
| <a name="input_scale_storage_cluster_gui_username"></a> [scale\_storage\_cluster\_gui\_username](#input\_scale\_storage\_cluster\_gui\_username) | GUI user to perform system management and monitoring tasks on storage cluster. Note: Username should be at least 4 characters, any combination of lowercase and uppercase letters. | `string` | `""` | no |
| <a name="input_scale_storage_image_name"></a> [scale\_storage\_image\_name](#input\_scale\_storage\_image\_name) | Name of the custom image that you would like to use to create virtual machines in your IBM Cloud account to deploy the Spectrum Scale storage cluster. By default, the automation uses a base image plus the Spectrum Scale software and any other software packages that it requires. If you would like, you can follow the instructions for [Planning for custom images](https://test.cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the Spectrum Scale storage cluster through this offering. | `string` | `"hpcc-scale5190-rhel88"` | no |
| <a name="input_scale_storage_node_count"></a> [scale\_storage\_node\_count](#input\_scale\_storage\_node\_count) | The number of Spectrum scale storage nodes that will be provisioned at the time the cluster is created. Enter a value in the range 2 - 18. It must to be divisible of 2. | `number` | `4` | no |
| <a name="input_scale_storage_node_instance_type"></a> [scale\_storage\_node\_instance\_type](#input\_scale\_storage\_node\_instance\_type) | Specify the virtual server instance storage profile type name to be used to create the Spectrum Scale storage nodes for the Spectrum Storage cluster. For more information, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui). | `string` | `"cx2d-8x16"` | no |
| <a name="input_spectrum_scale_enabled"></a> [spectrum\_scale\_enabled](#input\_spectrum\_scale\_enabled) | Setting this to true will enables Spectrum Scale integration with the cluster. Otherwise, Spectrum Scale integration will be disabled (default). By entering 'true' for the property, you have also agreed to one of the two conditions: (1) You are using the software in production and confirm you have sufficient licenses to cover your use under the International Program License Agreement (IPLA). (2) You are evaluating the software and agree to abide by the International License Agreement for Evaluation of Programs (ILAE). Note: Failure to comply with licenses for production use of software is a violation of [IBM International Program License Agreement](https://www.ibm.com/software/passportadvantage/programlicense.html). | `bool` | `false` | no |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | Comma-separated list of names of the SSH key configured in your IBM Cloud account that is used to establish a connection to the LSF management node. Ensure that the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the instructions given at [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys). | `string` | n/a | yes |
| <a name="input_storage_node_instance_type"></a> [storage\_node\_instance\_type](#input\_storage\_node\_instance\_type) | Specify the virtual server instance profile type to be used to create the storage nodes for the Spectrum LSF cluster. The storage nodes are the ones that are used to create an NFS instance to manage the data for HPC workloads.  For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles). | `string` | `"bx2-2x8"` | no |
| <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block) | Creates the address prefix for the new VPC, when the vpc\_name variable is empty. Only a single address prefix is allowed. For more information, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design). | `list(string)` | <pre>[<br>  "10.241.0.0/18"<br>]</pre> | no |
| <a name="input_vpc_cluster_login_private_subnets_cidr_blocks"></a> [vpc\_cluster\_login\_private\_subnets\_cidr\_blocks](#input\_vpc\_cluster\_login\_private\_subnets\_cidr\_blocks) | The CIDR block that's required for the creation of the login cluster private subnet. Modify the CIDR block if it has already been reserved or used for other applications within the VPC or conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the login subnet. Since login subnet is used only for the creation of login virtual server instance provide a CIDR range of /28. | `list(string)` | <pre>[<br>  "10.241.16.0/28"<br>]</pre> | no |
| <a name="input_vpc_cluster_private_subnets_cidr_blocks"></a> [vpc\_cluster\_private\_subnets\_cidr\_blocks](#input\_vpc\_cluster\_private\_subnets\_cidr\_blocks) | The CIDR block that's required for the creation of the compute and storage cluster private subnet. Modify the CIDR block if it has already been reserved or used for other applications within the VPC or conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the compute and storage subnet. Make sure to select a CIDR block size that will accommodate the maximum number of management, storage, and both static and dynamic worker nodes that you expect to have in your cluster.  For more information on CIDR block size selection, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc). | `list(string)` | <pre>[<br>  "10.241.0.0/20"<br>]</pre> | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc). | `string` | `""` | no |
| <a name="input_vpn_enabled"></a> [vpn\_enabled](#input\_vpn\_enabled) | Set to true to deploy a VPN gateway for VPC in the cluster. | `bool` | `false` | no |
| <a name="input_vpn_peer_address"></a> [vpn\_peer\_address](#input\_vpn\_peer\_address) | The peer public IP address to which the VPN will be connected. | `string` | `""` | no |
| <a name="input_vpn_peer_cidrs"></a> [vpn\_peer\_cidrs](#input\_vpn\_peer\_cidrs) | Comma separated list of peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected. | `string` | `""` | no |
| <a name="input_vpn_preshared_key"></a> [vpn\_preshared\_key](#input\_vpn\_preshared\_key) | The pre-shared key for the VPN. | `string` | `""` | no |
| <a name="input_worker_node_instance_type"></a> [worker\_node\_instance\_type](#input\_worker\_node\_instance\_type) | Specify the virtual server instance profile type name to be used to create the worker nodes for the Spectrum LSF cluster. The worker nodes are the ones where the workload execution takes place and the choice should be made according to the characteristic of workloads. For choices on profile types, see [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui). Note: If dedicated\_host\_enabled == true, available instance prefix (e.g., bx2 and cx2) can be limited depending on your target region. Check `ibmcloud target -r {region_name}; ibmcloud is dedicated-host-profiles.` | `string` | `"bx2-4x16"` | no |
| <a name="input_worker_node_max_count"></a> [worker\_node\_max\_count](#input\_worker\_node\_max\_count) | The maximum number of worker nodes that can be deployed in the Spectrum LSF cluster. In order to use the [Resource Connector](https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=lsf-resource-connnector) feature to dynamically create and delete worker nodes based on workload demand, the value selected for this parameter must be larger than worker\_node\_min\_count. If you plan to deploy only static worker nodes in the LSF cluster, e.g., when using Spectrum Scale storage, the value for this parameter should be equal to worker\_node\_min\_count. Enter a value in the range 1 - 500. | `number` | `10` | no |
| <a name="input_worker_node_min_count"></a> [worker\_node\_min\_count](#input\_worker\_node\_min\_count) | The minimum number of worker nodes. This is the number of static worker nodes that will be provisioned at the time the cluster is created. If using NFS storage, enter a value in the range 0 - 500. If using Spectrum Scale storage, enter a value in the range 1 - 64. NOTE: Spectrum Scale requires a minimum of 3 compute nodes (combination of management-host, management-host-candidate, and worker nodes) to establish a [quorum](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=failure-quorum#nodequo) and maintain data consistency in the event of a node failure. Therefore, the minimum value of 1 may need to be larger if the value specified for management\_node\_count is less than 2. | `number` | `0` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | IBM Cloud zone name within the selected region where the Spectrum LSF cluster should be deployed. To get a full list of zones within a region, see [Get zones by using the CLI](https://test.cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region&interface=cli#get-zones-using-the-cli). | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_center"></a> [application\_center](#output\_application\_center) | n/a |
| <a name="output_application_center_url"></a> [application\_center\_url](#output\_application\_center\_url) | n/a |
| <a name="output_image_map_entry_found"></a> [image\_map\_entry\_found](#output\_image\_map\_entry\_found) | n/a |
| <a name="output_region_name"></a> [region\_name](#output\_region\_name) | n/a |
| <a name="output_spectrum_scale_storage_ssh_command"></a> [spectrum\_scale\_storage\_ssh\_command](#output\_spectrum\_scale\_storage\_ssh\_command) | n/a |
| <a name="output_ssh_to_ldap_node"></a> [ssh\_to\_ldap\_node](#output\_ssh\_to\_ldap\_node) | n/a |
| <a name="output_ssh_to_login_node"></a> [ssh\_to\_login\_node](#output\_ssh\_to\_login\_node) | n/a |
| <a name="output_ssh_to_management_node"></a> [ssh\_to\_management\_node](#output\_ssh\_to\_management\_node) | n/a |
| <a name="output_vpc_name"></a> [vpc\_name](#output\_vpc\_name) | n/a |
| <a name="output_vpn_config_info"></a> [vpn\_config\_info](#output\_vpn\_config\_info) | n/a |
