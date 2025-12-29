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

# SPINNER FUNCTION COMMENTED OUT FOR DEVELOPMENT
# This prevents loading animations from hiding crashes/freezes during development
spinner() {
  # local pid=$!
  # local delay=0.1
  # local spinstr='|/-\'
  
  # while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
  #   local temp=${spinstr#?}
  #   printf " [%c]  " "$spinstr"
  #   local spinstr=$temp${spinstr%"$temp"}
  #   sleep $delay
  #   printf "\b\b\b\b\b\b"
  # done
  # printf "    \b\b\b\b"
  
  # Just wait for the background process without animation
  local pid=$!
  echo -e "${YELLOW}"
  wait $pid
  local exit_status=$?
  
  if [ $exit_status -eq 0 ]; then
    echo -e "${GREEN}"
  else
    echo -e "${RED}"
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
  echo -e "${YELLOW}"
  
  # Get current SSH port (default 22)
  ssh_port=$(sudo ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2 | head -n1)
  ssh_port=${ssh_port:-22}
  
  echo -e "${BLUE}"
  echo -e "${BLUE}"
  echo -e "${BLUE}"
  
  # Reset UFW to default settings
  sudo ufw --force reset
  
  # Set default policies
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  
  # Allow SSH
  sudo ufw allow $ssh_port/tcp comment 'SSH access'
  
  # Allow HTTPS
  sudo ufw allow 443/tcp comment 'HTTPS access'
  
  # Enable UFW
  sudo ufw --force enable
  
  echo -e "${GREEN}"
  
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