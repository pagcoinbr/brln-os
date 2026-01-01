#!/bin/bash
# Test script for password manager session handling

# Source required scripts
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

echo "=== Testing Password Manager Session Handling ==="
echo ""

# Test 1: Load master password
echo "1. Testing load_master_password..."
if load_master_password; then
    echo "   ✓ Master password loaded successfully"
    echo "   Source: ${BRLN_MASTER_PASSWORD:0:4}****"
else
    echo "   ✗ No master password available"
    echo "   This is normal if systemd credentials are not set up"
fi
echo ""

# Test 2: Ensure PM session
echo "2. Testing ensure_pm_session..."
if ensure_pm_session; then
    echo "   ✓ Password manager session is ready"
else
    echo "   ✗ Password manager session could not be initialized"
    echo "   Note: This requires password manager to be initialized"
fi
echo ""

# Test 3: Check if can store without prompting
echo "3. Testing non-interactive password storage..."
if [[ -n "${BRLN_MASTER_PASSWORD:-}" ]]; then
    echo "   ✓ BRLN_MASTER_PASSWORD is set - storage should be non-interactive"
else
    echo "   ✗ BRLN_MASTER_PASSWORD not set - storage may prompt for password"
fi
echo ""

echo "=== Test Complete ==="
