
# Intune Compliance Policy Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-7.0%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)


## Introduction

The **Intune Compliance Policy Script** is a PowerShell script designed to automate the creation of compliance policies for Microsoft Intune. It checks for the presence and versions of specified applications on client machines and generates a JSON output that can be used to enforce compliance rules within Intune. This ensures that all managed devices adhere to your organization's software standards and security policies.

## Features

- **Automated Application Checks**: Verifies the installation and version of specified applications.
- **Customizable Application List**: Easily add or remove applications to monitor.
- **JSON Output Generation**: Produces a JSON object compatible with Intune compliance policies.
- **Wildcard Support**: Allows the use of wildcards to search for software by display name.
- **Error Handling**: Gracefully handles missing applications to prevent compliance check errors.

## Prerequisites

Before using the Intune Compliance Policy Script, ensure you have the following:

- **Windows Operating System**: Compatible with Windows 10 and later.
- **PowerShell 7.0 or Higher**: The script is written for PowerShell 7.0+.
- **Administrative Privileges**: Necessary permissions to access registry entries and execute scripts.
- **Microsoft Intune Subscription**: Required to apply compliance policies.


## Configuration

1. **Define Application Names**

   Edit the script to specify the exact display names of the applications you want to check. These names should match the names shown in **Add or Remove Programs** (appwiz.cpl).

   ```powershell
   [array]$applicationName = @("Google Chrome","Test App")
   ```

2. **Set Compliance Rules**

   Define the compliance rules within Intune by specifying the required versions and remediation actions. This is typically done in the JSON configuration used by Intune.

   ```json
   {
       "Rules":[
           { 
               "SettingName":"Google Chrome",
               "Operator":"GreaterEquals",
               "DataType":"Version",
               "Operand":"116.0.5790.110",
               "MoreInfoUrl":"https://www.liviubarbat.info",
               "RemediationStrings":[ 
                   { 
                       "Language": "en_US",
                       "Title": "Google Chrome x64 is outdated.",
                       "Description": "Make sure to patch Google Chrome"
                   }
               ]
           },
           { 
               "SettingName":"Test App",
               "Operator":"GreaterEquals",
               "DataType":"Version",
               "Operand":"116.0.5790.110",
               "MoreInfoUrl":"https://www.liviubarbat.info",
               "RemediationStrings":[ 
                   { 
                       "Language": "en_US",
                       "Title": "Test App is either outdated or not installed.",
                       "Description": "Make sure to install or update it."
                   }
               ]
           }
       ]
   }
   ```

## Usage

1. **Run the Script**

   Execute the script in PowerShell with administrative privileges.

   ```powershell
   ./DiscoveryScript.ps1
   ```

2. **Review the JSON Output**

   The script will output a compressed JSON object containing the compliance rules based on the installed applications and their versions.

3. **Integrate with Intune**

   Use the generated JSON to create or update compliance policies within the Microsoft Intune portal.

## Script Explanation

### Script Overview

The script performs the following tasks:

1. **Define Applications to Check**: Lists the applications by their display names.
2. **Retrieve Installed Applications**: Searches the registry for installed applications.
3. **Check Installation and Version**: Verifies if each specified application is installed and retrieves its version.
4. **Generate Compliance Object**: Creates a key-value pair object with application names and versions.
5. **Convert to JSON**: Outputs the compliance data as a compressed JSON object suitable for Intune.



### Key Points

- **Exact Display Names**: Ensure that the application names match exactly as they appear in the **Add or Remove Programs** list.
- **Wildcard Support**: While wildcards can be used for searching, the script utilizes exact names for consistency in compliance checks.
- **JSON Compatibility**: The output JSON is formatted to meet Intune's requirements for compliance policy rules.

## Example JSON Output

```json
{
    "Google Chrome": "116.0.5790.110",
    "Test App": "0.0.0.0"
}
```

In this example:

- **Google Chrome** is installed with version **116.0.5790.110**.
- **Test App** is not installed, hence its version is set to **0.0.0.0** to mark it as compliant by default.

## Troubleshooting

- **Script Execution Policy**

  If you encounter execution policy errors, you may need to adjust the PowerShell execution policy:

  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

- **Missing Applications**

  Ensure that the display names in the `$applicationName` array match exactly with those in **Add or Remove Programs**. Mismatches will result in applications being marked as not installed.

- **Registry Access Issues**

  Run the script with administrative privileges to ensure it can access the necessary registry keys.

- **PowerShell Version**

  Verify that you are running PowerShell version 7.0 or higher:

  ```powershell
  $PSVersionTable.PSVersion
  ```



## License

This project is licensed under the [MIT License](LICENSE).


---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.