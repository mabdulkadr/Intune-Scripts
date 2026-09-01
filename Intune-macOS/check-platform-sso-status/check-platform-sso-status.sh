#!/bin/bash
# ============================================================================
# check-platform-sso-status.sh - macOS Platform SSO Status Check
# ============================================================================
# Checks macOS Platform SSO registration status (GA May 2026) via
# app-sso platform status and dsconfigad. Reports SSO state for Intune.
#
# Usage: ./check-platform-sso-status.sh
# Exit: 0=healthy, 1=issue found, 2=error
# ============================================================================

set -euo pipefail

SOLUTION_NAME="check-platform-sso-status"
LOG_DIR="/tmp/${SOLUTION_NAME}"
LOG_FILE="${LOG_DIR}/${SOLUTION_NAME}.log"

mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"; }

log "INFO" "Platform SSO status check started (macOS $(sw_vers -productVersion))"

# Check 1: app-sso platform SSO status (macOS 14+)
if command -v app-sso &>/dev/null; then
    log "INFO" "Checking Platform SSO via app-sso..."
    if app-sso platform -s 2>&1 | grep -qi "registered\|enabled"; then
        log "SUCCESS" "Platform SSO is registered and enabled"
    else
        log "WARNING" "Platform SSO not registered - configure via Intune Settings Catalog (Platform SSO)"
        echo "Platform SSO not registered"
        exit 1
    fi
else
    log "DEBUG" "app-sso not available (requires macOS 14+)"
fi

# Check 2: Verify Intune Company Portal SSO extension
if /usr/bin/profiles show -type configuration 2>&1 | grep -qi "PlatformSSO\|SingleSignOn"; then
    log "SUCCESS" "Platform SSO profile found in configuration profiles"
else
    log "WARNING" "No Platform SSO profile found - deploy via Intune"
    echo "No Platform SSO profile"
    exit 1
fi

# Check 3: Kerberos / SSO token validity
if klist 2>&1 | grep -qi "krbtgt\|valid"; then
    log "SUCCESS" "Kerberos ticket present"
else
    log "INFO" "No Kerberos ticket (expected if not yet signed in via SSO)"
fi

# Check 4: Entra ID device registration
if /usr/bin/dsconfigad -show 2>&1 | grep -qi "Active Directory"; then
    log "INFO" "AD binding detected (legacy) - consider Platform SSO migration"
fi

log "SUCCESS" "Platform SSO health check completed"
echo "Platform SSO check completed - compliant"
exit 0
