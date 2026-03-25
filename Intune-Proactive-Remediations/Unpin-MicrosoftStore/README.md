# 📌 Unpin-MicrosoftStore – Remove Microsoft Store from the Taskbar

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Taskbar%20Cleanup-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Unpin-MicrosoftStore** checks whether **Microsoft Store** is pinned to the Windows taskbar and removes it when the unpin verb is available.

The package uses the `Shell.Application` COM object and the special AppsFolder namespace rather than editing a documented taskbar layout file or registry policy. Detection looks for the **Unpin from taskbar** verb on the Microsoft Store shell item. Remediation then invokes that same shell verb.

This approach is lightweight, but it depends heavily on the localized shell verb text exposed by the operating system.

---

# ✨ Core Features

### 🔹 COM-Based Taskbar Inspection

Detection uses the shell namespace:

* `shell:::{4234d49b-0245-4df3-b780-3893943456e1}`
* `Shell.Application`
* Verbs exposed by the Microsoft Store app item

---

### 🔹 Unpin via Shell Verb

Remediation does not hard-code taskbar layout files:

* Resolves the Store app item in the AppsFolder
* Finds the `Unpin from taskbar` verb
* Calls `.DoIt()` on the matching verb

---

### 🔹 Standardized Logging Path

Both scripts initialize:

```text
<SystemDrive>\IntuneLogs\Unpin-MicrosoftStore
```

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Unpin-MicrosoftStore
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Unpin-MicrosoftStore
│
├── README.md
├── Unpin-MicrosoftStore--Detect.ps1
└── Unpin-MicrosoftStore--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Unpin-MicrosoftStore--Detect.ps1
```

### Purpose

Checks whether Microsoft Store still exposes an **Unpin from taskbar** action.

### Logic

1. Opens the AppsFolder shell namespace through `Shell.Application`
2. Locates the app item named `Microsoft Store`
3. Enumerates its verbs
4. Returns `1` when the `Unpin from taskbar` verb is present
5. Returns `0` when the unpin verb is not found

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Store is not detected as pinned |
| 1    | Store appears to be pinned and can be unpinned |

### Example

```powershell
.\Unpin-MicrosoftStore--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Unpin-MicrosoftStore--Remediate.ps1
```

### Purpose

Invokes the shell verb that removes Microsoft Store from the taskbar.

### Actions

1. Enumerates AppsFolder items through `Shell.Application`
2. Resolves the app whose name matches `*store*`
3. Finds the `Unpin from taskbar` verb
4. Executes that verb with `.DoIt()`

### Example

```powershell
.\Unpin-MicrosoftStore--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* The script must run in a user context where the taskbar shell verbs are available

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Unpin-MicrosoftStore--Detect.ps1
```

### Remediation Script

```powershell
Unpin-MicrosoftStore--Remediate.ps1
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
2. Detection inspects the Microsoft Store shell verbs
3. If the unpin verb is present, detection exits with code **1**
4. Intune runs the **Remediation Script**
5. Remediation invokes the unpin verb for the Store app

---

# 🛡 Operational Notes

* Detection depends on exact shell verb text. Localized Windows builds can expose a different string and break the check.
* The remediation script matches `*store*`, so it is intentionally broad when locating the final app item.
* This package manipulates the current user's shell experience. It is not a device-wide taskbar policy.

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
