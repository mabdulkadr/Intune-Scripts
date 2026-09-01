<#
.TITLE
    Backup Intune Configuration

.SYNOPSIS
    Exports Intune configuration profiles, compliance policies, ADMX policies, and platform scripts to JSON files for backup and versioning.

.DESCRIPTION
    This script connects to Microsoft Graph and exports the core Intune configuration
    surfaces to a timestamped backup folder: device configuration profiles, settings
    catalog policies (including their full setting bodies), compliance policies,
    administrative template (ADMX) policies with their definition values, Windows
    PowerShell scripts, and macOS shell scripts. Each object is written as one JSON
    file including its assignments, and a manifest summarizes the backup. The output
    is designed to be stored in source control for change tracking and used as input
    for the companion restore-intune-configuration script. Supports both interactive
    sign-in (delegated) and app-only authentication (client secret or certificate)
    on the workstation. Workstation-only execution.

.TAGS
    Configuration

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.2.1

.CHANGELOG
    1.2.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.2 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.1 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\backup-intune-configuration.ps1
    Exports all supported configuration areas to a timestamped folder beside the script

.EXAMPLE
    .\backup-intune-configuration.ps1 -OutputPath "C:\IntuneBackups" -Areas DeviceConfigurations,CompliancePolicies
    Exports only classic configuration profiles and compliance policies to C:\IntuneBackups

.EXAMPLE
    .\backup-intune-configuration.ps1 -SkipScriptContent "true"
    Exports all areas but skips downloading the base64 script bodies of platform scripts

.NOTES
    - Requires Microsoft.Graph.Authentication module (auto-installed if missing)
    - Uses beta Graph endpoints because the full Intune configuration surface is not exposed on v1.0
    - Settings catalog setting bodies and ADMX definition values require one extra request per policy
    - Graph never returns secret values (encrypted OMA-URI settings, passwords, certificates) in exports; those settings appear with secret references only and must be re-entered manually after a restore
    - Interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows if present, with fallback to Microsoft.Graph.Authentication
    - Workstation dual-mode: interactive (delegated) or app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint
    - Relative output paths resolve beside this script, not the caller's working directory
    - Logs: %ProgramData%\backup-intune-configuration\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Folder in which the timestamped backup folder is created")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Configuration areas to export")]
    [ValidateSet("DeviceConfigurations", "SettingsCatalog", "CompliancePolicies", "AdmxPolicies", "PlatformScripts")]
    [string[]]$Areas = @("DeviceConfigurations", "SettingsCatalog", "CompliancePolicies", "AdmxPolicies", "PlatformScripts"),

    [Parameter(Mandatory = $false, HelpMessage = "Skip downloading base64 script bodies of platform scripts")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$SkipScriptContent,

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Entra tenant ID for app-only authentication")]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "App registration client ID for app-only authentication")]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication (alternative to client secret)")]
    [string]$CertificateThumbprint
)

$ErrorActionPreference = 'Stop'

# Normalize the local module-install override for workstation parameter binding.
$forceModuleInstallRaw = [string]$ForceModuleInstall
Remove-Variable -Name ForceModuleInstall
if ([string]::IsNullOrWhiteSpace($forceModuleInstallRaw)) {
    $ForceModuleInstall = $false
}
elseif ($forceModuleInstallRaw.Trim().ToLowerInvariant() -in @("true", "1", '$true')) {
    $ForceModuleInstall = $true
}
elseif ($forceModuleInstallRaw.Trim().ToLowerInvariant() -in @("false", "0", '$false')) {
    $ForceModuleInstall = $false
}
else {
    throw "Parameter 'ForceModuleInstall' accepts only true, false, 1, 0, $true, or $false."
}

