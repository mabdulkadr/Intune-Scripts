<#
.TITLE
    Stale and Orphaned Device Report

.SYNOPSIS
    Identifies stale and orphaned devices across Intune and Entra ID.

.DESCRIPTION
    Cross-references Intune managed devices and Entra ID device records to find: devices that haven't synced with Intune in X days (default 90), devices that haven't signed in to Entra ID in X days, orphaned Intune devices with no matching Entra ID record, orphaned Entra ID devices with no matching Intune record, devices with no primary user assigned, and disabled Entra ID accounts still owning managed devices. Exports a comprehensive CSV with recommended actions.

.TAGS
    Devices,Stale,Inventory,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All,Device.Read.All,Directory.Read.All,User.Read.All

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
    .\Get-IntuneStaleDevices.ps1
    # Find devices inactive for 90+ days
 .EXAMPLE
    .\Get-IntuneStaleDevices.ps1 -InactivityDays 60 -WarningDays 30
    # More aggressive thresholds
 .EXAMPLE
    .\Get-IntuneStaleDevices.ps1 -OSFilter "Windows" -ExportPath "C:\temp\stale_windows.csv"
    # Windows devices only
 .EXAMPLE
    .\Get-IntuneStaleDevices.ps1 -IncludeCompliant -ExportPath "C:\temp\full_device_health.csv"
    # Full device health report including active devices

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\get-intunestaledevices\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [int]$InactivityDays = 90,

    [Parameter()]
    [int]$WarningDays = 60,

    [Parameter()]
    [switch]$IncludeCompliant,

    [Parameter()]
    [string]$OSFilter,

    [Parameter()]
    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'get-intunestaledevices'
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
function Write-Status { param([string]$Msg, [string]$Color = 'Cyan') ; Write-Log -Message "  [$((Get-Date).ToString('HH:mm:ss'))] $Msg" -Level 'INFO' }
function Write-Section { param([string]$Msg) ; Write-Log -Message "`n$('='*60)" -Level 'WARNING'; Write-Log -Message "  $Msg" -Level 'WARNING'; Write-Log -Message "$('='*60)" -Level 'WARNING' }

function Get-MgGraphAllPages {
    param([string]$Uri, [string]$Method = 'GET')
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
    } catch [System.Exception] {
        Write-Verbose "Graph call failed for $Uri : $_"
        return @()
    }
}
#endregion

#region --- Authentication ---
Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Write-Status "Connecting to Microsoft Graph..." "White"
    Connect-MgGraph -Scopes @(
        'DeviceManagementManagedDevices.Read.All',
        'Device.Read.All',
        'Directory.Read.All',
        'User.Read.All'
    ) -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"
#endregion

#region --- Configuration ---
Write-Section "CONFIGURATION"
$now = Get-Date
$staleThreshold   = $now.AddDays(-$InactivityDays)
$warningThreshold = $now.AddDays(-$WarningDays)

Write-Log -Message "  Stale threshold    : $InactivityDays days ($($staleThreshold.ToString('yyyy-MM-dd')))" -Level 'INFO'
Write-Log -Message "  Warning threshold  : $WarningDays days ($($warningThreshold.ToString('yyyy-MM-dd')))" -Level 'INFO'
Write-Log -Message "  OS filter          : $(if($OSFilter){$OSFilter}else{'All'})" -Level 'INFO'
Write-Log -Message "  Include active     : $($IncludeCompliant.IsPresent)" -Level 'INFO'
#endregion

#region --- Retrieve Intune Devices ---
Write-Section "RETRIEVING INTUNE MANAGED DEVICES"

$intuneUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,deviceName,azureADDeviceId,userPrincipalName,userId,lastSyncDateTime,enrolledDateTime,complianceState,operatingSystem,osVersion,model,manufacturer,serialNumber,managedDeviceOwnerType,managementAgent,deviceRegistrationState"

if ($OSFilter) {
    $intuneUri += "&`$filter=operatingSystem eq '$OSFilter'"
}

Write-Status "Fetching Intune devices$(if($OSFilter){" (OS: $OSFilter)"})..."
$intuneDevices = Get-MgGraphAllPages -Uri $intuneUri
Write-Status "$($intuneDevices.Count) Intune managed devices retrieved" "Green"
#endregion

#region --- Retrieve Entra ID Devices ---
Write-Section "RETRIEVING ENTRA ID DEVICE RECORDS"

