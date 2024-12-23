
# Create Windows ISO with APJSON Configuration

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview  
This PowerShell script automates the creation of a Windows ISO image, embedding an `autopilot.json` configuration file. The resulting ISO is customized for use with Microsoft Intune and Windows Autopilot, enabling seamless deployment and device provisioning.

**Script Reference:** [create-windows-iso-with-apjson.ps1](https://github.com/andrew-s-taylor/public/blob/main/Powershell%20Scripts/Intune/create-windows-iso-with-apjson.ps1)

---

## Key Features  
- Automates the creation of Windows ISO files.  
- Embeds an `autopilot.json` file into the ISO.  
- Streamlines deployment of Windows devices via Microsoft Intune.  
- Customizable paths for source ISO, configuration file, and output ISO.  

---

## Scripts Included  

### **1. create-windows-iso-with-apjson.ps1**  
- **Purpose:** Automates ISO creation with a pre-configured `autopilot.json` for Intune deployment.  
- **File Path:** `.\create-windows-iso-with-apjson.ps1`  
- **Reference:** [Script Link](https://github.com/andrew-s-taylor/public/blob/main/Powershell%20Scripts/Intune/create-windows-iso-with-apjson.ps1)  

---

## Prerequisites  

- Windows 10/11 or Windows Server with PowerShell 5.1 or later.  
- Administrative privileges on the executing machine.  
- Windows Assessment and Deployment Kit (ADK) tools installed.  
- Valid `autopilot.json` file.  
- Sufficient disk space for temporary files and final ISO.  

---

## Script Details  

### **1. create-windows-iso-with-apjson.ps1**  

#### **Purpose**  
The script creates a customized Windows ISO image by injecting an `autopilot.json` configuration file. This simplifies Windows Autopilot device enrollment in Microsoft Intune, ensuring the ISO is ready for deployment on target devices.

#### **Parameters**  

| Parameter    | Required | Description                                     | Example                       |
|--------------|----------|-------------------------------------------------|--------------------------------|
| `-SourceISO` | Yes      | Path to the source Windows ISO file.            | `C:\ISOs\Windows10.iso`        |
| `-APJSON`    | Yes      | Path to the `autopilot.json` configuration file.| `C:\Configs\autopilot.json`    |
| `-OutputISO` | Yes      | Path to save the newly created ISO file.        | `C:\ISOs\Windows10_AP.iso`     |

#### **How to Run**  

1. Open PowerShell as an Administrator.  
2. Run the script with the required parameters:  
```powershell
.\create-windows-iso-with-apjson.ps1 -SourceISO "C:\ISOs\Windows10.iso" -APJSON "C:\Configs\autopilot.json" -OutputISO "C:\ISOs\Windows10_AP.iso"
```
3. Verify the output ISO file is created successfully.  

#### **Outputs**  
- A customized Windows ISO file containing the `autopilot.json` configuration.  
- Log files detailing the script execution process.  

---

## Example Workflow  

1. Prepare a valid Windows ISO file (`Windows10.iso`).  
2. Prepare a valid `autopilot.json` file with Intune configuration settings.  
3. Run the script with appropriate parameters.  
4. Burn or mount the output ISO for deployment on devices.  

#### **Sample autopilot.json File**  
```json
{
    "CloudAssignedTenantId": "your-tenant-id",
    "CloudAssignedDomainJoinMethod": "AzureADJoin",
    "CloudAssignedOobeConfig": 1
}
```

---

## Error Handling  

- The script includes error checks for invalid file paths and missing parameters.  
- Log files are generated to help troubleshoot issues.  
- Common errors such as insufficient permissions or disk space are flagged.  

---

## Best Practices  

- Always validate your `autopilot.json` file.  
- Test the ISO on a virtual machine before deploying it to physical devices.  
- Store the output ISO securely to prevent unauthorized access.  

---

## Troubleshooting  

| Issue                          | Possible Cause                  | Solution                           |
|--------------------------------|----------------------------------|------------------------------------|
| Script fails to run            | Insufficient permissions         | Run PowerShell as Administrator.   |
| Invalid path error             | Incorrect file paths             | Double-check file paths.           |
| ISO creation failed            | Insufficient disk space          | Free up disk space.                |

---

## Notes  
- This script is intended for IT administrators managing Intune and Windows Autopilot deployments.  
- Always test the ISO in a staging environment before production deployment.  
- Review Microsoft documentation on [Windows Autopilot](https://learn.microsoft.com/en-us/mem/autopilot/).  

## License  
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).  

---

**Disclaimer:** These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.

