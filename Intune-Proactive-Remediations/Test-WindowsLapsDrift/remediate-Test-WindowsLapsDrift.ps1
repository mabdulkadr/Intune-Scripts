<#
.TITLE
    Remediation - Windows LAPS Drift Cleanup Report
.SYNOPSIS
    Reports Windows LAPS drift and guides cleanup of legacy CSE.
.DESCRIPTION
    Paired remediation for Test-WindowsLapsDrift. Report-only: documents drift,
    writes event log, and provides manual cleanup steps. Does not auto-uninstall
    legacy CSE to avoid lockout - operator must verify Windows LAPS backup first.
    Exit contract:
    Exit 0 = success (report generated)
    Exit 1 = failure
    Exit 2 = script error
.TAGS
    Remediation,Action,LAPS,Drift,Report
.REMEDIATIONTYPE
    Remediation
.PAIRSCRIPT
    detect-Test-WindowsLapsDrift.ps1
.PLATFORM
    Windows
.MINROLE
    Intune Service Administrator
.PERMISSIONS
    None (local SYSTEM context) - reads registry and writes report.
.AUTHOR
    Mohammad Abdelkader Omar
.VERSION
    1.0.0
.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; drift report with manual cleanup guidance.
.LASTUPDATE
    2026-08-31
.EXAMPLE
    .\remediate-Test-WindowsLapsDrift.ps1
    Generates drift report.
.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Manual step: uninstall legacy LAPS MSI after confirming Windows LAPS escrow.
    - Logs: <SystemDrive>\IntuneLogs\Test-WindowsLapsDrift\Test-WindowsLapsDrift-Remediation.txt
