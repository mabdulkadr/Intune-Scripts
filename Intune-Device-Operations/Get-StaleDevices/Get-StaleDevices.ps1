<#
.TITLE
    Get Stale Intune Devices

.SYNOPSIS
    Identifies and reports on devices that haven't checked in to Intune within a specified timeframe

.DESCRIPTION
    This script connects to Microsoft Graph and retrieves all managed devices from Intune,
    then identifies devices that are considered "stale" based on their last check-in date.
    The script supports all device platforms (Windows, iOS, Android, macOS) and provides
    comprehensive reporting with options to export results to CSV format.

    Stale devices may indicate hardware that is no longer in use, devices that have been
    reimaged without proper cleanup, or devices experiencing connectivity issues.

    Workstation authentication modes:
    - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available).
    - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication.
    Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.
.TAGS
    Operational,Devices

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.3.1

.CHANGELOG
    1.3.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.3 - Added workstation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.2 - workstation now records script progress, outcomes, and summaries in job history
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing)
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-stale-devices.ps1 -DaysStale 30
    Gets all devices that haven't checked in for 30 days or more

.EXAMPLE
    .\get-stale-devices.ps1 -DaysStale 60 -Platform "Windows" -ExportPath "C:\Reports\stale-windows-devices.csv"
    Gets Windows devices that haven't checked in for 60 days and exports to CSV

.EXAMPLE
    .\get-stale-devices.ps1 -DaysStale 90 -IncludeNeverCheckedIn "true" -ShowProgressBar "true"
    Gets devices stale for 90+ days, includes devices that never checked in, with progress display

.EXAMPLE
    .\get-stale-devices.ps1 -DaysStale 30 -ForceModuleInstall "true"
    Gets stale devices and forces module installation without prompting

.NOTES
    - Requires only Microsoft.Graph.Authentication module
    - Uses Connect-MgGraph and Invoke-MgGraphRequest for all Graph operations
    - Large environments may take several minutes to process
    - Consider running during off-hours for large tenant scans
    - Devices that have never checked in will show 'Never' as last check-in time
    - Corporate-owned devices vs personal devices are distinguished in the output
    - Disclaimer: This script is provided AS IS without warranty of any kind. Use it at your own risk.
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Number of days since last check-in to consider a device stale")]
    [ValidateRange(1, 1000)]
    [int]$DaysStale,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by specific platform (Windows, iOS, Android, macOS)")]
    [ValidateSet("Windows", "iOS", "Android", "macOS", "All")]
    [string]$Platform = "All",

    [Parameter(Mandatory = $false, HelpMessage = "Include devices that have never checked in")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeNeverCheckedIn,

    [Parameter(Mandatory = $false, HelpMessage = "Export results to CSV file path")]
    [string]$ExportPath,

    [Parameter(Mandatory = $false, HelpMessage = "Show progress bar during processing")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ShowProgressBar,

    [Parameter(Mandatory = $false, HelpMessage = "Include additional device details in output")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeDetails,

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

$SolutionName = 'Get-StaleDevices'
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

# Normalize the local module-install override for workstation parameter binding.
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

# workstation supplies portal parameter values as strings. Normalize the
# public boolean parameters once so local and runbook execution use real booleans.
foreach ($runbookBooleanParameter in @('IncludeNeverCheckedIn', 'ShowProgressBar', 'IncludeDetails')) {
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
    <#
    .SYNOPSIS
    Ensures required modules are available and loaded
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ModuleNames,

        [Parameter(Mandatory = $false)]
        [bool]$ForceInstall = $false
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-Verbose "Checking module: $ModuleName"

        $module = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

        if (-not $module) {
            Write-Information "Module '$ModuleName' not found. Attempting to install..." -InformationAction Continue

            if (-not $ForceInstall) {
                $response = Read-Host "Install module '$ModuleName'? (Y/N)"
                if ($response -notmatch '^[Yy]') {
                    throw "Module '$ModuleName' is required but installation was declined."
                }
            }

            try {
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }

                Write-Information "Installing '$ModuleName' in scope '$scope'..." -InformationAction Continue
                Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                Write-Information "Successfully installed '$ModuleName'" -InformationAction Continue
            }
            catch {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }

        try {
            Write-Verbose "Importing module: $ModuleName"
            Import-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Verbose "Successfully imported '$ModuleName'"
        }
        catch {
            throw "Failed to import module '$ModuleName': $($_.Exception.Message)"
        }
    }
}

# Workstation execution (no runbook detection)

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
            "DeviceManagementManagedDevices.Read.All"
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

# Function to get all pages of results from Graph API
function Get-MgGraphAllPages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [int]$DelayMs = 100
    )

    $AllResults = @()
    $NextLink = $Uri
    $RequestCount = 0

    do {
        try {
            # Add delay to respect rate limits
            if ($RequestCount -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }

            $Response = Invoke-MgGraphRequest -Uri $NextLink -Method GET
            $RequestCount++

            if ($null -ne $Response.value) {
                $AllResults += $Response.value
            }
            else {
                $AllResults += $Response
            }

            $NextLink = $Response.'@odata.nextLink'
        }
        catch {
            if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*throttled*") {
                Write-Information "`nRate limit hit, waiting 60 seconds..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data from $NextLink : $($_.Exception.Message)"
        }
    } while ($NextLink)

    return $AllResults
}

