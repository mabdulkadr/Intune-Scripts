<#
.TITLE
    Remediation - Battery Health Report
.SYNOPSIS
    Generates a battery health report and event log entry.
.DESCRIPTION
    Paired remediation for Get-BatteryHealth. Report-only: emits health JSON, writes Application event log.
    Exit contract:
    Exit 0 = success
    Exit 1 = failure
    Exit 2 = script error
.TAGS
    Remediation,Action,Battery,Report
.REMEDIATIONTYPE
    Remediation
.PAIRSCRIPT
    detect-Get-BatteryHealth.ps1
.PLATFORM
    Windows
.MINROLE
    Intune Service Administrator
.PERMISSIONS
    None (local SYSTEM context) - reads battery and writes event log.
.AUTHOR
    Mohammad Abdelkader Omar
.VERSION
    1.0.0
.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; report-only with event log.
.LASTUPDATE
    2026-08-31
.EXAMPLE
    .\remediate-Get-BatteryHealth.ps1
    Generates report.
.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Logs: <SystemDrive>\IntuneLogs\Get-BatteryHealth\Get-BatteryHealth-Remediation.txt
#>
#Requires -Version 5.1
[CmdletBinding()] param()
$ErrorActionPreference='Stop'
$SolutionName='Get-BatteryHealth';$ScriptMode='Remediation'
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
Write-RemediationLog "Battery health report generation started" -Level 'Info'
$batteries=Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
$report=@()
foreach($b in $batteries){
$design=$b.DesignCapacity; $full=$b.FullChargeCapacity
if(-not $design -or $design -eq 0){ continue }
$health=[math]::Round(($full/$design)*100,1)
$report+= [PSCustomObject]@{ DeviceID=$b.DeviceID; DesignCapacity=$design; FullChargeCapacity=$full; HealthPercent=$health; Status=$b.Status }
Write-RemediationLog "Battery $($b.DeviceID): $health% health (Design $design / Full $full)" -Level 'Info'
}
if($report.Count -gt 0){
$jsonPath=Join-Path $script:LogRoot "BatteryHealth_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonPath -Encoding UTF8 -ErrorAction SilentlyContinue
Write-RemediationLog "Report saved to $jsonPath" -Level 'Info'
try{ New-EventLog -LogName Application -Source "Intune-BatteryHealth" -ErrorAction SilentlyContinue; Write-EventLog -LogName Application -Source "Intune-BatteryHealth" -EventId 1001 -EntryType Warning -Message "Battery health degraded: $($report | ConvertTo-Json -Compress)" -ErrorAction SilentlyContinue }catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
}
$script:remediationResult.Status="Success"
$script:remediationResult.PostCheckStatus+="Report generated"
Write-Output "Battery health report completed"
Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
Finish-Script -ExitCode 0 -Message "Remediation completed - report generated" -Level 'SUCCESS'
}catch{
$script:remediationResult.Status="Error"
$script:remediationResult.Error=@{Message=$_.Exception.Message;Type=$_.Exception.GetType().FullName;StackTrace=$_.ScriptStackTrace}
Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally{ Write-Log -Message "Cleanup complete" -Level 'DEBUG' }
