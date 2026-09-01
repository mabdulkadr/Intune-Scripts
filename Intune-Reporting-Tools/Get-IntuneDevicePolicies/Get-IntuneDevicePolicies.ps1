<#
.TITLE
    Intune Device Policies

.SYNOPSIS
    Retrieves all Intune policies assigned to a specific device via group memberships, All Devices, or All Users.

.DESCRIPTION
    Queries Microsoft Graph to find every policy assigned to a device via group memberships,
    All Devices, or All Users. Covers device configuration, settings catalog, compliance,
    group policy, scripts, remediation, app configuration, Autopilot, endpoint security
    intents, update rings, feature/driver/quality updates, and app assignments with structured
    CSV/JSON output.

.TAGS
    Intune,Policies,Assignment,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.Read.All,DeviceManagementServiceConfig.Read.All,Device.Read.All,Directory.Read.All,Group.Read.All,GroupMember.Read.All,DeviceManagementApps.Read.All

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
    .\Get-IntuneDevicePolicies.ps1 -DeviceName "L-PF4Z0HM0"
    Lists every policy assigned to the device

.EXAMPLE
    .\Get-IntuneDevicePolicies.ps1 -DeviceId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    Lookup by managed device ID

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Resolves transitive group memberships for device and user
    - Logs: %ProgramData%\get-intune-device-policies\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = 'ByName')]
param(
    [Parameter(Mandatory, ParameterSetName = 'ByName')]
    [string]$DeviceName,

    [Parameter(Mandatory, ParameterSetName = 'ById')]
    [string]$DeviceId,

    [string]$ExportPath,
    [bool]$OutputFindings = $true
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-intune-device-policies'
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

#region --- Helpers (standalone) ---
function Write-Status { param([string]$Msg,[string]$Color='Cyan'); $level = switch ($Color) { 'Red'{'ERROR'} 'Yellow'{'WARNING'} 'Green'{'SUCCESS'} 'DarkYellow'{'WARNING'} 'DarkGray'{'DEBUG'} default{'INFO'} }; Write-Log -Message $Msg -Level $level }
function Write-Section { param([string]$Msg); Write-Log -Message "=== $Msg ===" -Level 'INFO' }

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
    Write-Log -Message "Connecting to Microsoft Graph..." -Level 'INFO'
    Connect-MgGraph -Scopes @(
        'DeviceManagementConfiguration.Read.All',
        'DeviceManagementManagedDevices.Read.All',
        'DeviceManagementServiceConfig.Read.All',
        'Device.Read.All',
        'Directory.Read.All',
        'Group.Read.All',
        'GroupMember.Read.All',
        'DeviceManagementApps.Read.All'
    ) -ErrorAction Stop
    $context = Get-MgContext
}
Write-Log -Message "Signed in as: $($context.Account)" -Level 'SUCCESS'
#endregion

#region --- Resolve Device ---
Write-Section "RESOLVING DEVICE"

if ($DeviceName) {
    Write-Log -Message "Searching for device: $DeviceName" -Level 'INFO'
    $devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$DeviceName'"
    if ($devices.Count -eq 0) {
        Write-Log -Message "Device '$DeviceName' not found in Intune." -Level 'ERROR'
        return
    }
    $device = $devices[0]
} else {
    Write-Log -Message "Looking up device ID: $DeviceId" -Level 'INFO'
    $device = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$DeviceId"
    if (-not $device) {
        Write-Log -Message "Device ID '$DeviceId' not found in Intune." -Level 'ERROR'
        return
    }
}

$managedDeviceId   = $device.id
$deviceName        = $device.deviceName
$entraDeviceId     = $device.azureADDeviceId
$userPrincipalName = $device.userPrincipalName
$osVersion         = $device.osVersion
$complianceState   = $device.complianceState
$serialNumber      = $device.serialNumber
$lastSync          = $device.lastSyncDateTime
$enrolledDate      = $device.enrolledDateTime

Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Device Name      : $deviceName" -Level 'INFO'
Write-Log -Message "  Managed Device ID: $managedDeviceId" -Level 'INFO'
Write-Log -Message "  Entra Device ID  : $entraDeviceId" -Level 'INFO'
Write-Log -Message "  Primary User     : $userPrincipalName" -Level 'INFO'
Write-Log -Message "  OS Version       : $osVersion" -Level 'INFO'
Write-Log -Message "  Serial Number    : $serialNumber" -Level 'INFO'
Write-Log -Message "  Compliance State : $complianceState" -Level 'WARNING'
Write-Log -Message "  Last Sync        : $lastSync" -Level 'WARNING'
Write-Log -Message "  Enrolled         : $enrolledDate" -Level 'INFO'

