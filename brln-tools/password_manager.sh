#!/bin/bash
# BRLN-OS Password Manager Shell Wrapper
# Provides convenient functions for password storage

PASSWORD_MANAGER_SCRIPT="/root/brln-os/brln-tools/password_manager.py"

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
