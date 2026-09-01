<#
.TITLE
    Check Certificate Profile Expiry

.SYNOPSIS
    Audits SCEP, PKCS, and trusted root certificate profiles: validity settings, deployment errors, and root certificates nearing expiry.

.DESCRIPTION
    This script inventories all certificate-related configuration profiles (SCEP,
    PKCS, and trusted certificate profiles) across platforms, reports their validity
    period settings and assignment state, and pulls per-profile deployment status to
    surface devices in which certificate delivery is failing. For trusted certificate
    profiles it decodes the embedded root certificate and reports its actual expiry
    date, catching root or issuing CA certificates that will silently break SCEP
    enrollment when they lapse.

    Supports interactive sign-in and unattended app-only via -TenantId/-ClientId.

.TAGS
    Monitoring,Security

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All

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
    .\Test-CertificateProfileExpiry.ps1
    Audits all certificate profiles with a 90-day expiry warning window

.EXAMPLE
    .\Test-CertificateProfileExpiry.ps1 -ExpiryWarningDays 180 -ExportToCsv "true"
    Uses a 180-day warning window for embedded root certificates and exports to CSV

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Individual issued device certificates are not exposed via Graph; this script audits the profiles, their embedded CA certificates, and delivery status
    - Trusted certificate payloads are decoded locally to read the real certificate expiry
    - Uses beta Graph endpoints for the device configuration surface
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
    - Logs: %ProgramData%\check-certificate-profile-expiry\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Days before an embedded certificate expiry to raise a warning")]
    [ValidateRange(1, 730)]
    [int]$ExpiryWarningDays = 90,

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
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'check-certificate-profile-expiry'
$ScriptMode   = 'run'

