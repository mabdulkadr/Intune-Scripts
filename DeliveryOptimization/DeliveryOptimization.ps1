<#
.SYNOPSIS
    Enhanced Delivery Optimization troubleshooting script with advanced features.

.DESCRIPTION
    A comprehensive script to troubleshoot and verify Delivery Optimization settings, services, ports, endpoints,
    bandwidth policies, caching policies, and overall network configuration.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Date    : 2024-12-16
#>

# Function to display section headers
function Write-Header {
    param ([string]$Message)
    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "$Message"
    Write-Host "------------------------------------------------------------"
}

# Function to check Delivery Optimization service
function Check-DOService {
    Write-Header "Checking Delivery Optimization Service (DoSvc)"
    try {
        $Service = Get-Service -Name DoSvc -ErrorAction Stop
        if ($Service.Status -eq "Running") {
            Write-Host "Delivery Optimization service is running." -ForegroundColor Green
        } else {
            Write-Host "Delivery Optimization service is NOT running. Attempting to start..." -ForegroundColor Yellow
            Start-Service -Name DoSvc
            Write-Host "Delivery Optimization service started successfully." -ForegroundColor Green
        }
    } catch {
        Write-Host "Error checking or starting Delivery Optimization service: $_" -ForegroundColor Red
    }
}

# Function to test Delivery Optimization ports
function Test-DOPorts {
    Write-Header "Testing Delivery Optimization Required Ports"
    $Ports = @(
        @{ Name = "TCP - 7680 (P2P)"; Port = 7680; Protocol = "TCP" },
        @{ Name = "UDP - 3544 (Teredo)"; Port = 3544; Protocol = "UDP" },
        @{ Name = "TCP - 443 (HTTPS)"; Port = 443; Protocol = "TCP" }
    )

    foreach ($Port in $Ports) {
        Write-Host "Testing $($Port.Name)..." -ForegroundColor White
        if ($Port.Protocol -eq "TCP") {
            $Result = Test-NetConnection -ComputerName "www.microsoft.com" -Port $Port.Port
            if ($Result.TcpTestSucceeded) {
                Write-Host "$($Port.Name) is reachable and functional." -ForegroundColor Green
            } else {
                Write-Host "$($Port.Name) is NOT reachable. Check firewall or network configuration." -ForegroundColor Red
            }
        } elseif ($Port.Protocol -eq "UDP") {
            Write-Host "Testing UDP Port 3544 (Teredo NAT Traversal)..." -ForegroundColor Yellow
            Check-TeredoStatus
        }
    }
}

# Function to check Teredo status and automatically fix it
function Check-TeredoStatus {
    Write-Header "Checking Teredo Status (UDP Port 3544)"
    try {
        $TeredoState = netsh interface teredo show state | Select-String "State"
        if ($TeredoState -match "qualified") {
            Write-Host "Teredo is enabled and in a qualified state." -ForegroundColor Green
        } else {
            Write-Host "Teredo is NOT in a qualified state. Attempting to enable it..." -ForegroundColor Yellow
            netsh interface teredo set state enterpriseclient
            Write-Host "Teredo has been enabled. Verify its status by rerunning this script." -ForegroundColor Green
        }
    } catch {
        Write-Host "Error checking Teredo status: $_" -ForegroundColor Red
    }
}

# Function to check Delivery Optimization jobs
function Check-DOJobs {
    Write-Header "Checking Delivery Optimization Jobs"
    try {
        $Jobs = Get-DeliveryOptimizationStatus | Where-Object { $_.State -eq "Downloading" -or $_.State -eq "Uploading" }
        if ($Jobs) {
            Write-Host "Active Delivery Optimization jobs found:" -ForegroundColor Green
            $Jobs | Format-Table -AutoSize
        } else {
            Write-Host "No active Delivery Optimization jobs." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error retrieving Delivery Optimization jobs: $_" -ForegroundColor Red
    }
}

# Function to test connectivity to Microsoft endpoints
function Test-DOEndpoints {
    Write-Header "Testing Connectivity to Microsoft Delivery Optimization Endpoints"
    $Endpoints = @(
        "http://download.microsoft.com",
        "http://tlu.dl.delivery.mp.microsoft.com",
        "http://geo.delivery.mp.microsoft.com",
        "http://*.do.dsp.mp.microsoft.com"
    )

    foreach ($Endpoint in $Endpoints) {
        Write-Host "Testing connection to $Endpoint..." -ForegroundColor White
        try {
            Invoke-WebRequest -Uri $Endpoint -UseBasicParsing -TimeoutSec 10 | Out-Null
            Write-Host "Successfully connected to $Endpoint." -ForegroundColor Green
        } catch {
            Write-Host "Failed to connect to $Endpoint : $_" -ForegroundColor Red
        }
    }
}

# Function to check Delivery Optimization bandwidth policies
function Check-DOBandwidth {
    Write-Header "Checking Delivery Optimization Bandwidth Policies"
    try {
        $DOGroupPolicy = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -ErrorAction Stop
        Write-Host "Bandwidth Policy Settings:" -ForegroundColor Green
        $DOGroupPolicy | Format-Table -AutoSize
    } catch {
        Write-Host "No Delivery Optimization bandwidth policies found. Default settings may be in use." -ForegroundColor Yellow
    }
}

# Function to test general network connectivity
function Check-NetworkConnectivity {
    Write-Header "Checking General Network Connectivity"
    try {
        $PingTest = Test-Connection -ComputerName "8.8.8.8" -Count 3 -Quiet
        if ($PingTest) {
            Write-Host "General network connectivity is healthy." -ForegroundColor Green
        } else {
            Write-Host "General network connectivity is unavailable. Check your internet connection." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error testing general network connectivity: $_" -ForegroundColor Red
    }
}

# Function to check firewall rules
function Check-FirewallRules {
    Write-Header "Checking Firewall Rules for Delivery Optimization"
    try {
        $Rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*Delivery Optimization*" }
        if ($Rules) {
            Write-Host "Delivery Optimization firewall rules found:" -ForegroundColor Green
            $Rules | Format-Table -AutoSize
        } else {
            Write-Host "No firewall rules found for Delivery Optimization. Check your firewall configuration." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error retrieving firewall rules: $_" -ForegroundColor Red
    }
}

# Main Execution
Write-Header "Starting Comprehensive Delivery Optimization Troubleshooting"
Check-DOService
Check-DOJobs
Test-DOPorts
Check-TeredoStatus
Test-DOEndpoints
Check-DOBandwidth
Check-NetworkConnectivity
Check-FirewallRules
Write-Header "Delivery Optimization Troubleshooting Completed"
