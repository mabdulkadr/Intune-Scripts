# WH4B - Last Used Method

This script is used to detect the last used method for Windows Hello for Business. It is a detect-only script.

Normal states (exit 0)

- `Pin authentication`
- `Fingerprint authentication`
- `Facial authentication`
- `Password authentication`
- `FIDO authentication`

Error states: (exit 1)

- `LastLoggedOnProvider Value is not there`
- `Authentication method cannot be checked`
- `Something went wrong:`

## Usage/Examples

Use [GetWH4BLastUsedMethod--Detect.ps1](C:\QU Data\Scripts\Intune-Scripts\Intune - Remediation Scripts\1-InSight-RemediationScripts\Get-WH4BLastUsedMethod\GetWH4BLastUsedMethod--Detect.ps1) as the detection script. Make sure:

- Run this script using the logged-on credentials = Yes
- Run script in 64-bit PowerShell = Yes

Schedule it to run repeatedly, e.g. daily.

## Troubleshooting/Logs

The log file is created in the user's temp folder, for example:

`%TEMP%\Logs\GetWH4BLastUsedMethod\<COMPUTERNAME>_GetWH4BLastUsedMethod--Detect.txt`
