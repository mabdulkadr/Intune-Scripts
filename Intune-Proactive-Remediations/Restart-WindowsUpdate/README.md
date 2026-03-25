# 🔄 Restart-WindowsUpdate – Restart the Windows Update Service

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Service%20Recovery-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Restart-WindowsUpdate** checks the Windows Update service (`wuauserv`) and restarts it when the package decides remediation is needed.

The detection script checks whether `wuauserv` exists and whether it is running. The remediation script then runs `Restart-Service -Name wuauserv -Force`.

Like the other service-restart packages in this library, the current detection logic is permissive and can return success even when only one of its conditions is met.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Restart-WindowsUpdate
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Restart-WindowsUpdate
│
├── README.md
├── Restart-WindowsUpdate--Detect.ps1
└── Restart-WindowsUpdate--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Restart-WindowsUpdate--Detect.ps1
```

### Purpose

Checks whether the Windows Update service exists and appears to be running.

### Logic

1. Reads the `wuauserv` service
2. Increments an internal counter if the service exists
3. Increments the counter again if the service is running
4. Returns success when the counter is not zero

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | The script considers Windows Update service available/running |
| 1    | Windows Update service was not found or not considered healthy |

### Example

```powershell
.\Restart-WindowsUpdate--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Restart-WindowsUpdate--Remediate.ps1
```

### Purpose

Restarts the Windows Update service forcibly.

### Actions

1. Runs `Restart-Service -Name wuauserv -Force`

### Example

```powershell
.\Restart-WindowsUpdate--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Technologies Used

* `Get-Service`
* `Restart-Service`

### Permissions

* Administrative rights may be required to restart the Windows Update service

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Restart-WindowsUpdate--Detect.ps1
```

### Remediation Script

```powershell
Restart-WindowsUpdate--Remediate.ps1
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
2. Detection checks the `wuauserv` service
3. If the script returns code **1**, Intune triggers the **Remediation Script**
4. Remediation restarts the Windows Update service

---

# 🛡 Operational Notes

* The current detection logic is permissive and should be reviewed if you need stricter service-state validation.
* Restarting `wuauserv` can interrupt ongoing Windows Update activity if used at the wrong time.

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
