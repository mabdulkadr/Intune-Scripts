<#
.TITLE
    Get Defender Status Report

.SYNOPSIS
    Reports Microsoft Defender health across all Windows devices: protection state, signature age, and devices needing attention.

.DESCRIPTION
    This script reads the tenant-wide device protection overview and the per-device
    Windows protection state to report Microsoft Defender health: real-time
    protection, tamper protection, malware protection, signature currency, overdue
    scans, pending reboots, and devices whose state is not clean. Use it to find the
    machines on which Defender is silently off or outdated before they become incident
    tickets.

    Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency.

.TAGS
    Security,Monitoring

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.2.1

.CHANGELOG
    1.2.1 (2026-08-26)
    - Migrated to Enterprise Admin standards
    1.2 - Added workstation boolean handling with typed validation, beta Graph endpoints, and terminating paging errors
    1.1 - Workstation logging now records progress and summaries
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-defender-status-report.ps1
    Reports Defender health for all Windows devices

.EXAMPLE
    .\get-defender-status-report.ps1 -OnlyIssues "true"
    Lists only devices with at least one Defender health issue

.EXAMPLE
    .\get-defender-status-report.ps1 -ExportToCsv "true"
    Exports the full per-device Defender state to a timestamped CSV

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Protection state is fetched per device (one request each); large tenants take a few minutes
    - Devices that never reported protection state are listed separately
    - Uses beta Graph endpoints because windowsProtectionState is exposed there
    - Interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows; app-only via -TenantId/-ClientId/-ClientSecret or -CertificateThumbprint
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Show only devices with Defender issues")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$OnlyIssues,

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
foreach ($runbookBooleanParameter in @('OnlyIssues', 'ExportToCsv')) {
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

$SolutionName = 'get-defender-status-report'
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


function Get-DefenderIssue {
    param([object]$ProtectionState)

    $issues = [System.Collections.Generic.List[string]]::new()

    if ($ProtectionState.malwareProtectionEnabled -ne $true) { $issues.Add("Malware protection disabled") }
    if ($ProtectionState.realTimeProtectionEnabled -ne $true) { $issues.Add("Real-time protection disabled") }
    if ($ProtectionState.tamperProtectionEnabled -ne $true) { $issues.Add("Tamper protection disabled") }
    if ($ProtectionState.signatureUpdateOverdue -eq $true) { $issues.Add("Signature update overdue") }
    if ($ProtectionState.quickScanOverdue -eq $true) { $issues.Add("Quick scan overdue") }
    if ($ProtectionState.fullScanOverdue -eq $true) { $issues.Add("Full scan overdue") }
    if ($ProtectionState.rebootRequired -eq $true) { $issues.Add("Reboot required") }
    if ($ProtectionState.deviceState -and $ProtectionState.deviceState -ne "clean") { $issues.Add("Device state: $($ProtectionState.deviceState)") }

    return @($issues)
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    # Tenant-wide overview first - cheap and gives immediate context
    Write-Output "Retrieving tenant protection overview..."
    $overview = $null
    try {
        $overview = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceProtectionOverview" -Method GET
    }
    catch {
        Write-Warning "Could not read the device protection overview: $($_.Exception.Message)"
    }

    Write-Output "Retrieving Windows devices..."
    $windowsDevices = Get-MgGraphAllPage -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,deviceName,userPrincipalName,lastSyncDateTime"
    Write-Output "✓ Found $(@($windowsDevices).Count) Windows devices - fetching protection state per device..."

    [System.Collections.Generic.List[Object]]$report = @()
    $noStateCount = 0
    $processedCount = 0

    foreach ($device in $windowsDevices) {
        $processedCount++
        if ($processedCount % 50 -eq 0) {
            Write-Output "  Processed $processedCount of $(@($windowsDevices).Count)..."
        }

        $protectionState = $null
        try {
            Start-Sleep -Milliseconds 100
            $protectionState = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/windowsProtectionState" -Method GET
        }
        catch {
            if ($_.Exception.Message -like "*429*") {
                Write-Output "Rate limit hit, waiting 60 seconds..."
                Start-Sleep -Seconds 60
                try {
                    $protectionState = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/windowsProtectionState" -Method GET
                }
                catch {
                    Write-Verbose "No protection state for '$($device.deviceName)': $($_.Exception.Message)"
                }
            }
            else {
                Write-Verbose "No protection state for '$($device.deviceName)': $($_.Exception.Message)"
            }
        }

        if (-not $protectionState -or -not $protectionState.lastReportedDateTime) {
            $noStateCount++
            $report.Add([PSCustomObject]@{
                    DeviceName         = $device.deviceName
                    User               = $device.userPrincipalName
                    DeviceState        = "NotReported"
                    RealTimeProtection = ""
                    TamperProtection   = ""
                    SignatureVersion   = ""
                    SignatureOverdue   = ""
                    LastReported       = ""
                    Issues             = "No Defender state reported"
                    IssueCount         = 1
                })
            continue
        }

        $issues = Get-DefenderIssue -ProtectionState $protectionState
        $lastReported = if ($protectionState.lastReportedDateTime) { [DateTime]::Parse($protectionState.lastReportedDateTime.ToString()) } else { $null }

        $report.Add([PSCustomObject]@{
                DeviceName         = $device.deviceName
                User               = $device.userPrincipalName
                DeviceState        = $protectionState.deviceState
                RealTimeProtection = $protectionState.realTimeProtectionEnabled
                TamperProtection   = $protectionState.tamperProtectionEnabled
                SignatureVersion   = $protectionState.signatureVersion
                SignatureOverdue   = $protectionState.signatureUpdateOverdue
                LastReported       = if ($lastReported) { $lastReported.ToString("yyyy-MM-dd HH:mm") } else { "" }
                Issues             = ($issues -join "; ")
                IssueCount         = $issues.Count
            })
    }

    # ----- Display results -----
    Write-Output "`nDEFENDER STATUS REPORT"
    Write-Output ("=" * 50)
    Write-Output "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    if ($overview) {
        Write-Output "`nTenant overview:"
        Write-Output "  Reporting devices:        $($overview.totalReportedDeviceCount)"
        Write-Output "  Clean:                    $($overview.cleanDeviceCount)"
        Write-Output "  Critical failures:        $($overview.criticalFailuresDeviceCount)"
        Write-Output "  Pending signature update: $($overview.pendingSignatureUpdateDeviceCount)"
        Write-Output "  Pending restart:          $($overview.pendingRestartDeviceCount)"
        Write-Output "  Inactive agent:           $($overview.inactiveThreatAgentDeviceCount)"
    }

    $devicesWithIssues = @($report | Where-Object { $_.IssueCount -gt 0 })
    $healthyDevices = @($report | Where-Object { $_.IssueCount -eq 0 })

    if ($devicesWithIssues.Count -gt 0) {
        Write-Output "`nDevices with issues ($($devicesWithIssues.Count)):"
        foreach ($row in ($devicesWithIssues | Sort-Object IssueCount -Descending)) {
            Write-Output "  $($row.DeviceName) | $($row.User)"
            Write-Output "    $($row.Issues)"
        }
    }

    if (-not $OnlyIssues -and $healthyDevices.Count -gt 0) {
        Write-Output "`nHealthy devices ($($healthyDevices.Count)):"
        foreach ($row in ($healthyDevices | Sort-Object DeviceName)) {
            Write-Output "  $($row.DeviceName) | signatures $($row.SignatureVersion) | reported $($row.LastReported)"
        }
    }

    # Summary
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($report.Count) Windows devices | $($healthyDevices.Count) healthy | $($devicesWithIssues.Count) with issues | $noStateCount never reported"
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Defender_Status_$timestamp.csv"
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
