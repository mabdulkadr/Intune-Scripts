# 🗑️ Clear-RecycleBin – Always Empty the Recycle Bin

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Storage%20Cleanup-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Clear-RecycleBin** is an always-run cleanup package that empties the local Recycle Bin whenever remediation runs.

The detection script does not evaluate any state and always returns exit code `1`. That forces Intune to trigger the remediation script, which then runs `Clear-RecycleBin -Force`.

This package is intended for direct cleanup rather than for conditional remediation.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Clear-RecycleBin
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Clear-RecycleBin
│
├── Clear-RecycleBin--Detect.ps1
├── Clear-RecycleBin--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Clear-RecycleBin--Detect.ps1
```

### Purpose

Always triggers the cleanup script.

### Logic

1. Writes a message that the script will always be triggered
2. Exits with code `1`

### Exit Codes

| Code | Status |
| ---- | ------ |
| 1    | Always trigger remediation |

### Example

```powershell
.\Clear-RecycleBin--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Clear-RecycleBin--Remediate.ps1
```

### Purpose

Empties the local Recycle Bin without prompting the user.

### Actions

1. Runs `Clear-RecycleBin -Force`

### Example

```powershell
.\Clear-RecycleBin--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* `Clear-RecycleBin`

### Permissions

* The script must run in a context that can clear the target Recycle Bin content

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Clear-RecycleBin--Detect.ps1
```

### Remediation Script

```powershell
Clear-RecycleBin--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | Yes |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection always exits with code **1**
3. Intune triggers the **Remediation Script**
4. The remediation script clears the Recycle Bin immediately

---

# 🛡 Operational Notes

* This package is intentionally unconditional.
* It does not check how much data is in the Recycle Bin before clearing it.
* Because the cleanup is immediate, test carefully before broad rollout.

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
