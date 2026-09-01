<#
.TITLE
    Group Policy Assignment Report

.SYNOPSIS
    Retrieves all Intune policies and apps assigned to a specific Entra ID group.

.DESCRIPTION
    Queries Microsoft Graph to find every policy (configuration profiles, compliance, Settings Catalog, endpoint security, update rings, scripts, app config, etc.) that targets a specific Entra ID group - either as an Include or Exclude assignment. Also reports "All Devices", "All Users", and "All Licensed Users" assignments.

.TAGS
    Group,Assignment,Intune,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.Read.All,DeviceManagementServiceConfig.Read.All,Device.Read.All,Directory.Read.All,Group.Read.All,GroupMember.Read.All,DeviceManagementApps.Read.All

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
    .\Get-IntuneGroupPolicies.ps1 -GroupName "SG-Intune-Windows-Devices"
 .EXAMPLE
    .\Get-IntuneGroupPolicies.ps1 -GroupId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -ExportPath "C:\temp\group_policies.csv"
 .EXAMPLE
    .\Get-IntuneGroupPolicies.ps1 -GroupName "SG-Intune-Pilot" -IncludeAllDevicesAllUsers

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\get-intunegrouppolicies\Logs
#>

#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = 'ByName')]
param(
    [Parameter(Mandatory, ParameterSetName = 'ByName')]
    [string]$GroupName,

    [Parameter(Mandatory, ParameterSetName = 'ById')]
    [string]$GroupId,

    [Parameter()]
    [switch]$IncludeAllDevicesAllUsers,

    [Parameter()]
    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'get-intunegrouppolicies'
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

function Get-PolicyAssignments {
    param([string]$PolicyId, [string]$BaseUri)
    $uri = "$BaseUri/$PolicyId/assignments"
    return Get-MgGraphAllPages -Uri $uri
}

function Test-GroupAssignment {
    <#
    .SYNOPSIS
        Checks if a policy's assignments target a specific group.
        Returns match info including whether the group is Included or Excluded.
    #>
    param(
        [array]$Assignments,
        [string]$TargetGroupId,
        [bool]$IncludeGlobalAssignments = $false
    )
    $matchResults = @()

    foreach ($a in $Assignments) {
        $target = $a.target
        if (-not $target) { continue }
        $type = $target.'@odata.type'

        switch ($type) {
            '#microsoft.graph.allDevicesAssignmentTarget' {
                if ($IncludeGlobalAssignments) {
                    $matchResults += @{ AssignmentType = 'Include'; Via = 'All Devices' }
                }
            }
            '#microsoft.graph.allUsersAssignmentTarget' {
                if ($IncludeGlobalAssignments) {
                    $matchResults += @{ AssignmentType = 'Include'; Via = 'All Users' }
                }
            }
            '#microsoft.graph.allLicensedUsersAssignmentTarget' {
                if ($IncludeGlobalAssignments) {
                    $matchResults += @{ AssignmentType = 'Include'; Via = 'All Licensed Users' }
                }
            }
            '#microsoft.graph.groupAssignmentTarget' {
                if ($target.groupId -eq $TargetGroupId) {
                    $matchResults += @{ AssignmentType = 'Include'; Via = 'Direct Group Assignment' }
                }
            }
            '#microsoft.graph.exclusionGroupAssignmentTarget' {
                if ($target.groupId -eq $TargetGroupId) {
                    $matchResults += @{ AssignmentType = 'Exclude'; Via = 'Direct Group Exclusion' }
                }
            }
        }
    }
    return $matchResults
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
        'DeviceManagementServiceConfig.Read.All',
        'Device.Read.All',
        'Directory.Read.All',
        'Group.Read.All',
        'GroupMember.Read.All',
        'DeviceManagementApps.Read.All'
    ) -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"
#endregion

#region --- Resolve Group ---
Write-Section "RESOLVING GROUP"

if ($GroupName) {
    Write-Status "Searching for group: $GroupName"
    $groups = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$($GroupName -replace "'","''")'"
    if ($groups.Count -eq 0) {
        Write-Log -Message "  ERROR: Group '$GroupName' not found in Entra ID." -Level 'ERROR'
        return
    }
    if ($groups.Count -gt 1) {
        Write-Log -Message "  WARNING: Multiple groups found with name '$GroupName'. Using first match." -Level 'WARNING'
    }
    $group = $groups[0]
} else {
    Write-Status "Looking up group ID: $GroupId"
    $group = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId"
    if (-not $group -or $group.Count -eq 0) {
        Write-Log -Message "  ERROR: Group ID '$GroupId' not found in Entra ID." -Level 'ERROR'
        return
    }
    if ($group -is [array]) { $group = $group[0] }
}

$targetGroupId   = $group.id
$targetGroupName = $group.displayName
$groupType       = if ($group.groupTypes -contains 'DynamicMembership') { 'Dynamic' } else { 'Assigned' }
$membershipRule  = $group.membershipRule
$securityEnabled = $group.securityEnabled
$mailEnabled     = $group.mailEnabled

# Get member count
$members = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups/$targetGroupId/members?`$count=true&`$top=1" 2>$null
$memberCount = if ($members -is [array]) { $members.Count } else { 'Unknown' }
# Try to get the actual count from the response header approach
$memberCountUri = "https://graph.microsoft.com/v1.0/groups/$targetGroupId/members/`$count"
try {
    $actualCount = Invoke-MgGraphRequest -Uri $memberCountUri -Method GET -Headers @{ 'ConsistencyLevel' = 'eventual' } -ErrorAction Stop
    $memberCount = $actualCount
} catch [System.Exception] {
    # Fall back to the basic count
}

Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Group Name       : $targetGroupName" -Level 'INFO'
Write-Log -Message "  Group ID         : $targetGroupId" -Level 'DEBUG'
Write-Log -Message "  Group Type       : $groupType" -Level 'DEBUG'
Write-Log -Message "  Security Enabled : $securityEnabled" -Level 'DEBUG'
Write-Log -Message "  Mail Enabled     : $mailEnabled" -Level 'DEBUG'
Write-Log -Message "  Member Count     : $memberCount" -Level 'DEBUG'
if ($membershipRule) {
    Write-Log -Message "  Membership Rule  : $membershipRule" -Level 'INFO'
}

# Get parent groups (groups this group is a member of)
Write-Status "Checking parent group memberships..."
$parentGroups = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups/$targetGroupId/transitiveMemberOf?`$select=id,displayName"
$parentGroupList = $parentGroups | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }
if ($parentGroupList.Count -gt 0) {
    Write-Status "Group is nested inside $($parentGroupList.Count) parent group(s):" "White"
    foreach ($pg in $parentGroupList) {
        Write-Log -Message "    - $($pg.displayName) ($($pg.id))" -Level 'INFO'
    }
} else {
    Write-Status "Group is not nested inside any other groups" "DarkGray"
}
#endregion

#region --- Policy Discovery ---
$allPolicies = [System.Collections.Generic.List[PSCustomObject]]::new()
$includeGlobal = $IncludeAllDevicesAllUsers.IsPresent

# --- Standard policy types (use $expand=Assignments for efficiency when supported) ---
$policyTypes = @(
    @{ Name = 'Device Configuration Profiles';   Uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations';          NameProp = 'displayName'; SupportsExpand = $true }
    @{ Name = 'Settings Catalog Policies';        Uri = 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies';        NameProp = 'name';        SupportsExpand = $true }
    @{ Name = 'Compliance Policies';              Uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies';     NameProp = 'displayName'; SupportsExpand = $true }
    @{ Name = 'Group Policy Configurations';      Uri = 'https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations';    NameProp = 'displayName'; SupportsExpand = $true }
    @{ Name = 'Device Management Scripts';        Uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts';      NameProp = 'displayName'; SupportsExpand = $true }
    @{ Name = 'Health/Remediation Scripts';        Uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts';          NameProp = 'displayName'; SupportsExpand = $true }
    @{ Name = 'App Configuration Policies (MDM)'; Uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceAppManagement/mobileAppConfigurations'; NameProp = 'displayName'; SupportsExpand = $false }
    @{ Name = 'Windows Autopilot Profiles';       Uri = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles'; NameProp = 'displayName'; SupportsExpand = $true }
)

foreach ($pt in $policyTypes) {
    Write-Section "SCANNING: $($pt.Name)"

    # Try $expand=Assignments to reduce API calls
    $policies = @()
    $expandWorked = $false
    if ($pt.SupportsExpand) {
        $expandUri = "$($pt.Uri)?`$expand=Assignments"
        $policies = Get-MgGraphAllPages -Uri $expandUri
        if ($policies.Count -gt 0 -and $null -ne $policies[0].assignments) {
            $expandWorked = $true
        } else {
            $policies = Get-MgGraphAllPages -Uri $pt.Uri
        }
    } else {
        $policies = Get-MgGraphAllPages -Uri $pt.Uri
    }

    Write-Status "Found $($policies.Count) total policies$(if($expandWorked){' (assignments pre-loaded)'}), checking assignments..."
    $matchCount = 0

    foreach ($p in $policies) {
        # Get assignments either from expanded data or separate call
        $assignments = if ($expandWorked -and $p.assignments) {
            $p.assignments
        } else {
            Get-PolicyAssignments -PolicyId $p.id -BaseUri $pt.Uri
        }

        $results = Test-GroupAssignment -Assignments $assignments -TargetGroupId $targetGroupId -IncludeGlobalAssignments $includeGlobal

        foreach ($result in $results) {
            $matchCount++

            $policyName = $p.($pt.NameProp)
            if (-not $policyName) { $policyName = $p.displayName }
            if (-not $policyName) { $policyName = $p.name }
            if (-not $policyName) { $policyName = "(Unnamed - $($p.id))" }

            $odataType = $p.'@odata.type'
            $platformText = switch -Wildcard ($odataType) {
                '*windows*'  { 'Windows' }
                '*ios*'      { 'iOS' }
                '*android*'  { 'Android' }
                '*macOS*'    { 'macOS' }
                default      { if ($p.platforms) { $p.platforms } elseif ($p.platformType) { $p.platformType } else { '-' } }
            }

            $assignColor = if ($result.AssignmentType -eq 'Exclude') { 'DarkYellow' } else { 'Green' }
            $assignTag   = if ($result.AssignmentType -eq 'Exclude') { 'EXCLUDE' } else { 'INCLUDE' }

            Write-Log -Message "    [$assignTag] $policyName" -Level 'INFO'
            Write-Log -Message "              via: $($result.Via)" -Level 'INFO'

            $allPolicies.Add([PSCustomObject]@{
                PolicyType     = $pt.Name
                PolicyName     = $policyName
                Platform       = $platformText
                AssignmentType = $result.AssignmentType
                AssignedVia    = $result.Via
                PolicyId       = $p.id
            })
        }
    }
    Write-Status "$matchCount matching assignments found" $(if($matchCount -gt 0){'Green'}else{'DarkGray'})
}

