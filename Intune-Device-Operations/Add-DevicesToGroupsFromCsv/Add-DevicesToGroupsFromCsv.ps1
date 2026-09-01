<#
.TITLE
    Add Devices to Entra ID Groups from CSV

.SYNOPSIS
    Adds Intune-managed devices to Entra ID groups based on a CSV file input.

.DESCRIPTION
    This script reads a CSV file containing device identifiers and group names, then adds
    the specified devices to their corresponding Entra ID groups. It supports multiple
    device identifiers (Device Name, Serial Number, Entra ID Device ID) for flexible
    device matching and can add devices to multiple groups.

    The script validates that devices exist in Intune before processing, checks for
    existing group memberships to avoid duplicates, and can create new groups with
    user confirmation. A dry-run mode allows previewing changes before execution.

    Workstation authentication modes:
    - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available).
    - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication.
    Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.
.TAGS
    Operational,Devices

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    Group.ReadWrite.All,DeviceManagementManagedDevices.Read.All,Directory.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.4.1

.CHANGELOG
    1.4.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.4 - Added workstation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.3 - workstation now records script progress, outcomes, and summaries in job history
    1.2 - Cache group memberships once per group instead of refetching per CSV row and suppress progress bars in runbooks
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing)
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\add-devices-to-groups-from-csv.ps1 -GenerateTemplate "true"
    Creates a template CSV file using your system's default delimiter (automatically comma for US, semicolon for Europe)

.EXAMPLE
    .\add-devices-to-groups-from-csv.ps1 -GenerateTemplate "true" -TemplatePath "C:\templates\mytemplate.csv"
    Creates a template CSV file at the specified path with system default delimiter

.EXAMPLE
    .\add-devices-to-groups-from-csv.ps1 -CsvPath "C:\devices.csv"
    Reads the CSV file and adds devices to specified groups

.EXAMPLE
    .\add-devices-to-groups-from-csv.ps1 -CsvPath "C:\devices.csv" -DryRun "true"
    Preview what changes would be made without actually making them

.EXAMPLE
    .\add-devices-to-groups-from-csv.ps1 -CsvContent $csvContent -DryRun "true"
    Uses CSV text supplied at runtime, which is suitable for workstation

