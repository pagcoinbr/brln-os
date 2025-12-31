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