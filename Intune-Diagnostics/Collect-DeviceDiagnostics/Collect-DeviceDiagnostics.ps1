<#
.TITLE
    Collect Device Diagnostics

.SYNOPSIS
    Triggers remote diagnostics collection on Windows devices and downloads the resulting log packages.

.DESCRIPTION
    This script starts the Intune "Collect diagnostics" remote action on one or more
    Windows devices (by device name or Entra ID group), waits for the collection to
    complete, and downloads the resulting diagnostic ZIP packages to a local folder.
    It can also list and download previously completed collection requests without
    triggering a new one. This replaces clicking through the portal for every device
    when troubleshooting at scale.

.TAGS
    Diagnostics,Devices

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.ReadWrite.All,GroupMember.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.2.1

.CHANGELOG
    1.2.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.2 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.1 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\collect-device-diagnostics.ps1 -DeviceNames "PC-001","PC-002"
    Triggers diagnostics collection on two devices and downloads the packages when ready

.EXAMPLE
    .\collect-device-diagnostics.ps1 -GroupName "Support - Troubleshooting" -OutputPath "C:\DeviceLogs"
    Collects diagnostics from all Windows devices in the group and saves packages to C:\DeviceLogs

.EXAMPLE
    .\collect-device-diagnostics.ps1 -DeviceNames "PC-001" -DownloadExisting "true"
    Skips triggering a new collection and downloads the most recent completed package instead

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Collect diagnostics is only supported on Windows 10/11 devices; other platforms are skipped
    - The device must be online to receive the action; collection typically completes within minutes but the script stops waiting after -TimeoutMinutes
    - Listing and creating log collection requests requires DeviceManagementManagedDevices.ReadWrite.All (Graph rejects read-only scopes for this surface)
    - Uses beta Graph endpoints for the log collection surface
    - Execution context: LocalOnly - an admin workstation or Azure Automation runbook, not an Intune device context
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Device names to collect diagnostics from")]
    [ValidateNotNullOrEmpty()]
    [string[]]$DeviceNames,

    [Parameter(Mandatory = $false, HelpMessage = "Entra ID group whose Windows devices get diagnostics collected")]
    [ValidateNotNullOrEmpty()]
    [string]$GroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Folder in which diagnostic packages are saved")]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Download the latest existing completed package instead of triggering a new collection")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$DownloadExisting,

    [Parameter(Mandatory = $false, HelpMessage = "Minutes to wait for collections to complete")]
    [ValidateRange(1, 120)]
    [int]$TimeoutMinutes = 15,

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and log placement.
# ============================================================================

$SolutionName = 'collect-device-diagnostics'
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

# Normalize the local module-install override for Azure Automation parameter binding.
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

