#!/bin/bash

# Gotty installation and management functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

gotty_install() {
  echo -e "${GREEN}"
  
  # Gotty official release from GitHub
  GOTTY_VERSION="2.0.0-alpha.3"
  GOTTY_URL="https://github.com/yudai/gotty/releases/download/v${GOTTY_VERSION}/gotty_${GOTTY_VERSION}_linux_amd64.tar.gz"
  
  # Detect architecture
  ARCH=$(uname -m)
  if [[ "$ARCH" == "x86_64" ]]; then
    GOTTY_ARCH="amd64"
  elif [[ "$ARCH" == "aarch64" ]]; then
    GOTTY_ARCH="arm64"
  elif [[ "$ARCH" == "armv7l" ]]; then
    GOTTY_ARCH="arm"
  else
    echo -e "${YELLOW}"
    GOTTY_ARCH="amd64"
  fi
  
  GOTTY_URL="https://github.com/yudai/gotty/releases/download/v${GOTTY_VERSION}/gotty_${GOTTY_VERSION}_linux_${GOTTY_ARCH}.tar.gz"
  
  # Remove existing gotty if present
  if [[ -f /usr/local/bin/gotty ]]; then
    echo -e "${YELLOW}"
    sudo rm -f /usr/local/bin/gotty
  fi
  
  # Download and install gotty
  cd /tmp
  echo -e "${YELLOW}"
  if wget -nv "$GOTTY_URL" -O "gotty.tar.gz"; then
    if tar -xzf gotty.tar.gz; then
      sudo mv gotty /usr/local/bin/gotty
      sudo chmod +x /usr/local/bin/gotty
      rm -f gotty.tar.gz
      echo -e "${GREEN}"
      
      # Verify installation
      if /usr/local/bin/gotty --version; then
        echo -e "${GREEN}"
        return 0
      else
        echo -e "${RED}"
        return 1
      fi
    else
      echo -e "${RED}"
      rm -f gotty.tar.gz
      return 1
    fi
  else
    echo -e "${RED}"
    return 1
  fi
}

setup_gotty_service() {
  # Source services.sh to get the create_gotty_service function
  source "$(dirname "${BASH_SOURCE[0]}")/services.sh"
  
  # Call the actual service creation function
  create_gotty_service

  # Reload systemd and enable service
  sudo systemctl daemon-reload
  sudo systemctl enable gotty-fullauto
  
  echo -e "${GREEN}✅ Gotty service setup complete${NC}"
}

terminal_web() {
  echo -e "${GREEN}"
  
  # Install Gotty
  if gotty_install; then
    # Create and enable service
    setup_gotty_service
    
    # Start the service within script context
    echo -e "${YELLOW}"
    # Stop any conflicting processes first
    sudo pkill -f 'gotty.*3131' || true
    
    sudo systemctl start gotty-fullauto
    
    # Centralized service check
    for i in {1..3}; do
        if sudo systemctl is-active --quiet gotty-fullauto; then
            echo -e "${GREEN}"
            break
        elif [[ $i -eq 3 ]]; then
            echo -e "${YELLOW}"
        else
            sleep 1
        fi
    done
  else
    echo -e "${RED}"
    return 1
  fi
}