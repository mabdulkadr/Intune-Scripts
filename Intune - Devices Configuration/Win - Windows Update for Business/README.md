
# 📊 Windows Update for Business – Intune Policies

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Windows Update](https://img.shields.io/badge/Windows%20Update-Business-green.svg)
![Deployment Model](https://img.shields.io/badge/Deployment-Rings-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

This repository contains **Microsoft Intune configuration policies for Windows Update for Business (WUfB)** exported through **Microsoft Graph API**.

These policies implement a **phased Windows update deployment model** designed for enterprise environments to control how Windows updates are delivered, validated, and deployed across managed devices.

The policies define configuration standards for:

- Windows Update deployment rings  
- Update compliance and telemetry reporting  
- Delivery Optimization bandwidth management  
- Update installation deadlines and restart behavior  

This configuration ensures Windows devices receive updates in a **controlled, secure, and validated rollout process**.

---

# ✨ Core Features

- Phased Windows update rollout strategy  
- Enterprise Windows Update ring architecture  
- Delivery Optimization bandwidth management  
- Update compliance reporting configuration  
- Restart deadline enforcement  
- Rollback protection for feature updates  
- Microsoft Intune MDM policy deployment  

---

# 📂 Project Structure

```

Windows-Update-WUfB-Policies
│
├── Win - WUfB - Delivery Optimization.json
├── Win - WUfB - Reports and Telemetry.json
│
├── Win - WUfB - Ring 1 - Pilot.json
├── Win - WUfB - Ring 2 - UAT.json
├── Win - WUfB - Ring 3 - Production.json
│
└── README.md

```

---

# ⚙ Windows Update Deployment Architecture

These policies follow the **Enterprise Windows Update Ring Model**.

```

Microsoft Update Release
│
▼
Pilot Ring
│
▼
UAT Ring
│
▼
Production Ring

```

This layered deployment model enables administrators to:

- Detect update issues early
- Validate patches before enterprise rollout
- Reduce update-related operational risk
- Maintain device stability across production environments

---

# ⚙ Delivery Optimization Policy

Policy File  
`Win - WUfB - Delivery Optimization.json`

This policy controls **how Windows devices download updates using Delivery Optimization**.

Delivery Optimization enables devices to download updates from:

- Microsoft Update servers
- Other devices on the same network
- Internet peers

This reduces bandwidth consumption and accelerates update distribution.

### Configuration Summary

| Setting | Configuration |
|---|---|
Delivery Optimization Mode | User Defined |
Peer-to-Peer Download | Enabled |
Peer Caching | Enabled |
Maximum Cache Size | 20% |
Minimum RAM Required | 2 GB |
Minimum File Size for Caching | 10 MB |
VPN Peer Caching | Disabled |

### Benefits

- Reduces WAN bandwidth usage
- Improves update download speed
- Enables distributed update delivery across networks

---

# 📊 Windows Update Reporting & Telemetry

Policy File  
`Win - WUfB - Reports and Telemetry.json`

This policy configures **Windows diagnostic and reporting settings required for update monitoring**.

It enables Windows devices to send update-related telemetry data used for **update compliance and health reporting in Microsoft Intune**.

### Configuration Summary

| Setting | Configuration |
|---|---|
Allow Telemetry | Required |
Update Compliance Reporting | Enabled |
Diagnostic Data Upload | Enabled |
Telemetry Notification UX | Enabled |

### Purpose

These settings support:

- Windows Update compliance dashboards
- Update failure diagnostics
- Update deployment reporting
- Device update health monitoring

---

# 🔄 Windows Update Rings

The repository includes **three update rings** designed for staged deployment.

---

# 🧪 Pilot Ring

Policy File  
`Win - WUfB - Ring 1 - Pilot.json`

Policy Name  
**Win - WUfB - Ring 1 - Pilot**

This ring is used for **initial validation of updates** on a small group of devices managed by IT administrators.

### Configuration Details

| Setting | Value |
|---|---|
Quality Update Deferral | 0 Days |
Feature Update Deferral | 0 Days |
Drivers | Included |
Restart Deadline | Immediate |
Grace Period | 1 Day |
User Pause Updates | Disabled |
Manual Update Scan | Enabled |
Feature Update Rollback Window | 30 Days |
Allow Windows 11 Upgrade | Disabled |

### Deployment Purpose

- Early detection of update issues  
- Internal IT validation  
- Compatibility testing  

---

# 🧪 UAT Ring

Policy File  
`Win - WUfB - Ring 2 - UAT.json`

Policy Name  
**Win - WUfB - Ring 2 - UAT**

This ring is used for **user acceptance testing before production rollout**.

### Configuration Details

| Setting | Value |
|---|---|
Quality Update Deferral | 3 Days |
Feature Update Deferral | 0 Days |
Drivers | Included |
Restart Deadline | Immediate |
Grace Period | 2 Days |
User Pause Updates | Disabled |
Manual Update Scan | Enabled |
Feature Update Rollback Window | 30 Days |
Allow Windows 11 Upgrade | Disabled |

### Deployment Purpose

- Validate updates with real users
- Detect application compatibility issues
- Confirm update stability before production rollout

---

# 🏢 Production Ring

Policy File  
`Win - WUfB - Ring 3 - Production.json`

Policy Name  
**Win - WUfB - Ring 3 - Production**

This ring is used for **full enterprise deployment of Windows updates**.

### Configuration Details

| Setting | Value |
|---|---|
Quality Update Deferral | 10 Days |
Feature Update Deferral | 0 Days |
Drivers | Included |
Restart Deadline | 2 Days |
Grace Period | 1 Day |
User Pause Updates | Disabled |
Manual Update Scan | Enabled |
Feature Update Rollback Window | 30 Days |
Allow Windows 11 Upgrade | Disabled |

Devices in this ring receive updates **10 days after Microsoft releases them**, ensuring updates are validated by Pilot and UAT rings first.

---

# 📦 Deployment via Microsoft Intune

### Step 1 — Import Policies

Policies can be imported using:

- Microsoft Graph API
- Intune configuration automation scripts
- Intune documentation export/import tools

---

### Step 2 — Configure Update Rings

Navigate to:

```

Microsoft Intune
Devices → Windows Updates → Update Rings

```

---

### Step 3 — Assign Policies

Typical enterprise assignments:

| Ring | Assignment |
|---|---|
Pilot | IT devices |
UAT | Selected departments |
Production | All managed devices |

---

# 🔁 Policy Architecture

| Layer | Purpose |
|---|---|
Delivery Optimization | Efficient update downloads |
Reporting & Telemetry | Update monitoring and analytics |
Update Rings | Controlled update deployment |

This layered architecture ensures **secure and stable Windows update management**.

---

# ⚠ Operational Notes

- Policies apply to **Windows 10 and Windows 11 devices**
- Devices must be **managed by Microsoft Intune**
- Updates are delivered using **Windows Update for Business**
- Always test policies in **pilot rings before enterprise rollout**

---

# 📜 License

This project is licensed under the **MIT License**.

---

# 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.0**

---

# ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

# ⚠ Disclaimer

These configuration policies are provided as-is.  
Always validate policies in a staging or pilot environment before deploying them to production devices.

