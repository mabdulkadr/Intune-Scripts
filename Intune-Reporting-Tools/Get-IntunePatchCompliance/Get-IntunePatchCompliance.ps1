<#
.TITLE
    Windows Patch Compliance Report

.SYNOPSIS
    Reports Windows patch compliance across all Intune managed devices.

.DESCRIPTION
    Pulls OS version data from all Windows managed devices and produces a patch compliance report showing: OS build distribution, devices on each build, how many builds behind each device is, devices stuck on old versions, and a breakdown by Windows version (21H2, 22H2, 23H2, 24H2, 25H2).

.TAGS
    Patch,Compliance,Windows,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All,Device.Read.All,Group.Read.All,GroupMember.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    1.0.0
    - Initial Toolkit import

.LASTUPDATE
    2026-08-26

 .EXAMPLE
    .\Get-IntunePatchCompliance.ps1
 .EXAMPLE
    .\Get-IntunePatchCompliance.ps1 -MinBuild "10.0.22631.0"

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\get-intunepatchcompliance\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()][string]$MinBuild,
    [Parameter()][string]$GroupName,
    [Parameter()][string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'get-intunepatchcompliance'
$ScriptMode   = 'run'

$scriptBasePath = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if ($ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = Join-Path -Path $scriptBasePath -ChildPath $ExportPath
}

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# Single source of truth: Initialize-Log / Write-Banner / Write-Log / Finish-Script.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

# Creates the Intune log folder/file and reports readiness.
function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')]
        [string]$Type = 'General'
    )

    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }

        if (-not (Test-Path -LiteralPath $script:LogRoot)) {
            $null = [System.IO.Directory]::CreateDirectory($script:LogRoot)
        }
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            $null = [System.IO.File]::Create($script:LogFile).Dispose()
        }

        $script:LogReady = $true
        return $true
    }
    catch {
        Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

# Writes the solution banner to console and log file.
function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    $title      = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        } else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady -and $script:LogFile) {
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }
}

# Writes one timestamped, level-colored line to console and log file.
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $logLine -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoExit
    )

    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) {
        exit $ExitCode
    }
}

# ============================================================================
# MAIN ENTRY LOGGING INITIALIZATION
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started" -Level 'INFO'



#region --- Helpers ---
function Write-Status { param([string]$Msg,[string]$Color='Cyan'); Write-Log -Message "  [$((Get-Date).ToString('HH:mm:ss'))] $Msg" -Level 'INFO' }
function Write-Section { param([string]$Msg); Write-Log -Message "`n$('='*60)" -Level 'WARNING'; Write-Log -Message "  $Msg" -Level 'WARNING'; Write-Log -Message "$('='*60)" -Level 'WARNING' }

function Get-MgGraphAllPages {
    param([string]$Uri,[string]$Method='GET')
    try {
        $response = Invoke-MgGraphRequest -Uri $Uri -Method $Method -ErrorAction Stop
        $results = @()
        if ($null -ne $response.value) { $results += $response.value }
        elseif ($response) { $results += $response }
        while ($response.'@odata.nextLink') {
            $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET -ErrorAction Stop
            if ($null -ne $response.value) { $results += $response.value }
        }
        return ,$results
    } catch [System.Exception] { Write-Verbose "Graph call failed: $_"; return @() }
}

# Windows build to version name mapping
$buildMap = @{
    '19041' = 'Windows 10 2004'
    '19042' = 'Windows 10 20H2'
    '19043' = 'Windows 10 21H1'
    '19044' = 'Windows 10 21H2'
    '19045' = 'Windows 10 22H2'
    '22000' = 'Windows 11 21H2'
    '22621' = 'Windows 11 22H2'
    '22631' = 'Windows 11 23H2'
    '26100' = 'Windows 11 24H2'
    '26200' = 'Windows 11 25H2'
}

function Get-WindowsVersion {
    param([string]$OsVersion)
    if (-not $OsVersion) { return 'Unknown' }
    $parts = $OsVersion -split '\.'
    if ($parts.Count -ge 3) {
        $build = $parts[2]
        if ($buildMap.ContainsKey($build)) { return $buildMap[$build] }
    }
    return "Build $OsVersion"
}
#endregion

#region --- Auth ---
Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All','Device.Read.All','Group.Read.All','GroupMember.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"
#endregion

#region --- Get Devices ---
Write-Section "COLLECTING WINDOWS DEVICES"

