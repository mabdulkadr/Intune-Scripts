<#
.TITLE
    Get Outdated iOS Devices Report

.SYNOPSIS
    Reports Intune-managed iOS devices running a major version older than the latest two releases.

.DESCRIPTION
    Connects to Microsoft Graph and retrieves Intune-managed iOS devices, including
    their assigned user and last check-in date. Devices with an iOS major version
    lower than the older of the two supported major releases are exported to a
    timestamped CSV file. The supported major versions can be updated by parameter
    when Apple releases a new major version.

    Workstation authentication modes:
    - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available).
    - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication.
    Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.
.TAGS
    Monitoring,Devices

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.1.1

.CHANGELOG
    1.1.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.1 - Added workstation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\get-outdated-ios-devices-report.ps1
    Reports devices below iOS 18 and exports the results to the current directory.

.EXAMPLE
    .\get-outdated-ios-devices-report.ps1 -OutputPath "C:\Reports"
    Exports the timestamped CSV report to C:\Reports.

.EXAMPLE
    .\get-outdated-ios-devices-report.ps1 -LatestMajorVersion 27 -PreviousMajorVersion 26
    Uses iOS 27 and iOS 26 as the latest two major releases.

.NOTES
    - Requires Microsoft.Graph.Authentication and, for local runs, MgGraphCommunity.
    - Defaults to iOS 26 and iOS 18, the two released major branches as of 2026-07-29.
    - A device is outdated when its parsed major version is lower than the older supported major.
    - Devices with a missing or unrecognized OS version are excluded and reported as warnings.
    - Workstation app-only authentication requires the same Graph permissions granted to the Entra app registration.
    - Local interactive sign-in uses MgGraphCommunity to avoid mandatory WAM authentication.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The latest released iOS major version")]
    [ValidateRange(1, 99)]
    [int]$LatestMajorVersion = 26,

    [Parameter(Mandatory = $false, HelpMessage = "The previous released iOS major version")]
    [ValidateRange(1, 99)]
    [int]$PreviousMajorVersion = 18,

    [Parameter(Mandatory = $false, HelpMessage = "Directory in which the timestamped CSV report will be saved")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Tenant ID for app-only authentication")]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "Client ID for app-only authentication")]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication")]
    [string]$CertificateThumbprint
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and log placement.
# ============================================================================

$SolutionName = 'get-outdated-ios-devices-report'
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

# Resolves the script directory across direct runs and dot-sourcing (Law 12).
$scriptBase = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).Path
}

# Anchors the default output directory beside the script (Law 12).
if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
    $OutputPath = $scriptBase
}

# Normalize the local module-install override for workstation parameter binding.
$forceModuleInstallRaw = [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Tenant ID for app-only authentication")]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "Client ID for app-only authentication")]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication")]
    [string]$CertificateThumbprint
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

# ============================================================================
# ENVIRONMENT DETECTION AND SETUP
# ============================================================================

function Initialize-RequiredModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ModuleNames,

        [Parameter(Mandatory = $false)]
        [bool]$ForceInstall = $false
    )

    foreach ($moduleName in $ModuleNames) {
        $module = Get-Module -ListAvailable -Name $moduleName | Select-Object -First 1

        if (-not $module) {
Write-Information "Module '$moduleName' was not found." -InformationAction Continue

            if (-not $ForceInstall) {
                $response = Read-Host "Install module '$moduleName'? (Y/N)"
                if ($response -notmatch '^[Yy]') {
                    throw "Module '$moduleName' is required, but installation was declined."
                }
            }

            try {
                $installScope = "CurrentUser"

                if ($IsWindows) {
                    $isAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                        [Security.Principal.WindowsBuiltInRole]::Administrator
                    )
                    if ($isAdministrator) {
                        $installScope = "AllUsers"
                    }
                }

                Install-Module -Name $moduleName -Scope $installScope -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
                Write-Information "Installed module '$moduleName'." -InformationAction Continue
            }
            catch {
                throw "Failed to install module '$moduleName': $($_.Exception.Message)"
            }
        }

        try {
            Import-Module -Name $moduleName -Force -ErrorAction Stop
        }
        catch {
            throw "Failed to import module '$moduleName': $($_.Exception.Message)"
        }
    }
}
$RequiredModules = @("Microsoft.Graph.Authentication")

    # MgGraphCommunity gives WAM-free interactive sign-in for local runs
