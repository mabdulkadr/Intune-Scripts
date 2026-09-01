<#
.TITLE
    Intune Compliance Report

.SYNOPSIS
    Generates a detailed Intune device compliance report showing non-compliant devices, the policies they failed, and the specific settings in violation.

.DESCRIPTION
    Queries Microsoft Graph to retrieve all managed devices (or a filtered subset) and their
    compliance policy states. For each non-compliant or in-grace-period device, drills into
    the specific settings that triggered the failure. Exports a flat CSV with one row per non-
    compliant setting per device.

.TAGS
    Intune,Compliance,Reporting,Security

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.Read.All,Device.Read.All,Directory.Read.All,Group.Read.All,GroupMember.Read.All

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
    .\Get-IntuneComplianceReport.ps1
    Reports all non-compliant devices across the tenant

.EXAMPLE
    .\Get-IntuneComplianceReport.ps1 -DeviceName "L-PF4Z0HM0"
    Deep-dive compliance for a single device

.EXAMPLE
    .\Get-IntuneComplianceReport.ps1 -GroupName "SG-Intune-Windows-Devices" -ExportPath "C:\temp\compliance.csv"
    Compliance report for devices in a specific group

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Large tenants may take several minutes
    - Logs: %ProgramData%\get-intune-compliance-report\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = 'All')]
