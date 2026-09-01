<#
.TITLE
    Windows Update Compliance Report

.SYNOPSIS
    Comprehensive Windows Update compliance report - the single source of truth for patch status across your Intune environment.

.DESCRIPTION
    Cross-references every Windows device's actual OS build against: update ring assignments and their deferral/deadline settings, feature update profile assignments and target versions, quality update (expedited) profile assignments, and driver update profile assignments. Reports per-ring compliance rates, devices stuck on old builds, devices assigned to multiple rings (conflict), paused rings still affecting devices, feature update vs ring deferral conflicts, Windows 10 EOL devices, and devices not in any ring.

.TAGS
    Update,Compliance,Patch,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.Read.All,Device.Read.All,Group.Read.All,GroupMember.Read.All

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
    .\Get-IntuneUpdateComplianceReport.ps1
 .EXAMPLE
    .\Get-IntuneUpdateComplianceReport.ps1 -DaysOutdated 14

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\get-intuneupdatecompliancereport\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()][string]$ExportPath,
    [Parameter()][int]$DaysOutdated = 21
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'get-intuneupdatecompliancereport'
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

$buildToVersion = @{
    '19041'='Win10 2004'; '19042'='Win10 20H2'; '19043'='Win10 21H1'
    '19044'='Win10 21H2'; '19045'='Win10 22H2'
    '22000'='Win11 21H2'; '22621'='Win11 22H2'; '22631'='Win11 23H2'
    '26100'='Win11 24H2'; '26200'='Win11 25H2'
}

function Get-WinVersion { param([string]$OsVer)
    if (-not $OsVer) { return 'Unknown' }
    $parts = $OsVer -split '\.'; if ($parts.Count -ge 3 -and $buildToVersion.ContainsKey($parts[2])) { return $buildToVersion[$parts[2]] }
    return "Build $OsVer"
}
#endregion

#region --- Auth ---
Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All','DeviceManagementManagedDevices.Read.All','Device.Read.All','Group.Read.All','GroupMember.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"
#endregion

#region --- Collect All Data ---
Write-Section "COLLECTING DATA"

# 1. All Windows devices
Write-Status "Fetching Windows managed devices..."
$devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,deviceName,osVersion,userPrincipalName,complianceState,lastSyncDateTime,serialNumber,model,manufacturer,azureADDeviceId"
Write-Status "$($devices.Count) Windows devices" "Green"

# 2. Update rings with assignments
Write-Status "Fetching update ring configurations..."
$allConfigs = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windowsUpdateForBusinessConfiguration')&`$expand=assignments"
Write-Status "$($allConfigs.Count) update rings" "Green"

# 3. Feature update profiles
Write-Status "Fetching feature update profiles..."
$featureProfiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles"
Write-Status "$($featureProfiles.Count) feature update profiles" "Green"

# 4. Quality update (expedited) profiles
Write-Status "Fetching quality update profiles..."
$qualityProfiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles"
Write-Status "$($qualityProfiles.Count) quality update profiles" "Green"

# 5. Driver update profiles
Write-Status "Fetching driver update profiles..."
$driverProfiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles"
Write-Status "$($driverProfiles.Count) driver update profiles" "Green"

