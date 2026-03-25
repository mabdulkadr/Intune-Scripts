# 🔎 Restart-WindowsSearch – Restart the Windows Search Service

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Service%20Recovery-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Restart-WindowsSearch** checks the Windows Search service (`WSearch`) and restarts it when the package decides the service needs attention.

The detection script checks whether `WSearch` exists and whether it is running. The remediation script then runs `Restart-Service -Name WSearch -Force`.

The current detection logic is permissive: it returns success when either the service exists or it is running, because the internal counter only has to be non-zero. That means the compliance result is not as strict as the output text suggests.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Restart-WindowsSearch
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Restart-WindowsSearch
│
├── README.md
├── Restart-WindowsSearch--Detect.ps1
└── Restart-WindowsSearch--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Restart-WindowsSearch--Detect.ps1
```

### Purpose

Checks whether the Windows Search service exists and appears to be running.

### Logic

1. Reads the `WSearch` service
2. Increments an internal counter if the service exists
3. Increments the counter again if the service is running
4. Returns success when the counter is not zero

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | The script considers Windows Search available/running |
| 1    | Windows Search was not found or not considered healthy |

### Example

```powershell
.\Restart-WindowsSearch--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Restart-WindowsSearch--Remediate.ps1
```

### Purpose

Restarts the Windows Search service forcibly.

### Actions

1. Runs `Restart-Service -Name WSearch -Force`

### Example

```powershell
.\Restart-WindowsSearch--Remediate.ps1
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

* Administrative rights may be required to restart the Windows Search service

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Restart-WindowsSearch--Detect.ps1
```

### Remediation Script

```powershell
Restart-WindowsSearch--Remediate.ps1
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
2. Detection checks the `WSearch` service
3. If the script returns code **1**, Intune triggers the **Remediation Script**
4. Remediation restarts the Windows Search service

---

# 🛡 Operational Notes

* The current detection logic is not strict enough to guarantee that the service both exists and is running.
* If you want stricter enforcement, the detection script should require both conditions explicitly.

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
