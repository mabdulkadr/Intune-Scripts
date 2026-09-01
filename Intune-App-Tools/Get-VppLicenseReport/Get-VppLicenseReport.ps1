<#
.TITLE
    Get VPP License Report

.SYNOPSIS
    Reports Apple VPP app license utilization and flags apps and tokens that are close to exhaustion or expiry.

.DESCRIPTION
    This script reads all Apple Volume Purchase Program tokens and VPP apps (iOS and
    macOS) from Intune and reports used versus total licenses per app, highlighting
    apps above a configurable utilization threshold. VPP token state and expiration
    are included because an expired token silently breaks app installs. Use it to
    buy licenses before users hit "installation failed" and to catch tokens that
    need renewal.

    Supports workstation dual-mode: interactive sign-in (auto-installs Microsoft.Graph.Authentication if missing; WAM-free via MgGraphCommunity when available) and optional app-only authentication via -TenantId/-ClientId with -ClientSecret or -CertificateThumbprint.

.TAGS
    Apps,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementApps.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.2.1

.CHANGELOG
    1.2.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.2 - Added contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.1 -     1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-vpp-license-report.ps1
    Reports all VPP apps with their license utilization

.EXAMPLE
    .\get-vpp-license-report.ps1 -WarningThresholdPercent 80
    Flags apps that have used 80 percent or more of their licenses

.EXAMPLE
    .\get-vpp-license-report.ps1 -ExportToCsv "true"
    Exports the license report to a timestamped CSV file

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Tenants without Apple VPP (Apps and Books) configured will report no tokens and no apps
    - License counts come from the iosVppApp and macOsVppApp usedLicenseCount / totalLicenseCount properties
    - Uses beta Graph endpoints because VPP app license properties are exposed there
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Utilization percentage above which an app is flagged")]
    [ValidateRange(1, 100)]
    [int]$WarningThresholdPercent = 90,

    [Parameter(Mandatory = $false, HelpMessage = "Days before token expiry to flag a VPP token")]
    [ValidateRange(1, 365)]
    [int]$TokenExpiryWarningDays = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Export results to CSV")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ExportToCsv,

    [Parameter(Mandatory = $false, HelpMessage = "Output path for exports")]
    [string]$OutputPath = "",

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall
)

# Resolve OutputPath beside the script when caller passes "." or empty (Law 12).
$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
if (-not $OutputPath -or $OutputPath -eq ".") {
    $OutputPath = $scriptDirectory
} elseif ($PSBoundParameters.ContainsKey('OutputPath') -and $OutputPath -and -not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptDirectory $OutputPath
}

$ErrorActionPreference = 'Stop'

# Normalize the local module-install override for string parameter binding.
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

# String parameter values are normalized to booleans.

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

# ============================================================================
# MAIN FLOW INITIALIZATION - structured logging starts before any tenant work.
# Flow: init log -> banner -> module setup -> Graph auth -> main logic.
# ============================================================================

$SolutionName = 'get-vpp-license-report'
$ScriptMode   = 'run'

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
            catch [System.Exception] {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }

        Import-Module -Name $ModuleName -Force -ErrorAction Stop
    }
}

# Detect execution environment

# Initialize required modules
$RequiredModules = @("Microsoft.Graph.Authentication")

# MgGraphCommunity provides WAM-free interactive sign-in for workstation scenarios
$RequiredModules += "MgGraphCommunity"

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "✓ All required modules are available"
}
catch [System.Exception] {
    Write-Error "Module initialization failed: $_"
    exit 1
}

# ============================================================================
# AUTHENTICATION
# ============================================================================

