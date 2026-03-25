<#
.SYNOPSIS
    Automates the approval of pending Windows driver updates in Microsoft Intune via Microsoft Graph API.

.DESCRIPTION
    This PowerShell script installs the necessary Microsoft Graph modules, authenticates with Microsoft Graph using a user account (supports MFA), fetches all Windows driver updates that require review, and approves them for deployment in Microsoft Intune. It loops through all driver update profiles, handles pagination, and ensures all applicable drivers are processed.

.EXAMPLE
    .\IntuneDriverApproveBulk.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-03
#>


####################################################
# Install and Import Microsoft Graph Modules
####################################################

# Display a message indicating the start of module installation
Write-Host "Installing Microsoft Graph modules if required (current user scope)" -ForegroundColor Cyan

# Install Microsoft Graph Authentication Module if not already installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    try {
        # Install the module for the current user from the PowerShell Gallery
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force
        Write-Host "Microsoft Graph Authentication Module Installed Successfully" -ForegroundColor Green
    } catch {
        # Display an error message if installation fails and exit the script
        Write-Host "Failed to Install Microsoft Graph Authentication Module: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
} else {
    # Inform the user that the module is already installed
    Write-Host "Microsoft Graph Authentication Module Already Installed" -ForegroundColor Green
}

# Install Microsoft.Graph.Beta.DeviceManagement.Actions Module if not already installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Beta.DeviceManagement.Actions)) {
    try {
        # Install the module for the current user from the PowerShell Gallery
        Install-Module -Name Microsoft.Graph.Beta.DeviceManagement.Actions -Scope CurrentUser -Repository PSGallery -Force
        Write-Host "Microsoft Graph Beta Device Management Module Installed Successfully" -ForegroundColor Green
    } catch {
        # Display an error message if installation fails and exit the script
        Write-Host "Failed to Install Microsoft Graph Beta Device Management Module: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
} else {
    # Inform the user that the module is already installed
    Write-Host "Microsoft Graph Beta Device Management Module Already Installed" -ForegroundColor Green
}

# Import the installed Microsoft Graph modules into the current session
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Beta.DeviceManagement.Actions

####################################################
# Authenticate with an MFA-Enabled Account
####################################################

# Connect to Microsoft Graph using user-based authentication with the required scopes
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"

####################################################
# Fetch and Approve Windows Driver Updates
####################################################

# Display a message indicating the start of the driver update approval process
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

# Disconnect the session from Microsoft Graph to clean up resources
Disconnect-MgGraph

# Inform the user that the script has finished and the session is disconnected
Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Cyan
