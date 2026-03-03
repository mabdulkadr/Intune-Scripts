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
    .\ForceWindowsUpdate--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'ForceWindowsUpdate--Remediate.ps1'
$ScriptBaseName = 'ForceWindowsUpdate--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# PowerShell module used during remediation.
$ModuleName = 'PSWindowsUpdate'

# Update source.
# Valid values: MicrosoftUpdate, WindowsUpdate
$UpdateSource = 'MicrosoftUpdate'

# Reference values for UpdateType.
$AvailableUpdateTypes = @(
    'Driver',
    'Software'
)

# Common category values. These are reference values for easy selection.
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

# Common severity values. These are reference values for easy selection.
$AvailableUpdateSeverities = @(
    'Critical',
    'Important',
    'Moderate',
    'Low'
)

# User selections.
# Leave arrays empty to target all available updates.
$SelectedUpdateTypes      = @()
$SelectedUpdateCategories = @()
$SelectedUpdateSeverities = @()
$IncludeKBArticleIDs      = @()
$ExcludeKBArticleIDs      = @()

# Reboot behavior after installation.
$AutoRebootAfterInstall = $false

# Common registry locations used to detect a pending reboot.
$PendingRebootKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
)
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Force Windows Update"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Remediation-specific log file.
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ==================== PATHS AND LOGGING ====================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and file exist before any write attempts.
function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        return $true
    }
    catch {
        # If logging init fails, the script still continues with console output.
        return $false
    }
}

$LogReady = Initialize-Logging

# Write colored console output and persist the same line to the log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "OK", "WARN", "FAIL")]
        [string]$Level = "INFO"
    )

    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    switch ($Level) {
        "OK"   { Write-Host $line -ForegroundColor Green }
        "WARN" { Write-Host $line -ForegroundColor Yellow }
        "FAIL" { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    if ($LogReady) {
        try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
    }
}

# Ensure the required update module is available before installing updates.
function Ensure-Module {
    param([string]$Name)

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Log -Level "WARN" -Message ("Module '{0}' was not found. Installing it now." -f $Name)
        Install-Module -Name $Name -Force -AllowClobber -ErrorAction Stop
        Write-Log -Level "OK" -Message ("Module '{0}' installed successfully." -f $Name)
    }
    else {
        Write-Log -Level "OK" -Message ("Module '{0}' is already installed." -f $Name)
    }
}

# Validate user selections before calling PSWindowsUpdate.
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
        Write-Log -Level "WARN" -Message ("Custom category value(s) detected: {0}" -f ($customCategories -join ', '))
    }

    $customSeverities = @($SelectedUpdateSeverities | Where-Object { $_ -notin $AvailableUpdateSeverities })
    if ($customSeverities.Count -gt 0) {
        Write-Log -Level "WARN" -Message ("Custom severity value(s) detected: {0}" -f ($customSeverities -join ', '))
    }
}

# Build the PSWindowsUpdate query parameters from the current configuration.
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

    if ($SelectedUpdateTypes.Count -gt 0) {
        $parameters.UpdateType = $SelectedUpdateTypes
    }
    if ($SelectedUpdateCategories.Count -gt 0) {
        $parameters.Category = $SelectedUpdateCategories
    }
    if ($SelectedUpdateSeverities.Count -gt 0) {
        $parameters.Severity = $SelectedUpdateSeverities
    }
    if ($IncludeKBArticleIDs.Count -gt 0) {
        $parameters.KBArticleID = $IncludeKBArticleIDs
    }
    if ($ExcludeKBArticleIDs.Count -gt 0) {
        $parameters.NotKBArticleID = $ExcludeKBArticleIDs
    }

    return $parameters
}

