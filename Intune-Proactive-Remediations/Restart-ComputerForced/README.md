# 💽 Restart-ComputerForced – Pending Reboot Detection and Forced Restart Workflow

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Forced%20Restart-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Restart-ComputerForced** is an Intune remediation package that detects whether Windows is waiting for a reboot and then forces a restart when the condition is present.

The detection script checks several common pending reboot indicators in the registry and writes the result to `C:\Intune\RestartStatus.txt`. The main remediation script reads that status file, shows warning balloon notifications to the signed-in user, waits for the configured delay, and then forces a restart. A second remediation script is also included for cases where an immediate restart is required with no warning period.

This folder is useful when Intune needs to enforce a reboot after updates, servicing, or other system changes that leave the device in a pending restart state.

---

# ✨ Core Features

### 🔹 Pending Reboot Detection

* Checks common reboot-required registry indicators under `HKLM`
* Writes the detection result to `C:\Intune\RestartStatus.txt`
* Returns exit code `1` when a restart is required

### 🔹 Delayed Forced Restart

* Reads the status file created by detection
* Warns the user with `System.Windows.Forms.NotifyIcon` balloon messages
* Waits for the configured delay and then forces a restart

### 🔹 Immediate Restart Option

* Includes a separate script for immediate restart
* Does not wait for the status file
* Does not display a user warning period

### 🔹 Intune Proactive Remediation Ready

* Detection and restart actions are separated into dedicated scripts
* Exit codes control when remediation runs
* The delayed and immediate restart paths are both available in the same package

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Restart-ComputerForced
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Restart-ComputerForced
│
├── README.md
├── Restart-ComputerForced--Detect.ps1
├── Restart-ComputerForcedNow--Remediate.ps1
└── Restart-ComputerForced--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Restart-ComputerForced--Detect.ps1
```

### Purpose

Detects whether Windows is waiting for a restart by checking common pending reboot indicators.

### Logic

1. Creates `C:\Intune` if it does not already exist
2. Checks `WindowsUpdate\Auto Update\RebootRequired`
3. Checks `PendingFileRenameOperations`
4. Checks the configured computer name registry path used by the script as an additional reboot signal
5. Checks `Component Based Servicing\RebootPending`
6. Writes either `Restart required` or `No restart required` to `C:\Intune\RestartStatus.txt`

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | No restart required |
| 1    | Restart required |

### Example

```powershell
.\Restart-ComputerForced--Detect.ps1
```

---

## 🛠️ Remediation Script

**File**

```powershell
Restart-ComputerForced--Remediate.ps1
```

### Purpose

Warns the user, waits for the configured delay, and then forces a restart when the detection script has already marked the device as requiring one.

### Actions

1. Creates `C:\Intune` if needed
2. Reads `C:\Intune\RestartStatus.txt`
3. Stops with an error if the status file is missing
4. Shows an initial restart warning by using `System.Windows.Forms.NotifyIcon`
5. Waits for the configured delay, which defaults to `1800` seconds
6. Shows a final one-minute warning
7. Forces the restart with `Restart-Computer -Force`

### Key References

* Registry: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired`
* Registry: `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager`
* Registry: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending`
* Path: `C:\Intune\RestartStatus.txt`

### Example

```powershell
.\Restart-ComputerForced--Remediate.ps1
```

---

## 🛠️ Remediation Script

**File**

```powershell
Restart-ComputerForced--Remediate.ps1
```

### Purpose

Forces an immediate restart without a delay, without a status-file check, and without user-facing warning logic.

### Actions

1. Writes a status message to the console
2. Runs `Restart-Computer -Force -Confirm:$false`
3. Returns exit code `1` only if the restart attempt throws an error

### Example

```powershell
.\Restart-ComputerForced--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to read the required `HKLM` reboot indicators
* Permission to create `C:\Intune`
* Rights to restart the local computer

### Runtime Notes

* Balloon notifications are meaningful only when an interactive user session is available
* The delayed remediation script depends on the detection status file being created first

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Restart-ComputerForced--Detect.ps1
```

### Remediation Script

```powershell
Restart-ComputerForced--Remediate.ps1
```

### Additional Script

```powershell
Restart-ComputerForced--Remediate.ps1
```

Use the immediate restart script only when a forced reboot with no grace period is acceptable.

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | Yes, if user warnings must be visible |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. The script checks the pending reboot registry indicators
3. Detection writes the result to `C:\Intune\RestartStatus.txt`
4. If a restart is required, detection exits with code `1`
5. Intune runs the delayed **Remediation Script**
6. The user receives warning notifications
7. The device is restarted forcibly after the configured delay

---

# 🛡️ Operational Notes

* The delayed remediation path depends on `C:\Intune\RestartStatus.txt`
* The immediate restart script bypasses the delay and status file completely
* Notifications are implemented with Windows Forms balloon tips, not native toast notifications
* The computer-name registry check used by detection is broader than a strict rename comparison and may report restart-required state more aggressively than some environments expect
* Test this workflow carefully on pilot devices before assigning it broadly

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
