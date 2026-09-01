<#
.TITLE
    Intune Driver Approve Bulk

.SYNOPSIS
    Approves every pending Windows driver update across all Intune driver update profiles via Microsoft Graph.

.DESCRIPTION
    Installs the required Microsoft Graph modules, authenticates with Microsoft Graph using an
    interactive user account (MFA supported), fetches all Windows driver update profiles, and for each
    profile pulls the full paginated driver inventory filtered to category 'other' with approvalStatus
    'needsreview'. Every pending driver is approved through the executeAction action with an ISO 8601
    deployment date, then the session is disconnected.

.TAGS
    Intune,Graph,Drivers,WindowsUpdate,BulkApproval

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    DeviceManagementConfiguration.ReadWrite.All (delegated, consented during interactive sign-in).

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-08-27)
    - Added SupportsShouldProcess and -Force gate; mandatory confirmation prompt before bulk-approving drivers (per-profile preview)
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, retry helper)
    - Manual @odata.nextLink loops replaced by Get-MgGraphAllPages; approval POSTs wrapped in Invoke-MgGraphRequestWithRetry
    1.0.0 (2024-11-03)
    - Initial release

.LASTUPDATE
    2026-08-27

.EXAMPLE
    .\Approve-IntuneDriverUpdates.ps1
    Signs in interactively, approves all drivers awaiting review, and disconnects from Microsoft Graph.

.EXAMPLE
    .\Approve-IntuneDriverUpdates.ps1 -Verbose
    Same run with verbose preference; per-request details are also captured in the log file.

.NOTES
    - Endpoints stay on the beta service: windowsDriverUpdateProfiles, driverInventories and microsoft.graph.executeAction.
    - The profile list itself is read from the first page only (legacy behavior); inventories are fully paginated.
    - Requires the Microsoft.Graph.Authentication and Microsoft.Graph.Beta.DeviceManagement.Actions modules (installed per-user when missing).
    - Logs: C:\ProgramData\Approve-IntuneDriverUpdates\Logs\
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantId = "",

    [Parameter(Mandatory = $false)]
    [string]$AppId = "",

    [Parameter(Mandatory = $false)]
    [string]$AppSecret = "",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and Graph constants.
# ============================================================================

$SolutionName = 'Approve-IntuneDriverUpdates'
$ScriptMode   = 'ApproveDrivers'

$GraphScopes  = "DeviceManagementConfiguration.ReadWrite.All"
$ProfileUrl   = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/"

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
# MODULE PREPARATION
# Installs the Graph modules the legacy script depended on (current user scope).
# ============================================================================

# Installs a required Microsoft Graph module for the current user when it is missing.
function Install-RequiredGraphModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        try {
            Install-Module -Name $ModuleName -Scope CurrentUser -Repository PSGallery -Force
            Write-Log -Message "$DisplayName Installed Successfully" -Level 'SUCCESS'
        }
        catch {
            Finish-Script -ExitCode 1 -Message "Failed to Install ${DisplayName}: $($_.Exception.Message)" -Level 'ERROR'
        }
    }
    else {
        Write-Log -Message "$DisplayName Already Installed" -Level 'SUCCESS'
    }
}

# ============================================================================
# AUTHENTICATION
# Client-credentials token acquisition honoring Graph module major version.
# ============================================================================

# Authenticates to Microsoft Graph via app-only client credentials or interactive user scopes.
function Connect-ToGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)] [string]$Tenant,
        [Parameter(Mandatory = $false)] [string]$AppId,
        [Parameter(Mandatory = $false)] [string]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$Scopes = "DeviceManagementConfiguration.ReadWrite.All"
    )

    $version = (Get-Module Microsoft.Graph.Authentication | Select-Object -ExpandProperty Version).Major

    if ($AppId) {
        $body = @{
            grant_type    = "client_credentials"
            client_id     = $AppId
            client_secret = $AppSecret
            scope         = "https://graph.microsoft.com/.default"
        }

        $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token" -Body $body
        $accessToken = $response.access_token

        if ($version -eq 2) {
            Write-Log -Message "Version 2 module detected" -Level 'DEBUG'
            $accessTokenFinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
        } else {
            Write-Log -Message "Version 1 Module Detected" -Level 'DEBUG'
            Select-MgProfile -Name Beta
            $accessTokenFinal = $accessToken
        }
        $null = Connect-MgGraph -AccessToken $accessTokenFinal
        Write-Log -Message "Connected to Intune tenant $Tenant using App-based Authentication" -Level 'SUCCESS'
    }
    else {
        if ($version -eq 2) {
            Write-Log -Message "Version 2 module detected" -Level 'DEBUG'
        } else {
            Write-Log -Message "Version 1 Module Detected" -Level 'DEBUG'
            Select-MgProfile -Name Beta
        }
        $null = Connect-MgGraph -Scopes $Scopes
        Write-Log -Message "Connected to Intune tenant $((Get-MgContext).TenantId)" -Level 'SUCCESS'
    }
}

# ============================================================================
# DRIVER APPROVAL
# Approves every driver inventory item that still awaits review.
# ============================================================================