# Build the PSWindowsUpdate install parameters from the current configuration.
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

    if ($SelectedUpdateTypes.Count -gt 0) {
        $parameters.UpdateType = $SelectedUpdateTypes
    }
    if ($SelectedUpdateCategories.Count -gt 0) {
        $parameters.Category = $SelectedUpdateCategories
    }
    if ($SelectedUpdateSeverities.Count -gt 0) {
        $parameters.Severity = $SelectedUpdateSeverities
    }
    if ($IncludeKBArticleIDs.Count -gt 0) {
        $parameters.KBArticleID = $IncludeKBArticleIDs
    }
    if ($ExcludeKBArticleIDs.Count -gt 0) {
        $parameters.NotKBArticleID = $ExcludeKBArticleIDs
    }

    return $parameters
}

# Check common registry locations that indicate a reboot is pending.
function Test-PendingReboot {
    foreach ($RegistryKey in $PendingRebootKeys) {
        if (Test-Path -Path $RegistryKey) {
            return $true
        }
    }

    return $false
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ==================== FIRST REMEDIATION BLOCK ====================
Write-Log -Level "INFO" -Message "=== Remediation START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level "INFO" -Message ("Module name: {0}" -f $ModuleName)
Write-Log -Level "INFO" -Message ("Update source: {0}" -f $UpdateSource)
Write-Log -Level "INFO" -Message ("Selected UpdateType: {0}" -f $(if ($SelectedUpdateTypes.Count) { $SelectedUpdateTypes -join ', ' } else { 'All' }))
Write-Log -Level "INFO" -Message ("Selected Category: {0}" -f $(if ($SelectedUpdateCategories.Count) { $SelectedUpdateCategories -join ', ' } else { 'All' }))
Write-Log -Level "INFO" -Message ("Selected Severity: {0}" -f $(if ($SelectedUpdateSeverities.Count) { $SelectedUpdateSeverities -join ', ' } else { 'All' }))
Write-Log -Level "INFO" -Message ("Included KBs: {0}" -f $(if ($IncludeKBArticleIDs.Count) { $IncludeKBArticleIDs -join ', ' } else { 'None' }))
Write-Log -Level "INFO" -Message ("Excluded KBs: {0}" -f $(if ($ExcludeKBArticleIDs.Count) { $ExcludeKBArticleIDs -join ', ' } else { 'None' }))
Write-Log -Level "INFO" -Message ("Auto reboot after install: {0}" -f $AutoRebootAfterInstall)

try {
    # Log the current execution policy for visibility, but do not modify it here.
    $CurrentPolicy = Get-ExecutionPolicy
    Write-Log -Level "INFO" -Message ("Current execution policy is '{0}'. No changes are made by this remediation script." -f $CurrentPolicy)

    # Validate the configured filters and ensure the update module is ready.
    Test-UpdateConfiguration
    Ensure-Module -Name $ModuleName
    Import-Module $ModuleName -ErrorAction Stop
    Write-Log -Level "OK" -Message ("Module '{0}' imported successfully." -f $ModuleName)

    # Query available updates using the selected filters.
    $UpdateQueryParameters = Get-UpdateQueryParameters
    $MatchingUpdates = @(Get-WindowsUpdate @UpdateQueryParameters)
    Write-Log -Level "INFO" -Message ("Matching updates returned: {0}" -f $MatchingUpdates.Count)

    if ($MatchingUpdates.Count -gt 0) {
        Write-Log -Level "INFO" -Message ("Installing {0} matching Windows updates." -f $MatchingUpdates.Count)
        $InstallParameters = Get-InstallParameters
        Install-WindowsUpdate @InstallParameters | Out-Null
        Write-Log -Level "OK" -Message "All matching updates installed successfully."

        # Report whether a restart is required after update installation.
        if (Test-PendingReboot) {
            Write-Log -Level "WARN" -Message "A reboot is required to complete the update process."
        }
        else {
            Write-Log -Level "OK" -Message "No reboot is required after updates."
        }
    }
    else {
        Write-Log -Level "OK" -Message "No matching updates were found."
    }

    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
    exit 0
}
catch {
    Write-Log -Level "FAIL" -Message ("Remediation error: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
