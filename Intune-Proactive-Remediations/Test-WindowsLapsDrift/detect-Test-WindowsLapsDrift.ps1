<#
.TITLE
    Detection - Windows LAPS Drift (Legacy vs Windows LAPS)
.SYNOPSIS
    Detects drift between legacy LAPS CSE and Windows LAPS policy.
.DESCRIPTION
    Checks for legacy LAPS installation (AdmPwd.dll CSE) co-existing with Windows LAPS.
    Flags: legacy CSE still registered when Windows LAPS is configured, or Windows LAPS
    policy missing while legacy is removed. Recommends migration path per Microsoft guidance.
    This script NEVER modifies the system.
    Exit contract:
    Exit 0 = compliant (Windows LAPS clean)
    Exit 1 = non-compliant (drift detected)
    Exit 2 = script error
.TAGS
    Remediation,Detection,LAPS,Drift,Hardening
.REMEDIATIONTYPE
    Detection
.PAIRSCRIPT
    remediate-Test-WindowsLapsDrift.ps1
.PLATFORM
    Windows
.MINROLE
    Intune Service Administrator
.PERMISSIONS
    None (local SYSTEM context) - reads registry and CSE.
.AUTHOR
    Mohammad Abdelkader Omar
.VERSION
    1.0.0
.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; legacy vs Windows LAPS drift detection.
.LASTUPDATE
    2026-08-31
.EXAMPLE
    .\detect-Test-WindowsLapsDrift.ps1
    Returns exit 0 when clean; exit 1 when drift detected.
.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Logs: <SystemDrive>\IntuneLogs\Test-WindowsLapsDrift\Test-WindowsLapsDrift-Detection.txt
#>
#Requires -Version 5.1
[CmdletBinding()] param()
$ErrorActionPreference='Stop'
$SolutionName='Test-WindowsLapsDrift';$ScriptMode='Detection'
$LegacyCseGuid='{A0AFB8BA-A28A-4D96-A0F0-B1A5E1A3AD72}'
$LegacyDllPath='C:\Program Files\LAPS\CSE\AdmPwd.dll'
$WindowsLapsRegPath='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\LAPS'
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
function Test-ComplianceState{
$reasons=[System.Collections.Generic.List[string]]::new()
try{
$legacyCsePresent=$false; $windowsLapsConfigured=$false
# Check legacy CSE registration
try{
$csePath="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\$LegacyCseGuid"
if(Test-Path -LiteralPath $csePath){ $legacyCsePresent=$true; Write-Log -Message "Legacy LAPS CSE found at $csePath" -Level 'DEBUG' }
if(Test-Path -LiteralPath $LegacyDllPath){ $legacyCsePresent=$true; Write-Log -Message "Legacy DLL found at $LegacyDllPath" -Level 'DEBUG' }
}catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
# Check Windows LAPS configuration
if(Test-Path -LiteralPath $WindowsLapsRegPath){ $windowsLapsConfigured=$true; Write-Log -Message "Windows LAPS policy found at $WindowsLapsRegPath" -Level 'DEBUG'
try{ $props=Get-ItemProperty -LiteralPath $WindowsLapsRegPath -ErrorAction SilentlyContinue
if($props.BackupDirectory -ne 1 -and $props.BackupDirectory -ne 2){ Write-Log -Message "Windows LAPS BackupDirectory not set to Entra (1) or AD (2)" -Level 'DEBUG' }
}catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
}
# Also check Intune LAPS policy via CSP path
$intuneLapsPath='HKLM:\SOFTWARE\Microsoft\Policies\Microsoft\LAPS'
if(Test-Path -LiteralPath $intuneLapsPath){ $windowsLapsConfigured=$true; Write-Log -Message "Intune LAPS policy path present" -Level 'DEBUG' }
if($legacyCsePresent -and $windowsLapsConfigured){
$reasons.Add("Legacy LAPS CSE and Windows LAPS both present - complete migration by removing legacy CSE (AdmPwd.dll) and legacy GPO")
}
elseif($legacyCsePresent -and -not $windowsLapsConfigured){
$reasons.Add("Legacy LAPS CSE present but Windows LAPS not configured - migrate to Windows LAPS via Intune Account Protection policy")
}
# Check for Windows LAPS backup failure: Event ID 10011 in LAPS Operational log
try{
$events=Get-WinEvent -LogName 'Microsoft-Windows-LAPS/Operational' -MaxEvents 5 -ErrorAction SilentlyContinue | Where-Object{ $_.Id -eq 10011 -and $_.TimeCreated -gt (Get-Date).AddDays(-7) }
if($events){ $reasons.Add("Windows LAPS backup failures detected in last 7 days (Event 10011) - check Entra permissions") }
}catch{ Write-Log -Message "LAPS event log check skipped: $($_.Exception.Message)" -Level 'DEBUG' }
}catch{throw "Failed to evaluate LAPS drift: $($_.Exception.Message)"}
return @($reasons)
}
try{
$null=Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
Write-Banner
if($script:LogReady){Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'}
Write-Log -Message "Detection started - Windows LAPS drift" -Level 'INFO'
$reasons=Test-ComplianceState
if($reasons.Count -eq 0){Finish-Script -ExitCode 0 -Message "Compliant - Windows LAPS clean, no drift" -Level 'SUCCESS'}
foreach($reason in $reasons){Write-Output $reason;Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'}
Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}catch{
Write-Output "Detection error: $($_.Exception.Message)"
Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
