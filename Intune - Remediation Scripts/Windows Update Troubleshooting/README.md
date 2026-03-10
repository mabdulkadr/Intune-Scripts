# 🛠 Windows Update Troubleshooting

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Feature](https://img.shields.io/badge/Feature-Windows%20Update-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Windows Update Troubleshooting** is a PowerShell automation solution designed to detect and remediate common **Windows Update issues** on managed devices.

Windows Update failures are common in enterprise environments and may occur due to:

* Corrupted Windows Update components
* Paused or deferred update policies
* Outdated OS builds
* Windows Update services malfunction
* System image corruption

This project provides **Detection + Remediation scripts** designed to automatically identify Windows Update issues and apply corrective actions.

The solution is intended for **Microsoft Intune Proactive Remediations**.

---

# ✨ Core Features

### 🔹 Windows Update Health Detection

The detection script evaluates the update health of the device by checking:

* Windows OS build version
* Last installed update date
* Registry keys indicating paused updates
* Update delay conditions

If any issue is detected, the device is marked as **non-compliant**.

---

### 🔹 Automatic Update Repair

When issues are detected, the remediation script automatically performs several repair actions including:

* Running the **Windows Update Troubleshooter**
* Repairing system image using **DISM**
* Resetting Windows Update components
* Removing paused update registry keys
* Ensuring required PowerShell modules are installed
* Triggering Windows Update scan

---

# 📂 Project Structure

```
WindowsUpdateTroubleshooting
│
├── WindowsUpdateTroubleshooting--Detect.ps1
├── WindowsUpdateTroubleshooting--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
WindowsUpdateTroubleshooting--Detect.ps1
```

### Purpose

Detects issues that may prevent Windows Update from functioning properly.

### Checks Performed

The script checks:

* OS build version compliance
* Time since last Windows update
* Registry configuration related to update pauses

### Exit Codes

| Code | Status                        |
| ---- | ----------------------------- |
| 0    | No issues detected            |
| 1    | Windows Update issue detected |

---

# 🛠 Remediation Script

**File**

```powershell
WindowsUpdateTroubleshooting--Remediate.ps1
```

### Purpose

Attempts to automatically resolve Windows Update problems detected by the detection script.

### Repair Actions

The remediation script performs the following operations:

1. Run Windows Update troubleshooter
2. Repair Windows system image

```powershell
DISM /Online /Cleanup-Image /RestoreHealth
```

3. Reset Windows Update components
4. Remove paused update policies
5. Trigger update detection

---

# 📄 Logging

Logs are generated to help troubleshooting.

Default log locations:

```
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\#Windows_Updates_Health_Check.log
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\#DISM.log
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

PowerShell **5.1 or later**

### Permissions

Administrator privileges required.

When deployed through Intune, scripts typically run in **SYSTEM context**.

---

# 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```
WindowsUpdateTroubleshooting--Detect.ps1
```

### Remediation Script

```
WindowsUpdateTroubleshooting--Remediate.ps1
```

### Recommended Settings

| Setting                                | Value |
| -------------------------------------- | ----- |
| Run script in 64-bit PowerShell        | Yes   |
| Run script using logged-on credentials | No    |
| Enforce script signature check         | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Script checks Windows Update health
3. If issue detected → Exit Code **1**
4. Intune triggers **Remediation Script**
5. Script repairs Windows Update components
6. Device resumes normal update operation

---

# 🛡 Operational Notes

* Windows Update issues can prevent critical security patches from installing.
* Automated remediation ensures update health across managed devices.
* Always test remediation scripts on **pilot devices** before wide deployment.

---

## 📜 License

This project is licensed under the **MIT License**

https://opensource.org/licenses/MIT

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.1**

---

## ☕ Support

If this project helps you, consider supporting it:

https://www.buymeacoffee.com/mabdulkadrx

---

## ⚠ Disclaimer

This project is provided **as-is**.

- Always test scripts before production deployment.
- Validate restart policies and user experience.
- Ensure compatibility with your organization’s device management policies.