$scriptBasePath = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path -Path $scriptBasePath -ChildPath $OutputPath
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
    }
    elseif ($TenantId -and $ClientId -and $CertificateThumbprint) {
        Write-Output "Connecting to Microsoft Graph with certificate..."
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        Write-Output "[OK] Successfully connected to Microsoft Graph"
    }
    else {
        Write-Output "Connecting to Microsoft Graph with interactive authentication..."
        $Scopes = @(
            "DeviceManagementConfiguration.Read.All"
        )
        if (Get-Command -Name Connect-MgGraphCommunity -ErrorAction SilentlyContinue) {
            Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        else {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        Write-Output "[OK] Successfully connected to Microsoft Graph"
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

function Get-EmbeddedCertificateExpiry {
    param([object]$CertProfile)

    # Trusted cert profiles embed the certificate as base64 in trustedRootCertificate
    if (-not $CertProfile.trustedRootCertificate) { return $null }

    try {
        $certBytes = [Convert]::FromBase64String($CertProfile.trustedRootCertificate)
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes)
        return [PSCustomObject]@{
            Subject   = $cert.Subject
            NotAfter  = $cert.NotAfter
            Thumbprint = $cert.Thumbprint
        }
    }
    catch {
        Write-Verbose "Could not decode certificate in '$($CertProfile.displayName)': $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner

    Write-Output "Retrieving configuration profiles..."
    $allConfigurations = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$expand=assignments"

    # Certificate-related profile types across all platforms
    $certificateProfiles = @($allConfigurations | Where-Object {
            $_.'@odata.type' -match "ScepCertificateProfile|PkcsCertificateProfile|TrustedRootCertificate|TrustedCertificate"
        })

    if ($certificateProfiles.Count -eq 0) {
        Write-Output "`nNo SCEP, PKCS, or trusted certificate profiles found in this tenant."
        return
    }
    Write-Output "[OK] Found $($certificateProfiles.Count) certificate profiles"

    $now = Get-Date
    [System.Collections.Generic.List[Object]]$report = @()

    foreach ($certProfile in $certificateProfiles) {
        $typeName = ([string]$certProfile.'@odata.type') -replace "#microsoft.graph.", ""

        $kind = if ($typeName -match "Scep") { "SCEP" }
        elseif ($typeName -match "Pkcs") { "PKCS" }
        else { "Trusted Certificate" }

        # Deployment health per profile
        $deviceStatuses = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($certProfile.id)/deviceStatuses"
        $errorCount = @($deviceStatuses | Where-Object { $_.status -in @("error", "conflict", "nonCompliant") }).Count
        $okCount = @($deviceStatuses | Where-Object { $_.status -in @("compliant", "succeeded") }).Count

        # Real certificate expiry for trusted cert profiles
        $embedded = if ($kind -eq "Trusted Certificate") { Get-EmbeddedCertificateExpiry -CertProfile $certProfile } else { $null }
        $embeddedExpiry = ""
        $flag = ""

        if ($embedded) {
            $daysLeft = [math]::Round(($embedded.NotAfter - $now).TotalDays, 0)
            $embeddedExpiry = "$($embedded.NotAfter.ToString('yyyy-MM-dd')) ($daysLeft days)"
            if ($daysLeft -lt 0) { $flag = "CertificateExpired" }
            elseif ($daysLeft -le $ExpiryWarningDays) { $flag = "CertificateExpiring" }
        }

        if (-not $flag) {
            if (@($certProfile.assignments).Count -eq 0) { $flag = "NotAssigned" }
            elseif ($errorCount -gt 0) { $flag = "DeploymentErrors" }
        }

        $validity = ""
        if ($certProfile.certificateValidityPeriodValue) {
            $validity = "$($certProfile.certificateValidityPeriodValue) $($certProfile.certificateValidityPeriodScale)"
        }

        $report.Add([PSCustomObject]@{
                ProfileName     = $certProfile.displayName
                Kind            = $kind
                ProfileType     = $typeName
                IsAssigned      = (@($certProfile.assignments).Count -gt 0)
                ValiditySetting = $validity
                EmbeddedCertExpiry = $embeddedExpiry
                DevicesOk       = $okCount
                DevicesError    = $errorCount
                Flag            = $flag
                ProfileId       = $certProfile.id
            })
    }

    # ----- Display results -----
    Write-Output "`nCERTIFICATE PROFILE AUDIT"
    Write-Output ("=" * 50)
    Write-Output "Expiry warning window: $ExpiryWarningDays days | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    foreach ($kindGroup in ($report | Group-Object -Property Kind | Sort-Object Name)) {
        Write-Output "`n$($kindGroup.Name) profiles ($($kindGroup.Count)):"
        foreach ($row in ($kindGroup.Group | Sort-Object ProfileName)) {
            $assignedLabel = if ($row.IsAssigned) { "assigned" } else { "NOT ASSIGNED" }
            $line = "  $($row.ProfileName) [$assignedLabel]"
            if ($row.Flag) { $line += " [$($row.Flag)]" }
            Write-Output $line

            if ($row.ValiditySetting) {
                Write-Output "    Issued cert validity: $($row.ValiditySetting)"
            }
            if ($row.EmbeddedCertExpiry) {
                Write-Output "    Embedded certificate expires: $($row.EmbeddedCertExpiry)"
            }
            Write-Output "    Deployment: $($row.DevicesOk) ok, $($row.DevicesError) errors"
        }
    }

    # Summary
    $flagged = @($report | Where-Object { $_.Flag })
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($report.Count) certificate profiles | $($flagged.Count) flagged"
    foreach ($row in $flagged) {
        Write-Output "  [$($row.Flag)] $($row.ProfileName)"
    }
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Certificate_Profile_Audit_$timestamp.csv"
        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Output "[OK] CSV report saved: $csvPath"
    }
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    try {
        $null = Disconnect-MgGraph
        Write-Output "[OK] Disconnected from Microsoft Graph"
    }
    catch {
        Write-Verbose "Graph disconnection completed"
    }
}
