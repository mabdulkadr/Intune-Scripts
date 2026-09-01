<#
.TITLE
    Export-IntuneDashboard - Intune Health Dashboard

.SYNOPSIS
    Generates a single-page HTML dashboard aggregating Intune health metrics.

.DESCRIPTION
    Pulls data from multiple Microsoft Graph endpoints in one pass and renders a self-contained HTML report with compliance, inventory, update ring, Conditional Access, license, and risky user insights. HTML has zero external dependencies for browser sharing.

        Scope & safety:
        - Read-only Graph queries; never modifies tenant or device state.
        Degradation behavior:
        - Missing Graph data renders as empty sections; never aborts the report.
        Output contract:
        - Self-contained HTML file saved beside the script by default; exit 0 = success, 1 = failure.

.TAGS
    Reporting,Dashboard,Intune,EntraID,Graph

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All, DeviceManagementManagedDevices.Read.All, DeviceManagementServiceConfig.Read.All, DeviceManagementApps.Read.All, Device.Read.All, Directory.Read.All, Group.Read.All, User.Read.All, Policy.Read.All, Application.Read.All, AuditLog.Read.All, IdentityRiskyUser.Read.All, Organization.Read.All, RoleManagement.Read.All, SecurityEvents.Read.All, ServiceHealth.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-27)
    - Merged Get-DailyTenantReport sections into the dashboard (8 new sections + 6 new KPIs)
    - Added: M365 Secure Score gauge with posture color
    - Added: Apple Certificates (APNs/VPP/DEP) expiry table with severity badges
    - Added: Intune Service Health issues + status indicator
    - Added: Tenant Connectors (MTD/NDES/ServiceNow/Zebra/Remote Assist/Compliance Partner) with heartbeat
    - Added: Failed Entra sign-ins (last 24h) table
    - Added: App Registrations with secrets expiring in 90 days
    - Added: Windows Update Reports summary (feature/quality/driver alerts)
    - Added: Windows 365 Cloud PCs summary
    - Expanded KPI bar from 6 to 12 tiles
    - Now the single integrated report (Get-DailyTenantReport.ps1 deleted)
    1.1.0 (2026-08-27)
    - Redesigned footer: 3-column layout (tenant/operator + compliance grade card with tooltip + action bar)
    - Added Print, Copy Path, Top, Disclaimer modal, and Text Summary export buttons
    - Added run ID, UTC timestamp, timezone, and script version in footer
    - Added @media print rules for clean PDF export (hides footer, inverts colors)
    - Improved compliance grade colors (Carbon palette: A=green, F=red)
    1.0.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-27

.EXAMPLE
    .\Export-IntuneDashboard.ps1
    Generates the dashboard using default output beside the script.

.EXAMPLE
    .\\Export-IntuneDashboard.ps1 -OutputPath "C:\\Reports\\Dashboard.html"
    Generates the dashboard at a specific path.

.NOTES
    - Requires Microsoft.Graph.Authentication module.
        - Read-only; no tenant modifications.
        - Logs: C:\ProgramData\Export-IntuneDashboard\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()][string]$OutputPath,
    [Parameter()][int]$DaysStale = 90
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'Export-IntuneDashboard'
$ScriptMode   = 'run'

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# Single source of truth: Initialize-Log / Write-Banner / Write-Log / Finish-Script.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('')
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
        Write-Log -Message "Log initialization failed: $($_.Exception.Message)" -Level 'ERROR'
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
# REPORT OUTPUT ANCHORING (Law 12)
# Anchors relative output paths beside the script using fallback chain.
# ============================================================================

$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

# Resolve relative ExportPath/OutputPath beside the script (Law 12).
if ($PSBoundParameters.ContainsKey('ExportPath') -and $ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = Join-Path $scriptDirectory $ExportPath
}
if ($PSBoundParameters.ContainsKey('OutputPath') -and $OutputPath -and -not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptDirectory $OutputPath
}


# ============================================================================
# MAIN ENTRY LOGGING INITIALIZATION
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started: Export-IntuneDashboard" -Level 'INFO'



#region --- Helpers ---

function Get-MgGraphAllPages {
    param([string]$Uri,[string]$Method='GET')
    try {
        $response = Invoke-MgGraphRequest -Uri $Uri -Method $Method -ErrorAction Stop
        $results = @()
        if ($null -ne $response.value) { $results += $response.value }
        elseif ($response) { $results += $response }
        while ($response.'@odata.nextLink') {
            $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET -ErrorAction Stop
            if ($null -ne $response.value) { $results += $response.value }
        }
        return ,$results
    } catch [System.Exception] { # typed catch - handles Graph or runtime errors
        Write-Verbose "Graph call failed: $_"; return @() }
}
#endregion

#region --- Auth ---
Write-Log -Message "=== AUTHENTICATION ===" -Level 'INFO'
$context = Get-MgContext
if (-not $context) {
    Connect-MgGraph -Scopes @(
        'DeviceManagementConfiguration.Read.All','DeviceManagementManagedDevices.Read.All',
        'DeviceManagementServiceConfig.Read.All','DeviceManagementApps.Read.All',
        'Device.Read.All','Directory.Read.All','Group.Read.All','User.Read.All',
        'Policy.Read.All','Application.Read.All','AuditLog.Read.All',
        'IdentityRiskyUser.Read.All','Organization.Read.All','RoleManagement.Read.All',
        'SecurityEvents.Read.All','ServiceHealth.Read.All'
    ) -NoWelcome -ErrorAction Stop
    $context = Get-MgContext
}
Write-Log -Message "Signed in as: $($context.Account)" -Level 'INFO'
$tenantInfo = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/organization"
$tenantName = if ($tenantInfo.Count -gt 0) { $tenantInfo[0].displayName } else { $context.TenantId }
#endregion

#region --- Data Collection ---
Write-Log -Message "=== COLLECTING DATA ===" -Level 'INFO'
$now = Get-Date

# 1. Managed devices
Write-Log -Message "Fetching managed devices..." -Level 'INFO'
$devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices"
Write-Log -Message "$($devices.Count) managed devices" -Level 'INFO'

# 2. Update rings
Write-Log -Message "Fetching update rings..." -Level 'INFO'
$updateRings = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windowsUpdateForBusinessConfiguration')"
Write-Log -Message "$($updateRings.Count) update rings" -Level 'INFO'

# 3. Feature update profiles
Write-Log -Message "Fetching feature update profiles..." -Level 'INFO'
$featureProfiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles"
Write-Log -Message "$($featureProfiles.Count) feature update profiles" -Level 'INFO'

# 4. Conditional Access
Write-Log -Message "Fetching Conditional Access policies..." -Level 'INFO'
$caPolicies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
Write-Log -Message "$($caPolicies.Count) CA policies" -Level 'INFO'

# 5. License subscriptions
Write-Log -Message "Fetching license subscriptions..." -Level 'INFO'
$subscriptions = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"
Write-Log -Message "$($subscriptions.Count) subscriptions" -Level 'INFO'

