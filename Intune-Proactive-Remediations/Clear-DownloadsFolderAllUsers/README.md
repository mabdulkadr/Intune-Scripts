# 📥 Clear-DownloadsFolderAllUsers – Forced Downloads Folder Cleanup

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Downloads%20Cleanup-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Clear-DownloadsFolderAllUsers** is a very direct Intune remediation package that deletes files and folders under every user's `Downloads` directory on the local device.

The detection script does not inspect device state at all. It always exits with code `1`, which forces Intune to run the remediation script every time the package executes. The remediation script then runs a recursive deletion against:

```text
C:\Users\*\Downloads\*
```

This package is best understood as a scheduled cleanup action packaged as an Intune remediation, not as a true detection/remediation pair.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Clear-DownloadsFolderAllUsers
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Clear-DownloadsFolderAllUsers
│
├── Clear-DownloadsFolderAllUsers--Detect.ps1
├── Clear-DownloadsFolderAllUsers--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Clear-DownloadsFolderAllUsers--Detect.ps1
```

### Purpose

Always forces remediation to run.

### Logic

1. Initializes logging
2. Writes a status message
3. Exits with code `1` every time

### Exit Codes

| Code | Status |
| ---- | ------ |
| 1    | Always trigger remediation |

### Example

```powershell
.\Clear-DownloadsFolderAllUsers--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Clear-DownloadsFolderAllUsers--Remediate.ps1
```

### Purpose

Deletes all content inside every detected `Downloads` folder under `C:\Users`.

### Actions

1. Initializes logging
2. Enumerates `C:\Users\*\Downloads\*`
3. Removes matching items recursively and forcefully

### Key References

* Path: `C:\Users\*\Downloads\*`
* Command: `Remove-Item -Recurse -Force`

### Example

```powershell
.\Clear-DownloadsFolderAllUsers--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to enumerate user profiles under `C:\Users`
* Permission to delete files from user `Downloads` folders

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Clear-DownloadsFolderAllUsers`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Clear-DownloadsFolderAllUsers--Detect.ps1
```

### Remediation Script

```powershell
Clear-DownloadsFolderAllUsers--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | Review your target profile access model |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection immediately exits with code `1`
3. Intune runs the **Remediation Script**
4. Remediation deletes content from all matching `Downloads` folders

---

# 🛡 Operational Notes

* This package is destructive by design
* Detection is only a trigger and does not represent a compliance check
* The remediation script does not exclude active user content, recent files, or protected file types
* Test carefully before broad deployment, especially on shared or multi-user devices

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

