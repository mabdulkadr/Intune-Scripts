# 💻 Uninstall-DellSupportAssistApp – Remove Dell SupportAssist from the Device

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Dell%20App%20Removal-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Uninstall-DellSupportAssistApp** detects **Dell SupportAssist** by reading the uninstall registry keys and then removes it by using the uninstall method exposed by the installed product.

Detection searches both 64-bit and Wow6432Node uninstall hives for a display name of `Dell SupportAssist`. Remediation reads the uninstall string and supports two uninstall paths:

* `msiexec.exe` with a product GUID
* `SupportAssistUninstaller.exe` with silent arguments

This package is a cleaner fit for OEM cleanup than the AppX-based uninstall packages in this folder.

---

# ✨ Core Features

### 🔹 Registry-Based Application Discovery

Detection looks in:

* `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`
* `HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*`

and captures both `DisplayName` and `UninstallString`.

---

### 🔹 Multiple Uninstall Paths

Remediation supports two uninstall methods based on the stored uninstall string:

* MSI uninstall via extracted product GUID
* SupportAssist uninstaller executable with `/arp /S`

---

### 🔹 Explicit Detection Output

When SupportAssist is found, the detection script also writes the uninstall string to output. That can be useful during pilot validation.

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Uninstall-DellSupportAssistApp
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Uninstall-DellSupportAssistApp
│
├── README.md
├── Uninstall-DellSupportAssistApp--Detect.ps1
└── Uninstall-DellSupportAssistApp--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Uninstall-DellSupportAssistApp--Detect.ps1
```

### Purpose

Checks whether Dell SupportAssist is installed and captures its uninstall string.

### Logic

1. Searches the standard uninstall registry locations
2. Filters for `DisplayName -eq 'Dell SupportAssist'`
3. Returns `1` when the application is found
4. Returns `0` when it is not present

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Dell SupportAssist not found |
| 1    | Dell SupportAssist found |

### Example

```powershell
.\Uninstall-DellSupportAssistApp--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Uninstall-DellSupportAssistApp--Remediate.ps1
```

### Purpose

Removes Dell SupportAssist by using the uninstall method recorded in the uninstall string.

### Actions

1. Reads the uninstall registry data for Dell SupportAssist
2. If the uninstall string contains `msiexec.exe`, extracts the product GUID and runs `/x {GUID} /qn`
3. If the uninstall string contains `SupportAssistUninstaller.exe`, launches it with `/arp /S`
4. Returns an error when neither method is recognized

### Example

```powershell
.\Uninstall-DellSupportAssistApp--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Administrative rights are required to uninstall the application

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Uninstall-DellSupportAssistApp--Detect.ps1
```

### Remediation Script

```powershell
Uninstall-DellSupportAssistApp--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | No    |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection reads the uninstall registry keys
3. If Dell SupportAssist is found, detection exits with code **1**
4. Intune runs the **Remediation Script**
5. Remediation uses the recorded uninstall method to remove the application

---

# 🛡 Operational Notes

* The remediation logic only supports the uninstall methods explicitly handled in the script.
* The MSI branch relies on the uninstall string containing a GUID in braces. If Dell changes the format, that parsing can fail.
* The script assumes the uninstall string is trustworthy and executable as returned from the registry.

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.2**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.