# 6. Resolve device group memberships for ring matching
Write-Status "Resolving Entra device objects for group matching..."
$entraDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/devices?`$select=id,deviceId,displayName"
$entraMap = @{} # azureADDeviceId -> entraObjectId
foreach ($ed in $entraDevices) { if ($ed.deviceId) { $entraMap[$ed.deviceId] = $ed.id } }
Write-Status "$($entraMap.Count) Entra device objects mapped" "Green"
#endregion

#region --- Build Ring Assignment Map ---
Write-Section "MAPPING RING ASSIGNMENTS"

# For each ring, collect group IDs from assignments
$ringData = @()
foreach ($ring in $allConfigs) {
    $ringGroups = @()
    $hasAllDevices = $false
    $excludeGroups = @()

    if ($ring.assignments) {
        foreach ($a in $ring.assignments) {
            $t = $a.target.'@odata.type'
            if ($t -eq '#microsoft.graph.groupAssignmentTarget') { $ringGroups += $a.target.groupId }
            elseif ($t -like '*allDevices*') { $hasAllDevices = $true }
            elseif ($t -eq '#microsoft.graph.exclusionGroupAssignmentTarget') { $excludeGroups += $a.target.groupId }
        }
    }

    $ringData += [PSCustomObject]@{
        RingName           = $ring.displayName
        RingId             = $ring.id
        QualityDeferral    = $ring.qualityUpdatesDeferralPeriodInDays
        FeatureDeferral    = $ring.featureUpdatesDeferralPeriodInDays
        QualityDeadline    = $ring.qualityUpdatesDeadlineInDays
        QualityGrace       = $ring.qualityUpdatesGracePeriodInDays
        FeatureDeadline    = $ring.featureUpdatesDeadlineInDays
        FeatureGrace       = $ring.featureUpdatesGracePeriodInDays
        QualityPaused      = $ring.qualityUpdatesPaused
        FeaturePaused      = $ring.featureUpdatesPaused
        DriversExcluded    = $ring.driversExcluded
        ActiveHoursStart   = $ring.activeHoursStart
        ActiveHoursEnd     = $ring.activeHoursEnd
        DeliveryOptMode    = $ring.deliveryOptimizationMode
        IncludeGroups      = $ringGroups
        HasAllDevices      = $hasAllDevices
        ExcludeGroups      = $excludeGroups
    }
}

# Resolve group members for ring matching
Write-Status "Resolving group memberships for ring assignment matching..."
$groupMembers = @{} # groupId -> list of device azureADDeviceIds
$allRingGroupIds = ($ringData | ForEach-Object { $_.IncludeGroups + $_.ExcludeGroups }) | Where-Object { $_ } | Select-Object -Unique

foreach ($gid in $allRingGroupIds) {
    $members = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups/$gid/members?`$select=id,deviceId"
    $groupMembers[$gid] = @($members | Where-Object { $_.deviceId } | ForEach-Object { $_.deviceId })
}
Write-Status "Resolved $($allRingGroupIds.Count) groups" "Green"
#endregion

#region --- Per-Device Analysis ---
Write-Section "ANALYZING PER-DEVICE UPDATE COMPLIANCE"

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

# Find most common patch level per major build (proxy for "latest CU")
$buildPatchLevels = @{}
foreach ($d in $devices) {
    if ($d.osVersion -match '10\.0\.(\d+)\.(\d+)') {
        $major = $Matches[1]; $patch = [int]$Matches[2]
        if (-not $buildPatchLevels.ContainsKey($major)) { $buildPatchLevels[$major] = @() }
        $buildPatchLevels[$major] += $patch
    }
}
$latestPatch = @{}
foreach ($b in $buildPatchLevels.Keys) {
    $latestPatch[$b] = ($buildPatchLevels[$b] | Sort-Object -Descending | Select-Object -First 1)
}

$ringMatchCount = @{} # ringName -> device count
$multiRingDevices = 0
$noRingDevices = 0
$pausedRingDeviceCount = 0

