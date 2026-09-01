<#
.TITLE
    Get Windows 11 Readiness Report

.SYNOPSIS
    Reports Windows 11 upgrade readiness for all Windows devices using Endpoint Analytics hardware signals.

.DESCRIPTION
    This script reads the Endpoint Analytics work-from-anywhere device data to report
    which Windows devices are eligible for Windows 11 and which hardware checks are
    blocking the rest: TPM, Secure Boot, RAM, storage, processor family, speed, core
    count, and 64-bit capability. It shows the tenant-level readiness summary plus a
    per-device breakdown of failed checks, so upgrade waves and hardware refresh
    budgets can be planned from real inventory data.

    Workstation authentication modes:
    - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available).
    - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication.
    Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.
.TAGS
    Devices,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All,DeviceManagementConfiguration.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.2.1

.CHANGELOG
    1.2.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.2 - Added workstation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.1 - workstation now records script progress, outcomes, and summaries in job history
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-windows11-readiness-report.ps1
    Shows the tenant readiness summary and all devices with failed upgrade checks

.EXAMPLE
    .\get-windows11-readiness-report.ps1 -ExportToCsv "true"
    Exports the full per-device readiness data to a timestamped CSV file

.EXAMPLE
    .\get-windows11-readiness-report.ps1 -OnlyBlocked "true"
    Lists only devices that are not eligible for the Windows 11 upgrade

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Endpoint Analytics must be enabled and collecting data; without it the report is empty
    - Devices need to report analytics data for up to 24 hours after enrollment before appearing
    - Uses beta Graph endpoints because the work-from-anywhere analytics surface is not exposed on v1.0
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Show only devices that are blocked from upgrading")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$OnlyBlocked,

    [Parameter(Mandatory = $false, HelpMessage = "Export results to CSV")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ExportToCsv,

    [Parameter(Mandatory = $false, HelpMessage = "Output path for exports")]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Tenant ID for app-only authentication")]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "Client ID for app-only authentication")]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication")]
    [string]$CertificateThumbprint
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and log placement.
# ============================================================================

$SolutionName = 'get-windows11-readiness-report'
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

# Resolves the script directory across direct runs and dot-sourcing (Law 12).
$scriptBase = if ($PSScriptRoot) {
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

# Anchors the default output directory beside the script (Law 12).
if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
    $OutputPath = $scriptBase
}

# Normalize the local module-install override for workstation parameter binding.
$forceModuleInstallRaw = [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Tenant ID for app-only authentication")]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "Client ID for app-only authentication")]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication")]
    [string]$CertificateThumbprint
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

# workstation supplies portal parameter values as strings. Normalize the
# public boolean parameters once so local and runbook execution use real booleans.
foreach ($runbookBooleanParameter in @('OnlyBlocked', 'ExportToCsv')) {
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
else {
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
        }

        Import-Module -Name $ModuleName -Force -ErrorAction Stop
    }
}

# Detect execution environment

# Initialize required modules
$RequiredModules = @("Microsoft.Graph.Authentication")
# MgGraphCommunity gives WAM-free interactive sign-in for local runs
$RequiredModules += "MgGraphCommunity"

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
    if ($TenantId -and $ClientId -and ($ClientSecret -or $CertificateThumbprint)) {
        Write-Output "Connecting to Microsoft Graph with app-only authentication..."
        if ($CertificateThumbprint) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        else {
            $ClientSecretSecure = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            $ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $ClientSecretSecure
            Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome -ErrorAction Stop
        }
        Write-Output "Successfully connected to Microsoft Graph with app-only authentication."
    }
    else {
        Write-Output "Connecting to Microsoft Graph with interactive authentication..."
        $Scopes = @(
            "DeviceManagementManagedDevices.Read.All",
            "DeviceManagementConfiguration.Read.All"
        )
        Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
        Write-Output "Successfully connected to Microsoft Graph."
    }
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