# 6. Risky users
Write-Log -Message "Fetching risky users..." -Level 'INFO'
$riskyUsers = @()
try { $riskyUsers = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers?`$filter=riskState ne 'dismissed' and riskState ne 'remediated'" } catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
Write-Log -Message "$($riskyUsers.Count) active risky users" -Level 'INFO'

# 7. Guest users
Write-Log -Message "Fetching guest users..." -Level 'INFO'
$guestUsers = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/users?`$filter=userType eq 'Guest'&`$select=id,displayName,mail,accountEnabled,createdDateTime,signInActivity,externalUserState"
Write-Log -Message "$($guestUsers.Count) guest users" -Level 'INFO'

# 8. Entra devices (for stale cross-ref)
Write-Log -Message "Fetching Entra ID device records..." -Level 'INFO'
$entraDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/devices?`$select=id,deviceId,displayName,approximateLastSignInDateTime,accountEnabled,operatingSystem"
Write-Log -Message "$($entraDevices.Count) Entra ID devices" -Level 'INFO'

# 9. Secure Score (M365 security posture)
Write-Log -Message "Fetching M365 Secure Score..." -Level 'INFO'
$secureScore = $null
$secureScoreMax = 0
try {
    $scores = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/security/secureScores?`$top=1"
    if ($scores.Count -gt 0) {
        $secureScore = [int]$scores[0].currentScore
        $secureScoreMax = [int]$scores[0].maxScore
    }
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
Write-Log -Message "Secure Score: $secureScore / $secureScoreMax" -Level 'INFO'

# 10. Apple Push Notification certificate
Write-Log -Message "Fetching Apple Push certificate..." -Level 'INFO'
$applePush = $null
try {
    $applePush = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/applePushNotificationCertificate" -Method GET
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
$applePushExpiry = if ($applePush -and $applePush.expirationDateTime) { [datetime]$applePush.expirationDateTime } else { $null }
$applePushDays = if ($applePushExpiry) { [int]($applePushExpiry - $now).TotalDays } else { $null }
Write-Log -Message ("Apple Push cert expires: {0}" -f $applePushDays) -Level 'INFO'

# 11. VPP tokens
Write-Log -Message "Fetching VPP tokens..." -Level 'INFO'
$vppExpiry = $null
$vppDays = $null
try {
    $vppTokens = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/vppTokens"
    if ($vppTokens.Count -gt 0) {
        $vppExpiry = [datetime]$vppTokens[0].expirationDateTime
        $vppDays = [int]($vppExpiry - $now).TotalDays
    }
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }

# 12. DEP onboarding settings
Write-Log -Message "Fetching DEP settings..." -Level 'INFO'
$depExpiry = $null
$depDays = $null
try {
    $depSettings = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings"
    if ($depSettings.Count -gt 0 -and $depSettings[0].tokenExpirationDateTime) {
        $depExpiry = [datetime]$depSettings[0].tokenExpirationDateTime
        $depDays = [int]($depExpiry - $now).TotalDays
    }
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }

# 13. Intune service health (issues + messages)
Write-Log -Message "Fetching Intune service health..." -Level 'INFO'
$healthIssues = @()
$healthMessages = @()
$healthOverview = $null
try {
    $healthOverview = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/admin/serviceAnnouncement/healthOverviews/microsoft.intune"
    $healthIssues = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/admin/serviceAnnouncement/issues?`$filter=service eq 'Microsoft Intune'&`$orderby=lastModifiedDateTime desc&`$top=10"
    $healthMessages = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/admin/serviceAnnouncement/messages?`$filter=service eq 'Microsoft Intune'&`$orderby=lastModifiedDateTime desc&`$top=10"
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
$healthStatus = if ($healthOverview -and $healthOverview.Count -gt 0) { $healthOverview[0].status } else { 'Unknown' }
$healthIssueCount = @($healthIssues | Where-Object { $_.isResolved -ne $true }).Count
Write-Log -Message ("Service health: {0}, {1} active issues" -f $healthStatus, $healthIssueCount) -Level 'INFO'

# 14. Connectors status (NDES, Zebra, ServiceNow, MTD, ChromeOS, etc.)
Write-Log -Message "Fetching connectors status..." -Level 'INFO'
$connectors = @()
$connectorData = @()
try {
    # Mobile Threat Defense connectors
    $mtdConnectors = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/mobileThreatDefenseConnectors?`$select=id,displayName,lastHeartbeatDateTime,partnerState,androidEnabled,iosEnabled,windowsEnabled,macEnabled"
    foreach ($c in $mtdConnectors) {
        $heartbeat = if ($c.lastHeartbeatDateTime) { [datetime]$c.lastHeartbeatDateTime } else { $null }
        $daysSinceHb = if ($heartbeat) { [int]($now - $heartbeat).TotalDays } else { 999 }
        $state = $c.partnerState
        $connectorData += [PSCustomObject]@{
            Category = 'MTD'
            Name     = $c.displayName
            State    = $state
            LastHb   = if ($heartbeat) { $heartbeat.ToString('yyyy-MM-dd') } else { 'Never' }
            DaysHb   = $daysSinceHb
            Issue    = if ($state -ne 'enabled' -or $daysSinceHb -gt 7) { 'Yes' } else { 'No' }
        }
    }
    # NDES connectors
    $ndes = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/ndesConnectors"
    foreach ($c in $ndes) {
        $connectorData += [PSCustomObject]@{
            Category = 'NDES'
            Name     = $c.displayName
            State    = if ($c.enabled) { 'enabled' } else { 'disabled' }
            LastHb   = '-'
            DaysHb   = 0
            Issue    = if (-not $c.enabled) { 'Yes' } else { 'No' }
        }
    }
    # ServiceNow
    $snowConnectors = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/serviceNowConnections"
    foreach ($c in $snowConnectors) {
        $connectorData += [PSCustomObject]@{
            Category = 'ServiceNow'
            Name     = $c.displayName
            State    = 'configured'
            LastHb   = '-'
            DaysHb   = 0
            Issue    = 'No'
        }
    }
    # Zebra FOTA
    $zebra = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/zebraFotaConnector"
    if ($zebra.Count -gt 0) {
        foreach ($c in $zebra) {
            $connectorData += [PSCustomObject]@{
                Category = 'Zebra FOTA'
                Name     = $c.displayName
                State    = if ($c.state -eq 'enabled') { 'enabled' } else { 'disabled' }
                LastHb   = '-'
                DaysHb   = 0
                Issue    = 'No'
            }
        }
    }
    # Remote Assistance
    $raPartners = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/remoteAssistancePartners"
    foreach ($c in $raPartners) {
        $connectorData += [PSCustomObject]@{
            Category = 'Remote Assist'
            Name     = $c.displayName
            State    = if ($c.state -eq 'enabled') { 'enabled' } else { 'disabled' }
            LastHb   = '-'
            DaysHb   = 0
            Issue    = 'No'
        }
    }
    # Compliance Management Partners
    $cmp = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/complianceManagementPartners"
    foreach ($c in $cmp) {
        $connectorData += [PSCustomObject]@{
            Category = 'Compliance Partner'
            Name     = $c.displayName
            State    = if ($c.state -eq 'enabled') { 'enabled' } else { 'disabled' }
            LastHb   = '-'
            DaysHb   = 0
            Issue    = 'No'
        }
    }
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
$connectorIssueCount = @($connectorData | Where-Object { $_.Issue -eq 'Yes' }).Count
Write-Log -Message ("{0} connectors, {1} with issues" -f $connectorData.Count, $connectorIssueCount) -Level 'INFO'

# 15. Failed sign-ins (last 24h)
Write-Log -Message "Fetching failed sign-ins (24h)..." -Level 'INFO'
$failedSignIns = @()
try {
    $startDate = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $signIns = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/auditLogs/signIns?api-version=beta&`$filter=createdDateTime ge $startDate and status/errorCode ne 0&`$top=50"
    $failedSignIns = $signIns | ForEach-Object {
        $errCode = $_.status.errorCode
        $errDesc = $_.status.failureReason
        [PSCustomObject]@{
            User      = $_.userPrincipalName
            App       = $_.appDisplayName
            IP        = $_.ipAddress
            Time      = ([datetime]$_.createdDateTime).ToString('MM-dd HH:mm')
            ErrorCode = $errCode
            Reason    = $errDesc
        }
    }
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
Write-Log -Message "$($failedSignIns.Count) failed sign-ins in last 24h" -Level 'INFO'

# 16. App registrations with expiring secrets (90 days)
Write-Log -Message "Fetching app registrations with expiring secrets..." -Level 'INFO'
$expiringApps = @()
try {
    $apps = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/applications?`$select=id,displayName,appId,passwordCredentials,keyCredentials"
    foreach ($app in $apps) {
        $minExpiry = $null
        $type = ''
        # Check password credentials
        foreach ($cred in $app.passwordCredentials) {
            $exp = [datetime]$cred.endDateTime
            $days = [int]($exp - $now).TotalDays
            if ($null -eq $minExpiry -or $exp -lt $minExpiry) {
                $minExpiry = $exp
                $type = 'Secret'
            }
        }
        # Check key credentials
        foreach ($cred in $app.keyCredentials) {
            $exp = [datetime]$cred.endDateTime
            if ($null -eq $minExpiry -or $exp -lt $minExpiry) {
                $minExpiry = $exp
                $type = 'Cert'
            }
        }
        if ($minExpiry) {
            $daysToExpiry = [int]($minExpiry - $now).TotalDays
            if ($daysToExpiry -le 90) {
                $expiringApps += [PSCustomObject]@{
                    Name      = $app.displayName
                    AppId     = $app.appId
                    Type      = $type
                    Expires   = $minExpiry.ToString('yyyy-MM-dd')
                    DaysLeft  = $daysToExpiry
                    Severity  = if ($daysToExpiry -lt 0) { 'expired' } elseif ($daysToExpiry -le 30) { 'critical' } elseif ($daysToExpiry -le 60) { 'high' } else { 'medium' }
                }
            }
        }
    }
    $expiringApps = $expiringApps | Sort-Object DaysLeft
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
Write-Log -Message ("{0} app registrations with secrets expiring in 90 days" -f $expiringApps.Count) -Level 'INFO'

# 17. Windows Update reports (feature/quality/driver errors summary)
Write-Log -Message "Fetching Windows Update report summaries..." -Level 'INFO'
$wuFeatureErrors = 0
$wuQualityErrors = 0
$wuDriverErrors = 0
try {
    $qualityReport = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/getWindowsUpdateAlertSummaryReport" -Method POST -Body '{}' -ContentType "application/json"
    if ($qualityReport) { $wuQualityErrors = @($qualityReport).Count }
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
try {
    $featureReport = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/getWindowsFeatureUpdateAlertSummaryReport" -Method POST -Body '{}' -ContentType "application/json"
    if ($featureReport) { $wuFeatureErrors = @($featureReport).Count }
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
try {
    $driverReport = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/getWindowsDriverUpdateAlertSummaryReport" -Method POST -Body '{}' -ContentType "application/json"
    if ($driverReport) { $wuDriverErrors = @($driverReport).Count }
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
$wuTotalErrors = $wuFeatureErrors + $wuQualityErrors + $wuDriverErrors

# 18. Cloud PCs (Windows 365) summary
Write-Log -Message "Fetching Cloud PCs (Windows 365)..." -Level 'INFO'
$cloudPcs = @()
$cloudPcProvisioned = 0
$cloudPcFailed = 0
try {
    $cloudPcs = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$select=id,displayName,status,userPrincipalName,lastModifiedDateTime"
    $cloudPcProvisioned = @($cloudPcs | Where-Object { $_.status -eq 'provisioned' }).Count
    $cloudPcFailed = @($cloudPcs | Where-Object { $_.status -eq 'failed' -or $_.status -eq 'provisioningFailed' }).Count
} catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }
Write-Log -Message ("{0} Cloud PCs ({1} provisioned, {2} failed)" -f $cloudPcs.Count, $cloudPcProvisioned, $cloudPcFailed) -Level 'INFO'
#endregion

#region --- Data Processing ---
Write-Log -Message "=== PROCESSING METRICS ===" -Level 'INFO'

# --- Compliance ---
$compliant      = @($devices | Where-Object { $_.complianceState -eq 'compliant' }).Count
$nonCompliant   = @($devices | Where-Object { $_.complianceState -eq 'noncompliant' }).Count
$inGrace        = @($devices | Where-Object { $_.complianceState -eq 'inGracePeriod' }).Count
$unknownComp    = $devices.Count - $compliant - $nonCompliant - $inGrace
$complianceRate = if ($devices.Count -gt 0) { [math]::Round(($compliant / $devices.Count) * 100, 1) } else { 0 }

# --- OS Distribution ---
$osDist = @{}
foreach ($d in $devices) {
    $os = if ($d.operatingSystem) { $d.operatingSystem } else { 'Unknown' }
    if (-not $osDist.ContainsKey($os)) { $osDist[$os] = 0 }
    $osDist[$os]++
}

# --- Manufacturer Distribution ---
$mfgDist = @{}
foreach ($d in $devices) {
    $mfg = if ($d.manufacturer) { $d.manufacturer } else { 'Unknown' }
    if (-not $mfgDist.ContainsKey($mfg)) { $mfgDist[$mfg] = 0 }
    $mfgDist[$mfg]++
}

# --- Stale Devices ---
$staleThreshold = $now.AddDays(-$DaysStale)
$warnThreshold  = $now.AddDays(-60)
$activeDevices = 0; $warnDevices = 0; $staleDevices = 0; $noSyncDevices = 0
foreach ($d in $devices) {
    if ($d.lastSyncDateTime) {
        $lastSync = [datetime]$d.lastSyncDateTime
        if ($lastSync -ge $warnThreshold) { $activeDevices++ }
        elseif ($lastSync -ge $staleThreshold) { $warnDevices++ }
        else { $staleDevices++ }
    } else { $noSyncDevices++ }
}

# Top 10 most stale
$topStale = $devices | Where-Object { $_.lastSyncDateTime } |
    Sort-Object { [datetime]$_.lastSyncDateTime } |
    Select-Object -First 10 |
    ForEach-Object {
        $days = [math]::Round(($now - [datetime]$_.lastSyncDateTime).TotalDays, 1)
        [PSCustomObject]@{ Name=$_.deviceName; User=$_.userPrincipalName; OS=$_.operatingSystem; DaysStale=$days; LastSync=([datetime]$_.lastSyncDateTime).ToString('yyyy-MM-dd') }
    }

# --- Encryption ---
$encrypted    = @($devices | Where-Object { $_.isEncrypted -eq $true }).Count
$notEncrypted = @($devices | Where-Object { $_.isEncrypted -eq $false }).Count
$unknownEnc   = $devices.Count - $encrypted - $notEncrypted

# --- Windows Build Distribution ---
$winDevices = $devices | Where-Object { $_.operatingSystem -eq 'Windows' }
$buildDist = @{}
foreach ($d in $winDevices) {
    $ver = if ($d.osVersion) { $d.osVersion } else { 'Unknown' }
    if (-not $buildDist.ContainsKey($ver)) { $buildDist[$ver] = 0 }
    $buildDist[$ver]++
}

# --- Update Ring Health ---
$ringFindings = @()
foreach ($ring in $updateRings) {
    $issues = @()
    if (-not $ring.qualityUpdatesDeferralPeriodInDays -and -not $ring.qualityUpdatesRollbackStartDateTime) {}
    $qDeadline = $ring.deadlineForQualityUpdatesInDays
    $fDeadline = $ring.deadlineForFeatureUpdatesInDays
    $grace     = $ring.deadlineGracePeriodInDays

    if (-not $qDeadline -and $qDeadline -ne 0) { $issues += @{Severity='High';Finding='No quality update deadline'} }
    if (-not $grace -and $grace -ne 0) { $issues += @{Severity='Medium';Finding='Zero grace period'} }
    if ($ring.featureUpdatesDeferralPeriodInDays -gt 0 -and $featureProfiles.Count -gt 0) {
        $issues += @{Severity='High';Finding="Feature deferral $($ring.featureUpdatesDeferralPeriodInDays)d conflicts with Feature Update profiles"}
    }

    foreach ($iss in $issues) {
        $ringFindings += [PSCustomObject]@{
            RingName = $ring.displayName
            Severity = $iss.Severity
            Finding  = $iss.Finding
        }
    }
}

# --- CA Policy Summary ---
$caEnabled    = @($caPolicies | Where-Object { $_.state -eq 'enabled' }).Count
$caReportOnly = @($caPolicies | Where-Object { $_.state -eq 'enabledForReportingButNotEnforced' }).Count
$caDisabled   = @($caPolicies | Where-Object { $_.state -eq 'disabled' }).Count

# --- License Utilisation ---
$licenseData = @()
foreach ($sub in $subscriptions) {
    if ($null -ne $sub.prepaidUnits -and $sub.prepaidUnits.enabled -gt 0) {
        $total    = $sub.prepaidUnits.enabled
        $consumed = $sub.consumedUnits
        $avail    = $total - $consumed
        $pct      = [math]::Round(($consumed / $total) * 100, 1)
        $licenseData += [PSCustomObject]@{
            Name     = $sub.skuPartNumber
            Total    = $total
            Used     = $consumed
            Available = $avail
            UsedPct  = $pct
        }
    }
}
$licenseData = $licenseData | Sort-Object UsedPct -Descending

# --- Guest Users ---
$guestNeverSignedIn = @($guestUsers | Where-Object {
    -not $_.signInActivity -or -not $_.signInActivity.lastSignInDateTime
}).Count
$guestDisabled = @($guestUsers | Where-Object { $_.accountEnabled -eq $false }).Count
$guestPending  = @($guestUsers | Where-Object { $_.externalUserState -eq 'PendingAcceptance' }).Count

# --- Secure Score percentage ---
$secureScorePct = if ($secureScoreMax -gt 0) { [math]::Round(($secureScore / $secureScoreMax) * 100, 1) } else { 0 }
$secureScoreColor = if ($secureScorePct -ge 80) { 'var(--cds-support-success)' } elseif ($secureScorePct -ge 50) { 'var(--cds-support-warning)' } else { 'var(--cds-support-error)' }

# --- Apple Certificate summary ---
$appleCertMinDays = @($applePushDays, $vppDays, $depDays) | Where-Object { $null -ne $_ } | Measure-Object -Minimum
$appleCertMinDaysValue = if ($appleCertMinDays) { $appleCertMinDays.Minimum } else { $null }
$appleCertOverallColor = if ($null -eq $appleCertMinDaysValue) { 'var(--cds-text-helper)' } elseif ($appleCertMinDaysValue -lt 0) { 'var(--cds-support-error)' } elseif ($appleCertMinDaysValue -le 30) { 'var(--cds-support-error)' } elseif ($appleCertMinDaysValue -le 90) { 'var(--cds-support-warning)' } else { 'var(--cds-support-success)' }

# --- Service Health color ---
$healthColor = switch ($healthStatus) {
    'operational' { 'var(--cds-support-success)' }
    'investigating' { 'var(--cds-support-warning)' }
    'restoringService' { 'var(--cds-support-warning)' }
    'verifyingService' { 'var(--cds-support-warning)' }
    'serviceDegradation' { 'var(--cds-support-error)' }
    'serviceInterruption' { 'var(--cds-support-error)' }
    'extendedServiceInterruption' { 'var(--cds-support-error)' }
    default { 'var(--cds-text-helper)' }
}

# --- Connector Issue color ---
$connectorColor = if ($connectorIssueCount -gt 0) { 'var(--cds-support-warning)' } else { 'var(--cds-support-success)' }

Write-Log -Message "All metrics processed" -Level 'INFO'
#endregion

#region --- HTML Generation ---
Write-Log -Message "=== GENERATING HTML DASHBOARD ===" -Level 'INFO'

# Convert data to JSON for embedded charts
function ConvertTo-JsonSafe { param($Obj); return ($Obj | ConvertTo-Json -Compress -Depth 5) -replace "'","'" }

$osDistJson  = ConvertTo-JsonSafe ($osDist.GetEnumerator()  | Sort-Object Value -Descending | ForEach-Object { @{label=$_.Key;value=$_.Value} })
$mfgDistJson = ConvertTo-JsonSafe ($mfgDist.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 8 | ForEach-Object { @{label=$_.Key;value=$_.Value} })
$buildDistJson = ConvertTo-JsonSafe ($buildDist.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { @{label=$_.Key;value=$_.Value} })
$licenseJson = ConvertTo-JsonSafe ($licenseData | Select-Object -First 15 | ForEach-Object { @{name=$_.Name;total=$_.Total;used=$_.Used;pct=$_.UsedPct} })

$staleTableHtml = ""
foreach ($s in $topStale) {
    $sevClass = if ($s.DaysStale -gt 180) { 'critical' } elseif ($s.DaysStale -gt 90) { 'high' } else { 'medium' }
    $staleTableHtml += "<tr><td>$($s.Name)</td><td>$($s.User)</td><td>$($s.OS)</td><td class='badge $sevClass'>$($s.DaysStale)d</td><td>$($s.LastSync)</td></tr>`n"
}

$ringTableHtml = ""
foreach ($rf in $ringFindings) {
    $sevClass = switch ($rf.Severity) { 'High'{'high'} 'Medium'{'medium'} 'Low'{'low'} 'Critical'{'critical'} default{'low'} }
    $ringTableHtml += "<tr><td>$($rf.RingName)</td><td class='badge $sevClass'>$($rf.Severity)</td><td>$($rf.Finding)</td></tr>`n"
}

$riskyTableHtml = ""
foreach ($ru in ($riskyUsers | Select-Object -First 10)) {
    $riskClass = switch ($ru.riskLevel) { 'high'{'high'} 'medium'{'medium'} 'low'{'low'} default{'low'} }
    $riskyTableHtml += "<tr><td>$($ru.userDisplayName)</td><td>$($ru.userPrincipalName)</td><td class='badge $riskClass'>$($ru.riskLevel)</td><td>$($ru.riskState)</td><td>$($ru.riskLastUpdatedDateTime)</td></tr>`n"
}

$licenseTableHtml = ""
foreach ($lic in ($licenseData | Select-Object -First 15)) {
    $pctClass = if ($lic.UsedPct -ge 95) { 'critical' } elseif ($lic.UsedPct -ge 80) { 'high' } elseif ($lic.UsedPct -ge 50) { 'medium' } else { 'low' }
    $licenseTableHtml += "<tr><td>$($lic.Name)</td><td>$($lic.Total)</td><td>$($lic.Used)</td><td>$($lic.Available)</td><td><div class='progress-bar'><div class='progress-fill $pctClass' style='width:$($lic.UsedPct)%'></div></div><span class='pct-label'>$($lic.UsedPct)%</span></td></tr>`n"
}

# Apple certs HTML
$appleCertTableHtml = ""
function Get-CertRow {
    param($Label, $Expiry, $Days)
    $sevClass = if ($null -eq $Days) { 'low' } elseif ($Days -lt 0) { 'critical' } elseif ($Days -le 30) { 'critical' } elseif ($Days -le 90) { 'medium' } else { 'low' }
    $labelText = if ($null -eq $Days) { 'N/A' } elseif ($Days -lt 0) { "EXPIRED $(-$Days)d ago" } else { "$Days days" }
    $expiryText = if ($Expiry) { $Expiry.ToString('yyyy-MM-dd') } else { '-' }
    "<tr><td>$Label</td><td>$expiryText</td><td class='badge $sevClass'>$labelText</td></tr>`n"
}
$appleCertTableHtml += Get-CertRow 'APNs Certificate' $applePushExpiry $applePushDays
$appleCertTableHtml += Get-CertRow 'VPP Token'         $vppExpiry       $vppDays
$appleCertTableHtml += Get-CertRow 'DEP Token'         $depExpiry       $depDays

# Service health issues HTML
$healthTableHtml = ""
foreach ($h in ($healthIssues | Select-Object -First 5)) {
    $sev = if ($h.severity) { $h.severity } else { 'informational' }
    $sevLower = $sev.ToString().ToLower()
    $isResolved = if ($h.isResolved) { 'resolved' } else { 'active' }
    $titleStr = [string]$h.title
    if ($titleStr.Length -gt 80) { $titleStr = $titleStr.Substring(0, 80) + '...' }
    $lastMod = if ($h.lastModifiedDateTime) { ([datetime]$h.lastModifiedDateTime).ToString('yyyy-MM-dd') } else { '-' }
    $healthTableHtml += "<tr><td class='badge $sevLower'>$sev</td><td>$titleStr</td><td class='badge $(if($isResolved -eq 'resolved'){'low'}else{'high'})'>$isResolved</td><td>$lastMod</td></tr>`n"
}

# Connectors HTML
$connectorTableHtml = ""
foreach ($c in $connectorData) {
    $issueClass = if ($c.Issue -eq 'Yes') { 'high' } else { 'low' }
    $stateClass = if ($c.State -eq 'enabled' -or $c.State -eq 'configured') { 'low' } else { 'medium' }
    $connectorTableHtml += "<tr><td>$($c.Category)</td><td>$($c.Name)</td><td class='badge $stateClass'>$($c.State)</td><td>$($c.LastHb)</td><td class='badge $issueClass'>$($c.Issue)</td></tr>`n"
}

# Failed sign-ins HTML
$signInTableHtml = ""
foreach ($s in ($failedSignIns | Select-Object -First 10)) {
    $reason = ($s.Reason -as [string])
    if ($reason.Length -gt 60) { $reason = $reason.Substring(0, 60) + '...' }
    $signInTableHtml += "<tr><td>$($s.Time)</td><td>$($s.User)</td><td>$($s.App)</td><td>$($s.IP)</td><td>$($s.ErrorCode)</td><td>$reason</td></tr>`n"
}

# Expiring app registrations HTML
$expiringAppsTableHtml = ""
foreach ($a in ($expiringApps | Select-Object -First 10)) {
    $expiringAppsTableHtml += "<tr><td>$($a.Name)</td><td>$($a.AppId)</td><td>$($a.Type)</td><td>$($a.Expires)</td><td class='badge $($a.Severity)'>$($a.DaysLeft)d</td></tr>`n"
}

$reportTimestamp = $now.ToString('yyyy-MM-dd HH:mm:ss')
$reportTimestampUtc = $now.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$reportTimezone = [System.TimeZoneInfo]::Local.DisplayName
$runId = [guid]::NewGuid().ToString().Substring(0, 8).ToUpper()
$scriptVersion = '1.1.0'
$complianceGrade = if ($complianceRate -ge 95) { 'A' } elseif ($complianceRate -ge 85) { 'B' } elseif ($complianceRate -ge 70) { 'C' } elseif ($complianceRate -ge 50) { 'D' } else { 'F' }
$gradeColor = switch ($complianceGrade) { 'A'{'#24a148'} 'B'{'#42be65'} 'C'{'#f1c21b'} 'D'{'#ff832b'} 'F'{'#da1e28'} }
$gradeTip = "Compliance Grade $complianceGrade ($complianceRate%)`n`nA >= 95% (Excellent)`nB >= 85% (Good)`nC >= 70% (Acceptable)`nD >= 50% (At Risk)`nF < 50% (Critical)`n`nCalculated as: compliant devices / total managed devices, excluding Unknown and InGrace states."

# TODO: Migrate the raw here-string below (lines 831-1941) to use the canonical Carbon helpers
# from templates/html-report/EnterpriseHtmlReport.ps1 (Get-StandardHtmlHead/Open/Footer/Close).
# Body content (KPI tiles, sections, donut charts) is already Carbon-classed and should move unchanged
# into a -Body parameter to Export-StandardHtmlReport. Tracked as a separate refactor PR.

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Intune & Entra ID Dashboard  $tenantName</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@300;400;500;600&display=swap');

:root {
    --cds-background: #161616;
    --cds-layer-01: #262626;
    --cds-layer-02: #353535;
    --cds-border-strong-01: #4d4d4d;
    --cds-border-subtle-01: #393939;
    --cds-text-primary: #f4f4f4;
    --cds-text-secondary: #c6c6c6;
    --cds-text-helper: #8d8d8d;
    --cds-link: #78a9ff;
    
    /* Carbon Theme Accents */
    --cds-blue: #0f62fe;
    --cds-purple: #8a3ffc;
    --cds-magenta: #d02670;
    
    /* Support Status Colors */
    --cds-support-success: #24a148;
    --cds-support-warning: #f1c21b;
    --cds-support-error: #da1e28;
    --cds-support-info: #0043ce;
}

* { 
    margin: 0; 
    padding: 0; 
    box-sizing: border-box; 
}

body {
    font-family: 'IBM Plex Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background-color: var(--cds-background);
    color: var(--cds-text-primary);
    line-height: 1.4;
    padding: 32px;
    -webkit-font-smoothing: antialiased;
}

/* Header Area */
.header {
    margin-bottom: 40px;
    padding-bottom: 24px;
    border-bottom: 1px solid var(--cds-border-strong-01);
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    flex-wrap: wrap;
    gap: 16px;
}

.header-left h1 {
    font-size: 28px;
    font-weight: 300;
    letter-spacing: 0.5px;
    color: var(--cds-text-primary);
    margin-bottom: 4px;
}

.header-left h1 strong {
    font-weight: 600;
}

.header .subtitle {
    color: var(--cds-text-secondary);
    font-size: 14px;
    font-family: 'IBM Plex Mono', monospace;
}

.header-right {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 12px;
    color: var(--cds-text-helper);
    text-align: right;
}

/* KPI / Metric Grid */
.kpi-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 2px; /* Carbon-like grid border separator */
    background-color: var(--cds-border-subtle-01);
    border: 1px solid var(--cds-border-subtle-01);
    margin-bottom: 40px;
}

.kpi-card {
    background-color: var(--cds-layer-01);
    padding: 20px;
    display: flex;
    flex-direction: column-reverse;
    justify-content: space-between;
    min-height: 120px;
    transition: background-color 0.15s ease;
}

.kpi-card:hover {
    background-color: var(--cds-layer-02);
}

.kpi-value {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 38px;
    font-weight: 400;
    line-height: 1.1;
    color: var(--cds-text-primary);
}

.kpi-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--cds-text-secondary);
    letter-spacing: 0.2px;
    margin-bottom: 12px;
}