try {
    $scopes = @(
            "DeviceManagementApps.Read.All"
        )

    if ($TenantId -and $ClientId -and ($ClientSecret -or $CertificateThumbprint)) {
        Write-Output "Connecting to Microsoft Graph with app-only authentication..."
        if ($CertificateThumbprint) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        else {
            $secureSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $secureSecret
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecretCredential $credential -NoWelcome -ErrorAction Stop
        }
        Write-Output "✓ Successfully connected to Microsoft Graph (app-only)"
    }
    else {
        Write-Output "Connecting to Microsoft Graph..."
        if (Get-Module -ListAvailable -Name MgGraphCommunity) {
            Connect-MgGraphCommunity -Scopes $scopes -NoWelcome -ErrorAction Stop
        }
        else {
            Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
        }
        Write-Output "✓ Successfully connected to Microsoft Graph"
    }
}
catch [System.Exception] {
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

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    # ----- VPP tokens -----
    Write-Output "Retrieving VPP tokens..."
    $tokens = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/vppTokens"
    Write-Output "✓ Found $(@($tokens).Count) VPP token(s)"

    # ----- VPP apps (iOS and macOS) -----
    Write-Output "Retrieving VPP apps..."
    $iosVppApps = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.iosVppApp')"
    $macVppApps = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.macOsVppApp')"
    $vppApps = @($iosVppApps) + @($macVppApps)
    Write-Output "✓ Found $(@($vppApps).Count) VPP app(s)"

    if (@($tokens).Count -eq 0 -and @($vppApps).Count -eq 0) {
        Write-Output "`nNo Apple VPP tokens or apps found - is Apple Apps and Books configured for this tenant?"
        return
    }

    [System.Collections.Generic.List[Object]]$report = @()
    foreach ($app in $vppApps) {
        $total = [int]$app.totalLicenseCount
        $used = [int]$app.usedLicenseCount
        $utilization = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 1) } else { 0 }

        $status = if ($total -eq 0) { "NoLicenses" }
        elseif ($utilization -ge 100) { "Exhausted" }
        elseif ($utilization -ge $WarningThresholdPercent) { "NearLimit" }
        else { "OK" }

        $platform = if ($app.'@odata.type' -like "*macOsVppApp") { "macOS" } else { "iOS" }

        $report.Add([PSCustomObject]@{
                AppName       = $app.displayName
                Platform      = $platform
                TokenAppleId  = $app.vppTokenAppleId
                UsedLicenses  = $used
                TotalLicenses = $total
                UtilizationPct = $utilization
                Status        = $status
                AppId         = $app.id
            })
    }

    # ----- Display results -----
    Write-Output "`nVPP LICENSE REPORT"
    Write-Output ("=" * 50)
    Write-Output "Warning threshold: $WarningThresholdPercent% | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    # Token health first - expired tokens break everything downstream
    if (@($tokens).Count -gt 0) {
        Write-Output "`nVPP tokens:"
        foreach ($token in $tokens) {
            $expiry = if ($token.expirationDateTime) { [DateTime]::Parse($token.expirationDateTime.ToString()) } else { $null }
            $daysLeft = if ($expiry) { [math]::Round(($expiry - (Get-Date)).TotalDays, 0) } else { $null }

            $tokenLine = "  $($token.appleId) | state: $($token.state)"
            if ($null -ne $daysLeft) {
                $tokenLine += " | expires in $daysLeft days"
            }
            Write-Output $tokenLine

            if ($token.state -ne "valid") {
                Write-Warning "  Token '$($token.appleId)' state is '$($token.state)' - VPP app installs may be failing"
            }
            elseif ($null -ne $daysLeft -and $daysLeft -le $TokenExpiryWarningDays) {
                Write-Warning "  Token '$($token.appleId)' expires in $daysLeft days - renew it in Apple Business Manager"
            }
        }
    }

    if ($report.Count -gt 0) {
        foreach ($statusGroup in ($report | Group-Object -Property Status | Sort-Object Name)) {
            Write-Output "`n[$($statusGroup.Name)] $($statusGroup.Count) app(s)"
            foreach ($row in ($statusGroup.Group | Sort-Object UtilizationPct -Descending)) {
                Write-Output "  $($row.AppName) ($($row.Platform)): $($row.UsedLicenses)/$($row.TotalLicenses) licenses ($($row.UtilizationPct)%)"
            }
        }
    }

    # Summary
    $flagged = @($report | Where-Object { $_.Status -in @("NearLimit", "Exhausted") })
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($report.Count) VPP apps, $($flagged.Count) at or above $WarningThresholdPercent% utilization"
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "VPP_License_Report_$timestamp.csv"
        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Output "✓ CSV report saved: $csvPath"
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