function Get-FailedCheck {
    param([object]$Device)

    # Each check property is TRUE when the check FAILED
    $checkMap = [ordered]@{
        osCheckFailed                 = "OS version"
        processor64BitCheckFailed     = "64-bit processor"
        processorFamilyCheckFailed    = "Processor family"
        processorCoreCountCheckFailed = "Processor core count"
        processorSpeedCheckFailed     = "Processor speed"
        ramCheckFailed                = "RAM"
        secureBootCheckFailed         = "Secure Boot"
        storageCheckFailed            = "Storage"
        tpmCheckFailed                = "TPM 2.0"
    }

    $failed = foreach ($check in $checkMap.Keys) {
        if ($Device.$check -eq $true) { $checkMap[$check] }
    }

    return @($failed)
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode 'run' -Type 'General'
    Write-Banner
    # Tenant-level readiness summary
    Write-Output "Retrieving tenant hardware readiness summary..."
    $readinessSummary = $null
    try {
        $readinessSummary = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsWorkFromAnywhereHardwareReadinessMetric" -Method GET
    }
    catch {
        Write-Warning "Could not read the hardware readiness summary: $($_.Exception.Message)"
    }

    # Per-device work-from-anywhere data
    Write-Output "Retrieving per-device readiness data..."
    $selectFields = "id,deviceName,serialNumber,manufacturer,model,ownership,managedBy,osDescription,osVersion,upgradeEligibility,osCheckFailed,processor64BitCheckFailed,processorFamilyCheckFailed,processorCoreCountCheckFailed,processorSpeedCheckFailed,ramCheckFailed,secureBootCheckFailed,storageCheckFailed,tpmCheckFailed"
    $devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsWorkFromAnywhereMetrics/allDevices/metricDevices?`$select=$selectFields"

    if (@($devices).Count -eq 0) {
        Write-Warning "No work-from-anywhere analytics data found. Endpoint Analytics may not be enabled, or devices have not reported yet."
        return
    }
    Write-Output "✓ Found analytics data for $(@($devices).Count) devices"

    [System.Collections.Generic.List[Object]]$report = @()
    foreach ($device in $devices) {
        $failedChecks = Get-FailedCheck -Device $device

        $report.Add([PSCustomObject]@{
                DeviceName         = $device.deviceName
                SerialNumber       = $device.serialNumber
                Manufacturer       = $device.manufacturer
                Model              = $device.model
                Ownership          = $device.ownership
                OsDescription      = $device.osDescription
                OsVersion          = $device.osVersion
                UpgradeEligibility = $device.upgradeEligibility
                FailedChecks       = ($failedChecks -join "; ")
                FailedCheckCount   = $failedChecks.Count
            })
    }

    if ($OnlyBlocked) {
        $report = [System.Collections.Generic.List[Object]]@($report | Where-Object { $_.UpgradeEligibility -notin @("capable", "upgraded") })
    }

    # ----- Display results -----
    Write-Output "`nWINDOWS 11 READINESS REPORT"
    Write-Output ("=" * 50)
    Write-Output "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    if ($readinessSummary) {
        Write-Output "`nTenant summary (Endpoint Analytics):"
        Write-Output "  Total devices:    $($readinessSummary.totalDeviceCount)"
        Write-Output "  Upgrade eligible: $($readinessSummary.upgradeEligibleDeviceCount)"
    }

    foreach ($eligibilityGroup in ($report | Group-Object -Property UpgradeEligibility | Sort-Object Name)) {
        $groupLabel = if ($eligibilityGroup.Name) { $eligibilityGroup.Name } else { "unknown" }
        Write-Output "`n[$groupLabel] $($eligibilityGroup.Count) device(s)"

        foreach ($row in ($eligibilityGroup.Group | Sort-Object FailedCheckCount -Descending)) {
            $line = "  $($row.DeviceName) | $($row.Manufacturer) $($row.Model) | $($row.OsVersion)"
            if ($row.FailedChecks) {
                $line += " | blocked by: $($row.FailedChecks)"
            }
            Write-Output $line
        }
    }

    # Summary of the most common blockers
    $blockedDevices = @($report | Where-Object { $_.FailedCheckCount -gt 0 })
    if ($blockedDevices.Count -gt 0) {
        Write-Output "`nMost common blocking checks:"
        $allFailures = $blockedDevices | ForEach-Object { $_.FailedChecks -split "; " }
        foreach ($failureGroup in ($allFailures | Group-Object | Sort-Object Count -Descending)) {
            Write-Output "  $($failureGroup.Name): $($failureGroup.Count) devices"
        }
    }

    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($report.Count) devices reported, $($blockedDevices.Count) with failed hardware checks"
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Windows11_Readiness_$timestamp.csv"
        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
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