#region --- Endpoint Security Policies (Intents) ---
Write-Section "SCANNING: Endpoint Security Policies"
$templates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/templates?`$filter=templateType eq 'securityBaseline' or templateType eq 'cloudPC' or templateType eq 'firewall' or templateType eq 'attackSurfaceReduction' or templateType eq 'endpointDetectionAndResponse' or templateType eq 'accountProtection' or templateType eq 'antivirus' or templateType eq 'diskEncryption'"
$intents = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/intents"
Write-Status "Found $($intents.Count) endpoint security policies, checking assignments..."
$matchCount = 0

foreach ($intent in $intents) {
    $assignments = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$($intent.id)/assignments"
    $results = Test-GroupAssignment -Assignments $assignments -TargetGroupId $targetGroupId -IncludeGlobalAssignments $includeGlobal

    foreach ($result in $results) {
        $matchCount++

        $templateName = ($templates | Where-Object { $_.id -eq $intent.templateId }).displayName
        $intentName = $intent.displayName
        if ($templateName) { $intentName = "$intentName [$templateName]" }

        $assignColor = if ($result.AssignmentType -eq 'Exclude') { 'DarkYellow' } else { 'Green' }
        $assignTag   = if ($result.AssignmentType -eq 'Exclude') { 'EXCLUDE' } else { 'INCLUDE' }

        Write-Log -Message "    [$assignTag] $intentName" -Level 'INFO'
        Write-Log -Message "              via: $($result.Via)" -Level 'INFO'

        $allPolicies.Add([PSCustomObject]@{
            PolicyType     = "Endpoint Security ($templateName)"
            PolicyName     = $intent.displayName
            Platform       = 'Windows'
            AssignmentType = $result.AssignmentType
            AssignedVia    = $result.Via
            PolicyId       = $intent.id
        })
    }
}
Write-Status "$matchCount matching assignments found" $(if($matchCount -gt 0){'Green'}else{'DarkGray'})
#endregion

#region --- Update Rings ---
Write-Section "SCANNING: Windows Update Rings"
$updateRings = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windowsUpdateForBusinessConfiguration')"
Write-Status "Found $($updateRings.Count) update rings, checking assignments..."
$matchCount = 0

foreach ($ring in $updateRings) {
    $assignments = Get-PolicyAssignments -PolicyId $ring.id -BaseUri 'https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations'
    $results = Test-GroupAssignment -Assignments $assignments -TargetGroupId $targetGroupId -IncludeGlobalAssignments $includeGlobal

    foreach ($result in $results) {
        if ($allPolicies | Where-Object { $_.PolicyId -eq $ring.id }) { continue }
        $matchCount++

        $assignColor = if ($result.AssignmentType -eq 'Exclude') { 'DarkYellow' } else { 'Green' }
        $assignTag   = if ($result.AssignmentType -eq 'Exclude') { 'EXCLUDE' } else { 'INCLUDE' }

        Write-Log -Message "    [$assignTag] $($ring.displayName)" -Level 'INFO'
        Write-Log -Message "              via: $($result.Via)" -Level 'INFO'

        $allPolicies.Add([PSCustomObject]@{
            PolicyType     = 'Windows Update Ring'
            PolicyName     = $ring.displayName
            Platform       = 'Windows'
            AssignmentType = $result.AssignmentType
            AssignedVia    = $result.Via
            PolicyId       = $ring.id
        })
    }
}
Write-Status "$matchCount additional update rings found" $(if($matchCount -gt 0){'Green'}else{'DarkGray'})
#endregion

#region --- Feature Update Policies ---
Write-Section "SCANNING: Feature Update Policies"
$featureUpdates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles"
Write-Status "Found $($featureUpdates.Count) feature update policies, checking assignments..."
$matchCount = 0

foreach ($fu in $featureUpdates) {
    $assignments = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles/$($fu.id)/assignments"
    $results = Test-GroupAssignment -Assignments $assignments -TargetGroupId $targetGroupId -IncludeGlobalAssignments $includeGlobal

    foreach ($result in $results) {
        $matchCount++

        $assignColor = if ($result.AssignmentType -eq 'Exclude') { 'DarkYellow' } else { 'Green' }
        $assignTag   = if ($result.AssignmentType -eq 'Exclude') { 'EXCLUDE' } else { 'INCLUDE' }

        Write-Log -Message "    [$assignTag] $($fu.displayName)" -Level 'INFO'
        Write-Log -Message "              via: $($result.Via)" -Level 'INFO'

        $allPolicies.Add([PSCustomObject]@{
            PolicyType     = 'Feature Update Policy'
            PolicyName     = $fu.displayName
            Platform       = 'Windows'
            AssignmentType = $result.AssignmentType
            AssignedVia    = $result.Via
            PolicyId       = $fu.id
        })
    }
}
Write-Status "$matchCount matching assignments found" $(if($matchCount -gt 0){'Green'}else{'DarkGray'})
#endregion

#region --- Driver Update Policies ---
Write-Section "SCANNING: Driver Update Policies"
$driverUpdates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles"
Write-Status "Found $($driverUpdates.Count) driver update policies, checking assignments..."
$matchCount = 0

foreach ($du in $driverUpdates) {
    $assignments = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$($du.id)/assignments"
    $results = Test-GroupAssignment -Assignments $assignments -TargetGroupId $targetGroupId -IncludeGlobalAssignments $includeGlobal

    foreach ($result in $results) {
        $matchCount++

        $assignColor = if ($result.AssignmentType -eq 'Exclude') { 'DarkYellow' } else { 'Green' }
        $assignTag   = if ($result.AssignmentType -eq 'Exclude') { 'EXCLUDE' } else { 'INCLUDE' }

        Write-Log -Message "    [$assignTag] $($du.displayName)" -Level 'INFO'
        Write-Log -Message "              via: $($result.Via)" -Level 'INFO'

        $allPolicies.Add([PSCustomObject]@{
            PolicyType     = 'Driver Update Policy'
            PolicyName     = $du.displayName
            Platform       = 'Windows'
            AssignmentType = $result.AssignmentType
            AssignedVia    = $result.Via
            PolicyId       = $du.id
        })
    }
}
Write-Status "$matchCount matching assignments found" $(if($matchCount -gt 0){'Green'}else{'DarkGray'})
#endregion

#region --- Quality Update Policies ---
Write-Section "SCANNING: Quality (Expedited) Update Policies"
$qualityUpdates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles"
Write-Status "Found $($qualityUpdates.Count) quality update policies, checking assignments..."
$matchCount = 0

foreach ($qu in $qualityUpdates) {
    $assignments = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles/$($qu.id)/assignments"
    $results = Test-GroupAssignment -Assignments $assignments -TargetGroupId $targetGroupId -IncludeGlobalAssignments $includeGlobal

    foreach ($result in $results) {
        $matchCount++

        $assignColor = if ($result.AssignmentType -eq 'Exclude') { 'DarkYellow' } else { 'Green' }
        $assignTag   = if ($result.AssignmentType -eq 'Exclude') { 'EXCLUDE' } else { 'INCLUDE' }

        Write-Log -Message "    [$assignTag] $($qu.displayName)" -Level 'INFO'
        Write-Log -Message "              via: $($result.Via)" -Level 'INFO'

        $allPolicies.Add([PSCustomObject]@{
            PolicyType     = 'Quality Update Policy'
            PolicyName     = $qu.displayName
            Platform       = 'Windows'
            AssignmentType = $result.AssignmentType
            AssignedVia    = $result.Via
            PolicyId       = $qu.id
        })
    }
}
Write-Status "$matchCount matching assignments found" $(if($matchCount -gt 0){'Green'}else{'DarkGray'})
#endregion

#region --- App Protection Policies ---
Write-Section "SCANNING: App Protection Policies"

# iOS App Protection
$iosAppProtection = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections?`$expand=Assignments"
# Android App Protection
$androidAppProtection = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections?`$expand=Assignments"
# Windows Information Protection (without device enrollment)
$windowsAppProtection = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/windowsInformationProtectionPolicies?`$expand=Assignments"
# Windows Information Protection (MDM)
$windowsMdmProtection = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies?`$expand=Assignments"

$allAppProtection = @()
$allAppProtection += $iosAppProtection     | ForEach-Object { $_ | Add-Member -NotePropertyName '_platform' -NotePropertyValue 'iOS'     -PassThru -Force }
$allAppProtection += $androidAppProtection | ForEach-Object { $_ | Add-Member -NotePropertyName '_platform' -NotePropertyValue 'Android' -PassThru -Force }
$allAppProtection += $windowsAppProtection | ForEach-Object { $_ | Add-Member -NotePropertyName '_platform' -NotePropertyValue 'Windows' -PassThru -Force }
$allAppProtection += $windowsMdmProtection | ForEach-Object { $_ | Add-Member -NotePropertyName '_platform' -NotePropertyValue 'Windows' -PassThru -Force }

Write-Status "Found $($allAppProtection.Count) app protection policies, checking assignments..."
$matchCount = 0

foreach ($ap in $allAppProtection) {
    $assignments = $ap.assignments
    if (-not $assignments) { continue }
    $results = Test-GroupAssignment -Assignments $assignments -TargetGroupId $targetGroupId -IncludeGlobalAssignments $includeGlobal

    foreach ($result in $results) {
        $matchCount++

        $assignColor = if ($result.AssignmentType -eq 'Exclude') { 'DarkYellow' } else { 'Green' }
        $assignTag   = if ($result.AssignmentType -eq 'Exclude') { 'EXCLUDE' } else { 'INCLUDE' }

        Write-Log -Message "    [$assignTag] $($ap.displayName)" -Level 'INFO'
        Write-Log -Message "              via: $($result.Via) | Platform: $($ap._platform)" -Level 'INFO'

        $allPolicies.Add([PSCustomObject]@{
            PolicyType     = 'App Protection Policy'
            PolicyName     = $ap.displayName
            Platform       = $ap._platform
            AssignmentType = $result.AssignmentType
            AssignedVia    = $result.Via
            PolicyId       = $ap.id
        })
    }
}
Write-Status "$matchCount matching assignments found" $(if($matchCount -gt 0){'Green'}else{'DarkGray'})
#endregion

#region --- App Assignments ---
Write-Section "SCANNING: App Assignments"
$apps = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=(microsoft.graph.managedApp/appAvailability eq null or microsoft.graph.managedApp/appAvailability eq 'lineOfBusiness' or isAssigned eq true)&`$select=id,displayName,isAssigned"
Write-Status "Found $($apps.Count) apps, checking assignments..."
$matchCount = 0

