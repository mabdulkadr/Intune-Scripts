<#
.TITLE
    Intune App Status Report

.SYNOPSIS
    Generates a detailed Intune app installation status report showing deployment results per app per device with failure reasons.

.DESCRIPTION
    Queries Microsoft Graph to retrieve app installation status across managed devices. Shows
    which apps succeeded, failed, or are pending installation, including error codes, failure
    reasons, and install state details. Supports filtering by a single app, a single device,
    or all assigned apps.

.TAGS
    Intune,Apps,Deployment,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementApps.Read.All,DeviceManagementManagedDevices.Read.All,Device.Read.All,Directory.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.1.0

.CHANGELOG
    1.1.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, banner, ErrorActionPreference, full cmdlet names, typed catches)
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Get-IntuneAppStatusReport.ps1
    All assigned apps - failed installations only

.EXAMPLE
    .\Get-IntuneAppStatusReport.ps1 -AppName "Microsoft Teams"
    Status for a specific app across all devices

.EXAMPLE
    .\Get-IntuneAppStatusReport.ps1 -DeviceName "L-PF4Z0HM0" -IncludeAll
    All app statuses for a single device

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Large tenants may take several minutes
    - Logs: %ProgramData%\get-intune-app-status-report\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = 'AllApps')]
param(
    [Parameter(ParameterSetName = 'ByApp')]
    [string]$AppName,

    [Parameter(ParameterSetName = 'ByDevice')]
    [string]$DeviceName,

    [Parameter()]
    [switch]$IncludeAll,

    [Parameter()]
    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-intune-app-status-report'
$ScriptMode   = 'run'

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
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
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
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
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
# Flow: init -> banner -> modules -> Graph connection -> report generation.
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started" -Level 'INFO'
# ============================================================================
# REPORT OUTPUT ANCHORING
# Anchor relative output paths beside the script so CSV exports land in a
# predictable location regardless of the caller's current directory.
# Fallback chain: $PSScriptRoot -> $PSCommandPath -> $MyInvocation -> Get-Location.
# ============================================================================

$scriptDirectory = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).Path
}

if ($ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = [System.IO.Path]::GetFullPath((Join-Path $scriptDirectory $ExportPath))
}

#region --- Helpers ---
function Write-Status { param([string]$Msg,[string]$Color='Cyan'); $level = switch ($Color) { 'Red'{'ERROR'} 'Yellow'{'WARNING'} 'Green'{'SUCCESS'} 'DarkYellow'{'WARNING'} 'DarkGray'{'DEBUG'} default{'INFO'} }; Write-Log -Message $Msg -Level $level }
function Write-Section { param([string]$Msg); Write-Log -Message "=== $Msg ===" -Level 'INFO' }

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
    }
    catch [System.Exception] {
        Write-Verbose "Graph call failed for $Uri : $_"
        return @()
    }
}

function Get-FriendlyInstallState {
    param([string]$State)
    switch ($State) {
        'installed'              { 'Installed' }
        'failed'                 { 'Failed' }
        'notInstalled'           { 'Not Installed' }
        'uninstallFailed'        { 'Uninstall Failed' }
        'pendingInstall'         { 'Pending Install' }
        'unknown'                { 'Unknown' }
        'notApplicable'          { 'Not Applicable' }
        'installError'           { 'Install Error' }
        default                  { $State }
    }
}

function Get-InstallStateColor {
    param([string]$State)
    switch ($State) {
        'installed'         { 'Green' }
        'failed'            { 'Red' }
        'installError'      { 'Red' }
        'uninstallFailed'   { 'Red' }
        'notInstalled'      { 'Yellow' }
        'pendingInstall'    { 'DarkYellow' }
        'notApplicable'     { 'DarkGray' }
        default             { 'Gray' }
    }
}
#endregion

#region --- Authentication ---
Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Write-Status "Connecting to Microsoft Graph..." "White"
    Connect-MgGraph -Scopes @(
        'DeviceManagementApps.Read.All',
        'DeviceManagementManagedDevices.Read.All',
        'Device.Read.All',
        'Directory.Read.All'
    ) -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"
#endregion

#region --- Resolve Scope ---
Write-Section "RESOLVING SCOPE"

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

