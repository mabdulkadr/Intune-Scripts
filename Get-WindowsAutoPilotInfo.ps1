<#PSScriptInfo

.VERSION 3.7

.GUID ebf446a3-3362-4774-83c0-b7299410b63f

.AUTHOR Michael Niehaus

.COMPANYNAME Microsoft

.COPYRIGHT 

.TAGS Windows AutoPilot

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0:  Original published version.
Version 1.1:  Added -Append switch.
Version 1.2:  Added -Credential switch.
Version 1.3:  Added -Partner switch.
Version 1.4:  Switched from Get-WMIObject to Get-CimInstance.
Version 1.5:  Added -GroupTag parameter.
Version 1.6:  Bumped version number (no other change).
Version 2.0:  Added -Online parameter.
Version 2.1:  Bug fix.
Version 2.3:  Updated comments.
Version 2.4:  Updated "online" import logic to wait for the device to sync, added new parameter.
Version 2.5:  Added AssignedUser for Intune importing, and AssignedComputerName for online Intune importing.
Version 2.6:  Added support for app-based authentication via Connect-MSGraphApp.
Version 2.7:  Added new Reboot option for use with -Online -Assign.
Version 2.8:  Fixed up parameter sets.
Version 2.9:  Fixed typo installing AzureAD module.
Version 3.0:  Fixed typo for app-based auth, added logic to explicitly install NuGet (silently).
Version 3.2:  Fixed logic to explicitly install NuGet (silently).
Version 3.3:  Added more logging and error handling for group membership.
Version 3.4:  Added logic to verify that devices were added successfully.  Fixed a bug that could cause all Autopilot devices to be added to the specified AAD group.
Version 3.5:  Added logic to display the serial number of the gathered device.
Version 3.6:  Added ability to use AddToGroup with AppID & AppSecret and migration some functions to Graph Powershell v1.0
Version 3.7:  Changed AddToGroup to accept a list of group names. Added module version checks
Version 3.8:  Fixed bugs caused by changes to the dependent modules
#>

<#
.SYNOPSIS
Retrieves the Windows AutoPilot deployment details from one or more computers

MIT LICENSE

Copyright (c) 2020 Microsoft

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.DESCRIPTION
This script uses WMI to retrieve properties needed for a customer to register a device with Windows Autopilot.  Note that it is normal for the resulting CSV file to not collect a Windows Product ID (PKID) value since this is not required to register a device.  Only the serial number and hardware hash will be populated.
.PARAMETER Name
The names of the computers.  These can be provided via the pipeline (property name Name or one of the available aliases, DNSHostName, ComputerName, and Computer).
.PARAMETER OutputFile
The name of the CSV file to be created with the details for the computers.  If not specified, the details will be returned to the PowerShell
pipeline.
.PARAMETER Append
Switch to specify that new computer details should be appended to the specified output file, instead of overwriting the existing file.
.PARAMETER Credential
Credentials that should be used when connecting to a remote computer (not supported when gathering details from the local computer).
.PARAMETER Partner
Switch to specify that the created CSV file should use the schema for Partner Center (using serial number, make, and model).
.PARAMETER GroupTag
An optional tag value that should be included in a CSV file that is intended to be uploaded via Intune (not supported by Partner Center or Microsoft Store for Business).
.PARAMETER AssignedUser
An optional value specifying the UPN of the user to be assigned to the device.  This can only be specified for Intune (not supported by Partner Center or Microsoft Store for Business).
.PARAMETER Online
Add computers to Windows Autopilot via the Intune Graph API
.PARAMETER AssignedComputerName
An optional value specifying the computer name to be assigned to the device.  This can only be specified with the -Online switch and only works with AAD join scenarios.
.PARAMETER AddToGroup
Specifies a list of names of Azure AD groups that the new device should be added to.
.PARAMETER RemoveGroups
Removes membership for any Azure AD groups where the device is an assigned member (runs before AddToGroup)
.PARAMETER Assign
Wait for the Autopilot profile assignment.  (This can take a while for dynamic groups.)
.PARAMETER WaitForProfile
Wait for the correct Autopilot profile to be assigned. Requires -Assign (This can take a while for dynamic groups.)
.PARAMETER Reboot
Reboot the device after the Autopilot profile has been assigned (necessary to download the profile and apply the computer name, if specified).
.PARAMETER Delay
Set a delay in seconds at the end of the script for the user to read the output
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER -OutputFile .\MyComputer.csv
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER -OutputFile .\MyComputer.csv -GroupTag Kiosk
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER -OutputFile .\MyComputer.csv -GroupTag Kiosk -AssignedUser JohnDoe@contoso.com
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER -OutputFile .\MyComputer.csv -Append
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER1,MYCOMPUTER2 -OutputFile .\MyComputers.csv
.EXAMPLE
Get-ADComputer -Filter * | .\GetWindowsAutoPilotInfo.ps1 -OutputFile .\MyComputers.csv
.EXAMPLE
Get-CMCollectionMember -CollectionName "All Systems" | .\GetWindowsAutoPilotInfo.ps1 -OutputFile .\MyComputers.csv
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER1,MYCOMPUTER2 -OutputFile .\MyComputers.csv -Partner
.EXAMPLE
.\GetWindowsAutoPilotInfo.ps1 -Online

