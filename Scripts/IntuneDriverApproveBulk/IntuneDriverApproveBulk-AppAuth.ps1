<#
.SYNOPSIS
    Automates the approval of pending Windows driver updates in Microsoft Intune via Microsoft Graph API using app-based authentication.

.DESCRIPTION
    This PowerShell script installs the necessary Microsoft Graph modules, authenticates with Microsoft Graph using app-based authentication, fetches all Windows driver updates that require review, and approves them for deployment in Microsoft Intune. It includes a function to connect to Microsoft Graph using either user-based or app-based authentication. The script defaults to using app-based authentication with provided Tenant ID, App ID, and App Secret.

.PARAMETER TenantID
    The Azure AD Tenant ID. Replace '<Your Tenant ID>' with your actual Tenant ID.

.PARAMETER AppID
    The Application (Client) ID of your Azure AD app registration. Replace '<Your Application (Client) ID>' with your actual App ID.

.PARAMETER AppSecret
    The Client Secret of your Azure AD app registration. Replace '<Your Client Secret>' with your actual App Secret.

.EXAMPLE
    .\IntuneDriverApproveBulk -AppAuth.ps1 -TenantID "your-tenant-id" -AppID "your-app-id" -AppSecret "your-app-secret"

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-03
#>

####################################################
# Automatically Connect to Microsoft Graph using App-based Authentication
####################################################
$tenantID    = "<Your Tenant ID>"                     #Tenant ID
$appID       = "<Your Application (Client) ID>"       #Client ID
$appSecret   = "<Your Client Secret>"                 #Client Secret

####################################################
# Install and Import Microsoft Graph Modules
####################################################
Write-Host "Installing Microsoft Graph modules if required (current user scope)" -ForegroundColor Cyan

# Install Microsoft Graph Authentication Module if not installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    try {
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force
        Write-Host "Microsoft Graph Authentication Module Installed Successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to Install Microsoft Graph Authentication Module: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "Microsoft Graph Authentication Module Already Installed" -ForegroundColor Green
}

# Install Microsoft.Graph.Beta.DeviceManagement.Actions if not installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Beta.DeviceManagement.Actions)) {
    try {
        Install-Module -Name Microsoft.Graph.Beta.DeviceManagement.Actions -Scope CurrentUser -Repository PSGallery -Force
        Write-Host "Microsoft Graph Beta Device Management Module Installed Successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to Install Microsoft Graph Beta Device Management Module: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "Microsoft Graph Beta Device Management Module Already Installed" -ForegroundColor Green
}

# Import necessary modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Beta.DeviceManagement.Actions


####################################################
# Function to Connect to Microsoft Graph
####################################################
function Connect-ToGraph {
    param (
        [Parameter(Mandatory = $false)] [string]$Tenant,
        [Parameter(Mandatory = $false)] [string]$AppId,
        [Parameter(Mandatory = $false)] [string]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$Scopes = "DeviceManagementConfiguration.ReadWrite.All"
    )

    $version = (Get-Module microsoft.graph.authentication).Version.Major

    if ($AppId) {
        # App-based Authentication
        $body = @{
            grant_type    = "client_credentials"
            client_id     = $AppId
            client_secret = $AppSecret
            scope         = "https://graph.microsoft.com/.default"
        }

        $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token" -Body $body
        $accessToken = $response.access_token

        if ($version -eq 2) {
            Write-Host "Version 2 module detected" -ForegroundColor Yellow
            $accessTokenFinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
        } else {
            Write-Host "Version 1 Module Detected" -ForegroundColor Yellow
            Select-MgProfile -Name Beta
            $accessTokenFinal = $accessToken
        }
        Connect-MgGraph -AccessToken $accessTokenFinal
        Write-Host "Connected to Intune tenant $Tenant using App-based Authentication" -ForegroundColor Green
    } else {
        # User-based Authentication
        if ($version -eq 2) {
            Write-Host "Version 2 module detected" -ForegroundColor Yellow
        } else {
            Write-Host "Version 1 Module Detected" -ForegroundColor Yellow
            Select-MgProfile -Name Beta
        }
        Connect-MgGraph -Scopes $Scopes
        Write-Host "Connected to Intune tenant $((Get-MgTenant).TenantId)" -ForegroundColor Green
    }
}


Connect-ToGraph -Tenant $tenantID -AppId $appID -AppSecret $appSecret

####################################################
# Fetch and Approve Windows Driver Updates
####################################################
Write-Host "Fetching and Approving Driver Updates" -ForegroundColor Cyan

# Fetch all driver update profiles
$profileUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/"
$response = Invoke-MgGraphRequest -Uri $profileUrl -Method GET

# Loop through each driver profile
foreach ($driverProfile in $response.value) {
    $driverProfileID = $driverProfile.id
    $url = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$driverProfileID/driverInventories?\$filter=category eq 'other' and approvalStatus eq 'needsreview'"

    do {
        $response2 = Invoke-MgGraphRequest -Uri $url -Method GET

        foreach ($item in $response2.value) {
            $driverID = $item.id
            $params = @{
                actionName    = "Approve"
                driverIds     = @($driverID)
                # Format deploymentDate as an ISO 8601 DateTimeOffset string
                deploymentDate = (Get-Date).ToString("o") # ISO 8601 format for DateTimeOffset
            }

            # Use REST API to approve the driver update
            $approvalUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$driverProfileID/microsoft.graph.executeAction"
            $response = Invoke-MgGraphRequest -Uri $approvalUrl -Method POST -Body ($params | ConvertTo-Json -Depth 3)

            if ($response) {
                Write-Host "Driver $driverID approved for deployment" -ForegroundColor Green
            } else {
                Write-Host "Failed to approve driver $driverID" -ForegroundColor Red
            }
        }

        $url = $response2.'@odata.nextLink'
    } while ($null -ne $url)
}

####################################################
# Disconnect from Microsoft Graph
####################################################
Disconnect-MgGraph
Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Cyan
