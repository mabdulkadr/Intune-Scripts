<#
.TITLE
    Rotate macOS LAPS Passwords

.SYNOPSIS
    Rotates Local Administrator Password Solution (LAPS) passwords for macOS devices in Intune using Graph API.

.DESCRIPTION
    This script connects to Intune via Microsoft Graph API and rotates the LAPS passwords for managed macOS devices.
    The script retrieves all macOS devices from Intune and triggers LAPS password rotation for each device.
    It provides real-time feedback on the rotation process, handles errors gracefully, and generates detailed reports.
    The script supports filtering by device groups, individual devices, or processing all macOS devices.

    Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency.

.TAGS
    Security,Operational

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.PrivilegedOperations.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.5.1

.CHANGELOG
    1.5.1 (2026-08-26)
    - Migrated to Enterprise Admin standards
    1.5 - Treat test-mode and empty-target outcomes as normal output
    1.4 - Added workstation boolean handling with typed validation, beta Graph endpoints, and terminating paging errors
    1.3 - Workstation logging now records progress and summaries
    1.2 - Confirmation now uses -Force to skip prompt; rotation calls retry once after 60 seconds on throttling; results collection uses a generic list
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing); added DeviceManagementManagedDevices.PrivilegedOperations.All scope required by the Graph action (calls previously always failed with 403)
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Rotate-MacOSFileVaultPasswords.ps1
    Rotates LAPS passwords for all macOS devices in Intune

.EXAMPLE
    .\Rotate-MacOSFileVaultPasswords.ps1 -DeviceName "MacBook-001"
    Rotates LAPS password for a specific device

.EXAMPLE
    .\Rotate-MacOSFileVaultPasswords.ps1 -DelaySeconds 5 -ExportReport "true"
    Rotates LAPS passwords with a 5-second delay between operations and exports results

.EXAMPLE
    .\Rotate-MacOSFileVaultPasswords.ps1 -TestMode "true" -DeviceLimit 5
    Runs in test mode, processing only 5 devices without actual rotation

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - LAPS must be configured and enabled for macOS devices in Intune
    - The rotation is triggered immediately but may take time to complete on the device
    - Personal devices cannot have their LAPS passwords rotated
    - The new password will be available in Intune after successful rotation
    - Interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows; app-only via -TenantId/-ClientId/-ClientSecret or -CertificateThumbprint
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Specific device name to rotate LAPS password")]
    [string]$DeviceName,

    [Parameter(Mandatory = $false, HelpMessage = "Specific device ID to rotate LAPS password")]
    [string]$DeviceId,

    [Parameter(Mandatory = $false, HelpMessage = "Delay in seconds between LAPS rotation operations")]
    [int]$DelaySeconds = 2,

    [Parameter(Mandatory = $false, HelpMessage = "Export rotation results to CSV")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ExportReport,

    [Parameter(Mandatory = $false, HelpMessage = "Directory path to save reports")]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Test mode - show what would be rotated without making changes")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$TestMode,

    [Parameter(Mandatory = $false, HelpMessage = "Limit number of devices to process (useful for testing)")]
    [int]$DeviceLimit = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Show progress during processing")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ShowProgress,

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt before rotation")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Entra tenant ID for app-only authentication")]
    [string]$TenantId = "",

    [Parameter(Mandatory = $false, HelpMessage = "Application (client) ID for app-only authentication")]
    [string]$ClientId = "",

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret = "",

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication (alternative to client secret)")]
    [string]$CertificateThumbprint = ""
)

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
foreach ($runbookBooleanParameter in @('ExportReport', 'TestMode', 'ShowProgress', 'Force')) {
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

$ErrorActionPreference = 'Stop'

# Report path anchored to the script location (Law 12): dot-sourcing or a
# caller's cd must never redirect exports to an unpredictable directory.
$scriptBase = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
if (-not $PSBoundParameters.ContainsKey('OutputPath')) { $OutputPath = $scriptBase }

# ============================================================================
# CONFIGURATION - solution identity and logging.
# ============================================================================

$SolutionName = 'Rotate-MacOSFileVaultPasswords'
$ScriptMode   = 'Run'

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

$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
Write-Banner

# ============================================================================
# ENVIRONMENT DETECTION AND SETUP
# ============================================================================

function Initialize-RequiredModule {
    <#
    .SYNOPSIS
    Ensures required modules are available and loaded
    #>
    param(
        [string[]]$ModuleNames,
        [bool]$IsAutomation = $false,
        [bool]$ForceInstall = $false
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-Verbose "Checking module: $ModuleName"

        # Check if module is available
        $module = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

        if (-not $module) {
            if ($IsAutomation) {
                $errorMessage = @"
Module '$ModuleName' is not available in this Azure Automation Account.

To resolve this issue:
1. Go to Azure Portal
2. Navigate to your Automation Account
3. Go to 'Modules' > 'Browse Gallery'
4. Search for '$ModuleName'
5. Click 'Import' and wait for installation to complete

Alternative: Use PowerShell to import the module:
Import-Module Az.Automation
Import-AzAutomationModule -AutomationAccountName "YourAccount" -ResourceGroupName "YourRG" -Name "$ModuleName"
"@
                throw $errorMessage
            }
            else {
                # Local environment - attempt to install
                Write-Information "Module '$ModuleName' not found. Attempting to install..." -InformationAction Continue

                if (-not $ForceInstall) {
                    $response = Read-Host "Install module '$ModuleName'? (Y/N)"
                    if ($response -notmatch '^[Yy]') {
                        throw "Module '$ModuleName' is required but installation was declined."
                    }
                }

                try {
                    # Check if running as administrator for AllUsers scope
                    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                    $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }

                    Write-Information "Installing '$ModuleName' in scope '$scope'..." -InformationAction Continue
                    Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                    Write-Information "✓ Successfully installed '$ModuleName'" -InformationAction Continue
                }
                catch {
                    throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
                }
            }
        }

        # Import the module
        try {
            Write-Verbose "Importing module: $ModuleName"
            Import-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Verbose "✓ Successfully imported '$ModuleName'"
        }
        catch {
            throw "Failed to import module '$ModuleName': $($_.Exception.Message)"
        }
    }
}

