
# 🤖 Android Device Compliance – Intune Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Android-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Compliance](https://img.shields.io/badge/Device-Compliance-green.svg)
![Security](https://img.shields.io/badge/Android-Security%20Policy-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**Android - Device Compliance** is a **Microsoft Intune Android Enterprise Device Compliance Policy** designed to enforce essential security controls on managed Android devices before they are allowed to access corporate resources.

This policy ensures that Android devices comply with enterprise security standards by enforcing requirements such as:

- Device password protection  
- Storage encryption  
- Microsoft Defender threat protection  
- Google SafetyNet device integrity validation  
- Android OS minimum version compliance  

Devices that fail these requirements are marked **non-compliant** and may be restricted from accessing organizational services using **Microsoft Entra Conditional Access**.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Enforces **Android security baseline**
- Requires **numeric device password**
- Enforces **password expiration**
- Requires **device encryption**
- Integrates with **Microsoft Defender for Endpoint**
- Validates **Google SafetyNet integrity**
- Supports **Conditional Access enforcement**

---

# 📂 Project Structure

```

Android-Device-Compliance
│
├── Android - Device Compliance.json
└── README.md

```

---

# ⚙ How It Works

The compliance policy evaluates Android devices against defined security requirements.

Devices are checked for:

- Device password configuration
- Password expiration policy
- Android OS version compliance
- Storage encryption status
- Microsoft Defender threat protection status
- SafetyNet integrity verification

If all requirements are satisfied:

```

Device → Compliant

```

If any requirement fails:

```

Device → Non-Compliant

```

Non-compliant devices can automatically be restricted from accessing corporate services.

---

# 🧾 Policy Details

## Android - Device Compliance.json

### Policy Name

```

Android - Device Compliance

```

### Platform

```

Android Enterprise

```

### Policy Type

```

Microsoft Intune Android Device Owner Compliance Policy

```

---

# 🔐 Password Requirements

The compliance policy enforces the following password configuration.

| Setting | Requirement |
|------|------|
| Password Required | Enabled |
| Password Type | Numeric |
| Minimum Password Length | 4 |
| Password Expiration | 90 Days |
| Password History | 3 Previous Passwords |
| Lock After Inactivity | 1 Minute |

---

# 🛡 Device Security Controls

Additional Android device security protections enforced by the policy.

| Security Setting | Configuration |
|---|---|
| Device Encryption | Required |
| Microsoft Defender Threat Protection | Enabled |
| Allowed Threat Level | Low |
| SafetyNet Basic Integrity | Required |
| SafetyNet Evaluation Type | Basic |
| Intune App Integrity | Required |
| Minimum Android Version | Android 11 |

These checks ensure that Android devices are secure before accessing enterprise resources.

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import the Policy

Upload the configuration file:

```

Android - Device Compliance.json

```

Using:

- Microsoft Graph API  
- Intune configuration automation  
- Intune policy backup / restore tools  

---

### 2️⃣ Configure Compliance Policy

Navigate to:

```

Microsoft Intune
Devices → Compliance Policies → Android

```

Create or import the policy.

---

### 3️⃣ Assign the Policy

Assign the policy to:

- Android device groups
- Azure AD groups
- Managed Android users

---

### 4️⃣ Monitor Compliance

Compliance status can be monitored from:

```

Microsoft Intune
Devices → Monitor → Compliance

```

---

# 💡 Example Use Cases

### Android Enterprise Security

Ensure all Android devices meet security standards before accessing corporate resources.

---

### Conditional Access Enforcement

Prevent non-compliant devices from accessing:

- Microsoft 365  
- Exchange Online  
- SharePoint  
- Corporate SaaS applications  

---

### Mobile Device Governance

Maintain a consistent Android security baseline across all managed devices.

---

# 🛠 Customization

Administrators can extend this compliance policy with additional controls such as:

- Minimum Android security patch level
- Stronger password complexity
- Root detection policies
- Higher Defender threat protection requirements

These settings can be managed through **Microsoft Intune Compliance Policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune Android Compliance Policies**
- Works with **Android Enterprise devices**
- Integrates with **Microsoft Entra Conditional Access**
- Always test policies with **pilot devices before production rollout**

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

These configurations are provided as-is. Always test compliance policies in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.

