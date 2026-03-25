<#
.SYNOPSIS
    Remediate matching Windows updates by installing them.

.DESCRIPTION
    This remediation script ensures the `PSWindowsUpdate` module is available,
    checks for matching Windows updates, installs them, and reports whether a
    reboot is required afterward.

    You can optionally target specific update types, categories, severities,
    or KB article IDs from the configuration block.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\Invoke-WindowsUpdateScan--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName = 'Invoke-WindowsUpdateScan--Remediate.ps1'
$SolutionName = 'Invoke-WindowsUpdateScan'
$ScriptMode = 'Remediation'

$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

$ModuleName = 'PSWindowsUpdate'
$UpdateSource = 'MicrosoftUpdate'

$AvailableUpdateTypes = @(
    'Driver',
    'Software'
)

$AvailableUpdateCategories = @(
    'Critical Updates',
    'Security Updates',
    'Definition Updates',
    'Drivers',
    'Feature Packs',
    'Update Rollups',
    'Updates',
    'Upgrades',
    'Microsoft Defender Antivirus'
)

$AvailableUpdateSeverities = @(
    'Critical',
    'Important',
    'Moderate',
    'Low'
)

# Leave arrays empty to target all available updates.
$SelectedUpdateTypes      = @()
$SelectedUpdateCategories = @()
$SelectedUpdateSeverities = @()
$IncludeKBArticleIDs      = @()
$ExcludeKBArticleIDs      = @()

$AutoRebootAfterInstall = $false

$PendingRebootKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
)

$LogRoot    = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile    = Join-Path $LogRoot 'Invoke-WindowsUpdateScan--Remediate.txt'
$BannerLine = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

function Initialize-Log {
    try {
        if (-not (Test-Path -Path $LogRoot)) {
            New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

function Write-Banner {
    $title = "{0} | {1}" -f $SolutionName, $ScriptMode
    $lines = @('', $BannerLine, $title, $BannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        }
        else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
        }
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
    }
}

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO',

        [string]$OutputMessage
    )

    Write-Log -Message $Message -Level $Level

    if ($OutputMessage) {
        Write-Output $OutputMessage
    }

    exit $ExitCode
}

function Ensure-Module {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Log -Level 'WARNING' -Message ("Module '{0}' was not found. Installing it now." -f $Name)
        Install-Module -Name $Name -Force -AllowClobber -ErrorAction Stop
        Write-Log -Level 'SUCCESS' -Message ("Module '{0}' installed successfully." -f $Name)
    }
    else {
        Write-Log -Level 'SUCCESS' -Message ("Module '{0}' is already installed." -f $Name)
    }
}

function Test-UpdateConfiguration {
    $validSources = @('MicrosoftUpdate', 'WindowsUpdate')
    if ($UpdateSource -notin $validSources) {
        throw ("Invalid UpdateSource '{0}'. Valid values: {1}" -f $UpdateSource, ($validSources -join ', '))
    }

    $invalidTypes = @($SelectedUpdateTypes | Where-Object { $_ -notin $AvailableUpdateTypes })
    if ($invalidTypes.Count -gt 0) {
        throw ("Invalid UpdateType value(s): {0}. Valid values: {1}" -f ($invalidTypes -join ', '), ($AvailableUpdateTypes -join ', '))
    }

    $customCategories = @($SelectedUpdateCategories | Where-Object { $_ -notin $AvailableUpdateCategories })
    if ($customCategories.Count -gt 0) {
        Write-Log -Level 'WARNING' -Message ("Custom category value(s) detected: {0}" -f ($customCategories -join ', '))
    }

    $customSeverities = @($SelectedUpdateSeverities | Where-Object { $_ -notin $AvailableUpdateSeverities })
    if ($customSeverities.Count -gt 0) {
        Write-Log -Level 'WARNING' -Message ("Custom severity value(s) detected: {0}" -f ($customSeverities -join ', '))
    }
}

