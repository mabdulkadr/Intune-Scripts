# WH4B - Enrolled Methods

This is a detect-only script that checks which Windows Hello for Business
(WHfB) sign-in methods are enrolled for the current user and returns the result
as pre-remediation detection output.

Normal states (exit 0)

- `PIN configured`
- `Face and Fingerprint configured`
- `Face configured`
- `Fingerprint configured`
- `Unknown Biometric configured`

>If a biometric is configured a PIN is also configured. If a PIN is configured a biometric is not necessarily configured.

Error states: (exit 1)

- `Windows Hello not configured`
- `LogonCredsAvailable Value is not there`
- `Something went wrong`
- `Uncaught error`

## Usage/Examples

Use [GetWH4BEnrolledMethods--Detect.ps1](C:\QU Data\Scripts\Intune-Scripts\Intune - Remediation Scripts\1-InSight-RemediationScripts\Get-WH4BEnrolledMethods\GetWH4BEnrolledMethods--Detect.ps1) as the detection script. Make sure:

- Run this script using the logged-on credentials = Yes
- Run script in 64-bit PowerShell = Yes

Schedule it to run repeatedly, e.g. daily.

## Troubleshooting/Logs

The log file is created in the user's temp folder, for example:

`%TEMP%\Logs\GetWH4BEnrolledMethods\<COMPUTERNAME>_GetWH4BEnrolledMethods--Detect.txt`