# Workstation string boolean normalization. Normalize the
# public boolean parameters once so workstation execution uses real booleans.
foreach ($runbookBooleanParameter in @('SkipScriptContent')) {
    $runbookBooleanRaw = [string](Get-Variable -Name $runbookBooleanParameter -ValueOnly)
    Remove-Variable -Name $runbookBooleanParameter

    if ([string]::IsNullOrWhiteSpace($runbookBooleanRaw)) {
        Set-Variable -Name $runbookBooleanParameter -Value $false
        continue
    }

    switch ($runbookBooleanRaw.Trim().ToLowerInvariant()) {
        { $_ -in @("true", "1", '$true') } {
            Set-Variable -Name $runbookBooleanParameter -Value $true
        }
        { $_ -in @("false", "0", '$false') } {
            Set-Variable -Name $runbookBooleanParameter -Value $false
        }
        default {
            throw "Parameter '$runbookBooleanParameter' accepts only true, false, 1, 0, $true, or $false."
        }
    }
}

# ============================================================================
# CONFIGURATION - solution identity for structured logging.
# ============================================================================

$SolutionName = 'backup-intune-configuration'
$ScriptMode   = 'run'

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# Single source of truth: Initialize-Log / Write-Banner / Write-Log / Finish-Script.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

# Creates the Intune log folder/file and reports readiness.
function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')]
        [string]$Type = 'General'
    )

    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }

        if (-not (Test-Path -LiteralPath $script:LogRoot)) {
            $null = [System.IO.Directory]::CreateDirectory($script:LogRoot)
        }
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            $null = [System.IO.File]::Create($script:LogFile).Dispose()
        }

        $script:LogReady = $true
        return $true
    }
    catch {
        Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

# Writes the solution banner to console and log file.
function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    $title      = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        } else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady -and $script:LogFile) {
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }
}

# Writes one timestamped, level-colored line to console and log file.
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $logLine -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoExit
    )

    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) {
        exit $ExitCode
    }
}

# ============================================================================
# OUTPUT PATH ANCHORING - relative export paths resolve beside this script.
# ============================================================================

$scriptBase = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    (Get-Location).Path
}
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $scriptBase $OutputPath
}

# ============================================================================
# MODULE SETUP (workstation)
# ============================================================================

function Initialize-RequiredModule {
    param(
        [string[]]$ModuleNames,
        [bool]$ForceInstall = $false
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-Verbose "Checking module: $ModuleName"

        $module = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

        if (-not $module) {
            Write-Information "Module '$ModuleName' not found. Installing..." -InformationAction Continue

            if (-not $ForceInstall) {
                $response = Read-Host "Install module '$ModuleName'? (Y/N)"
                if ($response -notmatch '^[Yy]') {
                    throw "Module '$ModuleName' is required but installation was declined."
                }
            }

            try {
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }

                Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                Write-Information "✓ Successfully installed '$ModuleName'" -InformationAction Continue
            }
            catch {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }

        Import-Module -Name $ModuleName -Force -ErrorAction Stop
    }
}

# Initialize required modules (workstation - auto-install Microsoft.Graph.Authentication if missing)
$RequiredModules = @("Microsoft.Graph.Authentication", "MgGraphCommunity")

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "✓ All required modules are available"
}
catch {
    Write-Error "Module initialization failed: $_"
    exit 1
}

# ============================================================================
# AUTHENTICATION (workstation dual-mode: interactive or app-only)
# ============================================================================

try {
    $isAppOnly = (-not [string]::IsNullOrWhiteSpace($TenantId) -and -not [string]::IsNullOrWhiteSpace($ClientId) -and (-not [string]::IsNullOrWhiteSpace($ClientSecret) -or -not [string]::IsNullOrWhiteSpace($CertificateThumbprint)))
    if ($isAppOnly) {
        Write-Output "Connecting to Microsoft Graph (app-only)..."
        if (-not [string]::IsNullOrWhiteSpace($CertificateThumbprint)) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        else {
            $secureSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $secureSecret -NoWelcome -ErrorAction Stop
        }
    }
    else {
        Write-Output "Connecting to Microsoft Graph (interactive)..."
        $Scopes = @(
            "DeviceManagementConfiguration.Read.All"
        )
        try {
            if (Get-Module -ListAvailable -Name MgGraphCommunity) {
                Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
            }
            else {
                Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
            }
        }
        catch {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
    }
    Write-Output "✓ Successfully connected to Microsoft Graph"
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-MgGraphAllPages {
    param(
        [string]$Uri,
        [int]$DelayMs = 100
    )

    $allResults = @()
    $nextLink = $Uri

    do {
        try {
            if ($allResults.Count -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }

            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET

            if ($null -ne $response.value) {
                $allResults += $response.value
            }
            else {
                $allResults += $response
            }

            $nextLink = $response.'@odata.nextLink'
        }
        catch {
            if ($_.Exception.Message -like "*429*") {
                Write-Information "Rate limit hit, waiting 60 seconds..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data: $($_.Exception.Message)"
        }
    } while ($nextLink)

    return $allResults
}

function Get-SafeFileName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return "unnamed"
    }

    $safe = $Name -replace '[\\/:*?"<>|]', '_'
    $safe = $safe.Trim().Trim('.')
    if ($safe.Length -gt 120) {
        $safe = $safe.Substring(0, 120)
    }
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "unnamed"
    }
    return $safe
}

