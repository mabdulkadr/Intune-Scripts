<#
.SYNOPSIS
    Detects whether matching Windows updates are pending.

.DESCRIPTION
    This detection script checks for available Windows updates on the local
    device by using the PSWindowsUpdate module.

    You can optionally target specific update types, categories, severities,
    or KB article IDs from the configuration block. If one or more matching
    updates are pending, remediation should run.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant
    - Exit 2: Detection error

.RUN AS
    System

.EXAMPLE
    .\ForceWindowsUpdate--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'ForceWindowsUpdate--Detect.ps1'
$ScriptBaseName = 'ForceWindowsUpdate--Detect'
$SolutionName   = 'Force Windows Update'

# Update module and source
$ModuleName   = 'PSWindowsUpdate'
$UpdateSource = 'MicrosoftUpdate'   # Valid values: MicrosoftUpdate, WindowsUpdate

# Reference values for filtering
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

# Leave these arrays empty to check all updates
$SelectedUpdateTypes      = @()
$SelectedUpdateCategories = @()
$SelectedUpdateSeverities = @()
$IncludeKBArticleIDs      = @()
$ExcludeKBArticleIDs      = @()

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if needed
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

# Write a message to console and log file
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

# Return a friendly label for log output
function Get-ArrayDisplayValue {
    param(
        [object[]]$Value,
        [string]$EmptyText = 'All'
    )

    if ($Value -and $Value.Count -gt 0) {
        return ($Value -join ', ')
    }

    return $EmptyText
}

# Validate current filter settings
function Test-UpdateConfiguration {
    $ValidSources = @('MicrosoftUpdate', 'WindowsUpdate')
    if ($UpdateSource -notin $ValidSources) {
        throw "Invalid UpdateSource '$UpdateSource'. Valid values: $($ValidSources -join ', ')"
    }

    $InvalidTypes = @($SelectedUpdateTypes | Where-Object { $_ -notin $AvailableUpdateTypes })
    if ($InvalidTypes.Count -gt 0) {
        throw "Invalid UpdateType value(s): $($InvalidTypes -join ', '). Valid values: $($AvailableUpdateTypes -join ', ')"
    }

    $CustomCategories = @($SelectedUpdateCategories | Where-Object { $_ -notin $AvailableUpdateCategories })
    if ($CustomCategories.Count -gt 0) {
        Write-Log -Message "Custom category value(s) detected: $($CustomCategories -join ', ')" -Level 'WARNING'
    }

    $CustomSeverities = @($SelectedUpdateSeverities | Where-Object { $_ -notin $AvailableUpdateSeverities })
    if ($CustomSeverities.Count -gt 0) {
        Write-Log -Message "Custom severity value(s) detected: $($CustomSeverities -join ', ')" -Level 'WARNING'
    }
}

# Build parameters for Get-WindowsUpdate
function Get-UpdateQueryParameters {
    $Parameters = @{
        ComputerName = 'localhost'
        AcceptAll    = $true
        ErrorAction  = 'Stop'
    }

    if ($UpdateSource -eq 'MicrosoftUpdate') {
        $Parameters.MicrosoftUpdate = $true
    }
    else {
        $Parameters.WindowsUpdate = $true
    }

    if ($SelectedUpdateTypes.Count -gt 0) {
        $Parameters.UpdateType = $SelectedUpdateTypes
    }

    if ($SelectedUpdateCategories.Count -gt 0) {
        $Parameters.Category = $SelectedUpdateCategories
    }

    if ($SelectedUpdateSeverities.Count -gt 0) {
        $Parameters.Severity = $SelectedUpdateSeverities
    }

    if ($IncludeKBArticleIDs.Count -gt 0) {
        $Parameters.KBArticleID = $IncludeKBArticleIDs
    }

    if ($ExcludeKBArticleIDs.Count -gt 0) {
        $Parameters.NotKBArticleID = $ExcludeKBArticleIDs
    }

    return $Parameters
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Module name: $ModuleName"
Write-Log -Message "Update source: $UpdateSource"
Write-Log -Message "Selected UpdateType: $(Get-ArrayDisplayValue -Value $SelectedUpdateTypes -EmptyText 'All')"
Write-Log -Message "Selected Category: $(Get-ArrayDisplayValue -Value $SelectedUpdateCategories -EmptyText 'All')"
Write-Log -Message "Selected Severity: $(Get-ArrayDisplayValue -Value $SelectedUpdateSeverities -EmptyText 'All')"
Write-Log -Message "Included KBs: $(Get-ArrayDisplayValue -Value $IncludeKBArticleIDs -EmptyText 'None')"
Write-Log -Message "Excluded KBs: $(Get-ArrayDisplayValue -Value $ExcludeKBArticleIDs -EmptyText 'None')"
Write-Log -Message "Log file: $LogFile"

try {
    # Validate the selected filters
    Test-UpdateConfiguration

    # Detection should not install modules
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Log -Message "Required module '$ModuleName' is not installed." -Level 'WARNING'
        Write-Output "NonCompliant: Required module '$ModuleName' is not installed."
        exit 1
    }

    Import-Module $ModuleName -ErrorAction Stop
    Write-Log -Message "Module '$ModuleName' imported successfully." -Level 'SUCCESS'

    # Query matching updates
    $UpdateQueryParameters = Get-UpdateQueryParameters
    $MatchingUpdates = @(Get-WindowsUpdate @UpdateQueryParameters)

    Write-Log -Message "Matching updates returned: $($MatchingUpdates.Count)"

    if ($MatchingUpdates.Count -gt 0) {
        Write-Log -Message "There are $($MatchingUpdates.Count) pending matching Windows updates." -Level 'WARNING'

        foreach ($Update in $MatchingUpdates) {
            $KbValue = if ($Update.KB -or $Update.KBArticleIDs) {
                @($Update.KB, $Update.KBArticleIDs | Where-Object { $_ }) | Select-Object -First 1
            }
            else {
                'No KB'
            }

            $TitleValue = if ($Update.Title) { $Update.Title } else { 'No title' }
            Write-Log -Message "Pending update: $KbValue | $TitleValue" -Level 'WARNING'
        }

        Write-Output "There are $($MatchingUpdates.Count) pending Windows updates."
        exit 1
    }

    Write-Log -Message 'No pending matching Windows updates were found.' -Level 'SUCCESS'
    Write-Output 'No pending Windows updates.'
    exit 0
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Output "Error during detection: $($_.Exception.Message)"
    exit 2
}

#endregion ---------- Detection Logic ----------