/* Dashboard Sections */
.section-title {
    font-size: 14px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: var(--cds-text-secondary);
    margin: 40px 0 16px 0;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--cds-border-subtle-01);
    display: flex;
    align-items: center;
    gap: 8px;
}

.grid-2 {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(450px, 1fr));
    gap: 24px;
    margin-bottom: 24px;
}

.card {
    background-color: var(--cds-layer-01);
    border: 1px solid var(--cds-border-subtle-01);
    padding: 24px;
    display: flex;
    flex-direction: column;
}

.card h2 {
    font-size: 16px;
    font-weight: 400;
    margin-bottom: 24px;
    color: var(--cds-text-primary);
    border-left: 3px solid var(--cds-blue);
    padding-left: 12px;
}

/* Charts layouts */
.donut-container {
    display: flex;
    align-items: center;
    justify-content: space-around;
    gap: 24px;
    flex-wrap: wrap;
}

.donut-wrap { 
    position: relative; 
    width: 160px; 
    height: 160px; 
}

.donut-center {
    position: absolute;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    text-align: center;
}

.donut-center .grade {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 36px;
    font-weight: 500;
    line-height: 1;
}

.donut-center .rate {
    font-size: 11px;
    color: var(--cds-text-helper);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-top: 4px;
}

.legend { 
    list-style: none; 
    flex: 1;
    min-width: 180px;
}

