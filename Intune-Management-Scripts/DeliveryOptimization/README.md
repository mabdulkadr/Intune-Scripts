
# Delivery Optimization Troubleshooting Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Description
This PowerShell script provides a comprehensive tool to troubleshoot and verify the functionality of **Delivery Optimization (DO)** on Windows devices. It checks key components such as the DO service, required ports, bandwidth and caching policies, endpoint connectivity, and network settings, ensuring compliance with organizational configurations.

The script also includes automated fixes, such as enabling Teredo and providing actionable insights for resolving common issues.

---

## Features

1. **Delivery Optimization Service Check**
   - Verifies if the `DoSvc` service is running and starts it if necessary.

2. **Active DO Jobs Check**
   - Displays current download or upload jobs managed by Delivery Optimization.

3. **Port Testing**
   - Tests critical ports required for Delivery Optimization:
     - TCP: `7680`, `443`
     - UDP: `3544` (Teredo NAT traversal)

4. **Teredo Status Verification and Fix**
   - Checks the state of Teredo and enables it if not in a qualified state.

5. **Microsoft Endpoint Connectivity**
   - Validates connectivity to key Delivery Optimization endpoints, ensuring network accessibility.

6. **Bandwidth Policy Check**
   - Retrieves and displays Group Policy settings related to Delivery Optimization bandwidth usage.

7. **Firewall Rules Validation**
   - Ensures proper Delivery Optimization-related firewall rules are configured and active.

8. **General Network Connectivity**
   - Tests overall internet connectivity using DNS and ping requests.

9. **Clear and Actionable Output**
   - Color-coded outputs for clarity:
     - **Green**: Success
     - **Yellow**: Warnings
     - **Red**: Errors
   - Provides actionable suggestions for resolving identified issues.

---

## Requirements

- **Operating System**: Windows 10 or later.
- **Permissions**: Must be run with Administrator privileges.
- **PowerShell Version**: PowerShell 5.1 or later.

---

## Usage

### 1. Download the Script
Save the script as `DeliveryOptimization.ps1` on your local machine.

### 2. Run the Script
Open PowerShell as an Administrator and execute the script:
```powershell
.\DeliveryOptimization.ps1
```

### 3. Review the Output
The script outputs the status of each check, providing detailed results for troubleshooting.

---

## Output Example

```plaintext
------------------------------------------------------------
Starting Comprehensive Delivery Optimization Troubleshooting
------------------------------------------------------------

------------------------------------------------------------
Checking Delivery Optimization Service (DoSvc)
------------------------------------------------------------
Delivery Optimization service is running.

------------------------------------------------------------
Checking Delivery Optimization Jobs
------------------------------------------------------------
No active Delivery Optimization jobs.

------------------------------------------------------------
Testing Delivery Optimization Required Ports
------------------------------------------------------------
Testing TCP - 7680 (P2P)...
TCP - 7680 (P2P) is NOT reachable. Check firewall or network configuration.
Testing UDP - 3544 (Teredo)...
Teredo is NOT in a qualified state. Attempting to enable it...
Teredo has been enabled. Verify its status by rerunning this script.
Testing TCP - 443 (HTTPS)...
TCP - 443 (HTTPS) is reachable and functional.

------------------------------------------------------------
Testing Connectivity to Microsoft Delivery Optimization Endpoints
------------------------------------------------------------
Successfully connected to http://download.microsoft.com.
Failed to connect to http://tlu.dl.delivery.mp.microsoft.com: Access Denied.

------------------------------------------------------------
Checking Delivery Optimization Bandwidth Policies
------------------------------------------------------------
No Delivery Optimization bandwidth policies found. Default settings may be in use.

------------------------------------------------------------
Checking General Network Connectivity
------------------------------------------------------------
General network connectivity is healthy.

------------------------------------------------------------
Delivery Optimization Troubleshooting Completed
------------------------------------------------------------
```

---

## Troubleshooting

### Common Issues and Fixes

#### 1. **Teredo is NOT in a qualified state**
- Run the following command to enable Teredo manually:
  ```powershell
  netsh interface teredo set state enterpriseclient
  ```

#### 2. **Port 7680 (P2P) or 3544 (UDP) is not reachable**
- Ensure the following ports are open in your firewall:
  - TCP: `7680`, `443`
  - UDP: `3544`

#### 3. **Access Denied for Endpoint Connectivity**
- Verify your network proxy or firewall settings are not blocking Microsoft Delivery Optimization endpoints.

#### 4. **General Network Connectivity Fails**
- Check your internet connection or resolve DNS issues by using public DNS servers (e.g., 8.8.8.8).

---

## Files Included

- `DeliveryOptimization.ps1`: The PowerShell script for troubleshooting.
- `README.md`: Documentation for the script.

## License

This project is licensed under the [MIT License](LICENSE).


---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.