.EXAMPLE
    .\add-devices-to-groups-from-csv.ps1 -CsvPath "C:\devices.csv" -CreateMissingGroups "true" -Force "true"
    Add devices to groups and automatically create missing groups without prompting

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - CSV file should contain columns: DeviceName, SerialNumber, DeviceId (Entra ID), GroupName
    - At least one device identifier (DeviceName, SerialNumber, or DeviceId) must be provided per row
    - The GroupName column is required for all rows
    - Devices already in target groups will be skipped
    - Device matching priority: DeviceId > SerialNumber > DeviceName
    - CSV import: Automatically detects comma or semicolon delimiters
    - Template generation: Automatically uses your system's regional delimiter (comma for US/UK, semicolon for Europe)
    - Templates will open correctly in Excel on the system that generated them

    CSV Format Example:
    DeviceName,SerialNumber,DeviceId,GroupName
    DESKTOP-ABC123,VMW12345,IT-Department-Devices
    ,VMW67890,Finance-Devices
    ,a1b2c3d4-e5f6-7890-abcd-ef1234567890,Executive-Devices
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to the CSV file containing device and group information")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if ($_ -and -not (Test-Path $_ -PathType Leaf)) {
            throw "CSV file not found at path: $_"
        }
        return $true
    })]
    [string]$CsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "CSV text with device identifiers and GroupName, suitable for workstation")]
    [string]$CsvContent = "",

    [Parameter(Mandatory = $false, HelpMessage = "Generate a CSV template file")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$GenerateTemplate,

    [Parameter(Mandatory = $false, HelpMessage = "Path for the generated template file")]
    [string]$TemplatePath = "device-group-template.csv",

    [Parameter(Mandatory = $false, HelpMessage = "Preview changes without making them")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Automatically create missing groups without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$CreateMissingGroups,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$Force,

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

$SolutionName = 'add-devices-to-groups-from-csv'
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

# workstation supplies portal parameter values as strings. Normalize the
# public boolean parameters once so local and runbook execution use real booleans.
foreach ($runbookBooleanParameter in @('GenerateTemplate', 'DryRun', 'CreateMissingGroups', 'Force')) {
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
# TEMPLATE GENERATION
# ============================================================================

if ($GenerateTemplate) {
    try {
        # Anchor the default template output beside the script (Law 12).
        if (-not $PSBoundParameters.ContainsKey('TemplatePath')) {
            $TemplatePath = Join-Path $scriptBase $TemplatePath
        }
        Write-Output "Generating CSV template file..."

        # Use system's default list separator
        $csvDelimiter = (Get-Culture).TextInfo.ListSeparator
        Write-Output "Using system delimiter: '$csvDelimiter' (comma for US, semicolon for Europe)"

        # Create template data with examples
        $templateData = @(
            [PSCustomObject]@{
                DeviceName   = "DESKTOP-ABC123"
                SerialNumber = "VMW12345"
                DeviceId     = ""
                GroupName    = "IT-Department-Devices"
            },
            [PSCustomObject]@{
                DeviceName   = ""
                SerialNumber = "VMW67890"
                DeviceId     = ""
                GroupName    = "Finance-Devices"
            },
            [PSCustomObject]@{
                DeviceName   = ""
                SerialNumber = ""
                DeviceId     = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                GroupName    = "Executive-Devices"
            },
            [PSCustomObject]@{
                DeviceName   = "LAPTOP-XYZ789"
                SerialNumber = ""
                DeviceId     = ""
                GroupName    = "IT-Department-Devices"
            }
        )

        # Export to CSV with system delimiter
        $templateData | Export-Csv -Path $TemplatePath -NoTypeInformation -Encoding UTF8 -Delimiter $csvDelimiter

        Write-Output "Successfully created template file: $TemplatePath"
        Write-Output ""
        Write-Output "Template includes examples showing:"
        Write-Output "  - Using DeviceName and SerialNumber together"
        Write-Output "  - Using only SerialNumber"
        Write-Output "  - Using only DeviceId (Entra ID Device ID)"
        Write-Output "  - Using only DeviceName"
        Write-Output "  - Multiple devices assigned to the same group"
        Write-Output ""
        Write-Output "Notes:"
        Write-Output "  - At least one device identifier must be provided per row"
        Write-Output "  - GroupName is required for all rows"
        Write-Output "  - Device matching priority: DeviceId > SerialNumber > DeviceName"

        exit 0
    }
    catch {
        Write-Error "Failed to generate template: $($_.Exception.Message)"
        exit 1
    }
}

# Validate the input mode when not generating a local template
if (-not $GenerateTemplate) {
    $csvInputs = @(
        if (-not [string]::IsNullOrWhiteSpace($CsvPath)) { 'CsvPath' }
        if (-not [string]::IsNullOrWhiteSpace($CsvContent)) { 'CsvContent' }
    )
    if ($csvInputs.Count -ne 1) {
        Write-Error "Specify exactly one CSV input: CsvPath or CsvContent. Use GenerateTemplate to create a local template first."
        exit 1
    }
}
elseif (-not [string]::IsNullOrWhiteSpace($CsvContent)) {
    Write-Error "CsvContent cannot be combined with GenerateTemplate."
    exit 1
}

# ============================================================================
# ENVIRONMENT DETECTION AND SETUP
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
else {
                Write-Log -Message "Module '$ModuleName' not found. Installing..." -Level 'INFO'

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
                    Write-Log -Message "Successfully installed '$ModuleName'" -Level 'SUCCESS'
                }
                catch {
                    throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
                }
            }
        }

        Import-Module -Name $ModuleName -Force -ErrorAction Stop
    }
}

