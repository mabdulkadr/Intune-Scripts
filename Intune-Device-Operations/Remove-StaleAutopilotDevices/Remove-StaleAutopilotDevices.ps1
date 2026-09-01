<#
.TITLE
    Cleanup Orphaned Autopilot Devices

.SYNOPSIS
    Remove devices from Autopilot that are no longer managed in Intune

.DESCRIPTION
    This script connects to Microsoft Graph and identifies Windows Autopilot devices that are
    registered in the Autopilot service but are no longer present as managed devices in Intune.
    These orphaned devices can accumulate over time when devices are retired, reimaged, or
    replaced without proper cleanup of the Autopilot registration.

    The script provides options to preview orphaned devices before removal and supports
    batch operations with confirmation prompts for safety. It helps maintain a clean
    Autopilot device inventory and prevents potential enrollment issues.

    Workstation authentication modes:
    - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available).
    - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication.
    Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.
.TAGS
    Operational,Devices

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementServiceConfig.ReadWrite.All,DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.4.1

.CHANGELOG
    1.4.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.4 - Added workstation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.3 - workstation now records script progress, outcomes, and summaries in job history
    1.2 - Treat 0001-01-01 last contact as Never, require -Force for removals in workstation, suppress progress bars in runbooks, and limit Graph list calls with projected columns
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing)
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\cleanup-autopilot-devices.ps1 -PreviewOnly "true"
    Shows orphaned Autopilot devices without removing them

.EXAMPLE
    .\cleanup-autopilot-devices.ps1 -RemoveOrphaned "true" -ExportPath "C:\Reports\removed-autopilot-devices.csv"
    Removes orphaned devices and exports the list to CSV

.EXAMPLE
    .\cleanup-autopilot-devices.ps1 -RemoveOrphaned "true" -Force "true" -ShowProgressBar "true"
    Removes orphaned devices without confirmation prompts, with progress display

.EXAMPLE
    .\cleanup-autopilot-devices.ps1 -PreviewOnly "true" -ForceModuleInstall "true"
    Shows orphaned devices and forces module installation without prompting

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Uses Connect-MgGraph and Invoke-MgGraphRequest for all Graph operations
    - Only processes Windows Autopilot devices
    - Comparison is based on device serial numbers
    - Use -PreviewOnly first to review devices before removal
    - Large environments may take several minutes to process
    - Consider running during maintenance windows
    - Disclaimer: This script is provided AS IS without warranty of any kind. Use it at your own risk.
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Only preview orphaned devices without removing them")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$PreviewOnly,

    [Parameter(Mandatory = $false, HelpMessage = "Remove orphaned Autopilot devices")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$RemoveOrphaned,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts when removing devices")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$Force,

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

$SolutionName = 'cleanup-autopilot-devices'
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
foreach ($runbookBooleanParameter in @('PreviewOnly', 'RemoveOrphaned', 'Force', 'ShowProgressBar', 'IncludeDetails')) {
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
    Write-Verbose "All required modules are available"
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
            "DeviceManagementServiceConfig.ReadWrite.All",
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
                Write-Log -Message "Rate limit hit, waiting 60 seconds..." -Level 'WARNING'
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data from $NextLink : $($_.Exception.Message)"
        }
    } while ($NextLink)

    return $AllResults
}

# Function to get all Autopilot devices
function Get-AutopilotDevice {
    try {
        Write-Log -Message "Retrieving Autopilot devices..." -Level 'INFO'
        $Uri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
        $AutopilotDevices = Get-MgGraphAllPages -Uri $Uri
        Write-Log -Message "Retrieved $($AutopilotDevices.Count) Autopilot devices" -Level 'SUCCESS'
        return $AutopilotDevices
    }
    catch {
        throw "Failed to retrieve Autopilot devices: $($_.Exception.Message)"
    }
}

# Function to get all Intune managed devices
function Get-IntuneDevice {
    try {
        Write-Log -Message "Retrieving Intune managed devices..." -Level 'INFO'
        $Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,serialNumber"
        $IntuneDevices = Get-MgGraphAllPages -Uri $Uri
        Write-Log -Message "Retrieved $($IntuneDevices.Count) Windows managed devices" -Level 'SUCCESS'
        return $IntuneDevices
    }
    catch {
        throw "Failed to retrieve Intune managed devices: $($_.Exception.Message)"
    }
}

