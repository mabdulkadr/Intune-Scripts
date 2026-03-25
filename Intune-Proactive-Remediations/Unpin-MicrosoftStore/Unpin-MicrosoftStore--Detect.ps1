<#
.SYNOPSIS
    Checks whether Microsoft Store still exposes an Unpin from taskbar action.

.DESCRIPTION
    This detection script opens the AppsFolder shell namespace through
    `Shell.Application`, locates the Microsoft Store app item, enumerates its
    verbs, and checks whether the taskbar unpin action is available.

    Exit codes:
    - Exit 0: Store is not detected as pinned
    - Exit 1: Store appears to be pinned and can be unpinned

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Unpin-MicrosoftStore--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Unpin-MicrosoftStore--Detect.ps1'
$SolutionName = 'Unpin-MicrosoftStore'
$ScriptMode   = 'Detection'

$AppsFolderNamespace = 'shell:::{4234d49b-0245-4df3-b780-3893943456e1}'
$TargetAppName       = 'Microsoft Store'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Unpin-MicrosoftStore--Detect.txt'
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

    return $folder.Items() | Where-Object { $_.Name -eq $TargetAppName } | Select-Object -First 1
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
        Finish-Script -Message 'Compliant: Microsoft Store shell item was not found.' -ExitCode 0 -Level 'SUCCESS'
    }

    $unpinVerb = Get-UnpinVerb -ShellItem $storeItem
    if (-not $unpinVerb) {
        Finish-Script -Message 'Compliant: Microsoft Store does not expose an unpin taskbar action.' -ExitCode 0 -Level 'SUCCESS'
    }

    Finish-Script -Message 'Non-Compliant: Microsoft Store appears to be pinned to the taskbar.' -ExitCode 1 -Level 'WARNING'
}
catch {
    Finish-Script -Message ("Detection failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