foreach ($app in $apps) {
    if (-not $app.isAssigned) { continue }
    $assignments = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)/assignments"
    $results = Test-GroupAssignment -Assignments $assignments -TargetGroupId $targetGroupId -IncludeGlobalAssignments $includeGlobal

    foreach ($result in $results) {
        $matchCount++

        # Determine install intent for this specific assignment
        $intent = ($assignments | Where-Object {
            $t = $_.target.'@odata.type'
            ($t -eq '#microsoft.graph.groupAssignmentTarget' -and $_.target.groupId -eq $targetGroupId) -or
            ($t -eq '#microsoft.graph.allDevicesAssignmentTarget') -or
            ($t -eq '#microsoft.graph.allUsersAssignmentTarget') -or
            ($t -eq '#microsoft.graph.allLicensedUsersAssignmentTarget')
        } | Select-Object -First 1).intent

        $assignColor = if ($result.AssignmentType -eq 'Exclude') { 'DarkYellow' } else { 'Green' }
        $assignTag   = if ($result.AssignmentType -eq 'Exclude') { 'EXCLUDE' } else { 'INCLUDE' }
        $intentText  = if ($intent) { " (Intent: $intent)" } else { '' }

        Write-Log -Message "    [$assignTag] $($app.displayName)$intentText" -Level 'INFO'
        Write-Log -Message "              via: $($result.Via)" -Level 'INFO'

        $allPolicies.Add([PSCustomObject]@{
            PolicyType     = "App Assignment$(if($intent){" ($intent)"})"
            PolicyName     = $app.displayName
            Platform       = '-'
            AssignmentType = $result.AssignmentType
            AssignedVia    = $result.Via
            PolicyId       = $app.id
        })
    }
}
Write-Status "$matchCount matching app assignments found" $(if($matchCount -gt 0){'Green'}else{'DarkGray'})
#endregion

