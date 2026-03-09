<#
.SYNOPSIS
    Remediates the .NET Framework 3.5 feature by enabling it.

.DESCRIPTION
    This remediation script checks the current state of the NetFx3 Windows
    optional feature.

    If the feature is not enabled, the script attempts to install it.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System

.EXAMPLE
    .\dotNet3.5_Feature--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'dotNet3.5_Feature--Remediate.ps1'
$ScriptBaseName = 'dotNet3.5_Feature--Remediate'
$SolutionName   = 'Enable .Net3.5 Feature'

# Windows feature to enable
$FeatureName = 'NetFx3'

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

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Feature name: $FeatureName"
Write-Log -Message "Log file: $LogFile"

try {
    # Check the current state first
    $Feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop

    if (-not $Feature) {
        Write-Log -Message "No feature data was returned for '$FeatureName'." -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "Current feature state: $($Feature.State)"

    if ($Feature.State -eq 'Enabled') {
        Write-Log -Message '.NET Framework 3.5 is already enabled.' -Level 'SUCCESS'
        exit 0
    }

    Write-Log -Message 'Enabling .NET Framework 3.5...'

    # Enable the optional feature
    Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart -ErrorAction Stop | Out-Null

    # Verify the result
    $FeatureAfter = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop

    if ($FeatureAfter.State -eq 'Enabled') {
        Write-Log -Message '.NET Framework 3.5 has been enabled successfully.' -Level 'SUCCESS'
        exit 0
    }
    else {
        Write-Log -Message "Feature installation finished, but current state is '$($FeatureAfter.State)'." -Level 'WARNING'
        exit 1
    }
}
catch {
    Write-Log -Message "Failed to enable .NET Framework 3.5: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------