#!/bin/bash
# BRLN-OS Secure Password Manager v2 Shell Wrapper
# Enhanced security with ephemeral master password

# Dynamic path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURE_PM_SCRIPT="$SCRIPT_DIR/secure_password_manager.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Ensure script is executable
if [[ ! -x "$SECURE_PM_SCRIPT" ]]; then
    chmod +x "$SECURE_PM_SCRIPT" 2>/dev/null
fi

# Check if password manager is initialized
is_pm_initialized() {
    python3 "$SECURE_PM_SCRIPT" status 2>/dev/null | grep -q "Initialized: Yes"
}

# Initialize password manager with master password
secure_pm_init() {
    local master_password="$1"
    
    if [[ -z "$master_password" ]]; then
        # Interactive mode
        python3 "$SECURE_PM_SCRIPT" init
    else
        python3 "$SECURE_PM_SCRIPT" init "$master_password"
    fi
}

# Unlock session with master password
secure_pm_unlock() {
    local master_password="$1"
    
    if [[ -n "${BRLN_MASTER_PASSWORD:-}" ]]; then
        python3 "$SECURE_PM_SCRIPT" unlock "$BRLN_MASTER_PASSWORD"
        return $?
    fi
    
    if [[ -n "$master_password" ]]; then
        python3 "$SECURE_PM_SCRIPT" unlock "$master_password"
    else
        python3 "$SECURE_PM_SCRIPT" unlock
    fi
}

# Lock session immediately
secure_pm_lock() {
    python3 "$SECURE_PM_SCRIPT" lock
}

# Store password with full details
secure_store_password_full() {
    local service_name="$1"
    local password="$2"
    local description="$3"
    local username="$4"
    local port="$5"
    local url="$6"
    local master_password="$7"
    
    if [[ -z "$service_name" || -z "$password" ]]; then
        echo -e "${RED}Error: service_name and password are required${NC}" >&2
        return 1
    fi
    
    # Check if initialized
    if ! is_pm_initialized; then
        echo -e "${YELLOW}⚠️  Password manager not initialized${NC}"
        echo -e "${CYAN}💡 Run: secure_pm_init${NC}"
        return 1
    fi
    
    # Set defaults
    username="${username:-admin}"
    description="${description:-$service_name}"
    port="${port:-0}"
    url="${url:-}"
    
    # Use environment variable if available
    if [[ -z "$master_password" && -n "${BRLN_MASTER_PASSWORD:-}" ]]; then
        master_password="$BRLN_MASTER_PASSWORD"
    fi
    
    if [[ -n "$master_password" ]]; then
        python3 "$SECURE_PM_SCRIPT" store "$service_name" "$username" "$password" "$description" "$port" "$url" "$master_password"
    else
        python3 "$SECURE_PM_SCRIPT" store "$service_name" "$username" "$password" "$description" "$port" "$url"
    fi
}

# Store password with minimal details
secure_store_password() {
    local service_name="$1"
    local password="$2"
    local username="${3:-admin}"
    local master_password="$4"
    
    secure_store_password_full "$service_name" "$password" "$service_name" "$username" 0 "" "$master_password"
}

# Get password for a service
secure_get_password() {
    local service_name="$1"
    local master_password="$2"
    
    if [[ -z "$service_name" ]]; then
        echo -e "${RED}Error: service_name is required${NC}" >&2
        return 1
    fi
    
    # Check if initialized
    if ! is_pm_initialized; then
        echo -e "${YELLOW}⚠️  Password manager not initialized${NC}" >&2
        return 1
    fi
    
    # Use environment variable if available
    if [[ -z "$master_password" && -n "${BRLN_MASTER_PASSWORD:-}" ]]; then
        master_password="$BRLN_MASTER_PASSWORD"
    fi
    
    if [[ -n "$master_password" ]]; then
        python3 "$SECURE_PM_SCRIPT" get "$service_name" "$master_password"
    else
        python3 "$SECURE_PM_SCRIPT" get "$service_name"
    fi
}