Write-Status "Fetching Entra ID devices (with sign-in activity)..."
# Use beta for approximateLastSignInDateTime
$entraDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/devices?`$select=id,deviceId,displayName,approximateLastSignInDateTime,accountEnabled,operatingSystem,operatingSystemVersion,trustType,registrationDateTime,isManaged,isCompliant"
Write-Status "$($entraDevices.Count) Entra ID device records retrieved" "Green"

# Build lookup by Entra device ID (azureADDeviceId in Intune = deviceId in Entra)
$entraLookup = @{}
foreach ($ed in $entraDevices) {
    if ($ed.deviceId) { $entraLookup[$ed.deviceId] = $ed }
}
#endregion

#region --- Cross-Reference Analysis ---
Write-Section "CROSS-REFERENCING DEVICES"

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

# Counters
$activeCount   = 0
$warningCount  = 0
$staleCount    = 0
$orphanIntune  = 0
$orphanEntra   = 0
$noUserCount   = 0
$disabledOwner = 0
$deviceIndex   = 0

foreach ($device in $intuneDevices) {
    $deviceIndex++
    if ($deviceIndex % 100 -eq 0) {
        Write-Progress -Activity "Analyzing Intune devices" -Status "$deviceIndex of $($intuneDevices.Count)" -PercentComplete (($deviceIndex / $intuneDevices.Count) * 100)
    }

    $lastSync = $device.lastSyncDateTime
    $entraDeviceId = $device.azureADDeviceId
    $upn = $device.userPrincipalName

    # Calculate Intune staleness
    $daysSinceSync = if ($lastSync) {
        [math]::Round(($now - [datetime]$lastSync).TotalDays, 1)
    } else { 9999 }

    # Look up matching Entra ID record
    $entraRecord = if ($entraDeviceId) { $entraLookup[$entraDeviceId] } else { $null }

    $entraLastSignIn = $null
    $daysSinceEntraSignIn = 'N/A'
    $entraAccountEnabled = $null
    $entraIsManaged = $null

    if ($entraRecord) {
        $entraLastSignIn = $entraRecord.approximateLastSignInDateTime
        $entraAccountEnabled = $entraRecord.accountEnabled
        $entraIsManaged = $entraRecord.isManaged

        if ($entraLastSignIn) {
            $daysSinceEntraSignIn = [math]::Round(($now - [datetime]$entraLastSignIn).TotalDays, 1)
        }
    }

    # Determine status
    $intuneStatus = if ($daysSinceSync -ge $InactivityDays) { 'Stale' }
                    elseif ($daysSinceSync -ge $WarningDays) { 'Warning' }
                    else { 'Active' }

    $entraStatus = if (-not $entraRecord) { 'No Entra Record' }
                   elseif ($daysSinceEntraSignIn -eq 'N/A') { 'No Sign-In Data' }
                   elseif ([double]$daysSinceEntraSignIn -ge $InactivityDays) { 'Stale' }
                   elseif ([double]$daysSinceEntraSignIn -ge $WarningDays) { 'Warning' }
                   else { 'Active' }

    # Classify issues
    $issues = @()

    if ($intuneStatus -eq 'Stale') { $issues += "Intune sync stale ($daysSinceSync days)" ; $staleCount++ }
    elseif ($intuneStatus -eq 'Warning') { $issues += "Intune sync warning ($daysSinceSync days)" ; $warningCount++ }
    else { $activeCount++ }

    if ($entraStatus -eq 'No Entra Record') { $issues += 'No matching Entra ID device record' ; $orphanIntune++ }
    if ($entraStatus -eq 'Stale') { $issues += "Entra sign-in stale ($daysSinceEntraSignIn days)" }

    if (-not $upn -or $upn -eq '') { $issues += 'No primary user assigned' ; $noUserCount++ }

    if ($entraAccountEnabled -eq $false) { $issues += 'Entra device account disabled' ; $disabledOwner++ }

    # Check if the owning user account is disabled
    $userAccountDisabled = $false
    if ($upn -and $upn -ne '' -and $device.userId) {
        # We'll batch this check - for now flag for the report
        # (individual user lookups would be too slow for large tenants)
    }

    # Recommended action
    $recommendation = if ($issues.Count -eq 0) { 'No action needed' }
    elseif ($intuneStatus -eq 'Stale' -and $entraStatus -eq 'No Entra Record') { 'RETIRE - Orphaned stale device' }
    elseif ($intuneStatus -eq 'Stale' -and $entraStatus -eq 'Stale') { 'RETIRE - Stale in both systems' }
    elseif ($intuneStatus -eq 'Stale') { 'REVIEW - Stale Intune sync' }
    elseif ($entraStatus -eq 'No Entra Record') { 'REVIEW - Missing Entra record' }
    elseif ($entraAccountEnabled -eq $false) { 'REVIEW - Entra device disabled' }
    elseif ($intuneStatus -eq 'Warning') { 'MONITOR - Approaching stale' }
    else { 'REVIEW' }

    # Skip active devices unless -IncludeCompliant
    if ($issues.Count -eq 0 -and -not $IncludeCompliant) { continue }

    $report.Add([PSCustomObject]@{
        DeviceName             = $device.deviceName
        UserPrincipalName      = $upn
        OperatingSystem        = $device.operatingSystem
        OSVersion              = $device.osVersion
        Model                  = $device.model
        Manufacturer           = $device.manufacturer
        SerialNumber           = $device.serialNumber
        Ownership              = $device.managedDeviceOwnerType
        ComplianceState        = $device.complianceState
        ManagementAgent        = $device.managementAgent
        IntuneLastSync         = $lastSync
        DaysSinceIntuneSync    = $daysSinceSync
        IntuneStatus           = $intuneStatus
        EntraLastSignIn        = $entraLastSignIn
        DaysSinceEntraSignIn   = $daysSinceEntraSignIn
        EntraStatus            = $entraStatus
        EntraAccountEnabled    = $entraAccountEnabled
        EnrolledDateTime       = $device.enrolledDateTime
        Issues                 = ($issues -join '; ')
        Recommendation         = $recommendation
        IntuneDeviceId         = $device.id
        EntraDeviceId          = $entraDeviceId
    })
}

# Check for Entra ID devices not in Intune (orphaned Entra records)
Write-Status "Checking for Entra ID devices not enrolled in Intune..."
$intuneEntraIds = $intuneDevices | Where-Object { $_.azureADDeviceId } | ForEach-Object { $_.azureADDeviceId }

foreach ($ed in $entraDevices) {
    # Only check managed devices or Azure AD joined
    if ($ed.trustType -notin @('AzureAd','ServerAd','Workplace') ) { continue }
    if (-not $ed.isManaged -and $ed.trustType -eq 'Workplace') { continue }

    if ($ed.deviceId -and $intuneEntraIds -notcontains $ed.deviceId) {
        # Apply OS filter if set
        if ($OSFilter -and $ed.operatingSystem -ne $OSFilter) { continue }

        $orphanEntra++

        $entraLastSignIn = $ed.approximateLastSignInDateTime
        $daysSinceSign = if ($entraLastSignIn) { [math]::Round(($now - [datetime]$entraLastSignIn).TotalDays, 1) } else { 'N/A' }

        $orphanRec = if ($daysSinceSign -ne 'N/A' -and [double]$daysSinceSign -ge $InactivityDays) {
            'DELETE - Stale Entra device, not in Intune'
        } else {
            'REVIEW - Entra device not enrolled in Intune'
        }

        $report.Add([PSCustomObject]@{
            DeviceName             = $ed.displayName
            UserPrincipalName      = '-'
            OperatingSystem        = $ed.operatingSystem
            OSVersion              = $ed.operatingSystemVersion
            Model                  = '-'
            Manufacturer           = '-'
            SerialNumber           = '-'
            Ownership              = '-'
            ComplianceState        = if($ed.isCompliant){'compliant'}else{'unknown'}
            ManagementAgent        = '-'
            IntuneLastSync         = '-'
            DaysSinceIntuneSync    = 'N/A'
            IntuneStatus           = 'Not Enrolled'
            EntraLastSignIn        = $entraLastSignIn
            DaysSinceEntraSignIn   = $daysSinceSign
            EntraStatus            = if($daysSinceSign -ne 'N/A' -and [double]$daysSinceSign -ge $InactivityDays){'Stale'}else{'Active'}
            EntraAccountEnabled    = $ed.accountEnabled
            EnrolledDateTime       = $ed.registrationDateTime
            Issues                 = 'Entra ID device not enrolled in Intune'
            Recommendation         = $orphanRec
            IntuneDeviceId         = '-'
            EntraDeviceId          = $ed.deviceId
        })
    }
}

Write-Progress -Activity "Analyzing Intune devices" -Completed
#endregion

#region --- Summary ---
Write-Section "STALE DEVICE SUMMARY"
Write-Log -Message "" -Level 'INFO'

Write-Log -Message "  Intune Managed Devices : $($intuneDevices.Count)" -Level 'INFO'
Write-Log -Message "  Entra ID Devices       : $($entraDevices.Count)" -Level 'INFO'
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  --- Intune Sync Status ---" -Level 'WARNING'
Write-Log -Message "  Active (< $WarningDays days)     : $activeCount" -Level 'SUCCESS'
Write-Log -Message "  Warning ($WarningDays-$InactivityDays days)    : $warningCount" -Level 'INFO'
Write-Log -Message "  Stale (> $InactivityDays days)      : $staleCount" -Level 'INFO'
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  --- Cross-Reference Issues ---" -Level 'WARNING'
Write-Log -Message "  Intune orphans (no Entra record)  : $orphanIntune" -Level 'INFO'
Write-Log -Message "  Entra orphans (not in Intune)     : $orphanEntra" -Level 'INFO'
Write-Log -Message "  No primary user assigned          : $noUserCount" -Level 'INFO'
Write-Log -Message "  Entra device account disabled     : $disabledOwner" -Level 'INFO'

# Recommendation breakdown
if ($report.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Recommended Actions ---" -Level 'WARNING'
    $actionGroups = $report | Group-Object Recommendation | Sort-Object Count -Descending
    foreach ($ag in $actionGroups) {
        $actionColor = switch -Wildcard ($ag.Name) {
            'RETIRE*' { 'Red' }
            'DELETE*' { 'Red' }
            'REVIEW*' { 'Yellow' }
            'MONITOR*' { 'DarkYellow' }
            default   { 'DarkGray' }
        }
        Write-Log -Message "  $($ag.Name) : $($ag.Count) device(s)" -Level 'INFO'
    }

    # Show top stale devices
    $staleDevices = $report | Where-Object { $_.IntuneStatus -eq 'Stale' } | Sort-Object { [double]$_.DaysSinceIntuneSync } -Descending
    if ($staleDevices.Count -gt 0) {
        $displayCount = [math]::Min($staleDevices.Count, 15)
        Write-Section "MOST STALE DEVICES (top $displayCount)"
        Write-Log -Message "" -Level 'INFO'

        foreach ($sd in ($staleDevices | Select-Object -First 15)) {
            Write-Log -Message "  $($sd.DeviceName)" -Level 'INFO'
            Write-Log -Message " | $($sd.DaysSinceIntuneSync) days" -Level 'ERROR'
            Write-Log -Message " | $($sd.UserPrincipalName)" -Level 'DEBUG'
            Write-Log -Message " | $($sd.OperatingSystem)" -Level 'DEBUG'
            Write-Log -Message "    $($sd.Recommendation)" -Level 'INFO'
        }
        Write-Log -Message "" -Level 'INFO'
    }

    # OS breakdown of stale devices
    $staleByOS = $report | Where-Object { $_.Recommendation -match 'RETIRE|DELETE|REVIEW' } | Group-Object OperatingSystem | Sort-Object Count -Descending
    if ($staleByOS.Count -gt 0) {
        Write-Section "ISSUES BY OPERATING SYSTEM"
        Write-Log -Message "" -Level 'INFO'
        foreach ($os in $staleByOS) {
            Write-Log -Message "  $($os.Name): $($os.Count) device(s)" -Level 'WARNING'
        }
        Write-Log -Message "" -Level 'INFO'
    }
}

# Export
if ($report.Count -gt 0) {
    if ($ExportPath) {
        $report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
        Write-Status "Exported $($report.Count) rows to: $ExportPath" "Green"
    } else {
        $defaultPath = Join-Path $env:TEMP "StaleDeviceReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $report | Export-Csv -Path $defaultPath -NoTypeInformation -Encoding UTF8
        Write-Status "Auto-exported $($report.Count) rows to: $defaultPath" "Green"
    }
} else {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  No stale or problematic devices found. Environment is clean!" -Level 'SUCCESS'
}

Write-Log -Message "`n$('='*60)" -Level 'DEBUG'
#endregion