#endregion

#region --- Summary ---
Write-Section "SUMMARY FOR GROUP: $targetGroupName"
Write-Log -Message "" -Level 'INFO'

if ($allPolicies.Count -eq 0) {
    Write-Log -Message "  No policies found assigned to this group." -Level 'DEBUG'
} else {
    $includeCount = ($allPolicies | Where-Object { $_.AssignmentType -eq 'Include' }).Count
    $excludeCount = ($allPolicies | Where-Object { $_.AssignmentType -eq 'Exclude' }).Count
    Write-Log -Message "  Total assignments found : $($allPolicies.Count)" -Level 'SUCCESS'
    Write-Log -Message "  Included                : $includeCount" -Level 'SUCCESS'
    Write-Log -Message "  Excluded                : $excludeCount" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'

    $grouped = $allPolicies | Group-Object PolicyType | Sort-Object Name
    foreach ($grp in $grouped) {
        Write-Log -Message "  $($grp.Name) ($($grp.Count))" -Level 'WARNING'
        foreach ($p in $grp.Group) {
            $prefix = if ($p.AssignmentType -eq 'Exclude') { '[EXCLUDE]' } else { '[INCLUDE]' }
            $color  = if ($p.AssignmentType -eq 'Exclude') { 'DarkYellow' } else { 'White' }
            Write-Log -Message "    $prefix $($p.PolicyName)" -Level 'INFO'
            Write-Log -Message "      via: $($p.AssignedVia)" -Level 'DEBUG'
        }
        Write-Log -Message "" -Level 'INFO'
    }

    if ($ExportPath) {
        $allPolicies | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
        Write-Status "Exported to: $ExportPath" "Green"
    } else {
        $defaultPath = Join-Path $env:TEMP "$($targetGroupName -replace '[^\w\-]','_')_IntunePolicies_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $allPolicies | Export-Csv -Path $defaultPath -NoTypeInformation -Encoding UTF8
        Write-Status "Auto-exported to: $defaultPath" "Green"
    }
}

Write-Log -Message "`n$('='*60)" -Level 'DEBUG'
#endregion


