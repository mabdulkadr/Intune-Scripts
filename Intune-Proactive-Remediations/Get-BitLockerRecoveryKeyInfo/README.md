# 🔑 Get-BitLockerRecoveryKeyInfo – BitLocker Recovery Password Reporting

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-BitLocker%20Reporting-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Get-BitLockerRecoveryKeyInfo** is a reporting-focused Intune package that checks whether the system drive already has a BitLocker recovery password protector and prints that recovery password when it is available.

The detection script queries BitLocker on `C:` by using `Get-BitLockerVolume`, inspects the `KeyProtector` collection, and looks for a populated `RecoveryPassword` value. If a recovery password is present, the script returns success. If no recovery password is found, detection returns a non-zero code so remediation can run.

The remediation script does not create a new protector, rotate an existing key, or escrow anything to Entra ID, Active Directory, or MBAM. It simply re-queries BitLocker and outputs the current recovery password when the drive reports `EncryptionPercentage` as `100`.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Get-BitLockerRecoveryKeyInfo
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Get-BitLockerRecoveryKeyInfo
│
├── Get-BitLockerRecoveryKeyInfo--Detect.ps1
├── Get-BitLockerRecoveryKeyInfo--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Get-BitLockerRecoveryKeyInfoInfo--Detect.ps1
```

### Purpose

Checks whether the OS volume already exposes a BitLocker recovery password protector.

### Logic

1. Runs `Get-BitLockerVolume -MountPoint C`
2. Reads the returned `KeyProtector` data
3. Extracts the `RecoveryPassword` value
4. Returns success if a recovery password is present
5. Returns failure if no recovery password is available or the query fails

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Recovery password found |
| 1    | Recovery password missing or query failed |

### Example

```powershell
.\Get-BitLockerRecoveryKeyInfoInfo--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Get-BitLockerRecoveryKeyInfoInfo--Remediate.ps1
```

### Purpose

Re-queries BitLocker and prints the current recovery password when the drive is already fully encrypted.

### Actions

The script performs the following steps:

1. Calls `Get-BitLockerVolume`
2. Checks whether `EncryptionPercentage` equals `100`
3. Reads the recovery password from the key protector list
4. Outputs the recovery password if present

### Important Behavior

This script is not a true remediation in the usual Intune sense. It does not repair a missing recovery password. It only reports the current key when one already exists and the drive is fully encrypted.

### Example

```powershell
.\Get-BitLockerRecoveryKeyInfoInfo--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Dependencies

* BitLocker PowerShell module
* `Get-BitLockerVolume`

### Permissions

* Administrative rights are typically required to query BitLocker volume details reliably

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Get-BitLockerRecoveryKeyInfoInfo--Detect.ps1
```

### Remediation Script

```powershell
Get-BitLockerRecoveryKeyInfoInfo--Remediate.ps1
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
2. The script checks whether `C:` exposes a BitLocker recovery password
3. If the recovery password is missing, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation re-queries BitLocker and reports the current key if one is available on a fully encrypted volume

---

# 🛡 Operational Notes

* This package is best understood as a **reporting** workflow, not a full remediation workflow.
* Detection and remediation both assume the relevant protector is exposed through the BitLocker PowerShell cmdlets.
* The remediation script does not add missing recovery protectors.
* The current scripts only target the `C:` volume.
* If your goal is key escrow or protector creation, this package is incomplete on its own.

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
