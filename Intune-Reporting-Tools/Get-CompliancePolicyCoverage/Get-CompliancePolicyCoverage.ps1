<#
.TITLE
    Get Compliance Policy Coverage

.SYNOPSIS
    Finds device platforms in the tenant that no assigned compliance policy covers.

.DESCRIPTION
    This script compares the platforms of all enrolled Intune devices against the
    platforms targeted by assigned compliance policies. Platforms with enrolled
    devices but no assigned compliance policy are a real gap: those devices report
    as compliant by default (or fall to the built-in policy) and can slip through
    Conditional Access checks. The report also lists compliance policies that exist
    but are not assigned to anything, and the device count per platform so gaps can
    be prioritized.

    Supports interactive sign-in and unattended app-only via -TenantId/-ClientId.

.TAGS
    Security,Compliance

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
    1.2 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.1 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-compliance-policy-coverage.ps1
    Shows the platform coverage matrix and any gaps

.EXAMPLE
    .\get-compliance-policy-coverage.ps1 -ExportToCsv "true"
    Exports the coverage report to a timestamped CSV file

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Policy platform is derived from the policy's OData type (windows10CompliancePolicy targets Windows, etc.)
    - A platform counts as covered when at least one policy for it has at least one assignment; group scoping within the platform is not evaluated
    - Check the tenant's "Mark devices with no compliance policy assigned as" setting: if it is set to Compliant, uncovered platforms silently pass Conditional Access
    - Uses beta Graph endpoints for consistency with the rest of the library
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
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

    [Parameter(Mandatory = $false, HelpMessage = "Tenant ID for app-only authentication")]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "Client ID for app-only authentication")]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication")]
    [string]$CertificateThumbprint
)

