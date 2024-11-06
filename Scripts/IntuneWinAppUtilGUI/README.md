# IntuneWinAppUtilGUI

**IntuneWinAppUtilGUI** is a graphical user interface (GUI) for the **Microsoft Win32 Content Prep Tool**, a tool that packages Win32 applications for deployment via **Microsoft Intune**. This utility simplifies the application packaging process by providing a user-friendly interface, making it easier for IT administrators to package and deploy applications in an Intune-managed environment.

## Overview

The **IntuneWinAppUtilGUI** script leverages the **Microsoft Win32 Content Prep Tool** (`IntuneWinAppUtil.exe`) and wraps it with a GUI for easier packaging of applications for deployment through Intune. By streamlining the process of creating `.intunewin` files, this tool saves time and reduces potential errors in application packaging.

## Features

- **User-Friendly GUI**: Simplifies the Win32 app packaging process.
- **Automated Packaging**: Uses Microsoft’s `IntuneWinAppUtil.exe` to create `.intunewin` files.
- **Customizable Paths**: Easily select source and output folders through the GUI.
- **Error Handling**: Provides feedback for troubleshooting packaging issues.

## Requirements

- **Windows OS**: Windows 10 or later.
- **Microsoft .NET Framework 4.6 or higher**.
- **Microsoft Win32 Content Prep Tool**: `IntuneWinAppUtil.exe` should be downloaded and placed in the same directory as the script.
  - You can download the Win32 Content Prep Tool from the Microsoft official site: [Download Here](https://learn.microsoft.com/mem/intune/apps/apps-win32-app-management#prepare-the-win32-app-content)


## Usage

1. **Launch the GUI**:

   ```powershell
   .\PSGUIIntuneWinAppUtility.ps1
   ```

2. **Select Source Folder**:
   - Choose the folder containing the application files to be packaged.

3. **Specify Setup File**:
   - Select the main executable file or setup file for the application you are packaging.

4. **Choose Output Folder**:
   - Specify the folder where you want the `.intunewin` file to be saved.

5. **Create Package**:
   - Click the **Package** button to start the packaging process.
   - The tool will use `IntuneWinAppUtil.exe` to create the `.intunewin` package, which will be saved to the specified output folder.

6. **Deploy to Intune**:
   - Once the `.intunewin` file is created, it can be uploaded to Microsoft Intune for deployment.

## Troubleshooting

- **Missing `IntuneWinAppUtil.exe`**: Ensure `IntuneWinAppUtil.exe` is in the same directory as the GUI.
- **Permission Errors**: Run the GUI with administrative privileges if you encounter access issues.
- **Incomplete Packaging**: Double-check that the source folder and setup file paths are correctly specified.

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

*With IntuneWinAppUtilGUI, packaging Win32 applications for Intune has never been easier! Use this tool to simplify and streamline your application deployments.*