#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
	[Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0)][alias("DNSHostName","ComputerName","Computer")] [String[]] $Name = @("localhost"),
	[Parameter(Mandatory=$False)] [String] $OutputFile = "", 
	[Parameter(Mandatory=$False)] [String] $GroupTag = "",
	[Parameter(Mandatory=$False)] [String] $AssignedUser = "",
	[Parameter(Mandatory=$False)] [Switch] $Append = $false,
	[Parameter(Mandatory=$False)] [System.Management.Automation.PSCredential] $Credential = $null,
	[Parameter(Mandatory=$False)] [Switch] $Partner = $false,
	[Parameter(Mandatory=$False)] [Switch] $Force = $false,
	[Parameter(Mandatory=$False)] [int] $Delay = 1,
	[Parameter(Mandatory=$True,ParameterSetName = 'Online')] [Switch] $Online = $true,
[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $TenantId = "c2b04da6-8487-41cc-8803-90321048a772",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AppId = "6c70c0c3-e3a6-489c-973e-51e8138540f9",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AppSecret = "Uoj8Q~1_acd.7WU4Ol3vOczrfeYQbdHR_mzhTb6n",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String[]] $AddToGroup = "",
    [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [Switch] $RemoveGroups = $false,
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AssignedComputerName = "it-op-test2",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')]
    [Parameter(Mandatory=$True,ParameterSetName = 'Assign')]
        [Switch] $Assign = $false,
    [Parameter(Mandatory=$False,ParameterSetName = 'Online')]
    [Parameter(Mandatory=$False,ParameterSetName = 'Assign')]
        [string] $WaitForProfile, 
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [Switch] $Reboot = $false
)

