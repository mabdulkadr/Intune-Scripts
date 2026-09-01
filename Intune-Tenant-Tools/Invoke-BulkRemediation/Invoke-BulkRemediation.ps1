<#
.TITLE
    Bulk Run Remediations On Demand

.SYNOPSIS
    Triggers an Intune proactive remediation on demand across one or many managed devices via Microsoft Graph.

.DESCRIPTION
    Connects to Microsoft Graph either interactively (MFA-aware user sign-in) or with app-only
    client credentials when Tenant, ClientId and ClientSecret are supplied, then lets the operator
    pick a remediation (deviceHealthScripts) and target devices through Out-GridView, and posts the
    initiateOnDemandProactiveRemediation action for every selected device.

    Authentication modes:
    - Interactive: run without credentials and complete the browser sign-in.
    - App-only: pass -Tenant, -ClientId and -ClientSecret of an app registration holding the required
      application permissions with admin consent. Secrets must be injected at runtime from a secret
      store - never hardcode them in this file.

    Legacy behavior intentionally preserved:
    - All endpoints remain on the beta service (deviceHealthScripts, devicemanagement/managedDevices,
      initiateOnDemandProactiveRemediation).
    - The on-demand request body keeps its historical shape, including the trailing comma of the
      original payload, so tenant-side behavior does not change.