$filter = "operatingSystem eq 'Windows'"
$selectFields = "id,deviceName,osVersion,operatingSystem,complianceState,lastSyncDateTime,userPrincipalName,model,manufacturer,serialNumber"
$devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=$filter&`$select=$selectFields"
Write-Status "Found $($devices.Count) Windows devices total" "Green"

# Filter by group if specified
if ($GroupName) {
    Write-Status "Filtering to group: $GroupName..."
    $groups = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$GroupName'&`$select=id,displayName"
    if ($groups.Count -eq 0) { Write-Log -Message "  ERROR: Group not found." -Level 'ERROR'; return }
    $groupId = $groups[0].id
    $members = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/members?`$select=id,deviceId"
    $memberDeviceIds = $members | ForEach-Object { $_.deviceId }
    $devices = $devices | Where-Object { $_.azureADDeviceId -in $memberDeviceIds -or $_.id -in ($members | ForEach-Object { $_.id }) }
    Write-Status "Filtered to $($devices.Count) devices in group" "Green"
}
#endregion

#region --- Analyze ---
Write-Section "PATCH COMPLIANCE ANALYSIS"

$report = [System.Collections.Generic.List[PSCustomObject]]::new()
$versionCounts = @{}
$buildCounts = @{}
$outdatedDevices = @()

foreach ($d in $devices) {
    $osVer = $d.osVersion
    $winVer = Get-WindowsVersion $osVer
    $buildNum = if ($osVer -match '10\.0\.(\d+)\.(\d+)') { [int]$Matches[1] } else { 0 }
    $patchLevel = if ($osVer -match '10\.0\.\d+\.(\d+)') { [int]$Matches[1] } else { 0 }

    $isOutdated = $false
    if ($MinBuild) {
        $minParts = $MinBuild -split '\.'
        $minBuildNum = if ($minParts.Count -ge 3) { [int]$minParts[2] } else { 0 }
        $minPatch = if ($minParts.Count -ge 4) { [int]$minParts[3] } else { 0 }
        if ($buildNum -lt $minBuildNum -or ($buildNum -eq $minBuildNum -and $patchLevel -lt $minPatch)) {
            $isOutdated = $true
        }
    }

    $daysSinceSync = if ($d.lastSyncDateTime) {
        [math]::Round(((Get-Date) - [datetime]$d.lastSyncDateTime).TotalDays, 0)
    } else { 999 }

    if (-not $versionCounts.ContainsKey($winVer)) { $versionCounts[$winVer] = 0 }
    $versionCounts[$winVer]++
    if (-not $buildCounts.ContainsKey($osVer)) { $buildCounts[$osVer] = 0 }
    $buildCounts[$osVer]++

    if ($isOutdated) { $outdatedDevices += $d }

    $report.Add([PSCustomObject]@{
        DeviceName      = $d.deviceName
        User            = $d.userPrincipalName
        OSVersion       = $osVer
        WindowsVersion  = $winVer
        BuildNumber     = $buildNum
        PatchLevel      = $patchLevel
        ComplianceState = $d.complianceState
        LastSync        = $d.lastSyncDateTime
        DaysSinceSync   = $daysSinceSync
        Model           = $d.model
        Manufacturer    = $d.manufacturer
        SerialNumber    = $d.serialNumber
        BelowMinBuild   = $isOutdated
    })
}

# Windows version distribution
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  --- Windows Version Distribution ---" -Level 'WARNING'
foreach ($v in ($versionCounts.GetEnumerator() | Sort-Object { $_.Key })) {
    $pct = [math]::Round(($v.Value / $devices.Count) * 100, 1)
    $bar = '*' * [math]::Min([math]::Round($pct / 2), 30)
    $color = if ($v.Key -like '*10*') { 'DarkYellow' } else { 'Green' }
    Write-Log -Message "    $($v.Key.PadRight(25)) : $($v.Value.ToString().PadLeft(4)) ($pct%) $bar" -Level 'INFO'
}

# Top OS builds
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  --- Top 15 OS Builds ---" -Level 'WARNING'
$topBuilds = $buildCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15
foreach ($b in $topBuilds) {
    $pct = [math]::Round(($b.Value / $devices.Count) * 100, 1)
    Write-Log -Message "    $($b.Key.PadRight(22)) : $($b.Value.ToString().PadLeft(4)) devices ($pct%)" -Level 'INFO'
}

# Outdated devices
if ($MinBuild -and $outdatedDevices.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Devices Below Minimum Build: $MinBuild ($($outdatedDevices.Count)) ---" -Level 'ERROR'
    foreach ($od in ($outdatedDevices | Sort-Object { $_.osVersion } | Select-Object -First 20)) {
        Write-Log -Message "    $($od.deviceName) | $($od.osVersion) | $($od.userPrincipalName)" -Level 'WARNING'
    }
    if ($outdatedDevices.Count -gt 20) { Write-Log -Message "    ... and $($outdatedDevices.Count - 20) more" -Level 'DEBUG' }
}

# Windows 10 EOL warning
$win10Count = ($report | Where-Object { $_.WindowsVersion -like '*10*' }).Count
if ($win10Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  WARNING: $win10Count device(s) still on Windows 10 (EOL: Oct 14, 2025)" -Level 'ERROR'
}

# Stale + outdated
$staleAndOld = $report | Where-Object { $_.DaysSinceSync -gt 30 -and $_.BelowMinBuild }
if ($staleAndOld.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  RISK: $($staleAndOld.Count) device(s) are BOTH outdated AND haven't synced in 30+ days" -Level 'ERROR'
}
#endregion

#region --- Summary & Export ---
Write-Section "SUMMARY"
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Total Windows devices  : $($devices.Count)" -Level 'INFO'
Write-Log -Message "  Unique OS builds       : $($buildCounts.Count)" -Level 'INFO'
Write-Log -Message "  Windows versions       : $($versionCounts.Count)" -Level 'INFO'
if ($MinBuild) {
    $compliancePct = [math]::Round((($devices.Count - $outdatedDevices.Count) / [math]::Max($devices.Count, 1)) * 100, 1)
    Write-Log -Message "  At or above min build  : $($devices.Count - $outdatedDevices.Count) ($compliancePct%)" -Level 'INFO'
    Write-Log -Message "  Below minimum build    : $($outdatedDevices.Count)" -Level 'INFO'
}

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "PatchCompliance_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'
#endregion


