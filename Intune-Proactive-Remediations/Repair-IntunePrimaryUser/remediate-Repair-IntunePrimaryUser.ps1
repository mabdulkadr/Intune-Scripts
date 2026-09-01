<#
.TITLE
    Remediation - Assign Intune Primary User

.SYNOPSIS
    Assigns the current logged-on user as the device primary user in Intune.

.DESCRIPTION
    Paired remediation for IntunePrimaryUserUpdate. Runs only when
    detect-Repair-IntunePrimaryUser.ps1 returns exit 1. Detects the active
    console session via "query user", maps the SAM account to a UPN using
    DefaultUpnSuffix, authenticates to Microsoft Graph with app-only client
    credentials, resolves device and user, then POSTs the users/$ref assignment
    and verifies it by re-reading the primary-user list.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Intune,Graph

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Repair-IntunePrimaryUser.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    Microsoft Graph app-only (client credentials). Token is requested with
    scope=https://graph.microsoft.com/.default, so consent follows the app
    registration. Endpoints used require: DeviceManagementManagedDevices.Read.All
    (device lookup, primary-user reads), DeviceManagementManagedDevices.ReadWrite.All
    (primary-user assignment via beta managedDevices(id)/users/$ref), and
    User.Read.All (user lookup by UPN).

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / fix / post-verify flow with JSON result output
    - Added DefaultUpnSuffix configuration value (referenced but undefined in legacy release)
    1.1 - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Repair-IntunePrimaryUser.ps1
    Assigns the active console user as primary user and verifies; exits 0 on success.

.EXAMPLE
    .\remediate-Repair-IntunePrimaryUser.ps1
    Exits 1 if verification fails after assignment, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Changing the primary user affects user-device affiliation in Intune (app targeting, user affinity).
    - Configure TenantId, ClientId, ClientSecret, and DefaultUpnSuffix in CONFIGURATION before deployment.
    - Logs: <SystemDrive>\IntuneLogs\IntunePrimaryUserUpdate\IntunePrimaryUserUpdate-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Repair-IntunePrimaryUser'
$ScriptMode   = 'Remediation'

# App registration settings
$TenantId     = ' '
$ClientId     = ' '
$ClientSecret = ' '

# UPN suffix appended to the detected SAM account name (e.g. 'contoso.com').
$DefaultUpnSuffix = ''

# Current device name
$DeviceName = $env:COMPUTERNAME

$remediationResult = @{
    Status             = "Unknown"
    PreCheckStatus     = @()
    RemediationActions = @()
    PostCheckStatus    = @()
    Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName       = $env:COMPUTERNAME
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

# Appends structured per-target remediation entries to the audit trail.
function Write-RemediationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    # Console/file via canonical Write-Log + structured record for JSON output.
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:RemediationResult.RemediationActions += @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Level     = $Level
        Message   = $Message
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

# Invoke Graph POST request with shared headers.
function Invoke-GraphPost {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,

        [Parameter(Mandatory = $true)]
        [string]$Body
    )

    Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Body $Body -ContentType 'application/json' -ErrorAction Stop
}

# Detects the active logged-on console user from "query user" output.
function Get-ActiveLoggedOnUser {
    try {
        $rawOutput = (& query user) 2>$null
        if (-not $rawOutput) {
            return $null
        }

        $lines = @($rawOutput | Select-Object -Skip 1)
        if (-not $lines -or $lines.Count -eq 0) {
            return $null
        }

        $activeSessions = @($lines | Where-Object { $_ -match '\s+Active\s+' })
        if (-not $activeSessions -or $activeSessions.Count -eq 0) {
            return $null
        }

        $consoleSession = $activeSessions | Where-Object { $_ -match '\s+console\s+' } | Select-Object -First 1
        $pickedSession  = if ($consoleSession) { $consoleSession } else { $activeSessions | Select-Object -First 1 }

        $userField = ($pickedSession -replace '^\s*>?\s*', '' -split '\s+')[0]
        if ([string]::IsNullOrWhiteSpace($userField)) {
            return $null
        }

        return $userField
    }
    catch {
        # No queryable interactive session is an expected pre-state here.
        return $null
    }
}

# Maps a SAM account name to a UPN using the configured suffix.
function Convert-SamToUpn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SamAccountName
    )

    return "$SamAccountName@$DefaultUpnSuffix"
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

    $exactMatch = $devices | Where-Object { $_.deviceName -eq $Name } | Select-Object -First 1
    if ($exactMatch) {
        return $exactMatch
    }

    return $devices[0]
}

# Get a Graph user object by UPN.
function Get-GraphUserByUpn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $safeUpn = [uri]::EscapeDataString($UserPrincipalName)
    $uri     = "https://graph.microsoft.com/v1.0/users/$safeUpn"
    return Invoke-GraphGet -Uri $uri -Headers $Headers
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

    return @($response.value)
}

# Adds a user reference as managed device primary user.
function Add-ManagedDevicePrimaryUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManagedDeviceId,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $uri  = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$ManagedDeviceId')/users/`$ref"
    $body = @{
        '@odata.id' = "https://graph.microsoft.com/beta/users/$UserId"
    } | ConvertTo-Json

    Invoke-GraphPost -Uri $uri -Headers $Headers -Body $body | Out-Null
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # Graph credentials must be configured before any call can succeed.
        if ([string]::IsNullOrWhiteSpace($TenantId) -or
            [string]::IsNullOrWhiteSpace($ClientId) -or
            [string]::IsNullOrWhiteSpace($ClientSecret)) {
            throw 'TenantId, ClientId, or ClientSecret is empty.'
        }

        $script:RemediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-RemediationLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# REMEDIATION ACTION (per-target pattern)
