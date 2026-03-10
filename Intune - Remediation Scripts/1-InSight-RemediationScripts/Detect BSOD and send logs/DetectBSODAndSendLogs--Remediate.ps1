<#
.SYNOPSIS
    Collect BSOD diagnostics, compress them, and upload the archive.

.DESCRIPTION
    This remediation script gathers diagnostic information after a detected BSOD.

    It exports event logs, copies dump files, builds inventory reports, creates
    a ZIP archive, and then uploads that archive to SharePoint. When configured,
    it can also send a webhook notification after the upload succeeds.

.RUN AS
    System

.EXAMPLE
    .\DetectBSODAndSendLogs--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DetectBSODAndSendLogs--Remediate.ps1'
$ScriptBaseName = 'DetectBSODAndSendLogs--Remediate'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }

# Script-specific logging location.
$SolutionName = 'DetectBSODAndSendLogs'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ('{0}.txt' -f $ScriptBaseName)
$Log_File     = $LogFile

$Temp_folder = "C:\Windows\Temp"
$DMP_Logs_folder = "$Temp_folder\DMP_Logs_folder"
$DMP_Logs_folder_ZIP = "$Temp_folder\BSOD_$env:computername.zip"
$ZIP_Name = "BSOD_$env:computername.zip"

$Use_Webhook = $False # Choose if you want to publish on a Teams channel(True or False)
$Webhook = "" # Type the path of the webhook

$Tenant = ""  # tenant name
$ClientID = "" # azure app client id
$Secret = '' # azure app secret
$SharePoint_SiteID = ""  # sharepoint site id
$SharePoint_Path = ""  # sharepoint main path
$SharePoint_ExportFolder = ""  # folder where to upload file
#endregion ====================== CONFIGURATION ======================

#region ========================= HELPER FUNCTIONS =========================
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

function Start-LogRun {
    Initialize-LogFile
    if (Test-Path -LiteralPath $LogFile) {
        $existingLog = Get-Item -LiteralPath $LogFile -ErrorAction SilentlyContinue
        if ($existingLog -and $existingLog.Length -gt 0) {
            Add-Content -Path $LogFile -Value '' -Encoding UTF8
        }
    }
    Add-Content -Path $LogFile -Value ('=' * 78) -Encoding UTF8
}

Function Write_Log
	{
		param(
		$Message_Type,
		$Message
		)

		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"
		write-host "$MyDate - $Message_Type : $Message"
	}

Function Export_Event_Logs
	{
		param(
		$Log_To_Export,
		$File_Name
		)

		Write_Log -Message_Type "INFO" -Message "Collecting logs from: $Log_To_Export"
		Try
			{
				WEVTUtil export-log $Log_To_Export -ow:true /q:"*[System[TimeCreated[timediff(@SystemTime) <= 1296000000 ]]]" "$DMP_Logs_folder\$File_Name.evtx" | out-null
				Write_Log -Message_Type "SUCCESS" -Message "Event log $File_Name.evtx has been successfully exported"
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting event log $File_Name.evtx"
			}
	}

Function Get_DeviceUpTime
	{
		param(
		[Switch]$Show_Days,
		[Switch]$Show_Uptime
		)

		$Last_reboot = Get-ciminstance Win32_OperatingSystem | Select -Exp LastBootUpTime
		$Check_FastBoot = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -ea silentlycontinue).HiberbootEnabled
		If(($Check_FastBoot -eq $null) -or ($Check_FastBoot -eq 0))
			{
				$Boot_Event = Get-WinEvent -ProviderName 'Microsoft-Windows-Kernel-Boot'| where {$_.ID -eq 27 -and $_.message -like "*0x0*"}
				If($Boot_Event -ne $null)
					{
						$Last_boot = $Boot_Event[0].TimeCreated
					}
			}
		ElseIf($Check_FastBoot -eq 1)
			{
				$Boot_Event = Get-WinEvent -ProviderName 'Microsoft-Windows-Kernel-Boot'| where {$_.ID -eq 27 -and $_.message -like "*0x1*"}
				If($Boot_Event -ne $null)
					{
						$Last_boot = $Boot_Event[0].TimeCreated
					}
			}

		If($Last_boot -eq $null)
			{
				$Uptime = $Uptime = $Last_reboot
			}
		Else
			{
				If($Last_reboot -ge $Last_boot)
					{
						$Uptime = $Last_reboot
					}
				Else
					{
						$Uptime = $Last_boot
					}
			}

		If($Show_Days)
			{
				$Current_Date = get-date
				$Diff_boot_time = $Current_Date - $Uptime
				$Boot_Uptime_Days = $Diff_boot_time.Days
				$Real_Uptime = $Boot_Uptime_Days
			}
		ElseIf($Show_Uptime)
			{
				$Real_Uptime = $Uptime

			}
		ElseIf(($Show_Days -eq $False) -and ($Show_Uptime -eq $False))
			{
				$Real_Uptime = $Uptime
			}
		Return "$Real_Uptime"
	}
