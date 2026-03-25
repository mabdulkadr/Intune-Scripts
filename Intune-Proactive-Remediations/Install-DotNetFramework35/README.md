# 🧩 Install-DotNetFramework35 – .NET Framework 3.5 Feature Enablement

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-.NET%203.5%20Enablement-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Install-DotNetFramework35** is a small Intune remediation package for devices that still need the legacy **NetFx3** Windows optional feature.

The detection script checks the local feature state with `Get-WindowsOptionalFeature -Online -FeatureName NetFx3` and returns non-compliant when the feature is disabled. The remediation script then enables the same feature with `Enable-WindowsOptionalFeature`.

Both scripts also initialize the standard logging path under `<SystemDrive>\IntuneLogs\Install-DotNetFramework35`, while the detection script additionally starts a transcript in `%TEMP%\NetFx3.log`.

---

# ✨ Core Features

### 🔹 Native Windows Feature Detection

The detection script uses the built-in optional feature engine rather than checking files or registry markers:

* Queries `NetFx3` directly from the online Windows image
* Treats `Enabled` as the success state
* Returns exit code `1` when the feature is still disabled

---

### 🔹 Direct NetFx3 Remediation

When remediation runs, the script enables **.NET Framework 3.5** on the local operating system:

* Uses `Enable-WindowsOptionalFeature -Online -FeatureName NetFx3`
* Writes a simple status message to output
* Returns exit code `0` only when the enable action succeeds

---

### 🔹 Intune-Friendly Execution

This package fits the standard Intune remediation pattern:

* One detection script
* One remediation script
* Exit-code based handoff between both stages

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Install-DotNetFramework35
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Install-DotNetFramework35
│
├── Install-DotNetFramework35--Detect.ps1
├── Install-DotNetFramework35--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Install-DotNetFramework35--Detect.ps1
```

### Purpose

Checks whether the Windows **NetFx3** optional feature is already enabled.

### Logic

1. Starts a transcript in `%TEMP%\NetFx3.log`
2. Reads the current state of `NetFx3` from the online OS image
3. Returns `0` when the feature state is `Enabled`
4. Returns `1` when the feature is not enabled

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | NetFx3 is enabled |
| 1    | NetFx3 is disabled |

### Example

```powershell
.\Install-DotNetFramework35--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Install-DotNetFramework35--Remediate.ps1
```

### Purpose

Enables **.NET Framework 3.5** on the device.

### Actions

1. Calls `Enable-WindowsOptionalFeature -Online -FeatureName NetFx3`
2. Writes a confirmation message if the command completes
3. Returns `1` if PowerShell throws an exception during feature enablement

### Example

```powershell
.\Install-DotNetFramework35--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Administrative rights are required to enable Windows optional features
* The device must support local servicing of the `NetFx3` feature

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Install-DotNetFramework35--Detect.ps1
```

### Remediation Script

```powershell
Install-DotNetFramework35--Remediate.ps1
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
2. The script checks the `NetFx3` feature state
3. If the feature is disabled, detection exits with code **1**
4. Intune runs the **Remediation Script**
5. The remediation script enables the feature on the local OS image

---

# 🛡 Operational Notes

* The detection script starts a transcript in `%TEMP%\NetFx3.log`, but the remediation script does not.
* The remediation script does not provide a local installation source, so success still depends on the servicing configuration available on the device.
* Test on pilot devices first, especially on networks where optional feature payload retrieval is restricted.

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
