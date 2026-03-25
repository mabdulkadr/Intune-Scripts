# 🔍 App Version Compliance – Intune Custom Compliance

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Custom-Compliance-green.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**App Version Compliance** is a PowerShell solution designed for **Microsoft Intune Custom Compliance Policies**.

The script verifies:

1. Whether a specific application is installed.
2. Whether the installed version meets a **minimum required version**.

This allows organizations to enforce **software version compliance** and ensure that managed devices run **approved and up-to-date applications**.

The solution consists of:

- **PowerShell detection script**
- **JSON compliance rule**

These components allow Intune to evaluate device compliance and report non-compliant devices automatically.

---

# ✨ Key Features

- Detects whether an application is installed
- Validates the installed **application version**
- Supports both **machine-wide and user-based installations**
- Checks registry locations in:
  - `HKLM`
  - `HKCU`
- Outputs **JSON formatted results compatible with Intune**
- Easily configurable using a **JSON policy rule**

---

# 📂 Project Structure

```

App-Version-Compliance
│
├── App-Version-Compliance.ps1
├── App-Version-Compliance.json
└── README.md

```

---

# ⚙ How It Works

The script scans Windows uninstall registry locations to detect installed applications and determine their version.

Registry locations checked:

```

HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall
HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall

````

If the application exists:

- The script retrieves the **installed version**

The installed version is then compared with the **minimum required version** defined in the JSON compliance rule.

---

# 🧾 Script Details

## App-Version-Compliance.ps1

### Purpose

Detects whether a specified application is installed and verifies that its version meets the **minimum required version**.

### Example Execution

```powershell
.\App-Version-Compliance.ps1
````

### Example Output

If the application exists:

```
{
 "Google Chrome": "133.0.6943.54"
}
```

If the application is not installed:

```
{
 "Google Chrome": false
}
```

---

# 📄 Compliance Rule Configuration

The compliance policy rule is defined in:

```
App-Version-Compliance.json
```

Example rule:

```json
{
 "Rules": [
   {
     "SettingName": "Google Chrome",
     "Operator": "GreaterEquals",
     "DataType": "Version",
     "Operand": "133.0.6943.54",
     "MoreInfoUrl": "https://www.momar.tech",
     "RemediationStrings": [
       {
         "Language": "en_US",
         "Title": "Google Chrome is outdated or not installed. Value discovered was {ActualValue}.",
         "Description": "Make sure to install or update Google Chrome"
       }
     ]
   }
 ]
}
```



---

# 📊 Compliance Logic

| Scenario                                | Result        |
| --------------------------------------- | ------------- |
| Application not installed               | Non-compliant |
| Application version lower than required | Non-compliant |
| Application version equal or higher     | Compliant     |

---

# 🚀 Deployment in Microsoft Intune

### Step 1 – Upload Detection Script

Upload:

```
App-Version-Compliance.ps1
```

as a **Custom Compliance Detection Script**.

---

### Step 2 – Upload Compliance Rule

Upload:

```
App-Version-Compliance.json
```

as the **Compliance Policy Rule**.

---

### Step 3 – Assign Policy

Assign the policy to:

* Device groups
* User groups

---

### Step 4 – Monitor Compliance

Navigate to:

```
Microsoft Intune
Devices → Compliance policies → Device compliance
```

to monitor results.

---

# 💡 Example Use Cases

### Enforce Minimum Browser Version

Ensure users run the latest version of:

* Google Chrome
* Microsoft Edge
* Mozilla Firefox

---

### Security Compliance

Detect devices running **outdated software versions** with potential vulnerabilities.

---

### Application Governance

Maintain a **baseline software version standard** across all managed devices.

---

# 🛠 Customization

To monitor another application:

### Modify the script

```powershell
$applicationName = @("ApplicationName")
```

### Modify the JSON rule

```
"SettingName": "ApplicationName"
```

Update the minimum required version:

```
"Operand": "RequiredVersion"
```

Ensure the application name matches exactly what appears in:

```
appwiz.cpl
(Add or Remove Programs)
```

---

# ⚠ Important Notes

* Designed specifically for **Microsoft Intune Custom Compliance Policies**
* Script should run in **64-bit PowerShell**
* Application names must match uninstall registry entries
* Always test policies in a **pilot group before production rollout**

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.1**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.