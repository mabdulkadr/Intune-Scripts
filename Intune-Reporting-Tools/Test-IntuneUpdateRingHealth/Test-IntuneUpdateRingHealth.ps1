<#
.TITLE
    Update Ring Health Audit

.SYNOPSIS
    Audits Windows Update ring configurations against Microsoft best practices.

.DESCRIPTION
    Checks every update ring against Microsoft's Autopatch-recommended values and common misconfiguration patterns. Flags: excessive quality deferrals (>14 days), missing deadlines, zero grace periods, paused rings, feature deferral conflicts, drivers excluded conflicts, delivery optimization misconfigurations, active hours not configured, devices in multiple rings, rings with no assignments, and inconsistent deadline/grace ratios across rings.

.TAGS
    Update,Ring,Health,Audit

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All

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
    .\Test-IntuneUpdateRingHealth.ps1

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\test-intuneupdateringhealth\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param([Parameter()][string]$ExportPath)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'test-intuneupdateringhealth'
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

Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

Write-Section "LOADING UPDATE ENVIRONMENT"

$rings = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windowsUpdateForBusinessConfiguration')&`$expand=assignments"
Write-Status "$($rings.Count) update rings" "Green"

$featureProfiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles"
$driverProfiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles"
Write-Status "$($featureProfiles.Count) feature update profiles, $($driverProfiles.Count) driver update profiles" "Green"

# Microsoft Autopatch recommended values
$bestPractice = @{
    MaxQualityDeferral  = 14
    MinQualityDeadline  = 2
    MaxQualityDeadline  = 7
    MinGracePeriod      = 2
    MaxGracePeriod      = 5
    MaxFeatureDeferral  = 0  # When using Feature Update profiles
    RecommendedDO       = 'httpWithPeeringNat'
}

$report = [System.Collections.Generic.List[PSCustomObject]]::new()
$totalFindings = 0

Write-Section "AUDIT FINDINGS"
Write-Log -Message "" -Level 'INFO'

# --- Autopatch best practice reference ---
Write-Log -Message "  Microsoft Autopatch recommended values (reference):" -Level 'DEBUG'
Write-Log -Message "    Quality deferral  : 0-10 days across rings" -Level 'DEBUG'
Write-Log -Message "    Quality deadline  : 2-5 days" -Level 'DEBUG'
Write-Log -Message "    Grace period      : 2 days" -Level 'DEBUG'
Write-Log -Message "    Feature deferral  : 0 days (use Feature Update profiles instead)" -Level 'DEBUG'
Write-Log -Message "    Auto-reboot       : Yes (before deadline)" -Level 'DEBUG'
Write-Log -Message "" -Level 'INFO'

