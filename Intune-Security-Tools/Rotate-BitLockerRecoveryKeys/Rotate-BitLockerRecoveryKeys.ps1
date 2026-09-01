<#
.TITLE
    Rotate BitLocker Keys

.SYNOPSIS
    Rotates BitLocker keys for all Windows devices in Intune using Graph API.

.DESCRIPTION
    This script connects to Intune via Graph API and rotates the BitLocker keys for all managed Windows devices.
    The script retrieves all Windows devices from Intune and triggers BitLocker key rotation for each device.
    It provides real-time feedback on the rotation process and handles errors gracefully.

    Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency.

.TAGS
    Security,Operational

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.ReadWrite.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.5.1

.CHANGELOG
    1.5.1 (2026-08-26)
    - Migrated to Enterprise Admin standards
    1.5 - Added a DryRun mode so Azure Automation can validate targeting and permissions without rotating keys
    1.4 - Added workstation boolean handling with typed validation, beta Graph endpoints, and terminating paging errors
    1.3 - Workstation logging now records progress and summaries
    1.2 - Added a confirmation prompt before tenant-wide rotation (skippable with -Force; Azure Automation runbooks now require -Force); rotation calls retry once after 60 seconds on throttling
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing)
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\rotate-bitlocker-keys.ps1
    Rotates BitLocker keys for all Windows devices in Intune

.EXAMPLE
    .\rotate-bitlocker-keys.ps1 -DelaySeconds 5
    Rotates BitLocker keys with a 5-second delay between operations

.EXAMPLE
    .\rotate-bitlocker-keys.ps1 -Force "true"
    Rotates BitLocker keys without the confirmation prompt (use -Force to skip confirmation)