#endregion ====================== HELPER FUNCTIONS ======================

Start-LogRun
Write_Log -Message_Type 'INFO' -Message '=== Remediation START ==='
Write_Log -Message_Type 'INFO' -Message "Script: $ScriptName"
Write_Log -Message_Type 'INFO' -Message "Log file: $LogFile"

#region ==================== FIRST REMEDIATION BLOCK ====================
If(test-path $DMP_Logs_folder){remove-item $DMP_Logs_folder -Force -Recurse}
new-item $DMP_Logs_folder -type Directory -force | out-null
If(test-path $DMP_Logs_folder_ZIP){Remove-Item $DMP_Logs_folder_ZIP -Force}

Write_Log -Message_Type "INFO" -Message "A recent BSOD has been found"
Write_Log -Message_Type "INFO" -Message "Date: $Last_DMP"

# Copy hotfix list
$Hotfix_CSV = "$DMP_Logs_folder\Hotfix_List.csv"
$Hotfix_list = Get-wmiobject win32_quickfixengineering | Select-Object hotfixid, Description, Caption, InstalledOn  | Sort-Object InstalledOn
$Hotfix_list | export-CSV $Hotfix_CSV -delimiter ";" -notypeinformation

# Copy services list
$Services_CSV = "$DMP_Logs_folder\Services_List.csv"
$services_List = Get-wmiobject win32_service | Select-Object Name, Caption, State, Startmode
$services_List | export-CSV $Services_CSV -delimiter ";" -notypeinformation

# copy drivers list
$Drivers_CSV = "$DMP_Logs_folder\Drivers_List.csv"
$Drivers_List = gwmi Win32_PnPSignedDriver | Select-Object devicename, manufacturer, driverversion, infname, @{Label="DriverDate";Expression={$_.ConvertToDateTime($_.DriverDate).ToString("MM-dd-yyyy")}}, Description, IsSigned, ClassGuid, HardWareID, DeviceID | where-object {$_.devicename -ne $null -and $_.infname -ne $null} | sort-object devicename -Unique
$Drivers_List | export-CSV $Drivers_CSV -delimiter ";" -notypeinformation

# copy process list
$Process_CSV = "$DMP_Logs_folder\Process_List.csv"
$Process_List = gwmi win32_process | select ProcessName, caption, CommandLine, path, CreationDate, Description, ExecutablePath, Name, ProcessID, SessionID
$Process_List | export-CSV $Process_CSV -delimiter ";" -notypeinformation

# export pending updates
$Pending_Updates_CSV = "$DMP_Logs_folder\Pending_Updates.csv"
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateupdateSearcher()
$Updates = @($UpdateSearcher.Search("IsHidden=0 and IsInstalled=0 and Type='Software'").Updates)
$Pending_Updates = $Updates  | Select-Object Title, Description, LastdeploymentChangeTime, SupportUrl, Type, RebootRequired
$Pending_Updates | export-CSV $Pending_Updates_CSV -delimiter ";" -notypeinformation

# Export last reboot date
Get_DeviceUpTime | out-file "$DMP_Logs_folder\Last_reboot_date.txt"

# Export EVTX from last 15 days
Export_Event_Logs -Log_To_Export System -File_Name "System"
Export_Event_Logs -Log_To_Export Application -File_Name "Applications"
Export_Event_Logs -Log_To_Export Security -File_Name "Security"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-Power/Thermal-Operational" -File_Name "KernelPower"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-PnP/Driver Watchdog" -File_Name "KernelPnP_Watchdog"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-PnP/Configuration" -File_Name "KernelPnp_Conf"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-LiveDump/Operational" -File_Name "KernelLiveDump"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-ShimEngine/Operational" -File_Name "KernelShimEngine"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-Boot/Operational" -File_Name "KernelBoot"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-IO/Operational" -File_Name "KernelIO"

# Copy Dump files
$Minidump_Folder = "C:\Windows\Minidump"
If(test-path $Minidump_Folder){copy-item $Minidump_Folder $DMP_Logs_folder -Recurse -Force}

# $Get_BugCheck_Event = (Get-EventLog system -Source bugcheck -ea silentlycontinue)[0]
$Get_BugCheck_Event = (Get-EventLog system -Source bugcheck -ea silentlycontinue)
If($Get_BugCheck_Event -ne $null)
	{
		$Get_last_BugCheck_Event = $Get_BugCheck_Event[0]
		$Get_last_BugCheck_Event_Date = $Get_last_BugCheck_Event.TimeGenerated
		$Get_last_BugCheck_Event_MSG = $Get_last_BugCheck_Event.Message
		$Get_last_BugCheck_Event_MSG | out-file "$DMP_Logs_folder\LastEvent_Message.txt"
	}

