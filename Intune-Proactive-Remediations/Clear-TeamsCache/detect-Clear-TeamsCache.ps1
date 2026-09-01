<#
.TITLE
    Detection - Teams Cache Health
.SYNOPSIS
    Detects stale or bloated Microsoft Teams cache (classic + new).
.DESCRIPTION
    Checks Teams cache folders for bloat (>500 MB) or stale files older than 7 days.
    Covers: %APPDATA%\Microsoft\Teams and %LOCALAPPDATA%\Packages\MSTeams_* (new Teams).
    This script NEVER modifies the system.
    Exit contract:
    Exit 0 = compliant
    Exit 1 = non-compliant
    Exit 2 = script error
.TAGS
    Remediation,Detection,Teams,Cache,Cleanup
.REMEDIATIONTYPE
    Detection
.PAIRSCRIPT
    remediate-Clear-TeamsCache.ps1
.PLATFORM
    Windows
.MINROLE
    Intune Service Administrator
.PERMISSIONS
    None (local SYSTEM context) - reads cache folder sizes.
.AUTHOR
    Mohammad Abdelkader Omar
.VERSION
    1.0.0
.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; Teams classic + new cache bloat detection.
.LASTUPDATE
    2026-08-31
.EXAMPLE
    .\detect-Clear-TeamsCache.ps1
    Returns exit 0 when compliant; exit 1 when cache cleanup needed.
.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Logs: <SystemDrive>\IntuneLogs\Clear-TeamsCache\Clear-TeamsCache-Detection.txt
#>
#Requires -Version 5.1
[CmdletBinding()] param()
$ErrorActionPreference='Stop'
$SolutionName='Clear-TeamsCache';$ScriptMode='Detection'
$CacheThresholdMB=500;$StaleDays=7
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
function Get-TeamsCachePaths{
$paths=[System.Collections.Generic.List[string]]::new()
$classic=Join-Path $env:APPDATA 'Microsoft\Teams'
if(Test-Path -LiteralPath $classic){$paths.Add($classic)}
$localPkg=Join-Path $env:LOCALAPPDATA 'Packages'
if(Test-Path -LiteralPath $localPkg){ Get-ChildItem -LiteralPath $localPkg -Directory -Filter 'MSTeams_*' -ErrorAction SilentlyContinue | ForEach-Object{ $paths.Add($_.FullName) } }
$usersBase=Join-Path $env:SystemDrive 'Users'
if(Test-Path -LiteralPath $usersBase){
Get-ChildItem -LiteralPath $usersBase -Directory -ErrorAction SilentlyContinue | ForEach-Object{
$pkg=Join-Path $_.FullName 'AppData\Local\Packages'
if(Test-Path -LiteralPath $pkg){ Get-ChildItem -LiteralPath $pkg -Directory -Filter 'MSTeams_*' -ErrorAction SilentlyContinue | ForEach-Object{ if($paths -notcontains $_.FullName){$paths.Add($_.FullName)} } }
$classicUser=Join-Path $_.FullName 'AppData\Roaming\Microsoft\Teams'
if(Test-Path -LiteralPath $classicUser){ if($paths -notcontains $classicUser){$paths.Add($classicUser)} }
}
}
return @($paths | Select-Object -Unique)
}
function Test-ComplianceState{
$reasons=[System.Collections.Generic.List[string]]::new()
try{
$paths=Get-TeamsCachePaths
if($paths.Count -eq 0){Write-Log -Message "No Teams cache paths found - compliant" -Level 'DEBUG';return @($reasons)}
foreach($cachePath in $paths){
try{
$sizeMB=(Get-ChildItem -LiteralPath $cachePath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
if($null -eq $sizeMB){$sizeMB=0}
Write-Log -Message "Teams cache $cachePath : $([math]::Round($sizeMB,1)) MB" -Level 'DEBUG'
if($sizeMB -gt $CacheThresholdMB){$reasons.Add("Teams cache bloated: $cachePath is $([math]::Round($sizeMB)) MB (threshold $CacheThresholdMB MB)")}
}catch{ Write-Log -Message "Cache check warning for $cachePath : $($_.Exception.Message)" -Level 'WARNING' }
}
if($reasons.Count -eq 0){
$totalStale=0
foreach($cachePath in $paths){
$c=Get-ChildItem -LiteralPath $cachePath -Recurse -File -ErrorAction SilentlyContinue | Where-Object{ $_.LastWriteTime -lt (Get-Date).AddDays(-$StaleDays) } | Measure-Object -Property Length -Sum
if($c.Sum){$totalStale+=$c.Sum}
}
if(($totalStale/1MB) -gt 200){$reasons.Add("Teams cache has $([math]::Round($totalStale/1MB)) MB of files older than $StaleDays days")}
}
}catch{throw "Failed to evaluate Teams cache: $($_.Exception.Message)"}
return @($reasons)
}
try{
$null=Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
Write-Banner
if($script:LogReady){Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'}
Write-Log -Message "Detection started - Teams cache" -Level 'INFO'
$reasons=Test-ComplianceState
if($reasons.Count -eq 0){Finish-Script -ExitCode 0 -Message "Compliant - Teams cache healthy" -Level 'SUCCESS'}
foreach($reason in $reasons){Write-Output $reason;Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'}
Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}catch{
Write-Output "Detection error: $($_.Exception.Message)"
Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
