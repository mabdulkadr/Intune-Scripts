
# 📊 Windows Health Monitoring – Endpoint Analytics

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows-blue.svg)
![Microsoft Intune](https://img.shields.io/badge/Microsoft-Intune-blue.svg)
![Endpoint Analytics](https://img.shields.io/badge/Endpoint-Analytics-green.svg)
![Monitoring](https://img.shields.io/badge/Device-Health%20Monitoring-orange.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

---

# 📖 Overview

**Win - Health Monitoring - Endpoint Analytics** is a **Microsoft Intune Windows Health Monitoring configuration** used to enable **Endpoint Analytics device health monitoring** on managed Windows devices.

Endpoint Analytics provides insights into device performance, boot experience, and overall device health across the organization. By enabling health monitoring, administrators can collect telemetry data that helps identify performance bottlenecks and improve the user experience.

This configuration enables device health monitoring with a focus on **boot performance analysis**, allowing IT administrators to track startup performance metrics across managed Windows devices.

Policy configuration file:  
:contentReference[oaicite:0]{index=0}

---

# ✨ Key Features

- Enables **Windows device health monitoring**
- Integrates with **Microsoft Endpoint Analytics**
- Collects **device performance telemetry**
- Monitors **boot performance metrics**
- Helps identify **startup performance issues**
- Supports **enterprise device performance optimization**

---

# 📂 Project Structure

```

Windows-Health-Monitoring
│
├── Win - Health Monitoring - Endpoint Analytics.json
└── README.md

```

---

# ⚙ How It Works

This configuration enables Windows health monitoring for devices managed by Microsoft Intune.

Once deployed:

1. Windows devices begin collecting health telemetry.
2. Endpoint Analytics processes performance metrics.
3. Administrators gain insights into device health trends.

The configuration specifically monitors:

- Boot performance
- Startup delays
- Device performance trends
- Endpoint user experience metrics

---

# 🧾 Configuration Details

## Win - Health Monitoring - Endpoint Analytics.json

### Configuration Name

```

Win - Health Monitoring - Endpoint Analytics

```

### Platform

```

Windows 10 / Windows 11

```

### Configuration Type

```

Windows Health Monitoring Configuration

```

### Monitoring Scope

```

Boot Performance

```

### Health Monitoring

```

Enabled

```

---

# 📊 Endpoint Analytics Insights

After deployment, administrators can analyze device performance from:

```

Microsoft Intune
Reports → Endpoint Analytics

```

Available insights include:

- Device startup performance
- Application reliability
- Device resource usage
- User experience score

These metrics help IT teams proactively improve device health across the organization.

---

# 🚀 Deployment in Microsoft Intune

### 1️⃣ Import the Configuration

Upload the configuration file:

```

Win - Health Monitoring - Endpoint Analytics.json

```

Using:

- Microsoft Graph API  
- Intune configuration automation  
- Policy backup / restore tools  

---

### 2️⃣ Configure in Intune

Navigate to:

```

Microsoft Intune
Devices → Configuration Profiles → Windows

```

Create or import the configuration profile.

---

### 3️⃣ Assign the Policy

Assign the policy to:

- Windows device groups
- Azure AD groups
- Corporate-managed devices

---

### 4️⃣ Monitor Device Health

Access health monitoring insights from:

```

Microsoft Intune
Reports → Endpoint Analytics

```

---

# 💡 Example Use Cases

### Device Performance Optimization

Identify devices with slow startup performance and optimize configuration.

---

### Endpoint Experience Monitoring

Track device health metrics and improve the overall end-user experience.

---

### Enterprise Device Analytics

Analyze performance trends across thousands of devices in the organization.

---

# 🛠 Customization

Administrators can extend monitoring scope to include:

- Application reliability monitoring
- Device resource usage tracking
- Custom health monitoring scopes
- Additional Endpoint Analytics telemetry

These configurations can be managed through **Microsoft Intune device configuration policies**.

---

# ⚠ Important Notes

- Designed for **Microsoft Intune Windows Device Configuration**
- Integrates with **Endpoint Analytics**
- Requires **Windows 10 or Windows 11 devices**
- Telemetry must be enabled for Endpoint Analytics insights
- Always validate monitoring configurations in a **pilot group before production deployment**

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

These configurations are provided as-is. Always test policies and monitoring configurations in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.