function Export-BackupObject {
    param(
        [object]$InputObject,
        [string]$FolderPath,
        [string]$DisplayName,
        [string]$Id
    )

    $fileName = "$(Get-SafeFileName -Name $DisplayName)_$Id.json"
    $filePath = Join-Path $FolderPath $fileName
    $InputObject | ConvertTo-Json -Depth 25 | Out-File -FilePath $filePath -Encoding utf8
    return $fileName
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================
# Flow: log init -> banner -> export each area -> manifest -> summary.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Intune configuration backup started" -Level 'INFO'
    Write-Output "Starting Intune configuration backup..."

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupRoot = Join-Path $OutputPath "IntuneConfigBackup_$timestamp"
    $null = New-Item -Path $backupRoot -ItemType Directory -Force

    $manifest = [ordered]@{
        backupDate    = (Get-Date -Format "o")
        areas         = @{}
        totalObjects  = 0
        backupVersion = "1.0"
    }

    # ----- Classic device configuration profiles -----
    if ($Areas -contains "DeviceConfigurations") {
        Write-Output "Exporting device configuration profiles..."
        $folder = Join-Path $backupRoot "DeviceConfigurations"
        $null = New-Item -Path $folder -ItemType Directory -Force

        $profiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$expand=assignments"
        foreach ($configProfile in $profiles) {
            $null = Export-BackupObject -InputObject $configProfile -FolderPath $folder -DisplayName $configProfile.displayName -Id $configProfile.id
        }

        $manifest.areas["DeviceConfigurations"] = @($profiles).Count
        $manifest.totalObjects += @($profiles).Count
        Write-Output "✓ Exported $(@($profiles).Count) device configuration profiles"
    }

    # ----- Settings catalog policies -----
    if ($Areas -contains "SettingsCatalog") {
        Write-Output "Exporting settings catalog policies..."
        $folder = Join-Path $backupRoot "SettingsCatalog"
        $null = New-Item -Path $folder -ItemType Directory -Force

        $policies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$expand=assignments"
        foreach ($policy in $policies) {
            # The list endpoint returns only a settingCount; the full setting bodies
            # live behind the per-policy settings navigation
            $settings = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)/settings"
            $policy | Add-Member -MemberType NoteProperty -Name "settings" -Value @($settings) -Force

            $null = Export-BackupObject -InputObject $policy -FolderPath $folder -DisplayName $policy.name -Id $policy.id
        }

        $manifest.areas["SettingsCatalog"] = @($policies).Count
        $manifest.totalObjects += @($policies).Count
        Write-Output "✓ Exported $(@($policies).Count) settings catalog policies"
    }

    # ----- Compliance policies -----
    if ($Areas -contains "CompliancePolicies") {
        Write-Output "Exporting compliance policies..."
        $folder = Join-Path $backupRoot "CompliancePolicies"
        $null = New-Item -Path $folder -ItemType Directory -Force

        # scheduledActionsForRule must be expanded explicitly; recreating a policy
        # without it is rejected by Graph, so the backup would be incomplete
        $compliancePolicies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies?`$expand=assignments,scheduledActionsForRule(`$expand=scheduledActionConfigurations)"
        foreach ($policy in $compliancePolicies) {
            $null = Export-BackupObject -InputObject $policy -FolderPath $folder -DisplayName $policy.displayName -Id $policy.id
        }

        $manifest.areas["CompliancePolicies"] = @($compliancePolicies).Count
        $manifest.totalObjects += @($compliancePolicies).Count
        Write-Output "✓ Exported $(@($compliancePolicies).Count) compliance policies"
    }

    # ----- Administrative template (ADMX) policies -----
    if ($Areas -contains "AdmxPolicies") {
        Write-Output "Exporting administrative template policies..."
        $folder = Join-Path $backupRoot "AdmxPolicies"
        $null = New-Item -Path $folder -ItemType Directory -Force

        $admxPolicies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations?`$expand=assignments"
        foreach ($policy in $admxPolicies) {
            # Definition values carry the actual configured settings; the expanded
            # definition gives human-readable names for the restore/report side
            $definitionValues = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/definitionValues?`$expand=definition(`$select=id,classType,displayName,categoryPath),presentationValues"
            $policy | Add-Member -MemberType NoteProperty -Name "definitionValues" -Value @($definitionValues) -Force

            $null = Export-BackupObject -InputObject $policy -FolderPath $folder -DisplayName $policy.displayName -Id $policy.id
        }

        $manifest.areas["AdmxPolicies"] = @($admxPolicies).Count
        $manifest.totalObjects += @($admxPolicies).Count
        Write-Output "✓ Exported $(@($admxPolicies).Count) administrative template policies"
    }

    # ----- Platform scripts (Windows PowerShell + macOS shell) -----
    if ($Areas -contains "PlatformScripts") {
        Write-Output "Exporting platform scripts..."
        $folder = Join-Path $backupRoot "PlatformScripts"
        $null = New-Item -Path $folder -ItemType Directory -Force

        $scriptSurfaces = @(
            @{ Name = "deviceManagementScripts"; Label = "Windows PowerShell scripts" },
            @{ Name = "deviceShellScripts"; Label = "macOS shell scripts" }
        )

        $scriptCount = 0
        foreach ($surface in $scriptSurfaces) {
            $platformScripts = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/$($surface.Name)?`$expand=assignments"

            foreach ($platformScript in $platformScripts) {
                # scriptContent is always null on the list endpoint; the single-object
                # GET returns the base64 body
                if (-not $SkipScriptContent) {
                    try {
                        $detail = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/$($surface.Name)/$($platformScript.id)" -Method GET
                        $platformScript.scriptContent = $detail.scriptContent
                    }
                    catch {
                        Write-Warning "Could not fetch script content for '$($platformScript.displayName)': $($_.Exception.Message)"
                    }
                }

                $platformScript | Add-Member -MemberType NoteProperty -Name "scriptSurface" -Value $surface.Name -Force
                $null = Export-BackupObject -InputObject $platformScript -FolderPath $folder -DisplayName $platformScript.displayName -Id $platformScript.id
                $scriptCount++
            }

            Write-Output "✓ Exported $(@($platformScripts).Count) $($surface.Label)"
        }

        $manifest.areas["PlatformScripts"] = $scriptCount
        $manifest.totalObjects += $scriptCount
    }

    # ----- Manifest -----
    $manifestPath = Join-Path $backupRoot "manifest.json"
    $manifest | ConvertTo-Json -Depth 5 | Out-File -FilePath $manifestPath -Encoding utf8

    Write-Output "`n========================================"
    Write-Output "Backup Summary"
    Write-Output "========================================"
    foreach ($area in $manifest.areas.Keys) {
        Write-Output "$($area): $($manifest.areas[$area]) objects"
    }
    Write-Output "Total: $($manifest.totalObjects) objects"
    Write-Output "Backup folder: $backupRoot"
    Write-Output "========================================"
    Write-Log -Message "Backup completed: $($manifest.totalObjects) objects exported to $backupRoot" -Level 'SUCCESS'
}
catch {
    Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    try {
        $null = Disconnect-MgGraph
        Write-Output "✓ Disconnected from Microsoft Graph"
    }
    catch {
        Write-Verbose "Graph disconnection completed"
    }
}
