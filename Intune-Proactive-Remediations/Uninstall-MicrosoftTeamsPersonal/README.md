# 💬 Uninstall-MicrosoftTeamsPersonal – Remove the AppX Package Named MicrosoftTeams

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Teams%20AppX%20Removal-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Uninstall-MicrosoftTeamsPersonal** removes the AppX package named `MicrosoftTeams` from all users on the device.

The detection script checks for `Get-AppxPackage -Name MicrosoftTeams -AllUsers`. If the package exists, remediation runs and attempts to remove it with `Remove-AppxPackage`.

This package appears to target the Store/AppX variant of Teams rather than the classic MSI-based desktop client.

---

# ✨ Core Features

### 🔹 All-Users AppX Detection

Detection uses:

* `Get-AppxPackage -Name MicrosoftTeams -AllUsers`

That means the package is evaluated as a machine-wide AppX presence check rather than a per-user HKCU uninstall check.

---

### 🔹 AppX Removal Workflow

Remediation uses:

* `Get-AppxPackage -Name MicrosoftTeams -AllUsers | Remove-AppxPackage`

There is no extra cleanup for cached data, machine-wide installers, or Teams Meeting Add-in components.

---

### 🔹 Clear Intent

Unlike some other packages in the folder, this one does one thing only:

* Detect the `MicrosoftTeams` AppX package
* Remove it if found

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Uninstall-MicrosoftTeamsPersonal
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Uninstall-MicrosoftTeamsPersonal
│
├── README.md
├── Uninstall-MicrosoftTeamsPersonal--Detect.ps1
└── Uninstall-MicrosoftTeamsPersonal--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Uninstall-MicrosoftTeamsPersonal--Detect.ps1
```

### Purpose

Checks whether the `MicrosoftTeams` AppX package is still present.

### Logic

1. Runs `Get-AppxPackage -Name MicrosoftTeams -AllUsers`
2. Returns `0` when the package is not found
3. Returns `1` when the package exists

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | MicrosoftTeams AppX package not found |
| 1    | MicrosoftTeams AppX package found |

### Example

```powershell
.\Uninstall-MicrosoftTeamsPersonal--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Uninstall-MicrosoftTeamsPersonal--Remediate.ps1
```

### Purpose

Removes the AppX package named `MicrosoftTeams`.

### Actions

1. Gets the package with `Get-AppxPackage -Name MicrosoftTeams -AllUsers`
2. Pipes the result to `Remove-AppxPackage`
3. Writes a success or error message

### Example

```powershell
.\Uninstall-MicrosoftTeamsPersonal--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* The execution context must be able to remove the targeted AppX package

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Uninstall-MicrosoftTeamsPersonal--Detect.ps1
```

### Remediation Script

```powershell
Uninstall-MicrosoftTeamsPersonal--Remediate.ps1
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
2. Detection checks for `MicrosoftTeams` with `-AllUsers`
3. If the package is present, detection exits with code **1**
4. Intune runs the **Remediation Script**
5. Remediation attempts to remove the AppX package

---

# 🛡 Operational Notes

* The package targets the AppX form of Teams only. It does not remove the classic Teams machine-wide installer or other related components.
* The remediation script catches errors and writes a message, but it does not explicitly return a final non-zero exit code after the catch block.

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
