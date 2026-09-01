<#
.TITLE
    Get Windows Update Compliance Report

.SYNOPSIS
    Reports Windows Update deployment state: update rings with per-device status, feature update profiles, quality and driver update profiles.

.DESCRIPTION
    This script inventories the tenant's Windows Update configuration and its
    deployment health: update rings (Windows Update for Business configurations)
    with per-device success and error status, feature update profiles with their
    target version and end-of-support date, expedited quality update profiles, and
    driver update profiles. It flags rings with device errors, feature update
    targets approaching end of support, and profiles without assignments.

    Supports interactive sign-in and unattended app-only via -TenantId/-ClientId.

.TAGS
    Monitoring,Reporting

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
    .\get-windows-update-compliance-report.ps1
    Reports update rings, feature updates, quality and driver update profiles

.EXAMPLE
    .\get-windows-update-compliance-report.ps1 -EndOfSupportWarningDays 120 -ExportToCsv "true"
    Flags feature update targets within 120 days of end of support and exports to CSV

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Update rings are deviceConfigurations of type windowsUpdateForBusinessConfiguration; per-device status comes from each ring's deviceStatuses
    - This reports deployment state from Intune's perspective; per-device patch level detail lives in Windows Update for Business reports (Log Analytics)
    - Uses beta Graph endpoints because feature/quality/driver update profiles are not exposed on v1.0
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Days before feature update end-of-support to raise a warning")]
    [ValidateRange(1, 730)]
    [int]$EndOfSupportWarningDays = 180,

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

# Normalize the module-install override parameter.
$forceModuleInstallRaw = [string]$ForceModuleInstall
Remove-Variable -Name ForceModuleInstall -ErrorAction SilentlyContinue
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

# Normalize boolean string parameters so
# workstation execution uses consistent boolean types.
foreach ($boolParamName in @('ExportToCsv')) {
    $boolRaw = [string](Get-Variable -Name $boolParamName -ValueOnly)
    Remove-Variable -Name $boolParamName -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($boolRaw)) {
        Set-Variable -Name $boolParamName -Value $false
        continue
    }

    switch ($boolRaw.Trim().ToLowerInvariant()) {
        { $_ -in @("true", "1", '$true') } {
            Set-Variable -Name $boolParamName -Value $true
        }
        { $_ -in @("false", "0", '$false') } {
            Set-Variable -Name $boolParamName -Value $false
        }
        default {
            throw "Parameter '$boolParamName' accepts only true, false, 1, 0, $true, or $false."
        }
    }
}

# ============================================================================
# CONFIGURATION - solution identity used by the logging helpers.
# ============================================================================

$SolutionName = 'get-windows-update-compliance-report'
$ScriptMode   = 'run'

# Anchor the default export location beside this script (Enterprise Law 12):
# dot-sourcing can leave $PSScriptRoot empty, so fall back through PSCommandPath,
# MyInvocation, and finally the current directory.
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

if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
    $OutputPath = Join-Path $scriptBase 'Reports'
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
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }
                Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                Write-Information "[OK] Successfully installed '$ModuleName'" -InformationAction Continue
            }
            catch {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }
        try {
            Import-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Verbose "[OK] Successfully imported '$ModuleName'"
        }
        catch {
            throw "Failed to import module '$ModuleName': $($_.Exception.Message)"
        }
    }
}

# ============================================================================
# ENVIRONMENT AND MODULES - Workstation only
# ============================================================================

