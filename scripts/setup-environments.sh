#!/bin/bash

# Master Environment Setup Script for BRLN-OS
# This script sets up all virtual environments and dependencies for the system

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

BRLN_ENVS_DIR="/root/brln-os-envs"

setup_all_environments() {
  echo -e "${GREEN}🚀 Setting up all BRLN-OS environments...${NC}"
  
  # Create main environments directory
  mkdir -p "$BRLN_ENVS_DIR"
  
  # Setup API environment
  echo -e "${BLUE}📡 Setting up API environment...${NC}"
  bash "$(dirname "${BASH_SOURCE[0]}")/setup-api-env.sh"
  
  # Setup Tools environment
  echo -e "${BLUE}🛠️  Setting up Tools environment...${NC}"
  bash "$(dirname "${BASH_SOURCE[0]}")/setup-tools-env.sh"
  
  # Setup Wallet environment
  echo -e "${BLUE}💳 Setting up Wallet environment...${NC}"
  bash "$(dirname "${BASH_SOURCE[0]}")/setup-wallet-env.sh"
  
  echo -e "${GREEN}✅ All environments setup complete!${NC}"
  echo -e "${YELLOW}📋 Environment locations:${NC}"
  echo -e "  API: ${BRLN_ENVS_DIR}/api-v1"
  echo -e "  Tools: ${BRLN_ENVS_DIR}/brln-tools"
  echo -e "  Wallet: ${BRLN_ENVS_DIR}/wallet-tools"
}

check_environments() {
  echo -e "${BLUE}🔍 Checking all environments...${NC}"
  
  local environments=(
    "api-v1:flask"
    "brln-tools:telebot"
    "wallet-tools:cryptography"
  )
  
  for env_info in "${environments[@]}"; do
    env_name="${env_info%:*}"
    test_package="${env_info#*:}"
    env_path="${BRLN_ENVS_DIR}/${env_name}"
    
    echo -n "  ${env_name}: "
    if [[ -d "$env_path" ]]; then
      if "$env_path/bin/python" -c "import $test_package" 2>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
      else
        echo -e "${RED}❌ Missing dependencies${NC}"
      fi
    else
      echo -e "${RED}❌ Not found${NC}"
    fi
  done
}

# Menu function
show_menu() {
  echo -e "${CYAN}BRLN-OS Environment Manager${NC}"
  echo "1. Setup all environments"
  echo "2. Setup API environment only"
  echo "3. Setup Tools environment only"
  echo "4. Setup Wallet environment only"
  echo "5. Check environments status"
  echo "6. Exit"
  echo -n "Choose an option: "
}

# Interactive mode
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -eq 0 ]]; then
    while true; do
      show_menu
      read -r choice
      case $choice in
        1) setup_all_environments ;;
        2) bash "$(dirname "${BASH_SOURCE[0]}")/setup-api-env.sh" ;;
        3) bash "$(dirname "${BASH_SOURCE[0]}")/setup-tools-env.sh" ;;
        4) bash "$(dirname "${BASH_SOURCE[0]}")/setup-wallet-env.sh" ;;
        5) check_environments ;;
        6) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
      esac
      echo
    done
  else
    case "$1" in
      all|setup) setup_all_environments ;;
      check) check_environments ;;
      api) bash "$(dirname "${BASH_SOURCE[0]}")/setup-api-env.sh" ;;
      tools) bash "$(dirname "${BASH_SOURCE[0]}")/setup-tools-env.sh" ;;
      wallet) bash "$(dirname "${BASH_SOURCE[0]}")/setup-wallet-env.sh" ;;
      *) 
        echo "Usage: $0 [all|check|api|tools|wallet]"
        exit 1
        ;;
    esac
  fi
fi