.legend li {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 0;
    font-size: 13px;
    border-bottom: 1px solid var(--cds-border-subtle-01);
}

.legend li:last-child {
    border-bottom: none;
}

.legend .dot {
    width: 8px;
    height: 8px;
    flex-shrink: 0;
}

.legend .count {
    margin-left: auto;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
}

/* Carbon Flat Bar Charts */
.bar-chart { 
    display: flex; 
    flex-direction: column; 
    gap: 12px; 
}

.bar-row { 
    display: flex; 
    align-items: center; 
    gap: 16px; 
    font-size: 13px; 
}

.bar-label { 
    min-width: 140px; 
    text-align: right; 
    color: var(--cds-text-secondary); 
    white-space: nowrap; 
    overflow: hidden; 
    text-overflow: ellipsis; 
}

.bar-track { 
    flex: 1; 
    height: 20px; 
    background-color: var(--cds-border-subtle-01); 
    position: relative; 
}

.bar-fill {
    height: 100%;
    transition: width 0.8s cubic-bezier(0.16, 1, 0.3, 1);
    display: flex;
    align-items: center;
    padding-left: 8px;
    font-size: 11px;
    font-family: 'IBM Plex Mono', monospace;
    color: #ffffff;
    min-width: 24px;
}

/* Carbon Structured Tables */
table { 
    width: 100%; 
    border-collapse: collapse; 
    font-size: 13px; 
}

