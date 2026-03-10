
# 🔄 Windows Uptime Restart Notification

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![UI](https://img.shields.io/badge/UI-WPF-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

## 📖 Overview

**Windows Uptime Restart Notification** is a PowerShell solution designed to detect devices that require a restart and notify the user with a **custom WPF dialog window**.

In enterprise environments, many devices remain active for long periods without rebooting. This can lead to:

- Pending Windows updates not completing
- System performance degradation
- Security patches not being applied
- Configuration or policy changes not taking effect

This solution detects restart conditions and displays a **modern restart notification window** allowing users to restart immediately or schedule a restart.

The solution is designed to work with **Microsoft Intune Proactive Remediations**.

---

## 🖥 Screenshots

### Arabic UI
![Arabic UI](Screenshot(Ar).png)

### English UI
![English UI](Screenshot(En).png)

---

## ✨ Key Features

### 🔹 Restart Requirement Detection

The detection script checks whether the device requires a restart based on:

- Pending Windows Update reboot
- Pending component servicing reboot
- Device uptime exceeding the configured threshold

Registry locations checked:

```

HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending

```

Device uptime is calculated using:

```

Win32_OperatingSystem.LastBootUpTime

```

---

### 🔹 Interactive Restart Notification

When a restart condition is detected, a **custom WPF dialog** is displayed to the logged-in user.

Available actions:

- Restart Now
- Restart in 1 Hour
- Restart in 2 Hours
- Close Notification

The UI supports **both English and Arabic** versions.

---

## 📂 Project Structure

```

Windows-Uptime-Restart-Notification
│
├── WinUptimeRestartNotification--Detect.ps1
├── WinUptimeRestartNotification(En)--Remediate.ps1
├── WinUptimeRestartNotification(Ar)--Remediate.ps1
└── README.md

```

---

## 🚀 Scripts Included

### 🔎 Detection Script

**File**

```

WinUptimeRestartNotification--Detect.ps1

```

**Purpose**

Detects whether a system restart is required.

**Checks performed**

- Windows Update pending reboot
- Component servicing reboot pending
- Device uptime threshold

**Exit Codes**

| Code | Result |
|-----|------|
| 0 | Device compliant |
| 1 | Restart required |

---

### 🛠 Remediation Script

**Files**

```

WinUptimeRestartNotification(En)--Remediate.ps1
WinUptimeRestartNotification(Ar)--Remediate.ps1

```

**Purpose**

Displays the restart notification window to the logged-in user.

**Notification options**

- Restart Now
- Restart after 1 hour
- Restart after 2 hours
- Close

The dialog is implemented using **WPF** for a modern interface and supports branding customization.

---

## ⚙️ Configuration

Several parameters can be customized inside the scripts.

### Restart Threshold

```

$MaxUptimeDays = 14

```

Defines the maximum allowed uptime before prompting for restart.

Ensure the same value is used in **both detection and remediation scripts**.

---

### Optional Forced Restart

```

$ForceRestartWhenPending

```

When enabled, the device may be forced to restart after the configured grace period.

---

### Grace Period

```

$GraceSeconds

```

Defines how long the user has before a forced restart when enforcement mode is enabled.

---

## ⚙️ Requirements

### Operating System

- Windows 10
- Windows 11

### PowerShell

- Windows PowerShell **5.1 or later**

### Execution Context

The remediation script must run in **user context** because it displays a UI window.

---

## 🧭 Intune Deployment

Recommended deployment method:

**Microsoft Intune → Devices → Scripts and Remediations**

### Detection Script

```

WinUptimeRestartNotification--Detect.ps1

```

### Remediation Script

```

WinUptimeRestartNotification(En)--Remediate.ps1
or
WinUptimeRestartNotification(Ar)--Remediate.ps1

```

### Recommended Settings

| Setting | Value |
|------|------|
Run script using logged-on credentials | Yes |
Run script in 64-bit PowerShell | Yes |
Enforce script signature check | No |

---

## 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Device uptime and reboot status are evaluated
3. If restart is required → Exit Code **1**
4. Intune runs the **Remediation Script**
5. Restart notification window appears
6. User selects a restart option

---

## 🛡 Operational Notes

- The remediation window requires an **interactive user session**.
- Save scripts as **UTF-8 with BOM** to ensure Arabic text displays correctly in PowerShell 5.1.
- Test the solution in a **pilot group** before deploying broadly.

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

This project is provided **as-is**.

- Always test scripts before production deployment.
- Validate restart policies and user experience.
- Ensure compatibility with your organization’s device management policies.
