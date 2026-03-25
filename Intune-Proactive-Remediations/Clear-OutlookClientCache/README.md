# 📧 Clear-OutlookClientCache – Outlook Autocomplete Cache Reset

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Outlook%20Cache%20Reset-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Clear-OutlookClientCache** is an Intune remediation package that launches Outlook with switches intended to clear the autocomplete cache and recycle the Outlook session.

The detection script is very simple: it checks whether Outlook exists at this fixed path:

```text
C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE
```

If that executable is present, detection exits with code `1` so remediation can run. The remediation script then starts Outlook with:

```text
/cleanautocompletecache /recycle
```

This package is useful when the goal is to reset Outlook nickname cache behavior without rebuilding the full user profile.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Clear-OutlookClientCache
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Clear-OutlookClientCache
│
├── Clear-OutlookClientCache--Detect.ps1
├── Clear-OutlookClientCache--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Clear-OutlookClientCache--Detect.ps1
```

### Purpose

Checks whether Outlook is installed in the hard-coded Office 16 path used by this package.

### Logic

1. Checks for `C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE`
2. Returns `1` if the executable exists
3. Returns `0` if the executable is not found

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Outlook was not found at the configured path |
| 1    | Outlook was found and remediation should run |

### Key References

* Path: `C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE`

### Example

```powershell
.\Clear-OutlookClientCache--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Clear-OutlookClientCache--Remediate.ps1
```

### Purpose

Starts Outlook with switches that clear the autocomplete cache and recycle the Outlook session.

### Actions

1. Initializes logging
2. Starts `OUTLOOK.EXE`
3. Passes `/cleanautocompletecache` and `/recycle`

### Key References

* Path: `C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE`
* Arguments: `/cleanautocompletecache`, `/recycle`

### Example

```powershell
.\Clear-OutlookClientCache--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Outlook must exist at the path hard-coded in the script
* The execution context must be able to launch Outlook interactively if user impact matters

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Clear-OutlookClientCache`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Clear-OutlookClientCache--Detect.ps1
```

### Remediation Script

```powershell
Clear-OutlookClientCache--Remediate.ps1
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
2. Detection checks whether Outlook exists at the configured path
3. If Outlook is found, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation starts Outlook with cache-reset arguments

---

# 🛡 Operational Notes

* This package only supports the exact Outlook installation path defined in the script
* Detection does not verify that the autocomplete cache is actually unhealthy
* Remediation starts Outlook, which is user-visible behavior
* Test on pilot devices before broad rollout, especially where Office is installed in a different path or architecture

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