$RequiredModules += "MgGraphCommunity"

try {
    Initialize-RequiredModule `
        -ModuleNames $RequiredModules ` -ForceInstall $ForceModuleInstall
}
catch {
    Write-Error "Module initialization failed: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# AUTHENTICATION (workstation dual-mode: interactive or app-only)
# ============================================================================

try {
    if ($TenantId -and $ClientId -and ($ClientSecret -or $CertificateThumbprint)) {
        Write-Output "Connecting to Microsoft Graph with app-only authentication..."
        if ($CertificateThumbprint) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        else {
            $ClientSecretSecure = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            $ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $ClientSecretSecure
            Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome -ErrorAction Stop
        }
        Write-Output "Successfully connected to Microsoft Graph with app-only authentication."
    }
    else {
        Write-Output "Connecting to Microsoft Graph with interactive authentication..."
        $Scopes = @(
            "DeviceManagementManagedDevices.Read.All"
        )
        Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
        Write-Output "Successfully connected to Microsoft Graph."
    }
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-MgGraphAllPages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 60000)]
        [int]$DelayMs = 100,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10)]
        [int]$MaxRetryCount = 3
    )

    [System.Collections.Generic.List[object]]$allResults = @()
    $nextLink = $Uri
    $requestCount = 0

    do {
        if ($requestCount -gt 0 -and $DelayMs -gt 0) {
            Start-Sleep -Milliseconds $DelayMs
        }

        $retryCount = 0

        while ($true) {
            try {
                $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
                $requestCount++
                break
            }
            catch {
                $isThrottled = $_.Exception.Message -match '429|Too Many Requests|throttl'

                if (-not $isThrottled -or $retryCount -ge $MaxRetryCount) {
                    throw "Microsoft Graph request failed for '$nextLink': $($_.Exception.Message)"
                }

                $retryCount++
                Write-Information "Rate limit reached. Waiting 60 seconds before retry $retryCount of $MaxRetryCount." -InformationAction Continue
                Start-Sleep -Seconds 60
            }
        }

        if ($null -ne $response.value) {
            foreach ($item in @($response.value)) {
                $allResults.Add($item)
            }
        }
        else {
            $allResults.Add($response)
        }

        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

function ConvertTo-IosMajorVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$OsVersion
    )

    if ([string]::IsNullOrWhiteSpace($OsVersion)) {
        return $null
    }

    $versionMatch = [regex]::Match($OsVersion.Trim(), '^(\d+)')
    if (-not $versionMatch.Success) {
        return $null
    }

    return [int]$versionMatch.Groups[1].Value
}

function Resolve-ReportDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

    if (Test-Path -LiteralPath $resolvedPath) {
        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
            throw "OutputPath must be a directory: $resolvedPath"
        }
    }
    else {
        $null = New-Item -Path $resolvedPath -ItemType Directory -Force -ErrorAction Stop
    }

    return $resolvedPath
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

