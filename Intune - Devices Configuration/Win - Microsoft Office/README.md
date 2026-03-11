
# 📊 Microsoft Office Policies

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Office](https://img.shields.io/badge/Microsoft%20365%20Apps-orange.svg)
![Security](https://img.shields.io/badge/Security-Hardening-green.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

This repository contains **Microsoft Intune configuration policies for Microsoft Office** exported through **Microsoft Graph API**.

These policies define enterprise configuration standards for **Microsoft 365 Apps for Enterprise** running on Windows devices.

The policies focus on three major areas:

- Office user experience configuration  
- Office security hardening  
- Office update management  

The configurations ensure that Office applications operate under **secure and standardized enterprise settings** across managed devices.

---

# ✨ Core Features

- Standardized Microsoft Office configuration  
- Centralized Office security policies  
- Enterprise macro protection  
- Office update automation  
- Secure application behavior enforcement  
- Microsoft Intune MDM policy deployment  

---

# 📂 Project Structure

```

Microsoft-Office-Intune-Policies
│
├── Win - Microsoft Office - Config and Experience.json
├── Win - Microsoft Office - Updates.json
├── Win - Microsoft Office - Security.json
│
└── README.md

```

---

# ⚙ Office Configuration Policy

Policy File  
`Win - Microsoft Office - Config and Experience.json`

Policy Name  
**Win - Microsoft Office - Config and Experience**

This policy contains **Office application configuration settings** applied to Windows devices via Intune MDM.

Policy metadata extracted from configuration: :contentReference[oaicite:0]{index=0}

Main configuration areas include:

- Excel default file format settings  
- Office first-run experience control  
- Office introductory movie disablement  
- Excel compatibility dialogs configuration  
- Office language settings management  
- Application behavior configuration  

Example configuration categories:

| Application | Configuration |
|---|---|
| Excel | Default file save format |
| Excel | Compatibility dialog behavior |
| Office Core | Disable first run experience |
| Office Core | Disable introduction screen |
| Office Language Settings | Disable proofing tools advertisement |
| Office System | Default hyperlink behavior |

These settings ensure **consistent user experience across managed devices**.

---

# 🔐 Office Security Policy

Policy File

```

Win - Microsoft Office - Security.json

```

Policy Name

**Win - Microsoft Office - Security**

This policy enforces **security hardening controls across Microsoft Office applications**.

Security protections typically include:

### Macro Protection

- Block macros from internet sources  
- Configure VBA warning levels  
- Control trusted locations  
- Restrict execution of unsigned extensions  

### Application Security

Applied across:

- Excel  
- Word  
- Outlook  
- PowerPoint  
- Access  
- OneNote  
- Visio  
- Project  
- Publisher  

Example security protections:

| Security Control | Purpose |
|---|---|
| Block Internet Macros | Prevent malicious document execution |
| VBA Security Policies | Restrict macro execution |
| Trusted Locations Control | Prevent unsafe execution paths |
| Signed Extensions Requirement | Ensure trusted application extensions |

These policies reduce the attack surface for **malicious Office documents and macro-based malware**.

---

# 🔄 Office Update Policy

Policy File

```

Win - Microsoft Office - Updates.json

```

Policy Name

**Win - Microsoft Office - Updates**

This policy manages how **Microsoft Office updates are deployed and controlled** on Windows devices.

Policy configuration extracted from Intune export: :contentReference[oaicite:1]{index=1}

Configured update settings include:

- Enable automatic Office updates  
- Hide update controls from users  
- Prevent Bing extension installation  
- Allow Office online repair with CDN fallback  

Example configuration:

| Setting | Purpose |
|---|---|
| Enable Automatic Updates | Keep Office patched |
| Hide Update Controls | Prevent user modification |
| Prevent Bing Install | Block bundled extension |
| Online Repair Configuration | Enable repair using Microsoft CDN |

This ensures **secure and controlled Office update distribution**.

---

# 📦 Deployment via Microsoft Intune

### Step 1 — Import Policy

Policies can be imported using:

- Microsoft Graph API  
- Intune configuration import scripts  
- Intune documentation tools  

---

### Step 2 — Configure in Intune Portal

Navigate to:

```

Microsoft Intune
Devices → Configuration Profiles

```

---

### Step 3 — Assign Policy

Typical enterprise assignments:

| Policy | Assignment |
|---|---|
| Office Configuration | All Windows devices |
| Office Security | Enterprise users |
| Office Updates | Managed endpoints |

---

# 🔁 Policy Architecture

| Layer | Purpose |
|---|---|
| Configuration | Office behavior standardization |
| Security | Protection against malicious documents |
| Updates | Patch and version management |

This layered design creates a **secure and controlled Microsoft Office environment**.

---

# ⚠ Operational Notes

- These policies apply only to **Microsoft 365 Apps for Enterprise**.
- Devices must be **managed by Microsoft Intune**.
- Policies are delivered through **MDM configuration profiles**.
- Exported via **Microsoft Graph API**.
- Test policies in **pilot groups before production rollout**.

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

