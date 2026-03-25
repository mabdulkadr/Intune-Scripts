# 🧩 Invoke-GPUpdate – Forced Group Policy Refresh

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Group%20Policy%20Refresh-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Invoke-GPUpdate** is a simple Intune remediation package that exists for one purpose: force a `gpupdate /force` run whenever the package executes.

The detection script is intentionally not a real state check. It always exits with code `1`, which guarantees that Intune will invoke the remediation script every time the package runs. The remediation script then launches `gpupdate /force` and reports success or failure based on the command result.

This is a practical package for cases where the goal is to run a policy refresh on demand rather than detect a meaningful compliance state.

---

# ✨ Core Features

### 🔹 Intentional Always-Run Detection

* Detection is a deliberate trigger, not a state evaluation
* Always returns exit code `1`
* Ensures remediation runs every time Intune executes the package

### 🔹 Direct Group Policy Refresh

* Runs `gpupdate /force`
* Uses a simple try/catch wrapper
* Returns a success or failure result directly from the refresh attempt

### 🔹 Minimal Operational Footprint

* No registry changes
* No scheduled tasks
* No custom state tracking between runs

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Invoke-GPUpdate
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Invoke-GPUpdate
│
├── Invoke-GPUpdate--Detect.ps1
├── Invoke-GPUpdate--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Invoke-GPUpdate--Detect.ps1
```

### Purpose

Always returns a non-zero result so the remediation script runs on every execution.

### Logic

1. Writes a message indicating that a Group Policy update is needed
2. Exits with code `1`
3. Does not inspect device state, policy state, or registry data

### Exit Codes

| Code | Status |
| ---- | ------ |
| 1    | Always trigger remediation |

### Example

```powershell
.\Invoke-GPUpdate--Detect.ps1
```

---

## 🛠️ Remediation Script

**File**

```powershell
Invoke-GPUpdate--Remediate.ps1
```

### Purpose

Forces a Group Policy refresh on the local device.

### Actions

1. Writes a status message to the console
2. Runs `gpupdate /force`
3. Returns exit code `0` on success
4. Returns exit code `1` if the refresh attempt throws an error

### Key References

* Command: `gpupdate /force`

### Example

```powershell
.\Invoke-GPUpdate--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to run `gpupdate`
* Execution context that can refresh the relevant machine or user policy scope

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Invoke-GPUpdate--Detect.ps1
```

### Remediation Script

```powershell
Invoke-GPUpdate--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | Review script context |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection immediately exits with code `1`
3. Intune runs the **Remediation Script**
4. Remediation executes `gpupdate /force`
5. The run succeeds or fails based on the policy refresh command result

---

# 🛡️ Operational Notes

* This package does not represent a true detection/remediation model; it is effectively a scheduled policy refresh wrapper
* Because detection always triggers remediation, the execution frequency is controlled entirely by the Intune schedule
* Use this package only where a repeated `gpupdate /force` is operationally acceptable
* Test the impact on pilot devices before assigning it broadly

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