# Resolve OutputPath beside the script when caller passes "." or empty (Law 12).
$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
if (-not $OutputPath -or $OutputPath -eq ".") {
    $OutputPath = $scriptDirectory
} elseif ($PSBoundParameters.ContainsKey('OutputPath') -and $OutputPath -and -not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptDirectory $OutputPath
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
foreach ($boolParamName in @('ExportToCsv')) {
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

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and logging.
# ============================================================================

$SolutionName = 'get-compliance-policy-coverage'
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

$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "MgGraphCommunity"
)

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
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
        Write-Log -Message "Connected to Microsoft Graph with client secret" -Level 'SUCCESS'
    }
    elseif ($TenantId -and $ClientId -and $CertificateThumbprint) {
        Write-Output "Connecting to Microsoft Graph with certificate..."
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        Write-Output "[OK] Successfully connected to Microsoft Graph"
        Write-Log -Message "Connected to Microsoft Graph with certificate" -Level 'SUCCESS'
    }
    else {
        Write-Output "Connecting to Microsoft Graph with interactive authentication..."
        $Scopes = @(
            "DeviceManagementConfiguration.Read.All",
            "DeviceManagementManagedDevices.Read.All"
        )
        if (Get-Command -Name Connect-MgGraphCommunity -ErrorAction SilentlyContinue) {
            Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        else {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        Write-Output "[OK] Successfully connected to Microsoft Graph"
        Write-Log -Message "Connected to Microsoft Graph with interactive authentication" -Level 'SUCCESS'
    }
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


function Get-PolicyPlatform {
    param([string]$ODataType)

    # Compliance policy types map 1:1 to platforms
    switch -Wildcard ($ODataType) {
        "*windows10CompliancePolicy" { "Windows" }
        "*windows81CompliancePolicy" { "Windows" }
        "*macOSCompliancePolicy" { "macOS" }
        "*iosCompliancePolicy" { "iOS/iPadOS" }
        "*androidCompliancePolicy" { "Android" }
        "*androidWorkProfileCompliancePolicy" { "Android" }
        "*androidDeviceOwnerCompliancePolicy" { "Android" }
        "*aospDeviceOwnerCompliancePolicy" { "Android" }
        "*linuxCompliancePolicy" { "Linux" }
        default { ($ODataType -replace "#microsoft.graph.", "") -replace "CompliancePolicy", "" }
    }
}

function Get-DevicePlatform {
    param([string]$OperatingSystem)

    switch -Wildcard ($OperatingSystem) {
        "Windows*" { "Windows" }
        "macOS*" { "macOS" }
        "iOS*" { "iOS/iPadOS" }
        "iPadOS*" { "iOS/iPadOS" }
        "Android*" { "Android" }
        "Linux*" { "Linux" }
        default { $OperatingSystem }
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    Write-Output "Retrieving compliance policies with assignments..."
    $policies = Get-MgGraphAllPage -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies?`$expand=assignments"
    Write-Output "✓ Found $(@($policies).Count) compliance policies"

    Write-Output "Retrieving managed devices..."
    $devices = Get-MgGraphAllPage -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,operatingSystem,complianceState"
    Write-Output "✓ Found $(@($devices).Count) managed devices"

    # Device counts per platform
    $devicePlatforms = @{}
    foreach ($device in $devices) {
        $platform = Get-DevicePlatform -OperatingSystem ([string]$device.operatingSystem)
        if (-not $devicePlatforms.ContainsKey($platform)) { $devicePlatforms[$platform] = 0 }
        $devicePlatforms[$platform]++
    }

    # Assigned policy counts per platform
    $platformPolicies = @{}
    [System.Collections.Generic.List[Object]]$unassignedPolicies = @()

    foreach ($policy in $policies) {
        $platform = Get-PolicyPlatform -ODataType ([string]$policy.'@odata.type')
        $isAssigned = (@($policy.assignments).Count -gt 0)

        if ($isAssigned) {
            if (-not $platformPolicies.ContainsKey($platform)) {
                $platformPolicies[$platform] = [System.Collections.Generic.List[string]]::new()
            }
            $platformPolicies[$platform].Add($policy.displayName)
        }
        else {
            $unassignedPolicies.Add([PSCustomObject]@{
                    PolicyName = $policy.displayName
                    Platform   = $platform
                })
        }
    }

    # Build coverage matrix
    [System.Collections.Generic.List[Object]]$report = @()
    foreach ($platform in ($devicePlatforms.Keys | Sort-Object)) {
        $assignedPolicyNames = if ($platformPolicies.ContainsKey($platform)) { @($platformPolicies[$platform]) } else { @() }
        $noncompliantCount = @($devices | Where-Object { (Get-DevicePlatform -OperatingSystem ([string]$_.operatingSystem)) -eq $platform -and $_.complianceState -eq "noncompliant" }).Count

        $report.Add([PSCustomObject]@{
                Platform           = $platform
                DeviceCount        = $devicePlatforms[$platform]
                NoncompliantCount  = $noncompliantCount
                AssignedPolicies   = $assignedPolicyNames.Count
                PolicyNames        = ($assignedPolicyNames -join "; ")
                CoverageStatus     = if ($assignedPolicyNames.Count -gt 0) { "Covered" } else { "NOT COVERED" }
            })
    }

    # ----- Display results -----
    Write-Output "`nCOMPLIANCE POLICY COVERAGE"
    Write-Output ("=" * 50)
    Write-Output "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    foreach ($row in $report) {
        Write-Output "`n[$($row.CoverageStatus)] $($row.Platform)"
        Write-Output "  Devices: $($row.DeviceCount) ($($row.NoncompliantCount) noncompliant)"
        if ($row.AssignedPolicies -gt 0) {
            Write-Output "  Assigned policies: $($row.PolicyNames)"
        }
        else {
            Write-Output "  No assigned compliance policy targets this platform"
        }
    }

    if ($unassignedPolicies.Count -gt 0) {
        Write-Output "`nUnassigned compliance policies:"
        foreach ($row in ($unassignedPolicies | Sort-Object Platform, PolicyName)) {
            Write-Output "  $($row.PolicyName) [$($row.Platform)]"
        }
    }

    # Summary
    $gapPlatforms = @($report | Where-Object { $_.CoverageStatus -eq "NOT COVERED" })
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($report.Count) platforms with devices, $($gapPlatforms.Count) without compliance coverage, $($unassignedPolicies.Count) unassigned policies"
    if ($gapPlatforms.Count -gt 0) {
        Write-Output "Gap platforms: $(($gapPlatforms | ForEach-Object { $_.Platform }) -join ', ')"
    }
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Compliance_Coverage_$timestamp.csv"
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