# Function to determine if a device is stale
function Test-DeviceStale {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Device,
        [Parameter(Mandatory = $true)]
        [int]$DaysStale,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeNeverCheckedIn
    )

    $LastCheckIn = $Device.lastSyncDateTime
    $IsStale = $false

    if ([string]::IsNullOrEmpty($LastCheckIn) -or $LastCheckIn -eq "0001-01-01T00:00:00Z") {
        # Device has never checked in
        $IsStale = $IncludeNeverCheckedIn
    }
    else {
        $LastCheckInDate = [DateTime]::Parse($LastCheckIn)
        $DaysSinceLastCheckIn = (Get-Date) - $LastCheckInDate
        $IsStale = $DaysSinceLastCheckIn.Days -ge $DaysStale
    }

    return $IsStale
}

# Function to format device information
function Format-DeviceInfo {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Device,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeDetails
    )

    $LastCheckIn = $Device.lastSyncDateTime
    $FormattedLastCheckIn = if ([string]::IsNullOrEmpty($LastCheckIn) -or $LastCheckIn -eq "0001-01-01T00:00:00Z") {
        "Never"
    }
    else {
        ([DateTime]::Parse($LastCheckIn)).ToString("yyyy-MM-dd HH:mm:ss")
    }

    $DaysSinceCheckIn = if ($FormattedLastCheckIn -eq "Never") {
        "N/A"
    }
    else {
        [math]::Floor(((Get-Date) - [DateTime]::Parse($LastCheckIn)).TotalDays)
    }

    $DeviceInfo = [PSCustomObject]@{
        DeviceName       = $Device.deviceName
        Platform         = $Device.operatingSystem
        OSVersion        = $Device.osVersion
        LastCheckIn      = $FormattedLastCheckIn
        DaysSinceCheckIn = $DaysSinceCheckIn
        DeviceId         = $Device.id
        SerialNumber     = $Device.serialNumber
        Model            = $Device.model
        Manufacturer     = $Device.manufacturer
        EnrollmentType   = $Device.deviceEnrollmentType
        Ownership        = $Device.managedDeviceOwnerType
        ComplianceState  = $Device.complianceState
        ManagementState  = $Device.managementState
    }

    if (-not $IncludeDetails) {
        $DeviceInfo = $DeviceInfo | Select-Object DeviceName, Platform, OSVersion, LastCheckIn, DaysSinceCheckIn, Ownership, ComplianceState
    }

    return $DeviceInfo
}

