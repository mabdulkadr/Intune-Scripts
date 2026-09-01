<#
.TITLE
    Detection - Intune Primary User Assignment Status

.SYNOPSIS
    Detects whether this Intune device already has a primary user assigned.

.DESCRIPTION
    Connects to Microsoft Graph with app-only authentication (client credentials),
    locates the current device in Intune by device name, then reads the assigned
    primary users via the managedDevices users navigation. Compliant when at least
    one primary user exists; non-compliant when none is assigned or the device is
    not found in Intune. Graph/transport failures are script errors and exit 2.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,Intune,Graph

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Repair-IntunePrimaryUser.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    Microsoft Graph app-only (client credentials). Token is requested with
    scope=https://graph.microsoft.com/.default, so consent follows the app
    registration. Endpoints used require: DeviceManagementManagedDevices.Read.All
    (device lookup by name, primary-user read via beta managedDevices(id)/users)
    plus valid TenantId/ClientId/ClientSecret configured in CONFIGURATION below.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    1.1 - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Repair-IntunePrimaryUser.ps1
    Returns exit 0 when a primary user exists; exit 1 when none is assigned.

.EXAMPLE
    .\detect-Repair-IntunePrimaryUser.ps1
    Returns exit 2 when Graph authentication or lookup fails unexpectedly.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Read-only against Graph: detection never modifies assignments.
    - Configure TenantId, ClientId, and ClientSecret in CONFIGURATION before deployment.
    - Logs: <SystemDrive>\IntuneLogs\IntunePrimaryUserUpdate\IntunePrimaryUserUpdate-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Repair-IntunePrimaryUser'
$ScriptMode   = 'Detection'

# App registration settings
$TenantId     = ' '
$ClientId     = ' '
$ClientSecret = ' '

# Current device name
$DeviceName = $env:COMPUTERNAME

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
        [AllowEmptyString()]
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
        [AllowEmptyString()]
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
# GRAPH HELPERS (app-only client credentials - legacy auth pattern preserved)
# ============================================================================

# Requests an app-only access token from the Microsoft identity platform.
function Get-GraphAccessToken {
    $body = @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = 'https://graph.microsoft.com/.default'
    }

    $tokenUri      = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUri -Body $body -ErrorAction Stop

    if (-not $tokenResponse.access_token) {
        throw 'Access token was not returned from Microsoft identity platform.'
    }

    return $tokenResponse.access_token
}

# Invoke Graph request with shared headers.
function Invoke-GraphGet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers -ErrorAction Stop
}

# Find current Intune managed device by device name.
function Get-ManagedDeviceByName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $safeName = $Name.Replace("'", "''")
    $uri      = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=deviceName eq '$safeName'"

    $response = Invoke-GraphGet -Uri $uri -Headers $Headers

    if (-not $response.value) {
        return $null
    }

    $devices = @($response.value)

    if ($devices.Count -eq 1) {
        return $devices[0]
    }

    if ($devices.Count -gt 1) {
        # Prefer exact device name match first
        $exactMatch = $devices | Where-Object { $_.deviceName -eq $Name } | Select-Object -First 1
        if ($exactMatch) {
            return $exactMatch
        }

        return $devices[0]
    }

    return $null
}

# Get primary users assigned to managed device.
function Get-ManagedDevicePrimaryUsers {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManagedDeviceId,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $uri      = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$ManagedDeviceId')/users"
    $response = Invoke-GraphGet -Uri $uri -Headers $Headers

    if (-not $response.value) {
        return @()
    }

    return @(
        $response.value |
        Where-Object { $_.userPrincipalName } |
        Select-Object -ExpandProperty userPrincipalName
    )
}

# ============================================================================
# DETECTION LOGIC
# Return a list of reason strings so operators see every failure at once.
# Empty list = compliant. Never modify anything here.
# ============================================================================

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    # Basic config validation - missing credentials are a script error, not
    # device non-compliance, so they throw and surface as exit 2.
    if ([string]::IsNullOrWhiteSpace($TenantId) -or
        [string]::IsNullOrWhiteSpace($ClientId) -or
        [string]::IsNullOrWhiteSpace($ClientSecret)) {
        throw 'TenantId, ClientId, or ClientSecret is empty.'
    }

    # Get Graph token
    Write-Log -Message "Requesting Microsoft Graph access token..." -Level 'DEBUG'
    $accessToken = Get-GraphAccessToken
    $headers     = @{ Authorization = "Bearer $accessToken" }

    # Find current device in Intune
    Write-Log -Message "Searching Intune managed device by name: $DeviceName" -Level 'DEBUG'
    $managedDevice = Get-ManagedDeviceByName -Name $DeviceName -Headers $headers

    if (-not $managedDevice) {
        $reasons.Add("Device '$DeviceName' was not found in Intune managedDevices")
        return @($reasons)
    }

    Write-Log -Message "Managed device found. Intune device ID: $($managedDevice.id)" -Level 'DEBUG'

    # Check primary users
    $primaryUsers = @(Get-ManagedDevicePrimaryUsers -ManagedDeviceId $managedDevice.id -Headers $headers)

    if ($primaryUsers.Count -gt 0) {
        Write-Log -Message "Primary user(s) already assigned: $($primaryUsers -join ', ')" -Level 'DEBUG'
    }
    else {
        $reasons.Add("No primary user is assigned to this Intune device")
    }

    return @($reasons)
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> banner -> compliance checks -> exit 0 compliant / 1 non-compliant / 2 error.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Detection started" -Level 'INFO'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message "Compliant - this device has a primary user assigned" -Level 'SUCCESS'
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}