#>
#Requires -Version 5.1
[CmdletBinding()] param()
$ErrorActionPreference='Stop'
$SolutionName='Test-WindowsLapsDrift';$ScriptMode='Remediation'
$remediationResult=@{Status="Unknown";PreCheckStatus=@();RemediationActions=@();PostCheckStatus=@();Timestamp=Get-Date -Format "yyyy-MM-dd HH:mm:ss";ComputerName=$env:COMPUTERNAME}
$script:SystemDrive=if($env:SystemDrive){$env:SystemDrive.TrimEnd('\')}else{[System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')}
$script:LogRoot=$null;$script:LogFile=$null;$script:LogReady=$false
function Initialize-Log{[CmdletBinding()]param([string]$SolutionName='EnterpriseAdminTool',[string]$ScriptMode='run',[ValidateSet('Intune','General')][string]$Type='General')
try{if($Type -eq 'Intune'){$script:LogRoot=Join-Path $script:SystemDrive "IntuneLogs\$SolutionName";$script:LogFile=Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"}else{$script:LogRoot=Join-Path $env:ProgramData "$SolutionName\Logs";$script:LogFile=Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"}
if(-not(Test-Path -LiteralPath $script:LogRoot)){$null=[System.IO.Directory]::CreateDirectory($script:LogRoot)}
if(-not(Test-Path -LiteralPath $script:LogFile)){$null=[System.IO.File]::Create($script:LogFile).Dispose()}
$script:LogReady=$true;return $true}catch{Write-Host "Log init failed: $($_.Exception.Message)" -ForegroundColor Red;$script:LogReady=$false;return $false}}
function Write-Banner{[CmdletBinding()][Alias('Show-Banner')]param()
$title='{0} | {1}' -f $SolutionName,$ScriptMode;$bannerLine='='*78;$lines=@('',$bannerLine,$title,$bannerLine)
foreach($line in $lines){if($line -eq $title){Write-Host $line -ForegroundColor White}else{Write-Host $line -ForegroundColor DarkGray}
if($script:LogReady -and $script:LogFile){Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false}}}
function Write-Log{[CmdletBinding()]param([Parameter(Mandatory=$false)][AllowEmptyString()][string]$Message="",[ValidateSet("INFO","SUCCESS","WARNING","ERROR","DEBUG")][string]$Level="INFO")
if([string]::IsNullOrEmpty($Message)){return};$timestamp=Get-Date -Format "yyyy-MM-dd HH:mm:ss";$logLine="[$timestamp] [$Level] $Message"
$color=switch($Level){"DEBUG"{"DarkGray"}"INFO"{"Cyan"}"SUCCESS"{"Green"}"WARNING"{"Yellow"}"ERROR"{"Red"}}
Write-Host $logLine -ForegroundColor $color
if($script:LogReady -and $script:LogFile){Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false}}
function Finish-Script{[CmdletBinding()]param([Parameter(Mandatory=$true)][int]$ExitCode,[Parameter(Mandatory=$false)][AllowEmptyString()][string]$Message="",[ValidateSet("INFO","SUCCESS","WARNING","ERROR","DEBUG")][string]$Level="INFO",[switch]$NoExit)
Write-Log -Message $Message -Level $Level;if(-not $NoExit){exit $ExitCode}}
function Write-RemediationLog{[CmdletBinding()]param([Parameter(Mandatory=$false)][AllowEmptyString()][string]$Message="",[ValidateSet('Info','Warning','Error')][string]$Level='Info')
if([string]::IsNullOrEmpty($Message)){return};$mapped=switch($Level){'Warning'{'WARNING'}'Error'{'ERROR'}default{'INFO'}}
Write-Log -Message $Message -Level $mapped
$script:remediationResult.RemediationActions+=@{Timestamp=(Get-Date -Format "yyyy-MM-dd HH:mm:ss");Level=$Level;Message=$Message}}
try{
$null=Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
Write-Banner
if($script:LogReady){Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'}
Write-RemediationLog "Windows LAPS drift remediation started - report-only mode" -Level 'Info'
Write-RemediationLog "Legacy CSE GUID: {A0AFB8BA-A28A-4D96-A0F0-B1A5E1A3AD72}" -Level 'Info'
Write-RemediationLog "Check 1: Looking for AdmPwd.dll at C:\Program Files\LAPS\CSE\AdmPwd.dll" -Level 'Info'
if(Test-Path -LiteralPath 'C:\Program Files\LAPS\CSE\AdmPwd.dll'){ Write-RemediationLog "FOUND legacy DLL - manual uninstall required via msiexec /x {legacy MSI}" -Level 'Warning' }
else{ Write-RemediationLog "Legacy DLL not found - OK" -Level 'Info' }
Write-RemediationLog "Check 2: Verifying Windows LAPS operational log for backup success (Event 10018)" -Level 'Info'
try{
$successEvents=Get-WinEvent -LogName 'Microsoft-Windows-LAPS/Operational' -MaxEvents 3 -ErrorAction SilentlyContinue | Where-Object{ $_.Id -eq 10018 }
if($successEvents){ Write-RemediationLog "Windows LAPS backup success found (Event 10018) at $($successEvents[0].TimeCreated)" -Level 'Info' }
else{ Write-RemediationLog "No recent Windows LAPS success events (10018) - verify Entra backup" -Level 'Warning' }
}catch{ Write-RemediationLog "LAPS event log unavailable: $($_.Exception.Message)" -Level 'Warning' }
Write-RemediationLog "Manual cleanup steps after verification:" -Level 'Info'
Write-RemediationLog "  1. Confirm Windows LAPS password escrowed in Entra ID (Get-LapsAADPassword)" -Level 'Info'
Write-RemediationLog "  2. Uninstall legacy LAPS MSI: msiexec /x {product-code} /qn" -Level 'Info'
Write-RemediationLog "  3. Remove legacy GPO CSE registration and delete AdmPwd.dll" -Level 'Info'
Write-RemediationLog "  4. Re-run detection to confirm compliant" -Level 'Info'
try{ New-EventLog -LogName Application -Source "Intune-LAPSDrift" -ErrorAction SilentlyContinue; Write-EventLog -LogName Application -Source "Intune-LAPSDrift" -EventId 1002 -EntryType Warning -Message "LAPS drift detected - legacy CSE present. See IntuneLogs\Test-WindowsLapsDrift" -ErrorAction SilentlyContinue }catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
$reportPath=Join-Path $script:LogRoot "LapsDrift_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$remediationResult | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding UTF8 -ErrorAction SilentlyContinue
Write-RemediationLog "Report saved to $reportPath" -Level 'Info'
$script:remediationResult.Status="Success";$script:remediationResult.PostCheckStatus+="Drift report generated - manual cleanup required"
Write-Output "LAPS drift report completed - manual cleanup required"
Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
Finish-Script -ExitCode 0 -Message "Remediation completed - report generated" -Level 'SUCCESS'
}catch{
$script:remediationResult.Status="Error"
$script:remediationResult.Error=@{Message=$_.Exception.Message;Type=$_.Exception.GetType().FullName;StackTrace=$_.ScriptStackTrace}
Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally{ Write-Log -Message "Cleanup complete - verify escrow before removing legacy" -Level 'DEBUG' }
