<#
.SYNOPSIS
    Assigns the current logged-on user as the device primary user in Intune.

.DESCRIPTION
    This remediation script:
    1. Detects the currently active logged-on user
    2. Connects to Microsoft Graph using app-only authentication
    3. Finds the current Intune managed device by computer name
    4. Finds the user by UPN
    5. Checks existing primary user assignments
    6. Assigns the detected user as primary user when needed

    Exit codes:
    - Exit 0: Completed successfully or no action required
    - Exit 1: Failed

.RUN AS
    System

.EXAMPLE
    .\IntunePrimaryUserUpdate--Remediate.ps1

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
$ScriptName     = 'IntunePrimaryUserUpdate--Remediate.ps1'
$ScriptBaseName = 'IntunePrimaryUserUpdate--Remediate'
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

function Invoke-GraphGet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers -ErrorAction Stop
}

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

function Get-ActiveLoggedOnUser {
    try {
        $RawOutput = (& query user) 2>$null
        if (-not $RawOutput) {
            return $null
        }

        $Lines = @($RawOutput | Select-Object -Skip 1)
        if (-not $Lines -or $Lines.Count -eq 0) {
            return $null
        }

        $ActiveSessions = @($Lines | Where-Object { $_ -match '\s+Active\s+' })
        if (-not $ActiveSessions -or $ActiveSessions.Count -eq 0) {
            return $null
        }

        $ConsoleSession = $ActiveSessions | Where-Object { $_ -match '\s+console\s+' } | Select-Object -First 1
        $PickedSession  = if ($ConsoleSession) { $ConsoleSession } else { $ActiveSessions | Select-Object -First 1 }

        $UserField = ($PickedSession -replace '^\s*>?\s*','' -split '\s+')[0]
        if ([string]::IsNullOrWhiteSpace($UserField)) {
            return $null
        }

        return $UserField
    }
    catch {
        return $null
    }
}

function Convert-SamToUpn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SamAccountName
    )

    return "$SamAccountName@$DefaultUpnSuffix"
}

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

    $ExactMatch = $Devices | Where-Object { $_.deviceName -eq $Name } | Select-Object -First 1
    if ($ExactMatch) {
        return $ExactMatch
    }

    return $Devices[0]
}

function Get-GraphUserByUpn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $SafeUpn = [uri]::EscapeDataString($UserPrincipalName)
    $Uri = "https://graph.microsoft.com/v1.0/users/$SafeUpn"
    return Invoke-GraphGet -Uri $Uri -Headers $Headers
}

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

    return @($Response.value)
}

function Add-ManagedDevicePrimaryUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManagedDeviceId,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$ManagedDeviceId')/users/`$ref"
    $Body = @{
        '@odata.id' = "https://graph.microsoft.com/beta/users/$UserId"
    } | ConvertTo-Json

    Invoke-GraphPost -Uri $Uri -Headers $Headers -Body $Body | Out-Null
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Computer name: $DeviceName"
Write-Log -Message "Log file: $LogFile"

try {
    if ([string]::IsNullOrWhiteSpace($TenantId) -or
        [string]::IsNullOrWhiteSpace($ClientId) -or
        [string]::IsNullOrWhiteSpace($ClientSecret)) {
        Write-Log -Message 'TenantId, ClientId, or ClientSecret is empty.' -Level 'ERROR'
        exit 1
    }

    # Detect active user
    $SamAccountName = Get-ActiveLoggedOnUser
    if (-not $SamAccountName) {
        Write-Log -Message 'No active logged-on user was found. No action required.' -Level 'SUCCESS'
        exit 0
    }

    $UPN = Convert-SamToUpn -SamAccountName $SamAccountName
    Write-Log -Message "Detected active user: $UPN"

    # Get Graph token
    Write-Log -Message 'Requesting Microsoft Graph access token...'
    $AccessToken = Get-GraphAccessToken
    $Headers = @{
        Authorization = "Bearer $AccessToken"
    }
    Write-Log -Message 'Graph access token acquired successfully.' -Level 'SUCCESS'

    # Find device
    Write-Log -Message "Searching Intune managed device by name: $DeviceName"
    $ManagedDevice = Get-ManagedDeviceByName -Name $DeviceName -Headers $Headers

    if (-not $ManagedDevice) {
        Write-Log -Message "Device '$DeviceName' was not found in Intune managedDevices." -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "Managed device found. Intune device ID: $($ManagedDevice.id)"

    # Find user
    Write-Log -Message "Looking up user by UPN: $UPN"
    $GraphUser = Get-GraphUserByUpn -UserPrincipalName $UPN -Headers $Headers

    if (-not $GraphUser -or -not $GraphUser.id) {
        Write-Log -Message "User lookup failed for $UPN" -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "User found. User ID: $($GraphUser.id)"

    # Check current primary users
    Write-Log -Message 'Checking existing primary user assignments...'
    $ExistingPrimaryUsers = Get-ManagedDevicePrimaryUsers -ManagedDeviceId $ManagedDevice.id -Headers $Headers

    if ($ExistingPrimaryUsers.Count -gt 0) {
        $ExistingUpns = @(
            $ExistingPrimaryUsers |
            Where-Object { $_.userPrincipalName } |
            Select-Object -ExpandProperty userPrincipalName
        )

        Write-Log -Message "Existing primary user(s): $($ExistingUpns -join ', ')"

        $AlreadyAssigned = $ExistingPrimaryUsers | Where-Object { $_.id -eq $GraphUser.id } | Select-Object -First 1
        if ($AlreadyAssigned) {
            Write-Log -Message "$UPN is already assigned as primary user. No action required." -Level 'SUCCESS'
            exit 0
        }
    }
    else {
        Write-Log -Message 'No primary users are currently assigned.'
    }

    # Assign user
    Write-Log -Message "Assigning $UPN as primary user..."
    Add-ManagedDevicePrimaryUser -ManagedDeviceId $ManagedDevice.id -UserId $GraphUser.id -Headers $Headers

    Start-Sleep -Seconds 2

    # Verify assignment
    $UpdatedPrimaryUsers = Get-ManagedDevicePrimaryUsers -ManagedDeviceId $ManagedDevice.id -Headers $Headers
    $VerifiedAssignment = $UpdatedPrimaryUsers | Where-Object { $_.id -eq $GraphUser.id } | Select-Object -First 1

    if ($VerifiedAssignment) {
        Write-Log -Message "Successfully assigned $UPN as primary user for $DeviceName." -Level 'SUCCESS'
        exit 0
    }

    Write-Log -Message "Assignment request completed, but verification failed for $UPN." -Level 'ERROR'
    exit 1
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------