if ($DeviceName) {
    # --- Single Device Mode ---
    Write-Status "Looking up device: $DeviceName"
    $devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$DeviceName'&`$select=id,deviceName,userPrincipalName,operatingSystem,osVersion,complianceState"
    if ($devices.Count -eq 0) {
        Write-Log -Message "  ERROR: Device '$DeviceName' not found in Intune." -Level 'ERROR'
        return
    }
    $device = $devices[0]
    Write-Status "Device found: $($device.deviceName) ($($device.operatingSystem))" "Green"

    Write-Section "APP INSTALLATION STATUS FOR: $($device.deviceName)"

    # Get all app statuses for this device
    $appStatuses = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/detectedApps"
    
    # Use device install status from managed apps
    Write-Status "Retrieving app installation states for device..."
    
    # Get assigned apps and their device statuses
    $assignedApps = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=isAssigned eq true&`$select=id,displayName,@odata.type"
    Write-Status "Checking $($assignedApps.Count) assigned apps..."

    $appIndex = 0
    foreach ($app in $assignedApps) {
        $appIndex++
        if ($appIndex % 25 -eq 0) {
            Write-Progress -Activity "Checking app statuses" -Status "$appIndex of $($assignedApps.Count) - $($app.displayName)" -PercentComplete (($appIndex / $assignedApps.Count) * 100)
        }

        # Get device status for this specific app
        $deviceStatuses = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)/deviceStatuses?`$filter=deviceId eq '$($device.id)'"

        foreach ($ds in $deviceStatuses) {
            $installState = $ds.installState
            if (-not $installState) { $installState = $ds.installStateDetail }

            # Filter to failures unless IncludeAll
            if (-not $IncludeAll -and $installState -in @('installed','notApplicable','unknown')) { continue }

            $errorCode = $ds.errorCode
            $errorDesc = if ($ds.installStateDetail) { $ds.installStateDetail } else { '-' }

            $report.Add([PSCustomObject]@{
                AppName           = $app.displayName
                AppType           = ($app.'@odata.type' -replace '#microsoft.graph.','')
                DeviceName        = $device.deviceName
                UserPrincipalName = $ds.userPrincipalName
                InstallState      = Get-FriendlyInstallState $installState
                InstallStateRaw   = $installState
                ErrorCode         = if ($errorCode -and $errorCode -ne 0) { "0x{0:X8}" -f $errorCode } else { '-' }
                ErrorCodeDec      = if ($errorCode -and $errorCode -ne 0) { $errorCode } else { '-' }
                InstallDetail     = $errorDesc
                LastModified      = $ds.lastSyncDateTime
                DeviceId          = $device.id
                AppId             = $app.id
            })
        }
    }
    Write-Progress -Activity "Checking app statuses" -Completed

} else {
    # --- All Apps or Filtered by App Name ---
    Write-Status "Retrieving assigned apps..."
    $apps = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=isAssigned eq true&`$select=id,displayName,@odata.type,isAssigned"

    if ($AppName) {
        $apps = $apps | Where-Object { $_.displayName -like "*$AppName*" }
        if ($apps.Count -eq 0) {
            Write-Log -Message "  ERROR: No assigned apps found matching '$AppName'." -Level 'ERROR'
            return
        }
        Write-Status "Found $($apps.Count) app(s) matching '$AppName'" "Green"
    } else {
        Write-Status "Found $($apps.Count) assigned apps" "Green"
    }

    Write-Section "SCANNING APP INSTALLATION STATUSES"

    $appIndex = 0
    foreach ($app in $apps) {
        $appIndex++
        $pctComplete = [math]::Round(($appIndex / $apps.Count) * 100)
        Write-Progress -Activity "Scanning app deployment status" -Status "$appIndex of $($apps.Count) - $($app.displayName)" -PercentComplete $pctComplete

        # Get device statuses for this app
        $deviceStatuses = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)/deviceStatuses"

        if ($deviceStatuses.Count -eq 0) { continue }

        foreach ($ds in $deviceStatuses) {
            $installState = $ds.installState
            if (-not $installState) { $installState = $ds.installStateDetail }

            # Filter to failures unless IncludeAll
            if (-not $IncludeAll -and $installState -in @('installed','notApplicable','unknown')) { continue }

            $errorCode = $ds.errorCode
            $errorDesc = if ($ds.installStateDetail) { $ds.installStateDetail } else { '-' }

            $report.Add([PSCustomObject]@{
                AppName           = $app.displayName
                AppType           = ($app.'@odata.type' -replace '#microsoft.graph.','')
                DeviceName        = $ds.deviceName
                UserPrincipalName = $ds.userPrincipalName
                InstallState      = Get-FriendlyInstallState $installState
                InstallStateRaw   = $installState
                ErrorCode         = if ($errorCode -and $errorCode -ne 0) { "0x{0:X8}" -f $errorCode } else { '-' }
                ErrorCodeDec      = if ($errorCode -and $errorCode -ne 0) { $errorCode } else { '-' }
                InstallDetail     = $errorDesc
                LastModified      = $ds.lastSyncDateTime
                DeviceId          = $ds.deviceId
                AppId             = $app.id
            })
        }

        # Show progress for current app
        $failedForApp = ($deviceStatuses | Where-Object { $_.installState -in @('failed','installError','uninstallFailed') }).Count
        if ($failedForApp -gt 0) {
            Write-Log -Message "    $($app.displayName)" -Level 'INFO'
            Write-Log -Message " - $failedForApp failure(s)" -Level 'ERROR'
        }
    }
    Write-Progress -Activity "Scanning app deployment status" -Completed
}
#endregion

#region --- Summary ---
Write-Section "APP DEPLOYMENT SUMMARY"
Write-Log -Message "" -Level 'INFO'

if ($report.Count -eq 0) {
    if ($IncludeAll) {
        Write-Log -Message "  No app installation records found for the specified scope." -Level 'DEBUG'
    } else {
        Write-Log -Message "  No app installation failures found. All deployments are healthy!" -Level 'SUCCESS'
        Write-Log -Message "  Use -IncludeAll to see all installation states." -Level 'DEBUG'
    }
} else {
    # State breakdown
    $stateGroups = $report | Group-Object InstallState | Sort-Object Count -Descending
    Write-Log -Message "  Installation State Breakdown:" -Level 'INFO'
    foreach ($sg in $stateGroups) {
        $stateColor = switch ($sg.Name) {
            'Installed'       { 'Green' }
            'Failed'          { 'Red' }
            'Install Error'   { 'Red' }
            'Uninstall Failed'{ 'Red' }
            'Not Installed'   { 'Yellow' }
            'Pending Install' { 'DarkYellow' }
            default           { 'Gray' }
        }
        Write-Log -Message "    $($sg.Name) : $($sg.Count)" -Level 'INFO'
    }
    Write-Log -Message "" -Level 'INFO'

    # Top failing apps
    $failedEntries = $report | Where-Object { $_.InstallState -in @('Failed','Install Error','Uninstall Failed') }
    if ($failedEntries.Count -gt 0) {
        Write-Section "TOP FAILING APPS"
        Write-Log -Message "" -Level 'INFO'
        $appFailRanking = $failedEntries | Group-Object AppName | Sort-Object Count -Descending | Select-Object -First 15

        foreach ($af in $appFailRanking) {
            $uniqueDevices = ($af.Group | Select-Object -Property DeviceName -Unique).Count
            Write-Log -Message "  $($af.Name)" -Level 'WARNING'
            Write-Log -Message "    $($af.Count) failure(s) across $uniqueDevices device(s)" -Level 'INFO'

            # Show top error codes for this app
            $errorCodes = $af.Group | Where-Object { $_.ErrorCode -ne '-' } | Group-Object ErrorCode | Sort-Object Count -Descending | Select-Object -First 3
            foreach ($ec in $errorCodes) {
                Write-Log -Message "      Error $($ec.Name) : $($ec.Count) occurrence(s)" -Level 'DEBUG'
            }
        }
        Write-Log -Message "" -Level 'INFO'

        # Top error codes overall
        $allErrors = $failedEntries | Where-Object { $_.ErrorCode -ne '-' } | Group-Object ErrorCode | Sort-Object Count -Descending | Select-Object -First 10
        if ($allErrors.Count -gt 0) {
            Write-Section "TOP ERROR CODES"
            Write-Log -Message "" -Level 'INFO'
            foreach ($err in $allErrors) {
                $affectedApps = ($err.Group | Select-Object -Property AppName -Unique | ForEach-Object { $_.AppName }) -join ', '
                $truncApps = if ($affectedApps.Length -gt 80) { $affectedApps.Substring(0,77) + '...' } else { $affectedApps }
                Write-Log -Message "  $($err.Name) : $($err.Count) occurrence(s)" -Level 'WARNING'
                Write-Log -Message "    Apps: $truncApps" -Level 'DEBUG'
            }
            Write-Log -Message "" -Level 'INFO'
        }

        # Devices with most failures
        $deviceFailRanking = $failedEntries | Group-Object DeviceName | Sort-Object Count -Descending | Select-Object -First 10
        if ($deviceFailRanking.Count -gt 0) {
            Write-Section "DEVICES WITH MOST APP FAILURES"
            Write-Log -Message "" -Level 'INFO'
            foreach ($df in $deviceFailRanking) {
                $upn = ($df.Group | Select-Object -First 1).UserPrincipalName
                Write-Log -Message "  $($df.Name)" -Level 'INFO'
                Write-Log -Message " ($upn)" -Level 'INFO'
                Write-Log -Message " - $($df.Count) failed app(s)" -Level 'ERROR'
            }
            Write-Log -Message "" -Level 'INFO'
        }
    }

    # Pending installs
    $pendingEntries = $report | Where-Object { $_.InstallState -eq 'Pending Install' }
    if ($pendingEntries.Count -gt 0) {
        Write-Section "PENDING INSTALLATIONS ($($pendingEntries.Count))"
        Write-Log -Message "" -Level 'INFO'
        $pendingByApp = $pendingEntries | Group-Object AppName | Sort-Object Count -Descending | Select-Object -First 10
        foreach ($pa in $pendingByApp) {
            Write-Log -Message "  $($pa.Name) : $($pa.Count) device(s) pending" -Level 'WARNING'
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
        $scopeSafe = switch ($PSCmdlet.ParameterSetName) {
            'ByApp'    { ($AppName -replace '[^\w\-]','_') }
            'ByDevice' { ($DeviceName -replace '[^\w\-]','_') }
            default    { 'AllApps' }
        }
        $defaultPath = Join-Path $env:TEMP "$scopeSafe`_AppStatusReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $report | Export-Csv -Path $defaultPath -NoTypeInformation -Encoding UTF8
        Write-Status "Auto-exported $($report.Count) rows to: $defaultPath" "Green"
    }
}

Write-Log -Message "`n$('='*60)" -Level 'DEBUG'
#endregion
