<#
.TITLE
    Get Policy Drift Report

.SYNOPSIS
    Compares current Intune policies against a baseline backup and reports every added, removed, or changed policy.

.DESCRIPTION
    This script takes a baseline folder created by backup-intune-configuration.ps1 and
    compares the tenant's current state against it: settings catalog policies (full
    setting bodies), classic device configuration profiles, and compliance policies.
    Policies are matched by object ID, and their configuration is compared as
    normalized JSON with volatile properties (timestamps, versions) removed. The
    report shows policies that were added, deleted, or modified since the baseline,
    making unreviewed configuration drift visible for change control. Supports both interactive sign-in (delegated) and app-only authentication (client secret or certificate) on the workstation. Workstation-only execution.

.TAGS
    Configuration,Monitoring

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.2.1

.CHANGELOG
    1.2.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.2 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.1 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-policy-drift-report.ps1 -BaselinePath ".\IntuneConfigBackup_2026-07-01_08-00-00"
    Compares the current tenant state against the July 1st baseline

.EXAMPLE
    .\get-policy-drift-report.ps1 -BaselinePath ".\IntuneConfigBackup_2026-07-01_08-00-00" -ExportToCsv "true"
    Exports the drift report to a timestamped CSV file

.NOTES
    - Requires Microsoft.Graph.Authentication module (auto-installed if missing)
    - The baseline must be a folder created by backup-intune-configuration.ps1
    - Policies are matched by ID, so a policy that was deleted and recreated appears as one deletion plus one addition
    - Timestamps, version counters, and assignment state are excluded from the comparison; only configuration content counts as drift
    - Uses beta Graph endpoints because the full Intune configuration surface is not exposed on v1.0
    - Interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows if present, with fallback to Microsoft.Graph.Authentication
    - Workstation dual-mode: interactive (delegated) or app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint
    - Relative CSV output paths resolve beside this script, not the caller's working directory
    - Logs: %ProgramData%\get-policy-drift-report\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to a baseline folder created by backup-intune-configuration.ps1")]
    [ValidateNotNullOrEmpty()]
    [string]$BaselinePath,

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
# CONFIGURATION - solution identity for structured logging.
# ============================================================================

$SolutionName = 'get-policy-drift-report'
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
            "DeviceManagementConfiguration.Read.All"
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

function ConvertTo-NormalizedJson {
    param([object]$InputObject)

    # Volatile properties change without any admin action; excluding them keeps
    # the comparison focused on actual configuration content
    $volatileProperties = @(
        "lastModifiedDateTime", "createdDateTime", "version", "settingCount",
        "assignments", "supportsScopeTags", "priorityMetaData", "creationSource"
    )

    $clone = $InputObject | ConvertTo-Json -Depth 30 | ConvertFrom-Json

    foreach ($property in $volatileProperties) {
        if ($clone.PSObject.Properties[$property]) {
            $clone.PSObject.Properties.Remove($property)
        }
    }
    foreach ($property in @($clone.PSObject.Properties.Name)) {
        if ($property -like "*@odata.context" -or $property -like "*@odata.count") {
            $clone.PSObject.Properties.Remove($property)
        }
    }

    return ($clone | ConvertTo-Json -Depth 30)
}

