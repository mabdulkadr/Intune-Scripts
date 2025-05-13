
# Bulk-IntunePrimaryUserUpdate.ps1

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview

`Bulk-IntunePrimaryUserUpdate.ps1` is a PowerShell script that assigns the **Primary User** for all **Windows devices** managed in Microsoft Intune using the **Microsoft Graph API**.

This script is designed for **bulk updates** across large environments (e.g., 5000+ devices), using **app-based authentication** (client credentials) with a registered Azure AD application.

It improves reliability by assigning the primary user based on the `userPrincipalName` already associated with each device, avoiding reliance on the potentially inaccurate `UsersLoggedOn` property.

---

## Features

- ✅ Authenticates via Azure AD App (Client ID & Secret)
- 📦 Retrieves all Windows devices in Intune (with pagination)
- 👤 Sets primary user based on the current `userPrincipalName`
- 🚀 Handles large-scale environments efficiently
- ⚠️ Includes safety prompts, throttling, and error handling

---

## Requirements

- PowerShell 5.1 or later
- Azure AD App Registration with the following Application API Permissions:
  - `DeviceManagementManagedDevices.ReadWrite.All`
  - `User.Read.All`
- A client secret for the Azure AD App

---

## Setup

1. **Register an Azure AD App** in Microsoft Entra admin center.
2. Assign the required Graph API permissions (application type).
3. Create a **client secret** and copy:
   - **Tenant ID**
   - **Client ID (App ID)**
   - **Client Secret**

---

## How to Use

1. Open `Bulk-IntunePrimaryUserUpdate.ps1` in a text editor.
2. Update the following variables at the top of the script:

```powershell
$tenantID   = "your-tenant-id-guid"
$appID      = "your-app-client-id"
$appSecret  = "your-app-client-secret"
````

3. Run the script from PowerShell:

```powershell
.\Bulk-IntunePrimaryUserUpdate.ps1
```

4. Confirm when prompted:

```plaintext
⚠️ Set primary user for 5000+ devices? (Y/N)
```

---

## Script Logic

1. Authenticates to Microsoft Graph using the client credentials flow.
2. Retrieves all Windows devices via the `deviceManagement/managedDevices` Graph endpoint.
3. Loops through each device:

   * Reads the current `userPrincipalName`
   * Resolves the user’s Object ID via `/users/{UPN}`
   * Assigns the user as the primary user via `/managedDevices/{id}/users/$ref`

---

## Output

* ✅ Console output for every successful assignment
* ⏭️ Warning for skipped devices (e.g., if `userPrincipalName` is empty)
* ❌ Error for any failed assignment

---

## Example Output

```plaintext
✅ [PC-IT-001] Primary user set to user01@contoso.com
⏭️ Skipping PC-IT-002: No userPrincipalName assigned.
❌ [PC-IT-003] Failed to set primary user: The user could not be found.
```

---

## References

* 💡 [Dustin Gullett – Intune Primary User Mix-Up (LinkedIn)](https://www.linkedin.com/pulse/intune-primary-user-mix-up-dustin-gullett-kmwec/)

---

## Notes

* The script uses a delay (`200ms`) between API requests to reduce throttling risk.
* Only devices running Windows OS are targeted (`operatingSystem eq 'Windows'`).
* This script uses Microsoft Graph Beta endpoints.

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## Disclaimer

> Use this script at your own risk. It is recommended to test in a development or pilot tenant before deploying in production. The author is not responsible for any unintended changes or impact.