foreach ($d in $devices) {
    $osVer = $d.osVersion
    $winVer = Get-WinVersion $osVer
    $buildNum = 0; $patchLevel = 0
    if ($osVer -match '10\.0\.(\d+)\.(\d+)') { $buildNum = [int]$Matches[1]; $patchLevel = [int]$Matches[2] }

    $azureDeviceId = $d.azureADDeviceId
    $daysSinceSync = if ($d.lastSyncDateTime) { [math]::Round(((Get-Date) - [datetime]$d.lastSyncDateTime).TotalDays, 0) } else { 999 }

    # Determine which rings this device is in
    $matchedRings = @()
    foreach ($ring in $ringData) {
        $isIncluded = $false; $isExcluded = $false

        if ($ring.HasAllDevices) { $isIncluded = $true }
        foreach ($gid in $ring.IncludeGroups) {
            if ($groupMembers.ContainsKey($gid) -and $azureDeviceId -in $groupMembers[$gid]) { $isIncluded = $true; break }
        }
        foreach ($gid in $ring.ExcludeGroups) {
            if ($groupMembers.ContainsKey($gid) -and $azureDeviceId -in $groupMembers[$gid]) { $isExcluded = $true; break }
        }

        if ($isIncluded -and -not $isExcluded) { $matchedRings += $ring }
    }

    $ringNames = ($matchedRings | ForEach-Object { $_.RingName }) -join '; '
    $ringCount = $matchedRings.Count
    $primaryRing = if ($matchedRings.Count -gt 0) { $matchedRings[0] } else { $null }

    if ($ringCount -gt 1) { $multiRingDevices++ }
    if ($ringCount -eq 0) { $noRingDevices++ }

    foreach ($mr in $matchedRings) {
        if (-not $ringMatchCount.ContainsKey($mr.RingName)) { $ringMatchCount[$mr.RingName] = 0 }
        $ringMatchCount[$mr.RingName]++
    }

    # Check if device is in a paused ring
    $inPausedRing = ($matchedRings | Where-Object { $_.QualityPaused -or $_.FeaturePaused }).Count -gt 0
    if ($inPausedRing) { $pausedRingDeviceCount++ }

    # Patch currency assessment
    $isLatestPatch = $false; $patchesBehind = 0
    if ($buildNum -gt 0 -and $latestPatch.ContainsKey($buildNum.ToString())) {
        $latest = $latestPatch[$buildNum.ToString()]
        $isLatestPatch = $patchLevel -ge $latest
        $patchesBehind = $latest - $patchLevel
    }

    $isWin10 = $winVer -like 'Win10*'
    $issues = @()
    if ($ringCount -gt 1) { $issues += "IN $ringCount RINGS (CONFLICT)" }
    if ($ringCount -eq 0) { $issues += 'NO UPDATE RING' }
    if ($inPausedRing) { $issues += 'IN PAUSED RING' }
    if ($isWin10) { $issues += 'WINDOWS 10 EOL' }
    if ($daysSinceSync -gt 30) { $issues += "STALE ($($daysSinceSync)d since sync)" }
    if ($patchesBehind -gt 0) { $issues += "$patchesBehind patches behind" }

    $report.Add([PSCustomObject]@{
        DeviceName       = $d.deviceName
        User             = $d.userPrincipalName
        OSVersion        = $osVer
        WindowsVersion   = $winVer
        BuildNumber      = $buildNum
        PatchLevel       = $patchLevel
        IsLatestPatch    = $isLatestPatch
        PatchesBehind    = $patchesBehind
        ComplianceState  = $d.complianceState
        UpdateRing       = if ($ringNames) { $ringNames } else { '(none)' }
        RingCount        = $ringCount
        QualityDeferral  = if ($primaryRing) { $primaryRing.QualityDeferral } else { '-' }
        QualityDeadline  = if ($primaryRing) { $primaryRing.QualityDeadline } else { '-' }
        FeatureDeferral  = if ($primaryRing) { $primaryRing.FeatureDeferral } else { '-' }
        InPausedRing     = $inPausedRing
        DriversExcluded  = if ($primaryRing) { $primaryRing.DriversExcluded } else { '-' }
        LastSync         = $d.lastSyncDateTime
        DaysSinceSync    = $daysSinceSync
        Model            = $d.model
        SerialNumber     = $d.serialNumber
        Issues           = if ($issues.Count -gt 0) { $issues -join '; ' } else { '-' }
    })
}
#endregion

#region --- Console Report ---
Write-Section "UPDATE COMPLIANCE SUMMARY"
Write-Log -Message "" -Level 'INFO'

$onLatest = ($report | Where-Object { $_.IsLatestPatch }).Count
$totalDevices = $report.Count
$compliancePct = if ($totalDevices -gt 0) { [math]::Round(($onLatest / $totalDevices) * 100, 1) } else { 0 }

Write-Log -Message "  Total Windows devices       : $totalDevices" -Level 'INFO'
Write-Log -Message "  On latest patch (per build) : $onLatest ($compliancePct%)" -Level 'INFO'
Write-Log -Message "  Multi-ring conflicts        : $multiRingDevices" -Level 'INFO'
Write-Log -Message "  No ring assigned            : $noRingDevices" -Level 'INFO'
Write-Log -Message "  In paused ring              : $pausedRingDeviceCount" -Level 'INFO'

$win10Count = ($report | Where-Object { $_.WindowsVersion -like 'Win10*' }).Count
Write-Log -Message "  Windows 10 (EOL)            : $win10Count" -Level 'INFO'

# Per-ring compliance
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  --- Per-Ring Compliance ---" -Level 'WARNING'
foreach ($ring in ($ringData | Sort-Object RingName)) {
    $ringDevices = $report | Where-Object { $_.UpdateRing -like "*$($ring.RingName)*" }
    $ringLatest = ($ringDevices | Where-Object { $_.IsLatestPatch }).Count
    $ringTotal = $ringDevices.Count
    $ringPct = if ($ringTotal -gt 0) { [math]::Round(($ringLatest / $ringTotal) * 100, 1) } else { 0 }
    $pauseTag = if ($ring.QualityPaused) { ' [Q-PAUSED]' } elseif ($ring.FeaturePaused) { ' [F-PAUSED]' } else { '' }
    $pctColor = if ($ringPct -ge 90) { 'Green' } elseif ($ringPct -ge 70) { 'Yellow' } else { 'Red' }

    Write-Log -Message "    $($ring.RingName)$pauseTag" -Level 'INFO'
    Write-Log -Message "      Devices: $ringTotal | Patched: $ringLatest ($ringPct%) | Defer: $($ring.QualityDeferral)d | Deadline: $($ring.QualityDeadline)d" -Level 'INFO'
}

