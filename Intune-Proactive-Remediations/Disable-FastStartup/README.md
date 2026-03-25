# ⚡ Disable-FastStartup – Fast Startup Registry Enforcement

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Fast%20Startup%20Disablement-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Disable-FastStartup** is an Intune remediation package that disables Windows Fast Startup by enforcing the `HiberbootEnabled` registry value.

The detection script reads `HiberbootEnabled` from the Session Manager Power key and checks whether it is already set to `0`. The remediation script writes the same value as a `DWORD`, which disables Fast Startup.

This package is useful in environments where Fast Startup interferes with reboot-dependent changes, dual-boot scenarios, or certain hardware and driver workflows.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Disable-FastStartup
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Disable-FastStartup
│
├── Disable-FastStartup--Detect.ps1
├── Disable-FastStartup--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Disable-FastStartup--Detect.ps1
```

### Purpose

Checks whether Fast Startup is already disabled in the local registry.

### Logic

1. Reads `HiberbootEnabled`
2. Compares the value to `0`
3. Returns exit code `0` only when Fast Startup is already disabled
4. Returns exit code `1` when the value is missing, different, or cannot be read

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Fast Startup is disabled |
| 1    | Fast Startup is enabled or detection failed |

### Key References

* Registry: `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power`
* Value: `HiberbootEnabled = 0`

### Example

```powershell
.\Disable-FastStartup--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Disable-FastStartup--Remediate.ps1
```

### Purpose

Disables Windows Fast Startup by setting `HiberbootEnabled` to `0`.

### Actions

1. Writes `HiberbootEnabled`
2. Uses `DWORD`
3. Forces the value to `0`

### Key References

* Registry: `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power`
* Value: `HiberbootEnabled = 0`

### Example

```powershell
.\Disable-FastStartup--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to read and write the target `HKLM` registry key

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Disable-FastStartup`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Disable-FastStartup--Detect.ps1
```

### Remediation Script

```powershell
Disable-FastStartup--Remediate.ps1
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
2. Detection checks `HiberbootEnabled`
3. If the value is not `0`, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation writes the required registry value

---

# 🛡 Operational Notes

* The current script files still contain duplicated generated sections, but the effective logic is the registry check and write described above
* A restart may be needed before users fully notice the behavior change in startup/shutdown flow
* Test on pilot devices before broad rollout, especially where Fast Startup is intentionally used

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
