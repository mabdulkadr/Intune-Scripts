<#
.TITLE
    Get Assignment Matrix Report

.SYNOPSIS
    Builds a who-gets-what matrix of every Intune policy, profile, script, and app mapped to its assignment targets and filters.

.DESCRIPTION
    This script connects to Microsoft Graph and collects assignments across the major
    Intune surfaces: device configuration profiles, settings catalog policies,
    compliance policies, administrative template (ADMX) policies, platform scripts,
    remediation scripts, and applications. Every assignment is flattened into one row
    showing the target (group, all users, all devices, or exclusion), the resolved
    group name, the assignment filter with its mode, and the install intent for apps.
    The result answers "what does this group actually get" and "what targets this
    device population" in a single CSV. Supports both interactive sign-in (delegated) and app-only authentication (client secret or certificate) on the workstation. Workstation-only execution.

.TAGS
    Configuration,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,DeviceManagementApps.Read.All,DeviceManagementScripts.Read.All,Group.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.3.1

.CHANGELOG
    1.3.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.3 - Declare and request DeviceManagementScripts.Read.All for PowerShell, shell, and remediation script inventory
    1.2 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.1 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-assignment-matrix-report.ps1
    Shows the assignment matrix for all surfaces in the console

.EXAMPLE
    .\get-assignment-matrix-report.ps1 -ExportToCsv "true"
    Exports the full assignment matrix to a timestamped CSV file

.EXAMPLE
    .\get-assignment-matrix-report.ps1 -Surfaces Apps,CompliancePolicies -IncludeUnassigned "true"
    Reports only apps and compliance policies, including objects that have no assignments

.NOTES
    - Requires Microsoft.Graph.Authentication module (auto-installed if missing)
    - Uses beta Graph endpoints because several Intune assignment surfaces are not exposed on v1.0
    - Apps without assignments are skipped unless -IncludeUnassigned is used (the app catalog contains many built-in unassigned entries)
    - Group names are resolved once and cached; deleted groups show as their object ID
    - Interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows if present, with fallback to Microsoft.Graph.Authentication
    - Workstation dual-mode: interactive (delegated) or app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint
    - Relative CSV output paths resolve beside this script, not the caller's working directory
    - Logs: %ProgramData%\get-assignment-matrix-report\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Assignment surfaces to include")]
    [ValidateSet("DeviceConfigurations", "SettingsCatalog", "CompliancePolicies", "AdmxPolicies", "PlatformScripts", "Remediations", "Apps")]
    [string[]]$Surfaces = @("DeviceConfigurations", "SettingsCatalog", "CompliancePolicies", "AdmxPolicies", "PlatformScripts", "Remediations", "Apps"),

    [Parameter(Mandatory = $false, HelpMessage = "Include objects that have no assignments")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeUnassigned,

    [Parameter(Mandatory = $false, HelpMessage = "Export results to CSV")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ExportToCsv,

    [Parameter(Mandatory = $false, HelpMessage = "Output path for exports")]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Entra tenant ID for app-only authentication")]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "App registration client ID for app-only authentication")]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication")]
    [string]$CertificateThumbprint
)

$ErrorActionPreference = 'Stop'

# Normalize the local module-install override for workstation parameter binding.
$forceModuleInstallRaw = [string]$ForceModuleInstall
Remove-Variable -Name ForceModuleInstall
if ([string]::IsNullOrWhiteSpace($forceModuleInstallRaw)) {
    $ForceModuleInstall = $false
}
elseif ($forceModuleInstallRaw.Trim().ToLowerInvariant() -in @("true", "1", '$true')) {
    $ForceModuleInstall = $true
}
elseif ($forceModuleInstallRaw.Trim().ToLowerInvariant() -in @("false", "0", '$false')) {
    $ForceModuleInstall = $false
}
else {
    throw "Parameter 'ForceModuleInstall' accepts only true, false, 1, 0, $true, or $false."
}