[System.Collections.Generic.List[object]]$report = @()
$csvPath = $null
$totalIosDevices = 0
$unrecognizedVersionCount = 0

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode 'run' -Type 'General'
    Write-Banner
    $supportedMajors = @(@($LatestMajorVersion, $PreviousMajorVersion) | Sort-Object -Unique -Descending)
    if ($supportedMajors.Count -ne 2) {
        throw "LatestMajorVersion and PreviousMajorVersion must be distinct."
    }

    $oldestSupportedMajor = ($supportedMajors | Measure-Object -Minimum).Minimum
    Write-Output "Supported iOS major versions: $($supportedMajors -join ', ')"
    Write-Output "Devices below iOS $oldestSupportedMajor will be reported."

    $selectFields = @(
        "id",
        "azureADDeviceId",
        "deviceName",
        "operatingSystem",
        "osVersion",
        "userId",
        "userDisplayName",
        "userPrincipalName",
        "lastSyncDateTime",
        "serialNumber",
        "manufacturer",
        "model",
        "managedDeviceOwnerType",
        "complianceState"
    ) -join ","

    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?" +
        "`$filter=operatingSystem eq 'iOS'&" +
        "`$select=$selectFields&" +
        "`$top=999"

    Write-Output "Retrieving iOS devices from Intune..."
    $iosDevices = @(Get-MgGraphAllPages -Uri $uri)
    $totalIosDevices = $iosDevices.Count
    Write-Output "Retrieved $totalIosDevices iOS device(s)."

    foreach ($device in $iosDevices) {
        $majorVersion = ConvertTo-IosMajorVersion -OsVersion $device.osVersion

        if ($null -eq $majorVersion) {
            $unrecognizedVersionCount++
            Write-Warning "Skipping device '$($device.deviceName)' because OS version '$($device.osVersion)' could not be parsed."
            continue
        }

        if ($majorVersion -ge $oldestSupportedMajor) {
            continue
        }

        $lastCheckIn = if ($device.lastSyncDateTime) {
            try {
                [DateTimeOffset]::Parse($device.lastSyncDateTime)
            }
            catch {
                Write-Warning "Device '$($device.deviceName)' has an invalid last check-in date: $($device.lastSyncDateTime)"
                $null
            }
        }
        else {
            $null
        }

        $lastCheckInUtc = if ($null -ne $lastCheckIn) {
            $lastCheckIn.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        else {
            $null
        }

        $daysSinceLastCheckIn = if ($null -ne $lastCheckIn) {
            [math]::Max(
                0,
                [math]::Floor(([DateTimeOffset]::UtcNow - $lastCheckIn.ToUniversalTime()).TotalDays)
            )
        }
        else {
            $null
        }

        $report.Add([PSCustomObject]@{
                DeviceName                  = $device.deviceName
                OSVersion                   = $device.osVersion
                OSMajorVersion              = $majorVersion
                OldestSupportedMajorVersion = $oldestSupportedMajor
                AssignedUserDisplayName     = $device.userDisplayName
                AssignedUserPrincipalName   = $device.userPrincipalName
                LastCheckInDateUtc           = $lastCheckInUtc
                DaysSinceLastCheckIn         = $daysSinceLastCheckIn
                SerialNumber                = $device.serialNumber
                Manufacturer                = $device.manufacturer
                Model                       = $device.model
                Ownership                   = $device.managedDeviceOwnerType
                ComplianceState             = $device.complianceState
                AssignedUserId              = $device.userId
                ManagedDeviceId             = $device.id
                EntraDeviceId               = $device.azureADDeviceId
            })
    }

    $sortedReport = @($report | Sort-Object OSMajorVersion, OSVersion, DeviceName)
    $report = [System.Collections.Generic.List[object]]@($sortedReport)

    $reportDirectory = Resolve-ReportDirectory -Path $OutputPath
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $csvPath = Join-Path -Path $reportDirectory -ChildPath "Outdated_iOS_Devices_$timestamp.csv"

    if ($report.Count -gt 0) {
        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    }
    else {
        $emptyReport = [PSCustomObject][ordered]@{
            DeviceName                  = $null
            OSVersion                   = $null
            OSMajorVersion              = $null
            OldestSupportedMajorVersion = $null
            AssignedUserDisplayName     = $null
            AssignedUserPrincipalName   = $null
            LastCheckInDateUtc           = $null
            DaysSinceLastCheckIn         = $null
            SerialNumber                = $null
            Manufacturer                = $null
            Model                       = $null
            Ownership                   = $null
            ComplianceState             = $null
            AssignedUserId              = $null
            ManagedDeviceId             = $null
            EntraDeviceId               = $null
        }
        $header = ($emptyReport | ConvertTo-Csv -NoTypeInformation)[0]
        Set-Content -LiteralPath $csvPath -Value $header -Encoding UTF8 -ErrorAction Stop
    }

    Write-Output "CSV report saved: $csvPath"
    Write-Output "Report summary:"
    Write-Output "  iOS devices evaluated: $totalIosDevices"
    Write-Output "  Outdated devices found: $($report.Count)"
    Write-Output "  Unrecognized OS versions skipped: $unrecognizedVersionCount"
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    $null = Disconnect-MgGraph -ErrorAction SilentlyContinue
}

$report
