# 🧪 Disable-LocalNetworkAccessRestrictions – Apply the Browser Flag for Local Network Access Checks

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Browser%20Configuration-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Disable-LocalNetworkAccessRestrictions** modifies Chrome and Edge `Local State` files so the `local-network-access-check` labs flag is present, then relaunches the browsers with a disable-features switch.

The detection script checks each browser's `Local State` JSON and validates whether `browser.enabled_labs_experiments` contains the required flag. The remediation script stops browser processes, backs up and edits the JSON files, supports both `@3` and `@2` flag variants, and relaunches the browsers with an additional runtime argument.

This package is a browser-profile configuration workflow and depends on the current user's local browser data.

---

# ✨ Core Features

### 🔹 Local State JSON Validation

The detection script checks these files:

* `%LOCALAPPDATA%\Google\Chrome\User Data\Local State`
* `%LOCALAPPDATA%\Microsoft\Edge\User Data\Local State`

It parses each file as JSON and looks for the required labs flag under `browser.enabled_labs_experiments`.

---

### 🔹 Browser Process Shutdown and File Backup

Before editing the JSON, the remediation script:

* Stops Chrome and Edge processes
* Waits for the `Local State` files to become writable
* Creates timestamped `.bak` backups

---

### 🔹 Flag Variant Support

The script supports two flag variants:

* `local-network-access-check@3`
* `local-network-access-check@2`

It can prefer one variant and fall back to the other if needed.

---

### 🔹 Browser Relaunch with Runtime Switch

After editing `Local State`, the script relaunches the browser with:

```text
--disable-features=LocalNetworkAccessChecks,LocalNetworkAccessCheck
```

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Disable-LocalNetworkAccessRestrictions
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Disable-LocalNetworkAccessRestrictions
│
├── Disable-LocalNetworkAccessRestrictions--Detect.ps1
├── Disable-LocalNetworkAccessRestrictions--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Disable-LocalNetworkAccessRestrictions--Detect.ps1
```

### Purpose

Checks whether Chrome and Edge both contain the required labs flag in their `Local State` files.

### Logic

1. Reads and parses each browser's `Local State` JSON
2. Checks whether `browser.enabled_labs_experiments` contains `local-network-access-check@3`
3. Returns success only when both browsers contain the flag

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Both Chrome and Edge contain the required flag |
| 1    | One or both browsers are missing the flag or detection failed |

### Example

```powershell
.\Disable-LocalNetworkAccessRestrictions--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Disable-LocalNetworkAccessRestrictions--Remediate.ps1
```

### Purpose

Adds the required labs flag to Chrome and Edge `Local State` files and relaunches the browsers with the related runtime switch.

### Actions

The script performs the following steps:

1. Stops Chrome and Edge processes
2. Waits for the `Local State` files to unlock
3. Creates backup copies of each file
4. Rewrites `browser.enabled_labs_experiments` to include the preferred or fallback flag variant
5. Relaunches the browser executable with the disable-features switch

### Example

```powershell
.\Disable-LocalNetworkAccessRestrictions--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* JSON parsing
* Browser `Local State` files
* Process management
* File backup and restore

### Permissions

* The package should run in the current user's context
* The script must be able to stop and relaunch the browser processes

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Disable-LocalNetworkAccessRestrictions--Detect.ps1
```

### Remediation Script

```powershell
Disable-LocalNetworkAccessRestrictions--Remediate.ps1
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
2. Detection checks the labs flag in Chrome and Edge `Local State`
3. If one or both browsers are missing the flag, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation edits the JSON files, creates backups, and relaunches the browsers

---

# 🛡 Operational Notes

* The package edits per-user browser profile files, not machine-wide browser policy.
* Active browser sessions are forcibly stopped during remediation.
* Backup files are created before each edit, which is useful operationally but should be considered in cleanup planning.

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
