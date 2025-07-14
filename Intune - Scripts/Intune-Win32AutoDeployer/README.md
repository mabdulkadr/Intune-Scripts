
# Intune-Win32App-AutoDeployer

![License](https://img.shields.io/badge/license-GPL-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-5.0.4-green.svg)

## Overview

`Intune-Win32App-AutoDeployer.ps1` is a PowerShell automation tool designed to streamline the deployment and management of **Win32 applications via Microsoft Intune**. It leverages **Winget**, **Microsoft Graph SDK v2**, and modern packaging tools to fully automate the creation, upload, assignment, and update lifecycle of applications in Intune.

---

## Features

- 🔍 Interactive **Winget app selection** via GridView  
- 📦 Automatic **IntuneWin packaging** using modern module (by [Stephan van Rooij](https://svrooij.io))  
- 👥 Creates **Install/Uninstall Azure AD groups**  
- 🔁 Configures **Proactive Remediations** for auto-updates  
- ☁️ Uploads and assigns the app to Intune (with **Available** installation support)  
- 🔄 Automatically relaunches in PowerShell 5.1 if executed from PS7  
- ✅ Compatible with **Graph SDK v2** and **automation runbooks**  
- 📝 Includes logging and support for CI/CD use  

---

## Requirements

- PowerShell 5.1 (auto-fallback from PS7 if needed)  
- Microsoft.Graph PowerShell SDK v2+  
- `winget` CLI or `Microsoft.WinGet.Client` PowerShell module  
- Intune Admin rights + app registration with necessary Graph API permissions  

---

## Scripts Included

1. **Intune-Win32App-AutoDeployer.ps1**  
   Main script for packaging and deploying Winget apps to Intune.

---

## How to Use

```powershell
# Launch the script
.\Intune-Win32App-AutoDeployer.ps1
````

* Select the desired Winget app from GridView
* Script will:

  * Fetch app info from Winget
  * Package as Win32 app
  * Create AAD install/uninstall groups
  * Upload to Intune and assign
  * Deploy proactive remediation for update checks (optional)

---

## Outputs

* Packaged `.intunewin` file
* App uploaded and assigned in Intune
* Azure AD groups created and linked
* Update remediation deployed (if enabled)
* Summary email (if configured in automation)

---

## Changelog

### Version 5.0.4

* 🛠️ Graph SDK v2 compatibility fixes
* 🧾 Encoding fix for detection script
* 💬 Added multilingual support in install/uninstall scripts
* 🧪 Support for PowerShell 7 with fallback logic
* 📦 Migrated to modern IntuneWin packaging module
* 🪪 Logging improvements for automation
* 🧯 Bug fixes and install/uninstall reliability improvements

---

## Credits

**Author:** Andrew Taylor
🌐 [andrewstaylor.com](https://andrewstaylor.com)
🐦 [@AndrewTaylor\_2](https://twitter.com/AndrewTaylor_2)

---

## References

* 📜 [Original Script - `deploy-winget-win32-multiple.ps1`](https://github.com/andrew-s-taylor/public/blob/main/Powershell%20Scripts/Intune/deploy-winget-win32-multiple.ps1)
  This script was heavily inspired by and built upon Andrew Taylor’s publicly available version. The enhancements include SDK v2 support, email summary, and packaging improvements.

---

## License

This project is licensed under the [GPL License](https://github.com/andrew-s-taylor/public/blob/main/LICENSE)

---

**Disclaimer**: Use at your own risk. Always test in a development environment before applying to production.