# Function to find orphaned Autopilot devices
function Find-OrphanedAutopilotDevice {
    param(
        [Parameter(Mandatory = $true)]
        [array]$AutopilotDevices,
        [Parameter(Mandatory = $true)]
        [array]$IntuneDevices
    )

    Write-Log -Message "Analyzing devices to find orphaned Autopilot registrations..." -Level 'INFO'

    # Create hashtable of Intune device serial numbers for fast lookup
    $IntuneSerialNumbers = @{}
    foreach ($Device in $IntuneDevices) {
        if (-not [string]::IsNullOrEmpty($Device.serialNumber)) {
            $IntuneSerialNumbers[$Device.serialNumber.ToUpper()] = $true
        }
    }

    $OrphanedDevices = @()
    $ProcessedCount = 0

    foreach ($AutopilotDevice in $AutopilotDevices) {
        $ProcessedCount++

        if ($ShowProgressBar) {
            $PercentComplete = [math]::Round(($ProcessedCount / $AutopilotDevices.Count) * 100)
            Write-Progress -Activity "Analyzing Autopilot devices" -Status "Processing device $ProcessedCount of $($AutopilotDevices.Count)" -PercentComplete $PercentComplete
        }

        # Check if Autopilot device serial number exists in Intune
        $SerialNumber = $AutopilotDevice.serialNumber
        if (-not [string]::IsNullOrEmpty($SerialNumber) -and -not $IntuneSerialNumbers.ContainsKey($SerialNumber.ToUpper())) {
            $OrphanedDevices += $AutopilotDevice
        }
    }

    if ($ShowProgressBar) {
        Write-Progress -Activity "Analyzing Autopilot devices" -Completed
    }

    Write-Log -Message "Found $($OrphanedDevices.Count) orphaned Autopilot devices" -Level 'SUCCESS'
    return $OrphanedDevices
}

# Function to format Autopilot device information
function Format-AutopilotDeviceInfo {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Device,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeDetails
    )

    $DeviceInfo = [PSCustomObject]@{
        SerialNumber          = $Device.serialNumber
        Model                 = $Device.model
        Manufacturer          = $Device.manufacturer
        ProductKey            = $Device.productKey
        GroupTag              = $Device.groupTag
        PurchaseOrderId       = $Device.purchaseOrderIdentifier
        EnrollmentState       = $Device.enrollmentState
        LastContactedDateTime = if ($Device.lastContactedDateTime -and $Device.lastContactedDateTime -ne "0001-01-01T00:00:00Z") {
            ([DateTime]::Parse($Device.lastContactedDateTime)).ToString("yyyy-MM-dd HH:mm:ss")
        }
        else {
            "Never"
        }
        Id                    = $Device.id
    }

    if (-not $IncludeDetails) {
        $DeviceInfo = $DeviceInfo | Select-Object SerialNumber, Model, Manufacturer, GroupTag, EnrollmentState, LastContactedDateTime
    }

    return $DeviceInfo
}

