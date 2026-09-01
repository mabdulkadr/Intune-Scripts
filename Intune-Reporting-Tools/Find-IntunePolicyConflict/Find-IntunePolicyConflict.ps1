<#
.TITLE
    Find-IntunePolicyConflict - Policy Conflict and Feature Impact Analyzer

.SYNOPSIS
    Troubleshoots Intune policy conflicts and feature side effects on a device with escalating modes.

.DESCRIPTION
    Three escalating modes verify policy health: Analyze finds Conflict/Error settings and overlapping CSP paths; Investigate X-rays every setting for a Windows feature area via dependency maps; Isolate guides a binary search with temporary assignment removals and restores all assignments at the end.

    Scope & safety:
    - Analyze/Investigate are read-only; Isolate makes temporary assignment changes only with guided restore.
    Degradation behavior:
    - Missing device or data logs a warning and exits gracefully without partial exports.
    Output contract:
    - Console tables plus optional CSV beside the script; exit 0 = success, 1 = failure.

.TAGS
    Troubleshooting,Intune,Policy,Graph

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All, DeviceManagementManagedDevices.Read.All, Device.Read.All, Directory.Read.All, Group.Read.All, GroupMember.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.1

.CHANGELOG
    1.0.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Find-IntunePolicyConflict.ps1 -DeviceName "L-PF4Z0HM0"
    Runs Analyze mode to find conflicts and errors.

.EXAMPLE
    .\Find-IntunePolicyConflict.ps1 -DeviceName "L-PF4Z0HM0" -Mode Investigate -Feature Hello
    X-rays every setting that could affect Windows Hello.

.EXAMPLE
    .\Find-IntunePolicyConflict.ps1 -DeviceName "L-PF4Z0HM0" -Mode Isolate
    Runs guided binary search to isolate the culprit policy.

.NOTES
    - Requires Microsoft.Graph.Authentication module.
    - Analyze/Investigate are read-only; Isolate temporarily modifies assignments.
    - Logs: C:\ProgramData\Find-IntunePolicyConflict\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DeviceName,

    [Parameter()]
    [ValidateSet('Analyze','Investigate','Isolate')]
    [string]$Mode = 'Analyze',

    [Parameter()]
    [string]$Feature,

    [Parameter()]
    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'Find-IntunePolicyConflict'
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
        [AllowEmptyString()]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

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

if ($PSBoundParameters.ContainsKey('ExportPath') -and $ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = Join-Path $scriptDirectory $ExportPath
}


# ============================================================================
# MAIN ENTRY LOGGING INITIALIZATION
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started: Find-IntunePolicyConflict" -Level 'INFO'