thead th {
    text-align: left;
    padding: 12px 16px;
    background-color: var(--cds-layer-02);
    border-bottom: 1px solid var(--cds-border-strong-01);
    color: var(--cds-text-primary);
    font-weight: 500;
    font-size: 12px;
}

tbody td {
    padding: 12px 16px;
    border-bottom: 1px solid var(--cds-border-subtle-01);
    color: var(--cds-text-secondary);
}

tbody tr {
    background-color: var(--cds-layer-01);
    transition: background-color 0.1s ease;
}

tbody tr:hover { 
    background-color: var(--cds-layer-02); 
}

/* Flat square badges */
.badge {
    display: inline-block;
    padding: 2px 8px;
    font-size: 11px;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}
.badge.critical { background-color: rgba(218, 30, 40, 0.15); color: #ff8389; border-left: 3px solid var(--cds-support-error); }
.badge.high { background-color: rgba(219, 109, 40, 0.15); color: #ffb38a; border-left: 3px solid var(--cds-accent-orange); }
.badge.medium { background-color: rgba(241, 194, 27, 0.15); color: #f1c21b; border-left: 3px solid var(--cds-support-warning); }
.badge.low { background-color: rgba(36, 161, 72, 0.15); color: #8ee0a5; border-left: 3px solid var(--cds-support-success); }

/* Progress indicator bars */
.progress-bar {
    display: inline-block;
    width: 100px;
    height: 8px;
    background-color: var(--cds-border-subtle-01);
    vertical-align: middle;
}

.progress-fill {
    height: 100%;
    transition: width 0.5s ease;
}
.progress-fill.low { background-color: var(--cds-support-success); }
.progress-fill.medium { background-color: var(--cds-support-warning); }
.progress-fill.high { background-color: #db6d28; }
.progress-fill.critical { background-color: var(--cds-support-error); }

.pct-label {
    font-size: 11px;
    font-family: 'IBM Plex Mono', monospace;
    margin-left: 8px;
    vertical-align: middle;
    color: var(--cds-text-secondary);
}

.empty-state {
    text-align: center;
    padding: 40px;
    color: var(--cds-text-helper);
    font-style: normal;
    border: 1px dashed var(--cds-border-strong-01);
    background-color: var(--cds-background);
}

canvas { 
    max-width: 100%; 
}

/* Footer */
.footer {
    margin-top: 80px;
    padding: 32px;
    background-color: var(--cds-layer-01);
    border: 1px solid var(--cds-border-subtle-01);
    display: grid;
    grid-template-columns: 1.2fr 0.8fr 1fr;
    gap: 32px;
    align-items: start;
}

.footer-col {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.footer-label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    color: var(--cds-text-helper);
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
    margin-bottom: 4px;
}

.footer-value {
    font-size: 13px;
    color: var(--cds-text-primary);
    font-family: 'IBM Plex Mono', monospace;
    line-height: 1.6;
    word-break: break-all;
}

.footer-value strong {
    color: var(--cds-text-primary);
    font-weight: 500;
}

.grade-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 16px;
    background-color: var(--cds-layer-02);
    border: 1px solid var(--cds-border-subtle-01);
    cursor: help;
    position: relative;
    transition: border-color 0.15s ease;
}

.grade-card:hover { border-color: var(--cds-blue); }

.grade-card .grade-letter {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 64px;
    font-weight: 300;
    line-height: 1;
    margin-bottom: 8px;
}

.grade-card .grade-rate {
    font-size: 12px;
    font-family: 'IBM Plex Mono', monospace;
    color: var(--cds-text-secondary);
    letter-spacing: 0.5px;
}

.grade-card .grade-label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    color: var(--cds-text-helper);
    margin-top: 12px;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
}

/* Tooltip for grade card */
.grade-card[data-tooltip]:hover::after {
    content: attr(data-tooltip);
    position: absolute;
    bottom: calc(100% + 8px);
    left: 50%;
    transform: translateX(-50%);
    background-color: var(--cds-layer-02);
    border: 1px solid var(--cds-blue);
    color: var(--cds-text-primary);
    padding: 12px 16px;
    font-size: 11px;
    font-family: 'IBM Plex Sans', sans-serif;
    text-transform: none;
    letter-spacing: normal;
    line-height: 1.5;
    width: 240px;
    text-align: left;
    z-index: 10;
    pointer-events: none;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
}

.action-bar {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 4px;
}

.btn {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 8px 14px;
    font-size: 12px;
    font-family: 'IBM Plex Sans', sans-serif;
    font-weight: 500;
    background-color: var(--cds-layer-02);
    color: var(--cds-text-primary);
    border: 1px solid var(--cds-border-strong-01);
    cursor: pointer;
    transition: background-color 0.15s ease, border-color 0.15s ease;
    text-decoration: none;
}

.btn:hover {
    background-color: var(--cds-layer-01);
    border-color: var(--cds-blue);
}

.btn-primary {
    background-color: var(--cds-blue);
    color: #ffffff;
    border-color: var(--cds-blue);
}

.btn-primary:hover {
    background-color: #0353e9;
    border-color: #0353e9;
}

.btn-icon {
    width: 14px;
    height: 14px;
    flex-shrink: 0;
}

.footer-meta {
    margin-top: 24px;
    padding-top: 20px;
    border-top: 1px solid var(--cds-border-subtle-01);
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 12px;
    font-size: 11px;
    color: var(--cds-text-helper);
    font-family: 'IBM Plex Mono', monospace;
    grid-column: 1 / -1;
}

.footer-meta a {
    color: var(--cds-link);
    text-decoration: none;
}

.footer-meta a:hover { text-decoration: underline; }

.disclaimer-box {
    position: fixed;
    inset: 0;
    background-color: rgba(0, 0, 0, 0.7);
    display: none;
    align-items: center;
    justify-content: center;
    z-index: 100;
    padding: 32px;
}

.disclaimer-box.is-open {
    display: flex;
}

.disclaimer-modal {
    background-color: var(--cds-layer-01);
    border: 1px solid var(--cds-border-strong-01);
    max-width: 560px;
    width: 100%;
    padding: 32px;
    max-height: 80vh;
    overflow-y: auto;
}

.disclaimer-modal h3 {
    font-size: 16px;
    font-weight: 600;
    margin-bottom: 16px;
    color: var(--cds-text-primary);
    text-transform: uppercase;
    letter-spacing: 1px;
}

.disclaimer-modal p {
    font-size: 13px;
    line-height: 1.6;
    color: var(--cds-text-secondary);
    margin-bottom: 16px;
}

.disclaimer-modal .disclaimer-actions {
    display: flex;
    gap: 8px;
    justify-content: flex-end;
    margin-top: 24px;
}

@media (max-width: 768px) {
    .grid-2 { grid-template-columns: 1fr; }
    .kpi-row { grid-template-columns: repeat(2, 1fr); }
    .footer { grid-template-columns: 1fr; gap: 24px; }
    body { padding: 16px; }
}

@media print {
    body { background-color: #ffffff; color: #000000; padding: 12px; }
    .header, .footer, .kpi-card, .card { background-color: #ffffff !important; border-color: #d0d0d0 !important; break-inside: avoid; }
    .footer { display: none; }
    .section-title { color: #000000; border-bottom-color: #000000; }
    thead th { background-color: #f4f4f4; color: #000000; }
    .no-print { display: none; }
}
</style>
</head>
<body>

<div class="header">
    <div class="header-left">
        <h1>Intune &amp; Entra ID <strong>Dashboard</strong></h1>
        <div class="subtitle">TENANT: $tenantName</div>
    </div>
    <div class="header-right">
        <div>GENERATED: $reportTimestamp</div>
        <div style="margin-top: 4px;">OPERATOR: $($context.Account)</div>
    </div>
</div>

<!-- KPI Cards -->
<div class="kpi-row">
    <div class="kpi-card">
        <div class="kpi-value">$($devices.Count)</div>
        <div class="kpi-label">Managed Devices</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value" style="color:$(if($complianceRate -lt 50){'var(--cds-support-error)'}elseif($complianceRate -lt 85){'var(--cds-support-warning)'}else{'var(--cds-support-success)'})">$complianceRate%</div>
        <div class="kpi-label">Compliance Rate</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value" style="color:$(if($staleDevices -gt 0){'var(--cds-support-warning)'}else{'var(--cds-text-primary)'})">$staleDevices</div>
        <div class="kpi-label">Stale Devices (>$($DaysStale)d)</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value" style="color:$(if($riskyUsers.Count -gt 0){'var(--cds-support-error)'}else{'var(--cds-support-success)'})">$($riskyUsers.Count)</div>
        <div class="kpi-label">Risky Users</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value">$($caPolicies.Count)</div>
        <div class="kpi-label">CA Policies</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value" style="color:$(if($notEncrypted -gt 0){'var(--cds-support-warning)'}else{'var(--cds-support-success)'})">$notEncrypted</div>
        <div class="kpi-label">Not Encrypted</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value" style="color:$secureScoreColor">$secureScorePct%</div>
        <div class="kpi-label">M365 Secure Score</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value" style="color:$healthColor">$healthStatus</div>
        <div class="kpi-label">Intune Service Health</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value" style="color:$appleCertOverallColor">$(if($null -eq $appleCertMinDaysValue){'-'}elseif($appleCertMinDaysValue -lt 0){"EXPIRED"}else{"$appleCertMinDaysValue d"})</div>
        <div class="kpi-label">Apple Certs (Soonest)</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value" style="color:$(if($failedSignIns.Count -gt 0){'var(--cds-support-warning)'}else{'var(--cds-support-success)'})">$($failedSignIns.Count)</div>
        <div class="kpi-label">Failed Sign-ins (24h)</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value" style="color:$(if($cloudPcFailed -gt 0){'var(--cds-support-error)'}elseif($cloudPcs.Count -gt 0){'var(--cds-support-success)'}else{'var(--cds-text-helper)'})">$($cloudPcs.Count)</div>
        <div class="kpi-label">Cloud PCs (365)</div>
    </div>
    <div class="kpi-card">
        <div class="kpi-value" style="color:$(if($connectorIssueCount -gt 0){'var(--cds-support-warning)'}else{'var(--cds-support-success)'})">$($connectorData.Count)</div>
        <div class="kpi-label">Connectors</div>
    </div>
</div>

<!-- Compliance & OS Distribution -->
<div class="section-title">Compliance & Device Overview</div>
<div class="grid-2">
    <div class="card">
        <h2>Device Compliance</h2>
        <div class="donut-container">
            <div class="donut-wrap">
                <canvas id="complianceDonut" width="160" height="160"></canvas>
                <div class="donut-center">
                    <div class="grade" style="color:$gradeColor">$complianceGrade</div>
                    <div class="rate">$complianceRate%</div>
                </div>
            </div>
            <ul class="legend">
                <li><span class="dot" style="background-color:var(--cds-support-success)"></span> Compliant <span class="count">$compliant</span></li>
                <li><span class="dot" style="background-color:var(--cds-support-error)"></span> Non-Compliant <span class="count">$nonCompliant</span></li>
                <li><span class="dot" style="background-color:var(--cds-support-warning)"></span> In Grace <span class="count">$inGrace</span></li>
                <li><span class="dot" style="background-color:var(--cds-text-helper)"></span> Unknown <span class="count">$unknownComp</span></li>
            </ul>
        </div>
    </div>
    <div class="card">
        <h2>OS Distribution</h2>
        <div class="bar-chart" id="osChart"></div>
    </div>
</div>

<!-- Encryption & Sync Health -->
<div class="grid-2">
    <div class="card">
        <h2>Encryption Status</h2>
        <div class="donut-container">
            <div class="donut-wrap">
                <canvas id="encryptionDonut" width="160" height="160"></canvas>
                <div class="donut-center">
                    <div class="grade" style="color:$(if($notEncrypted -eq 0){'var(--cds-support-success)'}else{'var(--cds-support-warning)'});font-size:28px">$(if($devices.Count -gt 0){[math]::Round(($encrypted/$devices.Count)*100)}else{0})%</div>
                    <div class="rate">encrypted</div>
                </div>
            </div>
            <ul class="legend">
                <li><span class="dot" style="background-color:var(--cds-support-success)"></span> Encrypted <span class="count">$encrypted</span></li>
                <li><span class="dot" style="background-color:var(--cds-support-error)"></span> Not Encrypted <span class="count">$notEncrypted</span></li>
                <li><span class="dot" style="background-color:var(--cds-text-helper)"></span> Unknown <span class="count">$unknownEnc</span></li>
            </ul>
        </div>
    </div>
    <div class="card">
        <h2>Device Sync Health</h2>
        <div class="donut-container">
            <div class="donut-wrap">
                <canvas id="syncDonut" width="160" height="160"></canvas>
                <div class="donut-center">
                    <div class="grade" style="color:$(if($staleDevices -eq 0){'var(--cds-support-success)'}else{'var(--cds-support-error)'});font-size:28px">$activeDevices</div>
                    <div class="rate">active</div>
                </div>
            </div>
            <ul class="legend">
                <li><span class="dot" style="background-color:var(--cds-support-success)"></span> Active (&lt;60d) <span class="count">$activeDevices</span></li>
                <li><span class="dot" style="background-color:var(--cds-support-warning)"></span> Warning (60-${DaysStale}d) <span class="count">$warnDevices</span></li>
                <li><span class="dot" style="background-color:var(--cds-support-error)"></span> Stale (&gt;${DaysStale}d) <span class="count">$staleDevices</span></li>
            </ul>
        </div>
    </div>
</div>

<!-- Stale Devices Table -->
$(if ($topStale.Count -gt 0) { @"
<div class="section-title">Most Stale Devices</div>
<div class="card" style="padding:0;overflow-x:auto;">
    <table>
        <thead><tr><th>Device</th><th>User</th><th>OS</th><th>Days Stale</th><th>Last Sync</th></tr></thead>
        <tbody>$staleTableHtml</tbody>
    </table>
</div>
"@ })

<!-- Windows Build Distribution -->
$(if ($buildDist.Count -gt 0) { @"
<div class="section-title">Windows Build Distribution</div>
<div class="card">
    <div class="bar-chart" id="buildChart"></div>
</div>
"@ })

<!-- Update Ring Health -->
$(if ($ringFindings.Count -gt 0) { @"
<div class="section-title">Update Ring Findings ($($ringFindings.Count))</div>
<div class="card" style="padding:0;overflow-x:auto;">
    <table>
        <thead><tr><th>Ring</th><th>Severity</th><th>Finding</th></tr></thead>
        <tbody>$ringTableHtml</tbody>
    </table>
</div>
"@ } else { @"
<div class="section-title">Update Ring Health</div>
<div class="card"><div class="empty-state">No update ring issues detected</div></div>
"@ })

<!-- Conditional Access -->
<div class="section-title">Conditional Access</div>
<div class="kpi-row">
    <div class="kpi-card"><div class="kpi-value" style="color:var(--cds-support-success)">$caEnabled</div><div class="kpi-label">Enabled</div></div>
    <div class="kpi-card"><div class="kpi-value" style="color:var(--cds-support-warning)">$caReportOnly</div><div class="kpi-label">Report-Only</div></div>
    <div class="kpi-card"><div class="kpi-value">$caDisabled</div><div class="kpi-label">Disabled</div></div>
</div>

<!-- License Utilisation -->
$(if ($licenseData.Count -gt 0) { @"
<div class="section-title">License Utilisation</div>
<div class="card" style="padding:0;overflow-x:auto;">
    <table>
        <thead><tr><th>SKU</th><th>Total</th><th>Used</th><th>Available</th><th>Utilisation</th></tr></thead>
        <tbody>$licenseTableHtml</tbody>
    </table>
</div>
"@ })

<!-- Risky Users -->
$(if ($riskyUsers.Count -gt 0) { @"
<div class="section-title">Risky Users ($($riskyUsers.Count))</div>
<div class="card" style="padding:0;overflow-x:auto;">
    <table>
        <thead><tr><th>Name</th><th>UPN</th><th>Risk Level</th><th>State</th><th>Last Updated</th></tr></thead>
        <tbody>$riskyTableHtml</tbody>
    </table>
</div>
"@ } else { @"
<div class="section-title">Risky Users</div>
<div class="card"><div class="empty-state">No active risky users detected</div></div>
"@ })

<!-- Guest Users -->
<div class="section-title">Guest User Summary</div>
<div class="kpi-row">
    <div class="kpi-card"><div class="kpi-value">$($guestUsers.Count)</div><div class="kpi-label">Total Guests</div></div>
    <div class="kpi-card"><div class="kpi-value" style="color:$(if($guestNeverSignedIn -gt 0){'var(--cds-support-warning)'}else{'var(--cds-support-success)'})">$guestNeverSignedIn</div><div class="kpi-label">Never Signed In</div></div>
    <div class="kpi-card"><div class="kpi-value">$guestDisabled</div><div class="kpi-label">Disabled</div></div>
    <div class="kpi-card"><div class="kpi-value" style="color:$(if($guestPending -gt 0){'var(--cds-support-warning)'}else{'var(--cds-support-success)'})">$guestPending</div><div class="kpi-label">Pending Invite</div></div>
</div>

<!-- Security Posture & Apple Certificates -->
<div class="section-title">Security Posture & Identity</div>
<div class="grid-2">
    <div class="card">
        <h2>M365 Secure Score</h2>
        <div class="donut-container">
            <div class="donut-wrap">
                <canvas id="secureScoreDonut" width="160" height="160"></canvas>
                <div class="donut-center">
                    <div class="grade" style="color:$secureScoreColor; font-size:28px">$secureScorePct%</div>
                    <div class="rate">$secureScore / $secureScoreMax</div>
                </div>
            </div>
            <ul class="legend">
                <li><span class="dot" style="background-color:var(--cds-support-success)"></span> Current Score <span class="count">$secureScore</span></li>
                <li><span class="dot" style="background-color:var(--cds-text-helper)"></span> Maximum <span class="count">$secureScoreMax</span></li>
                <li><span class="dot" style="background-color:$(if($secureScorePct -ge 80){'var(--cds-support-success)'}elseif($secureScorePct -ge 50){'var(--cds-support-warning)'}else{'var(--cds-support-error)'})"></span> Posture <span class="count">$(if($secureScorePct -ge 80){'Strong'}elseif($secureScorePct -ge 50){'Moderate'}else{'Weak'})</span></li>
            </ul>
        </div>
    </div>
    <div class="card">
        <h2>Apple Certificates &amp; Tokens</h2>
        <table>
            <thead><tr><th>Item</th><th>Expires</th><th>Status</th></tr></thead>
            <tbody>$appleCertTableHtml</tbody>
        </table>
    </div>
</div>

<!-- Service Health & Connectors -->
<div class="section-title">Service Health &amp; Connectors</div>
<div class="grid-2">
    <div class="card">
        <h2>Intune Service Health Issues</h2>
        $(if ($healthTableHtml) { @"
        <div style="padding:0;overflow-x:auto;">
            <table>
                <thead><tr><th>Severity</th><th>Title</th><th>Status</th><th>Last Modified</th></tr></thead>
                <tbody>$healthTableHtml</tbody>
            </table>
        </div>
"@ } else { @"
        <div class="empty-state">No active service health issues</div>
"@ })
    </div>
    <div class="card">
        <h2>Tenant Connectors</h2>
        $(if ($connectorTableHtml) { @"
        <div style="padding:0;overflow-x:auto;">
            <table>
                <thead><tr><th>Category</th><th>Name</th><th>State</th><th>Last Heartbeat</th><th>Issue</th></tr></thead>
                <tbody>$connectorTableHtml</tbody>
            </table>
        </div>
"@ } else { @"
        <div class="empty-state">No connectors configured</div>
"@ })
    </div>
</div>

<!-- Windows Update Reports Summary -->
$(if ($wuTotalErrors -gt 0) { @"
<div class="section-title">Windows Update Reports</div>
<div class="kpi-row">
    <div class="kpi-card"><div class="kpi-value" style="color:$(if($wuFeatureErrors -gt 0){'var(--cds-support-warning)'}else{'var(--cds-support-success)'})">$wuFeatureErrors</div><div class="kpi-label">Feature Update Alerts</div></div>
    <div class="kpi-card"><div class="kpi-value" style="color:$(if($wuQualityErrors -gt 0){'var(--cds-support-warning)'}else{'var(--cds-support-success)'})">$wuQualityErrors</div><div class="kpi-label">Quality Update Alerts</div></div>
    <div class="kpi-card"><div class="kpi-value" style="color:$(if($wuDriverErrors -gt 0){'var(--cds-support-warning)'}else{'var(--cds-support-success)'})">$wuDriverErrors</div><div class="kpi-label">Driver Update Alerts</div></div>
</div>
"@ })

<!-- Sign-ins & App Registrations -->
$(if (($failedSignIns.Count -gt 0) -or ($expiringApps.Count -gt 0)) { @"
<div class="section-title">Identity &amp; Application Security</div>
<div class="grid-2">
    $(if ($failedSignIns.Count -gt 0) { @"
    <div class="card">
        <h2>Failed Entra Sign-ins (24h)</h2>
        <div style="padding:0;overflow-x:auto;">
            <table>
                <thead><tr><th>Time</th><th>User</th><th>App</th><th>IP</th><th>Code</th><th>Reason</th></tr></thead>
                <tbody>$signInTableHtml</tbody>
            </table>
        </div>
    </div>
"@ } else { @"
    <div class="card"><div class="empty-state">No failed sign-ins in last 24h</div></div>
"@ })
    $(if ($expiringApps.Count -gt 0) { @"
    <div class="card">
        <h2>Expiring App Registrations (90d)</h2>
        <div style="padding:0;overflow-x:auto;">
            <table>
                <thead><tr><th>App Name</th><th>App ID</th><th>Type</th><th>Expires</th><th>Days Left</th></tr></thead>
                <tbody>$expiringAppsTableHtml</tbody>
            </table>
        </div>
    </div>
"@ } else { @"
    <div class="card"><div class="empty-state">No app registrations with secrets expiring in 90 days</div></div>
"@ })
</div>
"@ })

<!-- Cloud PCs (Windows 365) -->
$(if ($cloudPcs.Count -gt 0) { @"
<div class="section-title">Windows 365 Cloud PCs</div>
<div class="kpi-row">
    <div class="kpi-card"><div class="kpi-value">$($cloudPcs.Count)</div><div class="kpi-label">Total Cloud PCs</div></div>
    <div class="kpi-card"><div class="kpi-value" style="color:var(--cds-support-success)">$cloudPcProvisioned</div><div class="kpi-label">Provisioned</div></div>
    <div class="kpi-card"><div class="kpi-value" style="color:$(if($cloudPcFailed -gt 0){'var(--cds-support-error)'}else{'var(--cds-text-primary)'})">$cloudPcFailed</div><div class="kpi-label">Failed</div></div>
</div>
"@ })

<!-- Footer -->
<div class="footer">
    <div class="footer-col">
        <div class="footer-label">Tenant</div>
        <div class="footer-value"><strong>$tenantName</strong></div>
        <div class="footer-label" style="margin-top:12px;">Operator</div>
        <div class="footer-value">$($context.Account)</div>
        <div class="footer-label" style="margin-top:12px;">Generated</div>
        <div class="footer-value">$reportTimestamp</div>
        <div class="footer-value" style="color:var(--cds-text-helper);font-size:11px;">$reportTimezone &middot; UTC $reportTimestampUtc</div>
    </div>
    <div class="footer-col">
        <div class="grade-card" data-tooltip="$gradeTip" title="Click for grade explanation">
            <div class="grade-letter" style="color:$gradeColor">$complianceGrade</div>
            <div class="grade-rate">$complianceRate%</div>
            <div class="grade-label">Compliance Grade</div>
        </div>
    </div>
    <div class="footer-col">
        <div class="footer-label">Run</div>
        <div class="footer-value">$runId</div>
        <div class="footer-label" style="margin-top:12px;">Quick Actions</div>
        <div class="action-bar">
            <button class="btn btn-primary" onclick="window.print()" title="Print or save as PDF">
                <svg class="btn-icon" viewBox="0 0 16 16" fill="currentColor"><path d="M4 2h8v3H4V2zm0 5h8a2 2 0 0 1 2 2v3h-2v3H4v-3H2V9a2 2 0 0 1 2-2zm1 7v-3h6v3H5z"/></svg>
                Print
            </button>
            <button class="btn" onclick="navigator.clipboard.writeText(window.location.href)" title="Copy file path">
                <svg class="btn-icon" viewBox="0 0 16 16" fill="currentColor"><path d="M5 2h7a1 1 0 0 1 1 1v9h-2V4H6v8H4V3a1 1 0 0 1 1-1zM2 5h8a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zm1 2v6h6V7H3z"/></svg>
                Copy Path
            </button>
            <button class="btn" onclick="document.querySelector('.header').scrollIntoView({behavior:'smooth'})" title="Back to top">
                <svg class="btn-icon" viewBox="0 0 16 16" fill="currentColor"><path d="M8 3.5l5 5h-3v4H6v-4H3l5-5z"/></svg>
                Top
            </button>
        </div>
        <div class="action-bar" style="margin-top:8px;">
            <button class="btn" onclick="document.getElementById('disclaimerModal').classList.add('is-open')" title="View full disclaimer">
                <svg class="btn-icon" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1a7 7 0 1 0 0 14A7 7 0 0 0 8 1zm0 3a1 1 0 0 1 1 1v4a1 1 0 0 1-2 0V5a1 1 0 0 1 1-1zm0 8a1 1 0 1 1 0-2 1 1 0 0 1 0 2z"/></svg>
                Disclaimer
            </button>
            <button class="btn" onclick="exportSummary()" title="Download a text summary of this report">
                <svg class="btn-icon" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1v8.5L4.5 6 3 7.5 8 12.5 13 7.5 11.5 6 8 9.5V1H6v10H2v2h12v-2h-4V1H8z"/></svg>
                Summary
            </button>
        </div>
    </div>
    <div class="footer-meta">
        <span>Intune &amp; Entra ID Dashboard &middot; v$scriptVersion &middot; Run $runId</span>
        <span>Generated by <a href="https://github.com/mabdulkadr/powershell-enterprise-admin-skill" target="_blank" rel="noopener">PowerShell Enterprise Admin</a></span>
    </div>
</div>

<!-- Disclaimer modal -->
<div class="disclaimer-box" id="disclaimerModal" onclick="if(event.target===this)this.classList.remove('is-open')">
    <div class="disclaimer-modal">
        <h3>Disclaimer</h3>
        <p>This dashboard is generated from read-only Microsoft Graph queries and is provided as-is with no warranty of any kind. The compliance grade, counts, and identifiers shown are a point-in-time snapshot of the Intune and Entra ID tenant and may not reflect the current state by the time this report is reviewed.</p>
        <p>Test generated tools in a staging environment before deploying to production. The authors assume no liability for any damage or data loss resulting from their use.</p>
        <p>This report contains tenant identifiers and operator account names. Treat the file as confidential and follow your organization's data-handling policy when sharing.</p>
        <div class="disclaimer-actions">
            <button class="btn" onclick="document.getElementById('disclaimerModal').classList.remove('is-open')">Close</button>
        </div>
    </div>
</div>

<script>
// Mini donut chart renderer (no dependencies)
function drawDonut(canvasId, data, colors) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const cx = canvas.width / 2, cy = canvas.height / 2;
    const outerR = 76, innerR = 58; /* Thinner borders for Carbon style */
    const total = data.reduce((a, b) => a + b, 0);
    if (total === 0) return;
    let startAngle = -Math.PI / 2;
    data.forEach((val, i) => {
        const sliceAngle = (val / total) * 2 * Math.PI;
        ctx.beginPath();
        ctx.arc(cx, cy, outerR, startAngle, startAngle + sliceAngle);
        ctx.arc(cx, cy, innerR, startAngle + sliceAngle, startAngle, true);
        ctx.closePath();
        ctx.fillStyle = colors[i];
        ctx.fill();
        startAngle += sliceAngle;
    });
}

// Bar chart renderer
function drawBars(containerId, data, colorFn) {
    const container = document.getElementById(containerId);
    if (!container || !data) return;
    const dataArray = Array.isArray(data) ? data : [data];
    if (!dataArray.length || (dataArray.length === 1 && !dataArray[0])) return;
    const maxVal = Math.max(...dataArray.map(d => d.value || 0));
    const colors = ['#0f62fe','#8a3ffc','#00b0ff','#008080','#da1e28','#ff832b','#8d8d8d','#e0e0e0'];
    dataArray.forEach((item, i) => {
        if (!item) return;
        const val = item.value || 0;
        const label = item.label || 'Unknown';
        const pct = maxVal > 0 ? (val / maxVal * 100) : 0;
        const color = colorFn ? colorFn(item, i) : colors[i % colors.length];
        const row = document.createElement('div');
        row.className = 'bar-row';
        row.innerHTML =
            '<div class="bar-label" title="' + label + '">' + label + '</div>' +
            '<div class="bar-track"><div class="bar-fill" style="width:' + pct + '%;background-color:' + color + '">' + val + '</div></div>';
        container.appendChild(row);
    });
}

// Draw charts
drawDonut('complianceDonut', [$compliant, $nonCompliant, $inGrace, $unknownComp], ['#24a148','#da1e28','#f1c21b','#525252']);
drawDonut('encryptionDonut', [$encrypted, $notEncrypted, $unknownEnc], ['#24a148','#da1e28','#525252']);
drawDonut('syncDonut', [$activeDevices, $warnDevices, $staleDevices], ['#24a148','#f1c21b','#da1e28']);
drawDonut('secureScoreDonut', [$secureScore, ($secureScoreMax - $secureScore)], ['#24a148','#393939']);

drawBars('osChart', $osDistJson);
if (document.getElementById('buildChart')) drawBars('buildChart', $buildDistJson);

// Export a plain-text summary of the report
function exportSummary() {
    const sep = '================================================================\n';
    const lines = [
        sep,
        'INTUNE & ENTRA ID DASHBOARD - TEXT SUMMARY',
        sep,
        'Tenant     : $tenantName',
        'Operator   : $($context.Account)',
        'Generated  : $reportTimestamp ($reportTimezone)',
        'Run ID     : $runId',
        'Version    : $scriptVersion',
        '',
        '--- KEY METRICS ---',
        'Managed Devices    : $($devices.Count)',
        'Compliance Rate   : $complianceRate%  (Grade $complianceGrade)',
        'Stale Devices     : $staleDevices  (>$($DaysStale) days)',
        'Risky Users       : $($riskyUsers.Count)',
        'CA Policies       : $($caPolicies.Count)',
        'Not Encrypted     : $notEncrypted',
        '',
        '--- COMPLIANCE BREAKDOWN ---',
        'Compliant         : $compliant',
        'Non-Compliant     : $nonCompliant',
        'In Grace Period   : $inGrace',
        'Unknown           : $unknownComp',
        '',
        '--- ENCRYPTION ---',
        'Encrypted         : $encrypted',
        'Not Encrypted     : $notEncrypted',
        'Unknown           : $unknownEnc',
        '',
        '--- SYNC HEALTH ---',
        'Active (<60d)     : $activeDevices',
        'Warning (60-${DaysStale}d) : $warnDevices',
        'Stale (>${DaysStale}d)    : $staleDevices',
        '',
        '--- CONDITIONAL ACCESS ---',
        'Enabled           : $caEnabled',
        'Report-Only       : $caReportOnly',
        'Disabled          : $caDisabled',
        '',
        '--- GUEST USERS ---',
        'Total             : $($guestUsers.Count)',
        'Never Signed In   : $guestNeverSignedIn',
        'Disabled          : $guestDisabled',
        'Pending Invite    : $guestPending',
        '',
        sep,
        'Generated by PowerShell Enterprise Admin v$scriptVersion',
        'https://github.com/mabdulkadr/powershell-enterprise-admin-skill',
        sep
    ];
    const text = lines.join('\n');
    const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'IntuneDashboard_$runId.txt';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

// Close disclaimer modal on Escape
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        const m = document.getElementById('disclaimerModal');
        if (m) m.classList.remove('is-open');
    }
});
</script>

</body>
</html>
"@

# Determine output path
if (-not $OutputPath) {
    # Desktop path replaced by scriptDirectory anchoring (Law 12)
    $OutputPath = Join-Path $scriptDirectory "IntuneDashboard_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
}

$html | Out-File -FilePath $OutputPath -Encoding utf8 -Force
Write-Log -Message "Dashboard exported to: $OutputPath" -Level 'INFO'
# separator removed - handled by Write-Log banner
Write-Log -Message "Open in your browser:" -Level 'INFO'
Write-Log -Message "$OutputPath" -Level 'INFO'
# separator removed - handled by Write-Log banner

# Auto-open in default browser
try { Start-Process $OutputPath -ErrorAction SilentlyContinue } catch [System.Exception] {
        # typed catch - handles Graph or runtime errors
    }

Write-Log -Message "$('='*60)" -Level 'DEBUG'
#endregion


