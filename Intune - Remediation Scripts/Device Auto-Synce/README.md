
# 🔄 Intune AutoSync Repair

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Sync-Repair-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.1-green.svg)
---

# 📖 Overview

**Intune AutoSync Repair** is a PowerShell-based remediation solution designed to detect and repair Microsoft Intune device synchronization issues.

In some environments, devices may fail to sync with Intune for extended periods. This can lead to:

* Devices falling out of compliance
* Policies not being applied
* Applications not installing
* Security updates being delayed

This solution automatically detects devices that have not synchronized recently and forces an immediate sync using the **PushLaunch scheduled task**, which is part of the Windows MDM synchronization mechanism.

The solution is designed primarily for **Microsoft Intune Proactive Remediations**.

---

# ✨ Core Features

### 🔹 Sync Health Detection

The detection script checks the last execution time of the **PushLaunch scheduled task** used by the MDM sync engine.

It determines whether the device has synchronized with Intune within the last **48 hours**.

---

### 🔹 Automatic Sync Repair

If synchronization is overdue:

* The remediation script attempts to start the **PushLaunch task**
* If the task is missing, it recreates the task
* Forces the device to sync immediately with Intune

---

### 🔹 Enterprise Ready

Designed for:

**Microsoft Intune → Devices → Scripts and Remediations**

Provides:

* Detection logic
* Automatic remediation
* Compliance-based exit codes

---

### 🔹 Uses Native Windows MDM Mechanisms

The solution relies on the built-in Windows scheduled task:

```
PushLaunch
```

Which triggers the **Enterprise MDM Sync Engine**.

This ensures compatibility with the Windows MDM framework used by Intune.

---

# 📂 Project Structure

```
Intune-AutoSync-Repair
│
├── AutoSync--Detect.ps1
├── AutoSync--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```
AutoSync--Detect.ps1
```

### Purpose

Determines whether the device has recently synchronized with Intune.

### Logic

1. Locate the **PushLaunch scheduled task**
2. Retrieve the **LastRunTime**
3. Compare it with the current system time
4. Determine whether the device is overdue for synchronization

### Detection Result

| Result | Meaning          |
| ------ | ---------------- |
| Exit 0 | Sync is healthy  |
| Exit 1 | Sync is outdated |

### Example

```powershell
.\AutoSync--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```
AutoSync--Remediate.ps1
```

### Purpose

Forces an Intune synchronization when a device has not synced recently.

### Actions

The script performs the following operations:

1. Checks whether **PushLaunch** task exists
2. Starts the task to trigger sync
3. If the task does not exist:

   * Recreates the scheduled task
   * Starts it immediately

### Result

* Forces the device to sync with Intune
* Restores the MDM synchronization workflow

### Example

```powershell
.\AutoSync--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Administrator privileges required

### Device Enrollment

* Device must be enrolled in **Microsoft Intune / MDM**

---

# 🧭 Intune Deployment

Recommended deployment method:

**Intune Proactive Remediation**

### Detection Script

```
AutoSync--Detect.ps1
```

### Remediation Script

```
AutoSync--Remediate.ps1
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
2. Script checks the last MDM synchronization time
3. If last sync > 48 hours → device marked **Non-Compliant**
4. Intune triggers **Remediation Script**
5. Script starts **PushLaunch**
6. Device performs a forced Intune sync

---

# 🛡 Operational Notes

* The **PushLaunch task** is part of the Windows MDM sync framework.
* Devices should normally sync automatically every **8 hours**.
* If sync stops working, this remediation restores the mechanism.
* Always test scripts on **pilot devices** before broad deployment.

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.1**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.