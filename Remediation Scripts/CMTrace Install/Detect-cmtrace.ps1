<#
.SYNOPSIS
    Detects if CMTrace is installed on the system.

.DESCRIPTION
    This script checks if the CMTrace executable is present at the specified path. 
    If found, it outputs "Compliant" and exits with code 0. If not found, it outputs "Not Compliant" and exits with code 1.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04
#>

# Define the path to CMTrace
$Path = "C:\Windows\System32\CMTrace.exe"

# Function for logging messages
function Log-Message {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] [$Type] $Message"
}

# Start of script execution
Log-Message "Starting CMTrace compliance check."

Try {
    # Check if the CMTrace executable exists
    Log-Message "Checking for the presence of CMTrace at $Path."
    $check = Test-Path -Path $Path -ErrorAction Stop

    if ($check -eq $true) {
        Log-Message "CMTrace found. System is compliant."
        Write-Output "Compliant"
        Exit 0
    } else {
        Log-Message "CMTrace not found. System is not compliant." "WARNING"
        Write-Warning "Not Compliant"
        Exit 1
    }
} Catch {
    # Handle any unexpected errors
    Log-Message "An error occurred during compliance check: $_" "ERROR"
    Write-Warning "Not Compliant"
    Exit 1
} Finally {
    Log-Message "CMTrace compliance check completed."
}
