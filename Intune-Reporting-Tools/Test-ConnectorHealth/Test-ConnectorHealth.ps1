<#
.TITLE
    Check Connector Health

.SYNOPSIS
    One health report for every Intune tenant connector: Apple DEP/APNs/VPP, Managed Google Play, NDES, certificate connectors, and Mobile Threat Defense.

.DESCRIPTION
    This script checks the health of all tenant-level Intune connectors in a single
    run: Apple push notification certificate and DEP token expiry and sync state,
    VPP tokens, the Managed Google Play binding and app sync status, NDES and
    certificate connectors, and Mobile Threat Defense partner connectors with their
    heartbeat state. Every connector is scored healthy, warning, or critical, so a
    silent connector failure (expired token, stale sync, unresponsive partner)
    surfaces before users notice broken enrollments or app installs.

    Supports interactive sign-in and unattended app-only via -TenantId/-ClientId.

.TAGS
    Monitoring

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementServiceConfig.Read.All,DeviceManagementConfiguration.Read.All,DeviceManagementApps.Read.All

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
    .\Test-ConnectorHealth.ps1
    Checks all connectors with a 30-day expiry warning window

.EXAMPLE
    .\Test-ConnectorHealth.ps1 -ExpiryWarningDays 60 -ExportToCsv "true"
    Uses a 60-day warning window and exports the report to CSV

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Connectors that are not configured in the tenant are reported as NotConfigured, not as failures
    - Sync staleness thresholds: DEP sync older than 7 days and Google Play app sync older than 7 days raise warnings
    - Uses beta Graph endpoints because most connector surfaces are not exposed on v1.0
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
    - Logs: %ProgramData%\check-connector-health\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Days before certificate/token expiry to raise a warning")]
    [ValidateRange(1, 365)]
    [int]$ExpiryWarningDays = 30,

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

$SolutionName = 'check-connector-health'
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
            "DeviceManagementServiceConfig.Read.All",
            "DeviceManagementConfiguration.Read.All",
            "DeviceManagementApps.Read.All"
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

$script:ConnectorReport = [System.Collections.Generic.List[Object]]::new()

function Add-ConnectorResult {
    param(
        [string]$Connector,
        [string]$Instance,
        [string]$Status,
        [string]$Detail
    )

    $script:ConnectorReport.Add([PSCustomObject]@{
            Connector = $Connector
            Instance  = $Instance
            Status    = $Status
            Detail    = $Detail
        })
}

