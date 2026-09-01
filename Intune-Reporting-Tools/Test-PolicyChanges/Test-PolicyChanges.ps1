<#
.TITLE
    Policy Changes Monitor

.SYNOPSIS
    Monitor and report on recent changes to Policies in Microsoft Intune.

.DESCRIPTION
    This script connects to Microsoft Graph and retrieves recent changes to Policies
    configured in Intune. It checks audit logs for policy modifications, creations, deletions, and
    assignments within a specified time period. The script generates detailed reports in CSV format,
    highlighting policy changes with details about who made the changes, when they occurred, and
    what was modified. This helps administrators track configuration drift and maintain governance
    over device configuration policies.

    Supports interactive sign-in and unattended app-only via -TenantId/-ClientId.

.TAGS
    Monitoring

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementApps.Read.All,Mail.Send

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.4.1

.CHANGELOG
    1.4.1 (2026-08-26) - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.4 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.3 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.2 - Audit log filter timestamp is now built from UTC; severity check on activityResult is now case-insensitive (Graph returns "Success"/"Failure" capitalized); output directory is created automatically before the CSV export; pagination helper keeps single-item results as arrays
    1.1 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing)
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Test-PolicyChanges.ps1
    Generates a report of policy changes from the last 30 days

.EXAMPLE
    .\Test-PolicyChanges.ps1 -DaysBack 30 -OutputPath "C:\Reports"
    Generates a report of policy changes from the last 30 days and saves to specified directory

.EXAMPLE
    .\Test-PolicyChanges.ps1 -OnlyShowChanges "true" -SendEmailAlert "true" -AlertEmailAddress "<recipient-address>" -SenderUPN "<sender-upn>"
    Shows only modified policies and sends email alerts for changes

.NOTES
    - Requires Microsoft.Graph.Authentication module: Install-Module Microsoft.Graph.Authentication
    - Requires appropriate permissions in Entra ID
    - Email alerts require Mail.Send and a runtime-supplied SenderUPN and recipient address
    - Policies use modern configuration templates
    - Policies require beta Graph endpoint access
    - Audit data is available for up to 30 days by default
    - Critical for maintaining configuration governance and compliance
    - Monitor for unauthorized changes to security policies
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
    - Logs: %ProgramData%\check-policy-changes\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Number of days to look back for changes")]
    [ValidateRange(1, 90)]
    [int]$DaysBack = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Directory path to save reports")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Only show policies with changes")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$OnlyShowChanges,

    [Parameter(Mandatory = $false, HelpMessage = "Send email alert for policy changes")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$SendEmailAlert,

    [Parameter(Mandatory = $false, HelpMessage = "Email address to send alerts to")]
    [string]$AlertEmailAddress = "",

    [Parameter(Mandatory = $false, HelpMessage = "Mailbox UPN used to send alerts")]
    [string]$SenderUPN = "",

    [Parameter(Mandatory = $false, HelpMessage = "Include detailed change information")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$IncludeDetails,

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
# CONFIGURATION - solution identity and script-relative path anchoring.
# ============================================================================

$SolutionName = 'check-policy-changes'
$ScriptMode   = 'run'

$scriptBasePath = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path -Path $scriptBasePath -ChildPath $OutputPath
}

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

# Normalize the module-install override parameter.
$forceModuleInstallRaw = [string]$ForceModuleInstall
Remove-Variable -Name ForceModuleInstall -ErrorAction SilentlyContinue
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

# Normalize boolean string parameters so
# workstation execution uses consistent boolean types.
foreach ($boolParamName in @('OnlyShowChanges', 'SendEmailAlert', 'IncludeDetails')) {
    $boolRaw = [string](Get-Variable -Name $boolParamName -ValueOnly)
    Remove-Variable -Name $boolParamName -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($boolRaw)) {
        Set-Variable -Name $boolParamName -Value $false
        continue
    }

    switch ($boolRaw.Trim().ToLowerInvariant()) {
        { $_ -in @("true", "1", '$true') } {
            Set-Variable -Name $boolParamName -Value $true
        }
        { $_ -in @("false", "0", '$false') } {
            Set-Variable -Name $boolParamName -Value $false
        }
        default {
            throw "Parameter '$boolParamName' accepts only true, false, 1, 0, $true, or $false."
        }
    }
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
            Write-Information "Module '$ModuleName' not found. Installing..." -InformationAction Continue
            if (-not $ForceInstall) {
                $response = Read-Host "Install module '$ModuleName'? (Y/N)"
                if ($response -notmatch '^[Yy]') {
                    throw "Module '$ModuleName' is required but installation was declined."
                }
            }
            try {
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }
                Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                Write-Information "[OK] Successfully installed '$ModuleName'" -InformationAction Continue
            }
            catch {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }
        try {
            Import-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Verbose "[OK] Successfully imported '$ModuleName'"
        }
        catch {
            throw "Failed to import module '$ModuleName': $($_.Exception.Message)"
        }
    }
}

