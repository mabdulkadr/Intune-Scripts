[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
	[Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0)][alias("DNSHostName","ComputerName","Computer")] [String[]] $Name = @("localhost"),
	[Parameter(Mandatory=$False)] [String] $OutputFile = "", 
	[Parameter(Mandatory=$False)] [String] $GroupTag = $ComputerNameTag,
	[Parameter(Mandatory=$False)] [String] $AssignedUser = "",
	[Parameter(Mandatory=$False)] [Switch] $Append = $false,
	[Parameter(Mandatory=$False)] [System.Management.Automation.PSCredential] $Credential = $null,
	[Parameter(Mandatory=$False)] [Switch] $Partner = $false,
	[Parameter(Mandatory=$False)] [Switch] $Force = $false,
	[Parameter(Mandatory=$False)] [int] $Delay = 1,
	[Parameter(Mandatory=$True, ParameterSetName = 'Online')] [Switch] $Online = $True,
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $TenantId = "c2b04da6-8487-41cc-8803-90321048a772",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AppId = "6c70c0c3-e3a6-489c-973e-51e8138540f9",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AppSecret = "Uoj8Q~1_acd.7WU4Ol3vOczrfeYQbdHR_mzhTb6n",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String[]] $AddToGroup = "",
    [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [Switch] $RemoveGroups = $false,
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AssignedComputerName = $ComputerNameTag,
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')]
    [Parameter(Mandatory=$True, ParameterSetName = 'Assign')] [Switch] $Assign = $false,
    [Parameter(Mandatory=$False,ParameterSetName = 'Online')]
    [Parameter(Mandatory=$False,ParameterSetName = 'Assign')] [string] $WaitForProfile, 
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [Switch] $Reboot = $false
)



Begin

{
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

    clear
    Write-Host ""
    Write-Host "+----------------------------------------------------------------------+"
    Write-Host "| Device Name                                                          |"
    Write-Host "+----------------------------------------------------------------------+"
    Write-Host ""
    $ComputerNameTag = Read-Host "Please enter the Computer Name (e.g., IT-HD)"
    Write-Host ""
	Write-Host "+----------------------------------------------------------------------+"


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
        Write-Host ""
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
        Write-Host ""
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


            Write-Host ""
            Write-Host "+----------------------------------------------------------------------+"
            Write-Host "| Connecting MgGraph and MSGraph                                       |"
            Write-Host "+----------------------------------------------------------------------+"
            Write-Host ""

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

		    Write-Host "successfully Connected to Graph API tenant $TenantId using app-based authentication" -ForegroundColor Green
	    }
	    else {

            Write-Host "Connecting..."
            Write-Host " 1. Connecting MgGraph module (for Graph API)"
		    $graph = Connect-MgGraph -Scopes $scopes

            Write-Host " 2. Connecting MSGraph module (for WindowsAutopilotIntune)"
            $intune = Connect-MSGraph

		    Write-Host "successfully Connected to Graph API tenant $($graph.TenantId)" -ForegroundColor Green
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
            Write-Host ""
			Write-Host "Gathered details for device with serial number: $serial" -ForegroundColor Cyan
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
        Write-Host ""
		Write-Host "$successCount devices imported successfully.  Elapsed time to complete import: $importSeconds seconds" -ForegroundColor Green
		Write-Host ""


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
        
        
    Write-Host ""
    Write-Host "+----------------------------------------------------------------------+"
    Write-Host "| Device Summary                                                       |"
    Write-Host "+----------------------------------------------------------------------+"
    Write-Host ""
    Write-Host "      Device Name              : " = $ComputerNameTag
    Write-Host "      Group Tag                : " = $ComputerNameTag
    Write-Host "      Device Serial Number     : " = $serial
    Write-Host "      Intune Sync Status       : " = "Yes"
    Write-Host "      Intune Sync Time         : " = $syncSeconds
    Write-Host ""
    Write-Host "+----------------------------------------------------------------------+"


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
