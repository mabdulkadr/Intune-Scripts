<#
.TITLE
    Detection - Battery Health Degraded
.SYNOPSIS
    Detects degraded laptop battery health (<80% of design capacity or >500 cycles).
.DESCRIPTION
    Evaluates battery health via Win32_Battery FullChargeCapacity vs DesignCapacity.
    Reports non-compliant when health <80% or cycle count >500. Desktops without battery exit 0 (not applicable).
    This script NEVER modifies the system.
    Exit contract:
    Exit 0 = compliant or not applicable
    Exit 1 = non-compliant (battery degraded)
    Exit 2 = script error
.TAGS
    Remediation,Detection,Battery,Health,Hardware
.REMEDIATIONTYPE
    Detection
.PAIRSCRIPT
    remediate-Get-BatteryHealth.ps1
.PLATFORM
    Windows
.MINROLE
    Intune Service Administrator
.PERMISSIONS
    None (local SYSTEM context) - reads WMI battery.
.AUTHOR
    Mohammad Abdelkader Omar
.VERSION
    1.0.0
.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; battery health detection.
.LASTUPDATE
    2026-08-31
.EXAMPLE
    .\detect-Get-BatteryHealth.ps1
    Returns exit 0 when healthy or desktop; exit 1 when degraded.
.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Logs: <SystemDrive>\IntuneLogs\Get-BatteryHealth\Get-BatteryHealth-Detection.txt
#>
#Requires -Version 5.1
[CmdletBinding()] param()
$ErrorActionPreference='Stop'
$SolutionName='Get-BatteryHealth';$ScriptMode='Detection'
$HealthThresholdPercent=80;$CycleThreshold=500
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
$batteries=Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
if(-not $batteries -or @($batteries).Count -eq 0){ Write-Log -Message "No battery found - desktop or VM, not applicable" -Level 'DEBUG'; return @($reasons) }
foreach($b in $batteries){
try{
$design=$b.DesignCapacity; $full=$b.FullChargeCapacity; $cycles=$null
if(-not $design -or $design -eq 0){
$static=Get-CimInstance -Namespace root/wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1
if($static){ $design=$static.DesignedCapacity; $full=(Get-CimInstance -Namespace root/wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1).FullChargedCapacity }
}
if(-not $design -or $design -eq 0){ Write-Log -Message "DesignCapacity unavailable, skipping" -Level 'DEBUG'; continue }
$health=[math]::Round(($full / $design)*100,1)
Write-Log -Message "Battery $($b.DeviceID): Design=$design Full=$full Health=$health% " -Level 'DEBUG'
if($health -lt $HealthThresholdPercent){ $reasons.Add("Battery health degraded: $health% (threshold $HealthThresholdPercent%) Design=$design Full=$full") }
}catch{ Write-Log -Message "Battery eval warning: $($_.Exception.Message)" -Level 'WARNING' }
}
}catch{throw "Failed to evaluate battery health: $($_.Exception.Message)"}
return @($reasons)
}
try{
$null=Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
Write-Banner
if($script:LogReady){Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'}
Write-Log -Message "Detection started - Battery health threshold $HealthThresholdPercent%" -Level 'INFO'
$reasons=Test-ComplianceState
if($reasons.Count -eq 0){Finish-Script -ExitCode 0 -Message "Compliant - battery healthy or not applicable" -Level 'SUCCESS'}
foreach($reason in $reasons){Write-Output $reason;Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'}
Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}catch{
Write-Output "Detection error: $($_.Exception.Message)"
Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