param(
    [Parameter(ParameterSetName = 'All')]
    [switch]$All,

    [Parameter(Mandatory, ParameterSetName = 'ByDevice')]
    [string]$DeviceName,

    [Parameter(Mandatory, ParameterSetName = 'ByGroup')]
    [string]$GroupName,

    [Parameter()]
    [switch]$IncludeCompliant,

    [Parameter()]
    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-intune-compliance-report'
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
#endregion

#region --- Authentication ---
Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Write-Status "Connecting to Microsoft Graph..." "White"
    Connect-MgGraph -Scopes @(
        'DeviceManagementConfiguration.Read.All',
        'DeviceManagementManagedDevices.Read.All',
        'Device.Read.All',
        'Directory.Read.All',
        'Group.Read.All',
        'GroupMember.Read.All'
    ) -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"
#endregion

#region --- Resolve Device Scope ---
Write-Section "RESOLVING DEVICE SCOPE"

$targetDevices = @()

switch ($PSCmdlet.ParameterSetName) {
    'ByDevice' {
        Write-Status "Searching for device: $DeviceName"
        $targetDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$DeviceName'"
        if ($targetDevices.Count -eq 0) {
            Write-Log -Message "  ERROR: Device '$DeviceName' not found in Intune." -Level 'ERROR'
            return
        }
        Write-Status "Found device: $($targetDevices[0].deviceName)" "Green"
    }
    'ByGroup' {
        Write-Status "Resolving group: $GroupName"
        $groups = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$($GroupName -replace "'","''")'"
        if ($groups.Count -eq 0) {
            Write-Log -Message "  ERROR: Group '$GroupName' not found in Entra ID." -Level 'ERROR'
            return
        }
        $groupId = $groups[0].id
        Write-Status "Group found: $($groups[0].displayName) ($groupId)"

        # Get device members of the group
        Write-Status "Getting device members from group..."
        $groupMembers = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/members?`$select=id,deviceId,displayName"
        $deviceMembers = $groupMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' }

        if ($deviceMembers.Count -eq 0) {
            # Group might contain users - get their devices instead
            Write-Status "No device members found, checking user members' devices..."
            $userMembers = $groupMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' }
            if ($userMembers.Count -gt 0) {
                Write-Status "Found $($userMembers.Count) user members, retrieving their managed devices..."
                foreach ($um in $userMembers) {
                    $userDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=userId eq '$($um.id)'"
                    $targetDevices += $userDevices
                }
            }
        } else {
            # Map Entra device IDs to Intune managed devices
            Write-Status "Found $($deviceMembers.Count) device members, mapping to Intune..."
            foreach ($dm in $deviceMembers) {
                $entraDeviceId = $dm.deviceId
                if ($entraDeviceId) {
                    $intuneDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$entraDeviceId'"
                    $targetDevices += $intuneDevices
                }
            }
        }

        if ($targetDevices.Count -eq 0) {
            Write-Log -Message "  ERROR: No Intune managed devices found for group '$GroupName'." -Level 'ERROR'
            return
        }
        Write-Status "$($targetDevices.Count) managed devices resolved from group" "Green"
    }
    default {
        # All devices
        Write-Status "Retrieving all managed devices..."
        $targetDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,deviceName,userPrincipalName,complianceState,complianceGracePeriodExpirationDateTime,lastSyncDateTime,operatingSystem,osVersion,model,manufacturer,serialNumber,managedDeviceOwnerType,enrolledDateTime"
        Write-Status "$($targetDevices.Count) managed devices retrieved" "Green"
    }
}
#endregion

#region --- Compliance Analysis ---
Write-Section "ANALYZING COMPLIANCE STATUS"

# Summary counters
$totalDevices      = $targetDevices.Count
$compliantCount    = 0
$nonCompliantCount = 0
$inGraceCount      = 0
$unknownCount      = 0
$notEvalCount      = 0

$complianceReport = [System.Collections.Generic.List[PSCustomObject]]::new()
$deviceIndex = 0

foreach ($device in $targetDevices) {
    $deviceIndex++
    $pctComplete = [math]::Round(($deviceIndex / $totalDevices) * 100)
    Write-Progress -Activity "Analyzing device compliance" -Status "$deviceIndex of $totalDevices - $($device.deviceName)" -PercentComplete $pctComplete

    $compState = $device.complianceState
    $graceExpiry = $device.complianceGracePeriodExpirationDateTime
    $lastSync = $device.lastSyncDateTime

    # Classify device
    switch ($compState) {
        'compliant'    { $compliantCount++ }
        'noncompliant' { $nonCompliantCount++ }
        'inGracePeriod' { $inGraceCount++ }
        'configManager' { $unknownCount++ }
        'unknown'      { $unknownCount++ }
        default        { $notEvalCount++ }
    }

    # Skip compliant devices unless -IncludeCompliant is set
    if ($compState -eq 'compliant' -and -not $IncludeCompliant) { continue }

    # Calculate days since last sync
    $daysSinceSync = if ($lastSync) {
        [math]::Round(((Get-Date) - [datetime]$lastSync).TotalDays, 1)
    } else { 'N/A' }

    # Get detailed compliance policy states for this device
    $policyStates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/deviceCompliancePolicyStates"

    if ($policyStates.Count -eq 0) {
        # No compliance policies evaluated - report as a single row
        $complianceReport.Add([PSCustomObject]@{
            DeviceName        = $device.deviceName
            UserPrincipalName = $device.userPrincipalName
            OverallCompliance = $compState
            OperatingSystem   = $device.operatingSystem
            OSVersion         = $device.osVersion
            Model             = $device.model
            Manufacturer      = $device.manufacturer
            SerialNumber      = $device.serialNumber
            Ownership         = $device.managedDeviceOwnerType
            LastSyncDateTime  = $lastSync
            DaysSinceSync     = $daysSinceSync
            EnrolledDateTime  = $device.enrolledDateTime
            GraceExpiry       = $graceExpiry
            PolicyName        = '(No compliance policy assigned)'
            PolicyState       = $compState
            SettingName       = '-'
            SettingState      = '-'
            SettingDetail     = '-'
            DeviceId          = $device.id
        })
        continue
    }

    foreach ($ps in $policyStates) {
        $policyState = $ps.state
        $policyName  = $ps.displayName
        if (-not $policyName) { $policyName = "(Policy ID: $($ps.id))" }

        # For non-compliant policies, get the specific setting states
        if ($policyState -eq 'nonCompliant' -or $policyState -eq 'error' -or $policyState -eq 'conflict') {
            $settingStates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/deviceCompliancePolicyStates/$($ps.id)/settingStates"

            $nonCompliantSettings = $settingStates | Where-Object {
                $_.state -ne 'compliant' -and $_.state -ne 'notApplicable'
            }

            if ($nonCompliantSettings.Count -gt 0) {
                foreach ($ss in $nonCompliantSettings) {
                    $settingDetail = if ($ss.currentValue) { $ss.currentValue } else { '-' }

                    $complianceReport.Add([PSCustomObject]@{
                        DeviceName        = $device.deviceName
                        UserPrincipalName = $device.userPrincipalName
                        OverallCompliance = $compState
                        OperatingSystem   = $device.operatingSystem
                        OSVersion         = $device.osVersion
                        Model             = $device.model
                        Manufacturer      = $device.manufacturer
                        SerialNumber      = $device.serialNumber
                        Ownership         = $device.managedDeviceOwnerType
                        LastSyncDateTime  = $lastSync
                        DaysSinceSync     = $daysSinceSync
                        EnrolledDateTime  = $device.enrolledDateTime
                        GraceExpiry       = $graceExpiry
                        PolicyName        = $policyName
                        PolicyState       = $policyState
                        SettingName       = $ss.setting
                        SettingState      = $ss.state
                        SettingDetail     = $settingDetail
                        DeviceId          = $device.id
                    })
                }
            } else {
                # Policy is non-compliant but no specific settings flagged
                $complianceReport.Add([PSCustomObject]@{
                    DeviceName        = $device.deviceName
                    UserPrincipalName = $device.userPrincipalName
                    OverallCompliance = $compState
                    OperatingSystem   = $device.operatingSystem
                    OSVersion         = $device.osVersion
                    Model             = $device.model
                    Manufacturer      = $device.manufacturer
                    SerialNumber      = $device.serialNumber
                    Ownership         = $device.managedDeviceOwnerType
                    LastSyncDateTime  = $lastSync
                    DaysSinceSync     = $daysSinceSync
                    EnrolledDateTime  = $device.enrolledDateTime
                    GraceExpiry       = $graceExpiry
                    PolicyName        = $policyName
                    PolicyState       = $policyState
                    SettingName       = '(No specific setting reported)'
                    SettingState      = $policyState
                    SettingDetail     = '-'
                    DeviceId          = $device.id
                })
            }
        } elseif ($IncludeCompliant -or $policyState -ne 'compliant') {
            # Include compliant policy rows if requested, or non-standard states
            $complianceReport.Add([PSCustomObject]@{
                DeviceName        = $device.deviceName
                UserPrincipalName = $device.userPrincipalName
                OverallCompliance = $compState
                OperatingSystem   = $device.operatingSystem
                OSVersion         = $device.osVersion
                Model             = $device.model
                Manufacturer      = $device.manufacturer
                SerialNumber      = $device.serialNumber
                Ownership         = $device.managedDeviceOwnerType
                LastSyncDateTime  = $lastSync
                DaysSinceSync     = $daysSinceSync
                EnrolledDateTime  = $device.enrolledDateTime
                GraceExpiry       = $graceExpiry
                PolicyName        = $policyName
                PolicyState       = $policyState
                SettingName       = '-'
                SettingState      = $policyState
                SettingDetail     = '-'
                DeviceId          = $device.id
            })
        }
    }
}

Write-Progress -Activity "Analyzing device compliance" -Completed
#endregion

#region --- Summary ---
Write-Section "COMPLIANCE SUMMARY"
Write-Log -Message "" -Level 'INFO'

# Overall status
$scopeText = switch ($PSCmdlet.ParameterSetName) {
    'ByDevice' { "Device: $DeviceName" }
    'ByGroup'  { "Group: $GroupName" }
    default    { "All managed devices" }
}

Write-Log -Message "  Scope              : $scopeText" -Level 'INFO'
Write-Log -Message "  Total devices      : $totalDevices" -Level 'INFO'
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Compliant          : $compliantCount" -Level 'SUCCESS'
Write-Log -Message "  Non-Compliant      : $nonCompliantCount" -Level 'WARNING'
Write-Log -Message "  In Grace Period    : $inGraceCount" -Level 'WARNING'
Write-Log -Message "  Unknown/ConfigMgr  : $unknownCount" -Level 'WARNING'
Write-Log -Message "  Not Evaluated      : $notEvalCount" -Level 'WARNING'

if ($totalDevices -gt 0) {
    $complianceRate = [math]::Round(($compliantCount / $totalDevices) * 100, 1)
    $rateColor = if ($complianceRate -ge 95) { 'Green' } elseif ($complianceRate -ge 80) { 'Yellow' } else { 'Red' }
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Compliance Rate    : $complianceRate%" -Level 'INFO'
}

# Non-compliant device details
if ($complianceReport.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'

    # Group by device for console display
    $deviceGroups = $complianceReport | Group-Object DeviceName | Sort-Object Name
    $displayCount = [math]::Min($deviceGroups.Count, 25)

    Write-Section "NON-COMPLIANT DEVICE DETAILS$(if($deviceGroups.Count -gt 25){" (showing first 25 of $($deviceGroups.Count))"})"
    Write-Log -Message "" -Level 'INFO'

    foreach ($dg in ($deviceGroups | Select-Object -First 25)) {
        $firstRow = $dg.Group[0]
        $compColor = switch ($firstRow.OverallCompliance) {
            'noncompliant'  { 'Red' }
            'inGracePeriod' { 'Yellow' }
            'unknown'       { 'DarkYellow' }
            'compliant'     { 'Green' }
            default         { 'Gray' }
        }

        Write-Log -Message "  $($dg.Name)" -Level 'INFO'
        Write-Log -Message " | $($firstRow.UserPrincipalName)" -Level 'INFO'
        Write-Log -Message " | $($firstRow.OverallCompliance)" -Level 'INFO'
        Write-Log -Message "    $($firstRow.OperatingSystem) $($firstRow.OSVersion) | $($firstRow.Model) | Serial: $($firstRow.SerialNumber)" -Level 'DEBUG'
        Write-Log -Message "    Last sync: $($firstRow.LastSyncDateTime) ($($firstRow.DaysSinceSync) days ago)" -Level 'DEBUG'

        # Show failed policies and settings
        $failedPolicies = $dg.Group | Where-Object { $_.PolicyState -ne 'compliant' } | Group-Object PolicyName
        foreach ($fp in $failedPolicies) {
            $policyColor = switch ($fp.Group[0].PolicyState) {
                'nonCompliant' { 'Red' }
                'error'        { 'Magenta' }
                'conflict'     { 'DarkYellow' }
                default        { 'Yellow' }
            }
            Write-Log -Message "    POLICY: $($fp.Name) [$($fp.Group[0].PolicyState)]" -Level 'INFO'

            foreach ($setting in $fp.Group) {
                if ($setting.SettingName -ne '-' -and $setting.SettingName -ne '(No specific setting reported)') {
                    Write-Log -Message "      Setting: $($setting.SettingName)" -Level 'INFO'
                    Write-Log -Message " [$($setting.SettingState)]" -Level 'ERROR'
                    if ($setting.SettingDetail -ne '-') {
                        Write-Log -Message "        Current value: $($setting.SettingDetail)" -Level 'DEBUG'
                    }
                }
            }
        }
        Write-Log -Message "" -Level 'INFO'
    }

    # Top failing policies summary
    $failingPolicies = $complianceReport | Where-Object { $_.PolicyState -ne 'compliant' -and $_.PolicyName -ne '(No compliance policy assigned)' }
    if ($failingPolicies.Count -gt 0) {
        Write-Section "TOP FAILING POLICIES"
        Write-Log -Message "" -Level 'INFO'
        $policyRanking = $failingPolicies | Group-Object PolicyName | Sort-Object Count -Descending | Select-Object -First 10
        foreach ($pr in $policyRanking) {
            $uniqueDevices = ($pr.Group | Select-Object -Property DeviceName -Unique).Count
            Write-Log -Message "  $($pr.Name)" -Level 'WARNING'
            Write-Log -Message "    Failures: $($pr.Count) setting violations across $uniqueDevices device(s)" -Level 'INFO'
        }
        Write-Log -Message "" -Level 'INFO'
    }

    # Top failing settings summary
    $failingSettings = $complianceReport | Where-Object { $_.SettingState -ne 'compliant' -and $_.SettingState -ne '-' -and $_.SettingName -ne '-' -and $_.SettingName -ne '(No specific setting reported)' }
    if ($failingSettings.Count -gt 0) {
        Write-Section "TOP FAILING SETTINGS"
        Write-Log -Message "" -Level 'INFO'
        $settingRanking = $failingSettings | Group-Object SettingName | Sort-Object Count -Descending | Select-Object -First 10
        foreach ($sr in $settingRanking) {
            $uniqueDevices = ($sr.Group | Select-Object -Property DeviceName -Unique).Count
            Write-Log -Message "  $($sr.Name)" -Level 'WARNING'
            Write-Log -Message "    Failed on $uniqueDevices device(s)" -Level 'INFO'
        }
        Write-Log -Message "" -Level 'INFO'
    }

    # Devices with no compliance policy
    $noPolicyDevices = $complianceReport | Where-Object { $_.PolicyName -eq '(No compliance policy assigned)' }
    if ($noPolicyDevices.Count -gt 0) {
        Write-Section "DEVICES WITH NO COMPLIANCE POLICY"
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  $($noPolicyDevices.Count) device(s) have no compliance policy assigned:" -Level 'WARNING'
        foreach ($npd in ($noPolicyDevices | Select-Object -First 15)) {
            Write-Log -Message "    - $($npd.DeviceName) ($($npd.UserPrincipalName))" -Level 'INFO'
        }
        if ($noPolicyDevices.Count -gt 15) {
            Write-Log -Message "    ... and $($noPolicyDevices.Count - 15) more (see CSV export)" -Level 'DEBUG'
        }
        Write-Log -Message "" -Level 'INFO'
    }
}

# Export
if ($complianceReport.Count -gt 0) {
    if ($ExportPath) {
        $complianceReport | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
        Write-Status "Exported $($complianceReport.Count) rows to: $ExportPath" "Green"
    } else {
        $scopeSafe = switch ($PSCmdlet.ParameterSetName) {
            'ByDevice' { $DeviceName -replace '[^\w\-]','_' }
            'ByGroup'  { $GroupName -replace '[^\w\-]','_' }
            default    { 'AllDevices' }
        }
        $defaultPath = Join-Path $env:TEMP "$scopeSafe`_ComplianceReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $complianceReport | Export-Csv -Path $defaultPath -NoTypeInformation -Encoding UTF8
        Write-Status "Auto-exported $($complianceReport.Count) rows to: $defaultPath" "Green"
    }
} elseif ($complianceReport.Count -eq 0 -and -not $IncludeCompliant) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  All devices are compliant. Use -IncludeCompliant to generate a full report." -Level 'SUCCESS'
}

Write-Log -Message "`n$('='*60)" -Level 'DEBUG'
#endregion