Begin
{
	# Initialize empty list
	$computers = @()

	# If online, make sure we are able to authenticate
	if ($Online) {
        # Check Env variables because they might not be set e.g. during a task sequence
        if ($null -eq $env:APPDATA) { $env:APPDATA = "$($env:UserProfile)\AppData\Roaming" }
        if ($null -eq $env:LOCALAPPDATA) { $env:LOCALAPPDATA = "$($env:UserProfile)\AppData\Local" }

        #Set TLS 1.2
        #https://docs.microsoft.com/en-us/powershell/scripting/gallery/installing-psget?view=powershell-7.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

		# Check PSGallery
        Write-Host "Checking PSGallery"
        $gallery = Get-PSRepository -Name 'PSGallery' -ErrorAction Ignore
        if (-not $gallery) {
            Register-PSRepository -Default -Verbose
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        }

        # Get NuGet
        Write-Host "Checking NuGet"
		Find-PackageProvider -Name 'NuGet' -ForceBootstrap -IncludeDependencies -MinimumVersion 2.8.5.208 -ErrorAction SilentlyContinue
		
		# Install and connect to Graph
        # Define modules and minimum versions
        $modules = @{
            'Microsoft.Graph.Authentication'='2.8.0'
            'Microsoft.Graph.DeviceManagement'='2.8.0'
            'WindowsAutopilotIntune'='5.0'
            'Microsoft.Graph.Intune'='6.1907.1.0'
            }
        $scopes = 'DeviceManagementServiceConfig.ReadWrite.All','DeviceManagementManagedDevices.ReadWrite.All','Device.Read.All'

        # If using AddToGroup, we need extra modules and scopes
		if ($AddToGroup -or $RemoveGroups)
		{
            $modules.Add('Microsoft.Graph.Groups','2.8.0')
            $modules.Add('Microsoft.Graph.Identity.DirectoryManagement','2.8.0')
            $scopes += 'GroupMember.ReadWrite.All','Group.Read.All'
        }

        #Install any missing modules
        Write-Host "Checking Modules"
        $modules.Keys | ForEach-Object {
            Write-Host "  $($_)" -NoNewline
            $module = Get-InstalledModule -Name $_ -MinimumVersion $modules[$_] -ErrorAction Ignore
            if (-not $module) { 
                Write-Host "...installing" -NoNewline
                Install-Module $_ -Force -MinimumVersion $modules[$_] -AllowClobber
            }
            Write-Host ""
        }

        #Load the modules        
        Write-Host "Importing Modules"
        $modules.Keys | ForEach-Object {
            Import-Module $_ -MinimumVersion $modules[$_]
        }

		# Connect
	    if ($AppId -ne "")
	    {
            #Get an access token for the connection
            #https://blogs.aaddevsup.xyz/2022/06/microsoft-graph-powershell-sdk-use-client-secret-instead-of-certificate-for-service-principal-login/
            $body = @{
                grant_type="client_credentials";
                client_id=$AppId;
                client_secret=$AppSecret;
                scope="https://graph.microsoft.com/.default";
            }
 
            $response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token -Body $body
            $accessToken = $response.access_token

            Write-Host "Connecting..."
            Write-Host " 1. Connecting MgGraph module (for Graph API)"
			$targetParameter = (Get-Command Connect-MgGraph).Parameters['AccessToken']
			if ($targetParameter.ParameterType -eq [securestring]){
				$graph = Connect-MgGraph -AccessToken ($accessToken |ConvertTo-SecureString -AsPlainText -Force)
			}
			else {
				$graph = Connect-MgGraph -AccessToken $accessToken
			}

            Write-Host " 2. Connecting MSGraph module (for WindowsAutopilotIntune)"
            $intune = Connect-MSGraphApp -Tenant $TenantId -AppId $AppId -AppSecret $AppSecret

		    Write-Host "Connected to Graph API tenant $TenantId using app-based authentication"
	    }
	    else {
            Write-Host "Connecting..."
            Write-Host " 1. Connecting MgGraph module (for Graph API)"
		    $graph = Connect-MgGraph -Scopes $scopes

            Write-Host " 2. Connecting MSGraph module (for WindowsAutopilotIntune)"
            $intune = Connect-MSGraph

		    Write-Host "Connected to Graph API tenant $($graph.TenantId)"
	    }

        #check scopes
        $scopesOK = $true
        $currentScopes = Get-MgContext | Select -ExpandProperty Scopes
        $scopes | % {
            if (-not ($_ -in $currentScopes)) {
                Write-Warning "Scope not configured for session: $_"
                $scopesOK = $false
            }
        }

        if (-not $scopesOK) {
            Throw "Missing scope, script cannot run successfully"
        }

		# Force the output to a file
		if ($OutputFile -eq "")
		{
			$OutputFile = "$($env:TEMP)\autopilot.csv"
		} 
	}
}

Process
{
	foreach ($comp in $Name)
	{
		$bad = $false

		# Get a CIM session
		if ($comp -eq "localhost") {
			$session = New-CimSession
		}
		else
		{
			$session = New-CimSession -ComputerName $comp -Credential $Credential
		}

		# Get the common properties.
		Write-Verbose "Checking $comp"
		$serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber

		# Get the hash (if available)
		$devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
		if ($devDetail -and (-not $Force))
		{
			$hash = $devDetail.DeviceHardwareData
		}
		else
		{
			$bad = $true
			$hash = ""
		}

		# If the hash isn't available, get the make and model
		if ($bad -or $Force)
		{
			$cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
			$make = $cs.Manufacturer.Trim()
			$model = $cs.Model.Trim()
			if ($Partner)
			{
				$bad = $false
			}
		}
		else
		{
			$make = ""
			$model = ""
		}

		# Getting the PKID is generally problematic for anyone other than OEMs, so let's skip it here
		$product = ""

		# Depending on the format requested, create the necessary object
		if ($Partner)
		{
			# Create a pipeline object
			$c = New-Object psobject -Property @{
				"Device Serial Number" = $serial
				"Windows Product ID" = $product
				"Hardware Hash" = $hash
				"Manufacturer name" = $make
				"Device model" = $model
			}
			# From spec:
			#	"Manufacturer Name" = $make
			#	"Device Name" = $model

		}
		else
		{
			# Create a pipeline object
			$c = New-Object psobject -Property @{
				"Device Serial Number" = $serial
				"Windows Product ID" = $product
				"Hardware Hash" = $hash
			}
			
			if ($GroupTag -ne "")
			{
				Add-Member -InputObject $c -NotePropertyName "Group Tag" -NotePropertyValue $GroupTag
			}
			if ($AssignedUser -ne "")
			{
				Add-Member -InputObject $c -NotePropertyName "Assigned User" -NotePropertyValue $AssignedUser
			}
		}

		# Write the object to the pipeline or array
		if ($bad)
		{
			# Report an error when the hash isn't available
			Write-Error -Message "Unable to retrieve device hardware data (hash) from computer $comp" -Category DeviceError
		}
		elseif ($OutputFile -eq "")
		{
			$c
		}
		else
		{
			$computers += $c
			Write-Host "Gathered details for device with serial number: $serial"
		}

		Remove-CimSession $session
	}
}