# Function to get platform-specific OData filter
function Get-PlatformFilter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Platform
    )

    switch ($Platform) {
        "Windows" { return "operatingSystem eq 'Windows'" }
        "iOS" { return "operatingSystem eq 'iOS'" }
        "Android" { return "operatingSystem eq 'Android'" }
        "macOS" { return "operatingSystem eq 'macOS'" }
        "All" { return $null }
        default { return $null }
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode 'run' -Type 'General'
    Write-Banner
    Write-Output "Starting stale device detection..."
    Write-Output "Configuration:"
    Write-Output "  - Days considered stale: $DaysStale"
    Write-Output "  - Platform filter: $Platform"
    Write-Output "  - Include never checked in: $($IncludeNeverCheckedIn)"

    # Build the API URI with optional platform filter
    $BaseUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices"
    $PlatformFilter = Get-PlatformFilter -Platform $Platform

    if ($PlatformFilter) {
        $Uri = "$BaseUri?`$filter=$PlatformFilter"
        Write-Output "  - Applying platform filter: $PlatformFilter"
    }
    else {
        $Uri = $BaseUri
    }

    # Retrieve all managed devices
    Write-Output "Retrieving managed devices from Intune..."
    $AllDevices = Get-MgGraphAllPages -Uri $Uri
    Write-Output "✓ Retrieved $($AllDevices.Count) devices"

    # Process devices to find stale ones
    Write-Output "Analyzing devices for staleness..."
    $StaleDevices = @()
    $ProcessedCount = 0

    foreach ($Device in $AllDevices) {
        $ProcessedCount++

        if ($ShowProgressBar) {
            $PercentComplete = [math]::Round(($ProcessedCount / $AllDevices.Count) * 100)
            Write-Progress -Activity "Analyzing devices" -Status "Processing device $ProcessedCount of $($AllDevices.Count)" -PercentComplete $PercentComplete
        }

        if (Test-DeviceStale -Device $Device -DaysStale $DaysStale -IncludeNeverCheckedIn:$IncludeNeverCheckedIn) {
            $FormattedDevice = Format-DeviceInfo -Device $Device -IncludeDetails:$IncludeDetails
            $StaleDevices += $FormattedDevice
        }
    }

    if ($ShowProgressBar) {
        Write-Progress -Activity "Analyzing devices" -Completed
    }

    # Display results
    Write-Output "✓ Analysis completed"
    Write-Output ""
    Write-Output "========================================"
    Write-Output "STALE DEVICE REPORT"
    Write-Output "========================================"
    Write-Output "Total devices analyzed: $($AllDevices.Count)"
    Write-Output "Stale devices found: $($StaleDevices.Count)"
    Write-Output "Staleness threshold: $DaysStale days"
    Write-Output "Platform filter: $Platform"
    Write-Output "========================================"
    Write-Output ""

    if ($StaleDevices.Count -gt 0) {
        # Group by platform for summary
        $PlatformSummary = $StaleDevices | Group-Object Platform | Sort-Object Name
        Write-Output "Stale devices by platform:"
        foreach ($Group in $PlatformSummary) {
            Write-Output "  - $($Group.Name): $($Group.Count) devices"
        }
        Write-Output ""

        # Display the stale devices
        $StaleDevices | Sort-Object Platform, DeviceName | Format-Table -AutoSize

        # Export to CSV if path specified
        if ($ExportPath) {
            try {
                $StaleDevices | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding utf8
                Write-Output "✓ Results exported to: $ExportPath"
            }
            catch {
                Write-Warning "Failed to export to CSV: $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Output "No stale devices found matching the specified criteria."
    }

    Write-Output "✓ Script completed successfully"
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from Microsoft Graph
    try {
        Disconnect-MgGraph | Out-Null
        Write-Output "✓ Disconnected from Microsoft Graph"
    }
    catch {
        # Ignore disconnection errors - this is expected behavior when already disconnected
        Write-Verbose "Graph disconnection completed (may have already been disconnected)"
    }
}

# ============================================================================
# SCRIPT SUMMARY
# ============================================================================

Write-Output "
========================================
Script Execution Summary
========================================
Script: Get Stale Intune Devices
Parameters: DaysStale=$DaysStale, Platform=$Platform
Devices Analyzed: $($AllDevices.Count)
Stale Devices Found: $($StaleDevices.Count)
Status: Completed
========================================
"
