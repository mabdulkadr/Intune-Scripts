<#
.TITLE
    Get Windows LAPS Audit

.SYNOPSIS
    Audits Windows LAPS password escrow: which devices have a backed-up local admin password and how old it is.

.DESCRIPTION
    This script lists all device local credential records escrowed by Windows LAPS in
    Entra ID and cross-references them with Intune Windows devices. It reports which
    devices have no escrowed local administrator password at all, and which have
    passwords older than the rotation threshold - both signs that the LAPS policy is
    not applying. Only credential metadata (device name, backup time) is read; actual
    passwords are never retrieved by this script.

    Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency.

.TAGS
    Security,Compliance

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceLocalCredential.ReadBasic.All,DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.3.1

.CHANGELOG
    1.3.1 (2026-08-26)
    - Migrated to Enterprise Admin standards
    1.3 - Correctly treat an empty device-local-credentials response as an empty collection
    1.2 - Added workstation boolean handling with typed validation, beta Graph endpoints, and terminating paging errors
    1.1 - Workstation logging now records progress and summaries
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-windows-laps-audit.ps1
    Audits LAPS escrow state for all Windows devices with a 60-day age threshold

.EXAMPLE
    .\get-windows-laps-audit.ps1 -MaxPasswordAgeDays 30 -ExportToCsv "true"
    Flags passwords older than 30 days and exports the audit to CSV

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Reading LAPS credential metadata is limited to specific roles; Intune Administrator is one of the allowed roles
    - This script uses DeviceLocalCredential.ReadBasic.All and never retrieves password values
    - Devices are matched between the LAPS store and Intune via the Entra device ID
    - Uses beta Graph endpoints for the device local credentials surface
    - Interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows; app-only via -TenantId/-ClientId/-ClientSecret or -CertificateThumbprint
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Password age in days above which escrow is flagged as stale")]
    [ValidateRange(1, 365)]
    [int]$MaxPasswordAgeDays = 60,

    [Parameter(Mandatory = $false, HelpMessage = "Export results to CSV")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ExportToCsv,

    [Parameter(Mandatory = $false, HelpMessage = "Output path for exports")]
    [string]$OutputPath = "",

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Entra tenant ID for app-only authentication")]
    [string]$TenantId = "",

    [Parameter(Mandatory = $false, HelpMessage = "Application (client) ID for app-only authentication")]
    [string]$ClientId = "",

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret = "",

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication (alternative to client secret)")]
    [string]$CertificateThumbprint = "")

# Resolve OutputPath beside the script when caller passes "" or "." (Law 12).
$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
if (-not $OutputPath -or $OutputPath -eq ".") {
    $OutputPath = $scriptDirectory
} elseif ($PSBoundParameters.ContainsKey('OutputPath') -and $OutputPath -and -not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptDirectory $OutputPath
}

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
foreach ($runbookBooleanParameter in @('ExportToCsv')) {
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

$SolutionName = 'get-windows-laps-audit'
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
            "DeviceLocalCredential.ReadBasic.All",
            "DeviceManagementManagedDevices.Read.All"
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

function Get-MgGraphAllPage {
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

Set-Alias -Name Get-MgGraphAllPages -Value Get-MgGraphAllPage -Scope Global


# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    Write-Output "Retrieving Windows LAPS credential records..."
    $lapsRecords = Get-MgGraphAllPage -Uri "https://graph.microsoft.com/beta/directory/deviceLocalCredentials?`$select=id,deviceName,lastBackupDateTime"
    Write-Output "✓ Found $(@($lapsRecords).Count) escrowed LAPS records"

    Write-Output "Retrieving Intune Windows devices..."
    $windowsDevices = Get-MgGraphAllPage -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,deviceName,azureADDeviceId,lastSyncDateTime,userPrincipalName"
    Write-Output "✓ Found $(@($windowsDevices).Count) Windows devices"

    # LAPS record id is the Entra device ID; index for the cross-reference
    $lapsByDeviceId = @{}
    foreach ($record in $lapsRecords) {
        $lapsByDeviceId[$record.id] = $record
    }

    $now = Get-Date
    [System.Collections.Generic.List[Object]]$report = @()

    foreach ($device in $windowsDevices) {
        $lapsRecord = if ($device.azureADDeviceId -and $lapsByDeviceId.ContainsKey($device.azureADDeviceId)) {
            $lapsByDeviceId[$device.azureADDeviceId]
        }
        else {
            $null
        }

        $lastBackup = if ($lapsRecord -and $lapsRecord.lastBackupDateTime) {
            [DateTime]::Parse($lapsRecord.lastBackupDateTime.ToString())
        }
        else {
            $null
        }

        $ageDays = if ($lastBackup) { [math]::Round(($now - $lastBackup).TotalDays, 1) } else { $null }

        $status = if (-not $lapsRecord) { "NotEscrowed" }
        elseif ($null -eq $ageDays) { "EscrowedNoTimestamp" }
        elseif ($ageDays -gt $MaxPasswordAgeDays) { "Stale" }
        else { "Healthy" }

        $report.Add([PSCustomObject]@{
                DeviceName     = $device.deviceName
                User           = $device.userPrincipalName
                EntraDeviceId  = $device.azureADDeviceId
                LastBackup     = if ($lastBackup) { $lastBackup.ToString("yyyy-MM-dd HH:mm") } else { "" }
                PasswordAgeDays = $ageDays
                Status         = $status
            })
    }

    # ----- Display results -----
    Write-Output "`nWINDOWS LAPS AUDIT"
    Write-Output ("=" * 50)
    Write-Output "Stale threshold: $MaxPasswordAgeDays days | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    $statusOrder = @("NotEscrowed", "Stale", "EscrowedNoTimestamp", "Healthy")
    foreach ($statusName in $statusOrder) {
        $statusDevices = @($report | Where-Object { $_.Status -eq $statusName })
        if ($statusDevices.Count -eq 0) { continue }

        Write-Output "`n[$statusName] $($statusDevices.Count) device(s)"

        if ($statusName -ne "Healthy") {
            foreach ($row in ($statusDevices | Sort-Object DeviceName)) {
                $line = "  $($row.DeviceName) | $($row.User)"
                if ($row.LastBackup) { $line += " | last backup: $($row.LastBackup) ($($row.PasswordAgeDays) days)" }
                Write-Output $line
            }
        }
    }

    if (@($report | Where-Object { $_.Status -eq "NotEscrowed" }).Count -gt 0) {
        Write-Output "`nDevices without escrow either have no Windows LAPS policy assigned or have not rotated since policy assignment."
    }

    # Summary
    $escrowedCount = @($report | Where-Object { $_.Status -ne "NotEscrowed" }).Count
    $staleCount = @($report | Where-Object { $_.Status -eq "Stale" }).Count
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $(@($windowsDevices).Count) Windows devices | $escrowedCount escrowed | $staleCount stale | $(@($windowsDevices).Count - $escrowedCount) not escrowed"
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Windows_LAPS_Audit_$timestamp.csv"
        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Output "✓ CSV report saved: $csvPath"
        Write-Log -Message "CSV report saved: $csvPath" -Level 'INFO'
    }
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
