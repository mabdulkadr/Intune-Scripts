
# Bulk Run Remediation On-Demand Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

##Overview  
The **`bulk-run-remediation-ondemand.ps1`** script allows IT administrators to **trigger remediation scripts on multiple Intune-managed devices simultaneously** using the **Microsoft Graph API**. This script is designed for large-scale environments, enabling quick fixes, enforcing compliance, and ensuring consistency across managed endpoints.

---

##Reference  

- **Script Source:** [bulk-run-remediation-ondemand.ps1 on GitHub](https://github.com/andrew-s-taylor/public/blob/main/Powershell%20Scripts/Intune/bulk-run-remediation-ondemand.ps1)  
- **Microsoft Graph API Documentation:** [Microsoft Graph API Overview](https://learn.microsoft.com/en-us/graph/overview)  
- **Intune Remediation Scripts Guide:** [Microsoft Intune Remediation Scripts](https://learn.microsoft.com/en-us/mem/intune/protect/remediation-scripts)  

---

## 🚀 Key Features  

 **Bulk Remediation Execution:** Trigger remediation scripts across multiple devices simultaneously.  
 **Microsoft Graph API Integration:** Secure and efficient communication with Intune backend.  
 **Flexible Device Input:** Supports CSV files for specifying target devices.  
 **Real-Time Logging:** Provides logs and reports for each device execution.  
 **Error Handling:** Built-in checks for API calls, permissions, and device availability.  

---

##Prerequisites  

Before running the script, ensure the following prerequisites are met:

- **PowerShell 5.1+**  
- **Microsoft Graph API Permissions:**  
   - `DeviceManagementConfiguration.ReadWrite.All`  
- **Azure AD Account:** With sufficient Intune administrative privileges.  
- **CSV File:** Containing valid device IDs from Intune.  
- **Graph API Authentication Token:** Acquired via Azure AD app registration or interactive login.  
- **Administrative Privileges:** Run PowerShell with elevated privileges.  

---

##Script Details  

### **1. bulk-run-remediation-ondemand.ps1**

#### **Purpose**  
This script executes remediation tasks on-demand across Intune-managed devices. It leverages Microsoft Graph API to target devices specified in a CSV file, triggering pre-configured remediation scripts in bulk.

#### **Parameters**

| **Parameter**  | **Required** | **Description**                                | **Example**                    |
|---------------|-------------|------------------------------------------------|--------------------------------|
| `-DeviceList` | Yes         | Path to the CSV file containing device IDs.     | `C:\Devices\deviceList.csv`    |
| `-ScriptId`   | Yes         | Unique identifier for the remediation script.   | `12345-abcde-67890-fghij`      |
| `-GraphToken` | Yes         | Access token for authenticating to Graph API.   | `eyJhbGciOiJIUzI1NiIsInR5cCI6` |

---

#### **How to Run the Script**

1. Open **PowerShell** as an **Administrator**.  
2. Acquire a valid **Microsoft Graph API token** using Azure AD or an app registration.  
3. Prepare a CSV file containing the **Device IDs**.  
4. Run the script with required parameters:  

```powershell
.\bulk-run-remediation-ondemand.ps1 -DeviceList "C:\Devices\deviceList.csv" -ScriptId "12345-abcde-67890-fghij" -GraphToken "your-auth-token"
```

5. Monitor the output and check logs for success or errors.  

---

#### **Outputs**

- **Success Log:** Devices where remediation tasks were triggered successfully.  
- **Error Log:** Devices where execution failed, along with error details.  
- **Execution Summary:** Overview of success and failure rates across devices.

**Sample Output Log:**
```plaintext
[INFO] Device ID: device-id-1 - Remediation triggered successfully.
[ERROR] Device ID: device-id-2 - API Error: 403 Forbidden.
```

---

##CSV File Format  

The **DeviceList.csv** file should follow this structure:

```csv
DeviceId
device-id-1
device-id-2
device-id-3
```

- Each `DeviceId` must correspond to a valid device in Microsoft Intune.  

---

##Authentication Guide  

### **Option 1: Azure AD Interactive Login**  
1. Use the **Microsoft Graph Explorer** or **Azure Portal** to acquire a token.  
2. Ensure the token includes the required permissions (`DeviceManagementConfiguration.ReadWrite.All`).  

### **Option 2: Azure AD App Registration**  
1. Register an application in Azure AD.  
2. Grant required API permissions.  
3. Generate a client secret or certificate for authentication.  

For more details, refer to the [Microsoft Graph API Documentation](https://learn.microsoft.com/en-us/graph/overview).  

---

##Example Workflow  

1. **Prepare Device List:** Export device IDs into a CSV file.  
2. **Acquire Script ID:** Locate the remediation script ID from Intune portal or via Graph API.  
3. **Generate Token:** Authenticate and obtain a valid Graph API token.  
4. **Run Script:** Execute the script using the provided parameters.  
5. **Review Logs:** Analyze logs for success and failures.  

---

##Troubleshooting  

| **Issue**               | **Cause**                      | **Solution**                          |
|-------------------------|--------------------------------|---------------------------------------|
| Invalid API Token       | Token expired or invalid.     | Generate a new token.                 |
| Missing Permissions     | Insufficient Graph permissions| Verify API access settings.           |
| Device Not Found        | Invalid Device ID.            | Validate Device IDs in CSV.           |
| Network Timeout         | Slow network connection.      | Ensure stable connectivity.           |

---

##Best Practices  

- Validate the **DeviceList.csv** file before running the script.  
- Always use a secure method for storing API tokens.  
- Test the remediation script on a small subset of devices before bulk execution.  
- Enable detailed logging for easier troubleshooting.  

---

##Documentation and References  

- [Microsoft Graph API Documentation](https://learn.microsoft.com/en-us/graph/overview)  
- [Intune Remediation Scripts Overview](https://learn.microsoft.com/en-us/mem/intune/protect/remediation-scripts)  
- [Script Source on GitHub](https://github.com/andrew-s-taylor/public/blob/main/Powershell%20Scripts/Intune/bulk-run-remediation-ondemand.ps1)

---

##License  

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).  

---

**Disclaimer:**  
This script is provided **as-is**. Test it in a staging environment before production deployment. The author is **not responsible** for any unintended outcomes arising from its usage.
