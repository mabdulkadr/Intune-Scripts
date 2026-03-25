# ⏱️ Get-DeviceUptimeStatus – Detect Long Uptime and Prompt for Restart

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Uptime%20Notification-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Get-DeviceUptimeStatus** checks how long the device has been running since the last reboot and shows a user-facing Windows toast notification when uptime reaches seven days or more.

The detection script uses `Get-ComputerInfo` and reads `OSUptime`. If the uptime is at least seven days, detection exits with code `1`. The remediation script then downloads branding images from GitHub, registers PowerShell in the current user's notification settings if needed, builds a toast XML payload, and shows a reminder notification asking the user to restart.

This package does not restart the machine automatically. It is a notification workflow, not a forced reboot package.

---

# ✨ Core Features

### 🔹 Uptime Threshold Check

Detection reads:

```powershell
Get-ComputerInfo | Select-Object OSUptime
```

It flags the device only when `OSUptime.Days` is greater than or equal to `7`.

---

### 🔹 User-Facing Toast Reminder

The remediation script displays a Windows toast notification that tells the user the device has not been rebooted recently and recommends a restart for stability and performance reasons.

---

### 🔹 Branded Notification Assets

The script downloads two remote images into the current user's temp folder:

* `ToastLogoImage.png`
* `ToastHeroImage.png`

These are used in the toast payload shown to the user.

---

### 🔹 HKCU Notification Registration

Before showing the toast, the remediation script creates or updates:

```text
HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings
```

for the PowerShell AppID used by the notification.

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Get-DeviceUptimeStatus
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Get-DeviceUptimeStatus
│
├── Get-DeviceUptimeStatus--Detect.ps1
├── Get-DeviceUptimeStatus--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Get-DeviceUptimeStatus--Detect.ps1
```

### Purpose

Checks whether the device has been running for seven days or more without a reboot.

### Logic

1. Reads `OSUptime` from `Get-ComputerInfo`
2. Extracts the number of uptime days
3. Returns exit code `1` when uptime is at least seven days
4. Returns exit code `0` when uptime is below seven days

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Device uptime is below 7 days |
| 1    | Device uptime is 7 days or more |

### Example

```powershell
.\Get-DeviceUptimeStatus--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Get-DeviceUptimeStatus--Remediate.ps1
```

### Purpose

Shows a branded toast notification asking the current user to restart the device.

### Actions

The script performs the following steps:

1. Downloads two branding images with `Invoke-WebRequest`
2. Ensures the PowerShell notification AppID is present under the current user's notification settings
3. Builds a `ToastGeneric` XML payload
4. Uses Windows Runtime toast APIs to display the notification

### Example

```powershell
.\Get-DeviceUptimeStatus--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* `Get-ComputerInfo`
* `Invoke-WebRequest`
* Windows toast notification APIs
* `HKCU` notification registration

### Permissions

* The remediation script is designed for an interactive logged-on user session
* Network access is required to download the remote images

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Get-DeviceUptimeStatus--Detect.ps1
```

### Remediation Script

```powershell
Get-DeviceUptimeStatus--Remediate.ps1
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
2. Detection checks `OSUptime.Days`
3. If uptime is at least seven days, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation downloads notification assets and displays a toast reminder to the user

---

# 🛡 Operational Notes

* This package notifies the user but does not reboot the device.
* The remediation script depends on internet access to fetch the branding images from GitHub.
* The notification logic is built for user context and is not useful in a non-interactive system session.
* The current script references a dismiss button content variable that is not explicitly initialized in the visible logic, so notification rendering should be validated before production rollout.

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
