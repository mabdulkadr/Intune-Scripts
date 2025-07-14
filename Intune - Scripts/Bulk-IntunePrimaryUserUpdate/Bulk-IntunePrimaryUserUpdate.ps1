<#
.SYNOPSIS
    Sets the primary user for all Windows devices in Intune using Microsoft Graph API (App Authentication).

.DESCRIPTION
    This script connects to Microsoft Graph via a registered Azure AD App (client credentials),
    retrieves all Windows devices in Intune, and assigns the current userPrincipalName as the device's primary user.

    It uses REST API pagination to safely handle 5000+ devices.

.AUTHOR
    Mohammed Omar

.LINK
    Based on best practices from: https://www.linkedin.com/pulse/intune-primary-user-mix-up-dustin-gullett-kmwec/

.NOTES
    Filename: Bulk-IntunePrimaryUserUpdate.ps1
    Version: 1.0
    Date: 2025-05-13

.REQUIREMENTS
    - Azure AD App with the following API permissions (application type):
        * DeviceManagementManagedDevices.ReadWrite.All
        * User.Read.All
    - App Secret (client credentials flow)
    - PowerShell 5.1 or later

.EXAMPLE
    .\Bulk-IntunePrimaryUserUpdate.ps1
#>

# -----------------------------------------
# 🔐 APP REGISTRATION CONFIGURATION
# -----------------------------------------

$tenantID   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"   # Replace with your Tenant ID
$appID      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"   # Replace with your App (client) ID
$appSecret  = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"   # Replace with your App secret

# -----------------------------------------
# 🔗 GET ACCESS TOKEN
# -----------------------------------------

$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $appID
    client_secret = $appSecret
    scope         = "https://graph.microsoft.com/.default"
}

try {
    $tokenResponse = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token" -Body $tokenBody
    $accessToken = $tokenResponse.access_token
} catch {
    Write-Error "❌ Failed to get access token: $($_.Exception.Message)"
    exit
}

$headers = @{ Authorization = "Bearer $accessToken" }

# -----------------------------------------
# 🖥️ RETRIEVE ALL WINDOWS DEVICES
# -----------------------------------------

$graphApiVersion = "beta"
$resource = "deviceManagement/managedDevices"
$uri = "https://graph.microsoft.com/$graphApiVersion/$resource`?`$filter=operatingSystem eq 'Windows'"
$allDevices = @()

Write-Host "`n📦 Retrieving all Windows devices from Intune..." -ForegroundColor Cyan

do {
    try {
        $response = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
        $allDevices += $response.value
        $uri = $response.'@odata.nextLink'
    } catch {
        Write-Error "❌ Failed to retrieve devices: $($_.Exception.Message)"
        exit
    }
} while ($uri)

Write-Host "✅ Retrieved $($allDevices.Count) Windows devices." -ForegroundColor Green

# -----------------------------------------
# ⚠️ CONFIRM BEFORE APPLYING CHANGES
# -----------------------------------------

$response = Read-Host "`n⚠️ Set primary user for $($allDevices.Count) devices? (Y/N)"
if ($response -notin @('Y','y')) {
    Write-Host "❌ Operation cancelled by user." -ForegroundColor Red
    exit
}

# -----------------------------------------
# 🔁 PROCESS AND ASSIGN PRIMARY USERS
# -----------------------------------------

foreach ($device in $allDevices) {
    try {
        $deviceId = $device.id
        $deviceName = $device.deviceName
        $userUPN = $device.userPrincipalName

        if (-not $userUPN) {
            Write-Warning "⏭️ Skipping $deviceName : No userPrincipalName assigned."
            continue
        }

        # Get user object to retrieve user ID
        $userUri = "https://graph.microsoft.com/v1.0/users/$userUPN"
        $user = Invoke-RestMethod -Method GET -Uri $userUri -Headers $headers
        $userId = $user.id

        # Assign primary user
        $assignUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')/users/`$ref"
        $body = @{ "@odata.id" = "https://graph.microsoft.com/beta/users/$userId" } | ConvertTo-Json -Depth 3

        Invoke-RestMethod -Method POST -Uri $assignUri -Headers $headers -Body $body -ContentType "application/json"

        Write-Host "✅ [$deviceName] Primary user set to $userUPN" -ForegroundColor Green
    } catch {
        Write-Warning "❌ [$deviceName] Failed to set primary user: $($_.Exception.Message)"
    }

    Start-Sleep -Milliseconds 200  # Throttling control
}