#region --- Feature Dependency Maps ---
# Each feature maps to keywords that appear in CSP paths, setting names, or OMA-URIs.
# A hardening policy may break a feature by touching ANY of these areas.
$featureMaps = @{
    'Hello' = @(
        'Hello', 'WHfB', 'WindowsHelloForBusiness', 'PassportForWork',
        'Biometric', 'Fingerprint', 'FacialRecognition', 'PIN', 'PinComplexity',
        'TPM', 'TrustedPlatformModule', 'NGC', 'CredentialProvider',
        'Passkey', 'FIDO', 'FIDO2', 'WebAuthn', 'SmartCard',
        'Kerberos', 'CloudKerberosTicket', 'DeviceRegistration',
        'KeyCredentialManager', 'EnrollmentStatusPage', 'CompanionDevice',
        'SecurityDevice', 'AllowDomainPINLogon', 'UseSecurityKeyForSignin',
        'EnablePinRecovery', 'RequireSecurityDevice'
    )
    'BitLocker' = @(
        'BitLocker', 'Encryption', 'EncryptionMethod', 'SystemDrivesRequireStartupAuthentication',
        'RequireDeviceEncryption', 'AllowWarningForOtherDiskEncryption',
        'FixedDrivesRecovery', 'SystemDrivesRecovery', 'RemovableDrivesRecovery',
        'EncryptionReportPolicy', 'TPM', 'StartupAuthentication',
        'RecoveryKey', 'RecoveryPassword', 'DiskEncryption',
        'AllowStandardUserEncryption', 'ConfigureRecoveryPasswordRotation',
        'SilentEncryption', 'VolumeDiskEncryption'
    )
    'Firewall' = @(
        'Firewall', 'MdmStore', 'FirewallRules', 'DomainProfile',
        'PrivateProfile', 'PublicProfile', 'EnableFirewall',
        'DisableInboundNotifications', 'DefaultInboundAction',
        'DefaultOutboundAction', 'Shielded', 'WindowsFirewall',
        'FirewallEnabled', 'StealthMode', 'AllowLocalPolicyMerge'
    )
    'Defender' = @(
        'Defender', 'Antivirus', 'AntiMalware', 'WindowsDefender',
        'RealTimeMonitoring', 'CloudProtection', 'SubmitSamplesConsent',
        'AttackSurfaceReduction', 'ASR', 'ControlledFolderAccess',
        'NetworkProtection', 'ExploitGuard', 'PUAProtection',
        'ScanSchedule', 'SignatureUpdate', 'TamperProtection',
        'EndpointDetection', 'EDR', 'SenseIsRunning', 'OnboardingState',
        'BehaviorMonitoring', 'DeviceControl', 'SmartScreen',
        'ExploitProtection', 'ScheduledScan'
    )
    'WiFi' = @(
        'WiFi', 'Wi-Fi', 'Wireless', 'WLAN', 'WLANSvc',
        'WirelessProfile', 'NetworkProfile', '802.1x', 'EAP',
        'SSID', 'WPA', 'WPA2', 'WPA3', 'NetworkAuthentication',
        'Proxy', 'DnsClient'
    )
    'VPN' = @(
        'VPN', 'AlwaysOn', 'VPNv2', 'RasMan', 'RemoteAccess',
        'Tunnel', 'SplitTunnel', 'PluginProfile', 'NativeProfile',
        'TrafficFilter', 'Route', 'DnsSuffix', 'Proxy',
        'TrustedNetworkDetection', 'DeviceTunnel'
    )
    'Edge' = @(
        'Edge', 'Browser', 'InternetExplorer', 'MicrosoftEdge',
        'ExtensionInstallForcelist', 'HomepageLocation',
        'PasswordManager', 'PopupBlocking', 'SmartScreen',
        'SSLErrorOverride', 'CookieBlocking', 'TrackingPrevention',
        'DefaultSearchProvider', 'ProxySettings', 'EnterpriseModeSiteList'
    )
    'OneDrive' = @(
        'OneDrive', 'KFM', 'KnownFolderMove', 'FilesOnDemand',
        'SilentAccountConfig', 'TenantId', 'AllowTenantList',
        'BlockTenantList', 'SyncClientUpdate', 'SharePoint',
        'PersonalVault', 'NetworkBandwidth'
    )
    'Updates' = @(
        'Update', 'WindowsUpdate', 'WUfB', 'QualityUpdate',
        'FeatureUpdate', 'DriverUpdate', 'DeliveryOptimization',
        'ActiveHoursStart', 'ActiveHoursEnd', 'DeferFeatureUpdates',
        'DeferQualityUpdates', 'PauseFeatureUpdates', 'PauseQualityUpdates',
        'BranchReadinessLevel', 'ScheduledInstall', 'AutoRestartRequired',
        'EngagedRestart', 'Telemetry', 'UpdateRing'
    )
    'Certificates' = @(
        'Certificate', 'SCEP', 'PKCS', 'RootCertificate', 'TrustedRoot',
        'ClientCertificate', 'CertificateStore', 'CertificateAuthority',
        'CredentialProvider', 'SmartCard', 'PIV'
    )
    'Proxy' = @(
        'Proxy', 'ProxyServer', 'ProxySettings', 'AutoConfigUrl',
        'PAC', 'WPAD', 'ProxySettingsPerUser', 'NetworkProxy'
    )
    'Encryption' = @(
        'Encryption', 'TLS', 'SSL', 'Cipher', 'SCHANNEL',
        'CryptographicProtocol', 'ClientAuthTrustMode'
    )
    'AppLocker' = @(
        'AppLocker', 'ApplicationControl', 'WDAC', 'CodeIntegrity',
        'SmartLocker', 'AllowedApps', 'BlockedApps', 'ManagedInstaller'
    )
}
#endregion

#region --- Helpers ---
function Write-Status { param([string]$Msg, [string]$Color = 'Cyan') ; Write-Host "  [$((Get-Date).ToString('HH:mm:ss'))] $Msg" -ForegroundColor $Color }
function Write-Section { param([string]$Msg) ; Write-Log -Message "`n$('='*60)" -Level 'DEBUG'; Write-Log -Message "  $Msg" -Level 'WARNING'; Write-Log -Message "$('='*60)" -Level 'DEBUG' }

function Get-MgGraphAllPages {
    param([string]$Uri, [string]$Method = 'GET')
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
    }
    catch [System.Exception] { # typed catch
        Write-Verbose "Graph call failed for $Uri : $_"
        return @()
    }
}

function Test-SettingMatchesFeature {
    param([string]$SettingPath, [string]$SettingName, [string]$PolicyName, [string[]]$Keywords)
    foreach ($kw in $Keywords) {
        if ($SettingPath -like "*$kw*" -or $SettingName -like "*$kw*" -or $PolicyName -like "*$kw*") {
            return $true
        }
    }
    return $false
}
#endregion

