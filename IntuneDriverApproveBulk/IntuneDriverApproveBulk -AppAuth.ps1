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
    Author: Your Name
    Date: 2024-11-03
#>

# Define script parameters with default values
param (
    [Parameter(Mandatory = $true)]
    [string]$TenantID = "<Your Tenant ID>",

    [Parameter(Mandatory = $true)]
    [string]$AppID = "<Your Application (Client) ID>",

    [Parameter(Mandatory = $true)]
    [string]$AppSecret = "<Your Client Secret>"
)


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

# Install Microsoft.Graph.Beta.DeviceManagement.Actions Module if not installed
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

# Import the installed Microsoft Graph modules into the current session
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

    # Determine the version of the Microsoft Graph module
    $version = (Get-Module microsoft.graph.authentication).Version.Major

    if ($AppId) {
        # App-based Authentication
        $body = @{
            grant_type    = "client_credentials"
            client_id     = $AppId
            client_secret = $AppSecret
            scope         = "https://graph.microsoft.com/.default"
        }

        # Obtain the access token using client credentials flow
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

        # Connect to Microsoft Graph using the access token
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

        # Prompt the user to authenticate with Microsoft Graph
        Connect-MgGraph -Scopes $Scopes
        Write-Host "Connected to Intune tenant $((Get-MgTenant).TenantId)" -ForegroundColor Green
    }
}

####################################################
# Automatically Connect to Microsoft Graph using App-based Authentication
####################################################

# Call the Connect-ToGraph function with the provided parameters
Connect-ToGraph -Tenant $TenantID -AppId $AppID -AppSecret $AppSecret

####################################################
# Fetch and Approve Windows Driver Updates
####################################################
Write-Host "Fetching and Approving Driver Updates" -ForegroundColor Cyan

# Define the URL to fetch all Windows driver update profiles from Microsoft Graph
$profileUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/"

# Send a GET request to retrieve all driver update profiles
$response = Invoke-MgGraphRequest -Uri $profileUrl -Method GET

# Loop through each driver update profile retrieved from the response
foreach ($driverProfile in $response.value) {
    # Extract the ID of the current driver update profile
    $driverProfileID = $driverProfile.id

    # Construct the URL to fetch driver inventories that need review and belong to the 'other' category
    $url = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$driverProfileID/driverInventories?\$filter=category eq 'other' and approvalStatus eq 'needsreview'"

    # Initialize a loop to handle paginated results (if any)
    do {
        # Send a GET request to retrieve driver inventories matching the specified criteria
        $response2 = Invoke-MgGraphRequest -Uri $url -Method GET

        # Loop through each driver inventory item that needs review
        foreach ($item in $response2.value) {
            # Extract the ID of the driver that requires approval
            $driverID = $item.id

            # Prepare the parameters required to approve the driver update
            $params = @{
                actionName     = "Approve"                          # Action to perform
                driverIds      = @($driverID)                       # Driver IDs to approve
                deploymentDate = (Get-Date).ToString("o")           # Deployment date in ISO 8601 format
            }

            # Construct the URL to execute the approval action on the driver profile
            $approvalUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$driverProfileID/microsoft.graph.executeAction"

            # Send a POST request to approve the driver update
            $response = Invoke-MgGraphRequest -Uri $approvalUrl -Method POST -Body ($params | ConvertTo-Json -Depth 3)

            # Check if the approval was successful and display the appropriate message
            if ($response) {
                Write-Host "Driver $driverID approved for deployment" -ForegroundColor Green
            } else {
                Write-Host "Failed to approve driver $driverID" -ForegroundColor Red
            }
        }

        # Update the URL with the next page link if more results are available (pagination)
        $url = $response2.'@odata.nextLink'
    } while ($null -ne $url)  # Continue looping until all pages are processed
}

####################################################
# Disconnect from Microsoft Graph
####################################################
Disconnect-MgGraph
Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Cyan
