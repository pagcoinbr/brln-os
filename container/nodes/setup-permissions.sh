#!/bin/bash

# BRLN-OS Permission Setup Script
# This script sets up the correct permissions for all data directories
# before starting the containerized nodes

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

# Function to check if running as root or with sudo
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo privileges"
        print_status "Please run: sudo $0"
        exit 1
    fi
}

# Function to create directories
create_directories() {
    print_header "Creating data directories..."
    
    # Create main data directory
    mkdir -p /data
    print_status "Created /data directory"
    
    # Create service-specific directories
    mkdir -p /data/elements
    mkdir -p /data/lnd
    print_status "Created service data directories"
}

# Function to set ownership
set_ownership() {
    print_header "Setting correct ownership for service directories..."
    
    # Elements daemon - UID 1001, GID 1001
    chown 1001:1001 /data/elements
    print_status "Set ownership for Elements directory (1001:1001)"
    
    # LND daemon - UID 1008, GID 1008  
    chown 1008:1008 /data/lnd
    print_status "Set ownership for LND directory (1008:1008)"
}

# Function to set permissions
set_permissions() {
    print_header "Setting directory permissions..."
    
    # Elements - needs 777 due to container script bug
    chmod -R 777 /data/elements
    print_warning "Set Elements directory to 777 (required for container script)"
    
    # LND - secure 755 permissions
    chmod -R 755 /data/lnd
    print_status "Set LND directory to 755 (secure)"
    
    # Set main data directory to readable
    chmod 755 /data
    print_status "Set main data directory to 755"
}

# Function to verify setup
verify_setup() {
    print_header "Verifying permission setup..."
    
    echo -e "\nDirectory structure and permissions:"
    ls -la /data/
    
    echo -e "\nElements directory details:"
    ls -la /data/elements/ 2>/dev/null || echo "Elements directory is empty (normal for first run)"
    
    echo -e "\nLND directory details:"  
    ls -la /data/lnd/ 2>/dev/null || echo "LND directory is empty (normal for first run)"
}

# Function to create config files if they don't exist
setup_config_files() {
    print_header "Setting up configuration files..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Bitcoin config
    if [[ ! -f "$script_dir/bitcoin/bitcoin.conf" ]]; then
        if [[ -f "$script_dir/bitcoin/bitcoin.conf.example" ]]; then
            cp "$script_dir/bitcoin/bitcoin.conf.example" "$script_dir/bitcoin/bitcoin.conf"
            print_status "Created bitcoin.conf from example"
        else
            print_warning "bitcoin.conf.example not found, skipping"
        fi
    else
        print_status "bitcoin.conf already exists"
    fi
    
    # Elements config
    if [[ ! -f "$script_dir/elements/elements.conf" ]]; then
        if [[ -f "$script_dir/elements/elements.conf.example" ]]; then
            cp "$script_dir/elements/elements.conf.example" "$script_dir/elements/elements.conf"
            print_status "Created elements.conf from example"
        else
            print_warning "elements.conf.example not found, skipping"
        fi
    else
        print_status "elements.conf already exists"
    fi
    
    # LND config
    if [[ ! -f "$script_dir/lnd/lnd.conf" ]]; then
        if [[ -f "$script_dir/lnd/lnd.conf.example" ]]; then
            cp "$script_dir/lnd/lnd.conf.example" "$script_dir/lnd/lnd.conf"
            print_status "Created lnd.conf from example"
        else
            print_warning "lnd.conf.example not found, skipping"
        fi
    else
        print_status "lnd.conf already exists"
    fi
}

# Function to show security notes
show_security_notes() {
    print_header "Security Notes"
    echo -e "${YELLOW}⚠️  IMPORTANT SECURITY INFORMATION:${NC}"
    echo
    echo "1. Elements directory uses 777 permissions due to container script limitations"
    echo "2. This is a known issue with the current Elements container image"
    echo "3. LND uses secure 755 permissions"
    echo "4. All containers run with non-root users (UIDs 1001, 1008)"
    echo "5. Consider running this setup on an isolated network or VPN"
    echo
    echo -e "${GREEN}✅ Permission setup completed successfully!${NC}"
    echo
}

# Function to provide next steps
show_next_steps() {
    print_header "Next Steps"
    echo "1. Start the services:"
    echo "   podman-compose up -d"
    echo
    echo "2. Check service status:"
    echo "   podman-compose ps"
    echo
    echo "3. View logs:"
    echo "   podman-compose logs -f [service_name]"
    echo
    echo "4. Available services: tor, bitcoind, elementsd, lnd"
    echo
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                BRLN-OS Permission Setup                  ║"
    echo "║              Setting up data directories                 ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_privileges
    create_directories
    set_ownership
    set_permissions
    setup_config_files
    verify_setup
    show_security_notes
    show_next_steps
}

# Run main function
main "$@"
