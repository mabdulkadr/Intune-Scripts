<#
.SYNOPSIS
    Detect whether a recent BSOD dump exists and should trigger log collection.

.DESCRIPTION
    This detection script checks the Windows Minidump folder for recent `.dmp`
    files and compares the latest dump to BugCheck entries in the System event log.

    It returns a non-compliant result when a recent BSOD is found so the paired
    remediation script can collect and upload the related diagnostic logs.

.RUN AS
    System

.EXAMPLE
    .\DetectBSODAndSendLogs--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Number of days after a crash during which remediation should still run.
$Delay_alert = 30

# Minidump folder used to detect recent BSOD dump files.
$Minidump_Folder = 'C:\Windows\Minidump'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DetectBSODAndSendLogs--Detect.ps1'
$ScriptBaseName = 'DetectBSODAndSendLogs--Detect'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }

# Script-specific logging location.
$SolutionName = 'DetectBSODAndSendLogs'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ('{0}.txt' -f $ScriptBaseName)
$Log_File     = $LogFile
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

function Write_Log {
	param(
	$Message_Type,
	$Message
	)

	$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
	Add-Content $Log_File  "$MyDate - $Message_Type : $Message"
	Write-Host "$MyDate - $Message_Type : $Message"
}
#endregion ====================== HELPER FUNCTIONS ======================

Start-LogRun
Write_Log -Message_Type 'INFO' -Message '=== Detection START ==='
Write_Log -Message_Type 'INFO' -Message "Script: $ScriptName"
Write_Log -Message_Type 'INFO' -Message "Log file: $LogFile"

#region ===================== FIRST DETECTION BLOCK =====================
If (Test-Path $Minidump_Folder)
	{
		$Last_DMP = Get-Childitem $Minidump_Folder | where {$_.Extension -eq ".dmp"} | Sort-Object -Descending -Property LastWriteTime | Select -First 1
		If($Last_DMP -ne $null)
			{
				$Last_DMP_Date = $Last_DMP.LastWriteTime
				$Current_date = Get-Date
				$Last_DMP_delay = ($Current_date - $Last_DMP_Date).Days
				If($Last_DMP_delay -le $Delay_alert)
					{
						Write_Log -Message_Type "INFO" -Message "A recent BSOD has been found"
						Write_Log -Message_Type "INFO" -Message "Date: $Last_DMP"

						$Get_BugCheck_Events = (Get-EventLog system -Source bugcheck)
						$Get_last_BugCheck_Event = $Get_BugCheck_Events[0]
						$Get_last_BugCheck_Event_Date = $Get_last_BugCheck_Event.TimeGenerated
						$Get_last_BugCheck_Event_MSG = $Get_last_BugCheck_Event.Message
						If($Get_last_BugCheck_Event_Date -match $Last_DMP_Date)
							{
								Write_Log -Message_Type "INFO" -Message "A corresponding entry has been found in the event log"
								Write_Log -Message_Type "INFO" -Message "Event log time: $Get_last_BugCheck_Event_Date"
								Write_Log -Message_Type "INFO" -Message "Event log message: $Get_last_BugCheck_Event_MSG"

								Write_Log -Message_Type "INFO" -Message "$Get_Code"
								Write-Output "$Get_Code"
								Write_Log -Message_Type 'INFO' -Message '=== Detection END (Exit 1) ==='
								EXIT 1
							}
						Else
							{
								Write-Output "Last BSOD: $Get_last_BugCheck_Event_Date"
								Write_Log -Message_Type 'INFO' -Message '=== Detection END (Exit 1) ==='
								EXIT 1
							}
					}
			}
		Else
			{
				Write-Output "No recent BSOD found"
				Write_Log -Message_Type "INFO" -Message "No recent BSOD found"
				Write_Log -Message_Type 'INFO' -Message '=== Detection END (Exit 0) ==='
				EXIT 0
			}
	}
Else
	{
		Write_Log -Message_Type "INFO" -Message "No DMP files found"
		Write-Output "No DMP files found"
		Write_Log -Message_Type 'INFO' -Message '=== Detection END (Exit 0) ==='
		EXIT 0
	}
#endregion ================== FIRST DETECTION BLOCK ==================