# Function to remove Autopilot device
function Remove-AutopilotDevice {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,
        [Parameter(Mandatory = $false)]
        [string]$SerialNumber
    )

    # Create a meaningful identifier for logging
    $DeviceIdentifier = if (-not [string]::IsNullOrWhiteSpace($SerialNumber)) {
        "Serial: $SerialNumber"
    }
    else {
        "ID: $DeviceId"
    }

    if ($PSCmdlet.ShouldProcess($DeviceIdentifier, "Remove Autopilot Device")) {
        try {
            $Uri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$DeviceId"
            Invoke-MgGraphRequest -Uri $Uri -Method DELETE
            Write-Log -Message "Removed Autopilot device: $DeviceIdentifier" -Level 'SUCCESS'
            return $true
        }
        catch {
            Write-Log -Message "Failed to remove Autopilot device '$DeviceIdentifier': $($_.Exception.Message)" -Level 'WARNING'
            return $false
        }
    }
    else {
        Write-Log -Message "Skipped removal of Autopilot device: $DeviceIdentifier" -Level 'INFO'
        return $false
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode 'run' -Type 'General'
    Write-Banner

    # Validate parameters
    if (-not $PreviewOnly -and -not $RemoveOrphaned) {
        Write-Log -Message "No action specified. Use -PreviewOnly to preview orphaned devices or -RemoveOrphaned to remove them." -Level 'WARNING'
        Write-Output "Use 'Get-Help .\cleanup-autopilot-devices.ps1 -Examples' for usage examples."
        exit 0
    }

    if ($RemoveOrphaned -and $PreviewOnly) {
        Write-Log -Message "Cannot use both -PreviewOnly and -RemoveOrphaned switches. Choose one action." -Level 'WARNING'
        exit 1
    }

    Write-Output "Starting Autopilot device cleanup..."
    Write-Output "Configuration:"
    Write-Output "  - Mode: $(if ($PreviewOnly) { 'Preview Only' } else { 'Remove Orphaned Devices' })"
    Write-Output "  - Force removal: $($Force)"
    Write-Output "  - Include details: $($IncludeDetails)"

    # Get all Autopilot devices
    $AutopilotDevices = Get-AutopilotDevice
    if ($AutopilotDevices.Count -eq 0) {
        Write-Output "No Autopilot devices found. Exiting."
        exit 0
    }

    # Get all Intune managed devices
    $IntuneDevices = Get-IntuneDevice

    # Find orphaned Autopilot devices
    $OrphanedDevices = Find-OrphanedAutopilotDevice -AutopilotDevices $AutopilotDevices -IntuneDevices $IntuneDevices

    # Display results
    Write-Output ""
    Write-Output "========================================"
    Write-Output "AUTOPILOT CLEANUP REPORT"
    Write-Output "========================================"
    Write-Output "Total Autopilot devices: $($AutopilotDevices.Count)"
    Write-Output "Total Intune Windows devices: $($IntuneDevices.Count)"
    Write-Output "Orphaned Autopilot devices: $($OrphanedDevices.Count)"
    Write-Output "========================================"
    Write-Output ""

    if ($OrphanedDevices.Count -gt 0) {
        # Format device information for display
        $FormattedDevices = @()
        foreach ($Device in $OrphanedDevices) {
            $FormattedDevices += Format-AutopilotDeviceInfo -Device $Device -IncludeDetails:$IncludeDetails
        }

        # Display orphaned devices
        Write-Output "Orphaned Autopilot devices found:"
        $FormattedDevices | Sort-Object SerialNumber | Format-Table -AutoSize

        # Export to CSV if path specified
        if ($ExportPath) {
            try {
                $FormattedDevices | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding utf8
                Write-Output "Results exported to: $ExportPath"
            }
            catch {
                Write-Log -Message "Failed to export to CSV: $($_.Exception.Message)" -Level 'WARNING'
            }
        }

        # Remove orphaned devices if requested
        if ($RemoveOrphaned) {
            Write-Output ""

            if (-not $Force) {
                $Confirmation = Read-Host "Do you want to remove $($OrphanedDevices.Count) orphaned Autopilot devices? (y/N)"
                if ($Confirmation -notmatch '^[Yy]') {
                    Write-Output "Operation cancelled by user."
                    exit 0
                }
            }

            Write-Output "Removing orphaned Autopilot devices..."
            $RemovedCount = 0
            $FailedCount = 0
            $ProcessedCount = 0

            foreach ($Device in $OrphanedDevices) {
                $ProcessedCount++

                if ($ShowProgressBar) {
                    $PercentComplete = [math]::Round(($ProcessedCount / $OrphanedDevices.Count) * 100)
                    Write-Progress -Activity "Removing Autopilot devices" -Status "Processing device $ProcessedCount of $($OrphanedDevices.Count)" -PercentComplete $PercentComplete
                }

                $Success = Remove-AutopilotDevice -DeviceId $Device.id -SerialNumber $Device.serialNumber
                if ($Success) {
                    $RemovedCount++
                }
                else {
                    $FailedCount++
                }

                # Add small delay to avoid rate limiting
                Start-Sleep -Milliseconds 200
            }

            if ($ShowProgressBar) {
                Write-Progress -Activity "Removing Autopilot devices" -Completed
            }

            Write-Output ""
            Write-Output "Removal completed"
            Write-Output "  - Successfully removed: $RemovedCount devices"
            Write-Output "  - Failed to remove: $FailedCount devices"
        }
    }
    else {
        Write-Output "No orphaned Autopilot devices found. All Autopilot devices have corresponding Intune managed devices."
    }

    Write-Output "Script completed successfully"
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from Microsoft Graph
    try {
        Disconnect-MgGraph | Out-Null
        Write-Output "Disconnected from Microsoft Graph"
    }
    catch {
        # Ignore disconnection errors - this is expected behavior when already disconnected
        Write-Verbose "Graph disconnection completed (may have already been disconnected)"
    }
}

# ============================================================================
# SCRIPT SUMMARY
# ============================================================================

$SummaryMode = if ($PreviewOnly) { "Preview" } else { "Cleanup" }
$SummaryDevices = if ($OrphanedDevices) { $OrphanedDevices.Count } else { 0 }

Write-Output "
========================================
Script Execution Summary
========================================
Script: Cleanup Orphaned Autopilot Devices
Mode: $SummaryMode
Autopilot Devices: $($AutopilotDevices.Count)
Orphaned Devices Found: $SummaryDevices
Status: Completed
========================================
"