# Workstation string boolean normalization. Normalize the
# public boolean parameters once so workstation execution uses real booleans.
foreach ($runbookBooleanParameter in @('IncludeUnassigned', 'ExportToCsv')) {
    $runbookBooleanRaw = [string](Get-Variable -Name $runbookBooleanParameter -ValueOnly)
    Remove-Variable -Name $runbookBooleanParameter

    if ([string]::IsNullOrWhiteSpace($runbookBooleanRaw)) {
        Set-Variable -Name $runbookBooleanParameter -Value $false
        continue
    }

    switch ($runbookBooleanRaw.Trim().ToLowerInvariant()) {
        { $_ -in @("true", "1", '$true') } {
            Set-Variable -Name $runbookBooleanParameter -Value $true
        }
        { $_ -in @("false", "0", '$false') } {
            Set-Variable -Name $runbookBooleanParameter -Value $false
        }
        default {
            throw "Parameter '$runbookBooleanParameter' accepts only true, false, 1, 0, $true, or $false."
        }
    }
}

# ============================================================================
# CONFIGURATION - solution identity for structured logging.
# ============================================================================

$SolutionName = 'get-assignment-matrix-report'
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
# OUTPUT PATH ANCHORING - relative export paths resolve beside this script.
# ============================================================================

$scriptBase = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    (Get-Location).Path
}
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptBase $OutputPath
}

# ============================================================================
# MODULE SETUP (workstation)
# ============================================================================

function Initialize-RequiredModule {
    param(
        [string[]]$ModuleNames,
        [bool]$ForceInstall = $false
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-Verbose "Checking module: $ModuleName"

        $module = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

        if (-not $module) {
            Write-Information "Module '$ModuleName' not found. Installing..." -InformationAction Continue

            if (-not $ForceInstall) {
                $response = Read-Host "Install module '$ModuleName'? (Y/N)"
                if ($response -notmatch '^[Yy]') {
                    throw "Module '$ModuleName' is required but installation was declined."
                }
            }

            try {
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }

                Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                Write-Information "✓ Successfully installed '$ModuleName'" -InformationAction Continue
            }
            catch {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }

        Import-Module -Name $ModuleName -Force -ErrorAction Stop
    }
}

# Initialize required modules (workstation - auto-install Microsoft.Graph.Authentication if missing)
$RequiredModules = @("Microsoft.Graph.Authentication", "MgGraphCommunity")

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "✓ All required modules are available"
}
catch {
    Write-Error "Module initialization failed: $_"
    exit 1
}

# ============================================================================
# AUTHENTICATION (workstation dual-mode: interactive or app-only)
# ============================================================================