function Get-UpdateQueryParameters {
    $parameters = @{
        AcceptAll    = $true
        IgnoreReboot = $true
        ErrorAction  = 'Stop'
    }

    if ($UpdateSource -eq 'MicrosoftUpdate') {
        $parameters.MicrosoftUpdate = $true
    }
    else {
        $parameters.WindowsUpdate = $true
    }

    if ($SelectedUpdateTypes.Count -gt 0) { $parameters.UpdateType = $SelectedUpdateTypes }
    if ($SelectedUpdateCategories.Count -gt 0) { $parameters.Category = $SelectedUpdateCategories }
    if ($SelectedUpdateSeverities.Count -gt 0) { $parameters.Severity = $SelectedUpdateSeverities }
    if ($IncludeKBArticleIDs.Count -gt 0) { $parameters.KBArticleID = $IncludeKBArticleIDs }
    if ($ExcludeKBArticleIDs.Count -gt 0) { $parameters.NotKBArticleID = $ExcludeKBArticleIDs }

    return $parameters
}

function Get-InstallParameters {
    $parameters = @{
        AcceptAll   = $true
        ErrorAction = 'Stop'
    }

    if ($AutoRebootAfterInstall) {
        $parameters.AutoReboot = $true
    }
    else {
        $parameters.IgnoreReboot = $true
    }

    if ($UpdateSource -eq 'MicrosoftUpdate') {
        $parameters.MicrosoftUpdate = $true
    }
    else {
        $parameters.WindowsUpdate = $true
    }

    if ($SelectedUpdateTypes.Count -gt 0) { $parameters.UpdateType = $SelectedUpdateTypes }
    if ($SelectedUpdateCategories.Count -gt 0) { $parameters.Category = $SelectedUpdateCategories }
    if ($SelectedUpdateSeverities.Count -gt 0) { $parameters.Severity = $SelectedUpdateSeverities }
    if ($IncludeKBArticleIDs.Count -gt 0) { $parameters.KBArticleID = $IncludeKBArticleIDs }
    if ($ExcludeKBArticleIDs.Count -gt 0) { $parameters.NotKBArticleID = $ExcludeKBArticleIDs }

    return $parameters
}

function Test-PendingReboot {
    foreach ($registryKey in $PendingRebootKeys) {
        if (Test-Path -Path $registryKey) {
            return $true
        }
    }

    return $false
}

function Get-SelectionText {
    param([array]$Items, [string]$EmptyText = 'All')
    if ($Items.Count -gt 0) { return ($Items -join ', ') }
    return $EmptyText
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Module name: {0}" -f $ModuleName)
Write-Log -Message ("Update source: {0}" -f $UpdateSource)
Write-Log -Message ("Selected UpdateType: {0}" -f (Get-SelectionText -Items $SelectedUpdateTypes))
Write-Log -Message ("Selected Category: {0}" -f (Get-SelectionText -Items $SelectedUpdateCategories))
Write-Log -Message ("Selected Severity: {0}" -f (Get-SelectionText -Items $SelectedUpdateSeverities))
Write-Log -Message ("Included KBs: {0}" -f (Get-SelectionText -Items $IncludeKBArticleIDs -EmptyText 'None'))
Write-Log -Message ("Excluded KBs: {0}" -f (Get-SelectionText -Items $ExcludeKBArticleIDs -EmptyText 'None'))
Write-Log -Message ("Auto reboot after install: {0}" -f $AutoRebootAfterInstall)

try {
    $currentPolicy = Get-ExecutionPolicy
    Write-Log -Message ("Current execution policy is '{0}'. No changes are made by this remediation script." -f $currentPolicy)

    Test-UpdateConfiguration
    Ensure-Module -Name $ModuleName
    Import-Module $ModuleName -ErrorAction Stop
    Write-Log -Level 'SUCCESS' -Message ("Module '{0}' imported successfully." -f $ModuleName)

    $updateQueryParameters = Get-UpdateQueryParameters
    $matchingUpdates = @(Get-WindowsUpdate @updateQueryParameters)
    Write-Log -Message ("Matching updates returned: {0}" -f $matchingUpdates.Count)

    if ($matchingUpdates.Count -gt 0) {
        Write-Log -Message ("Installing {0} matching Windows updates." -f $matchingUpdates.Count)
        $installParameters = Get-InstallParameters
        Install-WindowsUpdate @installParameters | Out-Null
        Write-Log -Level 'SUCCESS' -Message 'All matching updates installed successfully.'

        if (Test-PendingReboot) {
            Write-Log -Level 'WARNING' -Message 'A reboot is required to complete the update process.'
        }
        else {
            Write-Log -Level 'SUCCESS' -Message 'No reboot is required after updates.'
        }
    }
    else {
        Write-Log -Level 'SUCCESS' -Message 'No matching updates were found.'
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Windows Update remediation completed successfully.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Remediation error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
