# 🔍 App Presence Compliance – Intune Custom Compliance

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Custom-Compliance-green.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**App Presence Compliance** is a lightweight PowerShell solution designed for **Microsoft Intune Custom Compliance Policies**.

The script checks whether a **specific application is installed on a device** and reports the compliance result to Microsoft Intune.

This allows administrators to enforce policies such as:

- Blocking unauthorized software
- Ensuring prohibited applications are removed
- Monitoring application compliance across managed devices

The project consists of:

- **PowerShell detection script**
- **JSON compliance rule**

The JSON file defines the compliance logic and remediation message. :contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Detects whether a **specific application is installed**
- Built for **Microsoft Intune Custom Compliance**
- Uses **Windows registry detection**
- Configurable through **JSON policy rules**
- Supports **multiple applications**
- Returns results compatible with **Intune compliance evaluation**

---

# 📂 Project Structure

```

App-Presence-Compliance
│
├── App-Presence-Compliance.ps1
├── App-Presence-Compliance.json
└── README.md

```

---

# ⚙ How It Works

The script searches Windows uninstall registry entries to detect installed applications.

Typical registry locations scanned:

```

HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall

```

If the application is detected:

```

Device → Non-Compliant

```

If the application is not detected:

```

Device → Compliant

````

---

# 🧾 Script Details

## App-Presence-Compliance.ps1

### Purpose

Detects whether a specified application exists on the device and returns a compliance status to Intune.

### Example Execution

```powershell
.\App-Presence-Compliance.ps1
````

### Exit Codes

| Exit Code | Result                                |
| --------- | ------------------------------------- |
| 0         | Compliant – Application not installed |
| 1         | Non-compliant – Application detected  |

---

# 📄 Compliance Rule Configuration

The compliance rule is defined in:

```
App-Presence-Compliance.json
```

Example rule:

```json
{
 "Rules": [
   {
     "SettingName": "Google Chrome",
     "Operator": "IsEquals",
     "DataType": "Boolean",
     "Operand": true,
     "MoreInfoUrl": "https://www.liviubarbat.info",
     "RemediationStrings": [
       {
         "Language": "en_US",
         "Title": "Google Chrome is installed.",
         "Description": "Please uninstall this software"
       }
     ]
   }
 ]
}
```

Key parameters:

| Parameter          | Description                   |
| ------------------ | ----------------------------- |
| SettingName        | Application name              |
| Operator           | Compliance operator           |
| DataType           | Expected data type            |
| Operand            | Expected compliance state     |
| RemediationStrings | Message displayed to the user |

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Upload Detection Script

Upload:

```
App-Presence-Compliance.ps1
```

as a **Custom Compliance Detection Script**.

---

### 2️⃣ Upload JSON Rule

Upload:

```
App-Presence-Compliance.json
```

as the **Compliance Policy Rule**.

---

### 3️⃣ Assign Policy

Assign the compliance policy to:

* Device groups
* User groups

---

### 4️⃣ Monitor Compliance

Navigate to:

```
Microsoft Intune
Devices → Compliance policies → Device compliance
```

---

# 💡 Example Use Cases

### Block Unauthorized Software

Detect and block:

* Google Chrome
* TeamViewer
* Zoom
* Any non-approved application

---

### Security Enforcement

Ensure only **approved applications** are installed on corporate devices.

---

### Software Governance

Detect:

* Legacy applications
* Unauthorized utilities
* Potentially risky software

---

# 🛠 Customization

To monitor a different application:

### Modify the script

```powershell
$AppNames = @("ApplicationName")
```

### Modify the JSON rule

```
"SettingName": "ApplicationName"
```

Ensure the name matches exactly what appears in:

```
appwiz.cpl
(Add or Remove Programs)
```

---

# ⚠ Important Notes

* Designed for **Microsoft Intune Custom Compliance Policies**
* Script should run in **64-bit PowerShell**
* Application names must match uninstall registry entries
* Always test policies in a **pilot group** before production deployment

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