# Detect execution environment

# Initialize required modules
$RequiredModules = @("Microsoft.Graph.Authentication")
# MgGraphCommunity gives WAM-free interactive sign-in for local runs
$RequiredModules += "MgGraphCommunity"

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "All required modules are available"
}
catch {
    Write-Error "Module initialization failed: $_"
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
            "Group.ReadWrite.All",
            "DeviceManagementManagedDevices.Read.All",
            "Directory.Read.All"
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
    param(
        [string]$Uri,
        [int]$DelayMs = 100
    )

    $allResults = @()
    $nextLink = $Uri
    $requestCount = 0

    do {
        try {
            if ($requestCount -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }

            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
            $requestCount++

            if ($null -ne $response.value) {
                $allResults += $response.value
            }
            else {
                $allResults += $response
            }

            $nextLink = $response.'@odata.nextLink'
        }
        catch {
            if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*throttled*") {
                Write-Log -Message "Rate limit hit, waiting 60 seconds..." -Level 'WARNING'
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data from $nextLink : $($_.Exception.Message)"
        }
    } while ($nextLink)

    return $allResults
}

function Import-DeviceCsv {
    param(
        [string]$Path,
        [string]$Content
    )

    try {
        if (-not [string]::IsNullOrWhiteSpace($Content)) {
            Write-Log -Message "Reading CSV content supplied at runtime" -Level 'INFO'
            $firstLine = $Content -split '\r?\n' | Select-Object -First 1
        }
        else {
            Write-Log -Message "Reading CSV file: $Path" -Level 'INFO'
            $firstLine = Get-Content -Path $Path -First 1
        }
        $delimiter = if ($firstLine -match ',') { ',' } else { ';' }

        Write-Verbose "Using delimiter: $delimiter"
        $csvData = if (-not [string]::IsNullOrWhiteSpace($Content)) {
            $Content | ConvertFrom-Csv -Delimiter $delimiter -ErrorAction Stop
        }
        else {
            Import-Csv -Path $Path -Delimiter $delimiter -ErrorAction Stop
        }

        if (-not $csvData) {
            throw "CSV file is empty or could not be read"
        }

        # Validate required columns
        $requiredColumn = "GroupName"
        $csvHeaders = $csvData[0].PSObject.Properties.Name

        if ($requiredColumn -notin $csvHeaders) {
            throw "CSV file must contain a '$requiredColumn' column"
        }

        # Check for at least one device identifier column
        $identifierColumns = @("DeviceName", "SerialNumber", "DeviceId")
        $hasIdentifier = $false
        foreach ($col in $identifierColumns) {
            if ($col -in $csvHeaders) {
                $hasIdentifier = $true
                break
            }
        }

        if (-not $hasIdentifier) {
            throw "CSV file must contain at least one device identifier column: DeviceName, SerialNumber, or DeviceId"
        }

        # Validate each row has at least one identifier
        $rowNumber = 1
        foreach ($row in $csvData) {
            $rowNumber++
            $hasValue = $false

            foreach ($col in $identifierColumns) {
                if ($row.PSObject.Properties.Name -contains $col -and -not [string]::IsNullOrWhiteSpace($row.$col)) {
                    $hasValue = $true
                    break
                }
            }

            if (-not $hasValue) {
                Write-Log -Message "Row $rowNumber has no device identifier (DeviceName, SerialNumber, or DeviceId)" -Level 'WARNING'
            }

            if ([string]::IsNullOrWhiteSpace($row.GroupName)) {
                Write-Log -Message "Row $rowNumber has no GroupName specified" -Level 'WARNING'
            }
        }

        Write-Log -Message "Successfully imported $($csvData.Count) rows from CSV" -Level 'SUCCESS'
        return $csvData
    }
    catch {
        throw "Failed to import CSV file: $($_.Exception.Message)"
    }
}

