<#
.SYNOPSIS
    Automates the synchronization of all enrolled devices in Microsoft Intune via Microsoft Graph API.

.DESCRIPTION
    This PowerShell script installs the necessary Microsoft Graph modules if they are not already installed, and authenticates with Microsoft Graph using either app-based or user-based authentication (supports MFA). It retrieves all managed devices enrolled in Microsoft Intune, handles paginated results to ensure all devices are processed, and sends a sync command to each device to initiate synchronization. The script also ensures proper disconnection from Microsoft Graph upon completion.

.EXAMPLE
    .\IntuneDriverApproveBulk -AppAuth.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-03
#>

Param(
    [string]$TenantID   = "<Your-Tenant-ID>",
    [string]$AppID      = "<Your-App-ID>",
    [string]$AppSecret  = "<Your-App-Secret>",
    [string]$Scopes     = "CloudPC.ReadWrite.All, Domain.Read.All, Directory.Read.All, DeviceManagementConfiguration.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, openid, profile, email, offline_access, DeviceManagementManagedDevices.PrivilegedOperations.All"
)

Write-Host "Installing Microsoft Graph modules if required (current user scope)"

# Install MS Graph module if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
    Write-Host "Microsoft Graph Already Installed"
} else {
    try {
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force
    } catch [Exception] {
        $_.Message
        exit
    }
}

# Load the Graph module
Import-Module Microsoft.Graph.Authentication

Function Connect-ToGraph {
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
            # App-based authentication
            $body = @{
                grant_type    = "client_credentials"
                client_id     = $AppId
                client_secret = $AppSecret
                scope         = "https://graph.microsoft.com/.default"
            }

            $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token" -Body $body
            $accessToken = $response.access_token

            if ($version -eq 2) {
                Write-Host "Version 2 module detected"
                $accessTokenFinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            } else {
                Write-Host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
                $accessTokenFinal = $accessToken
            }
            $graph = Connect-MgGraph -AccessToken $accessTokenFinal
            Write-Host "Connected to Intune tenant $Tenant using app-based authentication"
        } else {
            # User-based authentication
            if ($version -eq 2) {
                Write-Host "Version 2 module detected"
            } else {
                Write-Host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -Scopes $Scopes
            Write-Host "Connected to Intune tenant $($graph.TenantId)"
        }
    }
}

# Connect to Microsoft Graph
Connect-ToGraph -Tenant $TenantID -AppId $AppID -AppSecret $AppSecret -Scopes $Scopes

Function SyncDevice {
    param(
        [Parameter(Mandatory = $true)] [string]$DeviceID
    )
    $Resource = "deviceManagement/managedDevices('$DeviceID')/syncDevice"
    $uri = "https://graph.microsoft.com/Beta/$($Resource)"
    Write-Verbose $uri
    Write-Verbose "Sending sync command to $DeviceID"
    Invoke-MgGraphRequest -Uri $uri -Method Post -Body $null
}

# Sync All Devices
$graphApiVersion = "beta"
$Resource = "deviceManagement/managedDevices"
$uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"

$devices = Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject
$allDevices = @()
$allDevices += $devices.value
$policyNextLink = $devices."@odata.nextLink"

# Handle paginated results
while ($null -ne $policyNextLink) {
    $nextDevices = Invoke-MgGraphRequest -Uri $policyNextLink -Method Get -OutputType PSObject
    $policyNextLink = $nextDevices."@odata.nextLink"
    $allDevices += $nextDevices.value
}

# Send sync command to each device
foreach ($device in $allDevices) {
    SyncDevice -DeviceID $device.id
    $deviceName = $device.deviceName
    Write-Host "Sync sent to $deviceName"
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
