<#
.TITLE
    FileVault Key Storage Checker

.SYNOPSIS
    Monitor and verify that FileVault recovery keys for macOS devices are properly stored in Intune.

.DESCRIPTION
    This script connects to Microsoft Graph API, retrieves all macOS devices from Intune,
    and checks if each device has FileVault recovery keys stored in Intune. The script
    provides detailed reporting on compliance status, identifies devices without stored keys,
    and exports comprehensive results to CSV format for further analysis. This helps ensure
    proper FileVault key escrow for data recovery scenarios.

    Supports interactive sign-in and unattended app-only via -TenantId/-ClientId.

.TAGS
    Monitoring,Security

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.PrivilegedOperations.All,DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.4.1

.CHANGELOG
    1.4.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.4 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.3 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.2 - Key checks get a per-device delay and 429 retry; guarded last sync date parsing; device list selects only needed fields; pagination helper keeps single-item results as arrays
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing); added DeviceManagementManagedDevices.PrivilegedOperations.All scope required by the Graph action (calls previously always failed with 403)
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Test-FileVaultKeys.ps1
    Generates FileVault key storage report for all macOS devices in Intune

.EXAMPLE
    .\Test-FileVaultKeys.ps1 -OutputPath "C:\Reports" -OnlyShowMissing "true"
    Saves report to specified directory and shows only devices missing FileVault keys

