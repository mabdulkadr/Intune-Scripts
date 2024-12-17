# Windows Uptime Restart Notification Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Introduction

This repository contains two PowerShell scripts designed to monitor your Windows device's uptime and notify you when a system reboot is recommended for optimal performance and stability.

1. **Detect_WindowsUptimeRestartNotification.ps1**: checks if your device hasn't been restarted for 7 days or more and exits with a corresponding code, allowing integration with other systems or scripts.

2. **Remediate_WindowsUptimeRestartNotification.ps1**: Checks if your device hasn't been restarted for 7 days or more and displays a Windows toast notification prompting a reboot. The notification supports both English and Arabic languages based on your system settings and includes "Restart Now" and "Restart Later" buttons.

## Features

## Detect_WindowsUptimeRestartNotification.ps1

- **Simple Uptime Check**: Quickly checks if the device has been up for 7 days or more.
- **Exit Codes**: Uses exit codes to indicate whether a reboot is needed (`1`) or not (`0`).
- **Easy Integration**: Can be integrated into other scripts or monitoring systems.

### Remediate_WindowsUptimeRestartNotification.ps1

- **Uptime Check**: Determines if the device has been running for 7 days or more without a reboot.
- **Multilingual Notifications**: Automatically displays notifications in English or Arabic based on system language settings.
- **Interactive Buttons**: Includes "Restart Now" and "Restart Later" options within the notification.
- **Custom Imagery**: Displays custom logos and hero images in the notification.
- **User-Friendly Messages**: Provides detailed information on why a reboot is necessary.


## Prerequisites

- **Operating System**: Windows 10 or later.
- **PowerShell**: Version 5.0 or higher.
- **Execution Policy**: Scripts should be allowed to run (`RemoteSigned` or `Unrestricted`).


#### What the Script Does

- Checks the system's uptime.
- If uptime is 7 days or more:
  - Downloads custom images for the notification.
  - Detects the system's display language (English or Arabic).
  - Displays a toast notification with appropriate language and options.

#### Notification Actions

- **Restart Now**: Initiates a system restart immediately.
- **Restart Later**: Dismisses the notification.

## Notes

- **Permissions**: Ensure the user running the scripts has the necessary permissions, especially when modifying registry entries.
- **Customization**:
  - Modify image URLs to use your organization's logos or images.
  - Adjust notification text to suit your organization's messaging.
  - Localize the notification to additional languages if needed.

## Troubleshooting

- **Toast Notification Not Displaying**:
  - Ensure the script is run as the logged-on user, not as an administrator.
  - Verify that the registry entries for toast notifications are correctly set.
  - Check for any typos or syntax errors in the script, especially in the XML structure of the toast notification.
- **Script Execution Policy Errors**:
  - Confirm that the PowerShell execution policy allows the script to run.
  - Use `Get-ExecutionPolicy -List` to view current policies.
- **Image Download Issues**:
  - Verify internet connectivity.
  - Check that the URLs for the images are accessible.
  - Modify the script to use local images if necessary.

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.