$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "MgGraphCommunity"
)

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "[OK] All required modules are available"
}
catch {
    Write-Error "Module initialization failed: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# AUTHENTICATION - Workstation (interactive) and unattended app-only
# ============================================================================

try {
    if ($TenantId -and $ClientId -and $ClientSecret) {
        Write-Output "Connecting to Microsoft Graph with client secret..."
        $secureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $secureSecret -NoWelcome -ErrorAction Stop
        Write-Output "[OK] Successfully connected to Microsoft Graph"
    }
    elseif ($TenantId -and $ClientId -and $CertificateThumbprint) {
        Write-Output "Connecting to Microsoft Graph with certificate..."
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        Write-Output "[OK] Successfully connected to Microsoft Graph"
    }
    else {
        Write-Output "Connecting to Microsoft Graph with interactive authentication..."
        $Scopes = @(
            "DeviceManagementConfiguration.Read.All"
        )
        if (Get-Command -Name Connect-MgGraphCommunity -ErrorAction SilentlyContinue) {
            Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        else {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        Write-Output "[OK] Successfully connected to Microsoft Graph"
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

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Windows Update compliance report started" -Level 'INFO'

    [System.Collections.Generic.List[Object]]$report = @()

    # ----- Update rings -----
    Write-Output "Retrieving update rings..."
    $allConfigurations = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$expand=assignments"
    $updateRings = @($allConfigurations | Where-Object { $_.'@odata.type' -like "*windowsUpdateForBusinessConfiguration" })
    Write-Output "✓ Found $($updateRings.Count) update rings"

    foreach ($ring in $updateRings) {
        # Per-device deployment status for the ring
        $deviceStatuses = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($ring.id)/deviceStatuses"
        $statusGroups = @($deviceStatuses) | Group-Object -Property status

        $successCount = 0
        $errorCount = 0
        $otherCount = 0
        foreach ($group in $statusGroups) {
            switch ($group.Name) {
                { $_ -in @("compliant", "succeeded") } { $successCount += $group.Count }
                { $_ -in @("error", "conflict", "nonCompliant") } { $errorCount += $group.Count }
                default { $otherCount += $group.Count }
            }
        }

        $report.Add([PSCustomObject]@{
                Area          = "Update Ring"
                Name          = $ring.displayName
                Detail        = "Quality deferral: $($ring.qualityUpdatesDeferralPeriodInDays)d | Feature deferral: $($ring.featureUpdatesDeferralPeriodInDays)d"
                IsAssigned    = (@($ring.assignments).Count -gt 0)
                DeviceSuccess = $successCount
                DeviceErrors  = $errorCount
                DeviceOther   = $otherCount
                Flag          = if ($errorCount -gt 0) { "DeviceErrors" } elseif (@($ring.assignments).Count -eq 0) { "NotAssigned" } else { "" }
            })
    }

    # ----- Feature update profiles -----
    Write-Output "Retrieving feature update profiles..."
    $featureProfiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles?`$expand=assignments"
    Write-Output "✓ Found $(@($featureProfiles).Count) feature update profiles"

    foreach ($featureProfile in $featureProfiles) {
        $endOfSupport = if ($featureProfile.endOfSupportDate) { [DateTime]::Parse($featureProfile.endOfSupportDate.ToString()) } else { $null }
        $daysToEos = if ($endOfSupport) { [math]::Round(($endOfSupport - (Get-Date)).TotalDays, 0) } else { $null }

        $flag = ""
        if (@($featureProfile.assignments).Count -eq 0) { $flag = "NotAssigned" }
        elseif ($null -ne $daysToEos -and $daysToEos -lt 0) { $flag = "PastEndOfSupport" }
        elseif ($null -ne $daysToEos -and $daysToEos -le $EndOfSupportWarningDays) { $flag = "NearEndOfSupport" }

        $detail = "Target: $($featureProfile.featureUpdateVersion)"
        if ($null -ne $daysToEos) { $detail += " | end of support in $daysToEos days" }

        $report.Add([PSCustomObject]@{
                Area          = "Feature Update"
                Name          = $featureProfile.displayName
                Detail        = $detail
                IsAssigned    = (@($featureProfile.assignments).Count -gt 0)
                DeviceSuccess = ""
                DeviceErrors  = ""
                DeviceOther   = ""
                Flag          = $flag
            })
    }

    # ----- Quality update profiles (expedite) -----
    Write-Output "Retrieving quality update profiles..."
    $qualityProfiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles?`$expand=assignments"
    Write-Output "✓ Found $(@($qualityProfiles).Count) quality update profiles"

    foreach ($qualityProfile in $qualityProfiles) {
        $report.Add([PSCustomObject]@{
                Area          = "Quality Update (Expedite)"
                Name          = $qualityProfile.displayName
                Detail        = "Release: $($qualityProfile.expeditedUpdateSettings.qualityUpdateRelease)"
                IsAssigned    = (@($qualityProfile.assignments).Count -gt 0)
                DeviceSuccess = ""
                DeviceErrors  = ""
                DeviceOther   = ""
                Flag          = if (@($qualityProfile.assignments).Count -eq 0) { "NotAssigned" } else { "" }
            })
    }

    # ----- Driver update profiles -----
    Write-Output "Retrieving driver update profiles..."
    $driverProfiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles?`$expand=assignments"
    Write-Output "✓ Found $(@($driverProfiles).Count) driver update profiles"

    foreach ($driverProfile in $driverProfiles) {
        $report.Add([PSCustomObject]@{
                Area          = "Driver Update"
                Name          = $driverProfile.displayName
                Detail        = "Approval: $($driverProfile.approvalType) | new drivers pending: $($driverProfile.newUpdates)"
                IsAssigned    = (@($driverProfile.assignments).Count -gt 0)
                DeviceSuccess = ""
                DeviceErrors  = ""
                DeviceOther   = ""
                Flag          = if (@($driverProfile.assignments).Count -eq 0) { "NotAssigned" } elseif ([int]$driverProfile.newUpdates -gt 0) { "DriversPendingApproval" } else { "" }
            })
    }

    # ----- Display results -----
    Write-Output "`nWINDOWS UPDATE COMPLIANCE REPORT"
    Write-Output ("=" * 50)
    Write-Output "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    foreach ($areaGroup in ($report | Group-Object -Property Area)) {
        Write-Output "`n$($areaGroup.Name) ($($areaGroup.Count)):"
        foreach ($row in ($areaGroup.Group | Sort-Object Name)) {
            $assignedLabel = if ($row.IsAssigned) { "assigned" } else { "NOT ASSIGNED" }
            $line = "  $($row.Name) [$assignedLabel]"
            if ($row.Flag) { $line += " [$($row.Flag)]" }
            Write-Output $line
            Write-Output "    $($row.Detail)"
            if ($row.Area -eq "Update Ring") {
                Write-Output "    Devices: $($row.DeviceSuccess) ok, $($row.DeviceErrors) errors, $($row.DeviceOther) other"
            }
        }
    }

    if ($report.Count -eq 0) {
        Write-Output "`nNo Windows Update configuration found in this tenant."
    }

    # Summary
    $flaggedRows = @($report | Where-Object { $_.Flag })
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($report.Count) update deployment objects | $($flaggedRows.Count) flagged"
    foreach ($row in $flaggedRows) {
        Write-Output "  [$($row.Flag)] $($row.Area): $($row.Name)"
    }
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Windows_Update_Compliance_$timestamp.csv"
        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Output "✓ CSV report saved: $csvPath"
    }

    Write-Log -Message "Windows Update compliance report completed - $($report.Count) update deployment objects, $($flaggedRows.Count) flagged" -Level 'SUCCESS'
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
