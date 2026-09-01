<#
.TITLE
    Detection - BitLocker Encryption Method Custom Compliance

.SYNOPSIS
    Discovery script for Intune Custom Compliance (BitLocker Encryption Method).

.DESCRIPTION
    Returns JSON with BitLocker encryption method for Custom Compliance policies.
    Checks all BitLocker volumes for XTS-AES 128 (value 6) or XTS-AES 256 (value 7)
    per Microsoft hardening guidance. Used as a discovery script in
    Devices > Compliance > Scripts (Custom Compliance).

    Output JSON example:
    {"BitLockerEncryptionMethod":"XTS-AES 256","Compliant":true}

    Exit contract:
    Always exits 0 (discovery scripts must not exit 1); compliance is evaluated by the JSON rules.

.TAGS
    Compliance,Discovery,BitLocker,Encryption

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads BitLocker WMI.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; BitLocker XTS-AES discovery for Custom Compliance.

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\Get-BitlockerEncryptionMethodCompliance.ps1
    Outputs JSON for Custom Compliance.

.NOTES
    - Runs in SYSTEM context as discovery script.
    - JSON file: Bitlocker-EncryptionMethod.json defines compliance rule (Compliant must be true).
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    $volumes = Get-BitLockerVolume -ErrorAction SilentlyContinue | Where-Object { $_.VolumeType -eq 'OperatingSystem' }
    $result = @{
        BitLockerEncryptionMethod = "NotEncrypted"
        Compliant                 = $false
        Details                   = @()
    }

    if (-not $volumes -or @($volumes).Count -eq 0) {
        $result.Details += "No OS volume BitLocker data found"
    } else {
        foreach ($vol in $volumes) {
            $method = $vol.EncryptionMethod
            $methodName = switch ($method) {
                'Aes128'        { 'AES 128' }
                'Aes256'        { 'AES 256' }
                'XtsAes128'     { 'XTS-AES 128' }
                'XtsAes256'     { 'XTS-AES 256' }
                default         { "$method" }
            }
            $isCompliant = ($method -in @('XtsAes128', 'XtsAes256', 6, 7))
            # Numeric fallback: 6 = XTS-AES 128, 7 = XTS-AES 256
            if ($method -is [int] -and $method -in @(6, 7)) { $isCompliant = $true; $methodName = if ($method -eq 6) { 'XTS-AES 128' } else { 'XTS-AES 256' } }

            $result.BitLockerEncryptionMethod = $methodName
            $result.Compliant = $isCompliant
            $result.Details += "Volume $($vol.MountPoint): $methodName (Compliant=$isCompliant)"
        }
    }

    $result | ConvertTo-Json -Compress | Write-Output
    exit 0
}
catch {
    @{ BitLockerEncryptionMethod = "Error"; Compliant = $false; Error = $_.Exception.Message } | ConvertTo-Json -Compress | Write-Output
    exit 0
}
