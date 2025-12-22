#!/bin/bash

# BRLN-OS Deployment Script
# This script copies the updated files to Apache web directory

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SOURCE_DIR="/root/brln-os"
APACHE_DIR="/var/www/html"
BACKUP_DIR="/var/backups/brln-os-$(date +%Y%m%d-%H%M%S)"

echo -e "${YELLOW}BRLN-OS Deployment Script${NC}"
echo "=============================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Create backup of current Apache directory
echo -e "${YELLOW}Creating backup...${NC}"
mkdir -p "$BACKUP_DIR"
cp -r "$APACHE_DIR"/* "$BACKUP_DIR" 2>/dev/null
echo -e "${GREEN}Backup created at: $BACKUP_DIR${NC}"

# Copy main files
echo -e "${YELLOW}Copying main files...${NC}"
cp -f "$SOURCE_DIR/main.html" "$APACHE_DIR/index.html"

# Copy favicon and static assets
echo -e "${YELLOW}Copying static assets...${NC}"
if [ -f "$SOURCE_DIR/favicon.ico" ]; then
    cp -f "$SOURCE_DIR/favicon.ico" "$APACHE_DIR/"
fi

# Copy pages directory
echo -e "${YELLOW}Copying pages directory...${NC}"
cp -r "$SOURCE_DIR/pages" "$APACHE_DIR/"

# Copy simple-lnwallet if exists
if [ -d "$SOURCE_DIR/simple-lnwallet" ]; then
    echo -e "${YELLOW}Copying simple-lnwallet...${NC}"
    cp -r "$SOURCE_DIR/simple-lnwallet" "$APACHE_DIR/"
fi

# Copy any additional static assets (css, js, images in root)
echo -e "${YELLOW}Copying additional static assets...${NC}"
for ext in css js png jpg jpeg gif svg webp; do
    if ls "$SOURCE_DIR"/*.$ext 1> /dev/null 2>&1; then
        cp -f "$SOURCE_DIR"/*.$ext "$APACHE_DIR/" 2>/dev/null || true
    fi
done

# Set correct permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chown -R www-data:www-data "$APACHE_DIR"
chmod -R 755 "$APACHE_DIR"

# Enable required Apache modules
echo -e "${YELLOW}Checking Apache modules...${NC}"
a2enmod rewrite proxy proxy_http headers 2>/dev/null

# Test Apache configuration
echo -e "${YELLOW}Testing Apache configuration...${NC}"
if apache2ctl configtest; then
    echo -e "${GREEN}Apache configuration test passed${NC}"
    
    # Restart Apache
    echo -e "${YELLOW}Restarting Apache...${NC}"
    systemctl restart apache2
    
    if systemctl is-active --quiet apache2; then
        echo -e "${GREEN}Apache restarted successfully${NC}"
    else
        echo -e "${RED}Apache restart failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}Apache configuration test failed${NC}"
    exit 1
fi

# Check if services are running
echo -e "${YELLOW}Checking services...${NC}"
services=("lnd" "bitcoind" "simple-lnwallet" "thunderhub" "lnbits" "lndg")

for service in "${services[@]}"; do
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        if systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}✓ $service is running${NC}"
        else
            echo -e "${YELLOW}⚠ $service is enabled but not running${NC}"
            echo -e "${YELLOW}  Starting $service...${NC}"
            systemctl start "$service"
        fi
    else
        echo -e "${YELLOW}- $service is not enabled${NC}"
    fi
done

# Final status
echo ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Web interface available at: http://$(hostname -I | cut -d' ' -f1)${NC}"
echo -e "${YELLOW}Backup stored at: $BACKUP_DIR${NC}"

# Show listening ports
echo ""
echo -e "${YELLOW}Active services and ports:${NC}"
ss -tlnp | grep -E ':(80|3000|5000|8889|35671)\s' | awk '{print $4, $7}' | sort