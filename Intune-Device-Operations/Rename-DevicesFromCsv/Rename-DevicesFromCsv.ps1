<#
.TITLE
    Rename Devices from CSV

.SYNOPSIS
    Bulk-renames Intune Windows devices from a CSV mapping file using the setDeviceName remote action.

.DESCRIPTION
    This script reads a CSV file with DeviceName and NewName columns and triggers the
    Intune setDeviceName remote action for each matching Windows device. Every rename
    supports -WhatIf preview, name validation catches illegal computer names before
    any action is sent, and results are summarized per device. Devices are renamed on
    their next check-in; Windows devices typically need a restart for the new name to
    fully apply.

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
    DeviceManagementManagedDevices.PrivilegedOperations.All,DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.3.1

.CHANGELOG
    1.3.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.3 - Added a portal-safe DryRun mode for workstation rename previews
    1.2 - Added workstation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.1 - workstation now records script progress, outcomes, and summaries in job history
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\rename-devices-from-csv.ps1 -CsvPath ".\renames.csv" -WhatIf
    Previews all renames without sending any action

.EXAMPLE
    .\rename-devices-from-csv.ps1 -CsvPath ".\renames.csv"
    Renames all devices listed in the CSV (columns: DeviceName,NewName)

.EXAMPLE
    .\rename-devices-from-csv.ps1 -CsvContent $csvContent
    Uses CSV text supplied at runtime, which is suitable for workstation

.EXAMPLE
    .\rename-devices-from-csv.ps1 -CsvContent $csvContent -DryRun "true"
    Validates devices and proposed names without sending a rename action

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - CSV must contain the columns DeviceName (current Intune device name) and NewName
    - Windows computer names: max 15 characters, letters/digits/hyphens, not all digits
    - The rename applies at next device check-in; a restart completes it on Windows
    - setDeviceName requires the DeviceManagementManagedDevices.PrivilegedOperations.All scope
    - Uses beta Graph endpoints because the setDeviceName action is exposed there for all platforms
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to CSV file with DeviceName,NewName columns")]
    [string]$CsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "CSV text with DeviceName,NewName columns, suitable for workstation")]
    [string]$CsvContent = "",

    [Parameter(Mandatory = $false, HelpMessage = "Export results to CSV")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ExportToCsv,

    [Parameter(Mandatory = $false, HelpMessage = "Validate proposed renames without sending an action")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$DryRun,

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

$SolutionName = 'rename-devices-from-csv'
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
foreach ($runbookBooleanParameter in @('ExportToCsv', 'DryRun')) {
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
            "DeviceManagementManagedDevices.PrivilegedOperations.All",
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

function Test-ValidComputerName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    if ($Name.Length -gt 15) { return $false }
    if ($Name -match '^[0-9]+$') { return $false }
    if ($Name -notmatch '^[A-Za-z0-9-]+$') { return $false }
    if ($Name.StartsWith("-") -or $Name.EndsWith("-")) { return $false }
    return $true
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode 'run' -Type 'General'
    Write-Banner
    $csvInputs = @(
        if (-not [string]::IsNullOrWhiteSpace($CsvPath)) { 'CsvPath' }
        if (-not [string]::IsNullOrWhiteSpace($CsvContent)) { 'CsvContent' }
    )
    if ($csvInputs.Count -ne 1) {
        throw "Specify exactly one CSV input: CsvPath or CsvContent."
    }

    if (-not [string]::IsNullOrWhiteSpace($CsvContent)) {
        $renameEntries = @($CsvContent | ConvertFrom-Csv -ErrorAction Stop)
        $csvSourceDescription = "runtime CSV content"
    }
    else {
        if (-not (Test-Path $CsvPath)) {
            throw "CSV file '$CsvPath' does not exist"
        }
        $renameEntries = @(Import-Csv -Path $CsvPath -ErrorAction Stop)
        $csvSourceDescription = $CsvPath
    }
    if ($renameEntries.Count -eq 0) {
        throw "CSV input contains no rows"
    }

    $csvColumns = $renameEntries[0].PSObject.Properties.Name
    if ($csvColumns -notcontains "DeviceName" -or $csvColumns -notcontains "NewName") {
        throw "CSV must contain the columns 'DeviceName' and 'NewName' (found: $($csvColumns -join ', '))"
    }

    Write-Output "✓ Loaded $($renameEntries.Count) rename entries from $csvSourceDescription"

    [System.Collections.Generic.List[Object]]$report = @()
    $renamed = 0
    $failed = 0
    $skipped = 0

    foreach ($entry in $renameEntries) {
        $currentName = $entry.DeviceName.Trim()
        $newName = $entry.NewName.Trim()

        # Validate before touching Graph so one bad row cannot burn an action
        if (-not (Test-ValidComputerName -Name $newName)) {
            Write-Warning "Skipping '$currentName': new name '$newName' is not a valid computer name (max 15 chars, letters/digits/hyphens, not all digits)"
            $report.Add([PSCustomObject]@{ DeviceName = $currentName; NewName = $newName; Result = "InvalidName" })
            $skipped++
            continue
        }

        $escapedName = $currentName -replace "'", "''"
        $found = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$escapedName'&`$select=id,deviceName,operatingSystem"

        if (@($found).Count -eq 0) {
            Write-Warning "Skipping '$currentName': device not found in Intune"
            $report.Add([PSCustomObject]@{ DeviceName = $currentName; NewName = $newName; Result = "NotFound" })
            $skipped++
            continue
        }
        if (@($found).Count -gt 1) {
            Write-Warning "Skipping '$currentName': $(@($found).Count) devices share this name - rename manually to avoid hitting the wrong one"
            $report.Add([PSCustomObject]@{ DeviceName = $currentName; NewName = $newName; Result = "AmbiguousName" })
            $skipped++
            continue
        }

        $device = @($found)[0]

        if ($DryRun) {
            Write-Output "[DRY RUN] Would rename '$currentName' to '$newName'"
            $report.Add([PSCustomObject]@{ DeviceName = $currentName; NewName = $newName; Result = "DryRun" })
            continue
        }

        if ($PSCmdlet.ShouldProcess("$currentName -> $newName", "Send setDeviceName action")) {
            try {
                $body = @{ deviceName = $newName } | ConvertTo-Json
                Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/setDeviceName" -Method POST -Body $body -ContentType "application/json"
                Write-Output "✓ Rename queued: $currentName -> $newName"
                $report.Add([PSCustomObject]@{ DeviceName = $currentName; NewName = $newName; Result = "Queued" })
                $renamed++
            }
            catch {
                Write-Warning "Failed to rename '$currentName': $($_.Exception.Message)"
                $report.Add([PSCustomObject]@{ DeviceName = $currentName; NewName = $newName; Result = "Failed" })
                $failed++
            }
        }
        else {
            $report.Add([PSCustomObject]@{ DeviceName = $currentName; NewName = $newName; Result = "WhatIf" })
        }
    }

    # Summary
    Write-Output "`n========================================"
    Write-Output "Rename Summary"
    Write-Output "========================================"
    Write-Output "CSV entries:     $($renameEntries.Count)"
    Write-Output "Renames queued:  $renamed"
    Write-Output "Failed:          $failed"
    Write-Output "Skipped:         $skipped"
    Write-Output "Note: renames apply at next device check-in; Windows devices need a restart to complete"
    Write-Output "========================================"

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvOutPath = Join-Path $OutputPath "Device_Rename_Results_$timestamp.csv"
        $report | Export-Csv -Path $csvOutPath -NoTypeInformation -Encoding UTF8
        Write-Output "CSV report saved: $csvOutPath"
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