.EXAMPLE
    .\Test-FileVaultKeys.ps1 -IncludeLastSync "true" -ExportJson "true"
    Includes last sync information and exports results in JSON format as well

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - FileVault keys are automatically escrowed to Intune when properly configured
    - Devices must be enrolled in Intune and have FileVault policy applied
    - Consider configuring FileVault policies to enforce key escrow
    - Regular monitoring helps ensure compliance with data protection requirements
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
    - Logs: %ProgramData%\check-filevault-keys\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Directory path to save reports")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Only show devices missing FileVault keys")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$OnlyShowMissing,

    [Parameter(Mandatory = $false, HelpMessage = "Include last sync date information")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeLastSync,

    [Parameter(Mandatory = $false, HelpMessage = "Export results in JSON format as well")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ExportJson,

    [Parameter(Mandatory = $false, HelpMessage = "Show progress during processing")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ShowProgress,

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
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'check-filevault-keys'
$ScriptMode   = 'run'

$scriptBasePath = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path -Path $scriptBasePath -ChildPath $OutputPath
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
foreach ($boolParamName in @('OnlyShowMissing', 'IncludeLastSync', 'ExportJson', 'ShowProgress')) {
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

$RequiredModuleList = @(
    "Microsoft.Graph.Authentication",
    "MgGraphCommunity"
)

try {
    Initialize-RequiredModule -ModuleNames $RequiredModuleList -ForceInstall $ForceModuleInstall
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
            "DeviceManagementManagedDevices.PrivilegedOperations.All",
            "DeviceManagementManagedDevices.Read.All"
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

# Function to get all pages of results from Graph API
function Get-MgGraphAllPages {
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

    # Comma prevents unrolling so single-element results stay arrays
    return , $AllResult
}

# Function to check FileVault key availability for a device
function Test-FileVaultKeyAvailability {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,
        [Parameter(Mandatory = $false)]
        [string]$DeviceName = "Unknown",
        [Parameter(Mandatory = $false)]
        [string]$OwnerType = "unknown"
    )

    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        Write-Verbose "Device $DeviceName has no Device ID"
        return @{
            HasKey   = $false
            KeyAvailable = $false
            Status   = "No Device ID"
            ErrorDetails = $null
        }
    }

    $maxRetries = 2
    $retryCount = 0
    while ($true) {
        try {
            # Use the getFileVaultKey endpoint
            $keyUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$DeviceId')/getFileVaultKey"
            $keyResponse = Invoke-MgGraphRequest -Uri $keyUri -Method GET

            # Check if response contains a recovery key
            if ($keyResponse -and $keyResponse.value) {
                return @{
                    HasKey   = $true
                    KeyAvailable = $true
                    Status   = "Key Available"
                    ErrorDetails = $null
                }
            }
            else {
                return @{
                    HasKey   = $false
                    KeyAvailable = $false
                    Status   = "No Key Found"
                    ErrorDetails = $null
                }
            }
        }
        catch {
            $errorMessage = $_.Exception.Message

            # Retry on throttling instead of reporting a false "Error Checking"
            if (($errorMessage -like "*429*" -or $errorMessage -like "*throttled*") -and $retryCount -lt $maxRetries) {
                $retryCount++
                Write-Information "Rate limit hit checking device $DeviceName, waiting 60 seconds (retry $retryCount of $maxRetries)..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }

            # Handle specific error cases
            if ($errorMessage -like "*404*" -or $errorMessage -like "*Not Found*") {
                return @{
                    HasKey   = $false
                    KeyAvailable = $false
                    Status   = "No Key Stored"
                    ErrorDetails = "FileVault key not found in Intune"
                }
            }
            elseif ($errorMessage -like "*403*" -or $errorMessage -like "*Forbidden*") {
                return @{
                    HasKey   = $false
                    KeyAvailable = $false
                    Status   = "Access Denied"
                    ErrorDetails = "Insufficient permissions"
                }
            }
            elseif ($errorMessage -like "*BadRequest*" -or $errorMessage -like "*400*") {
                # BadRequest typically indicates personal device or unsupported operation
                if ($OwnerType -eq "personal") {
                    return @{
                        HasKey   = $false
                        KeyAvailable = $false
                        Status   = "Personal Device"
                        ErrorDetails = "FileVault keys not accessible for personal devices"
                    }
                }
                else {
                    return @{
                        HasKey   = $false
                        KeyAvailable = $false
                        Status   = "Not Supported"
                        ErrorDetails = "FileVault key retrieval not supported for this device"
                    }
                }
            }
            elseif ($errorMessage -like "*Personal*") {
                return @{
                    HasKey   = $false
                    KeyAvailable = $false
                    Status   = "Personal Device"
                    ErrorDetails = "Cannot retrieve key for personal device"
                }
            }
            else {
                Write-Verbose "Error checking FileVault key for device $DeviceName : $errorMessage"
                return @{
                    HasKey   = $false
                    KeyAvailable = $false
                    Status   = "Error Checking"
                    ErrorDetails = $errorMessage
                }
            }
        }
    }
}

# Function to format device last sync date
function Format-LastSyncDate {
    param([datetime]$LastSyncDateTime)

    if ($LastSyncDateTime -eq [datetime]::MinValue) {
        return "Never"
    }

    $daysSinceSync = (Get-Date) - $LastSyncDateTime

    if ($daysSinceSync.TotalDays -lt 1) {
        return "Today"
    }
    elseif ($daysSinceSync.TotalDays -lt 2) {
        return "Yesterday"
    }
    else {
        return "$([math]::Round($daysSinceSync.TotalDays)) days ago"
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner

    Write-Output "Starting FileVault key storage check..."

    # Validate output path
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Output "Created output directory: $OutputPath"
    }

    # Get all macOS devices from Intune
    Write-Output "Retrieving macOS devices from Intune..."
    $devicesUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'macOS'&`$select=id,deviceName,serialNumber,model,manufacturer,osVersion,complianceState,isEncrypted,managementState,ownerType,lastSyncDateTime"
    $devices = Get-MgGraphAllPages -Uri $devicesUri

    if ($devices.Count -eq 0) {
        Write-Warning "No macOS devices found in Intune"
        return
    }

    Write-Output "Found $($devices.Count) macOS devices. Checking FileVault key status..."

    $results = @()
    $processedCount = 0

    foreach ($device in $devices) {
        $processedCount++

        if ($ShowProgress) {
            $percentComplete = [math]::Round(($processedCount / $devices.Count) * 100, 1)
            Write-Progress -Activity "Checking FileVault Keys" -Status "Processing device: $($device.deviceName)" -PercentComplete $percentComplete
        }

        # Delay between per-device key checks to respect rate limits
        if ($processedCount -gt 1) {
            Start-Sleep -Milliseconds 100
        }

        # Check FileVault key availability
        $filevaultCheck = Test-FileVaultKeyAvailability -DeviceId $device.id -DeviceName $device.deviceName -OwnerType $device.ownerType

        # Prepare result object
        $deviceResult = [PSCustomObject]@{
            DeviceName                  = $device.deviceName
            SerialNumber                = $device.serialNumber
            Model                       = $device.model
            Manufacturer                = $device.manufacturer
            OSVersion                   = $device.osVersion
            DeviceId                    = $device.id
            "FileVault Key in Intune"   = if ($filevaultCheck.HasKey) { "Yes" } else { "No" }
            Status                      = $filevaultCheck.Status
            ComplianceState             = $device.complianceState
            EncryptionState             = $device.isEncrypted
            ManagementState             = $device.managementState
            OwnerType                   = $device.ownerType
        }

        # Add error details if present
        if ($filevaultCheck.ErrorDetails) {
            $deviceResult | Add-Member -MemberType NoteProperty -Name "Error Details" -Value $filevaultCheck.ErrorDetails
        }

        # Add last sync information if requested
        if ($IncludeLastSync) {
            # lastSyncDateTime arrives as a string from Graph; cast with a guard
            if (-not [string]::IsNullOrEmpty($device.lastSyncDateTime)) {
                $lastSyncDate = [datetime]$device.lastSyncDateTime
                $lastSyncDisplay = $lastSyncDate.ToString("yyyy-MM-dd HH:mm")
                $syncStatusDisplay = Format-LastSyncDate -LastSyncDateTime $lastSyncDate
            }
            else {
                $lastSyncDisplay = "Unknown"
                $syncStatusDisplay = "Unknown"
            }
            $deviceResult | Add-Member -MemberType NoteProperty -Name "Last Sync" -Value $lastSyncDisplay
            $deviceResult | Add-Member -MemberType NoteProperty -Name "Sync Status" -Value $syncStatusDisplay
        }

        # Add to results (filter if only showing missing keys)
        if (-not $OnlyShowMissing -or -not $filevaultCheck.HasKey) {
            $results += $deviceResult
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity "Checking FileVault Keys" -Completed
    }

    # Display results
    Write-Output "`nFileVault Key Storage Results:"
    $results | Format-Table -AutoSize

    # Calculate and display summary statistics
    $totalDevices = $devices.Count
    $devicesWithKeys = ($results | Where-Object { $_."FileVault Key in Intune" -eq "Yes" }).Count
    $devicesWithoutKeys = ($results | Where-Object { $_."FileVault Key in Intune" -eq "No" }).Count
    $personalDevices = ($results | Where-Object { $_.Status -eq "Personal Device" }).Count
    $errorDevices = ($results | Where-Object { $_.Status -eq "Error Checking" }).Count

    if ($totalDevices -gt 0) {
        $compliancePercentage = [math]::Round(($devicesWithKeys / $totalDevices) * 100, 1)
    }
    else {
        $compliancePercentage = 0
    }

    Write-Output "`n========================================"
    Write-Output "FileVault Key Storage Summary"
    Write-Output "========================================"
    Write-Output "Total macOS devices in Intune: $totalDevices"
    Write-Output "Devices with FileVault keys in Intune: $devicesWithKeys"
    Write-Output "Devices without FileVault keys: $devicesWithoutKeys"
    if ($personalDevices -gt 0) {
        Write-Output "Personal devices (keys not accessible): $personalDevices"
    }
    if ($errorDevices -gt 0) {
        Write-Output "Devices with errors: $errorDevices"
    }
    Write-Output "Compliance percentage: $compliancePercentage%"
    Write-Output "========================================"

    # Export results to CSV
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvPath = Join-Path $OutputPath "FileVault-Key-Storage-Report-$timestamp.csv"
    $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
    Write-Output "[OK] Results exported to: $csvPath"

    # Export to JSON if requested
    if ($ExportJson) {
        $jsonPath = Join-Path $OutputPath "FileVault-Key-Storage-Report-$timestamp.json"
        $jsonData = @{
            GeneratedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Summary       = @{
                TotalDevices         = $totalDevices
                DevicesWithKeys      = $devicesWithKeys
                DevicesWithoutKeys   = $devicesWithoutKeys
                PersonalDevices      = $personalDevices
                ErrorDevices         = $errorDevices
                CompliancePercentage = $compliancePercentage
            }
            Devices       = $results
        }
        $jsonData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath
        Write-Output "[OK] Results exported to JSON: $jsonPath"
    }

    # Show devices without keys if any exist and not in OnlyShowMissing mode
    if ($devicesWithoutKeys -gt 0 -and -not $OnlyShowMissing) {
        Write-Output "`nDevices without FileVault keys in Intune:"
        $devicesWithoutKeysList = $results | Where-Object { $_."FileVault Key in Intune" -eq "No" } | Select-Object DeviceName, SerialNumber, Status, OwnerType
        $devicesWithoutKeysList | Format-Table -AutoSize
    }

    Write-Output "[OK] FileVault key storage check completed successfully"
}
catch {
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

# ============================================================================
# SCRIPT SUMMARY
# ============================================================================

Write-Output "
========================================
Script Execution Summary
========================================
Script: FileVault Key Storage Checker
Total Devices Processed: $($devices.Count)
Devices with Keys: $devicesWithKeys
Compliance Rate: $compliancePercentage%
Report Location: $OutputPath
Status: Completed
========================================
"