# ============================================================================

# Applies the fix to ONE target and returns a structured success/failure object.
function Invoke-FixTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TargetName,
        [Parameter(Mandatory = $true)][scriptblock]$Fix
    )
    # Returns $true when the fix was applied AND verified for this target.
    try {
        & $Fix
        return $true
    }
    catch {
        $script:FailedCount++
        Write-RemediationLog "Target FAILED: $TargetName - $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # Re-read the same navigation the detector read. Return $true only when
        # the target user now appears among the assigned primary users.
        $updatedPrimaryUsers = @(Get-ManagedDevicePrimaryUsers -ManagedDeviceId $script:ManagedDeviceId -Headers $script:GraphHeaders)
        $verifiedAssignment  = $updatedPrimaryUsers | Where-Object { $_.id -eq $script:TargetUserId } | Select-Object -First 1

        if ($verifiedAssignment) {
            return $true
        }

        Write-RemediationLog "Assignment request completed, but verification failed." -Level 'Error'
        return $false
    }
    catch {
        Write-RemediationLog "Verification could not read primary users: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> pre-checks -> per-target fix -> post-verify -> exit 0 / 1 / 2.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-RemediationLog "Starting remediation..." -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # No active session means there is nothing to assign - legacy behavior kept.
    $samAccountName = Get-ActiveLoggedOnUser
    if (-not $samAccountName) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "No active logged-on user was found. No action required."

        Write-Output "No active logged-on user was found. No action required."
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "No active logged-on user was found. No action required." -Level 'SUCCESS'
    }

    $upn = Convert-SamToUpn -SamAccountName $samAccountName
    Write-RemediationLog "Detected active user: $upn" -Level 'Info'

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    # Resolve Graph token once so both fix and verification reuse it.
    Write-RemediationLog "Requesting Microsoft Graph access token..." -Level 'Info'
    $accessToken           = Get-GraphAccessToken
    $script:GraphHeaders   = @{ Authorization = "Bearer $accessToken" }
    Write-RemediationLog "Graph access token acquired successfully." -Level 'Info'

    # Locate the device and user this remediation targets.
    Write-RemediationLog "Searching Intune managed device by name: $DeviceName" -Level 'Info'
    $managedDevice = Get-ManagedDeviceByName -Name $DeviceName -Headers $script:GraphHeaders

    if (-not $managedDevice) {
        throw "Device '$DeviceName' was not found in Intune managedDevices."
    }

    Write-RemediationLog "Managed device found. Intune device ID: $($managedDevice.id)" -Level 'Info'
    $script:ManagedDeviceId = $managedDevice.id

    Write-RemediationLog "Looking up user by UPN: $upn" -Level 'Info'
    $graphUser = Get-GraphUserByUpn -UserPrincipalName $upn -Headers $script:GraphHeaders

    if (-not $graphUser -or -not $graphUser.id) {
        throw "User lookup failed for $upn."
    }

    Write-RemediationLog "User found. User ID: $($graphUser.id)" -Level 'Info'
    $script:TargetUserId = $graphUser.id

    # Skip when already assigned - idempotent behavior preserved from legacy.
    Write-RemediationLog "Checking existing primary user assignments..." -Level 'Info'
    $existingPrimaryUsers = @(Get-ManagedDevicePrimaryUsers -ManagedDeviceId $script:ManagedDeviceId -Headers $script:GraphHeaders)

    if ($existingPrimaryUsers.Count -gt 0) {
        $existingUpns = @(
            $existingPrimaryUsers |
            Where-Object { $_.userPrincipalName } |
            Select-Object -ExpandProperty userPrincipalName
        )

        Write-RemediationLog "Existing primary user(s): $($existingUpns -join ', ')" -Level 'Info'

        $alreadyAssigned = $existingPrimaryUsers | Where-Object { $_.id -eq $script:TargetUserId } | Select-Object -First 1
        if ($alreadyAssigned) {
            $script:RemediationResult.Status = "Success"
            $script:RemediationResult.PostCheckStatus += "$upn is already assigned as primary user. No action required."

            Write-Output "$upn is already assigned as primary user. No action required."
            Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

            Finish-Script -ExitCode 0 -Message "$upn is already assigned as primary user. No action required." -Level 'SUCCESS'
        }
    }
    else {
        Write-RemediationLog "No primary users are currently assigned." -Level 'Info'
    }

    $targetCount++
    Invoke-FixTarget -TargetName "Assign $upn as primary user" -Fix {
        Write-RemediationLog "Assigning $upn as primary user..." -Level 'Info'
        Add-ManagedDevicePrimaryUser -ManagedDeviceId $script:ManagedDeviceId -UserId $script:TargetUserId -Headers $script:GraphHeaders
        Start-Sleep -Seconds 2
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $failedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Successfully assigned $upn as primary user for $DeviceName."
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Successfully assigned $upn as primary user for $DeviceName." -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed" -Level 'ERROR'
    }
}
catch {
    $script:RemediationResult.Status = "Error"
    $script:RemediationResult.Error = @{
        Message    = $_.Exception.Message
        Type       = $_.Exception.GetType().FullName
        StackTrace = $_.ScriptStackTrace
    }
    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
    Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally {
    Write-Log -Message "Cleanup complete." -Level 'DEBUG'
}


