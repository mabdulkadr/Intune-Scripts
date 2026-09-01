<#
.TITLE
    User Policy Assignment Report

.SYNOPSIS
    Retrieves all Intune policies and apps assigned to a specific user.

.DESCRIPTION
    Queries Microsoft Graph to find every policy (configuration profiles, compliance, Settings Catalog, endpoint security, update rings, scripts, app config, app protection, etc.) assigned to a user via their transitive group memberships, "All Users", or "All Licensed Users". Also shows the user's Intune-managed devices and their compliance state.

.TAGS
    User,Assignment,Intune,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.Read.All,DeviceManagementServiceConfig.Read.All,Device.Read.All,Directory.Read.All,Group.Read.All,GroupMember.Read.All,User.Read.All,DeviceManagementApps.Read.All

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
    .\Get-IntuneUserPolicies.ps1 -UserPrincipalName "jsmith@contoso.com"
 .EXAMPLE
    .\Get-IntuneUserPolicies.ps1 -UserId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -ExportPath "C:\temp\user_policies.csv"

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Logs: %ProgramData%\get-intuneuserpolicies\Logs
#>

#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = 'ByUPN')]
param(
    [Parameter(Mandatory, ParameterSetName = 'ByUPN')]
    [string]$UserPrincipalName,

    [Parameter(Mandatory, ParameterSetName = 'ById')]
    [string]$UserId,

    [Parameter()]
    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'get-intuneuserpolicies'
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

function Test-UserAssignmentMatch {
    <#
    .SYNOPSIS
        Checks if a policy's assignments target a user via their group memberships
        or via "All Users" / "All Licensed Users" global assignments.
        Returns match info with Include/Exclude and which group triggered the match.
    #>
    param(
        [array]$Assignments,
        [array]$UserGroupIds,
        [hashtable]$GroupNameMap
    )
    $matchResults = @()

    foreach ($a in $Assignments) {
        $target = $a.target
        if (-not $target) { continue }
        $type = $target.'@odata.type'

        switch ($type) {
            '#microsoft.graph.allUsersAssignmentTarget' {
                $matchResults += @{ AssignmentType = 'Include'; Via = 'All Users' }
            }
            '#microsoft.graph.allLicensedUsersAssignmentTarget' {
                $matchResults += @{ AssignmentType = 'Include'; Via = 'All Licensed Users' }
            }
            '#microsoft.graph.groupAssignmentTarget' {
                $gid = $target.groupId
                if ($UserGroupIds -contains $gid) {
                    $gName = if ($GroupNameMap.ContainsKey($gid)) { "$($GroupNameMap[$gid]) ($gid)" } else { $gid }
                    $matchResults += @{ AssignmentType = 'Include'; Via = "Group: $gName" }
                }
            }
            '#microsoft.graph.exclusionGroupAssignmentTarget' {
                $gid = $target.groupId
                if ($UserGroupIds -contains $gid) {
                    $gName = if ($GroupNameMap.ContainsKey($gid)) { "$($GroupNameMap[$gid]) ($gid)" } else { $gid }
                    $matchResults += @{ AssignmentType = 'Exclude'; Via = "Group Exclusion: $gName" }
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
        'User.Read.All',
        'DeviceManagementApps.Read.All'
    ) -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"
#endregion

#region --- Resolve User ---
Write-Section "RESOLVING USER"

if ($UserPrincipalName) {
    Write-Status "Looking up user: $UserPrincipalName"
    # Try direct GET first, then filter as fallback
    $user = $null
    try {
        Write-Status "Trying direct GET..." "DarkGray"
        $user = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$UserPrincipalName" -Method GET -ErrorAction Stop
        Write-Status "Direct GET succeeded" "Green"
    } catch [System.Exception] {
        Write-Log -Message "  Direct GET failed: $_" -Level 'WARNING'
        # Direct GET failed - try with filter
        try {
            Write-Status "Trying filter query..." "DarkGray"
            $filterUri = "https://graph.microsoft.com/v1.0/users?`$filter=mail eq '$UserPrincipalName' or userPrincipalName eq '$UserPrincipalName'"
            $filterResult = Invoke-MgGraphRequest -Uri $filterUri -Method GET -ErrorAction Stop
            if ($filterResult.value -and $filterResult.value.Count -gt 0) {
                $user = $filterResult.value[0]
                Write-Status "Filter query succeeded" "Green"
            } else {
                Write-Log -Message "  Filter returned 0 results" -Level 'WARNING'
            }
        } catch [System.Exception] {
            Write-Log -Message "  Filter query failed: $_" -Level 'WARNING'
        }
    }
    if (-not $user -or -not $user.id) {
        Write-Log -Message "  ERROR: User '$UserPrincipalName' not found in Entra ID." -Level 'ERROR'
        return
    }
} else {
    Write-Status "Looking up user ID: $UserId"
    try {
        $user = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$UserId" -Method GET -ErrorAction Stop
    } catch [System.Exception] {
        $user = $null
    }
    if (-not $user) {
        Write-Log -Message "  ERROR: User ID '$UserId' not found in Entra ID." -Level 'ERROR'
        return
    }
}

$targetUserId  = $user.id
$targetUPN     = $user.userPrincipalName
$displayName   = $user.displayName
$jobTitle      = $user.jobTitle
$department    = $user.department
$accountEnabled = $user.accountEnabled
$licenseCount  = if ($user.assignedLicenses) { $user.assignedLicenses.Count } else { 0 }

Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Display Name     : $displayName" -Level 'INFO'
Write-Log -Message "  UPN              : $targetUPN" -Level 'INFO'
Write-Log -Message "  User ID          : $targetUserId" -Level 'DEBUG'
Write-Log -Message "  Job Title        : $(if($jobTitle){$jobTitle}else{'-'})" -Level 'DEBUG'
Write-Log -Message "  Department       : $(if($department){$department}else{'-'})" -Level 'DEBUG'
Write-Log -Message "  Account Enabled  : $accountEnabled" -Level 'INFO'
Write-Log -Message "  Assigned Licenses: $licenseCount" -Level 'DEBUG'
#endregion

#region --- User's Managed Devices ---
Write-Section "USER'S INTUNE MANAGED DEVICES"
$managedDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=userPrincipalName eq '$targetUPN'"

if ($managedDevices.Count -eq 0) {
    Write-Log -Message "  No Intune managed devices found for this user." -Level 'DEBUG'
} else {
    Write-Status "$($managedDevices.Count) managed device(s) found:" "Green"
    foreach ($md in $managedDevices) {
        $compColor = if ($md.complianceState -eq 'compliant') { 'Green' } elseif ($md.complianceState -eq 'noncompliant') { 'Red' } else { 'Yellow' }
        Write-Log -Message "    $($md.deviceName)" -Level 'INFO'
        Write-Log -Message " | $($md.operatingSystem) $($md.osVersion)" -Level 'DEBUG'
        Write-Log -Message " | $($md.complianceState)" -Level 'INFO'
        Write-Log -Message " | Last sync: $($md.lastSyncDateTime)" -Level 'DEBUG'
    }
}
#endregion

#region --- Resolve Group Memberships ---
Write-Section "RESOLVING USER GROUP MEMBERSHIPS"

Write-Status "Getting transitive group memberships for $targetUPN..."
$userMemberships = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/users/$targetUserId/transitiveMemberOf?`$select=id,displayName,@odata.type"
$userGroups = $userMemberships | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }
$userGroupIds = $userGroups | ForEach-Object { $_.id }

$groupNameMap = @{}
foreach ($g in $userGroups) {
    if ($g.id -and $g.displayName) { $groupNameMap[$g.id] = $g.displayName }
}

Write-Status "User is a member of $($userGroupIds.Count) groups" "Green"
if ($userGroupIds.Count -gt 0 -and $userGroupIds.Count -le 20) {
    foreach ($g in $userGroups) {
        Write-Log -Message "    - $($g.displayName)" -Level 'INFO'
    }
} elseif ($userGroupIds.Count -gt 20) {
    foreach ($g in ($userGroups | Select-Object -First 20)) {
        Write-Log -Message "    - $($g.displayName)" -Level 'INFO'
    }
    Write-Log -Message "    ... and $($userGroupIds.Count - 20) more" -Level 'DEBUG'
}
#endregion

#region --- Policy Discovery ---
$allPolicies = [System.Collections.Generic.List[PSCustomObject]]::new()

# --- Standard policy types ---
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
        $assignments = if ($expandWorked -and $p.assignments) {
            $p.assignments
        } else {
            Get-PolicyAssignments -PolicyId $p.id -BaseUri $pt.Uri
        }

        $results = Test-UserAssignmentMatch -Assignments $assignments -UserGroupIds $userGroupIds -GroupNameMap $groupNameMap

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
    $results = Test-UserAssignmentMatch -Assignments $assignments -UserGroupIds $userGroupIds -GroupNameMap $groupNameMap

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
    $results = Test-UserAssignmentMatch -Assignments $assignments -UserGroupIds $userGroupIds -GroupNameMap $groupNameMap

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
    $results = Test-UserAssignmentMatch -Assignments $assignments -UserGroupIds $userGroupIds -GroupNameMap $groupNameMap

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
    $results = Test-UserAssignmentMatch -Assignments $assignments -UserGroupIds $userGroupIds -GroupNameMap $groupNameMap

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
    $results = Test-UserAssignmentMatch -Assignments $assignments -UserGroupIds $userGroupIds -GroupNameMap $groupNameMap

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

$iosAppProtection = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections?`$expand=Assignments"
$androidAppProtection = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections?`$expand=Assignments"
$windowsAppProtection = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/windowsInformationProtectionPolicies?`$expand=Assignments"
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
    $results = Test-UserAssignmentMatch -Assignments $assignments -UserGroupIds $userGroupIds -GroupNameMap $groupNameMap

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
    $results = Test-UserAssignmentMatch -Assignments $assignments -UserGroupIds $userGroupIds -GroupNameMap $groupNameMap

    foreach ($result in $results) {
        $matchCount++

        # Determine install intent for the matching assignment
        $intent = ($assignments | Where-Object {
            $t = $_.target.'@odata.type'
            ($t -eq '#microsoft.graph.groupAssignmentTarget' -and $userGroupIds -contains $_.target.groupId) -or
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
Write-Section "SUMMARY FOR USER: $displayName ($targetUPN)"
Write-Log -Message "" -Level 'INFO'

if ($allPolicies.Count -eq 0) {
    Write-Log -Message "  No policies found assigned to this user." -Level 'DEBUG'
} else {
    $includeCount = ($allPolicies | Where-Object { $_.AssignmentType -eq 'Include' }).Count
    $excludeCount = ($allPolicies | Where-Object { $_.AssignmentType -eq 'Exclude' }).Count
    Write-Log -Message "  Total assignments found : $($allPolicies.Count)" -Level 'SUCCESS'
    Write-Log -Message "  Included                : $includeCount" -Level 'SUCCESS'
    Write-Log -Message "  Excluded                : $excludeCount" -Level 'INFO'
    Write-Log -Message "  User is in              : $($userGroupIds.Count) groups" -Level 'DEBUG'
    Write-Log -Message "  Managed devices         : $($managedDevices.Count)" -Level 'DEBUG'
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
        $safeName = ($targetUPN -split '@')[0] -replace '[^\w\-]','_'
        $defaultPath = Join-Path $env:TEMP "$safeName`_IntunePolicies_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $allPolicies | Export-Csv -Path $defaultPath -NoTypeInformation -Encoding UTF8
        Write-Status "Auto-exported to: $defaultPath" "Green"
    }
}

Write-Log -Message "`n$('='*60)" -Level 'DEBUG'
#endregion

