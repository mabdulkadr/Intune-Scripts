# WinRM Proactive Remediation

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview

This repository contains two PowerShell scripts designed to work with Intune's Proactive Remediations feature to ensure that Windows Remote Management (WinRM) remains consistently enabled on managed devices.

- **Detection Script:**  
  Verifies if WinRM/PSRemoting is currently enabled. If it is not, it signals that remediation is required.

- **Remediation Script:**  
  Forces the configuration of WinRM and PowerShell Remoting, ensuring the service is enabled, running, and properly configured.

Using these scripts together helps maintain a stable and reliable remote management environment across all your devices.

## Scripts

1. **Detection Script:**  
   - **Filename:** `Detect-WinRM.ps1`  
   - **Function:** Runs `Test-WSMan` to check if WinRM is operational.
   - **Exit Codes:**  
     - `0`: WinRM is enabled, no remediation needed.  
     - `1`: WinRM is disabled, remediation required.

   **Key Points:**  
   - Simple, one-step check using `Test-WSMan`.  
   - If the command fails or does not return a valid result, an exit code of `1` triggers remediation.

2. **Remediation Script:**  
   - **Filename:** `Remediate_EnableWinRM.ps1`  
   - **Function:** Enables WinRM and PowerShell Remoting using `Enable-PSRemoting -Force`, configures the WinRM service to start automatically, and verifies configuration with `winrm quickconfig`.
   - **Checks & Configurations:**  
     - Ensures the WinRM service is installed and starts if not already running.  
     - Sets the WinRM service startup type to Automatic.  
     - Verifies WinRM configuration.

   **Key Points:**  
   - Includes error handling with `try/catch` blocks.  
   - Uses color-coded output and clear status messages.  
   - Ensures the script is run as Administrator.

## Requirements

- **Administrator Privileges:**  
  The remediation script must be run with elevated permissions.  
  When deployed through Intune Proactive Remediations, it will typically run in SYSTEM context, meeting this requirement.

- **Windows OS:**  
  Works on Windows 10, Windows 11, and Windows Server (2016 and above), or any environment where WinRM and PowerShell are standard.

## Usage with Intune Proactive Remediations

1. **Upload the Detection Script:**  
   In Intune, navigate to **Devoces > Scripts and remediations**, create a new remediation package, and upload `Detect-WinRM.ps1` as the Detection script.

2. **Upload the Remediation Script:**  
   Upload `Remediate_EnableWinRM.ps1` as the Remediation script.

3. **Assignment & Scheduling:**  
   Assign the remediation to the device groups you wish to maintain.  
   Set it to run once or multiple times a day, as required.

4. **Outcomes:**
   - If WinRM is already enabled, the detection script exits with code `0`, so no remediation runs.
   - If WinRM is disabled, the detection script exits with code `1`, triggering the remediation script to enable and configure WinRM.

## Example Console Output (Remediation Script)

```
*** Starting WinRM Configuration ***

Step 1: Checking WinRM service status...
WinRM service is not running. Starting the service...
WinRM service started successfully.

Step 2: Enabling PowerShell remoting...
PowerShell remoting enabled successfully.

Step 3: Configuring WinRM service to start automatically on reboot...
WinRM service set to start automatically.

Step 4: Verifying WinRM configuration...
WinRM configuration verified successfully.

*** WinRM Configuration Completed Successfully ***
```

If any errors occur, they will be displayed in red for quick identification.

## Troubleshooting

- **Not Running as Administrator:**  
  If the remediation script is run outside Intune and prompts for admin rights, relaunch PowerShell as Administrator or allow Intune to run it as SYSTEM.

- **WinRM Service Not Found:**  
  Ensure WinRM is not disabled by system policies. WinRM is typically installed by default on modern Windows systems.

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.

