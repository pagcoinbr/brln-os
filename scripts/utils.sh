#!/bin/bash

# Utility functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Function to center text output
center_text() {
    local text="$1"
    local color="${2:-$NC}"
    local term_width=$(tput cols 2>/dev/null || echo 80)
    # Strip color codes for length calculation
    local text_plain=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_length=${#text_plain}
    local padding=$(( (term_width - text_length) / 2 ))
    
    if [[ $padding -gt 0 ]]; then
        printf "%${padding}s" ""
    fi
    echo -e "${color}${text}${NC}"
}

safe_cp() {
  local src="$1"
  local dest="$2"

  if [[ -e "$src" ]]; then
    sudo cp "$src" "$dest"
  else
    echo -e "${RED}"
    return 1
  fi
}

# SPINNER FUNCTION MODIFIED FOR DEBUG - SHOWS ALL OUTPUT
# This prevents loading animations from hiding crashes/freezes during development
spinner() {
  # Just wait for the background process without animation and show all output
  local pid=$!
  echo -e "${BLUE}[DEBUG] Waiting for process $pid to complete...${NC}"
  
  # Wait for the process and capture exit status
  wait $pid
  local exit_status=$?
  
  if [ $exit_status -eq 0 ]; then
    echo -e "${GREEN}[DEBUG] Process completed successfully (exit code: $exit_status)${NC}"
  else
    echo -e "${RED}[DEBUG] Process failed with exit code: $exit_status${NC}"
  fi
  
  return $exit_status
}

create_main_dir() {
  sudo mkdir -p $HOME
}

configure_ufw() {
  sudo ufw --force enable
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
}

configure_secure_firewall() {
  echo -e "${YELLOW}🔒 Configurando firewall para acesso local...${NC}"
  
  # Get current SSH port (default 22)
  ssh_port=$(sudo ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2 | head -n1)
  ssh_port=${ssh_port:-22}
  
  # Reset UFW to default settings
  sudo ufw --force reset
  
  # Set default policies
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  
  # Allow SSH
  sudo ufw allow $ssh_port/tcp comment 'SSH access'
  
  # Allow HTTPS only from local networks
  echo -e "${BLUE}Permitindo HTTPS (443) apenas de redes locais...${NC}"
  
  # Allow from localhost
  sudo ufw allow from 127.0.0.1 to any port 443 proto tcp comment 'HTTPS from localhost'
  
  # Allow from private network ranges (RFC 1918)
  sudo ufw allow from 192.168.0.0/16 to any port 443 proto tcp comment 'HTTPS from 192.168.x.x'
  sudo ufw allow from 10.0.0.0/8 to any port 443 proto tcp comment 'HTTPS from 10.x.x.x'
  sudo ufw allow from 172.16.0.0/12 to any port 443 proto tcp comment 'HTTPS from 172.16-31.x.x'
  
  # Allow from Tailscale network (100.64.0.0/10 - CGNAT range used by Tailscale)
  sudo ufw allow from 100.64.0.0/10 to any port 443 proto tcp comment 'HTTPS from Tailscale VPN'
  
  # Enable UFW
  sudo ufw --force enable
  
  echo -e "${GREEN}✅ Firewall configurado! HTTPS restrito a redes locais e Tailscale${NC}"
  
  # Show current status
  sudo ufw status numbered
}

close_ports_except_ssh() {
  echo -e "${YELLOW}"
  
  # Get current SSH port (default 22)
  ssh_port=$(sudo ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2 | head -n1)
  ssh_port=${ssh_port:-22}
  
  echo -e "${BLUE}"
  
  # Reset UFW to default settings
  sudo ufw --force reset
  
  # Set default policies
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  
  # Allow SSH
  sudo ufw allow $ssh_port/tcp comment 'SSH access'
  
  # Enable UFW
  sudo ufw --force enable
  
  echo -e "${GREEN}"
  
  # Show current status
  sudo ufw status numbered
}

# Function to ensure proper ownership of /data subdirectories
ensure_data_ownership() {
  local service="$1"  # bitcoin, lnd, elements, etc.
  local user="${2:-$service}"
  local group="${3:-$service}"
  
  if [[ -d "/data/$service" ]]; then
    echo -e "${BLUE}Assegurando propriedade: /data/$service → $user:$group${NC}"
    sudo chown -R "$user:$group" "/data/$service"
    sudo chmod 750 "/data/$service"
  fi
}

# Function to verify /data compartmentalization
verify_data_compartments() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}🔒 Verificando compartimentalização /data/${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  for dir in /data/*/; do
    if [[ -d "$dir" ]]; then
      local dirname=$(basename "$dir")
      local owner=$(stat -c '%U:%G' "$dir")
      local perms=$(stat -c '%a' "$dir")
      echo -e "${GREEN}✓${NC} $dirname: $owner (perms: $perms)"
    fi
  done
  echo ""
}

# ============================================================================
# PATH DETECTION FUNCTIONS - Reusable across all BRLN-OS scripts
# ============================================================================

# Detect current user (handles sudo cases)
detect_current_user() {
    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        echo "$SUDO_USER"
    else
        whoami
    fi
}

# Configure user environment paths based on detected user
# Sets global variables: ATUAL_USER, USER_HOME, BRLN_OS_DIR, API_DIR, VENV_DIR_API, VENV_DIR_TOOLS, API_USER
configure_brln_paths() {
    local quiet=${1:-false}
    
    # Detect the actual user (not root when using sudo)
    ATUAL_USER=$(detect_current_user)
    
    # Determine BRLN-OS installation directory
    # Try to detect from current script location first
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$script_dir" =~ .*/brln-os/.* ]]; then
        BRLN_OS_DIR="$(echo "$script_dir" | sed 's|\(/[^/]*/brln-os\).*|\1|')"
    else
        # Fallback to user-based detection
        if [[ $ATUAL_USER == "root" ]]; then
            BRLN_OS_DIR="/root/brln-os"
        elif [[ $ATUAL_USER == "admin" ]]; then
            BRLN_OS_DIR="/home/admin/brln-os"
        else
            BRLN_OS_DIR="/home/$ATUAL_USER/brln-os"
        fi
    fi
    
    # Set paths based on user
    if [[ $ATUAL_USER == "root" ]]; then
        USER_HOME="/root"
        VENV_DIR_API="/home/brln-api/venv"  # Create in brln-api home, not root
        VENV_DIR_TOOLS="/root/brln-os-envs/brln-tools"
        API_USER="brln-api"  # API always runs as brln-api user
        if [[ "$quiet" != "true" ]]; then
            echo -e "${BLUE}Modo: Root (administrador do sistema)${NC}"
        fi
    elif [[ $ATUAL_USER == "admin" ]]; then
        USER_HOME="/home/admin"
        VENV_DIR_API="/home/admin/brln-os-envs/api-v1"
        VENV_DIR_TOOLS="/home/admin/brln-os-envs/brln-tools"
        API_USER="admin"
        if [[ "$quiet" != "true" ]]; then
            echo -e "${BLUE}Modo: Admin (usuário dedicado)${NC}"
        fi
    else
        USER_HOME="/home/$ATUAL_USER"
        VENV_DIR_API="/home/$ATUAL_USER/brln-os-envs/api-v1"
        VENV_DIR_TOOLS="/home/$ATUAL_USER/brln-os-envs/brln-tools"
        API_USER="$ATUAL_USER"
        if [[ "$quiet" != "true" ]]; then
            echo -e "${BLUE}Modo: Usuário personalizado ($ATUAL_USER)${NC}"
        fi
    fi
    
    # Set derived paths
    API_DIR="$BRLN_OS_DIR/api/v1"
    PROTO_DIR="$API_DIR/proto"
    REQUIREMENTS_FILE_API="$API_DIR/requirements.txt"
    REQUIREMENTS_FILE_TOOLS="$BRLN_OS_DIR/brln-tools/requirements.txt"
    
    if [[ "$quiet" != "true" ]]; then
        echo -e "${BLUE}Usuário: $ATUAL_USER${NC}"
        echo -e "${BLUE}BRLN-OS Dir: $BRLN_OS_DIR${NC}"
        echo -e "${BLUE}API Dir: $API_DIR${NC}"
        echo -e "${BLUE}Diretório home: $USER_HOME${NC}"
    fi
}

