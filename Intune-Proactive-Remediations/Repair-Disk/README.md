# 🛠️ Repair-DiskFileSystem – Always Run an Offline Repair on Drive C

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Disk%20Repair-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Repair-DiskFileSystem** is an always-run remediation package that starts an offline repair operation on drive `C`.

The detection script always exits with code `1`, which guarantees remediation will run. The remediation script then calls `Repair-Volume -DriveLetter C -OfflineScanAndFix`.

This package does not check file system health before acting. It simply triggers an offline repair workflow every time remediation runs.

---

# ✨ Core Features

### 🔹 Always-Run Detection

The detection script:

* Writes a status message
* Exits with code `1`
* Always triggers remediation

---

### 🔹 Volume Repair Remediation

The remediation script runs:

```powershell
Repair-Volume -DriveLetter C -OfflineScanAndFix
```

This is a potentially disruptive storage repair action.

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Repair-Disk
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Repair-Disk
│
├── README.md
├── Repair-Disk--Detect.ps1
└── Repair-Disk--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Repair-DiskFileSystem--Detect.ps1
```

### Purpose

Always triggers the disk repair script.

### Logic

1. Writes a message that the script will always be triggered
2. Exits with code `1`

### Exit Codes

| Code | Status |
| ---- | ------ |
| 1    | Always trigger remediation |

### Example

```powershell
.\Repair-DiskFileSystem--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Repair-DiskFileSystem--Remediate.ps1
```

### Purpose

Runs an offline repair against the `C:` volume.

### Actions

1. Executes `Repair-Volume -DriveLetter C -OfflineScanAndFix`

### Example

```powershell
.\Repair-DiskFileSystem--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* `Repair-Volume`

### Permissions

* Administrative rights are required

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Repair-DiskFileSystem--Detect.ps1
```

### Remediation Script

```powershell
Repair-DiskFileSystem--Remediate.ps1
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
2. Detection always exits with code **1**
3. Intune triggers the **Remediation Script**
4. The script starts an offline repair on `C:`

---

# 🛡 Operational Notes

* This package does not validate whether a repair is actually needed.
* `Repair-Volume -OfflineScanAndFix` can be disruptive and should be tested carefully.
* The internal `SolutionName` and log naming still use `Invoke-Repair-DiskFileSystem`, while the folder name is `Repair-DiskFileSystem`.

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

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-%E2%98%95-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.
