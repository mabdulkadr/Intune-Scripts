<#
.TITLE
    Cleanup Orphaned Apps

.SYNOPSIS
    Finds Intune apps that have no assignments or are superseded by newer versions, and optionally deletes them.

.DESCRIPTION
    This script scans the Intune app catalog for cleanup candidates: apps with no
    assignments at all, and Win32 apps that a newer app supersedes. Old installer
    versions and abandoned test apps accumulate quickly and clutter the catalog. By
    default the script only reports; deletion requires the -Remove switch, supports
    -WhatIf preview, and prompts per app. Deleting an app from Intune does not
    uninstall it from devices that already have it.

    Supports workstation dual-mode: interactive sign-in (auto-installs Microsoft.Graph.Authentication if missing; WAM-free via MgGraphCommunity when available) and optional app-only authentication via -TenantId/-ClientId with -ClientSecret or -CertificateThumbprint.

.TAGS
    Apps,Operational

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementApps.ReadWrite.All

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
    .\cleanup-orphaned-apps.ps1
    Reports unassigned and superseded apps without deleting anything

.EXAMPLE
    .\cleanup-orphaned-apps.ps1 -OlderThanDays 90
    Only reports apps created more than 90 days ago

.EXAMPLE
    .\cleanup-orphaned-apps.ps1 -Remove "true" -WhatIf
    Shows exactly which apps would be deleted, without deleting them

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Superseded means another Win32 app declares a supersedence relationship to this app (supersedingAppCount > 0)
    - Deleting an app does not uninstall it from devices; it removes the deployment object
    - Recently created apps are excluded by default (-OlderThanDays 30) to avoid flagging work in progress
    - Uses beta Graph endpoints because supersedence counts are exposed there
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Only consider apps created more than this many days ago")]
    [ValidateRange(0, 3650)]
    [int]$OlderThanDays = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Delete the reported apps instead of only reporting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$Remove,

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

$SolutionName = 'cleanup-orphaned-apps'
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
            "DeviceManagementApps.ReadWrite.All"
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
    Write-Output "Retrieving app catalog with assignments..."
    $apps = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$expand=assignments"
    Write-Output "✓ Found $(@($apps).Count) apps"

    $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
    [System.Collections.Generic.List[Object]]$report = @()
    $deleted = 0
    $deleteFailed = 0

    foreach ($app in $apps) {
        $created = if ($app.createdDateTime) { [DateTime]::Parse($app.createdDateTime.ToString()) } else { $null }

        # Recently created apps are probably still being set up
        if ($created -and $created -gt $cutoffDate) {
            continue
        }

        $isUnassigned = (@($app.assignments).Count -eq 0)
        $isSuperseded = ([int]$app.supersedingAppCount -gt 0)

        if (-not $isUnassigned -and -not $isSuperseded) {
            continue
        }

        $reason = if ($isUnassigned -and $isSuperseded) { "Unassigned + Superseded" }
        elseif ($isSuperseded) { "Superseded" }
        else { "Unassigned" }

        $appType = ([string]$app.'@odata.type') -replace "#microsoft.graph.", ""

        $action = "Reported"
        if ($Remove) {
            if ($PSCmdlet.ShouldProcess("$($app.displayName) ($appType, $reason)", "Delete Intune app")) {
                try {
                    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)" -Method DELETE
                    Write-Output "✓ Deleted: $($app.displayName)"
                    $action = "Deleted"
                    $deleted++
                }
                catch {
                    Write-Warning "Failed to delete '$($app.displayName)': $($_.Exception.Message)"
                    $action = "DeleteFailed"
                    $deleteFailed++
                }
            }
            else {
                $action = "Skipped"
            }
        }

        $report.Add([PSCustomObject]@{
                AppName    = $app.displayName
                AppType    = $appType
                Publisher  = $app.publisher
                Reason     = $reason
                Created    = if ($created) { $created.ToString("yyyy-MM-dd") } else { "" }
                Superseded = $isSuperseded
                AppId      = $app.id
                Action     = $action
            })
    }

    # ----- Display results -----
    Write-Output "`nORPHANED APP REPORT"
    Write-Output ("=" * 50)
    Write-Output "Age filter: created more than $OlderThanDays days ago"
    Write-Output "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    if ($report.Count -eq 0) {
        Write-Output "`nNo orphaned or superseded apps found."
    }
    else {
        foreach ($reasonGroup in ($report | Group-Object -Property Reason | Sort-Object Name)) {
            Write-Output "`n$($reasonGroup.Name) ($($reasonGroup.Count) apps)"
            foreach ($row in ($reasonGroup.Group | Sort-Object AppName)) {
                Write-Output "  $($row.AppName) [$($row.AppType)] created $($row.Created) - $($row.Action)"
            }
        }
    }

    # Summary
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($report.Count) cleanup candidates of $(@($apps).Count) total apps"
    if ($Remove) {
        Write-Output "Deleted: $deleted | Failed: $deleteFailed"
    }
    elseif ($report.Count -gt 0) {
        Write-Output "Run again with -Remove to delete (add -WhatIf for a dry run). Deleting does NOT uninstall from devices."
    }
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Orphaned_Apps_$timestamp.csv"
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