.TAGS
    Intune,Graph,Remediation,BulkExecution,ProactiveRemediation

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    Interactive mode requests these user scopes: Group.ReadWrite.All, Device.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, DeviceManagementServiceConfig.ReadWrite.All, GroupMember.ReadWrite.All, Domain.ReadWrite.All, Organization.Read.All, DeviceManagementManagedDevices.PrivilegedOperations.All, DeviceManagementScripts.ReadWrite.All. App-only mode requires the matching application permissions with admin consent.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-08-27)
    - Added SupportsShouldProcess and -Force gate; mandatory confirmation prompt before triggering remediation on every selected device
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, retry and pagination helpers)
    - Added Invoke-MgGraphRequestWithRetry (HTTP 429/503 honoring Retry-After, max 5 attempts)
    - Replaced manual pagination loops with Get-MgGraphAllPages
    1.0.3 (2025-09-12)
    - Another scopes fix (upstream)
    1.0.2 (2023-12-21)
    - Scopes fix (upstream)
    1.0.0 (2023-09-06)
    - Initial release by Andrew Taylor (https://github.com/andrew-s-taylor/public), GPL licensed

.LASTUPDATE
    2026-08-27

.EXAMPLE
    .\Invoke-BulkRemediation.ps1
    Interactive sign-in, then choose the remediation and the target devices in the grid view pickers.

.EXAMPLE
    .\Invoke-BulkRemediation.ps1 -Tenant "contoso.onmicrosoft.com" -ClientId "<app-client-id>" -ClientSecret "<app-secret>" -RemediationId "<deviceHealthScript-id>" -DeviceId "<managed-device-id-1>","<managed-device-id-2>"
    App-only authentication with the remediation and devices supplied directly (no grid view).

.NOTES
    - Based on the public script by Andrew Taylor (GPL); migrated to the enterprise standard by Mohammad Abdelkader Omar.
    - The legacy Authenticode signature block was removed because any modification invalidates the signature.
    - Out-GridView requires a desktop PowerShell host; on headless sessions supply -RemediationId and -DeviceId.
    - When devices are passed as raw IDs, the historical per-device display name lookup is skipped (legacy behavior).
    - Logs: C:\ProgramData\Invoke-BulkRemediation\Logs\
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$Tenant,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$RemediationId,
    [string[]]$DeviceId,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for logging and reporting.
# ============================================================================

$SolutionName = 'Invoke-BulkRemediation'
$ScriptMode   = 'OnDemand'

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
        [Parameter(Mandatory = $false)] [string]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$Scopes
    )

    Process {
        Import-Module Microsoft.Graph.Authentication
        $version = (Get-Module Microsoft.Graph.Authentication | Select-Object -ExpandProperty Version).Major

        if ($AppId -ne "") {
            $body = @{
                grant_type    = "client_credentials";
                client_id     = $AppId;
                client_secret = $AppSecret;
                scope         = "https://graph.microsoft.com/.default";
            }

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
# DEVICE INVENTORY
# Builds the grid-view device list exactly as the legacy script did.
# ============================================================================

# Returns one row per managed device with ID, name, operating system and primary user.
function Get-DevicesAndUsers {
    $allDevices = Get-MgGraphAllPages -Url "https://graph.microsoft.com/beta/devicemanagement/manageddevices"
    $outputArray = @()
    foreach ($value in $allDevices) {
        $objectDetails = [pscustomobject]@{
            DeviceID    = $value.id
            DeviceName  = $value.deviceName
            OSVersion   = $value.operatingSystem
            PrimaryUser = $value.userPrincipalName
        }
        $outputArray += $objectDetails
    }
    return $outputArray
}

# ============================================================================
# MAIN
# Flow: init -> connect -> pick remediation -> pick devices -> trigger on demand.
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }

    Write-Log -Message "Installing Intune modules if required (current user scope)" -Level 'INFO'

    if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
        Write-Log -Message "Microsoft Graph Already Installed" -Level 'INFO'
    }
    else {
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force
    }

    Import-Module Microsoft.Graph.Authentication

    Write-Log -Message "Connecting to Microsoft Graph" -Level 'DEBUG'

    if ($ClientId -and $ClientSecret -and $Tenant) {
        Connect-ToGraph -Tenant $Tenant -AppId $ClientId -AppSecret $ClientSecret
        Write-Log -Message "Graph Connection Established" -Level 'SUCCESS'
    }
    else {
        Connect-ToGraph -Scopes "Group.ReadWrite.All, Device.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, DeviceManagementServiceConfig.ReadWrite.All, GroupMember.ReadWrite.All, Domain.ReadWrite.All, Organization.Read.All, DeviceManagementManagedDevices.PrivilegedOperations.All, DeviceManagementScripts.ReadWrite.All"
    }

    Write-Log -Message "Checking if remediation set in parameters" -Level 'INFO'
    if (-not $RemediationId) {
        Write-Log -Message "Remediation not set, getting all remediations" -Level 'INFO'
        $remediations = Get-MgGraphAllPages -Url "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"

        Write-Log -Message "Choose remediation" -Level 'INFO'
        $selectedRemediation = $remediations | Select-Object displayName, id | Out-GridView -PassThru -Title "Remediation Selection"
        $displayName = $selectedRemediation.displayName
        Write-Log -Message "Remediation $displayName selected" -Level 'INFO'

        $RemediationId = $selectedRemediation.id
    }
    else {
        Write-Log -Message "Remediation set as $RemediationId from parameters" -Level 'INFO'
    }

    Write-Log -Message "Checking if device set in parameters" -Level 'INFO'
    if (-not $DeviceId) {
        Write-Log -Message "No parameter set, grabbing devices" -Level 'INFO'
        $devices = Get-DevicesAndUsers

        Write-Log -Message "Choose devices" -Level 'INFO'
        $selectedDevices = $devices | Select-Object DeviceID, DeviceName, OSVersion, PrimaryUser | Out-GridView -PassThru -Title "Device Selection"

        Write-Log -Message "Devices selected" -Level 'INFO'
    }
    else {
        Write-Log -Message "Devices set from parameters" -Level 'INFO'
        $selectedDevices = $DeviceId
    }

    # Mandatory confirmation prompt before triggering remediation on every selected device.
    $deviceCount = $selectedDevices.Count
    Write-Log -Message ("Remediation $RemediationId will be triggered on $deviceCount device(s).") -Level 'WARNING'
    if (-not $Force -and -not $PSCmdlet.ShouldProcess(
        ("Trigger remediation {0} on {1} device(s)" -f $RemediationId, $deviceCount),
        'Trigger Intune proactive remediation',
        'Bulk remediation trigger')) {
        Write-Log -Message "Operator declined the confirmation prompt - no remediation was triggered." -Level 'WARNING'
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Finish-Script -ExitCode 0 -Message "Cancelled by operator." -Level 'INFO'
    }

    # Legacy payload shape preserved verbatim, including the trailing comma.
    $json = @"
{
	"ScriptPolicyId": "$RemediationId",
}
"@
    $count = 0
    $allDeviceCount = $selectedDevices.count
    foreach ($device in $selectedDevices) {
        $count++
        Write-Log -Message "Running remediation on $($device.DeviceName) ($count of $allDeviceCount)" -Level 'INFO'
        $targetDeviceId = $device.DeviceID
        $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$targetDeviceId')/initiateOnDemandProactiveRemediation"
        $null = Invoke-MgGraphRequestWithRetry -Uri $url -Method 'Post' -Body $json -ContentType "application/json"
    }

    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Finish-Script -ExitCode 0 -Message "Remediation triggered on $allDeviceCount device(s)" -Level 'SUCCESS'
}
catch {
    Finish-Script -ExitCode 1 -Message "Script error: $($_.Exception.Message)" -Level 'ERROR'
}