#region --- Authentication ---
Write-Log -Message "=== AUTHENTICATION ===" -Level 'INFO'
$requiredScopes = if ($Mode -eq 'Isolate') {
    @('DeviceManagementConfiguration.ReadWrite.All','DeviceManagementManagedDevices.Read.All','Device.Read.All','Directory.Read.All','Group.Read.All','GroupMember.Read.All')
} else {
    @('DeviceManagementConfiguration.Read.All','DeviceManagementManagedDevices.Read.All','Device.Read.All','Directory.Read.All')
}
$context = Get-MgContext
if (-not $context) {
    Write-Log -Message "Connecting to Microsoft Graph..." -Level 'INFO'
    Connect-MgGraph -Scopes $requiredScopes -ErrorAction Stop
    $context = Get-MgContext
}
Write-Log -Message "Signed in as: $($context.Account)" -Level 'SUCCESS'
#endregion

#region --- Resolve Device ---
Write-Log -Message "=== RESOLVING DEVICE ===" -Level 'INFO'
Write-Log -Message "Searching for device: $DeviceName" -Level 'INFO'
$devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$DeviceName'"
if ($devices.Count -eq 0) {
    Write-Log -Message "  ERROR: Device '$DeviceName' not found." -Level 'ERROR'
    return
}
$device = $devices[0]
$managedDeviceId = $device.id

Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Device Name      : $($device.deviceName)" -Level 'INFO'
Write-Log -Message "  OS               : $($device.operatingSystem) $($device.osVersion)" -Level 'INFO'
Write-Log -Message "  User             : $($device.userPrincipalName)" -Level 'INFO'
Write-Host "  Compliance       : $($device.complianceState)" -ForegroundColor $(if($device.complianceState -eq 'compliant'){'Green'}elseif($device.complianceState -eq 'conflict'){'Red'}else{'Yellow'})
Write-Log -Message "  Last Sync        : $($device.lastSyncDateTime)" -Level 'INFO'
#endregion

