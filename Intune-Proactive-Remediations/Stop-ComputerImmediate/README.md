# 💽 Stop-ComputerImmediate – Prompt and Schedule a Forced Restart

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Restart%20Trigger-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Stop-ComputerImmediate** is an always-run remediation package that shows a short message box and then schedules a restart.

The detection script does not evaluate device health or state. It always exits with `1` so Intune runs the remediation script every time. The remediation script displays a basic .NET message box that announces the pending restart, then runs `shutdown /r /t 60 /d p:0:0`.

Despite the folder name, the script performs a **restart**, not a shutdown.

---

# ✨ Core Features

### 🔹 Always-Run Detection

The detection script deliberately exits with `1` on every run. This makes the package behave like a forced action rather than a conditional remediation.

---

### 🔹 Simple User Prompt

Before the restart is scheduled, remediation loads `PresentationCore` and `PresentationFramework` and displays a basic message box with the restart countdown.

---

### 🔹 Timed Restart

The remediation script schedules:

```text
shutdown /r /t 60 /d p:0:0
```

This gives the user a 60-second delay before the restart is executed.

---

### 🔹 Local Script Logging

The package writes log files under:

```text
<SystemDrive>\IntuneLogs\Stop-ComputerImmediate
```

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Stop-ComputerImmediate
* Records detection and remediation activity locally, including intentional always-run behavior where applicable

---

# 📂 Project Structure

```text
Stop-ComputerImmediate
│
├── README.md
├── Stop-ComputerImmediate--Detect.ps1
└── Stop-ComputerImmediate--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Stop-ComputerImmediate--Detect.ps1
```

### Purpose

Always triggers the remediation script.

### Logic

1. Writes a status message
2. Exits with code `1`

### Exit Codes

| Code | Status |
| ---- | ------ |
| 1    | Always trigger remediation |

### Example

```powershell
.\Stop-ComputerImmediate--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Stop-ComputerImmediate--Remediate.ps1
```

### Purpose

Shows a brief restart notice and then schedules a restart after 60 seconds.

### Actions

The script performs the following steps:

1. Loads the WPF-related .NET assemblies
2. Displays a message box with the text `Shutdown triggered in 60 seconds`
3. Runs `shutdown /r /t 60 /d p:0:0`

### Example

```powershell
.\Stop-ComputerImmediate--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to initiate a device restart
* An interactive user session if the message box should be visible

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Stop-ComputerImmediate--Detect.ps1
```

### Remediation Script

```powershell
Stop-ComputerImmediate--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | Yes, if the message box must be shown |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection exits with code **1**
3. Intune triggers the **Remediation Script**
4. The user sees the restart notice
5. The device is scheduled to restart after 60 seconds

---

# 🛡 Operational Notes

* The script name and folder name say `Shutdown`, but the actual command is a restart.
* This package does not check for active users, maintenance windows, or pending work.
* Because detection always triggers remediation, repeated assignments can result in repeated restart prompts.

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
