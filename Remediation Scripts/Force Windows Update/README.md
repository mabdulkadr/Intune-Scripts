
# Windows Updates Management Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

This documentation describes two PowerShell scripts designed for managing Windows updates on a local system:

1. **Detect_ForceWindowsUpdate.ps1** - Detects pending Windows updates.
2. **Remediate_ForceWindowsUpdate.ps1** - Installs all pending Windows updates on the system.

---

## Scripts Overview

### 1. Detect_ForceWindowsUpdate.ps1
**Purpose:**
- This script checks the system for any pending Windows updates.
- It provides a count of updates that need to be installed, excluding firmware updates.

**Key Features:**
- Ensures the `PSWindowsUpdate` module is installed for managing updates.
- Outputs the number of pending updates or confirms that no updates are needed.

**Usage:**
```powershell
.\Detect_ForceWindowsUpdate.ps1
```

---

### 2. Remediate_ForceWindowsUpdate.ps1
**Purpose:**
- This script forces the installation of all pending Windows updates on the local system.
- If necessary, it will notify the user about a required reboot to complete the update process.

**Key Features:**
- Ensures the `PSWindowsUpdate` module is installed.
- Installs all pending updates silently and logs the process.
- Includes a function to check for a pending reboot using Windows registry keys.
- Automatically adjusts the PowerShell execution policy to "Unrestricted" if required.

**Usage:**
```powershell
.\Remediate_ForceWindowsUpdate.ps1
```

---

## Prerequisites
1. **PowerShell Execution Policy:**
   - Ensure your execution policy allows running scripts. The `Remediate_ForceWindowsUpdate.ps1` script will attempt to set it to `Unrestricted` if required.
   
2. **PSWindowsUpdate Module:**
   - The scripts will ensure the `PSWindowsUpdate` module is installed. If not present, it will be downloaded and installed automatically.

3. **Administrative Privileges:**
   - Both scripts must be run with administrative privileges to access Windows Update functionality.

---

## Example Output

### Detect Script
- **Pending Updates Found:**
  ```
  There are 3 pending Windows Updates.
  ```
- **No Pending Updates:**
  ```
  No pending Windows Updates.
  ```

### Remediate Script
- **Installing Updates:**
  ```
  Installing 3 pending Windows updates...
  All pending updates installed successfully.
  A reboot is required to complete the update process.
  ```
- **No Updates Found:**
  ```
  No pending updates found.
  ```

---

## Notes
- These scripts are designed to work on systems using Windows Update as their update management tool.
- For managed environments (e.g., WSUS or Intune), ensure compatibility with your organization's update policies.

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.

