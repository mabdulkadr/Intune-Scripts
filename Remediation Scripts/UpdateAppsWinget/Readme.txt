Software Update Management Scripts
Automate the detection and updating of essential software applications using PowerShell and Winget.

📄 Table of Contents
Overview
Features
Prerequisites
Installation
Usage
Scheduling
Customization
Troubleshooting
Contributing
License
Overview
This repository contains PowerShell scripts to detect and update a set of essential software applications within an organization. Leveraging the Windows Package Manager (winget.exe), these scripts ensure that critical applications remain up-to-date, enhancing security and performance with minimal manual effort.

Features
Automated Detection: Identify installed software and check for available updates.
Automated Remediation: Update outdated software to the latest versions seamlessly.
Multi-Application Support: Manage applications like 7-Zip, WinRAR, Google Chrome, Mozilla Firefox, Zoom, Notepad++, Company Portal, and VLC.
Scalable: Easily extendable to include additional applications.
Logging & Error Handling: Provides feedback on update statuses and handles errors gracefully.
Prerequisites
Operating System: Windows 10 (version 1809 or later) or Windows 11.
Winget: Ensure Winget is installed (typically included with the App Installer from the Microsoft Store).
Permissions: Administrative privileges to install or update software.
PowerShell Execution Policy: Set to allow script execution:
powershell
Copy code
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Internet Connectivity: Required for downloading updates via Winget.
Installation
Clone the Repository:
bash
Copy code
git clone https://github.com/yourusername/software-update-scripts.git
Navigate to the Directory:
bash
Copy code
cd software-update-scripts
Usage
1. Detection Script
Filename: Detect-SoftwareUpdates.ps1

Purpose:
Checks installed applications and identifies those that need updates.

Run the Script:

powershell
Copy code
.\Detect-SoftwareUpdates.ps1
Exit Codes:

0: All applications are up-to-date.
1: Updates are available for one or more applications.
2. Remediation Script
Filename: Remediate-SoftwareUpdates.ps1

Purpose:
Updates the specified applications to their latest versions.

Run the Script:

powershell
Copy code
.\Remediate-SoftwareUpdates.ps1
Scheduling
Automate script execution using Task Scheduler:

Open Task Scheduler (taskschd.msc).
Create a New Task with appropriate triggers (e.g., daily at 2 AM).
Set Actions to run PowerShell with the desired script:
powershell
Copy code
-ExecutionPolicy Bypass -File "C:\Path\To\Script\Detect-SoftwareUpdates.ps1"
Configure Security Options to run with highest privileges.
Customization
Adding More Applications
Edit the $apps Array in both scripts:
powershell
Copy code
$apps = @(
    @{ ID = "7zip.7zip"; FriendlyName = "7-Zip" },
    # ... existing apps ...
    @{ ID = "YourApp.ID"; FriendlyName = "Your App Name" } # New app
)
Verify Winget IDs:
powershell
Copy code
winget search "Application Name"
Troubleshooting
winget.exe Not Found: Ensure Winget is installed via the Microsoft Store.
Insufficient Permissions: Run PowerShell as an Administrator.
Execution Policy Restrictions: Adjust using Set-ExecutionPolicy.
Application Not Updating: Verify Winget ID and check for specific update requirements.
Contributing
Contributions are welcome! To contribute:

Fork the Repository.
Create a New Branch:
bash
Copy code
git checkout -b feature/YourFeatureName
Make Your Changes.
Commit and Push:
bash
Copy code
git commit -m "Add your message here"
git push origin feature/YourFeatureName
Open a Pull Request.
License
This project is licensed under the MIT License.

Maintaining up-to-date software is crucial for security and performance. These scripts provide an automated solution to manage updates efficiently.