try {
    $isAppOnly = (-not [string]::IsNullOrWhiteSpace($TenantId) -and -not [string]::IsNullOrWhiteSpace($ClientId) -and (-not [string]::IsNullOrWhiteSpace($ClientSecret) -or -not [string]::IsNullOrWhiteSpace($CertificateThumbprint)))
    if ($isAppOnly) {
        Write-Output "Connecting to Microsoft Graph (app-only)..."
        if (-not [string]::IsNullOrWhiteSpace($CertificateThumbprint)) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        else {
            $secureSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $secureSecret -NoWelcome -ErrorAction Stop
        }
    }
    else {
        Write-Output "Connecting to Microsoft Graph (interactive)..."
        $Scopes = @(
            "DeviceManagementConfiguration.Read.All",
            "DeviceManagementApps.Read.All",
            "DeviceManagementScripts.Read.All",
            "Group.Read.All"
        )
        try {
            if (Get-Module -ListAvailable -Name MgGraphCommunity) {
                Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
            }
            else {
                Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
            }
        }
        catch {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
    }
    Write-Output "✓ Successfully connected to Microsoft Graph"
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-MgGraphAllPages {
    param(
        [string]$Uri,
        [int]$DelayMs = 100
    )

    $allResults = @()
    $nextLink = $Uri

    do {
        try {
            if ($allResults.Count -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }

            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET

            if ($null -ne $response.value) {
                $allResults += $response.value
            }
            else {
                $allResults += $response
            }

            $nextLink = $response.'@odata.nextLink'
        }
        catch {
            if ($_.Exception.Message -like "*429*") {
                Write-Information "Rate limit hit, waiting 60 seconds..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data: $($_.Exception.Message)"
        }
    } while ($nextLink)

    return $allResults
}

$script:GroupNameCache = @{}

function Resolve-GroupName {
    param([string]$GroupId)

    if ($script:GroupNameCache.ContainsKey($GroupId)) {
        return $script:GroupNameCache[$GroupId]
    }

    $name = $GroupId
    try {
        $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/groups/${GroupId}?`$select=displayName" -Method GET
        if ($group.displayName) {
            $name = $group.displayName
        }
    }
    catch {
        Write-Verbose "Could not resolve group ${GroupId}: $($_.Exception.Message)"
    }

    $script:GroupNameCache[$GroupId] = $name
    return $name
}

function ConvertTo-AssignmentRow {
    param(
        [string]$SurfaceName,
        [string]$ObjectName,
        [string]$ObjectId,
        [object]$Assignment,
        [hashtable]$FilterLookup
    )

    $target = $Assignment.target
    $targetType = switch -Wildcard ($target.'@odata.type') {
        "*allDevicesAssignmentTarget" { "All Devices" }
        "*allLicensedUsersAssignmentTarget" { "All Users" }
        "*exclusionGroupAssignmentTarget" { "Excluded Group" }
        "*groupAssignmentTarget" { "Included Group" }
        default { $target.'@odata.type' -replace "#microsoft.graph.", "" }
    }

    $groupName = ""
    if ($target.groupId) {
        $groupName = Resolve-GroupName -GroupId $target.groupId
    }

    $filterName = ""
    $filterType = ""
    if ($target.deviceAndAppManagementAssignmentFilterId -and $target.deviceAndAppManagementAssignmentFilterType -ne "none") {
        $filterType = $target.deviceAndAppManagementAssignmentFilterType
        $filterName = if ($FilterLookup.ContainsKey($target.deviceAndAppManagementAssignmentFilterId)) {
            $FilterLookup[$target.deviceAndAppManagementAssignmentFilterId]
        }
        else {
            $target.deviceAndAppManagementAssignmentFilterId
        }
    }

    return [PSCustomObject]@{
        Surface    = $SurfaceName
        Name       = $ObjectName
        ObjectId   = $ObjectId
        TargetType = $targetType
        GroupName  = $groupName
        GroupId    = if ($target.groupId) { $target.groupId } else { "" }
        Intent     = if ($Assignment.intent) { $Assignment.intent } else { "" }
        FilterName = $filterName
        FilterMode = $filterType
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================
# Flow: log init -> banner -> load filters -> flatten assignments -> report.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Assignment matrix report started" -Level 'INFO'

    Write-Output "Building assignment matrix..."

    # Filter names are needed for every row, so fetch them once up front
    $filterLookup = @{}
    try {
        $filters = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters?`$select=id,displayName"
        foreach ($filter in $filters) {
            $filterLookup[$filter.id] = $filter.displayName
        }
        Write-Output "✓ Loaded $(@($filters).Count) assignment filters"
    }
    catch {
        Write-Warning "Could not load assignment filters, filter names will show as IDs: $($_.Exception.Message)"
    }

    # Each surface definition: list endpoint plus how to read the display name
    $surfaceDefinitions = @(
        @{ Key = "DeviceConfigurations"; Label = "Configuration Profile"; Uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$expand=assignments"; NameProperty = "displayName" },
        @{ Key = "SettingsCatalog"; Label = "Settings Catalog Policy"; Uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$expand=assignments"; NameProperty = "name" },
        @{ Key = "CompliancePolicies"; Label = "Compliance Policy"; Uri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies?`$expand=assignments"; NameProperty = "displayName" },
        @{ Key = "AdmxPolicies"; Label = "Administrative Template"; Uri = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations?`$expand=assignments"; NameProperty = "displayName" },
        @{ Key = "PlatformScripts"; Label = "PowerShell Script"; Uri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts?`$expand=assignments"; NameProperty = "displayName" },
        @{ Key = "PlatformScripts"; Label = "Shell Script (macOS)"; Uri = "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts?`$expand=assignments"; NameProperty = "displayName" },
        @{ Key = "Remediations"; Label = "Remediation Script"; Uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?`$expand=assignments"; NameProperty = "displayName" },
        @{ Key = "Apps"; Label = "Application"; Uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$expand=assignments"; NameProperty = "displayName" }
    )

    [System.Collections.Generic.List[Object]]$matrix = @()
    $unassignedCount = 0

    foreach ($surface in $surfaceDefinitions) {
        if ($Surfaces -notcontains $surface.Key) {
            continue
        }

        Write-Output "Collecting: $($surface.Label)..."
        $objects = Get-MgGraphAllPages -Uri $surface.Uri

        foreach ($object in $objects) {
            $objectName = $object.($surface.NameProperty)
            $assignments = @($object.assignments)

            if ($assignments.Count -eq 0) {
                $unassignedCount++
                if ($IncludeUnassigned) {
                    $matrix.Add([PSCustomObject]@{
                            Surface    = $surface.Label
                            Name       = $objectName
                            ObjectId   = $object.id
                            TargetType = "Not assigned"
                            GroupName  = ""
                            GroupId    = ""
                            Intent     = ""
                            FilterName = ""
                            FilterMode = ""
                        })
                }
                continue
            }

            foreach ($assignment in $assignments) {
                $matrix.Add((ConvertTo-AssignmentRow -SurfaceName $surface.Label -ObjectName $objectName -ObjectId $object.id -Assignment $assignment -FilterLookup $filterLookup))
            }
        }

        Write-Output "✓ $($surface.Label): $(@($objects).Count) objects"
    }

    # Display results grouped by surface
    Write-Output "`nASSIGNMENT MATRIX"
    Write-Output ("=" * 50)
    Write-Output "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    foreach ($surfaceGroup in ($matrix | Group-Object -Property Surface | Sort-Object Name)) {
        Write-Output "`n$($surfaceGroup.Name) ($($surfaceGroup.Count) assignments)"

        foreach ($row in ($surfaceGroup.Group | Sort-Object Name)) {
            $targetInfo = $row.TargetType
            if ($row.GroupName) { $targetInfo += ": $($row.GroupName)" }
            if ($row.Intent) { $targetInfo += " [$($row.Intent)]" }
            if ($row.FilterName) { $targetInfo += " (filter: $($row.FilterName)/$($row.FilterMode))" }
            Write-Output "  $($row.Name) -> $targetInfo"
        }
    }

    # Summary
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($matrix.Count) assignment rows, $($script:GroupNameCache.Count) unique groups, $unassignedCount unassigned objects"
    if (-not $IncludeUnassigned -and $unassignedCount -gt 0) {
        Write-Output "Tip: run with -IncludeUnassigned to list the $unassignedCount unassigned objects"
    }
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Intune_Assignment_Matrix_$timestamp.csv"
        $matrix | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Output "✓ CSV report saved: $csvPath"
    }

    Write-Log -Message "Assignment matrix completed: $($matrix.Count) rows, $($script:GroupNameCache.Count) unique groups" -Level 'SUCCESS'
}
catch {
    Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    try {
        $null = Disconnect-MgGraph
        Write-Output "✓ Disconnected from Microsoft Graph"
    }
    catch {
        Write-Verbose "Graph disconnection completed"
    }
}
