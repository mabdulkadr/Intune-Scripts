# 🛡 Microsoft Defender Antivirus – Intune Security Policies

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Security](https://img.shields.io/badge/Endpoint-Security-green.svg)
![Defender](https://img.shields.io/badge/Microsoft-Defender-red.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

This repository contains **Microsoft Defender Antivirus configuration policies** exported from **Microsoft Intune using Microsoft Graph API**.

These policies implement enterprise endpoint protection standards using **Microsoft Defender Antivirus** and include:

* Antivirus protection configuration
* Windows Security Experience configuration
* Defender update management
* Multi-ring update deployment strategy

The configuration ensures **consistent and secure antivirus protection across managed Windows devices**.

The policies included in this repository define security controls such as **Tamper Protection, cloud protection, behavior monitoring, and staged Defender updates**. 

---

# ✨ Core Features

* Centralized **Defender Antivirus configuration**
* **Real-time protection enforcement**
* **Behavior monitoring enabled**
* **Cloud-delivered protection**
* **Tamper protection**
* **Security experience control**
* **Phased Defender update deployment**
* **Enterprise endpoint protection baseline**

---

# 📂 Project Structure

```
Defender-Antivirus-Policies
│
├── Win - Defender Antivirus - AV Configuration.json
├── Win - Defender Antivirus - Security Experience.json
│
├── Win - Defender Antivirus Updates - Ring 1 - Pilot.json
├── Win - Defender Antivirus Updates - Ring 2 - UAT.json
├── Win - Defender Antivirus Updates - Ring 3 - Production.json
│
└── README.md
```

---

# ⚙ Defender Antivirus Configuration

Policy File

```
Win - Defender Antivirus - AV Configuration.json
```

Policy Name

**Win - Defender Antivirus - AV Configuration**

This policy configures **Microsoft Defender Antivirus core protection features** and enforces antivirus security standards across Windows devices.

### Configured Settings

| Setting                      | Description                                         |
| ---------------------------- | --------------------------------------------------- |
| Real-time protection         | Enables continuous scanning of files and processes  |
| Behavior monitoring          | Detects suspicious system behavior                  |
| Cloud-delivered protection   | Uses Microsoft cloud intelligence to detect threats |
| Script scanning              | Scans PowerShell and script-based threats           |
| Scan archive files           | Detect malware inside compressed files              |
| Scan network files           | Detect threats on mapped drives                     |
| Scan removable drives        | Protect USB and external devices                    |
| CPU usage limit              | Controls CPU usage during antivirus scans           |
| Signature update before scan | Ensures latest definitions before running scans     |

These controls ensure **strong baseline antivirus protection across enterprise endpoints**.

---

# 🛡 Windows Security Experience Policy

Policy File

```
Win - Defender Antivirus - Security Experience.json
```

Policy Name

**Win - Defender Antivirus - Security Experience**

This policy manages the **Windows Security application interface and user interaction with Defender settings**.

The policy contains **4 configuration settings** controlling security interface behavior. 

### Configured Security Settings

| Setting                        | Description                                                 |
| ------------------------------ | ----------------------------------------------------------- |
| Tamper Protection              | Prevents unauthorized changes to Defender security settings |
| Disable Family UI              | Removes family safety options from Windows Security         |
| Disable Enhanced Notifications | Reduces non-critical Defender notifications                 |
| Security UI controls           | Limits user modification of Defender configuration          |

Tamper Protection requires:

* Microsoft Defender for Endpoint P1 or P2
* Defender for Business license

This policy protects **Defender security settings from local modification**.

---

# 🔄 Defender Antivirus Update Rings

Defender updates are deployed using a **three-ring update deployment strategy**.

This staged approach reduces the risk of unstable updates affecting production systems.

---

# 🧪 Ring 1 — Pilot

Policy File

```
Win - Defender Antivirus Updates - Ring 1 - Pilot.json
```

Policy Name

**Win - Defender Antivirus Updates - Ring 1 - Pilot**

Purpose:

Early validation of Defender updates on limited devices.

Configured Settings: **3 update channel settings**. 

| Setting                       | Value        |
| ----------------------------- | ------------ |
| Engine Updates Channel        | Insider Fast |
| Platform Updates Channel      | Insider Fast |
| Security Intelligence Updates | Immediate    |

Target Devices:

* IT test machines
* Security validation devices

---

# 🧪 Ring 2 — UAT

Policy File

```
Win - Defender Antivirus Updates - Ring 2 - UAT.json
```

Policy Name

**Win - Defender Antivirus Updates - Ring 2 - UAT**

Purpose:

User Acceptance Testing stage for Defender updates.

Configured Settings: **3 update configuration controls**. 

| Setting                       | Value  |
| ----------------------------- | ------ |
| Engine Updates Channel        | Staged |
| Platform Updates Channel      | Staged |
| Security Intelligence Updates | Staged |

Target Devices:

* UAT testing departments
* validation devices

---

# 🏢 Ring 3 — Production

Policy File

```
Win - Defender Antivirus Updates - Ring 3 - Production.json
```

Policy Name

**Win - Defender Antivirus Updates - Ring 3 - Production**

Purpose:

Enterprise-wide rollout of Defender updates.

Configured Settings: **3 update channels**. 

| Setting                       | Value |
| ----------------------------- | ----- |
| Engine Updates Channel        | Broad |
| Platform Updates Channel      | Broad |
| Security Intelligence Updates | Broad |

Target Devices:

* All production endpoints

---

# 🚀 Deployment via Microsoft Intune

### Step 1 — Import Policies

Policies can be imported using:

* Microsoft Graph API
* Intune automation scripts
* Configuration backup tools

---

### Step 2 — Configure in Intune Portal

Navigate to:

```
Microsoft Intune
Endpoint Security → Antivirus
```

Import or create configuration policies.

---

### Step 3 — Assign Policies

Recommended assignment model:

| Policy              | Assignment          |
| ------------------- | ------------------- |
| AV Configuration    | All Windows Devices |
| Security Experience | All Windows Devices |
| Update Ring 1       | Pilot Devices       |
| Update Ring 2       | UAT Devices         |
| Update Ring 3       | Production Devices  |

---

# 🧱 Enterprise Security Architecture

| Layer                   | Purpose                                  |
| ----------------------- | ---------------------------------------- |
| Antivirus Configuration | Core malware protection                  |
| Security Experience     | Prevent tampering with security controls |
| Update Rings            | Controlled Defender update rollout       |

This layered model improves **endpoint security resilience across enterprise environments**.

---

# ⚠ Operational Notes

* Requires **Microsoft Defender Antivirus**
* Works with **Microsoft Intune Endpoint Security policies**
* Tamper protection requires **Defender for Endpoint licensing**
* Always test update rings before production deployment
* Recommended staged deployment strategy

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.0**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These configurations are provided as-is. Always test security policies in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.