# List all stored services
secure_list_passwords() {
    python3 "$SECURE_PM_SCRIPT" list
}

# Delete a password
secure_delete_password() {
    local service_name="$1"
    local master_password="$2"
    
    if [[ -z "$service_name" ]]; then
        echo -e "${RED}Error: service_name is required${NC}" >&2
        return 1
    fi
    
    # Use environment variable if available
    if [[ -z "$master_password" && -n "${BRLN_MASTER_PASSWORD:-}" ]]; then
        master_password="$BRLN_MASTER_PASSWORD"
    fi
    
    if [[ -n "$master_password" ]]; then
        python3 "$SECURE_PM_SCRIPT" delete "$service_name" "$master_password"
    else
        python3 "$SECURE_PM_SCRIPT" delete "$service_name"
    fi
}

# Show status
secure_pm_status() {
    python3 "$SECURE_PM_SCRIPT" status
}

# Change master password
secure_pm_change_password() {
    local old_password="$1"
    local new_password="$2"
    
    if [[ -n "$old_password" && -n "$new_password" ]]; then
        python3 "$SECURE_PM_SCRIPT" change-password "$old_password" "$new_password"
    else
        python3 "$SECURE_PM_SCRIPT" change-password
    fi
}

# Reset password database
secure_pm_reset() {
    python3 "$SECURE_PM_SCRIPT" reset
}

# Interactive setup helper
secure_pm_setup() {
    echo -e "${BLUE}=== BRLN-OS Secure Password Manager v2 Setup ===${NC}"
    echo ""
    
    if is_pm_initialized; then
        echo -e "${GREEN}✓ Password manager is already initialized${NC}"
        secure_pm_status
        return 0
    fi
    
    echo -e "${YELLOW}Password manager needs to be initialized with a master password.${NC}"
    echo ""
    echo -e "${CYAN}Security Features:${NC}"
    echo "  • Master password is NEVER stored locally"
    echo "  • Each password has unique encryption salt"
    echo "  • 500,000 PBKDF2 iterations for quantum resistance"
    echo "  • Challenge-response authentication (no hash storage)"
    echo "  • Session timeout after 5 minutes of inactivity"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: If you lose your master password, ALL passwords are UNRECOVERABLE!${NC}"
    echo ""
    
    read -p "Do you want to initialize now? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        secure_pm_init
    else
        echo "Setup cancelled"
        return 1
    fi
}

# Export functions for use in other scripts
export -f is_pm_initialized
export -f secure_pm_init
export -f secure_pm_unlock
export -f secure_pm_lock
export -f secure_store_password_full
export -f secure_store_password
export -f secure_get_password
export -f secure_list_passwords
export -f secure_delete_password
export -f secure_pm_status
export -f secure_pm_change_password
export -f secure_pm_reset
export -f secure_pm_setup

# If script is run directly (not sourced), show help
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "BRLN-OS Secure Password Manager v2 - Shell Wrapper"
    echo ""
    echo "This script should be sourced to use its functions:"
    echo "  source $0"
    echo ""
    echo "Available functions:"
    echo "  secure_pm_setup              - Interactive setup wizard"
    echo "  secure_pm_init [password]    - Initialize with master password"
    echo "  secure_pm_unlock [password]  - Unlock session"
    echo "  secure_pm_lock               - Lock session immediately"
    echo "  secure_store_password <svc> <pass> [user] [master_pw]"
    echo "  secure_get_password <service> [master_password]"
    echo "  secure_list_passwords        - List all stored services"
    echo "  secure_delete_password <service> [master_password]"
    echo "  secure_pm_change_password [old] [new]"
    echo "  secure_pm_status             - Show status"
    echo "  secure_pm_reset              - Reset database (DESTRUCTIVE)"
    echo ""
    echo "Environment variable:"
    echo "  BRLN_MASTER_PASSWORD - Set to avoid password prompts"
fi