# Initialize required modules (workstation - auto-install Microsoft.Graph.Authentication and MgGraphCommunity if missing)
$RequiredModuleList = @("Microsoft.Graph.Authentication", "MgGraphCommunity")

try {
    Initialize-RequiredModule -ModuleNames $RequiredModuleList -ForceInstall $ForceModuleInstall
    Write-Verbose "✓ All required modules are available"
}
catch {
    Write-Log -Message "Module initialization failed: $_" -Level 'ERROR'
    Write-Error "Module initialization failed: $_"
    exit 1
}

# ============================================================================
# AUTHENTICATION
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
            "DeviceManagementManagedDevices.PrivilegedOperations.All",
            "DeviceManagementManagedDevices.ReadWrite.All",
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
    Write-Log -Message "Connected to Microsoft Graph" -Level 'SUCCESS'
}
catch {
    Write-Log -Message "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Function to get all pages of results from Graph API
function Get-MgGraphPaginatedData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [int]$DelayMs = 100
    )

    $AllResult = @()
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
                $AllResult += $Response.value
            }
            else {
                $AllResult += $Response
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

    return $AllResult
}

# Function to rotate LAPS password for a device
function Invoke-LAPSPasswordRotation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,
        [Parameter(Mandatory = $true)]
        [string]$DeviceName,
        [string]$OwnerType = "unknown",
        [bool]$TestMode = $false
    )

    $result = [PSCustomObject]@{
        DeviceName = $DeviceName
        DeviceId = $DeviceId
        OwnerType = $OwnerType
        Status = "Pending"
        Message = ""
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    # Check if device is personal
    if ($OwnerType -eq "personal") {
        $result.Status = "Skipped"
        $result.Message = "Personal device - LAPS rotation not supported"
        return $result
    }

    if ($TestMode) {
        $result.Status = "Test Mode"
        $result.Message = "Would rotate LAPS password (test mode)"
        return $result
    }

    try {
        # Construct the URI for LAPS password rotation
        $rotateUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$DeviceId')/rotateLocalAdminPassword"

        # Send POST request to rotate LAPS password
        $response = Invoke-MgGraphRequest -Uri $rotateUri -Method POST

        $result.Status = "Success"
        $result.Message = "LAPS password rotation initiated successfully"
    }
    catch {
        $errorMessage = $_.Exception.Message

        # Retry once after throttling before classifying the failure
        if ($errorMessage -like "*429*" -or $errorMessage -like "*throttled*") {
            Write-Information "Rate limit hit, waiting 60 seconds..." -InformationAction Continue
            Start-Sleep -Seconds 60
            try {
                $response = Invoke-MgGraphRequest -Uri $rotateUri -Method POST

                $result.Status = "Success"
                $result.Message = "LAPS password rotation initiated successfully"
                return $result
            }
            catch {
                $errorMessage = $_.Exception.Message
            }
        }

        # Handle specific error cases
        if ($errorMessage -like "*404*" -or $errorMessage -like "*Not Found*") {
            $result.Status = "Failed"
            $result.Message = "Device not found or LAPS not configured"
        }
        elseif ($errorMessage -like "*403*" -or $errorMessage -like "*Forbidden*") {
            $result.Status = "Failed"
            $result.Message = "Access denied - insufficient permissions"
        }
        elseif ($errorMessage -like "*BadRequest*" -or $errorMessage -like "*400*") {
            $result.Status = "Failed"
            $result.Message = "LAPS rotation not supported for this device"
        }
        else {
            $result.Status = "Error"
            $result.Message = $errorMessage
        }
    }

    return $result
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    Write-Output "Starting macOS LAPS password rotation..."

    # Validate output path if export is requested
    if ($ExportReport) {
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
            Write-Output "Created output directory: $OutputPath"
        }
    }

    # Build filter for retrieving devices
    $filter = "operatingSystem eq 'macOS'"

    # Get devices based on parameters
    if ($DeviceId) {
        Write-Output "Retrieving device with ID: $DeviceId"
        $deviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$DeviceId')"
        try {
            $device = Invoke-MgGraphRequest -Uri $deviceUri -Method GET
            $devices = @($device)
        }
        catch {
            Write-Error "Failed to retrieve device with ID '$DeviceId': $_"
            exit 1
        }
    }
    elseif ($DeviceName) {
        Write-Output "Retrieving device: $DeviceName"
        $deviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=$filter and deviceName eq '$DeviceName'"
        $devices = Get-MgGraphPaginatedData -Uri $deviceUri

        if ($devices.Count -eq 0) {
            Write-Error "Device '$DeviceName' not found"
            exit 1
        }
    }
    else {
        Write-Output "Retrieving all macOS devices from Intune..."
        $devicesUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=$filter"
        $devices = Get-MgGraphPaginatedData -Uri $devicesUri
    }

    if ($devices.Count -eq 0) {
        Write-Output "No macOS devices found. No password rotation is required."
        return
    }

    # Apply device limit if specified
    if ($DeviceLimit -gt 0 -and $devices.Count -gt $DeviceLimit) {
        Write-Output "Limiting processing to $DeviceLimit devices (out of $($devices.Count) total)"
        $devices = $devices | Select-Object -First $DeviceLimit
    }

    Write-Output "Found $($devices.Count) macOS device(s) to process"

    # Show test mode warning
    if ($TestMode) {
        Write-Output "RUNNING IN TEST MODE - No actual LAPS passwords will be rotated"
    }

    # Confirmation gate: local runs prompt unless -Force; Azure Automation
    # cannot prompt, so -Force is required there
    if (-not $Force -and -not $TestMode) {
        if ($false) {
            Write-Error "Unattended runs cannot prompt for confirmation. Re-run with -Force to rotate LAPS passwords for $($devices.Count) device(s)."
            exit 1
        }
        Write-Output "`nYou are about to rotate LAPS passwords for $($devices.Count) device(s)."
        $confirmation = Read-Host "Do you want to continue? (Y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-Output "Operation cancelled by user"
            return
        }
    }

    # Process devices
    [System.Collections.Generic.List[Object]]$results = @()
    $processedCount = 0
    $successCount = 0
    $failedCount = 0
    $skippedCount = 0

    foreach ($device in $devices) {
        $processedCount++

        if ($ShowProgress) {
            $percentComplete = [math]::Round(($processedCount / $devices.Count) * 100, 1)
            Write-Progress -Activity "Rotating LAPS Passwords" -Status "Processing: $($device.deviceName)" -PercentComplete $percentComplete
        }

        Write-Output "[$processedCount/$($devices.Count)] Processing: $($device.deviceName)"

        # Rotate LAPS password
        $rotationResult = Invoke-LAPSPasswordRotation -DeviceId $device.id -DeviceName $device.deviceName -OwnerType $device.ownerType -TestMode $TestMode

        # Update counters
        switch ($rotationResult.Status) {
            "Success" { $successCount++ }
            "Failed" { $failedCount++ }
            "Error" { $failedCount++ }
            "Skipped" { $skippedCount++ }
            "Test Mode" { $successCount++ }
        }

        # Display result
        $statusSymbol = switch ($rotationResult.Status) {
            "Success" { "✓" }
            "Failed" { "✗" }
            "Error" { "✗" }
            "Skipped" { "⊘" }
            "Test Mode" { "ℹ" }
            default { "-" }
        }

        Write-Output "  $statusSymbol Status: $($rotationResult.Status) - $($rotationResult.Message)"

        # Add additional device information to result
        $rotationResult | Add-Member -MemberType NoteProperty -Name "SerialNumber" -Value $device.serialNumber
        $rotationResult | Add-Member -MemberType NoteProperty -Name "OSVersion" -Value $device.osVersion
        $rotationResult | Add-Member -MemberType NoteProperty -Name "LastSyncDateTime" -Value $device.lastSyncDateTime
        $rotationResult | Add-Member -MemberType NoteProperty -Name "ComplianceState" -Value $device.complianceState

        $results.Add($rotationResult)

        # Add delay between operations (except for last device)
        if ($processedCount -lt $devices.Count -and $DelaySeconds -gt 0) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity "Rotating LAPS Passwords" -Completed
    }

    # Display summary
    Write-Output "`n========================================"
    Write-Output "LAPS Password Rotation Summary"
    Write-Output "========================================"
    Write-Output "Total devices processed: $processedCount"
    Write-Output "Successful rotations: $successCount"
    Write-Output "Failed rotations: $failedCount"
    Write-Output "Skipped devices: $skippedCount"
    if ($TestMode) {
        Write-Output "Mode: TEST MODE (no actual changes made)"
    }
    Write-Output "========================================"

    # Export results if requested
    if ($ExportReport) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $csvPath = Join-Path $OutputPath "LAPS-Rotation-Report-$timestamp.csv"
        $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
        Write-Output "✓ Results exported to: $csvPath"

        # Also export failed devices separately if any
        if ($failedCount -gt 0) {
            $failedPath = Join-Path $OutputPath "LAPS-Rotation-Failed-$timestamp.csv"
            $results | Where-Object { $_.Status -in @("Failed", "Error") } | Export-Csv -Path $failedPath -NoTypeInformation -Encoding utf8
            Write-Output "✓ Failed devices exported to: $failedPath"
        }
    }

    # Show failed devices if any
    if ($failedCount -gt 0) {
        Write-Output "`nFailed devices:"
        $results | Where-Object { $_.Status -in @("Failed", "Error") } |
            Select-Object DeviceName, Status, Message |
            Format-Table -AutoSize
    }

    Write-Output "✓ LAPS password rotation completed"
    Write-Log -Message "LAPS password rotation completed - success: $successCount, failed: $failedCount, skipped: $skippedCount, total: $processedCount" -Level 'SUCCESS'
}
catch {
    Write-Log -Message "Script failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Cleanup operations
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        Write-Output "Disconnected from Microsoft Graph"
    }
    catch {
        Write-Verbose "Unable to disconnect from Microsoft Graph: $($_.Exception.Message)"
    }
}