function Find-IntuneDevice {
    param(
        [object]$CsvRow,
        [array]$AllDevices
    )

    # Try DeviceId first (most precise)
    if (-not [string]::IsNullOrWhiteSpace($CsvRow.DeviceId)) {
        $device = $AllDevices | Where-Object { $_.azureADDeviceId -eq $CsvRow.DeviceId } | Select-Object -First 1
        if ($device) {
            return $device
        }
    }

    # Try SerialNumber next
    if (-not [string]::IsNullOrWhiteSpace($CsvRow.SerialNumber)) {
        $device = $AllDevices | Where-Object { $_.serialNumber -eq $CsvRow.SerialNumber } | Select-Object -First 1
        if ($device) {
            return $device
        }
    }

    # Try DeviceName last
    if (-not [string]::IsNullOrWhiteSpace($CsvRow.DeviceName)) {
        $device = $AllDevices | Where-Object { $_.deviceName -eq $CsvRow.DeviceName } | Select-Object -First 1
        if ($device) {
            return $device
        }
    }

    return $null
}

function Get-EntraIdDevice {
    param(
        [string]$AzureAdDeviceId
    )

    try {
        $filter = "deviceId eq '$AzureAdDeviceId'"
        $uri = "https://graph.microsoft.com/beta/devices?`$filter=$filter"
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET

        if ($response.value -and $response.value.Count -gt 0) {
            return $response.value[0]
        }

        return $null
    }
    catch {
        Write-Log -Message "Error looking up Entra ID device for Entra ID Device ID $AzureAdDeviceId : $($_.Exception.Message)" -Level 'WARNING'
        return $null
    }
}

function Get-EntraIdGroup {
    param(
        [string]$GroupName
    )

    try {
        $filter = "displayName eq '$GroupName'"
        $uri = "https://graph.microsoft.com/beta/groups?`$filter=$filter"
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET

        if ($response.value -and $response.value.Count -gt 0) {
            return $response.value[0]
        }

        return $null
    }
    catch {
        Write-Log -Message "Error looking up group '$GroupName': $($_.Exception.Message)" -Level 'WARNING'
        return $null
    }
}

function Test-DeviceInGroup {
    param(
        [string]$GroupId,
        [string]$DeviceId
    )

    try {
        if (-not $script:GroupMemberCache.ContainsKey($GroupId)) {
            $uri = "https://graph.microsoft.com/beta/groups/$GroupId/members?`$select=id"
            $members = Get-MgGraphAllPages -Uri $uri

            $memberIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($member in $members) {
                if ($member.id) {
                    [void]$memberIds.Add($member.id)
                }
            }
            $script:GroupMemberCache[$GroupId] = $memberIds
        }

        return $script:GroupMemberCache[$GroupId].Contains($DeviceId)
    }
    catch {
        Write-Log -Message "Error checking group membership: $($_.Exception.Message)" -Level 'WARNING'
        return $false
    }
}

function New-EntraIdGroup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$GroupName
    )

    if ($PSCmdlet.ShouldProcess($GroupName, "Create new Entra ID group")) {
        try {
            $mailNickname = $GroupName -replace '[^a-zA-Z0-9]', ''

            $groupBody = @{
                displayName     = $GroupName
                mailEnabled     = $false
                mailNickname    = $mailNickname
                securityEnabled = $true
                description     = "Device group created by Intune Automation"
            } | ConvertTo-Json -Depth 10

            $newGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/groups" -Method POST -Body $groupBody -ContentType "application/json"
            Write-Log -Message "Created group: $GroupName" -Level 'SUCCESS'
            return $newGroup
        }
        catch {
            Write-Error "Failed to create group '$GroupName': $($_.Exception.Message)"
            return $null
        }
    }

    return $null
}

