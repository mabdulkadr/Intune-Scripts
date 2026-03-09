<#
.SYNOPSIS
    Detects whether this Intune device has a primary user assigned.

.DESCRIPTION
    This detection script connects to Microsoft Graph using app-only authentication,
    locates the current device in Intune by device name, then checks whether the
    device already has one or more assigned primary users.

    Exit codes:
    - Exit 0: Compliant (primary user exists)
    - Exit 1: Not compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\IntunePrimaryUserUpdate--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# App registration settings
$TenantId     = ' '
$ClientId     = ' '
$ClientSecret = ' '

# Script metadata
$ScriptName     = 'IntunePrimaryUserUpdate--Detect.ps1'
$ScriptBaseName = 'IntunePrimaryUserUpdate--Detect'
$SolutionName   = 'Intune Primary User Update'


# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    'C:'
}

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

# Current device name
$DeviceName = $env:COMPUTERNAME

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if needed
function Initialize-Logging {
    try {
        if (-not (Test-Path -LiteralPath $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

# Write log line to console and file
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$TimeStamp] [$Level] $Message"

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

# Get Graph access token
function Get-GraphAccessToken {
    $Body = @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = 'https://graph.microsoft.com/.default'
    }

    $TokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $TokenResponse = Invoke-RestMethod -Method Post -Uri $TokenUri -Body $Body -ErrorAction Stop

    if (-not $TokenResponse.access_token) {
        throw 'Access token was not returned from Microsoft identity platform.'
    }

    return $TokenResponse.access_token
}

# Invoke Graph request with shared headers
function Invoke-GraphGet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers -ErrorAction Stop
}

# Find current Intune managed device by device name
function Get-ManagedDeviceByName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $SafeName = $Name.Replace("'", "''")
    $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=deviceName eq '$SafeName'"

    $Response = Invoke-GraphGet -Uri $Uri -Headers $Headers

    if (-not $Response.value) {
        return $null
    }

    $Devices = @($Response.value)

    if ($Devices.Count -eq 1) {
        return $Devices[0]
    }

    if ($Devices.Count -gt 1) {
        # Prefer exact device name match first
        $ExactMatch = $Devices | Where-Object { $_.deviceName -eq $Name } | Select-Object -First 1
        if ($ExactMatch) {
            return $ExactMatch
        }

        return $Devices[0]
    }

    return $null
}

# Get primary users assigned to managed device
function Get-ManagedDevicePrimaryUsers {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManagedDeviceId,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$ManagedDeviceId')/users"
    $Response = Invoke-GraphGet -Uri $Uri -Headers $Headers

    if (-not $Response.value) {
        return @()
    }

    return @(
        $Response.value |
        Where-Object { $_.userPrincipalName } |
        Select-Object -ExpandProperty userPrincipalName
    )
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Computer name: $DeviceName"
Write-Log -Message "Log file: $LogFile"

try {
    # Basic config validation
    if ([string]::IsNullOrWhiteSpace($TenantId) -or
        [string]::IsNullOrWhiteSpace($ClientId) -or
        [string]::IsNullOrWhiteSpace($ClientSecret)) {
        Write-Log -Message 'TenantId, ClientId, or ClientSecret is empty.' -Level 'ERROR'
        exit 1
    }

    # Get Graph token
    Write-Log -Message 'Requesting Microsoft Graph access token...'
    $AccessToken = Get-GraphAccessToken
    $Headers = @{
        Authorization = "Bearer $AccessToken"
    }
    Write-Log -Message 'Graph access token acquired successfully.' -Level 'SUCCESS'

    # Find current device in Intune
    Write-Log -Message "Searching Intune managed device by name: $DeviceName"
    $ManagedDevice = Get-ManagedDeviceByName -Name $DeviceName -Headers $Headers

    if (-not $ManagedDevice) {
        Write-Log -Message "Device '$DeviceName' was not found in Intune managedDevices." -Level 'ERROR'
        Write-Output 'Not Compliant'
        exit 1
    }

    Write-Log -Message "Managed device found. Intune device ID: $($ManagedDevice.id)"
    Write-Log -Message "Azure AD device ID: $($ManagedDevice.azureADDeviceId)"
    Write-Log -Message "Operating system: $($ManagedDevice.operatingSystem)"

    # Check primary users
    Write-Log -Message 'Checking assigned primary user(s)...'
    $PrimaryUsers = Get-ManagedDevicePrimaryUsers -ManagedDeviceId $ManagedDevice.id -Headers $Headers

    if ($PrimaryUsers.Count -gt 0) {
        Write-Log -Message "Primary user(s) already assigned: $($PrimaryUsers -join ', ')" -Level 'SUCCESS'
        Write-Output 'Compliant'
        exit 0
    }

    Write-Log -Message 'No primary user is assigned to this Intune device.' -Level 'WARNING'
    Write-Output 'Not Compliant'
    exit 1
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Output 'Not Compliant'
    exit 1
}

#endregion ---------- Detection Logic ----------