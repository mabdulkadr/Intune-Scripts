<#
.TITLE
    Remediation - Clear Teams Cache
.SYNOPSIS
    Clears bloated Microsoft Teams cache (classic + new).
.DESCRIPTION
    Paired remediation for Clear-TeamsCache. Terminates Teams processes gracefully,
    deletes cache content under %APPDATA%\Microsoft\Teams and MSTeams_* packages.
    Exit contract:
    Exit 0 = success
    Exit 1 = failure
    Exit 2 = script error
.TAGS
    Remediation,Action,Teams,Cache,Cleanup
.REMEDIATIONTYPE
    Remediation
.PAIRSCRIPT
    detect-Clear-TeamsCache.ps1
.PLATFORM
    Windows
.MINROLE
    Intune Service Administrator
.PERMISSIONS
    None (local SYSTEM context) - deletes cache files.
.AUTHOR
    Mohammad Abdelkader Omar
.VERSION
    1.0.0
.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; clears classic + new Teams cache.
.LASTUPDATE
    2026-08-31
.EXAMPLE
    .\remediate-Clear-TeamsCache.ps1
    Clears Teams cache and verifies.
.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Logs: <SystemDrive>\IntuneLogs\Clear-TeamsCache\Clear-TeamsCache-Remediation.txt
#>
#Requires -Version 5.1
[CmdletBinding()] param()
$ErrorActionPreference='Stop'
$SolutionName='Clear-TeamsCache';$ScriptMode='Remediation'
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
function Test-RemediationPrerequisites{try{$script:remediationResult.PreCheckStatus+="Pre-check passed";return $true}catch{Write-RemediationLog "Pre-check error: $($_.Exception.Message)" -Level 'Error';return $false}}
function Clear-TeamsCachePath{param([string]$Path)
try{
if(-not(Test-Path -LiteralPath $Path)){return $true}
Get-Process -Name ms-teams,Teams -ErrorAction SilentlyContinue | ForEach-Object{ try{ $_.CloseMainWindow() | Out-Null; Start-Sleep -Seconds 2; if(-not $_.HasExited){ Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } }catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' } }
$subPaths=@('Cache','CachedData','GPUCache','Code Cache','tmp','logs','blob_storage','IndexedDB','Local Storage','CacheStorage')
foreach($sub in $subPaths){
$full=Join-Path $Path $sub
if(Test-Path -LiteralPath $full){
try{ Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction Stop; Write-RemediationLog "Cleared $full" -Level 'Info' }catch{ Write-RemediationLog "Partial clear $full : $($_.Exception.Message)" -Level 'Warning' }
}
}
Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object{ $_.LastWriteTime -lt (Get-Date).AddDays(-1)} | ForEach-Object{ try{ Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' } }
return $true
}catch{ Write-RemediationLog "Clear failed for $Path : $($_.Exception.Message)" -Level 'Error'; return $false}
}
try{
$null=Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
Write-Banner
if($script:LogReady){Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'}
Write-RemediationLog "Starting remediation - Teams cache cleanup" -Level 'Info'
if(-not(Test-RemediationPrerequisites)){throw "Pre-check failed"}
$script:failedCount=0;$targetCount=0
$paths=[System.Collections.Generic.List[string]]::new()
$classic=Join-Path $env:APPDATA 'Microsoft\Teams'; if(Test-Path -LiteralPath $classic){$paths.Add($classic)}
$localPkg=Join-Path $env:LOCALAPPDATA 'Packages'; if(Test-Path -LiteralPath $localPkg){ Get-ChildItem -LiteralPath $localPkg -Directory -Filter 'MSTeams_*' -ErrorAction SilentlyContinue | ForEach-Object{$paths.Add($_.FullName)} }
$usersBase=Join-Path $env:SystemDrive 'Users'
if(Test-Path -LiteralPath $usersBase){
Get-ChildItem -LiteralPath $usersBase -Directory -ErrorAction SilentlyContinue | ForEach-Object{
$pkg=Join-Path $_.FullName 'AppData\Local\Packages'
if(Test-Path -LiteralPath $pkg){ Get-ChildItem -LiteralPath $pkg -Directory -Filter 'MSTeams_*' -ErrorAction SilentlyContinue | ForEach-Object{ if($paths -notcontains $_.FullName){$paths.Add($_.FullName)} } }
$classicUser=Join-Path $_.FullName 'AppData\Roaming\Microsoft\Teams'
if(Test-Path -LiteralPath $classicUser){ if($paths -notcontains $classicUser){$paths.Add($classicUser)} }
}
}
Write-RemediationLog "Found $($paths.Count) cache location(s)" -Level 'Info'
foreach($p in $paths){ $targetCount++; if(-not(Clear-TeamsCachePath -Path $p)){ $script:failedCount++ } }
$verificationPassed=($script:failedCount -eq 0)
if($verificationPassed){ $script:remediationResult.Status="Success"; $script:remediationResult.PostCheckStatus+="Teams cache cleared"
Write-Output "Remediation completed successfully"
Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
}else{ $script:remediationResult.Status="Failed"
Write-Output "Remediation finished with $script:failedCount failure(s)"
Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
Finish-Script -ExitCode 1 -Message "Post-remediation verification failed" -Level 'ERROR'}
}
catch{
$script:remediationResult.Status="Error"
$script:remediationResult.Error=@{Message=$_.Exception.Message;Type=$_.Exception.GetType().FullName;StackTrace=$_.ScriptStackTrace}
Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally{ Write-Log -Message "Cleanup complete" -Level 'DEBUG' }