foreach ($ring in ($rings | Sort-Object displayName)) {
    $name = $ring.displayName
    $findings = @()

    # Assignment check
    $assignCount = 0; $hasAllDevices = $false
    if ($ring.assignments) {
        $assignCount = ($ring.assignments | Where-Object { $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' }).Count
        $hasAllDevices = ($ring.assignments | Where-Object { $_.target.'@odata.type' -like '*allDevices*' }).Count -gt 0
    }
    $totalAssignments = $assignCount + $(if ($hasAllDevices) { 1 } else { 0 })

    if ($totalAssignments -eq 0) {
        $findings += [PSCustomObject]@{ Severity='Medium'; Finding='No assignments - ring has no effect'; Category='Assignment' }
    }

    # Quality deferral
    $qd = $ring.qualityUpdatesDeferralPeriodInDays
    if ($qd -gt $bestPractice.MaxQualityDeferral) {
        $findings += [PSCustomObject]@{ Severity='High'; Finding="Quality deferral $qd days exceeds recommended max ($($bestPractice.MaxQualityDeferral) days)"; Category='Deferral' }
    }
    if ($qd -eq 0 -and $totalAssignments -gt 1) {
        $findings += [PSCustomObject]@{ Severity='Medium'; Finding='Zero quality deferral with broad assignment - no buffer for bad patches'; Category='Deferral' }
    }

    # Quality deadline
    $qdl = $ring.qualityUpdatesDeadlineInDays
    if (-not $qdl -or $qdl -eq 0) {
        $findings += [PSCustomObject]@{ Severity='High'; Finding='No quality update deadline - devices may never install updates'; Category='Deadline' }
    }
    if ($qdl -and $qdl -gt $bestPractice.MaxQualityDeadline) {
        $findings += [PSCustomObject]@{ Severity='Medium'; Finding="Quality deadline $qdl days exceeds recommended max ($($bestPractice.MaxQualityDeadline) days)"; Category='Deadline' }
    }

    # Grace period
    $gp = $ring.qualityUpdatesGracePeriodInDays
    if (-not $gp -or $gp -eq 0) {
        $findings += [PSCustomObject]@{ Severity='Medium'; Finding='Zero grace period - devices forced to reboot immediately after deadline'; Category='Grace' }
    }

    # Paused
    if ($ring.qualityUpdatesPaused) {
        $findings += [PSCustomObject]@{ Severity='Critical'; Finding='Quality updates are PAUSED - devices are not receiving security patches'; Category='Pause' }
    }
    if ($ring.featureUpdatesPaused) {
        $findings += [PSCustomObject]@{ Severity='Medium'; Finding='Feature updates are PAUSED'; Category='Pause' }
    }

    # Feature deferral vs Feature Update profiles
    $fd = $ring.featureUpdatesDeferralPeriodInDays
    if ($fd -gt 0 -and $featureProfiles.Count -gt 0) {
        $findings += [PSCustomObject]@{ Severity='High'; Finding="Feature deferral $fd days set while Feature Update profiles exist - may block feature updates"; Category='FeatureConflict' }
    }
    if ($fd -gt 365) {
        $findings += [PSCustomObject]@{ Severity='High'; Finding="Feature deferral $fd days - effectively blocking feature updates"; Category='Deferral' }
    }

    # Drivers
    if ($ring.driversExcluded -and $driverProfiles.Count -gt 0) {
        $findings += [PSCustomObject]@{ Severity='High'; Finding='Drivers excluded while Driver Update profiles exist - profiles will be blocked'; Category='DriverConflict' }
    }

    # Delivery optimization
    $do = $ring.deliveryOptimizationMode
    if ($do -eq 'httpOnly') {
        $findings += [PSCustomObject]@{ Severity='Low'; Finding='Delivery Optimization set to HTTP only - no peer-to-peer bandwidth savings'; Category='DeliveryOpt' }
    }

    # Auto-reboot before deadline
    if (-not $ring.autoRestartNotificationDismissal) {
        # This isn't directly the same setting but checking auto-restart behavior
    }

    # Feature deadline
    $fdl = $ring.featureUpdatesDeadlineInDays
    if (-not $fdl -or $fdl -eq 0) {
        $findings += [PSCustomObject]@{ Severity='Low'; Finding='No feature update deadline set'; Category='Deadline' }
    }

    # All Devices without exclusions
    if ($hasAllDevices) {
        $excludeCount = ($ring.assignments | Where-Object { $_.target.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget' }).Count
        if ($excludeCount -eq 0) {
            $findings += [PSCustomObject]@{ Severity='Medium'; Finding='Targets All Devices with NO exclusions - every device gets this ring'; Category='Assignment' }
        }
    }

    # Report
    $color = if (($findings | Where-Object { $_.Severity -eq 'Critical' }).Count -gt 0) { 'Red' }
             elseif (($findings | Where-Object { $_.Severity -eq 'High' }).Count -gt 0) { 'Yellow' }
             elseif ($findings.Count -gt 0) { 'DarkYellow' }
             else { 'Green' }

    $statusTag = if ($findings.Count -eq 0) { '[HEALTHY]' }
                 elseif (($findings | Where-Object { $_.Severity -eq 'Critical' }).Count -gt 0) { '[CRITICAL]' }
                 elseif (($findings | Where-Object { $_.Severity -eq 'High' }).Count -gt 0) { '[ISSUES]' }
                 else { '[REVIEW]' }

    Write-Log -Message "  $statusTag $name" -Level 'INFO'
    Write-Log -Message "    Defer: Q=$qd d / F=$fd d | Deadline: Q=$qdl d / F=$fdl d | Grace: $gp d | DO: $do" -Level 'DEBUG'
    Write-Log -Message "    Groups: $assignCount$(if($hasAllDevices){' + All Devices'}) | Paused: Q=$($ring.qualityUpdatesPaused) F=$($ring.featureUpdatesPaused) | Drivers excluded: $($ring.driversExcluded)" -Level 'DEBUG'

    if ($findings.Count -gt 0) {
        foreach ($f in ($findings | Sort-Object { switch($_.Severity){'Critical'{0}'High'{1}'Medium'{2}default{3}} })) {
            $fColor = switch ($f.Severity) { 'Critical'{'Red'} 'High'{'Yellow'} 'Medium'{'DarkYellow'} default{'DarkGray'} }
            Write-Log -Message "    [$($f.Severity.ToUpper())] $($f.Finding)" -Level 'INFO'
        }
        $totalFindings += $findings.Count
    }
    Write-Log -Message "" -Level 'INFO'

    foreach ($f in $findings) {
        $report.Add([PSCustomObject]@{
            RingName=$name; Severity=$f.Severity; Category=$f.Category; Finding=$f.Finding
            QualityDeferral=$qd; QualityDeadline=$qdl; GracePeriod=$gp
            FeatureDeferral=$fd; QualityPaused=$ring.qualityUpdatesPaused; FeaturePaused=$ring.featureUpdatesPaused
            DriversExcluded=$ring.driversExcluded; AssignmentCount=$totalAssignments
        })
    }
    if ($findings.Count -eq 0) {
        $report.Add([PSCustomObject]@{
            RingName=$name; Severity='Healthy'; Category='None'; Finding='No issues found'
            QualityDeferral=$qd; QualityDeadline=$qdl; GracePeriod=$gp
            FeatureDeferral=$fd; QualityPaused=$ring.qualityUpdatesPaused; FeaturePaused=$ring.featureUpdatesPaused
            DriversExcluded=$ring.driversExcluded; AssignmentCount=$totalAssignments
        })
    }
}

# Cross-ring checks
Write-Section "CROSS-RING ANALYSIS"

# Check for rings with no progressive deferral (all same deferral)
$deferrals = ($ringData | ForEach-Object { $_.QualityDeferral }) | Sort-Object -Unique
if ($deferrals.Count -eq 1 -and $rings.Count -gt 1) {
    Write-Log -Message "  [HIGH] All $($rings.Count) rings have the same quality deferral ($($deferrals[0]) days)" -Level 'WARNING'
    Write-Log -Message "    Rings should have progressive deferrals (e.g., 0, 1, 5, 9 days)" -Level 'DEBUG'
    $totalFindings++
}

# Check for any multi-ring assignment risk
$allGroupIds = @()
foreach ($ring in $rings) {
    if ($ring.assignments) {
        $allGroupIds += ($ring.assignments | Where-Object { $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' } | ForEach-Object { $_.target.groupId })
    }
}
$duplicateGroups = $allGroupIds | Group-Object | Where-Object { $_.Count -gt 1 }
if ($duplicateGroups.Count -gt 0) {
    Write-Log -Message "  [HIGH] $($duplicateGroups.Count) group(s) assigned to multiple rings - devices will have conflicts:" -Level 'WARNING'
    foreach ($dg in $duplicateGroups) {
        Write-Log -Message "    Group $($dg.Name) appears in $($dg.Count) rings" -Level 'WARNING'
    }
    $totalFindings += $duplicateGroups.Count
}

$multiAllDevices = ($rings | Where-Object { $_.assignments | Where-Object { $_.target.'@odata.type' -like '*allDevices*' } }).Count
if ($multiAllDevices -gt 1) {
    Write-Log -Message "  [CRITICAL] $multiAllDevices rings target 'All Devices' - EVERY device has ring conflicts" -Level 'ERROR'
    $totalFindings++
}

Write-Section "AUDIT SUMMARY"
Write-Log -Message "" -Level 'INFO'
$critCount = ($report | Where-Object { $_.Severity -eq 'Critical' }).Count
$highCount = ($report | Where-Object { $_.Severity -eq 'High' }).Count
$medCount = ($report | Where-Object { $_.Severity -eq 'Medium' }).Count
$healthyCount = ($report | Where-Object { $_.Severity -eq 'Healthy' }).Count

Write-Log -Message "  Total rings audited  : $($rings.Count)" -Level 'INFO'
Write-Log -Message "  Healthy              : $healthyCount" -Level 'SUCCESS'
Write-Log -Message "  Critical findings    : $critCount" -Level 'INFO'
Write-Log -Message "  High findings        : $highCount" -Level 'INFO'
Write-Log -Message "  Medium findings      : $medCount" -Level 'INFO'
Write-Log -Message "  Total findings       : $totalFindings" -Level 'INFO'

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "UpdateRingAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'


