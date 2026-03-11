
# 📱 Android BYOD App Protection – Intune App Protection Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Android-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Security](https://img.shields.io/badge/App%20Protection-MAM-green.svg)
![BYOD](https://img.shields.io/badge/BYOD-Policy-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**Android BYOD App Protection** is a **Microsoft Intune App Protection Policy (MAM)** designed to secure corporate data on **Android Bring Your Own Device (BYOD)** environments.

This policy protects organizational data inside managed applications without requiring full device enrollment.

It enforces security controls such as:

- Data encryption inside managed apps  
- Preventing data leakage between personal and corporate apps  
- Restricting copy/paste operations  
- Requiring authentication before accessing corporate data  
- Wiping corporate data if security requirements are violated  

This approach allows organizations to **protect corporate information while respecting user privacy** on personal devices.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Designed for **Android BYOD environments**
- Protects corporate data using **App Protection Policies (MAM)**
- No full device enrollment required
- Prevents **data leakage between apps**
- Requires **secure authentication** before accessing work data
- Supports **selective wipe of corporate data**

---

# 📂 Project Structure

```

Android-BYOD-AppProtection
│
├── Android - BYOD - App Protection.json
└── README.md

```

---

# ⚙ How It Works

The App Protection Policy applies security rules directly to **managed applications** installed on Android devices.

Typical protected apps include:

- Microsoft Outlook
- Microsoft Teams
- Microsoft OneDrive
- Microsoft Word / Excel / PowerPoint
- Microsoft Edge

Security controls are enforced **inside the application layer**, not at the device level.

If the device violates policy conditions:

```

Corporate Data → Blocked

```

If security requirements are satisfied:

```

Corporate Data → Accessible

```

---

# 🧾 Policy Details

## Android - BYOD - App Protection.json

### Purpose

Defines an **Android App Protection Policy** that secures corporate data on personally owned devices.

### Policy Name

```

Android - BYOD - App Protection

```

### Policy Type

```

Microsoft Intune Mobile Application Management (MAM)

```

### Platform

```

Android

```

### Ownership Model

```

BYOD (Bring Your Own Device)

```

---

# 🔐 Security Controls

Typical security protections enforced by this policy include:

| Security Control | Description |
|-----------------|-------------|
| App PIN Required | Requires authentication before opening corporate apps |
| Data Encryption | Protects corporate data stored within apps |
| Copy/Paste Restrictions | Prevents copying corporate data to personal apps |
| Save Restrictions | Prevents saving corporate files to personal storage |
| Screen Capture Blocking | Blocks screenshots of corporate data |
| Selective Wipe | Removes corporate data when policy violations occur |

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import the Policy

Upload the JSON configuration:

```

Android - BYOD - App Protection.json

```

Using:

- Microsoft Graph API  
- Intune configuration automation scripts  
- Policy backup/restore tools  

---

### 2️⃣ Configure App Protection Policy

Navigate to:

```

Microsoft Intune
Apps → App Protection Policies → Android

```

Create or import the policy configuration.

---

### 3️⃣ Assign the Policy

Assign the policy to:

- User groups
- Azure AD groups
- BYOD users

App protection policies apply **per user**, not per device.

---

### 4️⃣ Monitor Policy Status

Monitor policy application from:

```

Microsoft Intune
Apps → Monitor → App protection status

```

---

# 💡 Example Use Cases

### Secure BYOD Workforce

Allow employees to access corporate email and documents on personal devices without exposing company data.

---

### Data Loss Prevention

Prevent sensitive files from being copied to:

- Personal apps
- Personal cloud storage
- Unmanaged applications

---

### Corporate Data Isolation

Ensure corporate information stays inside approved applications only.

---

# 🛠 Customization

Administrators can customize the policy to enforce additional controls such as:

- Stronger authentication requirements
- Conditional launch restrictions
- Data transfer restrictions
- Offline data access limitations
- Jailbreak / root detection rules

All configurations can be managed through **Microsoft Intune App Protection Policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune App Protection (MAM)**
- Suitable for **BYOD environments**
- Does not require full device enrollment
- Works with **Microsoft managed applications**
- Always test policies with **pilot users before production deployment**

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

These configurations are provided as-is. Always test policies in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.