function Compare-PolicyArea {
    param(
        [string]$AreaLabel,
        [string]$BaselineFolder,
        [object[]]$CurrentPolicies,
        [string]$NameProperty
    )

    $rows = [System.Collections.Generic.List[Object]]::new()

    $baselineFiles = @()
    $folder = Join-Path $BaselinePath $BaselineFolder
    if (Test-Path $folder) {
        $baselineFiles = @(Get-ChildItem -Path $folder -Filter "*.json" -File)
    }
    else {
        Write-Warning "Baseline folder '$BaselineFolder' not found - every current $AreaLabel will appear as added"
    }

    $baselineById = @{}
    foreach ($file in $baselineFiles) {
        $baselineObject = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        if ($baselineObject.id) {
            $baselineById[$baselineObject.id] = $baselineObject
        }
    }

    $currentById = @{}
    foreach ($policy in $CurrentPolicies) {
        $currentById[$policy.id] = $policy
    }

    # Added and modified
    foreach ($policy in $CurrentPolicies) {
        $policyName = $policy.$NameProperty
        if (-not $baselineById.ContainsKey($policy.id)) {
            $rows.Add([PSCustomObject]@{
                    Area         = $AreaLabel
                    Name         = $policyName
                    ObjectId     = $policy.id
                    ChangeType   = "Added"
                    LastModified = $policy.lastModifiedDateTime
                })
            continue
        }

        $baselineJson = ConvertTo-NormalizedJson -InputObject $baselineById[$policy.id]
        $currentJson = ConvertTo-NormalizedJson -InputObject $policy
        if ($baselineJson -ne $currentJson) {
            $rows.Add([PSCustomObject]@{
                    Area         = $AreaLabel
                    Name         = $policyName
                    ObjectId     = $policy.id
                    ChangeType   = "Modified"
                    LastModified = $policy.lastModifiedDateTime
                })
        }
    }

    # Deleted
    foreach ($baselineId in $baselineById.Keys) {
        if (-not $currentById.ContainsKey($baselineId)) {
            $baselineObject = $baselineById[$baselineId]
            $rows.Add([PSCustomObject]@{
                    Area         = $AreaLabel
                    Name         = $baselineObject.$NameProperty
                    ObjectId     = $baselineId
                    ChangeType   = "Deleted"
                    LastModified = ""
                })
        }
    }

    return $rows
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================
# Flow: log init -> banner -> fetch tenant state -> compare baseline -> report.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Policy drift report started" -Level 'INFO'

    if (-not (Test-Path $BaselinePath)) {
        throw "Baseline path '$BaselinePath' does not exist"
    }

    $manifestPath = Join-Path $BaselinePath "manifest.json"
    if (Test-Path $manifestPath) {
        $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
        Write-Output "Baseline taken: $($manifest.backupDate)"
    }
    else {
        Write-Warning "No manifest.json found - is '$BaselinePath' a backup created by backup-intune-configuration.ps1?"
    }

    Write-Output "Fetching current tenant state..."

    # Settings catalog policies need their setting bodies for a meaningful comparison
    $settingsCatalogPolicies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"
    foreach ($policy in $settingsCatalogPolicies) {
        $settings = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)/settings"
        $policy | Add-Member -MemberType NoteProperty -Name "settings" -Value @($settings) -Force
    }
    Write-Output "✓ Loaded $(@($settingsCatalogPolicies).Count) settings catalog policies"

    $deviceConfigurations = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"
    Write-Output "✓ Loaded $(@($deviceConfigurations).Count) device configuration profiles"

    $compliancePolicies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies?`$expand=scheduledActionsForRule(`$expand=scheduledActionConfigurations)"
    Write-Output "✓ Loaded $(@($compliancePolicies).Count) compliance policies"

    # ----- Compare against baseline -----
    Write-Output "Comparing against baseline..."

    [System.Collections.Generic.List[Object]]$drift = @()
    $drift.AddRange((Compare-PolicyArea -AreaLabel "Settings Catalog" -BaselineFolder "SettingsCatalog" -CurrentPolicies @($settingsCatalogPolicies) -NameProperty "name"))
    $drift.AddRange((Compare-PolicyArea -AreaLabel "Configuration Profile" -BaselineFolder "DeviceConfigurations" -CurrentPolicies @($deviceConfigurations) -NameProperty "displayName"))
    $drift.AddRange((Compare-PolicyArea -AreaLabel "Compliance Policy" -BaselineFolder "CompliancePolicies" -CurrentPolicies @($compliancePolicies) -NameProperty "displayName"))

    # ----- Display results -----
    Write-Output "`nPOLICY DRIFT REPORT"
    Write-Output ("=" * 50)
    Write-Output "Baseline: $BaselinePath"
    Write-Output "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    if ($drift.Count -eq 0) {
        Write-Output "`nNo drift detected - the tenant matches the baseline."
    }
    else {
        foreach ($changeGroup in ($drift | Group-Object -Property ChangeType | Sort-Object Name)) {
            Write-Output "`n$($changeGroup.Name) ($($changeGroup.Count))"
            foreach ($row in ($changeGroup.Group | Sort-Object Area, Name)) {
                $detail = "  [$($row.Area)] $($row.Name)"
                if ($row.LastModified -and $row.ChangeType -eq "Modified") {
                    $detail += " (modified: $($row.LastModified))"
                }
                Write-Output $detail
            }
        }
    }

    # Summary
    $addedCount = @($drift | Where-Object { $_.ChangeType -eq "Added" }).Count
    $modifiedCount = @($drift | Where-Object { $_.ChangeType -eq "Modified" }).Count
    $deletedCount = @($drift | Where-Object { $_.ChangeType -eq "Deleted" }).Count

    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $addedCount added, $modifiedCount modified, $deletedCount deleted"
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Intune_Policy_Drift_$timestamp.csv"
        $drift | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Output "✓ CSV report saved: $csvPath"
    }

    Write-Log -Message "Policy drift report completed: $addedCount added, $modifiedCount modified, $deletedCount deleted" -Level 'SUCCESS'
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