# ============================================================================
# ENVIRONMENT AND MODULES - Workstation only
# ============================================================================

$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "MgGraphCommunity"
)

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "[OK] All required modules are available"
}
catch {
    Write-Error "Module initialization failed: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# AUTHENTICATION - Workstation (interactive) and unattended app-only
# ============================================================================

try {
    if ($TenantId -and $ClientId -and $ClientSecret) {
        Write-Output "Connecting to Microsoft Graph with client secret..."
        $secureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $secureSecret -NoWelcome -ErrorAction Stop
        Write-Output "[OK] Successfully connected to Microsoft Graph"
    }
    elseif ($TenantId -and $ClientId -and $CertificateThumbprint) {
        Write-Output "Connecting to Microsoft Graph with certificate..."
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        Write-Output "[OK] Successfully connected to Microsoft Graph"
    }
    else {
        Write-Output "Connecting to Microsoft Graph with interactive authentication..."
        $Scopes = @(
            "DeviceManagementApps.Read.All",
            "Mail.Send"
        )
        if (Get-Command -Name Connect-MgGraphCommunity -ErrorAction SilentlyContinue) {
            Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        else {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        Write-Output "[OK] Successfully connected to Microsoft Graph"
    }
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}
# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Function to get all pages of results from Graph API
function Get-MgGraphAllPages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [int]$DelayMs = 100
    )

    $AllResults = @()
    $NextLink = $Uri
    $RequestCount = 0

    do {
        try {
            # Add delay to respect rate limits
            if ($RequestCount -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }

            $Response = Invoke-MgGraphRequest -Uri $NextLink -Method GET
            $RequestCount++

            if ($null -ne $Response.value) {
                $AllResults += $Response.value
            }
            else {
                $AllResults += $Response
            }

            $NextLink = $Response.'@odata.nextLink'
        }
        catch {
            if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*throttled*") {
                Write-Information "`nRate limit hit, waiting 60 seconds..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data from $NextLink : $($_.Exception.Message)"
        }
    } while ($NextLink)

    # Comma prevents unrolling so single-element results stay arrays
    return , $AllResults
}

# Function to format change details
function Format-ChangeDetail {
    param(
        [object]$AuditLog
    )

    $ChangeDetails = @()

    if ($AuditLog.resources) {
        foreach ($Resource in $AuditLog.resources) {
            if ($Resource.modifiedProperties) {
                foreach ($Property in $Resource.modifiedProperties) {
                    $ChangeDetail = [PSCustomObject]@{
                        PropertyName = $Property.displayName
                        OldValue     = if ($Property.oldValue) { $Property.oldValue -replace "`n", " " } else { "N/A" }
                        NewValue     = if ($Property.newValue) { $Property.newValue -replace "`n", " " } else { "N/A" }
                    }
                    $ChangeDetails += $ChangeDetail
                }
            }
        }
    }

    return $ChangeDetails
}

# Function to determine change severity
function Get-ChangeSeverity {
    param(
        [string]$Activity,
        [string]$Result
    )

    # Graph returns "Success"/"Failure" capitalized; normalize so casing never matters
    if ($Result.ToLower() -eq "failure") {
        return "High"
    }

    switch -Wildcard ($Activity) {
        "*Delete*" { return "High" }
        "*Create*" { return "Medium" }
        "*Update*" { return "Medium" }
        "*Assign*" { return "Low" }
        default { return "Low" }
    }
}

function Send-PolicyChangeEmail {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Changes,

        [Parameter(Mandatory = $true)]
        [string]$RecipientAddresses,

        [Parameter(Mandatory = $true)]
        [string]$SenderUserPrincipalName
    )

    $toRecipients = @(
        $RecipientAddresses -split '[,;]' |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object {
                try {
                    $validatedAddress = [System.Net.Mail.MailAddress]::new($_).Address
                }
                catch {
                    throw "Invalid alert email address '$_'."
                }

                @{ emailAddress = @{ address = $validatedAddress } }
            }
    )
    if ($toRecipients.Count -eq 0) {
        throw "At least one alert email address is required."
    }

    $changeLines = @(
        $Changes | Select-Object -First 10 | ForEach-Object {
            "$($_.DateTime): $($_.PolicyName) - $($_.Action) by $($_.User)"
        }
    )
    $bodyText = @"
Policy Changes Report

Time period: Last $DaysBack days
Total changes: $($Changes.Count)

Recent changes:
$($changeLines -join [Environment]::NewLine)

Review the Intune audit log for full details.
"@
    $payload = @{
        message = @{
            subject = "Policy Changes Alert - $($Changes.Count) changes detected"
            body = @{
                contentType = "Text"
                content = $bodyText
            }
            toRecipients = $toRecipients
        }
        saveToSentItems = $true
    }

    $encodedSender = [uri]::EscapeDataString($SenderUserPrincipalName)
    $mailUri = "https://graph.microsoft.com/beta/users/$encodedSender/sendMail"
    Invoke-MgGraphRequest -Uri $mailUri -Method POST -Body ($payload | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction Stop | Out-Null
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner

    Write-Output "Starting Policies changes analysis..."

    # Calculate start date in UTC so the filter matches Graph timestamps
    $StartDate = (Get-Date).ToUniversalTime().AddDays(-$DaysBack)
    $StartDateFormatted = $StartDate.ToString("yyyy-MM-ddTHH:mm:ssZ")

    Write-Output "Analyzing changes from: $($StartDate.ToString('yyyy-MM-dd HH:mm:ss'))"

    # ========================================================================
    # GET AUDIT LOGS FOR SETTINGS CATALOG CHANGES
    # ========================================================================

    Write-Output "Retrieving audit logs for Policies changes..."

    try {
        # Query for Policies changes (DeviceConfiguration category)
        $AuditLogsUri = "https://graph.microsoft.com/beta/deviceManagement/auditEvents?`$filter=activityDateTime ge $StartDateFormatted and category eq 'DeviceConfiguration'&`$orderby=activityDateTime desc&`$top=50"
        $AuditLogs = Get-MgGraphAllPages -Uri $AuditLogsUri

        Write-Output "Retrieved $($AuditLogs.Count) DeviceConfiguration audit events"

        # Filter for Policies (DeviceManagementConfigurationPolicy) activities
        $PoliciesActivities = $AuditLogs | Where-Object {
            $_.activityType -like "*DeviceManagementConfigurationPolicy*"
        }

        Write-Output "[OK] Found $($PoliciesActivities.Count) policy changes"
    }
    catch {
        throw "Failed to retrieve audit logs: $($_.Exception.Message)"
    }

    # ========================================================================
    # FILTER AND PROCESS CHANGES
    # ========================================================================

    Write-Output "Processing Policies policy changes..."

    # Filter changes if OnlyShowChanges is specified
    if ($OnlyShowChanges) {
        $PoliciesActivities = $PoliciesActivities | Where-Object {
            $_.activityType -like "*Update*" -or $_.activityType -like "*Modify*"
        }
        Write-Output "Filtered to show only policy modifications: $($PoliciesActivities.Count) changes"
    }

    # Get the last 5 changes
    $Last5Changes = $PoliciesActivities | Select-Object -First 5

    if ($Last5Changes.Count -eq 0) {
        Write-Output "No Policies policy changes found in the specified time period."
        return
    }

    Write-Output "`n========================================"
    Write-Output "LAST 5 POLICIES POLICY CHANGES"
    Write-Output "========================================"

    # Prepare CSV data for export
    $CsvData = @()

    $ChangeNumber = 1
    foreach ($Change in $Last5Changes) {
        try {
            # Get policy name and user info
            $PolicyName = "Unknown Policy"
            $UserName = "System"

            if ($Change.resources -and $Change.resources.Count -gt 0) {
                $PolicyName = $Change.resources[0].displayName
            }

            if ($Change.actor -and $Change.actor.userPrincipalName) {
                $UserName = $Change.actor.userPrincipalName
            }

            Write-Output "`n[$ChangeNumber] $($Change.activityDateTime)"
            Write-Output "Policy: $PolicyName"
            Write-Output "Action: $($Change.activityType)"
            Write-Output "User: $UserName"
            Write-Output "Result: $($Change.activityResult)"

            # Collect change details for CSV export
            $ChangeDetails = ""
            $Severity = Get-ChangeSeverity -Activity $Change.activityType -Result $Change.activityResult

            # Show modified properties (before/after values)
            if ($Change.resources -and $Change.resources[0].modifiedProperties) {
                Write-Output "Changes:"
                $ChangeDetailsList = @()
                foreach ($Property in $Change.resources[0].modifiedProperties) {
                    $OldValue = if ($Property.oldValue) { $Property.oldValue } else { "(empty)" }
                    $NewValue = if ($Property.newValue) { $Property.newValue } else { "(empty)" }
                    Write-Output "  - $($Property.displayName): '$OldValue' -> '$NewValue'"

                    if ($IncludeDetails) {
                        $ChangeDetailsList += "$($Property.displayName): '$OldValue' -> '$NewValue'"
                    }
                }
                $ChangeDetails = $ChangeDetailsList -join "; "
            }
            else {
                Write-Output "  No detailed change information available"
            }

            # Add to CSV data
            $CsvRecord = [PSCustomObject]@{
                DateTime   = $Change.activityDateTime
                PolicyName = $PolicyName
                Action     = $Change.activityType
                User       = $UserName
                Result     = $Change.activityResult
                Severity   = $Severity
                Details    = if ($IncludeDetails) { $ChangeDetails } else { "" }
            }
            $CsvData += $CsvRecord

            $ChangeNumber++
        }
        catch {
            Write-Warning "Error processing change: $($_.Exception.Message)"
            continue
        }
    }

    # ========================================================================
    # EXPORT TO CSV
    # ========================================================================

    if ($CsvData.Count -gt 0) {
        # Create output directory if it does not exist
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
            Write-Output "Created output directory: $OutputPath"
        }

        $OutputFile = Join-Path -Path $OutputPath -ChildPath "PolicyChanges_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        try {
            $CsvData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
            Write-Output "[OK] Report exported to: $OutputFile"
        }
        catch {
            Write-Warning "Failed to export CSV report: $($_.Exception.Message)"
        }
    }

    # ========================================================================
    # EMAIL ALERTS
    # ========================================================================

    if ($SendEmailAlert) {
        if ([string]::IsNullOrWhiteSpace($AlertEmailAddress)) {
            throw "AlertEmailAddress is required when SendEmailAlert is enabled."
        }
        if ([string]::IsNullOrWhiteSpace($SenderUPN)) {
            throw "SenderUPN is required when SendEmailAlert is enabled."
        }

        if ($CsvData.Count -gt 0) {
            Send-PolicyChangeEmail -Changes $CsvData -RecipientAddresses $AlertEmailAddress -SenderUserPrincipalName $SenderUPN
            Write-Output "[OK] Policy change email sent."
        }
        else {
            Write-Output "No policy changes detected. Email alert was not sent."
        }
    }

    Write-Output "`n[OK] Policies changes analysis completed successfully"
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Cleanup operations
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        Write-Output "Disconnected from Microsoft Graph"
    }
    catch {
        Write-Warning "Failed to disconnect from Microsoft Graph: $($_.Exception.Message)"
    }
}

# ============================================================================
# SCRIPT SUMMARY
# ============================================================================

Write-Output "
========================================
Script Execution Summary
========================================
Script: Policies Changes Monitor
Time Period: Last $DaysBack days
Status: Completed
========================================
"
