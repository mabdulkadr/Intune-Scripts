# ☁️ Set-OneDriveFolderOfflineAvailability – Pin a OneDrive Folder for Offline Use

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-OneDrive%20Files%20On-Demand-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Set-OneDriveFolderOfflineAvailability** marks a selected OneDrive-synced folder as always available offline by changing the file attributes on the folder and its child items.

The package assumes a fixed OneDrive business path format:

```text
C:\Users\<UserName>\OneDrive - <CompanyName>\<FolderName>
```

Detection uses `attrib.exe` output to determine whether the folder currently has the expected pinned state. Remediation then applies `-U +P` attributes to the folder tree so the content stays available offline.

---

# ✨ Core Features

### 🔹 Fixed OneDrive Business Path

The scripts build the target folder from two configurable values:

* `$CompanyName`
* `$ODFolder`

By default the package targets:

* Company name: `scloud`
* Folder: `Desktop`

---

### 🔹 Attribute-Based Detection

Detection does not use the OneDrive client API:

* Calls `attrib.exe` against the target folder
* Removes spaces from the returned output
* Compares the result to an expected `RP` attribute pattern

---

### 🔹 Recursive Offline Pinning

Remediation applies offline availability to the folder tree:

* Runs `attrib.exe <path> -U +P /s /d` on the root
* Iterates child items recursively
* Applies `attrib.exe $_.FullName -U +P` to each item

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Set-OneDriveFolderOfflineAvailability
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Set-OneDriveFolderOfflineAvailability
│
├── README.md
├── Set-OneDriveFolderOfflineAvailability--Detect.ps1
└── Set-OneDriveFolderOfflineAvailability--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Set-OneDriveFolderOfflineAvailability--Detect.ps1
```

### Purpose

Checks whether the target OneDrive folder already appears to be pinned for offline use.

### Logic

1. Builds the OneDrive folder path from the configured company name and folder name
2. Runs `attrib.exe` against that path
3. Normalizes the output by removing spaces
4. Compares the returned attributes with the expected `RP` pattern
5. Returns `1` when the folder does not match the pinned state

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Folder already appears to be available offline |
| 1    | Folder does not match the expected offline-pinned state |

### Example

```powershell
.\Set-OneDriveFolderOfflineAvailability--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Set-OneDriveFolderOfflineAvailability--Remediate.ps1
```

### Purpose

Pins the selected OneDrive folder and its contents for offline use.

### Actions

1. Builds the OneDrive folder path for the current user
2. Applies `-U +P /s /d` to the root folder
3. Enumerates child items recursively
4. Applies `-U +P` to each child item

### Example

```powershell
.\Set-OneDriveFolderOfflineAvailability--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* The script must run in the user context that owns the OneDrive profile
* The target OneDrive business folder must already exist locally

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Set-OneDriveFolderOfflineAvailability--Detect.ps1
```

### Remediation Script

```powershell
Set-OneDriveFolderOfflineAvailability--Remediate.ps1
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
2. Detection checks the attribute state of the configured OneDrive folder
3. If the folder does not match the expected pinned state, detection exits with code **1**
4. Intune runs the **Remediation Script**
5. Remediation applies the offline-pinned attributes to the folder tree

---

# 🛡 Operational Notes

* The package relies on the exact `OneDrive - <CompanyName>` folder naming convention. If the tenant display name differs, the path will not resolve.
* Detection is based on `attrib.exe` string matching, which is a practical shortcut rather than a robust OneDrive API validation.
* This package is user-profile specific and is not suitable for pure system-context deployment.

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
