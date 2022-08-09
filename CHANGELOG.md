# **CHANGELOG**

## **2.0.3**
### ENHANCEMENTS
- Support dedicated hosts for static worker nodes.
- Support for Spectrum Scale storage nodes.

### **BUG FIXES**
- Fixed bug related to Http data source body depreciation.
- Fixed bug related to Ansible version 2.10 upgrade.

### **CHANGES**
- Removed the input parameter "region" to match with other offerings.

## **2.0.2**
### **BUG FIXES**
- Fix for custom image lookup error.

## **2.0.1**
### **CHANGES**
- Changes to post provisioning scripts to mitigate Polkit Local Privilege Escalation Vulnerability (CVE-2021-4034).

## **2.0.0**
### ENHANCEMENTS
- Support to use an existing VPC.
- Changes related to VPN support.

### **CHANGES**
- Updated terraform version to 0.14.
- Enable hyperthreading by default.
- Add parallelism to schematics destroy.

### **BUG FIXES**
- Fix for error "No image found with name" if the image name is not found in the image mapping file.

## **1.0.0**
- Initial Release.
