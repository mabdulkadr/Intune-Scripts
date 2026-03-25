# 🩺 Repair-WindowsComponentStore – Component Store and File Integrity Repair

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-System%20Health%20Repair-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Repair-WindowsComponentStore** is an Intune remediation package that looks for signs of component store or system file health issues, then runs the standard Windows repair sequence to correct them.

The detection script checks for a pending reboot and runs `DISM /Online /Cleanup-Image /CheckHealth`. If a reboot is already pending, `DISM` returns a non-zero exit code, or the output suggests repairable corruption, the device is marked for remediation.

The remediation script runs `DISM /RestoreHealth`, follows it with `SFC /scannow`, and then checks again for a pending reboot. If repairs complete but Windows still requires a restart, the script exits with code `3010` so the result reflects that additional step.

This package is useful when you want Intune to drive a standard Windows servicing repair workflow without manually touching `DISM` and `SFC` on each device.

---

# ✨ Core Features

### 🔹 Reboot-Pending Awareness

* Checks common reboot-pending registry locations before and after repair
* Treats an existing pending reboot as a signal that system health work is not fully settled
* Surfaces reboot-required state explicitly

### 🔹 DISM Health Inspection

* Runs `DISM /CheckHealth` during detection
* Looks at both exit code and output text
* Flags devices where the component store appears repairable or unhealthy

### 🔹 Standard Repair Sequence

* Runs `DISM /RestoreHealth`
* Runs `SFC /scannow` afterward
* Stops with failure if `SFC` reports files it could not repair

### 🔹 Reboot-Aware Remediation Result

* Returns `0` when repairs complete and no reboot is pending
* Returns `3010` when repairs finish but reboot is still required
* Returns `1` when repair steps fail

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Repair-WindowsComponentStore
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Repair-WindowsComponentStore
│
├── README.md
├── Repair-WindowsComponentStore--Detect.ps1
└── Repair-WindowsComponentStore--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Repair-WindowsComponentStore--Detect.ps1
```

### Purpose

Checks for reboot-pending state and signs of repairable component store corruption.

### Logic

1. Checks common reboot-pending registry keys
2. Runs `dism.exe /Online /Cleanup-Image /CheckHealth`
3. Reviews the DISM exit code
4. Searches the DISM output for strings such as `repairable` or `component store corruption`
5. Returns exit code `1` when any of those checks indicate remediation is needed

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | No reboot-pending state or DISM health issue was detected |
| 1    | Reboot is pending, DISM reported an issue, or detection failed |

### Key References

* Command: `dism.exe /Online /Cleanup-Image /CheckHealth`
* Registry: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending`
* Registry: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired`

### Example

```powershell
.\Repair-WindowsComponentStore--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Repair-WindowsComponentStore--Remediate.ps1
```

### Purpose

Repairs component store corruption and system file integrity issues by running `DISM` followed by `SFC`.

### Actions

1. Records whether a reboot was already pending before repair
2. Runs `dism.exe /Online /Cleanup-Image /RestoreHealth`
3. Runs `sfc.exe /scannow`
4. Interprets common `SFC` output strings to determine success or failure
5. Checks reboot-pending state again after repair
6. Returns `3010` when a reboot is required to finalize repairs

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | DISM and SFC completed successfully and no reboot is pending |
| 1    | One of the repair steps failed |
| 3010 | Repairs completed but a reboot is required |

### Key References

* Command: `dism.exe /Online /Cleanup-Image /RestoreHealth`
* Command: `sfc.exe /scannow`

### Example

```powershell
.\Repair-WindowsComponentStore--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* The scripts are intended to run as `System`
* Permission to run `DISM` and `SFC`

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Repair-WindowsComponentStore`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Repair-WindowsComponentStore--Detect.ps1
```

### Remediation Script

```powershell
Repair-WindowsComponentStore--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | No    |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection checks reboot-pending state and runs `DISM /CheckHealth`
3. If repair appears necessary, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation runs `DISM /RestoreHealth` and `SFC /scannow`
6. The script returns `3010` if a reboot is required after the repair sequence

---

# 🛡 Operational Notes

* Detection uses a best-effort string match against DISM output in addition to the process exit code
* The remediation script treats `SFC` output that says files could not be repaired as a hard failure
* A reboot pending before the repair begins is enough to produce a final `3010` result if that condition remains relevant
* Review repair impact on pilot devices before wide deployment, especially on machines with servicing stack or source issues

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
