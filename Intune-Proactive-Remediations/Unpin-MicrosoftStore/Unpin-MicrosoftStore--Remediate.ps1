<#
.SYNOPSIS
    Invokes the shell verb that removes Microsoft Store from the taskbar.

.DESCRIPTION
    This remediation script opens the AppsFolder shell namespace through
    `Shell.Application`, resolves the Microsoft Store app item, finds the
    shell verb that removes it from the taskbar, and invokes that verb.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Unpin-MicrosoftStore--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Unpin-MicrosoftStore--Remediate.ps1'
$SolutionName = 'Unpin-MicrosoftStore'
$ScriptMode   = 'Remediation'

$AppsFolderNamespace = 'shell:::{4234d49b-0245-4df3-b780-3893943456e1}'
$TargetAppPattern    = '*store*'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Unpin-MicrosoftStore--Remediate.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

function Initialize-Log {
    if (-not (Test-Path -Path $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
}

function Write-Banner {
    Write-Host ''
    Write-Host $BannerLine -ForegroundColor DarkGray
    Write-Host ("{0} | {1}" -f $SolutionName, $ScriptMode) -ForegroundColor White
    Write-Host $BannerLine -ForegroundColor DarkGray
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '{0} | {1,-7} | {2}' -f $timestamp, $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    Write-Log -Message $Message -Level $Level
    Write-Output $Message
    exit $ExitCode
}

function Get-StoreShellItem {
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.NameSpace($AppsFolderNamespace)
    if (-not $folder) {
        throw 'Unable to open the AppsFolder shell namespace.'
    }

    return $folder.Items() | Where-Object { $_.Name -like $TargetAppPattern } | Select-Object -First 1
}

function Get-UnpinVerb {
    param(
        [Parameter(Mandatory = $true)]
        $ShellItem
    )

    $verbs = @($ShellItem.Verbs())
    foreach ($verb in $verbs) {
        $name = ($verb.Name -replace '&', '').Trim()
        if ($name -match 'Unpin.+taskbar' -or $name -match 'إلغاء.+شريط المهام') {
            return $verb
        }
    }

    return $null
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message 'Resolving Microsoft Store shell item.'

    $storeItem = Get-StoreShellItem
    if (-not $storeItem) {
        Finish-Script -Message 'Microsoft Store shell item was not found. Nothing to remediate.' -ExitCode 0 -Level 'SUCCESS'
    }

    $unpinVerb = Get-UnpinVerb -ShellItem $storeItem
    if (-not $unpinVerb) {
        Finish-Script -Message 'Microsoft Store does not expose an unpin taskbar action. Nothing to remediate.' -ExitCode 0 -Level 'SUCCESS'
    }

    Write-Log -Message 'Invoking Microsoft Store unpin taskbar action.'
    $unpinVerb.DoIt()

    Finish-Script -Message 'Microsoft Store was unpinned from the taskbar successfully.' -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
