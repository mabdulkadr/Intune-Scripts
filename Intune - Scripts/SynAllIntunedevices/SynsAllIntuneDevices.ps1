﻿<#
.SYNOPSIS
    Automates the synchronization of all enrolled devices in Microsoft Intune via Microsoft Graph API.

.DESCRIPTION
    This PowerShell script installs the necessary Microsoft Graph modules if they are not already installed, and authenticates with Microsoft Graph using either app-based or user-based authentication (supports MFA). It retrieves all managed devices enrolled in Microsoft Intune, handles paginated results to ensure all devices are processed, and sends a sync command to each device to initiate synchronization. The script also ensures proper disconnection from Microsoft Graph upon completion.

.EXAMPLE
    .\SynsAllIntuneDevices.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-03
#>

Write-Host "Installing Microsoft Graph modules if required (current user scope)"

# Install MS Graph module if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.authentication) {
    Write-Host "Microsoft Graph Already Installed"
} else {
    try {
        Install-Module -Name Microsoft.Graph.authentication -Scope CurrentUser -Repository PSGallery -Force
    } catch [Exception] {
        $_.message
        exit
    }
}

# Load the Graph module
Import-Module Microsoft.Graph.authentication

# Function to connect to Microsoft Graph
Function Connect-ToGraph {

    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$Tenant,
        [Parameter(Mandatory = $false)] [string]$AppId,
        [Parameter(Mandatory = $false)] [string]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$scopes
    )

    Process {
        # Import the Microsoft Graph Authentication module
        Import-Module Microsoft.Graph.Authentication

        # Get the major version of the Microsoft Graph Authentication module
        $version = (Get-Module Microsoft.Graph.Authentication | Select-Object -ExpandProperty Version).Major

        if ($AppId -ne "") {
            # If AppId is provided, use app-only authentication

            # Prepare the body for the OAuth 2.0 token request
            $body = @{
                grant_type    = "client_credentials";
                client_id     = $AppId;
                client_secret = $AppSecret;
                scope         = "https://graph.microsoft.com/.default";
            }

            # Request an access token from Azure AD
            $response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token -Body $body

            # Extract the access token from the response
            $accessToken = $response.access_token

            # Output the access token (for debugging purposes)
            $accessToken

            if ($version -eq 2) {
                # For version 2 of the module, convert the access token to a secure string
                Write-Host "Version 2 module detected"
                $accesstokenfinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            }
            else {
                # For version 1 of the module, select the Beta profile
                Write-Host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
                $accesstokenfinal = $accessToken
            }

            # Connect to Microsoft Graph using the access token
            $graph = Connect-MgGraph -AccessToken $accesstokenfinal 

            Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
        }
        else {
            # If AppId is not provided, use user authentication (interactive)
            if ($version -eq 2) {
                Write-Host "Version 2 module detected"
            }
            else {
                Write-Host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -Scopes $scopes
            Write-Host "Connected to Intune tenant $($graph.TenantId)"
        }
    }
}
# Connect to Microsoft Graph with specified scopes
Connect-ToGraph -Scopes "CloudPC.ReadWrite.All, Domain.Read.All, Directory.Read.All, DeviceManagementConfiguration.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, openid, profile, email, offline_access, DeviceManagementManagedDevices.PrivilegedOperations.All"

# Function to sync a device by its ID
Function SyncDevice {
    param (
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

# Retrieve the initial list of devices
$devices = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
$alldevices = @()
$alldevices += $devices.value
$policynextlink = $devices."@odata.nextlink"

# Handle paginated results
while ($null -ne $policynextlink) {
    $nextdevices = (Invoke-MgGraphRequest -Uri $policynextlink -Method Get -OutputType PSObject)
    $policynextlink = $nextdevices."@odata.nextLink"
    $alldevices += $nextdevices.value
}

# Send sync command to each device
foreach ($device in $alldevices) {
    SyncDevice -DeviceID $device.id
    $devicename = $device.deviceName
    Write-Host "Sync sent to $devicename"
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