# Sync staleness finding
if ($lastSync) {
    $syncAge = (Get-Date) - [datetime]$lastSync
    if ($syncAge.TotalDays -gt 7) {
        Write-Log -Message "Finding: Device sync is very stale ($([math]::Round($syncAge.TotalDays)) days)" -Level 'WARNING'
    }
}

# Compliance finding
if ($complianceState -ne 'compliant') {
    Write-Log -Message "Finding: Device compliance state: $complianceState" -Level 'WARNING'
}
#endregion

#region --- Resolve Group Memberships ---
Write-Section "RESOLVING GROUP MEMBERSHIPS"

$deviceGroupIds = @()
if ($entraDeviceId) {
    Write-Log -Message "Getting Entra device object..." -Level 'INFO'
    $entraDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$entraDeviceId'"
    if ($entraDevices.Count -gt 0) {
        $entraObjectId = $entraDevices[0].id
        Write-Log -Message "Getting device transitive group memberships..." -Level 'INFO'
        $deviceGroups = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/devices/$entraObjectId/transitiveMemberOf?`$select=id,displayName"
        $deviceGroupIds = $deviceGroups | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' } | ForEach-Object { $_.id }
        Write-Log -Message "Device is in $($deviceGroupIds.Count) groups" -Level 'SUCCESS'
    }
}

$userGroupIds = @()
if ($userPrincipalName) {
    Write-Log -Message "Getting user transitive group memberships for $userPrincipalName..." -Level 'INFO'
    $userGroups = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/users/$userPrincipalName/transitiveMemberOf?`$select=id,displayName"
    $userGroupIds = $userGroups | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' } | ForEach-Object { $_.id }
    Write-Log -Message "User is in $($userGroupIds.Count) groups" -Level 'SUCCESS'
}

$groupNameMap = @{}
foreach ($g in (@($deviceGroups) + @($userGroups))) {
    if ($g -and $g.id -and $g.displayName) { $groupNameMap[$g.id] = $g.displayName }
}
#endregion

#region --- Assignment matching helper ---
function Test-AssignmentMatch {
    param([array]$Assignments, [array]$DeviceGroupIds, [array]$UserGroupIds)
    foreach ($a in $Assignments) {
        $target = $a.target
        if (-not $target) { continue }
        $type = $target.'@odata.type'
        switch ($type) {
            '#microsoft.graph.allDevicesAssignmentTarget'          { return @{ Match = $true; Via = 'All Devices' } }
            '#microsoft.graph.allUsersAssignmentTarget'            { return @{ Match = $true; Via = 'All Users' } }
            '#microsoft.graph.allLicensedUsersAssignmentTarget'    { return @{ Match = $true; Via = 'All Licensed Users' } }
            '#microsoft.graph.groupAssignmentTarget' {
                $gid = $target.groupId
                if ($DeviceGroupIds -contains $gid) { return @{ Match = $true; Via = "Device Group: $gid" } }
                if ($UserGroupIds -contains $gid)   { return @{ Match = $true; Via = "User Group: $gid" } }
            }
        }
    }
    return @{ Match = $false; Via = $null }
}

function Resolve-ViaText {
    param([string]$ViaText)
    if ($ViaText -match 'Group: (.+)$') {
        $gid = $Matches[1]
        if ($groupNameMap.ContainsKey($gid)) { return $ViaText -replace $gid, "$($groupNameMap[$gid]) ($gid)" }
    }
    return $ViaText
}
#endregion

#region --- Policy Discovery ---
$allPolicies = [System.Collections.Generic.List[PSCustomObject]]::new()

$policyTypes = @(
    @{ Name = 'Device Configuration Profiles';   Uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations';          NameProp = 'displayName' }
    @{ Name = 'Settings Catalog Policies';        Uri = 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies';        NameProp = 'name' }
    @{ Name = 'Compliance Policies';              Uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies';     NameProp = 'displayName' }
    @{ Name = 'Group Policy Configurations';      Uri = 'https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations';    NameProp = 'displayName' }
    @{ Name = 'Device Management Scripts';        Uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts';      NameProp = 'displayName' }
    @{ Name = 'Health/Remediation Scripts';        Uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts';          NameProp = 'displayName' }
    @{ Name = 'App Configuration Policies (MDM)'; Uri = 'https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations';   NameProp = 'displayName' }
    @{ Name = 'Windows Autopilot Profiles';       Uri = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles'; NameProp = 'displayName' }
)

foreach ($pt in $policyTypes) {
    Write-Section "SCANNING: $($pt.Name)"
    $policies = Get-MgGraphAllPages -Uri $pt.Uri
    Write-Log -Message "Found $($policies.Count) total policies, checking assignments..." -Level 'INFO'
    $matchCount = 0

    foreach ($p in $policies) {
        $assignments = Get-MgGraphAllPages -Uri "$($pt.Uri)/$($p.id)/assignments"
        $result = Test-AssignmentMatch -Assignments $assignments -DeviceGroupIds $deviceGroupIds -UserGroupIds $userGroupIds

        if ($result.Match) {
            $matchCount++
            $viaText = Resolve-ViaText $result.Via
            $policyName = $p.($pt.NameProp)
            if (-not $policyName) { $policyName = $p.displayName }
            if (-not $policyName) { $policyName = $p.name }
            if (-not $policyName) { $policyName = "(Unnamed - $($p.id))" }

            $odataType = $p.'@odata.type'
            $platformText = switch -Wildcard ($odataType) {
                '*windows*' { 'Windows' } '*ios*' { 'iOS' } '*android*' { 'Android' } '*macOS*' { 'macOS' }
                default { if ($p.platforms) { $p.platforms } elseif ($p.platformType) { $p.platformType } else { '-' } }
            }

            Write-Log -Message "    [MATCH] $policyName" -Level 'SUCCESS'
            Write-Log -Message "            Assigned via: $viaText" -Level 'INFO'

            $allPolicies.Add([PSCustomObject]@{
                PolicyType  = $pt.Name
                PolicyName  = $policyName
                Platform    = $platformText
                AssignedVia = $viaText
                PolicyId    = $p.id
            })
        }
    }
    Write-Log -Message "$matchCount matching assignments found" -Level $(if($matchCount -gt 0){'Success'}else{'Info'})
}

#--- Endpoint Security Policies (Intents) ---
Write-Section "SCANNING: Endpoint Security Policies"
$templates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/templates?`$filter=templateType eq 'securityBaseline' or templateType eq 'cloudPC' or templateType eq 'firewall' or templateType eq 'attackSurfaceReduction' or templateType eq 'endpointDetectionAndResponse' or templateType eq 'accountProtection' or templateType eq 'antivirus' or templateType eq 'diskEncryption'"
$intents = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/intents"
Write-Log -Message "Found $($intents.Count) endpoint security policies..." -Level 'INFO'
$matchCount = 0

foreach ($intent in $intents) {
    $assignments = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$($intent.id)/assignments"
    $result = Test-AssignmentMatch -Assignments $assignments -DeviceGroupIds $deviceGroupIds -UserGroupIds $userGroupIds
    if ($result.Match) {
        $matchCount++
        $viaText = Resolve-ViaText $result.Via
        $templateName = ($templates | Where-Object { $_.id -eq $intent.templateId }).displayName
        $intentName = if ($templateName) { "$($intent.displayName) [$templateName]" } else { $intent.displayName }
        Write-Log -Message "    [MATCH] $intentName" -Level 'SUCCESS'
        Write-Log -Message "            Assigned via: $viaText" -Level 'INFO'
        $allPolicies.Add([PSCustomObject]@{
            PolicyType = "Endpoint Security ($templateName)"; PolicyName = $intent.displayName
            Platform = 'Windows'; AssignedVia = $viaText; PolicyId = $intent.id
        })
    }
}
Write-Log -Message "$matchCount matching" -Level $(if($matchCount){'Success'}else{'Info'})

#--- Update Rings + Feature + Driver + Quality ---
$updateScans = @(
    @{ Name = 'Windows Update Rings';     Uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windowsUpdateForBusinessConfiguration')"; BaseUri = 'https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations' }
    @{ Name = 'Feature Update Policies';  Uri = 'https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles'; BaseUri = 'https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles' }
    @{ Name = 'Driver Update Policies';   Uri = 'https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles';  BaseUri = 'https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles' }
    @{ Name = 'Quality Update Policies';  Uri = 'https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles'; BaseUri = 'https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles' }
)

foreach ($scan in $updateScans) {
    Write-Section "SCANNING: $($scan.Name)"
    $items = Get-MgGraphAllPages -Uri $scan.Uri
    Write-Log -Message "Found $($items.Count), checking assignments..." -Level 'INFO'
    $mc = 0
    foreach ($item in $items) {
        $assignments = Get-MgGraphAllPages -Uri "$($scan.BaseUri)/$($item.id)/assignments"
        $result = Test-AssignmentMatch -Assignments $assignments -DeviceGroupIds $deviceGroupIds -UserGroupIds $userGroupIds
        if ($result.Match) {
            if ($allPolicies | Where-Object PolicyId -eq $item.id) { continue }
            $mc++
            $viaText = Resolve-ViaText $result.Via
            Write-Log -Message "    [MATCH] $($item.displayName)" -Level 'SUCCESS'
            Write-Log -Message "            Assigned via: $viaText" -Level 'INFO'
            $allPolicies.Add([PSCustomObject]@{
                PolicyType = $scan.Name; PolicyName = $item.displayName
                Platform = 'Windows'; AssignedVia = $viaText; PolicyId = $item.id
            })
        }
    }
    Write-Log -Message "$mc matching" -Level $(if($mc){'Success'}else{'Info'})
}

#--- App Assignments ---
Write-Section "SCANNING: App Assignments"
$apps = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=(microsoft.graph.managedApp/appAvailability eq null or microsoft.graph.managedApp/appAvailability eq 'lineOfBusiness' or isAssigned eq true)&`$select=id,displayName,isAssigned"
Write-Log -Message "Found $($apps.Count) apps..." -Level 'INFO'
$mc = 0

foreach ($app in $apps) {
    if (-not $app.isAssigned) { continue }
    $assignments = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)/assignments"
    $result = Test-AssignmentMatch -Assignments $assignments -DeviceGroupIds $deviceGroupIds -UserGroupIds $userGroupIds
    if ($result.Match) {
        $mc++
        $viaText = Resolve-ViaText $result.Via
        $intent = ($assignments | Where-Object { $_.target.'@odata.type' -ne '#microsoft.graph.exclusionGroupAssignmentTarget' } | Select-Object -First 1).intent
        Write-Log -Message "    [MATCH] $($app.displayName) (Intent: $intent)" -Level 'SUCCESS'
        Write-Log -Message "            Assigned via: $viaText" -Level 'INFO'
        $allPolicies.Add([PSCustomObject]@{
            PolicyType = "App Assignment ($intent)"; PolicyName = $app.displayName
            Platform = '-'; AssignedVia = $viaText; PolicyId = $app.id
        })
    }
}
Write-Log -Message "$mc matching app assignments" -Level $(if($mc){'Success'}else{'Info'})
#endregion

#region --- Summary ---
Write-Section "SUMMARY FOR: $deviceName"
Write-Log -Message "" -Level 'INFO'

if ($allPolicies.Count -eq 0) {
    Write-Log -Message "No policies found assigned to this device." -Level 'WARNING'
} else {
    Write-Log -Message "Total policies/assignments found: $($allPolicies.Count)" -Level 'SUCCESS'
    Write-Log -Message "" -Level 'INFO'

    $grouped = $allPolicies | Group-Object PolicyType | Sort-Object Name
    foreach ($group in $grouped) {
        Write-Log -Message "  $($group.Name) ($($group.Count))" -Level 'WARNING'
        foreach ($p in $group.Group) {
            Write-Log -Message "    - $($p.PolicyName)" -Level 'INFO'
            Write-Log -Message "      via: $($p.AssignedVia)" -Level 'DEBUG'
        }
        Write-Log -Message "" -Level 'INFO'
    }
}

# Export
$exportDest = $ExportPath
if (-not $exportDest -and $Global:IOSessionPath) {
    $exportDest = Join-Path $Global:IOSessionPath "Analysis\DevicePolicies_$deviceName.csv"
}
if (-not $exportDest) {
    $exportDest = Join-Path $env:TEMP "${deviceName}_IntunePolicies_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
}

$allPolicies | Export-Csv -Path $exportDest -NoTypeInformation -Encoding UTF8
Write-Log -Message "Exported to: $exportDest" -Level 'SUCCESS'

# JSON export for analysis scripts
if ($Global:IOSessionPath) {
    $jsonPath = Join-Path $Global:IOSessionPath "Analysis\DevicePolicies_$deviceName.json"
    $allPolicies | ConvertTo-Json -Depth 5 | Set-Content $jsonPath -Encoding UTF8
}

Write-Log -Message "`n$('='*60)" -Level 'DEBUG'
#endregion