# Azure Automation supplies portal parameter values as strings. Normalize the
# public boolean parameters once so local and runbook execution use real booleans.
foreach ($runbookBooleanParameter in @('DownloadExisting')) {
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

$selectedTargets = @(
    if (@($DeviceNames).Count -gt 0) { 'ByDevice' }
    if (-not [string]::IsNullOrWhiteSpace($GroupName)) { 'ByGroup' }
)
if ($selectedTargets.Count -ne 1) {
    throw "Specify exactly one target: DeviceNames or GroupName."
}
$TargetMode = $selectedTargets[0]

# ============================================================================
# ENVIRONMENT DETECTION AND SETUP
# ============================================================================

function Initialize-RequiredModule {
    param(
        [string[]]$ModuleNames,
        [bool]$IsAutomationEnvironment,
        [bool]$ForceInstall = $false
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-Verbose "Checking module: $ModuleName"

        $module = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

        if (-not $module) {
            if ($IsAutomationEnvironment) {
                throw "Module '$ModuleName' is not available in Azure Automation"
            }
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
$IsAzureAutomation = $null -ne $PSPrivateMetadata.JobId.Guid

# Initialize required modules
$RequiredModules = @("Microsoft.Graph.Authentication")

# MgGraphCommunity gives WAM-free interactive sign-in for local runs
if (-not $IsAzureAutomation) {
    $RequiredModules += "MgGraphCommunity"
}

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -IsAutomationEnvironment $IsAzureAutomation -ForceInstall $ForceModuleInstall
    Write-Verbose "✓ All required modules are available"
}
catch {
    Write-Error "Module initialization failed: $_"
    exit 1
}

# ============================================================================
# AUTHENTICATION
# ============================================================================

try {
    if ($IsAzureAutomation) {
        Write-Output "Connecting to Microsoft Graph using Managed Identity..."
        Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    }
    else {
        Write-Output "Connecting to Microsoft Graph..."
        $Scopes = @(
            "DeviceManagementManagedDevices.ReadWrite.All",
            "GroupMember.Read.All"
        )
        Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
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

function Get-TargetDevice {
    # Resolves the requested devices to Intune Windows managed devices
    $devices = [System.Collections.Generic.List[Object]]::new()

    if ($TargetMode -eq "ByDevice") {
        foreach ($deviceName in $DeviceNames) {
            $escapedName = $deviceName -replace "'", "''"
            $found = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$escapedName'&`$select=id,deviceName,operatingSystem,lastSyncDateTime"

            if (@($found).Count -eq 0) {
                Write-Warning "Device '$deviceName' not found in Intune"
                continue
            }
            foreach ($device in $found) {
                $devices.Add($device)
            }
        }
    }
    else {
        $escapedGroup = $GroupName -replace "'", "''"
        $groups = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/groups?`$filter=displayName eq '$escapedGroup'&`$select=id,displayName"
        if (@($groups).Count -ne 1) {
            throw "Expected exactly one group named '$GroupName', found $(@($groups).Count)"
        }

        $members = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/groups/$(@($groups)[0].id)/members?`$select=id,displayName,deviceId"
        foreach ($member in $members) {
            if (-not $member.deviceId) { continue }

            # Group members are Entra device objects; map to Intune managed devices
            $managed = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$($member.deviceId)'&`$select=id,deviceName,operatingSystem,lastSyncDateTime"
            foreach ($device in $managed) {
                $devices.Add($device)
            }
        }
    }

    # Collect diagnostics is a Windows-only action
    $windowsDevices = @($devices | Where-Object { $_.operatingSystem -eq "Windows" })
    $skipped = @($devices).Count - $windowsDevices.Count
    if ($skipped -gt 0) {
        Write-Warning "Skipped $skipped non-Windows device(s) - collect diagnostics only supports Windows"
    }

    return $windowsDevices
}

function Save-DiagnosticPackage {
    param(
        [object]$Device,
        [object]$Request
    )

    try {
        $downloadResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($Device.id)/logCollectionRequests/$($Request.id)/createDownloadUrl" -Method POST
        $downloadUrl = $downloadResponse.value

        if (-not $downloadUrl) {
            Write-Warning "No download URL returned for '$($Device.deviceName)'"
            return $false
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $zipPath = Join-Path $OutputPath "DeviceDiagnostics_$($Device.deviceName)_$timestamp.zip"

        # The download URL is a pre-authenticated Azure Storage link from Graph,
        # so a plain web request (not Invoke-MgGraphRequest) is correct here
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
        Write-Information "✓ Downloaded: $zipPath" -InformationAction Continue
        return $true
    }
    catch {
        Write-Warning "Failed to download package for '$($Device.deviceName)': $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode 'run' -Type 'General'
    Write-Banner
    $null = New-Item -Path $OutputPath -ItemType Directory -Force

    Write-Output "Resolving target devices..."
    $targetDevices = Get-TargetDevice

    if (@($targetDevices).Count -eq 0) {
        throw "No Windows devices found to collect diagnostics from"
    }
    Write-Output "✓ Targeting $(@($targetDevices).Count) Windows device(s)"

    $downloaded = 0
    $failed = 0
    $pendingRequests = @{}

    if ($DownloadExisting) {
        # Download the newest completed package per device without triggering anything
        foreach ($device in $targetDevices) {
            $requests = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/logCollectionRequests"
            # The response entity carries receivedDateTimeUTC (not receivedDateTime)
            $latestCompleted = @($requests | Where-Object { $_.status -eq "completed" } | Sort-Object -Property @{ Expression = {
                        $timestamp = if ($_.receivedDateTimeUTC) { $_.receivedDateTimeUTC } else { $_.requestedDateTimeUTC }
                        if ($timestamp) { [DateTime]::Parse($timestamp.ToString()) } else { [DateTime]::MinValue }
                    } } -Descending) | Select-Object -First 1

            if (-not $latestCompleted) {
                Write-Warning "No completed log collection exists for '$($device.deviceName)' - run without -DownloadExisting to trigger one"
                $failed++
                continue
            }

            if (Save-DiagnosticPackage -Device $device -Request $latestCompleted) { $downloaded++ } else { $failed++ }
        }
    }
    else {
        # Trigger a new collection on every device
        foreach ($device in $targetDevices) {
            try {
                # The action parameter is a nested deviceLogCollectionRequest object,
                # not a flat string (Graph rejects { templateType = "predefined" })
                $body = @{ templateType = @{ templateType = "predefined" } } | ConvertTo-Json
                $request = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/createDeviceLogCollectionRequest" -Method POST -Body $body -ContentType "application/json"
                $pendingRequests[$device.id] = @{ Device = $device; RequestId = $request.id }
                Write-Output "✓ Collection triggered on '$($device.deviceName)'"
            }
            catch {
                Write-Warning "Failed to trigger collection on '$($device.deviceName)': $($_.Exception.Message)"
                $failed++
            }
        }

        # Poll until requests complete or the timeout is reached
        if ($pendingRequests.Count -gt 0) {
            Write-Output "Waiting for $($pendingRequests.Count) collection(s) to complete (timeout: $TimeoutMinutes minutes)..."
            $deadline = (Get-Date).AddMinutes($TimeoutMinutes)

            while ($pendingRequests.Count -gt 0 -and (Get-Date) -lt $deadline) {
                Start-Sleep -Seconds 30

                foreach ($deviceId in @($pendingRequests.Keys)) {
                    $entry = $pendingRequests[$deviceId]
                    try {
                        $status = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/logCollectionRequests/$($entry.RequestId)" -Method GET

                        if ($status.status -eq "completed") {
                            if (Save-DiagnosticPackage -Device $entry.Device -Request $status) { $downloaded++ } else { $failed++ }
                            $pendingRequests.Remove($deviceId)
                        }
                        elseif ($status.status -eq "failed") {
                            Write-Warning "Collection failed on '$($entry.Device.deviceName)'"
                            $failed++
                            $pendingRequests.Remove($deviceId)
                        }
                    }
                    catch {
                        Write-Verbose "Status check pending for '$($entry.Device.deviceName)': $($_.Exception.Message)"
                    }
                }
            }

            foreach ($deviceId in @($pendingRequests.Keys)) {
                $entry = $pendingRequests[$deviceId]
                Write-Warning "Collection on '$($entry.Device.deviceName)' did not complete within $TimeoutMinutes minutes - the device may be offline. Re-run later with -DownloadExisting to fetch the package."
            }
        }
    }

    # Summary
    Write-Output "`n========================================"
    Write-Output "Diagnostics Collection Summary"
    Write-Output "========================================"
    Write-Output "Devices targeted:  $(@($targetDevices).Count)"
    Write-Output "Packages saved:    $downloaded"
    Write-Output "Failures/timeouts: $($failed + $pendingRequests.Count)"
    Write-Output "Output folder:     $OutputPath"
    Write-Output "========================================"
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
