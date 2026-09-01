<#
.TITLE
    Cleanup Duplicate Intune Device Records

.SYNOPSIS
    Finds Intune managed-device records that share a serial number and optionally removes the older stale duplicates.

.DESCRIPTION
    This script groups all Intune managed devices by serial number and identifies
    duplicates - typically left behind by re-enrollment, OS reinstalls, or Autopilot
    resets. For every duplicate set it keeps the record with the most recent sync and
    marks the older records for cleanup. By default the script only reports; deletion
    requires the -Remove switch and is preview-safe via -WhatIf. Removing a device
    record from Intune does not wipe the device; it only deletes the stale management
    object.

    Scope is limited to Intune managed-device records returned by
    /deviceManagement/managedDevices. The script does not inspect or delete Microsoft
    Entra device objects or Windows Autopilot registrations. Duplicate-looking Entra
    objects can be expected with Hybrid Autopilot deployments and must not be treated
    as stale Intune records.

    Workstation authentication modes:
    - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available).
    - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication.
    Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.
.TAGS
    Devices,Operational

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.ReadWrite.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.3.1

.CHANGELOG
    1.3.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.3 - Added workstation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.2 - Clarified that only Intune managed-device records are evaluated and removed
    1.1 - workstation now records script progress, outcomes, and summaries in job history
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\cleanup-duplicate-device-records.ps1
    Reports duplicate Intune managed-device records without deleting anything

.EXAMPLE
    .\cleanup-duplicate-device-records.ps1 -Remove "true" -WhatIf
    Shows exactly which Intune managed-device records would be deleted, without deleting them

.EXAMPLE
    .\cleanup-duplicate-device-records.ps1 -Remove "true"
    Deletes the older duplicate Intune managed-device records after an interactive confirmation

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Only Intune managed-device records are evaluated
    - Microsoft Entra device objects and Windows Autopilot registrations are never evaluated or deleted
    - Hybrid Autopilot deployments can create expected duplicate-looking Entra device objects
    - The newest record per serial number (by lastSyncDateTime, falling back to enrolledDateTime) is always kept
    - Devices with empty or placeholder serial numbers (e.g. "Defaultstring") are excluded from duplicate matching
    - Deleting an Intune device record does not wipe or retire the physical device
    - Uses beta Graph endpoints for consistency with the rest of the library
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Delete the older duplicate Intune managed-device records instead of only reporting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$Remove,

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

$SolutionName = 'cleanup-duplicate-device-records'
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
foreach ($runbookBooleanParameter in @('Remove', 'ExportToCsv')) {
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
                Write-Log -Message "Module '$ModuleName' not found. Installing..." -Level 'INFO'

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
                    Write-Log -Message "Successfully installed '$ModuleName'" -Level 'SUCCESS'
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
            "DeviceManagementManagedDevices.ReadWrite.All"
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
                Write-Log -Message "Rate limit hit, waiting 60 seconds..." -Level 'WARNING'
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data: $($_.Exception.Message)"
        }
    } while ($nextLink)

    return $allResults
}

function Get-EffectiveTimestamp {
    param([object]$Device)

    # lastSyncDateTime is the best liveness signal; fall back to enrollment time
    if ($Device.lastSyncDateTime) {
        return [DateTime]::Parse($Device.lastSyncDateTime.ToString())
    }
    if ($Device.enrolledDateTime) {
        return [DateTime]::Parse($Device.enrolledDateTime.ToString())
    }
    return [DateTime]::MinValue
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode 'run' -Type 'General'
    Write-Banner

    # Anchor the default export output beside the script (Law 12).
    if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
        $OutputPath = $scriptBase
    }

    Write-Output "Scope: Intune managed-device records only."
    Write-Output "Microsoft Entra device objects and Windows Autopilot registrations are not evaluated or removed."
    Write-Output "Retrieving Intune managed devices..."
    $devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,deviceName,serialNumber,operatingSystem,model,manufacturer,lastSyncDateTime,enrolledDateTime,userPrincipalName,managementAgent"
    Write-Output "Found $(@($devices).Count) Intune managed devices"

    # Placeholder serials would create false duplicate groups
    $invalidSerials = @("", "defaultstring", "tobefilledbyoem", "systemserialnumber", "0", "none", "unknown")
    $devicesWithSerial = @($devices | Where-Object {
            $_.serialNumber -and ($invalidSerials -notcontains $_.serialNumber.ToLowerInvariant().Trim())
        })

    $duplicateGroups = @($devicesWithSerial | Group-Object -Property { $_.serialNumber.Trim() } | Where-Object { $_.Count -gt 1 })

    if ($duplicateGroups.Count -eq 0) {
        Write-Output "`nNo duplicate Intune managed-device records found."
        return
    }

    Write-Output "Found $($duplicateGroups.Count) serial number(s) with duplicate Intune managed-device records"

    [System.Collections.Generic.List[Object]]$report = @()
    $deleted = 0
    $deleteFailed = 0

    Write-Output "`nDUPLICATE INTUNE MANAGED-DEVICE RECORDS"
    Write-Output ("=" * 50)

    foreach ($group in $duplicateGroups) {
        $sorted = @($group.Group | Sort-Object -Property @{ Expression = { Get-EffectiveTimestamp -Device $_ } } -Descending)
        $keeper = $sorted[0]
        $stale = @($sorted | Select-Object -Skip 1)

        Write-Output "`nSerial: $($group.Name)"
        Write-Output "  KEEP:   $($keeper.deviceName) | last sync $($keeper.lastSyncDateTime) | $($keeper.userPrincipalName)"

        foreach ($staleDevice in $stale) {
            Write-Output "  REMOVE: $($staleDevice.deviceName) | last sync $($staleDevice.lastSyncDateTime) | $($staleDevice.userPrincipalName)"

            $action = "Reported"
            if ($Remove) {
                if ($PSCmdlet.ShouldProcess("$($staleDevice.deviceName) ($($staleDevice.id))", "Delete Intune device record")) {
                    try {
                        Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($staleDevice.id)" -Method DELETE
                        Write-Output "    Deleted"
                        $action = "Deleted"
                        $deleted++
                    }
                    catch {
                        Write-Log -Message "Failed to delete '$($staleDevice.deviceName)': $($_.Exception.Message)" -Level 'WARNING'
                        $action = "DeleteFailed"
                        $deleteFailed++
                    }
                }
                else {
                    $action = "Skipped"
                }
            }

            $report.Add([PSCustomObject]@{
                    SerialNumber   = $group.Name
                    DeviceName     = $staleDevice.deviceName
                    DeviceId       = $staleDevice.id
                    User           = $staleDevice.userPrincipalName
                    LastSync       = $staleDevice.lastSyncDateTime
                    KeptDeviceName = $keeper.deviceName
                    KeptDeviceId   = $keeper.id
                    Action         = $action
                })
        }
    }

    # Summary
    $totalStale = $report.Count
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($duplicateGroups.Count) duplicate serials, $totalStale stale Intune managed-device records"
    if ($Remove) {
        Write-Output "Deleted: $deleted | Failed: $deleteFailed"
    }
    else {
        Write-Output "Run again with -Remove to delete the stale records (add -WhatIf for a dry run)"
    }
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Duplicate_Device_Records_$timestamp.csv"
        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Output "CSV report saved: $csvPath"
    }
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    try {
        $null = Disconnect-MgGraph
        Write-Output "Disconnected from Microsoft Graph"
    }
    catch {
        Write-Verbose "Graph disconnection completed"
    }
}