# Quick function to just get the API directory path
get_api_dir() {
    configure_brln_paths true
    echo "$API_DIR"
}

# Quick function to just get the BRLN-OS root directory
get_brln_os_dir() {
    configure_brln_paths true
    echo "$BRLN_OS_DIR"
}

# Load master password from SystemD credentials or environment
# This function should be called before using secure password manager functions
load_master_password() {
    # Check if already set in environment
    if [[ -n "${BRLN_MASTER_PASSWORD:-}" ]]; then
        return 0
    fi
    
    # Try to load from SystemD credentials (available in services)
    if [[ -n "${CREDENTIALS_DIRECTORY:-}" ]] && [[ -f "${CREDENTIALS_DIRECTORY}/brln-master-password" ]]; then
        export BRLN_MASTER_PASSWORD=$(cat "${CREDENTIALS_DIRECTORY}/brln-master-password")
        return 0
    fi
    
    # Try to load from credstore (if running as root)
    if [[ -f "/etc/credstore/brln-master-password.cred" ]] && command -v systemd-creds &>/dev/null; then
        # Decrypt SystemD credential
        BRLN_MASTER_PASSWORD=$(systemd-creds decrypt /etc/credstore/brln-master-password.cred - 2>/dev/null)
        if [[ -n "$BRLN_MASTER_PASSWORD" ]]; then
            export BRLN_MASTER_PASSWORD
            return 0
        fi
    fi
    
    # No automatic source found
    return 1
}

# Ensure password manager session is ready for non-interactive use
# Attempts to unlock session using available credentials
ensure_pm_session() {
    local script_dir="${BRLN_OS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    local pm_script="$script_dir/brln-tools/secure_password_manager.sh"
    
    # Source password manager if not already loaded
    if ! declare -f secure_pm_status &>/dev/null; then
        if [[ -f "$pm_script" ]]; then
            source "$pm_script"
        else
            echo -e "${RED}❌ Password manager script not found${NC}" >&2
            return 1
        fi
    fi
    
    # Check if password manager is initialized
    if ! is_pm_initialized; then
        echo -e "${YELLOW}⚠️  Password manager not initialized${NC}" >&2
        echo -e "${YELLOW}⚠️  Passwords will not be stored automatically${NC}" >&2
        return 1
    fi
    
    # Try to load master password
    if ! load_master_password; then
        echo -e "${YELLOW}⚠️  No automatic master password available${NC}" >&2
        echo -e "${YELLOW}⚠️  You may be prompted for the master password${NC}" >&2
        return 1
    fi
    
    # Unlock session with loaded password
    if secure_pm_unlock "$BRLN_MASTER_PASSWORD" >/dev/null 2>&1; then
        return 0
    else
        echo -e "${YELLOW}⚠️  Failed to unlock password manager session${NC}" >&2
        return 1
    fi
}