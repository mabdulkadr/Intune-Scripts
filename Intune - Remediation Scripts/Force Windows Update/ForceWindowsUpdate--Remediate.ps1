<#
.SYNOPSIS
    Scan, download, and install pending Windows software updates using the native WUA COM API.

.DESCRIPTION
    This script uses the built-in Windows Update Agent COM interfaces instead of
    PSWindowsUpdate. It searches for applicable software updates that are not installed,
    downloads them, installs them, and reports whether a reboot is required.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ---------- Configuration ----------

$ScriptName     = 'ForceWindowsUpdate-Native--Remediate.ps1'
$ScriptBaseName = 'ForceWindowsUpdate-Native--Remediate'
$SolutionName   = 'Force Windows Update'

$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}

$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

# Search only for software updates that are not installed and not hidden
$SearchCriteria = "IsInstalled=0 and Type='Software' and IsHidden=0"

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$TimeStamp] [$Level] $Message"

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

function Test-IsAdministrator {
    try {
        $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
        return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Test-PendingReboot {
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        return $true
    }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        return $true
    }

    try {
        $SessionManager = Get-ItemProperty `
            -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
            -Name 'PendingFileRenameOperations' `
            -ErrorAction SilentlyContinue

        if ($SessionManager -and $null -ne $SessionManager.PendingFileRenameOperations) {
            return $true
        }
    }
    catch {}

    return $false
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Search criteria: $SearchCriteria"
Write-Log -Message "Log file: $LogFile"

try {
    if (-not (Test-IsAdministrator)) {
        Write-Log -Message 'Administrative privileges are required.' -Level 'ERROR'
        exit 1
    }

    # Create WUA session and searcher
    $UpdateSession = New-Object -ComObject 'Microsoft.Update.Session'
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

    Write-Log -Message 'Searching for applicable updates...'
    $SearchResult = $UpdateSearcher.Search($SearchCriteria)

    if (-not $SearchResult -or $SearchResult.Updates.Count -eq 0) {
        Write-Log -Message 'No applicable updates were found.' -Level 'SUCCESS'
        exit 0
    }

    Write-Log -Message "Applicable updates found: $($SearchResult.Updates.Count)"

    # Build collections for download/install
    $UpdatesToProcess = New-Object -ComObject 'Microsoft.Update.UpdateColl'

    for ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
        $Update = $SearchResult.Updates.Item($i)

        if (-not $Update.EulaAccepted) {
            $Update.AcceptEula()
        }

        [void]$UpdatesToProcess.Add($Update)

        $KbText = 'No KB'
        if ($Update.KBArticleIDs -and $Update.KBArticleIDs.Count -gt 0) {
            $KbText = 'KB' + ($Update.KBArticleIDs -join ',KB')
        }

        Write-Log -Message "Queued update: $KbText | $($Update.Title)"
    }

    # Download updates
    $Downloader = $UpdateSession.CreateUpdateDownloader()
    $Downloader.Updates = $UpdatesToProcess

    Write-Log -Message 'Downloading updates...'
    $DownloadResult = $Downloader.Download()
    Write-Log -Message "Download result code: $($DownloadResult.ResultCode)"

    # Prepare only downloaded updates for installation
    $UpdatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

    for ($i = 0; $i -lt $UpdatesToProcess.Count; $i++) {
        $Update = $UpdatesToProcess.Item($i)
        if ($Update.IsDownloaded) {
            [void]$UpdatesToInstall.Add($Update)
        }
    }

    if ($UpdatesToInstall.Count -eq 0) {
        Write-Log -Message 'No updates were downloaded successfully.' -Level 'WARNING'
        exit 1
    }

    # Install updates
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall

    Write-Log -Message "Installing downloaded updates: $($UpdatesToInstall.Count)"
    $InstallResult = $Installer.Install()

    Write-Log -Message "Installation result code: $($InstallResult.ResultCode)"
    Write-Log -Message "Reboot required by installer: $($InstallResult.RebootRequired)"

    if ($InstallResult.RebootRequired -or (Test-PendingReboot)) {
        Write-Log -Message 'A reboot is required to complete update installation.' -Level 'WARNING'
    }
    else {
        Write-Log -Message 'Updates installed without pending reboot.' -Level 'SUCCESS'
    }

    if ($InstallResult.ResultCode -in 2,3) {
        Write-Log -Message 'Windows updates processed successfully.' -Level 'SUCCESS'
        exit 0
    }
    else {
        Write-Log -Message "Windows update installation returned non-success result code: $($InstallResult.ResultCode)" -Level 'WARNING'
        exit 1
    }
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------