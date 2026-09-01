<#
.TITLE
    Sync All Intune Devices

.SYNOPSIS
    Sends the syncDevice command to every managed device enrolled in Intune via Microsoft Graph.

.DESCRIPTION
    Installs the Microsoft Graph Authentication module when missing, authenticates to Microsoft Graph
    interactively with an MFA-capable account, retrieves the full paginated list of managed devices,
    and posts a syncDevice action for each device so it checks back in with the service immediately.
    The session is disconnected when the run completes.

.TAGS
    Intune,Graph,Devices,Sync,BulkExecution

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.ReadWrite.All, DeviceManagementManagedDevices.PrivilegedOperations.All, DeviceManagementConfiguration.ReadWrite.All, CloudPC.ReadWrite.All, Domain.Read.All, Directory.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, retry and pagination helpers)
    - Removed legacy console echo of the raw access token (secret hygiene)
    - Manual @odata.nextLink loop replaced by Get-MgGraphAllPages; sync POSTs wrapped in Invoke-MgGraphRequestWithRetry
    1.0.0 (2024-11-03)
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Sync-AllIntuneDevices.ps1
    Signs in interactively, then sends a sync request to every enrolled device.

.EXAMPLE
    .\Sync-AllIntuneDevices.ps1 -Verbose
    Same run with verbose preference; per-request details are also captured in the log file.

.NOTES
    - Endpoints stay on the beta service (deviceManagement/managedDevices and syncDevice).
    - Triggering sync on every device at once creates a burst of check-ins; schedule accordingly.
    - Logs: C:\ProgramData\Sync-AllIntuneDevices\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantId = "",

    [Parameter(Mandatory = $false)]
    [string]$AppId = "",

    [Parameter(Mandatory = $false)]
    [SecureString]$AppSecret,

    [Parameter(Mandatory = $false)]
    [string]$Scopes = "CloudPC.ReadWrite.All, Domain.Read.All, Directory.Read.All, DeviceManagementConfiguration.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, DeviceManagementManagedDevices.PrivilegedOperations.All"
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and Graph constants.
# ============================================================================

$SolutionName = 'Sync-AllIntuneDevices'
$ScriptMode   = 'SyncDevices'

$GraphApiVersion = "beta"
$Resource        = "deviceManagement/managedDevices"

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
# GRAPH HELPERS
# Thin retry wrapper plus canonical pagination for Microsoft Graph calls.
# URIs, methods and bodies are passed through untouched.
# ============================================================================

# Calls Invoke-MgGraphRequest and retries transient HTTP 429/503 failures up to 5 attempts.
function Invoke-MgGraphRequestWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $false)]
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',
        [Parameter(Mandatory = $false)]
        [object]$Body,
        [Parameter(Mandatory = $false)]
        [string]$ContentType,
        [Parameter(Mandatory = $false)]
        [int]$MaxAttempts = 5
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $invokeParameters = @{
                Uri        = $Uri
                Method     = $Method
                OutputType = 'PSObject'
            }
            if ($null -ne $Body) {
                $invokeParameters['Body'] = $Body
            }
            if ($ContentType) {
                $invokeParameters['ContentType'] = $ContentType
            }
            return Invoke-MgGraphRequest @invokeParameters
        }
        catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { $statusCode = $null }
            }
            if (-not $statusCode -and $_.Exception.Message -match '\(429\)') { $statusCode = 429 }
            if (-not $statusCode -and $_.Exception.Message -match '\(503\)') { $statusCode = 503 }

            if ($statusCode -ne 429 -and $statusCode -ne 503) {
                throw
            }

            $retrySeconds = $null
            try {
                $retryAfter = $_.Exception.Response.Headers.RetryAfter
                if ($retryAfter -and $retryAfter.Delta) {
                    $retrySeconds = [int][Math]::Ceiling($retryAfter.Delta.TotalSeconds)
                }
            }
            catch {
                $retrySeconds = $null
            }
            if (-not $retrySeconds) {
                $retrySeconds = [Math]::Min(60, 2 * $attempt)
            }

            Write-Log -Message "Transient Graph error (HTTP $statusCode) on attempt $attempt of $MaxAttempts - retrying in $retrySeconds second(s)" -Level 'WARNING'
            Start-Sleep -Seconds $retrySeconds
        }
    }
    throw "Graph request to '$Uri' failed after $MaxAttempts attempts"
}

# Collects every page of a paged Graph collection using @odata.nextLink.
function Get-MgGraphAllPages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $response = Invoke-MgGraphRequestWithRetry -Uri $Url -Method 'GET'
    $results  = @($response.value)
    $nextLink = $response.'@odata.nextLink'

    while ($null -ne $nextLink) {
        $pageResponse = Invoke-MgGraphRequestWithRetry -Uri $nextLink -Method 'GET'
        $nextLink = $pageResponse.'@odata.nextLink'
        $results += @($pageResponse.value)
    }

    return ,@($results)
}