# Feature update profile status
if ($featureProfiles.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Feature Update Profiles ---" -Level 'WARNING'
    foreach ($fp in $featureProfiles) {
        $targetVer = if ($fp.featureUpdateVersion) { $fp.featureUpdateVersion } else { 'Not set' }
        Write-Log -Message "    $($fp.displayName) -> Target: $targetVer" -Level 'INFO'
    }

    # Check for ring feature deferral conflict
    $ringsWithFeatureDeferral = $ringData | Where-Object { $_.FeatureDeferral -gt 0 }
    if ($ringsWithFeatureDeferral.Count -gt 0 -and $featureProfiles.Count -gt 0) {
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  WARNING: Feature Update profiles exist but these rings have feature deferral > 0:" -Level 'ERROR'
        foreach ($rfd in $ringsWithFeatureDeferral) {
            Write-Log -Message "    $($rfd.RingName) : $($rfd.FeatureDeferral) day deferral (may block feature update profiles)" -Level 'WARNING'
        }
        Write-Log -Message "  Best practice: Set feature deferral to 0 when using Feature Update profiles." -Level 'DEBUG'
    }
}

# Quality update profile status
if ($qualityProfiles.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Quality Update (Expedited) Profiles ---" -Level 'WARNING'
    foreach ($qp in $qualityProfiles) {
        Write-Log -Message "    $($qp.displayName) | Days to force reboot: $($qp.daysUntilForcedReboot)" -Level 'INFO'
    }
}

# Driver update profile status
if ($driverProfiles.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Driver Update Profiles ---" -Level 'WARNING'
    foreach ($dp in $driverProfiles) {
        $approvalType = if ($dp.approvalType) { $dp.approvalType } else { 'Not set' }
        Write-Log -Message "    $($dp.displayName) | Approval: $approvalType" -Level 'INFO'
    }

    # Check for driver exclusion conflict
    $ringsExcludingDrivers = $ringData | Where-Object { $_.DriversExcluded }
    if ($ringsExcludingDrivers.Count -gt 0 -and $driverProfiles.Count -gt 0) {
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  WARNING: Driver update profiles exist but these rings exclude drivers:" -Level 'ERROR'
        foreach ($red in $ringsExcludingDrivers) {
            Write-Log -Message "    $($red.RingName) - DriversExcluded=True (blocks driver update profiles)" -Level 'WARNING'
        }
    }
}

# Windows version distribution
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  --- Windows Version Distribution ---" -Level 'WARNING'
$verGroups = $report | Group-Object WindowsVersion | Sort-Object { $_.Group[0].BuildNumber } -Descending
foreach ($vg in $verGroups) {
    $pct = [math]::Round(($vg.Count / $totalDevices) * 100, 1)
    $bar = '*' * [math]::Min([math]::Round($pct / 2), 25)
    $c = if ($vg.Name -like 'Win10*') { 'DarkYellow' } else { 'Green' }
    Write-Log -Message "    $($vg.Name.PadRight(16)) : $($vg.Count.ToString().PadLeft(4)) ($pct%) $bar" -Level 'INFO'
}

# Devices with issues
$issueDevices = $report | Where-Object { $_.Issues -ne '-' }
if ($issueDevices.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Devices with Issues ($($issueDevices.Count)) ---" -Level 'ERROR'
    foreach ($id in ($issueDevices | Sort-Object { $_.RingCount } -Descending | Select-Object -First 20)) {
        Write-Log -Message "    $($id.DeviceName) | $($id.OSVersion) | $($id.Issues)" -Level 'WARNING'
    }
    if ($issueDevices.Count -gt 20) { Write-Log -Message "    ... and $($issueDevices.Count - 20) more (see CSV)" -Level 'DEBUG' }
}
#endregion

#region --- Export ---
$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "UpdateCompliance_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path ($($report.Count) rows)" "Green"
Write-Log -Message "" -Level 'INFO'
#endregion