.EXAMPLE
    .\rotate-bitlocker-keys.ps1 -DryRun "true"
    Lists the Windows devices that would be targeted without rotating any BitLocker keys

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID (delegated or application)
    - Local runs prompt for confirmation before rotating unless -Force is specified; Use -Force to skip confirmation in unattended runs
    - BitLocker key rotation is triggered immediately but may take time to complete on the device
    - The script will show real-time progress and results
    - Only Windows devices with BitLocker enabled will be processed
    - Disclaimer: This script is provided AS IS without warranty of any kind. Use it at your own risk.
    - Interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows; app-only via -TenantId/-ClientId/-ClientSecret or -CertificateThumbprint
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Delay in seconds between BitLocker key rotation operations")]
    [int]$DelaySeconds = 2,

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt before rotation")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Preview targeted devices without rotating BitLocker keys")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Entra tenant ID for app-only authentication")]
    [string]$TenantId = "",

    [Parameter(Mandatory = $false, HelpMessage = "Application (client) ID for app-only authentication")]
    [string]$ClientId = "",

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret = "",

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication (alternative to client secret)")]
    [string]$CertificateThumbprint = "")

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
foreach ($runbookBooleanParameter in @('Force', 'DryRun')) {
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

# ============================================================================
# CONFIGURATION - solution identity and logging.
# ============================================================================

$SolutionName = 'rotate-bitlocker-keys'
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

# Initialize required modules (workstation - auto-install Microsoft.Graph.Authentication and MgGraphCommunity if missing)
$RequiredModules = @("Microsoft.Graph.Authentication", "MgGraphCommunity")

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
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
            "DeviceManagementManagedDevices.ReadWrite.All"
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
function Get-MgGraphAllPage {
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

Set-Alias -Name Get-MgGraphAllPages -Value Get-MgGraphAllPage -Scope Global


# Function to rotate BitLocker keys for a device
function Invoke-BitLockerKeyRotation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,
        [Parameter(Mandatory = $true)]
        [string]$DeviceName
    )

    try {
        $rotateUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$DeviceId')/rotateBitLockerKeys"
        Invoke-MgGraphRequest -Method POST -Uri $rotateUri -ContentType "application/json"

        Write-Information "✓ Successfully rotated BitLocker keys for device: $DeviceName" -InformationAction Continue
        return $true
    }
    catch {
        # Retry once after throttling before treating the rotation as failed
        if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*throttled*") {
            Write-Information "Rate limit hit, waiting 60 seconds..." -InformationAction Continue
            Start-Sleep -Seconds 60
            try {
                Invoke-MgGraphRequest -Method POST -Uri $rotateUri -ContentType "application/json"

                Write-Information "✓ Successfully rotated BitLocker keys for device: $DeviceName" -InformationAction Continue
                return $true
            }
            catch {
                Write-Warning "✗ Failed to rotate BitLocker keys for device $DeviceName : $($_.Exception.Message)"
                return $false
            }
        }
        Write-Warning "✗ Failed to rotate BitLocker keys for device $DeviceName : $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    Write-Output "Starting BitLocker key rotation process..."

    # Get all managed Windows devices from Intune
    Write-Output "Retrieving all Windows devices from Intune..."
    $devicesUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem&`$filter=operatingSystem eq 'Windows'"
    $managedDevices = Get-MgGraphAllPage -Uri $devicesUri

    if ($managedDevices.Count -eq 0) {
        Write-Output "No Windows devices found in Intune. No rotation is required."
        exit 0
    }

    Write-Output "✓ Found $($managedDevices.Count) Windows devices"

    if ($DryRun) {
        Write-Output "`nDRY-RUN PREVIEW"
        Write-Output "==============="
        Write-Output "Windows devices that would receive a BitLocker key rotation: $($managedDevices.Count)"
        foreach ($device in $managedDevices) {
            Write-Output "• $($device.deviceName) [$($device.id)]"
        }
        Write-Output "✓ Dry run completed. No BitLocker keys were rotated."
        Write-Log -Message "Dry run completed - $($managedDevices.Count) device(s) would be targeted" -Level 'INFO'
        exit 0
    }

    # Confirmation gate: local runs prompt unless -Force; Azure Automation
    # cannot prompt, so -Force is required there
    if (-not $Force) {
        if ($false) {
            Write-Error "Unattended runs cannot prompt for confirmation. Re-run with -Force to rotate BitLocker keys for $($managedDevices.Count) device(s)."
            exit 1
        }
        Write-Output "`nYou are about to rotate BitLocker keys for $($managedDevices.Count) device(s)."
        $confirmation = Read-Host "Do you want to continue? (Y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-Output "Operation cancelled by user"
            exit 0
        }
    }

    # Initialize counters
    $successCount = 0
    $failureCount = 0
    $totalDevices = $managedDevices.Count
    $currentDevice = 0

    # Process each device
    foreach ($device in $managedDevices) {
        $currentDevice++
        $deviceId = $device.id
        $deviceName = $device.deviceName

        Write-Output "[$currentDevice/$totalDevices] Processing device: $deviceName"

        # Rotate BitLocker keys
        $success = Invoke-BitLockerKeyRotation -DeviceId $deviceId -DeviceName $deviceName

        if ($success) {
            $successCount++
        }
        else {
            $failureCount++
        }

        # Add delay between operations if specified
        if ($DelaySeconds -gt 0 -and $currentDevice -lt $totalDevices) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    # Display summary
    Write-Output "`n"
    Write-Output "============================================"
    Write-Output "BitLocker Key Rotation Summary"
    Write-Output "============================================"
    Write-Output "Total devices processed: $totalDevices"
    Write-Output "Successful rotations: $successCount"
    Write-Output "Failed rotations: $failureCount"
    Write-Output "Success rate: $([math]::Round(($successCount / $totalDevices) * 100, 2))%"
    Write-Output "============================================"

    Write-Output "✓ BitLocker key rotation process completed"
    Write-Log -Message "BitLocker key rotation completed - success: $successCount, failed: $failureCount, total: $totalDevices" -Level 'SUCCESS'
}
catch {
    Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Script execution failed: $($_.Exception.Message)"
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
