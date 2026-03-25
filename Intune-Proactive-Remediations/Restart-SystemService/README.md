# 🔁 Restart-SystemService – Template for Restarting a Windows Service

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Service%20Recovery-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Restart-SystemService** is a template package for checking and restarting a Windows service identified by the placeholder variable `$servicename = "ServiceName"`.

The detection script looks for the configured service and also checks whether it is running. The remediation script then runs `Restart-Service -Name $servicename -Force`.

As delivered, the package is not ready for production because the service name is still a placeholder and the detection logic is slightly loose: it treats the service as compliant when either the service exists or it is running, rather than requiring both conditions explicitly.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Restart-SystemService
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Restart-SystemService
│
├── README.md
├── Restart-SystemService--Detect.ps1
└── Restart-SystemService--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Restart-SystemService--Detect.ps1
```

### Purpose

Checks whether the configured service exists and whether it appears to be running.

### Logic

1. Reads the configured service by name
2. Increments an internal counter if the service exists
3. Increments the same counter if the service is running
4. Returns success when the counter is not zero

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | The script considers the service available/running |
| 1    | The service was not found or not considered healthy |

### Example

```powershell
.\Restart-SystemService--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Restart-SystemService--Remediate.ps1
```

### Purpose

Restarts the configured Windows service forcibly.

### Actions

1. Runs `Restart-Service -Name $servicename -Force`

### Example

```powershell
.\Restart-SystemService--Remediate.ps1
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

* Administrative rights may be required depending on the target service

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Restart-SystemService--Detect.ps1
```

### Remediation Script

```powershell
Restart-SystemService--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | No    |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Replace `ServiceName` with the real service name
2. Intune runs the **Detection Script**
3. If the script returns code **1**, Intune triggers the **Remediation Script**
4. The remediation script restarts the target service

---

# 🛡 Operational Notes

* The package is still a template until `ServiceName` is replaced.
* The current detection logic treats the service as compliant when the internal counter is non-zero, which means existence alone can satisfy the check.
* If you want stricter behavior, the detection script should require both presence and running state explicitly.

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
