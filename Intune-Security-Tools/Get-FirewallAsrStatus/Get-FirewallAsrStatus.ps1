<#
.TITLE
    Get Firewall and ASR Status

.SYNOPSIS
    Reports endpoint security policy coverage for firewall, attack surface reduction, and antivirus across the tenant.

.DESCRIPTION
    This script inventories all endpoint security policies (settings catalog policies
    with an endpoint security template plus legacy security intents) and reports the
    coverage per discipline: firewall, attack surface reduction, antivirus, disk
    encryption, EDR, and account protection. It flags disciplines with no assigned
    policy and lists unassigned endpoint security policies. Combined with the device
    count this shows whether the tenant's Windows fleet actually has firewall and ASR
    enforcement or just unassigned policy objects.

    Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency.

.TAGS
    Security,Monitoring

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.Read.All

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
    .\get-firewall-and-asr-status.ps1
    Shows endpoint security policy coverage per discipline

.EXAMPLE
    .\get-firewall-and-asr-status.ps1 -ExportToCsv "true"
    Exports the coverage report to a timestamped CSV file

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Endpoint security policies are settings catalog policies whose templateReference.templateFamily starts with endpointSecurity; template family filtering happens client-side because the server-side filter is unreliable on this surface
    - Legacy endpoint security intents (deviceManagement/intents) are included for older tenants
    - Coverage means at least one assigned policy per discipline; per-device applicability is not evaluated
    - Uses beta Graph endpoints because settings catalog templates and intents are exposed there
    - Interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows; app-only via -TenantId/-ClientId/-ClientSecret or -CertificateThumbprint
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
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

$SolutionName = 'get-firewall-and-asr-status'
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
            "DeviceManagementConfiguration.Read.All",
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


function Get-DisciplineLabel {
    param([string]$TemplateFamily)

    switch -Wildcard ($TemplateFamily) {
        "*Firewall*" { "Firewall" }
        "*AttackSurfaceReduction*" { "Attack Surface Reduction" }
        "*Antivirus*" { "Antivirus" }
        "*DiskEncryption*" { "Disk Encryption" }
        "*EndpointDetectionAndResponse*" { "EDR" }
        "*AccountProtection*" { "Account Protection" }
        "*EndpointPrivilegeManagement*" { "Endpoint Privilege Management" }
        "*ApplicationControl*" { "App Control" }
        default { $TemplateFamily }
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    Write-Output "Retrieving settings catalog policies..."
    $allPolicies = Get-MgGraphAllPage -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$expand=assignments"

    # Server-side templateFamily filters behave inconsistently, so filter locally
    $securityPolicies = @($allPolicies | Where-Object {
            $_.templateReference -and $_.templateReference.templateFamily -like "endpointSecurity*"
        })
    Write-Output "✓ Found $($securityPolicies.Count) endpoint security policies (of $(@($allPolicies).Count) settings catalog policies)"

    Write-Output "Retrieving legacy security intents..."
    $intents = @()
    try {
        $intents = @(Get-MgGraphAllPage -Uri "https://graph.microsoft.com/beta/deviceManagement/intents?`$select=id,displayName,templateId,isAssigned")
        Write-Output "✓ Found $($intents.Count) legacy intents"
    }
    catch {
        Write-Warning "Could not read legacy intents: $($_.Exception.Message)"
    }

    Write-Output "Counting Windows devices..."
    $windowsDevices = Get-MgGraphAllPage -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id"
    $windowsDeviceCount = @($windowsDevices).Count
    Write-Output "✓ $windowsDeviceCount Windows devices enrolled"

    # ----- Build per-policy rows -----
    [System.Collections.Generic.List[Object]]$report = @()

    foreach ($policy in $securityPolicies) {
        $discipline = Get-DisciplineLabel -TemplateFamily $policy.templateReference.templateFamily
        $report.Add([PSCustomObject]@{
                PolicyName   = $policy.name
                Discipline   = $discipline
                Source       = "Settings Catalog"
                Template     = $policy.templateReference.templateDisplayName
                Platforms    = $policy.platforms
                IsAssigned   = (@($policy.assignments).Count -gt 0)
                Assignments  = @($policy.assignments).Count
                PolicyId     = $policy.id
            })
    }

    foreach ($intent in $intents) {
        $report.Add([PSCustomObject]@{
                PolicyName   = $intent.displayName
                Discipline   = "Legacy Intent"
                Source       = "Intent (legacy)"
                Template     = $intent.templateId
                Platforms    = ""
                IsAssigned   = [bool]$intent.isAssigned
                Assignments  = ""
                PolicyId     = $intent.id
            })
    }

    # ----- Display results -----
    Write-Output "`nFIREWALL AND ASR STATUS"
    Write-Output ("=" * 50)
    Write-Output "Windows devices enrolled: $windowsDeviceCount | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    # Coverage per core discipline
    $coreDisciplines = @("Firewall", "Attack Surface Reduction", "Antivirus", "Disk Encryption", "EDR", "Account Protection")
    Write-Output "`nCoverage per discipline:"
    [System.Collections.Generic.List[string]]$gaps = @()

    foreach ($discipline in $coreDisciplines) {
        $disciplinePolicies = @($report | Where-Object { $_.Discipline -eq $discipline })
        $assigned = @($disciplinePolicies | Where-Object { $_.IsAssigned })

        if ($assigned.Count -gt 0) {
            Write-Output "  [COVERED] $($discipline): $($assigned.Count) assigned policy/policies"
        }
        elseif ($disciplinePolicies.Count -gt 0) {
            Write-Output "  [GAP] $($discipline): $($disciplinePolicies.Count) policy/policies exist but none is assigned"
            $gaps.Add($discipline)
        }
        else {
            Write-Output "  [GAP] $($discipline): no policy exists"
            $gaps.Add($discipline)
        }
    }

    # Policy details
    if ($report.Count -gt 0) {
        Write-Output "`nAll endpoint security policies:"
        foreach ($disciplineGroup in ($report | Group-Object -Property Discipline | Sort-Object Name)) {
            Write-Output "`n  $($disciplineGroup.Name):"
            foreach ($row in ($disciplineGroup.Group | Sort-Object PolicyName)) {
                $assignedLabel = if ($row.IsAssigned) { "assigned" } else { "NOT ASSIGNED" }
                Write-Output "    $($row.PolicyName) [$assignedLabel] ($($row.Source))"
            }
        }
    }

    # Summary
    $unassignedCount = @($report | Where-Object { -not $_.IsAssigned }).Count
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($report.Count) endpoint security policies | $unassignedCount unassigned | gaps: $(if ($gaps.Count -gt 0) { $gaps -join ', ' } else { 'none' })"
    if ($gaps -contains "Firewall" -or $gaps -contains "Attack Surface Reduction") {
        Write-Warning "Firewall or ASR has no assigned policy - $windowsDeviceCount Windows devices are running on local defaults"
    }
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Endpoint_Security_Coverage_$timestamp.csv"
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