# ============================================================================
# AUTHENTICATION
# Wrapper kept from the legacy script: client-credentials token acquisition or
# interactive scope consent, honoring Graph module major version differences.
# ============================================================================

# Authenticates to Microsoft Graph via app-only client credentials or interactive user scopes.
function Connect-ToGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)] [string]$Tenant,
        [Parameter(Mandatory = $false)] [string]$AppId,
        [Parameter(Mandatory = $false)] [SecureString]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$Scopes
    )

    Process {
        Import-Module Microsoft.Graph.Authentication
        $version = (Get-Module Microsoft.Graph.Authentication | Select-Object -ExpandProperty Version).Major

        if ($AppId -ne "") {
            if (-not $AppSecret) { throw "AppSecret is required when AppId is supplied for app-only authentication." }
            # Convert SecureString to plain text only for the token request body; clear immediately after use.
            $plainSecret = [System.Net.NetworkCredential]::new('', $AppSecret).Password
            # App-only authentication path (retained from the shared wrapper).
            $body = @{
                grant_type    = "client_credentials";
                client_id     = $AppId;
                client_secret = $plainSecret;
                scope         = "https://graph.microsoft.com/.default";
            }
            $plainSecret = $null

            $response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token -Body $body
            $accessToken = $response.access_token

            if ($version -eq 2) {
                Write-Log -Message "Version 2 module detected" -Level 'DEBUG'
                $accessTokenFinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            }
            else {
                Write-Log -Message "Version 1 Module Detected" -Level 'DEBUG'
                Select-MgProfile -Name Beta
                $accessTokenFinal = $accessToken
            }

            $graph = Connect-MgGraph -AccessToken $accessTokenFinal
            Write-Log -Message "Connected to Intune tenant $Tenant using app-based authentication (Azure AD authentication not supported)" -Level 'SUCCESS'
        }
        else {
            # Interactive user authentication path used by this script.
            if ($version -eq 2) {
                Write-Log -Message "Version 2 module detected" -Level 'DEBUG'
            }
            else {
                Write-Log -Message "Version 1 Module Detected" -Level 'DEBUG'
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -Scopes $Scopes
            Write-Log -Message "Connected to Intune tenant $($graph.TenantId)" -Level 'SUCCESS'
        }
    }
}

# ============================================================================
# DEVICE SYNC
# Posts the syncDevice action for one managed device.
# ============================================================================

# Sends the syncDevice action to one managed device by ID.
function Sync-Device {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceID
    )
    $Resource = "deviceManagement/managedDevices('$DeviceID')/syncDevice"
    $uri = "https://graph.microsoft.com/Beta/$($Resource)"
    Write-Log -Message "Sending sync command to $DeviceID" -Level 'DEBUG'
    $null = Invoke-MgGraphRequestWithRetry -Uri $uri -Method 'POST' -Body $null
}

# ============================================================================
# MAIN
# Flow: init -> install module -> connect -> enumerate devices -> sync each -> disconnect.
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }

    Write-Log -Message "Installing Microsoft Graph modules if required (current user scope)" -Level 'INFO'

    if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
        Write-Log -Message "Microsoft Graph Already Installed" -Level 'INFO'
    }
    else {
        try {
            Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force
        }
        catch [System.Exception] {
            Finish-Script -ExitCode 1 -Message "Failed to install Microsoft.Graph.Authentication: $($_.Exception.Message)" -Level 'ERROR'
        }
    }

    Import-Module Microsoft.Graph.Authentication

    if ($AppId) {
        if (-not $TenantId -or -not $AppSecret) {
            Finish-Script -ExitCode 1 -Message "TenantId and AppSecret are required when AppId is supplied" -Level 'ERROR'
        }
        Connect-ToGraph -Tenant $TenantId -AppId $AppId -AppSecret $AppSecret -Scopes $Scopes
    }
    else {
        Connect-ToGraph -Scopes $Scopes
    }

    # Enumerate every managed device across all pages.
    $uri = "https://graph.microsoft.com/$GraphApiVersion/$Resource"
    $alldevices = Get-MgGraphAllPages -Url $uri

    foreach ($device in $alldevices) {
        Sync-Device -DeviceID $device.id
        $devicename = $device.deviceName
        Write-Log -Message "Sync sent to $devicename" -Level 'INFO'
    }

    Disconnect-MgGraph
    Finish-Script -ExitCode 0 -Message "Sync command sent to $($alldevices.Count) device(s)" -Level 'SUCCESS'
}
catch {
    Finish-Script -ExitCode 1 -Message "Script error: $($_.Exception.Message)" -Level 'ERROR'
}

