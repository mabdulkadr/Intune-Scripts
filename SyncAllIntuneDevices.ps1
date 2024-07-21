
<#PSScriptInfo
.DESCRIPTION Synchronises All Intune managed devices
#>

####################################################
Write-Host "Installing Microsoft Graph modules if required (current user scope)"

#Install MS Graph if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.authentication) {
    Write-Host "Microsoft Graph Already Installed"
} 
else {
    try {
        Install-Module -Name Microsoft.Graph.authentication -Scope CurrentUser -Repository PSGallery -Force 
    }
    catch [Exception] {
        $_.message 
        exit
    }
}


# Load the Graph module
Import-Module microsoft.graph.authentication
####################################################################### END INSTALL MODULES #######################################################################
   
   Function Connect-ToGraph {
    <#
.SYNOPSIS
Authenticates to the Graph API via the Microsoft.Graph.Authentication module.
 
.DESCRIPTION
The Connect-ToGraph cmdlet is a wrapper cmdlet that helps authenticate to the Intune Graph API using the Microsoft.Graph.Authentication module. It leverages an Azure AD app ID and app secret for authentication or user-based auth.
 
.PARAMETER Tenant
Specifies the tenant (e.g. contoso.onmicrosoft.com) to which to authenticate.
 
.PARAMETER AppId
Specifies the Azure AD app ID (GUID) for the application that will be used to authenticate.
 
.PARAMETER AppSecret
Specifies the Azure AD app secret corresponding to the app ID that will be used to authenticate.

.PARAMETER Scopes
Specifies the user scopes for interactive authentication.
 
.EXAMPLE
Connect-ToGraph -TenantId $tenantID -AppId $app -AppSecret $secret
 
-#>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$Tenant,
        [Parameter(Mandatory = $false)] [string]$AppId,
        [Parameter(Mandatory = $false)] [string]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$scopes
    )

    Process {
        Import-Module Microsoft.Graph.Authentication
        $version = (get-module microsoft.graph.authentication | Select-Object -expandproperty Version).major

        if ($AppId -ne "") {
            $body = @{
                grant_type    = "client_credentials";
                client_id     = $AppId;
                client_secret = $AppSecret;
                scope         = "https://graph.microsoft.com/.default";
            }
     
            $response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token -Body $body
            $accessToken = $response.access_token
     
            $accessToken
            if ($version -eq 2) {
                write-host "Version 2 module detected"
                $accesstokenfinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            }
            else {
                write-host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
                $accesstokenfinal = $accessToken
            }
            $graph = Connect-MgGraph  -AccessToken $accesstokenfinal 
            Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
        }
        else {
            if ($version -eq 2) {
                write-host "Version 2 module detected"
            }
            else {
                write-host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -scopes $scopes
            Write-Host "Connected to Intune tenant $($graph.TenantId)"
        }
    }
}    


####################################################################### CREATE AAD OBJECTS #######################################################################
# Connect to Graph Automatically
$tenantID = "c2b04da6-8487-41cc-8803-90321048a772"
$appID = "6c70c0c3-e3a6-489c-973e-51e8138540f9"          #ClientID
$appSecret = "Uoj8Q~1_acd.7WU4Ol3vOczrfeYQbdHR_mzhTb6n"  #Value

Connect-ToGraph -Tenant $tenantID -AppId $appID -AppSecret $appSecret


####################################################
    
    function SyncDevice {
        param
(
    $DeviceID
)
        $Resource = "deviceManagement/managedDevices('$DeviceID')/syncDevice"
        $uri = "https://graph.microsoft.com/Beta/$($resource)"
        write-verbose $uri
        Write-Verbose "Sending sync command to $DeviceID"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $null
    }
    ####################################################


    
    
#####################################################
#Sync All Devices
#####################################################

$graphApiVersion = "beta"
$Resource = "deviceManagement/managedDevices"
$uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"

$devices = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
$alldevices = @()
$alldevices += $devices.value
$policynextlink = $devices."@odata.nextlink"

while ($null -ne $policynextlink) {
$nextdevices = (Invoke-MgGraphRequest -Uri $policynextlink -Method Get -OutputType PSObject)
$policynextlink = $nextdevices."@odata.nextLink"
$alldevices += $nextdevices.value
}





foreach ($device in $alldevices) {
    SyncDevice -Deviceid $device.id
    $devicename = $device.deviceName
    write-host "Sync sent to $devicename"
}