function Add-DeviceToGroup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$GroupId,
        [string]$DeviceId,
        [string]$DeviceName,
        [string]$GroupName
    )

    if ($PSCmdlet.ShouldProcess("$DeviceName to $GroupName", "Add device to group")) {
        try {
            $addBody = @{
                "@odata.id" = "https://graph.microsoft.com/beta/directoryObjects/$DeviceId"
            } | ConvertTo-Json

            $uri = "https://graph.microsoft.com/beta/groups/$GroupId/members/`$ref"
            Invoke-MgGraphRequest -Uri $uri -Method POST -Body $addBody -ContentType "application/json"

            return $true
        }
        catch {
            Write-Log -Message "Failed to add device '$DeviceName' to group '$GroupName': $($_.Exception.Message)" -Level 'WARNING'
            return $false
        }
    }

    return $false
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode 'run' -Type 'General'
    Write-Banner
    Write-Output "Starting device-to-group assignment from CSV..."

    if ($DryRun) {
        Write-Output "[DRY RUN MODE] No changes will be made"
    }

    # Import CSV data
    $csvData = Import-DeviceCsv -Path $CsvPath -Content $CsvContent

    # Get all Intune managed devices
    Write-Output "Retrieving all Intune managed devices..."
    $allDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices"
    Write-Output "Found $($allDevices.Count) managed devices"

    # Track statistics
    $stats = @{
        TotalRows            = $csvData.Count
        DevicesFound         = 0
        DevicesNotFound      = 0
        GroupsProcessed      = 0
        GroupsCreated        = 0
        DevicesAdded         = 0
        DevicesSkipped       = 0
        Errors               = 0
    }

    # Group CSV rows by GroupName for efficient processing
    $groupedData = $csvData | Group-Object -Property GroupName

    # Check which groups exist
    Write-Output "Checking group existence..."
    $groupCache = @{}
    $script:GroupMemberCache = @{}
    $missingGroups = @()

    foreach ($groupData in $groupedData) {
        $groupName = $groupData.Name

        if ([string]::IsNullOrWhiteSpace($groupName)) {
            continue
        }

        $group = Get-EntraIdGroup -GroupName $groupName

        if ($group) {
            $groupCache[$groupName] = $group
            Write-Verbose "Group exists: $groupName"
        }
        else {
            $missingGroups += $groupName
            Write-Verbose "Group not found: $groupName"
        }
    }

    # Handle missing groups
    if ($missingGroups.Count -gt 0) {
        Write-Output "`nThe following groups do not exist:"
        foreach ($groupName in $missingGroups) {
            Write-Output "  - $groupName"
        }

        if ($DryRun) {
            Write-Output "`n[DRY RUN] Would need to create $($missingGroups.Count) groups"
        }
        else {
            $shouldCreate = $CreateMissingGroups

            if (-not $shouldCreate -and -not $Force) {
                $response = Read-Host "`nDo you want to create these $($missingGroups.Count) missing groups? (Y/N)"
                $shouldCreate = $response -match '^[Yy]'
            }

            if ($shouldCreate) {
                Write-Output "Creating missing groups..."
                foreach ($groupName in $missingGroups) {
                    $newGroup = New-EntraIdGroup -GroupName $groupName
                    if ($newGroup) {
                        $groupCache[$groupName] = $newGroup
                        $stats.GroupsCreated++
                    }
                    else {
                        $stats.Errors++
                    }
                }
            }
            else {
                Write-Log -Message "Groups will not be created. Devices targeting missing groups will be skipped." -Level 'WARNING'
            }
        }
    }

    # Process each row in the CSV
    Write-Output "`nProcessing device assignments..."
    $processedCount = 0

    foreach ($row in $csvData) {
        $processedCount++
        
            Write-Progress -Activity "Processing CSV rows" -Status "$processedCount of $($csvData.Count)" -PercentComplete (($processedCount / $csvData.Count) * 100)
        

        $groupName = $row.GroupName

        if ([string]::IsNullOrWhiteSpace($groupName)) {
            Write-Log -Message "Row ${processedCount}: No group name specified, skipping" -Level 'WARNING'
            $stats.Errors++
            continue
        }

        # Check if group exists in cache
        if (-not $groupCache.ContainsKey($groupName)) {
            Write-Log -Message "Row ${processedCount}: Group '$groupName' not found and not created, skipping" -Level 'WARNING'
            $stats.Errors++
            continue
        }

        $group = $groupCache[$groupName]

        # Find the device
        $device = Find-IntuneDevice -CsvRow $row -AllDevices $allDevices

        if (-not $device) {
            $identifier = if (-not [string]::IsNullOrWhiteSpace($row.DeviceId)) { "DeviceId: $($row.DeviceId)" }
            elseif (-not [string]::IsNullOrWhiteSpace($row.SerialNumber)) { "SerialNumber: $($row.SerialNumber)" }
            elseif (-not [string]::IsNullOrWhiteSpace($row.DeviceName)) { "DeviceName: $($row.DeviceName)" }
            else { "Unknown" }

            Write-Log -Message "Row $processedCount : Device not found ($identifier)" -Level 'WARNING'
            $stats.DevicesNotFound++
            continue
        }

        $stats.DevicesFound++

        # Get Entra ID device object
        $entraDevice = Get-EntraIdDevice -AzureAdDeviceId $device.azureADDeviceId

        if (-not $entraDevice) {
            Write-Log -Message "Row $processedCount : Device '$($device.deviceName)' not found in Entra ID" -Level 'WARNING'
            $stats.Errors++
            continue
        }

        # Check if device is already in the group
        $isInGroup = Test-DeviceInGroup -GroupId $group.id -DeviceId $entraDevice.id

        if ($isInGroup) {
            Write-Verbose "Device '$($device.deviceName)' is already in group '$groupName', skipping"
            $stats.DevicesSkipped++
            continue
        }

        # Add device to group
        if ($DryRun) {
            Write-Output "[DRY RUN] Would add device '$($device.deviceName)' to group '$groupName'"
            $stats.DevicesAdded++
        }
        else {
            $success = Add-DeviceToGroup -GroupId $group.id -DeviceId $entraDevice.id -DeviceName $device.deviceName -GroupName $groupName

            if ($success) {
                Write-Output "Added device '$($device.deviceName)' to group '$groupName'"
                if ($script:GroupMemberCache.ContainsKey($group.id)) {
                    [void]$script:GroupMemberCache[$group.id].Add($entraDevice.id)
                }
                $stats.DevicesAdded++
            }
            else {
                $stats.Errors++
            }
        }

        # Small delay to avoid rate limiting
        Start-Sleep -Milliseconds 100
    }

    
        Write-Progress -Activity "Processing CSV rows" -Completed
    

    # Display summary
    Write-Output "`n========================================"
    Write-Output "DEVICE-TO-GROUP ASSIGNMENT SUMMARY"
    Write-Output "========================================"
    Write-Output "CSV rows processed: $($stats.TotalRows)"
    Write-Output "Devices found in Intune: $($stats.DevicesFound)"
    Write-Output "Devices not found: $($stats.DevicesNotFound)"
    Write-Output "Groups created: $($stats.GroupsCreated)"
    Write-Output "Devices added to groups: $($stats.DevicesAdded)"
    Write-Output "Devices skipped (already in group): $($stats.DevicesSkipped)"
    Write-Output "Errors: $($stats.Errors)"
    Write-Output "========================================"

    if ($DryRun) {
        Write-Output "`n[DRY RUN] No changes were made"
    }

    Write-Output "`nScript completed successfully"
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    try {
        Disconnect-MgGraph | Out-Null
        Write-Output "Disconnected from Microsoft Graph"
    }
    catch {
        Write-Verbose "Graph disconnection completed"
    }
}