if ($Mode -eq 'Analyze') {
    #region --- Analyze Mode ---
    Write-Log -Message "=== MODE: ANALYZE (finding conflicts and errors) ===" -Level 'INFO'

    Write-Log -Message "Fetching device configuration policy states..." -Level 'INFO'
    $configStates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$managedDeviceId/deviceConfigurationStates"
    Write-Log -Message "Found $($configStates.Count) configuration policy states" -Level 'INFO'

    Write-Log -Message "Fetching compliance policy states..." -Level 'INFO'
    $complianceStates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$managedDeviceId/deviceCompliancePolicyStates"
    Write-Log -Message "Found $($complianceStates.Count) compliance policy states" -Level 'INFO'

    Write-Log -Message "Fetching tenant-level conflict summary..." -Level 'INFO'
    $conflictSummary = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurationConflictSummary"

    # Combine
    $allStates = @()
    foreach ($cs in $configStates)    { $allStates += [PSCustomObject]@{ PolicyName=$cs.displayName; PolicyType='Device Configuration'; State=$cs.state; PolicyId=$cs.id } }
    foreach ($cs in $complianceStates) { $allStates += [PSCustomObject]@{ PolicyName=$cs.displayName; PolicyType='Compliance Policy'; State=$cs.state; PolicyId=$cs.id } }

    Write-Log -Message "=== POLICY STATE OVERVIEW ===" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'
    $stateGroups = $allStates | Group-Object State | Sort-Object Name
    foreach ($sg in $stateGroups) {
        $c = switch ($sg.Name) { 'compliant'{'Green'} 'conflict'{'Red'} 'error'{'Red'} 'notApplicable'{'DarkGray'} default{'Gray'} }
        Write-Host "  $($sg.Name) : $($sg.Count)" -ForegroundColor $c
    }

    # Drill into settings for all policies - find overlaps
    $settingReport = [System.Collections.Generic.List[PSCustomObject]]::new()
    $settingMap = @{}

    Write-Log -Message "=== DRILLING INTO PER-SETTING STATES ===" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'

    foreach ($cs in $configStates) {
        $settingStates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$managedDeviceId/deviceConfigurationStates/$($cs.id)/settingStates"
        foreach ($ss in $settingStates) {
            $key = if ($ss.setting) { $ss.setting } elseif ($ss.settingName) { $ss.settingName } else { continue }
            if ($ss.state -ne 'notApplicable') {
                if (-not $settingMap.ContainsKey($key)) { $settingMap[$key] = @() }
                $settingMap[$key] += [PSCustomObject]@{ PolicyName=$cs.displayName; State=$ss.state; Value=$ss.currentValue }
            }
            if ($ss.state -notin @('compliant','notApplicable')) {
                Write-Host "  [$($ss.state.ToUpper())] $key" -ForegroundColor $(if($ss.state -eq 'conflict'){'Red'}elseif($ss.state -eq 'error'){'Magenta'}else{'Yellow'})
                Write-Log -Message "    Policy : $($cs.displayName)" -Level 'INFO'
                if ($ss.currentValue) { Write-Log -Message "    Value  : $($ss.currentValue)" -Level 'DEBUG' }
                if ($ss.sources) { foreach ($src in $ss.sources) { Write-Log -Message "    Source : $($src.displayName) = $($src.value)" -Level 'WARNING' } }
                Write-Log -Message "" -Level 'INFO'
                $settingReport.Add([PSCustomObject]@{ DeviceName=$device.deviceName; PolicyName=$cs.displayName; SettingPath=$ss.setting; SettingName=$ss.settingName; State=$ss.state; Value=$ss.currentValue; Sources=if($ss.sources){($ss.sources | ForEach-Object {"$($_.displayName)=$($_.value)"})-join'; '}else{'-'} })
            }
        }
    }

    # Overlaps
    $overlaps = $settingMap.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | Sort-Object { $_.Value.Count } -Descending
    if ($overlaps.Count -gt 0) {
        Write-Log -Message "=== SETTING OVERLAPS ($($overlaps.Count) settings touched by multiple policies) ===" -Level 'INFO'
        Write-Log -Message "" -Level 'INFO'
        foreach ($ol in $overlaps) {
            $hasConflict = $ol.Value | Where-Object { $_.State -eq 'conflict' }
            $tag = if ($hasConflict) { '[CONFLICT]' } else { '[OVERLAP]' }
            Write-Host "  $($ol.Key) $tag" -ForegroundColor $(if($hasConflict){'Red'}else{'Yellow'})
            foreach ($e in $ol.Value) { Write-Host "    - $($e.PolicyName) [$($e.State)] = $($e.Value)" -ForegroundColor $(if($e.State -eq 'conflict'){'Red'}else{'White'}) }
            Write-Log -Message "" -Level 'INFO'
        }
    }

    Write-Log -Message "=== ANALYSIS COMPLETE ===" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Policies on device       : $($allStates.Count)" -Level 'INFO'
    Write-Host "  Settings in conflict     : $(($settingReport | Where-Object { $_.State -eq 'conflict' }).Count)" -ForegroundColor $(if(($settingReport | Where-Object { $_.State -eq 'conflict' }).Count -gt 0){'Red'}else{'Green'})
    Write-Host "  Settings in error        : $(($settingReport | Where-Object { $_.State -eq 'error' }).Count)" -ForegroundColor $(if(($settingReport | Where-Object { $_.State -eq 'error' }).Count -gt 0){'Red'}else{'Green'})
    Write-Host "  Settings with overlaps   : $($overlaps.Count)" -ForegroundColor $(if($overlaps.Count -gt 0){'Yellow'}else{'Green'})
    Write-Log -Message "" -Level 'INFO'
    if ($settingReport.Count -eq 0 -and $overlaps.Count -eq 0) {
        Write-Log -Message "  No conflicts or errors found." -Level 'SUCCESS'
        Write-Log -Message "  If a feature is broken without a reported conflict, the issue is" -Level 'DEBUG'
        Write-Log -Message "  likely a hardening side effect. Try:" -Level 'DEBUG'
        Write-Log -Message "    .\Find-IntunePolicyConflict.ps1 -DeviceName '$DeviceName' -Mode Investigate -Feature Hello" -Level 'INFO'
        Write-Log -Message "" -Level 'INFO'
    }
    if ($settingReport.Count -gt 0) {
        $path = if($ExportPath){$ExportPath}else{Join-Path $scriptDirectory "$($DeviceName -replace '[^\w\-]','_')_Conflicts_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"}
        $settingReport | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-Log -Message "Exported to: $path" -Level 'SUCCESS'
    }
    #endregion

} elseif ($Mode -eq 'Investigate') {
    #region --- Investigate Mode ---
    if (-not $Feature) {
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  -Feature is required for Investigate mode." -Level 'ERROR'
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  Built-in feature maps:" -Level 'WARNING'
        foreach ($f in ($featureMaps.Keys | Sort-Object)) {
            $kwCount = $featureMaps[$f].Count
            Write-Log -Message "    $f ($kwCount keywords)" -Level 'INFO'
        }
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  Or enter any custom keyword (e.g., -Feature 'Bluetooth')" -Level 'DEBUG'
        return
    }

    # Resolve keywords
    $keywords = if ($featureMaps.ContainsKey($Feature)) {
        $featureMaps[$Feature]
    } else {
        @($Feature)
    }

    $mapType = if ($featureMaps.ContainsKey($Feature)) { "built-in map ($($keywords.Count) keywords)" } else { "custom keyword" }

    Write-Log -Message "=== MODE: INVESTIGATE - Full X-Ray for '$Feature' ===" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  This mode shows EVERY setting applied to the device that could" -Level 'DEBUG'
    Write-Log -Message "  affect $Feature - INCLUDING settings that applied successfully." -Level 'DEBUG'
    Write-Log -Message "  A 'compliant' setting can still break a feature as a side effect." -Level 'WARNING'
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Feature     : $Feature ($mapType)" -Level 'INFO'
    if ($featureMaps.ContainsKey($Feature)) {
        Write-Log -Message "  Keywords    : $($keywords[0..4] -join ', ')$(if($keywords.Count -gt 5){', ...'})" -Level 'DEBUG'
    }
    Write-Log -Message "" -Level 'INFO'

    Write-Log -Message "Fetching all configuration policy states for device..." -Level 'INFO'
    $configStates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$managedDeviceId/deviceConfigurationStates"
    Write-Log -Message "$($configStates.Count) policies on device" -Level 'INFO'

    $featureSettings = [System.Collections.Generic.List[PSCustomObject]]::new()
    $policiesWithMatchingSettings = @{}
    $totalSettingsScanned = 0

    Write-Log -Message "Scanning all settings across all policies for $Feature-related entries..." -Level 'INFO'
    $policyIndex = 0

    foreach ($cs in $configStates) {
        $policyIndex++
        Write-Progress -Activity "Scanning policies" -Status "$policyIndex of $($configStates.Count) - $($cs.displayName)" -PercentComplete (($policyIndex / $configStates.Count) * 100)

        $settingStates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$managedDeviceId/deviceConfigurationStates/$($cs.id)/settingStates"
        $totalSettingsScanned += $settingStates.Count

        foreach ($ss in $settingStates) {
            $settingPath = if ($ss.setting) { $ss.setting } else { '' }
            $settingName = if ($ss.settingName) { $ss.settingName } else { '' }

            if (Test-SettingMatchesFeature -SettingPath $settingPath -SettingName $settingName -PolicyName $cs.displayName -Keywords $keywords) {

                if (-not $policiesWithMatchingSettings.ContainsKey($cs.displayName)) {
                    $policiesWithMatchingSettings[$cs.displayName] = 0
                }
                $policiesWithMatchingSettings[$cs.displayName]++

                $featureSettings.Add([PSCustomObject]@{
                    PolicyName     = $cs.displayName
                    PolicyState    = $cs.state
                    SettingPath    = $settingPath
                    SettingName    = $settingName
                    SettingState   = $ss.state
                    CurrentValue   = $ss.currentValue
                    Sources        = if ($ss.sources) { ($ss.sources | ForEach-Object { "$($_.displayName)=$($_.value)" }) -join '; ' } else { '-' }
                })
            }
        }
    }
    Write-Progress -Activity "Scanning policies" -Completed

    Write-Log -Message "=== INVESTIGATION RESULTS FOR: $Feature ===" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Total settings scanned     : $totalSettingsScanned" -Level 'INFO'
    Write-Log -Message "  $Feature-related settings  : $($featureSettings.Count)" -Level 'INFO'
    Write-Log -Message "  Policies touching $Feature : $($policiesWithMatchingSettings.Count)" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'

    if ($featureSettings.Count -eq 0) {
        Write-Log -Message "  No settings matching '$Feature' found on this device." -Level 'WARNING'
        Write-Log -Message "  Try a different keyword or check if the feature is controlled" -Level 'DEBUG'
        Write-Log -Message "  by a setting not in the built-in map." -Level 'DEBUG'
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  You can also try: -Mode Isolate (binary search)" -Level 'INFO'
        return
    }

    # Group by policy - show which policies are touching this feature area
    Write-Log -Message "=== POLICIES AFFECTING $($Feature.ToUpper()) ===" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'

    $groupedByPolicy = $featureSettings | Group-Object PolicyName | Sort-Object { $_.Group.Count } -Descending
    foreach ($pg in $groupedByPolicy) {
        $policyState = $pg.Group[0].PolicyState
        $settingCount = $pg.Group.Count
        $hasIssues = $pg.Group | Where-Object { $_.SettingState -notin @('compliant','notApplicable') }
        $policyColor = if ($hasIssues) { 'Yellow' } else { 'White' }
        $stateTag = if ($policyState -eq 'conflict') { ' [CONFLICT]' } elseif ($policyState -eq 'error') { ' [ERROR]' } else { '' }

        Write-Host "  $($pg.Name)$stateTag ($settingCount settings)" -ForegroundColor $policyColor
    }
    Write-Log -Message "" -Level 'INFO'

    # Show all settings grouped by policy
    Write-Log -Message "=== DETAILED SETTING VALUES ===" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Legend: Settings marked [COMPLIANT] applied successfully but MAY" -Level 'DEBUG'
    Write-Log -Message "  still cause side effects. Review the VALUES, not just the states." -Level 'DEBUG'
    Write-Log -Message "" -Level 'INFO'

    foreach ($pg in $groupedByPolicy) {
        Write-Log -Message "  POLICY: $($pg.Name)" -Level 'WARNING'
        Write-Log -Message "  $('-' * ($pg.Name.Length + 8))" -Level 'DEBUG'

        foreach ($s in ($pg.Group | Sort-Object SettingPath)) {
            $stateColor = switch ($s.SettingState) {
                'compliant'    { 'Green' }
                'conflict'     { 'Red' }
                'error'        { 'Magenta' }
                'notApplicable' { 'DarkGray' }
                default        { 'Yellow' }
            }
            $stateTag = "[$($s.SettingState.ToUpper())]"

            # Highlight potentially disruptive values
            $valueColor = 'DarkGray'
            $disruptiveFlag = ''
            if ($s.CurrentValue) {
                $val = $s.CurrentValue.ToString().ToLower()
                if ($val -in @('disabled','blocked','0','false','not allowed','not configured','deny','block')) {
                    $valueColor = 'DarkYellow'
                    $disruptiveFlag = ' <-- RESTRICTIVE'
                }
            }

            Write-Host "    $stateTag " -ForegroundColor $stateColor -NoNewline
            Write-Log -Message "$($s.SettingPath)" -Level 'INFO'
            if ($s.SettingName -and $s.SettingName -ne $s.SettingPath) {
                Write-Log -Message "      Name  : $($s.SettingName)" -Level 'INFO'
            }
            Write-Host "      Value : $($s.CurrentValue)$disruptiveFlag" -ForegroundColor $valueColor
            if ($s.Sources -ne '-') {
                Write-Log -Message "      Sources: $($s.Sources)" -Level 'DEBUG'
            }
        }
        Write-Log -Message "" -Level 'INFO'
    }

    # Flag potentially disruptive settings
    $restrictive = $featureSettings | Where-Object {
        $v = $_.CurrentValue
        $v -and ($v.ToString().ToLower() -in @('disabled','blocked','0','false','not allowed','deny','block'))
    }

    if ($restrictive.Count -gt 0) {
        Write-Log -Message "=== POTENTIALLY DISRUPTIVE SETTINGS ($($restrictive.Count)) ===" -Level 'INFO'
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  These settings have restrictive values (disabled/blocked/0/false)" -Level 'WARNING'
        Write-Log -Message "  that could break $Feature even without a conflict:" -Level 'WARNING'
        Write-Log -Message "" -Level 'INFO'
        foreach ($r in $restrictive) {
            Write-Log -Message "  $($r.SettingPath)" -Level 'ERROR'
            Write-Log -Message "    Policy : $($r.PolicyName)" -Level 'INFO'
            Write-Log -Message "    Value  : $($r.CurrentValue)" -Level 'WARNING'
            Write-Log -Message "" -Level 'INFO'
        }
    }

    # Summary
    Write-Log -Message "=== INVESTIGATION SUMMARY ===" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Feature investigated       : $Feature" -Level 'INFO'
    Write-Log -Message "  Policies touching feature  : $($policiesWithMatchingSettings.Count)" -Level 'INFO'
    Write-Log -Message "  Total related settings     : $($featureSettings.Count)" -Level 'INFO'
    Write-Host "  Restrictive values found   : $($restrictive.Count)" -ForegroundColor $(if($restrictive.Count -gt 0){'Red'}else{'Green'})
    Write-Host "  Settings in conflict/error : $(($featureSettings | Where-Object { $_.SettingState -in @('conflict','error') }).Count)" -ForegroundColor $(if(($featureSettings | Where-Object { $_.SettingState -in @('conflict','error') }).Count -gt 0){'Red'}else{'Green'})
    Write-Log -Message "" -Level 'INFO'

    if ($restrictive.Count -gt 0) {
        Write-Log -Message "  NEXT STEP: Review the restrictive settings above. One of those" -Level 'INFO'
        Write-Log -Message "  policies is likely hardening a setting that $Feature depends on." -Level 'INFO'
        Write-Log -Message "  Try relaxing the value in a test policy to confirm." -Level 'INFO'
    } else {
        Write-Log -Message "  No obviously restrictive values found. The issue may be more subtle." -Level 'DEBUG'
        Write-Log -Message "  Consider: -Mode Isolate for binary search." -Level 'INFO'
    }

    # Export
    if ($featureSettings.Count -gt 0) {
        $safeFeature = $Feature -replace '[^\w\-]','_'
        $path = if($ExportPath){$ExportPath}else{Join-Path $scriptDirectory "$($DeviceName -replace '[^\w\-]','_')_Investigate_$($safeFeature)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"}
        $featureSettings | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
        Write-Log -Message "Exported $($featureSettings.Count) settings to: $path" -Level 'SUCCESS'
    }
    #endregion

} elseif ($Mode -eq 'Isolate') {
    #region --- Isolate Mode (Binary Search) ---
    Write-Log -Message "=== MODE: ISOLATE - Binary Search Policy Isolation ===" -Level 'INFO'
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  This mode will TEMPORARILY modify policy assignments to isolate" -Level 'WARNING'
    Write-Log -Message "  the culprit policy. All changes are REVERTED at the end." -Level 'WARNING'
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  How it works:" -Level 'INFO'
    Write-Log -Message "    1. Collects all group-assigned config policies on this device" -Level 'DEBUG'
    Write-Log -Message "    2. Temporarily removes HALF the policy assignments" -Level 'DEBUG'
    Write-Log -Message "    3. You sync the device and test the broken feature" -Level 'DEBUG'
    Write-Log -Message "    4. You report: Fixed (F) or Still Broken (B)" -Level 'DEBUG'
    Write-Log -Message "    5. Narrows by half each round until 1 policy remains" -Level 'DEBUG'
    Write-Log -Message "    6. ALL original assignments restored automatically" -Level 'DEBUG'
    Write-Log -Message "" -Level 'INFO'

    $confirm = Read-Host "  Type YES to proceed (this will temporarily modify assignments)"
    if ($confirm -ne 'YES') {
        Write-Log -Message "  Aborted." -Level 'WARNING'
        return
    }

    # Resolve device's Entra object
    $entraDeviceId = $device.azureADDeviceId
    $entraDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$entraDeviceId'&`$select=id"
    if ($entraDevices.Count -eq 0) {
        Write-Log -Message "  ERROR: Cannot resolve Entra device." -Level 'ERROR'
        return
    }

    # Collect policies with group-based assignments
    Write-Log -Message "Collecting policies with assignments..." -Level 'INFO'
    $policyTypes = @(
        @{ Name='Device Configurations'; Uri='https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations'; NameProp='displayName' }
        @{ Name='Settings Catalog';      Uri='https://graph.microsoft.com/beta/deviceManagement/configurationPolicies'; NameProp='name' }
    )

    $candidatePolicies = @()
    foreach ($pt in $policyTypes) {
        $policies = Get-MgGraphAllPages -Uri "$($pt.Uri)?`$expand=Assignments"
        foreach ($p in $policies) {
            if (-not $p.assignments) { continue }
            foreach ($a in $p.assignments) {
                $target = $a.target
                if (-not $target) { continue }
                if ($target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' -and $target.groupId) {
                    $pName = $p.($pt.NameProp); if (-not $pName) { $pName = $p.displayName }; if (-not $pName) { $pName = $p.name }
                    $candidatePolicies += [PSCustomObject]@{ PolicyName=$pName; PolicyId=$p.id; PolicyType=$pt.Name; BaseUri=$pt.Uri; GroupId=$target.groupId }
                }
            }
        }
    }
    $candidatePolicies = $candidatePolicies | Sort-Object PolicyId -Unique

    if ($candidatePolicies.Count -lt 2) {
        Write-Log -Message "  Only $($candidatePolicies.Count) candidate(s) found. Need at least 2." -Level 'WARNING'
        return
    }

    Write-Log -Message "$($candidatePolicies.Count) candidate policies" -Level 'SUCCESS'

    # Backup all assignments
    $originalAssignments = @{}
    foreach ($cp in $candidatePolicies) {
        $assignments = Get-MgGraphAllPages -Uri "$($cp.BaseUri)/$($cp.PolicyId)/assignments"
        $originalAssignments[$cp.PolicyId] = @{ BaseUri=$cp.BaseUri; PolicyName=$cp.PolicyName; Assignments=$assignments }
    }
    Write-Log -Message "Backed up assignments for $($originalAssignments.Count) policies" -Level 'SUCCESS'

    $suspects = [System.Collections.ArrayList]::new($candidatePolicies)
    $round = 0
    $totalRoundsEstimate = [math]::Ceiling([math]::Log($suspects.Count, 2))

    try {
        while ($suspects.Count -gt 1) {
            $round++
            $mid = [math]::Ceiling($suspects.Count / 2)
            $removeGroup = $suspects[0..($mid-1)]
            $keepGroup = $suspects[$mid..($suspects.Count-1)]

            Write-Log -Message "=== ROUND $round of ~$totalRoundsEstimate | $($suspects.Count) remaining ===" -Level 'INFO'
            Write-Log -Message "" -Level 'INFO'
            Write-Log -Message "  REMOVING ($($removeGroup.Count)):" -Level 'WARNING'
            $removeGroup | ForEach-Object { Write-Log -Message "    - $($_.PolicyName)" -Level 'WARNING' }
            Write-Log -Message "  KEEPING ($($keepGroup.Count)):" -Level 'SUCCESS'
            $keepGroup | ForEach-Object { Write-Log -Message "    - $($_.PolicyName)" -Level 'SUCCESS' }
            Write-Log -Message "" -Level 'INFO'

            foreach ($rp in $removeGroup) {
                $cur = Get-MgGraphAllPages -Uri "$($rp.BaseUri)/$($rp.PolicyId)/assignments"
                $filtered = $cur | Where-Object { $_.target.groupId -ne $rp.GroupId }
                $body = @{ assignments = @($filtered | ForEach-Object { @{ target=$_.target } }) } | ConvertTo-Json -Depth 10
                try { Invoke-MgGraphRequest -Uri "$($rp.BaseUri)/$($rp.PolicyId)/assign" -Method POST -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null }
                catch [System.Exception] {
                    # typed catch - warning
                    Write-Log -Message "    WARNING: $($rp.PolicyName): $_" -Level 'WARNING'
                }
            }

            Write-Log -Message "  >>> Sync device and test the broken feature now." -Level 'INFO'
            Write-Log -Message "" -Level 'INFO'
            $answer = Read-Host "  Result? (F = Fixed, B = Still Broken, Q = Quit)"

            # Restore removed policies before narrowing
            foreach ($rp in $removeGroup) {
                $orig = $originalAssignments[$rp.PolicyId]
                $body = @{ assignments = @($orig.Assignments | ForEach-Object { @{ target=$_.target } }) } | ConvertTo-Json -Depth 10
                try { Invoke-MgGraphRequest -Uri "$($rp.BaseUri)/$($rp.PolicyId)/assign" -Method POST -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null } catch [System.Exception] { # typed catch - empty
    }
            }

            switch ($answer.Trim().ToUpper()) {
                'F' { $suspects = [System.Collections.ArrayList]::new($removeGroup) }
                'B' { $suspects = [System.Collections.ArrayList]::new($keepGroup) }
                'Q' { throw "UserQuit" }
                default { Write-Log -Message "  Invalid. Retrying round..." -Level 'ERROR'; continue }
            }
        }

        Write-Log -Message "=== CULPRIT FOUND ===" -Level 'INFO'
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  The policy causing the issue:" -Level 'SUCCESS'
        Write-Log -Message "    Name : $($suspects[0].PolicyName)" -Level 'INFO'
        Write-Log -Message "    Type : $($suspects[0].PolicyType)" -Level 'INFO'
        Write-Log -Message "    ID   : $($suspects[0].PolicyId)" -Level 'INFO'
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  Isolated in $round round(s) out of $($candidatePolicies.Count) policies." -Level 'SUCCESS'
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  Next step: Use -Mode Investigate to see exactly which settings" -Level 'INFO'
        Write-Log -Message "  in this policy are causing the issue." -Level 'INFO'

    } catch [System.Exception] { # typed catch
        if ($_.Exception.Message -ne 'UserQuit') { Write-Log -Message "  ERROR: $_" -Level 'ERROR' }
    } finally {
        Write-Log -Message "=== RESTORING ALL ORIGINAL ASSIGNMENTS ===" -Level 'INFO'
        $restored = 0
        foreach ($pid in $originalAssignments.Keys) {
            $orig = $originalAssignments[$pid]
            $body = @{ assignments = @($orig.Assignments | ForEach-Object { @{ target=$_.target } }) } | ConvertTo-Json -Depth 10
            try { Invoke-MgGraphRequest -Uri "$($orig.BaseUri)/$pid/assign" -Method POST -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null; $restored++ } catch [System.Exception] {
                    # typed catch - failed restore
                    Write-Log -Message "  FAILED: $($orig.PolicyName): $_" -Level 'ERROR'
                }
        }
        Write-Log -Message "$restored of $($originalAssignments.Count) policies restored" -Level 'SUCCESS'
    }
    #endregion
}

Write-Log -Message "`n$('='*60)" -Level 'DEBUG'