function Get-ExpiryStatus {
    param(
        [object]$ExpiryValue,
        [int]$WarningDays
    )

    if (-not $ExpiryValue) {
        return @{ Status = "Warning"; Detail = "No expiration date available" }
    }

    $expiry = [DateTime]::Parse($ExpiryValue.ToString())
    $daysLeft = [math]::Round(($expiry - (Get-Date)).TotalDays, 0)

    if ($daysLeft -lt 0) {
        return @{ Status = "Critical"; Detail = "EXPIRED $([math]::Abs($daysLeft)) days ago ($($expiry.ToString('yyyy-MM-dd')))" }
    }
    if ($daysLeft -le $WarningDays) {
        return @{ Status = "Warning"; Detail = "Expires in $daysLeft days ($($expiry.ToString('yyyy-MM-dd')))" }
    }
    return @{ Status = "Healthy"; Detail = "Expires in $daysLeft days ($($expiry.ToString('yyyy-MM-dd')))" }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner

    $staleSyncThreshold = (Get-Date).AddDays(-7)

    # ----- Apple push notification certificate -----
    Write-Output "Checking Apple MDM push certificate..."
    try {
        $apns = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/applePushNotificationCertificate" -Method GET
        if ($apns -and $apns.appleIdentifier) {
            $expiryInfo = Get-ExpiryStatus -ExpiryValue $apns.expirationDateTime -WarningDays $ExpiryWarningDays
            Add-ConnectorResult -Connector "Apple MDM Push Certificate" -Instance $apns.appleIdentifier -Status $expiryInfo.Status -Detail $expiryInfo.Detail
        }
        else {
            Add-ConnectorResult -Connector "Apple MDM Push Certificate" -Instance "-" -Status "NotConfigured" -Detail "No APNs certificate uploaded"
        }
    }
    catch {
        Add-ConnectorResult -Connector "Apple MDM Push Certificate" -Instance "-" -Status "NotConfigured" -Detail "Not configured or not readable"
    }

    # ----- Apple DEP tokens -----
    Write-Output "Checking Apple DEP tokens..."
    try {
        $depTokens = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings"
        if (@($depTokens).Count -eq 0) {
            Add-ConnectorResult -Connector "Apple DEP Token" -Instance "-" -Status "NotConfigured" -Detail "No Automated Device Enrollment tokens"
        }
        foreach ($token in $depTokens) {
            $expiryInfo = Get-ExpiryStatus -ExpiryValue $token.tokenExpirationDateTime -WarningDays $ExpiryWarningDays
            $status = $expiryInfo.Status
            $detail = $expiryInfo.Detail

            # A valid token with a failing or stale sync is still broken
            $lastSync = if ($token.lastSuccessfulSyncDateTime) { [DateTime]::Parse($token.lastSuccessfulSyncDateTime.ToString()) } else { $null }
            if ($token.lastSyncErrorCode -and $token.lastSyncErrorCode -ne 0) {
                if ($status -eq "Healthy") { $status = "Warning" }
                $detail += " | last sync error code: $($token.lastSyncErrorCode)"
            }
            if ($lastSync -and $lastSync -lt $staleSyncThreshold) {
                if ($status -eq "Healthy") { $status = "Warning" }
                $detail += " | last successful sync: $($lastSync.ToString('yyyy-MM-dd'))"
            }

            Add-ConnectorResult -Connector "Apple DEP Token" -Instance $token.tokenName -Status $status -Detail $detail
        }
    }
    catch {
        Add-ConnectorResult -Connector "Apple DEP Token" -Instance "-" -Status "Error" -Detail $_.Exception.Message
    }

    # ----- Apple VPP tokens -----
    Write-Output "Checking Apple VPP tokens..."
    try {
        $vppTokens = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/vppTokens"
        if (@($vppTokens).Count -eq 0) {
            Add-ConnectorResult -Connector "Apple VPP Token" -Instance "-" -Status "NotConfigured" -Detail "No VPP tokens"
        }
        foreach ($token in $vppTokens) {
            $expiryInfo = Get-ExpiryStatus -ExpiryValue $token.expirationDateTime -WarningDays $ExpiryWarningDays
            $status = if ($token.state -ne "valid") { "Critical" } else { $expiryInfo.Status }
            $detail = "State: $($token.state) | $($expiryInfo.Detail)"
            Add-ConnectorResult -Connector "Apple VPP Token" -Instance $token.appleId -Status $status -Detail $detail
        }
    }
    catch {
        Add-ConnectorResult -Connector "Apple VPP Token" -Instance "-" -Status "Error" -Detail $_.Exception.Message
    }

    # ----- Managed Google Play -----
    Write-Output "Checking Managed Google Play binding..."
    try {
        $googlePlay = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/androidManagedStoreAccountEnterpriseSettings" -Method GET
        if ($googlePlay.bindStatus -eq "notBound") {
            Add-ConnectorResult -Connector "Managed Google Play" -Instance "-" -Status "NotConfigured" -Detail "Tenant is not bound to Managed Google Play"
        }
        else {
            $status = "Healthy"
            $detail = "Bind status: $($googlePlay.bindStatus) | app sync: $($googlePlay.lastAppSyncStatus)"

            if ($googlePlay.lastAppSyncStatus -notin @("success", "none")) {
                $status = "Warning"
            }
            $lastAppSync = if ($googlePlay.lastAppSyncDateTime) { [DateTime]::Parse($googlePlay.lastAppSyncDateTime.ToString()) } else { $null }
            if ($lastAppSync) {
                $detail += " | last sync: $($lastAppSync.ToString('yyyy-MM-dd'))"
                if ($lastAppSync -lt $staleSyncThreshold) { $status = "Warning" }
            }

            Add-ConnectorResult -Connector "Managed Google Play" -Instance $googlePlay.ownerOrganizationName -Status $status -Detail $detail
        }
    }
    catch {
        Add-ConnectorResult -Connector "Managed Google Play" -Instance "-" -Status "Error" -Detail $_.Exception.Message
    }

    # ----- NDES connectors -----
    Write-Output "Checking NDES connectors..."
    try {
        $ndesConnectors = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/ndesConnectors"
        if (@($ndesConnectors).Count -eq 0) {
            Add-ConnectorResult -Connector "NDES Connector" -Instance "-" -Status "NotConfigured" -Detail "No NDES connectors installed"
        }
        foreach ($connector in $ndesConnectors) {
            $status = if ($connector.state -eq "active") { "Healthy" } else { "Critical" }
            $lastConnection = if ($connector.lastConnectionDateTime) { [DateTime]::Parse($connector.lastConnectionDateTime.ToString()) } else { $null }
            $detail = "State: $($connector.state)"
            if ($lastConnection) {
                $detail += " | last connection: $($lastConnection.ToString('yyyy-MM-dd HH:mm'))"
                if ($lastConnection -lt $staleSyncThreshold -and $status -eq "Healthy") { $status = "Warning" }
            }
            Add-ConnectorResult -Connector "NDES Connector" -Instance $connector.displayName -Status $status -Detail $detail
        }
    }
    catch {
        Add-ConnectorResult -Connector "NDES Connector" -Instance "-" -Status "Error" -Detail $_.Exception.Message
    }

    # ----- Certificate connectors -----
    Write-Output "Checking certificate connectors..."
    try {
        # This surface returns errors in tenants that never installed a connector
        $certificateConnectors = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/certificateConnectorDetails"
        if (@($certificateConnectors).Count -eq 0) {
            Add-ConnectorResult -Connector "Certificate Connector" -Instance "-" -Status "NotConfigured" -Detail "No certificate connectors installed"
        }
        foreach ($connector in $certificateConnectors) {
            $lastCheckIn = if ($connector.lastCheckinDateTime) { [DateTime]::Parse($connector.lastCheckinDateTime.ToString()) } else { $null }
            $status = "Healthy"
            $detail = "Version: $($connector.connectorVersion)"
            if ($lastCheckIn) {
                $detail += " | last check-in: $($lastCheckIn.ToString('yyyy-MM-dd HH:mm'))"
                if ($lastCheckIn -lt $staleSyncThreshold) { $status = "Critical" }
            }
            Add-ConnectorResult -Connector "Certificate Connector" -Instance $connector.machineName -Status $status -Detail $detail
        }
    }
    catch {
        Add-ConnectorResult -Connector "Certificate Connector" -Instance "-" -Status "NotConfigured" -Detail "No certificate connector infrastructure in this tenant"
    }

    # ----- Mobile Threat Defense connectors -----
    Write-Output "Checking Mobile Threat Defense connectors..."
    try {
        $mtdConnectors = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/mobileThreatDefenseConnectors"
        if (@($mtdConnectors).Count -eq 0) {
            Add-ConnectorResult -Connector "Mobile Threat Defense" -Instance "-" -Status "NotConfigured" -Detail "No MTD connectors"
        }
        foreach ($connector in $mtdConnectors) {
            $status = switch ($connector.partnerState) {
                "available" { "Healthy" }
                "enabled" { "Healthy" }
                "unresponsive" { "Critical" }
                default { "Warning" }
            }
            $lastHeartbeat = if ($connector.lastHeartbeatDateTime) { [DateTime]::Parse($connector.lastHeartbeatDateTime.ToString()) } else { $null }
            $detail = "Partner state: $($connector.partnerState)"
            if ($lastHeartbeat) {
                $detail += " | last heartbeat: $($lastHeartbeat.ToString('yyyy-MM-dd HH:mm'))"
            }
            Add-ConnectorResult -Connector "Mobile Threat Defense" -Instance $connector.id -Status $status -Detail $detail
        }
    }
    catch {
        Add-ConnectorResult -Connector "Mobile Threat Defense" -Instance "-" -Status "Error" -Detail $_.Exception.Message
    }

    # ----- Display results -----
    Write-Output "`nCONNECTOR HEALTH REPORT"
    Write-Output ("=" * 50)
    Write-Output "Warning window: $ExpiryWarningDays days | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output ("=" * 50)

    $statusOrder = @("Critical", "Warning", "Error", "Healthy", "NotConfigured")
    foreach ($statusName in $statusOrder) {
        $rows = @($script:ConnectorReport | Where-Object { $_.Status -eq $statusName })
        if ($rows.Count -eq 0) { continue }

        Write-Output "`n[$statusName]"
        foreach ($row in $rows) {
            Write-Output "  $($row.Connector) | $($row.Instance)"
            Write-Output "    $($row.Detail)"
        }
    }

    # Summary
    $criticalCount = @($script:ConnectorReport | Where-Object { $_.Status -eq "Critical" }).Count
    $warningCount = @($script:ConnectorReport | Where-Object { $_.Status -eq "Warning" }).Count
    Write-Output "`n"
    Write-Output ("=" * 50)
    Write-Output "Summary: $($script:ConnectorReport.Count) connector checks | $criticalCount critical | $warningCount warnings"
    Write-Output ("=" * 50)

    # Export to CSV if requested
    if ($ExportToCsv) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $csvPath = Join-Path $OutputPath "Connector_Health_$timestamp.csv"
        $script:ConnectorReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
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
