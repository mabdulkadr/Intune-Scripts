# 🔔 Show-RebootToastNotification – Simple Restart Reminder Toast

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Reboot%20Toast-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Show-RebootToastNotification** is a very small package that displays a basic Windows toast asking the user to reboot.

The remediation script is straightforward: it uses `Windows.UI.Notifications.ToastNotificationManager` and the built-in `ToastText02` template to show a two-line message. The detection script, however, does not measure actual device uptime correctly. It compares the current time to the start time of the PowerShell process running the script, not to the system boot time.

In practice, that means the detection script almost always returns code `1`, so remediation is triggered on nearly every run.

---

# ✨ Core Features

### 🔹 Minimal Toast Notification

The remediation stage is intentionally lightweight:

* No registry app registration
* No custom image
* No action buttons
* Just a short toast generated through the Windows Runtime notification API

---

### 🔹 Detection Logic Uses Process Lifetime

The current detection script does **not** calculate reboot age from OS boot data:

* Reads the current Unix time
* Reads the start time of the current PowerShell process
* Converts the difference to hours
* Compares that to a 7-day threshold

Because the remediation process is short-lived, this detection is effectively always non-compliant.

---

### 🔹 Standardized Logging Path

Both scripts initialize the shared folder:

```text
<SystemDrive>\IntuneLogs\Show-RebootToastNotification
```

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Show-RebootToastNotification
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Show-RebootToastNotification
│
├── README.md
├── Show-RebootToastNotification--Detect.ps1
└── Show-RebootToastNotification--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Show-RebootToastNotification--Detect.ps1
```

### Purpose

Decides whether remediation should run, based on the lifetime of the current PowerShell process.

### Logic

1. Converts the current time to Unix seconds
2. Converts the current PowerShell process start time to Unix seconds
3. Calculates the runtime difference in hours
4. Compares that value to a 7-day threshold
5. Returns `1` when the process runtime is under 7 days

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Current PowerShell process has been running for more than 7 days |
| 1    | Current PowerShell process has been running for less than 7 days |

### Example

```powershell
.\Show-RebootToastNotification--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Show-RebootToastNotification--Remediate.ps1
```

### Purpose

Shows a simple toast telling the user to reboot the machine.

### Actions

1. Loads the Windows toast notification runtime types
2. Uses the `ToastText02` template
3. Displays the message:
   * `Please Restart your Machine`
   * `Your computer has been on for more than 7 days, please reboot when possible`

### Example

```powershell
.\Show-RebootToastNotification--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* An interactive user session is needed for the toast to be visible

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Show-RebootToastNotification--Detect.ps1
```

### Remediation Script

```powershell
Show-RebootToastNotification--Remediate.ps1
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
2. Detection compares current time to the start time of the current PowerShell process
3. Detection almost always exits with code **1**
4. Intune runs the **Remediation Script**
5. The user sees a basic reboot reminder toast

---

# 🛡 Operational Notes

* The detection script does not measure actual system uptime. If the goal is to notify based on real reboot age, the detection logic needs to be rewritten.
* The remediation script only shows a message. It does not schedule a restart or offer action buttons.
* Because the toast uses the default `PowerShell` notifier identity, the visual experience is simpler than the richer toast packages elsewhere in this repository.

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