# Approves one pending driver through the profile executeAction endpoint.
function Approve-PendingDriver {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriverProfileID,
        [Parameter(Mandatory = $true)]
        [string]$DriverID
    )

    $params = @{
        actionName     = "Approve"
        driverIds      = @($DriverID)
        deploymentDate = (Get-Date).ToString("o")
    }

    $approvalUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$DriverProfileID/microsoft.graph.executeAction"
    $response = Invoke-MgGraphRequestWithRetry -Uri $approvalUrl -Method 'POST' -Body ($params | ConvertTo-Json -Depth 3)

    if ($response) {
        Write-Log -Message "Driver $DriverID approved for deployment" -Level 'SUCCESS'
    } else {
        Write-Log -Message "Failed to approve driver $DriverID" -Level 'ERROR'
    }
}

# ============================================================================
# MAIN
# Flow: init -> install modules -> sign in -> approve pending drivers -> disconnect.
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }

    Write-Log -Message "Installing Microsoft Graph modules if required (current user scope)" -Level 'INFO'

    Install-RequiredGraphModule -ModuleName 'Microsoft.Graph.Authentication' -DisplayName 'Microsoft Graph Authentication Module'
    Install-RequiredGraphModule -ModuleName 'Microsoft.Graph.Beta.DeviceManagement.Actions' -DisplayName 'Microsoft Graph Beta Device Management Module'

    Import-Module Microsoft.Graph.Authentication
    Import-Module Microsoft.Graph.Beta.DeviceManagement.Actions

    if ($AppId) {
        if (-not $TenantId -or -not $AppSecret) {
            Finish-Script -ExitCode 1 -Message "TenantId and AppSecret are required when AppId is supplied" -Level 'ERROR'
        }
        Write-Log -Message "Connecting to Microsoft Graph with app-only authentication" -Level 'INFO'
        Connect-ToGraph -Tenant $TenantId -AppId $AppId -AppSecret $AppSecret -Scopes $GraphScopes
    }
    else {
        Write-Log -Message "Connecting to Microsoft Graph with scopes: $GraphScopes" -Level 'INFO'
        Connect-ToGraph -Scopes $GraphScopes
    }

    Write-Log -Message "Fetching and Approving Driver Updates" -Level 'INFO'

    $response = Invoke-MgGraphRequestWithRetry -Uri $ProfileUrl -Method 'GET'

    # Dry-run preview: count pending drivers per profile BEFORE any confirmation prompt,
    # so the operator sees the real blast radius before deciding.
    $pendingByProfile = @()
    foreach ($driverProfile in $response.value) {
        $driverProfileID = $driverProfile.id
        $url = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$driverProfileID/driverInventories?\$filter=category eq 'other' and approvalStatus eq 'needsreview'"
        $pendingDrivers = @(Get-MgGraphAllPages -Url $url)
        $pendingByProfile += [pscustomobject]@{
            ProfileId   = $driverProfileID
            ProfileName = $driverProfile.displayName
            Pending     = $pendingDrivers.Count
        }
    }

    $totalPending = ($pendingByProfile | Measure-Object -Property Pending -Sum).Sum
    if ($totalPending -eq 0) {
        Write-Log -Message "No pending drivers found across $($pendingByProfile.Count) profile(s). Nothing to approve." -Level 'SUCCESS'
        Disconnect-MgGraph
        Finish-Script -ExitCode 0 -Message "No pending drivers to approve." -Level 'SUCCESS'
    }

    Write-Log -Message "Pending driver counts per profile (category=other, approvalStatus=needsreview):" -Level 'INFO'
    foreach ($row in $pendingByProfile) {
        Write-Log -Message ("  - {0} ({1}): {2} pending" -f $row.ProfileName, $row.ProfileId, $row.Pending) -Level 'INFO'
    }
    Write-Log -Message ("Total pending drivers to approve: {0} across {1} profile(s)" -f $totalPending, $pendingByProfile.Count) -Level 'WARNING'

    if (-not $Force -and -not $PSCmdlet.ShouldProcess(
        ("Approve {0} pending driver(s) across {1} profile(s)" -f $totalPending, $pendingByProfile.Count),
        'Approve Intune driver updates',
        'Bulk driver approval')) {
        Write-Log -Message "Operator declined the confirmation prompt - no drivers were approved." -Level 'WARNING'
        Disconnect-MgGraph
        Finish-Script -ExitCode 0 -Message "Cancelled by operator." -Level 'INFO'
    }

    foreach ($driverProfile in $response.value) {
        $driverProfileID = $driverProfile.id

        # Legacy filter preserved exactly: category 'other' and approvalStatus 'needsreview'.
        $url = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$driverProfileID/driverInventories?\$filter=category eq 'other' and approvalStatus eq 'needsreview'"

        $pendingDrivers = Get-MgGraphAllPages -Url $url

        foreach ($item in $pendingDrivers) {
            $driverID = $item.id
            Approve-PendingDriver -DriverProfileID $driverProfileID -DriverID $driverID
        }
    }

    Disconnect-MgGraph
    Write-Log -Message "Disconnected from Microsoft Graph" -Level 'INFO'

    Finish-Script -ExitCode 0 -Message "Driver approval run completed" -Level 'SUCCESS'
}
catch {
    Finish-Script -ExitCode 1 -Message "Script error: $($_.Exception.Message)" -Level 'ERROR'
}
