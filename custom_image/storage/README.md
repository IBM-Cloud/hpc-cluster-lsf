# Prerequisites

1. The source image to be used to create the custom image must be part of **Images of VPC**, which includes custom images, stock images, and catalog images and has an "Available" status.


2. The source image should be running on a [kernel version](https://www.ibm.com/docs/en/spectrum-scale?topic=STXKQY/gpfsclustersfaq.html#fsi) supported by Spectrum Scale.


3. The source image should be able to install the [prerequisites](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=gpfs-software-requirements) for Spectrum Scale.
   
   **Note**: The `kernel-devel` package should have same version as `kernel` package. 


4. Download the IBM Spectrum Scale Data Management Edition install package (from [Fix Central](https://www.ibm.com/support/fixcentral)). 
   1. On the **Find product** tab, enter _IBM Spectrum Scale (Software defined storage)_ in the **Product selector** field.
   2. For **Installed Version**, select the version for your custom image creation.
   3. For **Platform**, select Linux 64-bit,x86_64.
   4. Click **Continue**, and it will redirect to _Select fixes_ page.
   5. On the _Select fixes_ page, click the **Data Management** link to get the fix pack.

5. Create a directory (/tmp/packages/scale) and copy the listed packages.

   ```cli
   $ mkdir -p /tmp/packages/scale
   ```

   Example:
   ```cli
   $ ls /tmp/packages/scale
   SpectrumScale_public_key.pgp
   gpfs.adv-5.1.5-1.x86_64.rpm
   gpfs.base-5.1.5-1.x86_64.rpm
   gpfs.crypto-5.1.5-1.x86_64.rpm
   gpfs.docs-5.1.5-1.noarch.rpm
   gpfs.gpl-5.1.5-1.noarch.rpm
   gpfs.gskit-8.0.55-19.1.x86_64.rpm
   gpfs.gss.pmcollector-5.1.5-1.el8.x86_64.rpm
   gpfs.gss.pmsensors-5.1.5-1.el8.x86_64.rpm
   gpfs.gui-5.1.5-1.noarch.rpm
   gpfs.java-5.1.5-1.x86_64.rpm
   gpfs.license.dm-5.1.5-1.x86_64.rpm
   gpfs.msg.en_US-5.1.5-1.noarch.rpm
    ```
   
   **Note**: Ensure that you use the same Spectrum Scale packages for the worker custom image.


6. Download a pre-built [Packer binary](https://www.packer.io/downloads) for your operating system.

## Create Custom Image (using Packer)

The following steps provision the IBM Cloud VSI, install IBM Spectrum Scale RPM's, and create a new image.

1. Change working directory to `custom_image/storage/`.

   ```cli
   cd hpc-cluster-lsf/custom_image/storage/
   ```

2. Create packer variable definitions file (`inputs.auto.pkrvars.hcl`) and provide infrastructure inputs.
    
   **Note**: The `vpc_subnet_id` and `source_image_name` should belong to `vpc_region` variable value. 

   Minimal Example:

   ```jsonc
   $ cat inputs.auto.pkrvars.hcl
   ibm_api_key = "<IBMCloud_api_key>"
   vpc_region = "<IBMCloud_supported_region_name>"
   resource_group_id = "<Existing_resource_group_id>"
   vpc_subnet_id = "<Existing_subnet_id_from_provided_vpc_region>"
   source_image_name = "<Source_image_name_from_images_of_VPC>"
   image_name = "<image_name_for_newly_created_custom_image>"
    ```

3. Run `packer init .` to install the Packer plugin for IBM Cloud.


4. Run `packer build .` to create the custom image.

   **Note**: The `mmbuildgpl` command's output in the Packer console (mmbuildgpl: Building GPL module completed successfully) indicates if the new custom image creation is successful. Also, the newly created image should be listed under the custom [Images of VPC](https://cloud.ibm.com/vpc-ext/compute/images) with the name that you provided for the `image_name` parameter with Active status.


## Limitations:

- The custom image creation scripts are only compatible with Red Hat-based Linux distributions operating systems.

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ibm_api_key"></a> [ibm\_api\_key](#input\_ibm\_api\_key) | IBM Cloud API key. | `string` | n/a | yes |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | The name of the resulting custom image. Make sure that the image name is unique. | `string` | n/a | yes |
| <a name="input_private_key_file"></a> [private\_key\_file](#input\_private\_key\_file) | The SSH private key file path that is used to create a VPC SSH key pair. | `string` | `"/root/.ssh/id_rsa"` | no |
| <a name="input_public_key_file"></a> [public\_key\_file](#input\_public\_key\_file) | The SSH public key file path that is used to create a VPC SSH key pair. | `string` | `"/root/.ssh/id_rsa.pub"` | no |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | The existing resource group ID. | `string` | n/a | yes |
| <a name="input_source_image_name"></a> [source\_image\_name](#input\_source\_image\_name) | The source image name whose root volume is copied and provisioned on the currently running instance. | `string` | n/a | yes |
| <a name="input_vpc_region"></a> [vpc\_region](#input\_vpc\_region) | The region where IBM Cloud operations takes place (for example, us-east, us-south, etc.) | `string` | n/a | yes |
| <a name="input_vpc_subnet_id"></a> [vpc\_subnet\_id](#input\_vpc\_subnet\_id) | The subnet ID to use for the instance. | `string` | n/a | yes |
| <a name="input_vsi_profile"></a> [vsi\_profile](#input\_vsi\_profile) | The IBM Cloud VSI type to use while building the custom image. | `string` | `"bx2d-2x8"` | no |

