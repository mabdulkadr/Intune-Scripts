<#
.SYNOPSIS
    Remediates IPv6 by disabling it on network adapters and in the registry.

.DESCRIPTION
    This remediation script disables the ms_tcpip6 binding on network adapters
    where IPv6 is still enabled, then updates the registry to disable IPv6
    system-wide.

    A restart is usually required for the full change to take effect.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User (depending on Intune assignment)

.EXAMPLE
    .\DisableIPv6--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'DisableIPv6--Remediate.ps1'
$ScriptBaseName = 'DisableIPv6--Remediate'
$SolutionName   = 'Disable-IPv6'

# IPv6 binding and registry settings
$BindingComponentId = 'ms_tcpip6'
$RegistryPath       = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
$RegistryValueName  = 'DisabledComponents'
$RegistryValueData  = 255

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

# Return all IPv6 bindings
function Get-IPv6Bindings {
    try {
        @(Get-NetAdapterBinding -ComponentID $BindingComponentId -ErrorAction Stop)
    }
    catch {
        @()
    }
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Binding component: $BindingComponentId"
Write-Log -Message "Log file: $LogFile"

try {
    # Get all adapter bindings first
    $AllBindings = Get-IPv6Bindings

    if (-not $AllBindings) {
        Write-Log -Message "No adapter bindings were returned for component '$BindingComponentId'." -Level 'ERROR'
        exit 1
    }

    $EnabledBindings = @($AllBindings | Where-Object { $_.Enabled -eq $true })

    Write-Log -Message "Total adapters found: $($AllBindings.Count)"
    Write-Log -Message "Adapters with IPv6 enabled: $($EnabledBindings.Count)"

    $FailedAdapters = @()

    # Disable IPv6 only where still enabled
    if ($EnabledBindings.Count -eq 0) {
        Write-Log -Message 'No adapters currently have IPv6 enabled. No binding changes required.' -Level 'SUCCESS'
    }
    else {
        foreach ($Binding in $EnabledBindings) {
            try {
                Disable-NetAdapterBinding -Name $Binding.Name -ComponentID $BindingComponentId -ErrorAction Stop
                Write-Log -Message "IPv6 disabled on adapter: $($Binding.Name)" -Level 'SUCCESS'
            }
            catch {
                $FailedAdapters += $Binding.Name
                Write-Log -Message "Failed to disable IPv6 on adapter '$($Binding.Name)': $($_.Exception.Message)" -Level 'WARNING'
            }
        }
    }

    # Apply the registry setting for system-wide IPv6 disable
    try {
        New-Item -Path $RegistryPath -Force -ErrorAction SilentlyContinue | Out-Null

        New-ItemProperty `
            -Path $RegistryPath `
            -Name $RegistryValueName `
            -PropertyType DWord `
            -Value $RegistryValueData `
            -Force `
            -ErrorAction Stop | Out-Null

        Write-Log -Message "Registry updated: $RegistryPath\$RegistryValueName = $RegistryValueData" -Level 'SUCCESS'
        Write-Log -Message 'A system restart is required for the full change to take effect.'
    }
    catch {
        Write-Log -Message "Failed to update registry: $($_.Exception.Message)" -Level 'ERROR'
        exit 1
    }

    if ($FailedAdapters.Count -gt 0) {
        Write-Log -Message "Remediation completed with adapter-level issues. Failed adapters: $($FailedAdapters -join ', ')" -Level 'WARNING'
        exit 1
    }

    Write-Log -Message 'Remediation completed successfully. A system restart is required.' -Level 'SUCCESS'
    exit 0
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------