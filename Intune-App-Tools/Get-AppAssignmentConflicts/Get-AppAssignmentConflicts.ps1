<#
.TITLE
    Get App Assignment Conflicts

.SYNOPSIS
    Detects conflicting Intune app assignments: required versus uninstall, and groups that are both included and excluded.

.DESCRIPTION
    This script analyzes every Intune app's assignments and reports conflicts that
    produce unpredictable install behavior: the same app targeted with required and
    uninstall intent, the same group both included and excluded on one app, and the
    same group receiving the app with different intents. Group names are resolved so
    the report is directly actionable. These conflicts commonly appear after mergers
    of app deployments or copy-pasted assignment changes and are hard to spot in the
    portal.

    Supports workstation dual-mode: interactive sign-in (auto-installs Microsoft.Graph.Authentication if missing; WAM-free via MgGraphCommunity when available) and optional app-only authentication via -TenantId/-ClientId with -ClientSecret or -CertificateThumbprint.

.TAGS
    Apps,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementApps.Read.All,Group.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.2.1

.CHANGELOG
    1.2.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.2 - Added contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.1 -     1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-app-assignment-conflicts.ps1
    Reports all app assignment conflicts in the console

.EXAMPLE
    .\get-app-assignment-conflicts.ps1 -ExportToCsv "true"
    Exports the conflict report to a timestamped CSV file

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Required + available for the same group is reported as informational, not a conflict (required wins by design)
    - Nested group membership is not evaluated; only direct assignment targets are compared
    - Uses beta Graph endpoints for the app assignment surface
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Export results to CSV")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ExportToCsv,

    [Parameter(Mandatory = $false, HelpMessage = "Output path for exports")]
    [string]$OutputPath = "",

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall
)

# Resolve OutputPath beside the script when caller passes "." or empty (Law 12).
$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
if (-not $OutputPath -or $OutputPath -eq ".") {
    $OutputPath = $scriptDirectory
} elseif ($PSBoundParameters.ContainsKey('OutputPath') -and $OutputPath -and -not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptDirectory $OutputPath
}

$ErrorActionPreference = 'Stop'

# Normalize the local module-install override for string parameter binding.
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

# String parameter values are normalized to booleans.

foreach ($runbookBooleanParameter in @('ExportToCsv')) {
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
# MAIN FLOW INITIALIZATION - structured logging starts before any tenant work.
# Flow: init log -> banner -> module setup -> Graph auth -> main logic.
# ============================================================================

$SolutionName = 'get-app-assignment-conflicts'
$ScriptMode   = 'run'

$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
Write-Banner

# ============================================================================
# ENVIRONMENT DETECTION AND SETUP
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
            catch [System.Exception] {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }

        Import-Module -Name $ModuleName -Force -ErrorAction Stop
    }
}

# Detect execution environment

# Initialize required modules
$RequiredModules = @("Microsoft.Graph.Authentication")

# MgGraphCommunity provides WAM-free interactive sign-in for workstation scenarios
$RequiredModules += "MgGraphCommunity"

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "✓ All required modules are available"
}
catch [System.Exception] {
    Write-Error "Module initialization failed: $_"
    exit 1
}

# ============================================================================
# AUTHENTICATION
# ============================================================================