# ZIP DMP folder
Try
	{
		Add-Type -assembly "system.io.compression.filesystem"
		[io.compression.zipfile]::CreateFromDirectory($DMP_Logs_folder, $DMP_Logs_folder_ZIP)
		Write_Log -Message_Type "SUCCESS" -Message "The ZIP file has been successfully created"
		Write_Log -Message_Type "INFO" -Message "The ZIP is located in :$Logs_Collect_Folder_ZIP"
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "An issue occured while creating the ZIP file"
		$Reported_error = $error[0].exception.message
		write-output "KO (ZIP): $Reported_error"
		Write_Log -Message_Type 'INFO' -Message '=== Remediation END (Exit 1) ==='
		EXIT 1
	}

# Authentification sur SharePoint et upload du fichier
$Body = @{
    client_id = $ClientID
    client_secret = $Secret
    scope = "https://graph.microsoft.com/.default"
    grant_type = 'client_credentials'
}

Write_Log -Message_Type "INFO" -Message "SharePoint connexion"
$Graph_Url = "https://login.microsoftonline.com/$($Tenant).onmicrosoft.com/oauth2/v2.0/token"

Try
	{
		$AuthorizationRequest = Invoke-RestMethod -Uri $Graph_Url -Method "Post" -Body $Body
		Write_Log -Message_Type "SUCCESS" -Message "Connected to SharePoint"
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "Connexion to SharePoint failed"
		Write_Log -Message_Type 'INFO' -Message '=== Remediation END ==='
		EXIT
	}

$Access_token = $AuthorizationRequest.Access_token
$Header = @{
    Authorization = $AuthorizationRequest.access_token
    "Content-Type"= "application/json"
    'Content-Range' = "bytes 0-$($fileLength-1)/$fileLength"
}

$SharePoint_Graph_URL = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives"
$BodyJSON = $Body | ConvertTo-Json -Compress

Write_Log -Message_Type "INFO" -Message "Getting SharePoint site info"

Try
	{
		$Result = Invoke-RestMethod -Uri $SharePoint_Graph_URL -Method 'GET' -Headers $Header -ContentType "application/json"
		Write_Log -Message_Type "SUCCESS" -Message "Getting SharePoint site info"
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "Getting SharePoint site info"
		Write_Log -Message_Type 'INFO' -Message '=== Remediation END ==='
		EXIT
	}

$DriveID = $Result.value| Where-Object {$_.webURL -eq $SharePoint_Path } | Select-Object id -ExpandProperty id

$FileName = $DMP_Logs_folder_ZIP.Split("\")[-1]
$createUploadSessionUri = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$SharePoint_ExportFolder/$($fileName):/createUploadSession"

Write_Log -Message_Type "INFO" -Message "File to upload: $FileName"
Write_Log -Message_Type "INFO" -Message "Preparing the file for the upload"

Try
	{
		$uploadSession = Invoke-RestMethod -Uri $createUploadSessionUri -Method 'POST' -Headers $Header -ContentType "application/json"
		Write_Log -Message_Type "SUCCESS" -Message "Preparing the file for the upload"
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "Preparing the file for the upload"
		Write_Log -Message_Type 'INFO' -Message '=== Remediation END ==='
		EXIT
	}

$fileInBytes = [System.IO.File]::ReadAllBytes($DMP_Logs_folder_ZIP)
$fileLength = $fileInBytes.Length

$headers = @{
  'Content-Range' = "bytes 0-$($fileLength-1)/$fileLength"
}

Write_Log -Message_Type "INFO" -Message "Uploading file"
Try
	{
		$response = Invoke-RestMethod -Method 'Put' -Uri $uploadSession.uploadUrl -Body $fileInBytes -Headers $headers
		Write_Log -Message_Type "SUCCESS" -Message "File has been uploaded"
		$Upload_file_status = $true
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "Failed to upload the file"
		Write_Log -Message_Type 'INFO' -Message '=== Remediation END ==='
		EXIT
	}

Remove-Item $DMP_Logs_folder -Force -Recurse
Remove-Item $DMP_Logs_folder_ZIP -Force

If($Upload_file_status -eq $True)
	{
		write-output "File uploaded"

		If($Use_Webhook -eq $True)
			{
				$Date = get-date
				$MessageText = "A new BSOD occured on device <b>$env:computername</b>.<br><br>Date: $Date<br>Logs files have been uploaded in the below ZIP file: $ZIP_Name"
				$MessageTitle = "A new BSOD ZIP has been uploaded"
				$MessageColor = "#2874A6"

				$Body = @{
				'text'= $MessageText
				'Title'= $MessageTitle
				'themeColor'= $MessageColor
				}


				$Params = @{
						 Headers = @{'Content-Type'='application/json'}
						 Body = $Body | ConvertTo-Json
						 Method = 'Post'
						 URI = $Webhook
				}
				Invoke-RestMethod @Params
			}
		Write_Log -Message_Type 'INFO' -Message '=== Remediation END (Exit 0) ==='
		EXIT 0
	}
Else
	{
		$Reported_error = $error[0].exception.message
		write-output "KO (Add file): $Reported_error"
		Write_Log -Message_Type 'INFO' -Message '=== Remediation END (Exit 1) ==='
		EXIT 1
	}
#endregion ================= FIRST REMEDIATION BLOCK =================
