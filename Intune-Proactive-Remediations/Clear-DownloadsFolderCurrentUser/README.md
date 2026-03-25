# 📁 Clear-DownloadsFolderCurrentUser – Current User Downloads Cleanup

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-User%20Downloads%20Cleanup-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Clear-DownloadsFolderCurrentUser** is an Intune remediation package that checks the `Downloads` folder of the current user profile and clears it when items are present.

Unlike the broader multi-user cleanup package, this workflow is scoped to:

```text
$env:USERPROFILE\Downloads
```

The detection script enumerates that folder and returns a non-zero result when one or more files or folders are present. The remediation script then removes the contents of the same folder recursively.

This package is useful when you want a safer user-scoped cleanup model instead of deleting downloads across every profile on the device.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Clear-DownloadsFolderCurrentUser
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Clear-DownloadsFolderCurrentUser
│
├── Clear-DownloadsFolderCurrentUser--Detect.ps1
├── Clear-DownloadsFolderCurrentUser--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Clear-DownloadsFolderCurrentUser--Detect.ps1
```

### Purpose

Checks whether the current user's Downloads folder contains any items.

### Logic

1. Sets the target path to `$env:USERPROFILE\Downloads`
2. Enumerates the folder content with `Get-ChildItem`
3. Returns exit code `1` when one or more items are present
4. Returns exit code `0` when the folder is empty

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | The current user's Downloads folder is empty |
| 1    | One or more items are present in the current user's Downloads folder |

### Key References

* Path: `$env:USERPROFILE\Downloads`

### Example

```powershell
.\Clear-DownloadsFolderCurrentUser--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Clear-DownloadsFolderCurrentUser--Remediate.ps1
```

### Purpose

Clears the contents of the current user's Downloads folder.

### Actions

1. Initializes logging
2. Enumerates `$env:USERPROFILE\Downloads`
3. Removes all child items recursively and forcefully

### Key References

* Path: `$env:USERPROFILE\Downloads`
* Command: `Remove-Item -Recurse -Force`

### Example

```powershell
.\Clear-DownloadsFolderCurrentUser--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* The execution context must have access to the current user's profile folder
* User context is the natural fit for this workflow

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Clear-DownloadsFolderCurrentUser`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Clear-DownloadsFolderCurrentUser--Detect.ps1
```

### Remediation Script

```powershell
Clear-DownloadsFolderCurrentUser--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | Yes   |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection checks the current user's Downloads folder
3. If items are present, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation deletes the contents of that same folder

---

# 🛡 Operational Notes

* This package is still destructive, but only within the current user's Downloads folder
* Detection assumes the Downloads path is the standard profile location
* The remediation script does not exclude active files, recent files, or protected file types
* Test on pilot devices before wide deployment

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