try {
    $scopes = @(
            "DeviceManagementApps.Read.All",
            "Group.Read.All"
        )

    if ($TenantId -and $ClientId -and ($ClientSecret -or $CertificateThumbprint)) {
        Write-Output "Connecting to Microsoft Graph with app-only authentication..."
        if ($CertificateThumbprint) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        else {
            $secureSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $secureSecret
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecretCredential $credential -NoWelcome -ErrorAction Stop
        }
        Write-Output "✓ Successfully connected to Microsoft Graph (app-only)"
    }
    else {
        Write-Output "Connecting to Microsoft Graph..."
        if (Get-Module -ListAvailable -Name MgGraphCommunity) {
            Connect-MgGraphCommunity -Scopes $scopes -NoWelcome -ErrorAction Stop
        }
        else {
            Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
        }
        Write-Output "✓ Successfully connected to Microsoft Graph"
    }
}
catch [System.Exception] {
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

    if (-not $GroupId) { return "" }
    if ($script:GroupNameCache.ContainsKey($GroupId)) { return $script:GroupNameCache[$GroupId] }

    $name = $GroupId
    try {
        $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/groups/${GroupId}?`$select=displayName" -Method GET
        if ($group.displayName) { $name = $group.displayName }
    }
    catch {
        Write-Verbose "Could not resolve group ${GroupId}: $($_.Exception.Message)"
    }

    $script:GroupNameCache[$GroupId] = $name
    return $name
}

function Get-TargetKey {
    param([object]$Target)

    # Normalize every assignment target to a comparable key
    switch -Wildcard ([string]$Target.'@odata.type') {
        "*allDevicesAssignmentTarget" { return "AllDevices" }
        "*allLicensedUsersAssignmentTarget" { return "AllUsers" }
        default { return [string]$Target.groupId }
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    Write-Output "Retrieving apps with assignments..."
    $apps = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$expand=assignments"

    $assignedApps = @($apps | Where-Object { @($_.assignments).Count -gt 0 })
    Write-Output "✓ Found $($assignedApps.Count) apps with assignments (of $(@($apps).Count) total)"

    [System.Collections.Generic.List[Object]]$conflicts = @()

    foreach ($app in $assignedApps) {
        $assignments = @($app.assignments)

        # Build per-target views of intent and include/exclude
        $includedTargets = @{}
        $excludedTargets = @{}
        $intents = [System.Collections.Generic.HashSet[string]]::new()

        foreach ($assignment in $assignments) {
            $target = $assignment.target
            $targetKey = Get-TargetKey -Target $target
            if (-not $targetKey) { continue }

            $intent = [string]$assignment.intent
            $null = $intents.Add($intent)

            if ([string]$target.'@odata.type' -like "*exclusionGroupAssignmentTarget") {
                $excludedTargets[$targetKey] = $intent
            }
            else {
                if (-not $includedTargets.ContainsKey($targetKey)) {
                    $includedTargets[$targetKey] = [System.Collections.Generic.List[string]]::new()
                }
                $includedTargets[$targetKey].Add($intent)
            }
        }

        $appType = ([string]$app.'@odata.type') -replace "#microsoft.graph.", ""

        # Conflict 1: required and uninstall on the same app
        if ($intents.Contains("required") -and $intents.Contains("uninstall")) {
            $conflicts.Add([PSCustomObject]@{
                    AppName      = $app.displayName
                    AppType      = $appType
                    ConflictType = "RequiredAndUninstall"
                    Details      = "App is deployed with intent 'required' and 'uninstall' at the same time - install outcome depends on target overlap"
                    Group        = ""
                    AppId        = $app.id
                })
        }

        # Conflict 2: same group both included and excluded
        foreach ($targetKey in $includedTargets.Keys) {
            if ($excludedTargets.ContainsKey($targetKey)) {
                $groupName = Resolve-GroupName -GroupId $targetKey
                $conflicts.Add([PSCustomObject]@{
                        AppName      = $app.displayName
                        AppType      = $appType
                        ConflictType = "IncludedAndExcluded"
                        Details      = "Group is both an include target ($($includedTargets[$targetKey] -join ', ')) and an exclude target"
                        Group        = $groupName
                        AppId        = $app.id
                    })
            }
        }

        # Conflict 3: same group targeted with multiple different intents
        foreach ($targetKey in $includedTargets.Keys) {
            $groupIntents = @($includedTargets[$targetKey] | Select-Object -Unique)
            if ($groupIntents.Count -gt 1) {
                $groupName = Resolve-GroupName -GroupId $targetKey
                $severity = if ($groupIntents -contains "uninstall") { "MixedIntentWithUninstall" } else { "MixedIntent" }
                $conflicts.Add([PSCustomObject]@{
                        AppName      = $app.displayName
                        AppType      = $appType
                        ConflictType = $severity
                        Details      = "Same target has intents: $($groupIntents -join ', ')"
                        Group        = $groupName
                        AppId        = $app.id
                    })
            }
        }
    }

    # ----- Display results -----
    Write-Output "`nAPP ASSIGNMENT CONFLICT REPORT"
    Write-Output ("=" * 50)
    Write-Output "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    if ($conflicts.Count -eq 0) {
        Write-Output "`nNo assignment conflicts found."
    }
    else {
        foreach ($conflictGroup in ($conflicts | Group-Object -Property ConflictType | Sort-Object Name)) {
            Write-Output "`n[$($conflictGroup.Name)] $($conflictGroup.Count) finding(s)"
            foreach ($row in ($conflictGroup.Group | Sort-Object AppName)) {
                $line = "  $($row.AppName)"
                if ($row.Group) { $line += " | group: $($row.Group)" }
                Write-Output $line
                Write-Output "    $($row.Details)"
            }
        }
    }

    # Summary
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($assignedApps.Count) assigned apps analyzed, $($conflicts.Count) conflicts found"
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "App_Assignment_Conflicts_$timestamp.csv"
        $conflicts | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Output "✓ CSV report saved: $csvPath"
    }
}
catch {
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
