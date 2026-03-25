# 🚪 Invoke-LogoffCurrentUser – Always Force Logoff of the Interactive User

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-User%20Session%20Control-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Invoke-LogoffCurrentUser** is an always-run package that warns the current user and then forces a logoff.

The detection script always returns exit code `1`, which ensures remediation runs every time. The remediation script shows a simple WPF message box that says the user will be logged out in `60` seconds, then calls `shutdown /L /f 60`.

This package is intrusive by design and should only be used where forced session termination is acceptable.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Invoke-LogoffCurrentUser
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Invoke-LogoffCurrentUser
│
├── Invoke-LogoffCurrentUser--Detect.ps1
├── Invoke-LogoffCurrentUser--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Invoke-LogoffCurrentUser--Detect.ps1
```

### Purpose

Always triggers the logoff remediation script.

### Logic

1. Writes a message that the script will always be triggered
2. Exits with code `1`

### Exit Codes

| Code | Status |
| ---- | ------ |
| 1    | Always trigger remediation |

### Example

```powershell
.\Invoke-LogoffCurrentUser--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Invoke-LogoffCurrentUser--Remediate.ps1
```

### Purpose

Shows a warning dialog and then logs off the current user forcibly.

### Actions

The script performs the following steps:

1. Loads WPF assemblies
2. Shows a message box telling the user they will be logged off in 60 seconds
3. Runs `shutdown /L /f 60`

### Example

```powershell
.\Invoke-LogoffCurrentUser--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* WPF message box
* `shutdown.exe`

### Permissions

* The remediation script should run in an interactive user session

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Invoke-LogoffCurrentUser--Detect.ps1
```

### Remediation Script

```powershell
Invoke-LogoffCurrentUser--Remediate.ps1
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
2. Detection always exits with code **1**
3. Intune triggers the **Remediation Script**
4. The user sees a warning dialog
5. The script starts a forced logoff

---

# 🛡 Operational Notes

* This package always logs the user off when it runs.
* Unsaved user work can be lost.
* The `shutdown` syntax in the script should be validated in your environment before production deployment.

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