End
{
	if ($OutputFile -ne "")
	{
		if ($Append)
		{
			if (Test-Path $OutputFile)
			{
				$computers += Import-CSV -Path $OutputFile
			}
		}
		if ($Partner)
		{
			$computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash", "Manufacturer name", "Device model" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
		}
		elseif ($AssignedUser -ne "")
		{
			$computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag", "Assigned User" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
		}
		elseif ($GroupTag -ne "")
		{
			$computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
		}
		else
		{
			$computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
		}
	}
	if ($Online)
	{
		# Add the devices
		$importStart = Get-Date
		$imported = @()
		$computers | % {
			$imported += Add-AutopilotImportedDevice -serialNumber $_.'Device Serial Number' -hardwareIdentifier $_.'Hardware Hash' -groupTag $_.'Group Tag' -assignedUser $_.'Assigned User'
		}

		# Wait until the devices have been imported
		$processingCount = 999999
        $activity =  "Waiting for devices to be imported" 
        $progress = 0

		while ($processingCount -gt 0)
		{
			$apImportedDevices = @()
			$processingCount = 0
			$imported | % {
				$device = Get-AutopilotImportedDevice -id $_.id
				if ($device.state.deviceImportStatus -eq "unknown") {
					$processingCount = $processingCount + 1
				}
				$apImportedDevices += $device
			}
            
            $progress = $progress+1
			Write-Progress -Activity $activity -CurrentOperation "Processing $processingCount of $($imported.count)" -PercentComplete $progress
			if ($processingCount -gt 0){
				Start-Sleep 30
			}
		}
        Write-Progress -Activity $activity -Completed
		
		
        $importDuration = (Get-Date) - $importStart
		$importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
		$successCount = 0
		$apImportedDevices | % {
			Write-Host "$($device.serialNumber): $($device.state.deviceImportStatus) $($device.state.deviceErrorCode) $($device.state.deviceErrorName)"
			if ($device.state.deviceImportStatus -eq "complete") {
				$successCount = $successCount + 1
			}
		}
		Write-Host "$successCount devices imported successfully.  Elapsed time to complete import: $importSeconds seconds"
		
		# Wait until the devices can be found in Intune (should sync automatically)
		$syncStart = Get-Date
		$processingCount = 999999
		$activity =  "Waiting for devices to be synced" 
		$progress = 0

		while ($processingCount -gt 0)
		{
			$autopilotDevices = @()
			$processingCount = 0
			$apImportedDevices | % {
                if ($_.state.deviceRegistrationId) {
                    $device = Get-AutopilotDevice -id $_.state.deviceRegistrationId
                    if ($_.state.deviceImportStatus -eq "complete") {
					    if (-not $device) {
						    $processingCount = $processingCount + 1
					    }
                    } 
                }
                #If the device hasn't returned the deviceRegistrationId it might have errored 
                #because it already exists. Find it by the serial instead
                elseif ($_.state.deviceErrorName -eq 'ZtdDeviceAlreadyAssigned') {
                    $device = Get-AutopilotDevice -serial "$($_.serialNumber)"
                }

                if ($device) {
                    $autopilotDevices += $device
                }		
			}

            $progress = $progress+1
			Write-Progress -Activity $activity -CurrentOperation "Processing $processingCount of $($current.Length)" -PercentComplete $progress
			
			if ($processingCount -gt 0){
				Start-Sleep 30
			}
		}
        Write-Progress -Activity $activity -Completed
		$syncDuration = (Get-Date) - $syncStart
		$syncSeconds = [Math]::Ceiling($syncDuration.TotalSeconds)
		Write-Host "All devices synced.  Elapsed time to complete sync: $syncSeconds seconds"
        
		# Run group management tasks
		if ($AddToGroup -or $RemoveGroups)
		{
            Write-Host "Runnging group management tasks"
            #Get the groups listed in AddToGroup and add to a list for later use
            if ($AddToGroup) {   
                $AddingGroups = @()
                $AddToGroup | ForEach-Object {
                    $groupname = $_
			        $aadGroup = Get-MgGroup -Filter "DisplayName eq '$groupname'" -ErrorAction Ignore
                    if ($aadGroup) {
                        Write-Host "Devices will be added to group: '$groupname' ($($aadGroup.Id))"
                        $AddingGroups += $aadGroup
                    }
                    else {
				        Write-Error "Unable to find group $groupname"
			        }
                }
            }

                        		
            $groupList = @{}
            $autopilotDevices | % {
                $apDevice = $_
                $aadDevice = Get-MgDevice -Filter "DeviceId eq '$($apDevice.azureActiveDirectoryDeviceId)'"
                if ($aadDevice) {
                    Write-Verbose " Device ID: $($aadDevice.Id)"

                    #Run group cleanup
                    if ($RemoveGroups) {
                        $groupIds = Get-MgDeviceMemberOf -DeviceId $aadDevice.Id 
				        $groupIds | ForEach-Object {
                            $group = $groupList[$_.Id]
                            if (-not $group) {
                                $group = Get-MgGroup -GroupId $_.Id
                                $groupList.Add($_.Id, $group)
                            }

                            if ($group) {
                                if ($group.GroupTypes -notcontains 'DynamicMembership') {
                                    Write-Host " Removing group membership for device $($apDevice.serialNumber): '$($group.DisplayName)'" -ForegroundColor Yellow
					                Remove-MgGroupMemberByRef -GroupId $_.Id -DirectoryObjectId $aadDevice.Id
                                }
                            }
                            else {
                                Write-Error "Problem getting group: $($_.Id)"
                            }
				        }
                    }

                    #Add to device to the specified groups
                    if ($AddingGroups)
			        {
                        $AddingGroups | ForEach-Object {
						    Write-Host " Adding device $($apDevice.serialNumber) to group '$($_.Id)'" -ForegroundColor Blue
                            New-MgGroupMember -GroupId $_.Id -DirectoryObjectId $aadDevice.Id
                        }
			        }
                }
				else {
					Write-Error "Unable to find Azure AD device with ID $($_.azureActiveDirectoryDeviceId)"
				}
            }
		}

		# Assign the computer name 
		if ($AssignedComputerName -ne "")
		{
			$autopilotDevices | % {
				Set-AutopilotDevice -Id $_.Id -displayName $AssignedComputerName
			}
		}

		# Wait for assignment (if specified)
		if ($Assign)
		{
			$assignStart = Get-Date
			$processingCount = 999999
            $progress = 0

            if ($WaitForProfile) {
                Write-Host "Checking for AutoPilot profile $WaitForProfile"
                $apProfile = Get-AutopilotProfile | Where-Object { $_.displayName -eq $WaitForProfile }
                $activity = "Waiting for devices to be assigned to '$WaitForProfile'"
            }
            else {
                $activity = "Waiting for devices to be assigned"
            }

            while ($processingCount -gt 0)
			{
                $processingCount = 0
                if ($WaitForProfile) {
                    #Get a list of device ids assigned to the AutoPilot profile to compare against
                    $profileDeviceIds = Get-AutopilotProfileAssignedDevice -id $apProfile.id | ForEach-Object {
						Write-Output $_.id
					} 
                }

                $autopilotDevices | % {
					$device = Get-AutopilotDevice -id $_.id -Expand
                    Write-Verbose "Checking device: $($_.id)"

                    #Check if device is in the right profile
                    if ($profileDeviceIds -and $device.id -notin $profileDeviceIds) {
                        Write-Verbose "DeviceID $($_.id) not assigned to profile '$WaitForProfile'"
                        $processingCount = $processingCount + 1
                    }
                    #Check if profile status is assigned
                    elseif ((-not ($device.deploymentProfileAssignmentStatus.StartsWith("assigned")))) {
                        Write-Verbose "DeviceID $($_.id) not assigned"
						$processingCount = $processingCount + 1
					}
                    
                    else {
                        Write-Verbose "DeviceID $($_.id) found assigned to profile $WaitForProfile"
                    }
				}

                $progress = $progress+1
				Write-Progress -Activity $activity -CurrentOperation "Processing $processingCount of $($imported.count)" -PercentComplete $progress
				
				if ($processingCount -gt 0){
					Start-Sleep 30
				}	
			}
			Write-Progress -Activity $activity -Completed

			$assignDuration = (Get-Date) - $assignStart
			$assignSeconds = [Math]::Ceiling($assignDuration.TotalSeconds)
			Write-Host "Profiles assigned to all devices.  Elapsed time to complete assignment: $assignSeconds seconds"	

            for ($i = 1 ; $i -le $Delay ; $i++) {
                Write-Progress -Activity "Finished" -PercentComplete (($i / $Delay) * 100) -Status "Closing in $($Delay - $i) seconds"
                Start-Sleep -Seconds 1
            }

			if ($Reboot)
			{
				Restart-Computer -Force
			}
		}
	}
}