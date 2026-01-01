#!/bin/bash
# BRLN-OS Password Manager Shell Wrapper
# Provides convenient functions for password storage

# Dynamic path resolution to find password_manager.py
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORD_MANAGER_SCRIPT="$SCRIPT_DIR/password_manager.py"

# User key storage file
USER_KEY_FILE="$SCRIPT_DIR/.brln_user_key"

# Initialize user key if not already set
init_user_key() {
    # Check if BRLN_USER_KEY is already set
    if [[ -n "${BRLN_USER_KEY:-}" ]]; then
        return 0
    fi
    
    # Check if key file exists and load it
    if [[ -f "$USER_KEY_FILE" ]]; then
        export BRLN_USER_KEY=$(cat "$USER_KEY_FILE")
        return 0
    fi
    
    # Check if database exists and has users
    if python3 "$PASSWORD_MANAGER_SCRIPT" user >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Password manager database exists but user key is missing.${NC}"
        echo -e "${CYAN}💡 This might happen if the key file was lost or this is a migration.${NC}"
        echo -e "${CYAN}💡 You can either:${NC}"
        echo -e "${CYAN}   1. Provide your existing user key${NC}"
        echo -e "${CYAN}   2. Reset and create a new password database${NC}"
        echo ""
        read -p "Enter your existing user key (or press Enter to reset database): " user_key_input
        
        if [[ -n "$user_key_input" ]]; then
            # Test the provided key
            if python3 "$PASSWORD_MANAGER_SCRIPT" store "test_key_validation" "admin" "temp_test" "Key validation" 0 "" "$user_key_input" >/dev/null 2>&1; then
                python3 "$PASSWORD_MANAGER_SCRIPT" delete "test_key_validation" "$user_key_input" >/dev/null 2>&1
                echo "$user_key_input" > "$USER_KEY_FILE"
                chmod 600 "$USER_KEY_FILE"
                export BRLN_USER_KEY="$user_key_input"
                echo -e "${GREEN}✓ User key validated and saved${NC}"
                return 0
            else
                echo -e "${RED}✗ Invalid user key provided${NC}"
                return 1
            fi
        else
            # User chose to reset - remove database and start fresh
            echo -e "${YELLOW}Resetting password database...${NC}"
            rm -f "$(dirname "$PASSWORD_MANAGER_SCRIPT")/passwords.db"
        fi
    fi
    
    # Generate new user and capture the key (first time or after reset)
    echo -e "${BLUE}Initializing password manager...${NC}"
    local output=$(python3 "$PASSWORD_MANAGER_SCRIPT" store "init_test" "admin" "temp_password" "Initialization test" 0 "" 2>&1)
    
    # Extract user key from output
    local user_key=$(echo "$output" | grep "✓ User key:" | sed 's/.*User key: //')
    
    if [[ -n "$user_key" ]]; then
        # Store the key securely
        echo "$user_key" > "$USER_KEY_FILE"
        chmod 600 "$USER_KEY_FILE"
        export BRLN_USER_KEY="$user_key"
        
        # Remove the test entry
        python3 "$PASSWORD_MANAGER_SCRIPT" delete "init_test" "$user_key" 2>/dev/null || true
        
        echo -e "${GREEN}✓ Password manager initialized${NC}"
    else
        echo -e "${RED}✗ Failed to initialize password manager${NC}"
        return 1
    fi
}

# Ensure the script exists and is executable
if [[ ! -x "$PASSWORD_MANAGER_SCRIPT" ]]; then
    chmod +x "$PASSWORD_MANAGER_SCRIPT" 2>/dev/null
fi

# Store password with full details
store_password_full() {
    local service_name="$1"
    local password="$2"
    local description="$3"
    local username="$4"
    local port="$5"
    local url="$6"
    
    # Initialize user key if needed
    init_user_key || return 1
    
    local user_key="${BRLN_USER_KEY:-}"
    
    if [[ -z "$service_name" || -z "$password" ]]; then
        echo "Error: service_name and password are required" >&2
        return 1
    fi
    
    # Set defaults
    username="${username:-admin}"
    description="${description:-$service_name}"
    port="${port:-0}"
    url="${url:-}"
    
    if [[ -n "$user_key" ]]; then
        python3 "$PASSWORD_MANAGER_SCRIPT" store "$service_name" "$username" "$password" "$description" "$port" "$url" "$user_key"
    else
        python3 "$PASSWORD_MANAGER_SCRIPT" store "$service_name" "$username" "$password" "$description" "$port" "$url"
    fi
}

# Store password with minimal details
store_password() {
    local service_name="$1"
    local password="$2"
    local username="${3:-admin}"
    
    store_password_full "$service_name" "$password" "$service_name" "$username" 0 ""
}

# Get password for a service
get_password() {
    local service_name="$1"
    
    # Initialize user key if needed
    init_user_key || return 1
    
    local user_key="${BRLN_USER_KEY:-}"
    
    if [[ -z "$service_name" ]]; then
        echo "Error: service_name is required" >&2
        return 1
    fi
    
    if [[ -n "$user_key" ]]; then
        python3 "$PASSWORD_MANAGER_SCRIPT" get "$service_name" "$user_key"
    else
        python3 "$PASSWORD_MANAGER_SCRIPT" get "$service_name"
    fi
}

# List all stored passwords
list_passwords() {
    python3 "$PASSWORD_MANAGER_SCRIPT" list
}

# Delete a password
delete_password() {
    local service_name="$1"
    
    if [[ -z "$service_name" ]]; then
        echo "Error: service_name is required" >&2
        return 1
    fi
    
    python3 "$PASSWORD_MANAGER_SCRIPT" delete "$service_name"
}

# Export functions
export -f store_password_full
export -f store_password
export -f get_password
export -f list_passwords
export -f delete_password
