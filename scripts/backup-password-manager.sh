#!/bin/bash
# BRLN-OS Secure Password Manager - Backup and Restore Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
DB_PATH="/data/brln-secure-passwords.db"
BACKUP_DIR="/data/backups/passwords"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create backup directory
sudo mkdir -p "$BACKUP_DIR"
sudo chmod 700 "$BACKUP_DIR"

# Function to backup database
backup_database() {
    echo -e "${BLUE}🔐 BRLN-OS Password Manager Backup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    if [[ ! -f "$DB_PATH" ]]; then
        echo -e "${RED}❌ Database not found: $DB_PATH${NC}"
        exit 1
    fi
    
    # Generate timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/brln-passwords-backup-$TIMESTAMP.db"
    
    # Copy database
    echo -e "${YELLOW}📦 Creating backup...${NC}"
    sudo cp "$DB_PATH" "$BACKUP_FILE"
    
    # Set permissions
    sudo chmod 600 "$BACKUP_FILE"
    
    # Create checksum
    CHECKSUM=$(sha256sum "$BACKUP_FILE" | awk '{print $1}')
    echo "$CHECKSUM" | sudo tee "$BACKUP_FILE.sha256" > /dev/null
    
    # Get database info
    PASSWORD_COUNT=$(sudo sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM passwords;" 2>/dev/null || echo "0")
    DB_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    
    echo -e "${GREEN}✅ Backup created successfully!${NC}"
    echo
    echo -e "${BLUE}Backup Information:${NC}"
    echo -e "  📁 File: $BACKUP_FILE"
    echo -e "  📊 Size: $DB_SIZE"
    echo -e "  🔑 Passwords: $PASSWORD_COUNT"
    echo -e "  🔐 Checksum: ${CHECKSUM:0:16}..."
    echo
    echo -e "${YELLOW}⚠️  Important:${NC}"
    echo -e "  • Keep this backup in a SECURE location"
    echo -e "  • The database is encrypted but should still be protected"
    echo -e "  • You'll need the master password to restore"
    echo
    
    # Clean old backups (keep last 10)
    cleanup_old_backups
}

# Function to restore database
restore_database() {
    echo -e "${BLUE}🔐 BRLN-OS Password Manager Restore${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    # List available backups
    echo -e "${YELLOW}📦 Available backups:${NC}"
    BACKUPS=($(ls -t "$BACKUP_DIR"/*.db 2>/dev/null || true))
    
    if [[ ${#BACKUPS[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No backups found in $BACKUP_DIR${NC}"
        exit 1
    fi
    
    for i in "${!BACKUPS[@]}"; do
        BACKUP="${BACKUPS[$i]}"
        TIMESTAMP=$(basename "$BACKUP" | sed 's/brln-passwords-backup-\(.*\)\.db/\1/')
        SIZE=$(du -h "$BACKUP" | cut -f1)
        DATE=$(echo "$TIMESTAMP" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
        echo -e "  $((i+1)). $DATE ($SIZE)"
    done
    echo
    
    # Ask which backup to restore
    read -p "Select backup number to restore (1-${#BACKUPS[@]}): " SELECTION
    
    if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || [[ $SELECTION -lt 1 ]] || [[ $SELECTION -gt ${#BACKUPS[@]} ]]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
    fi
    
    SELECTED_BACKUP="${BACKUPS[$((SELECTION-1))]}"
    
    echo
    echo -e "${YELLOW}⚠️  WARNING: This will REPLACE your current password database!${NC}"
    echo -e "Selected backup: $(basename "$SELECTED_BACKUP")"
    echo
    read -p "Are you sure? (yes/no): " CONFIRM
    
    if [[ "$CONFIRM" != "yes" ]]; then
        echo -e "${BLUE}ℹ️  Restore cancelled${NC}"
        exit 0
    fi
    
    # Verify checksum if exists
    if [[ -f "$SELECTED_BACKUP.sha256" ]]; then
        echo
        echo -e "${YELLOW}🔍 Verifying backup integrity...${NC}"
        STORED_CHECKSUM=$(cat "$SELECTED_BACKUP.sha256")
        CURRENT_CHECKSUM=$(sha256sum "$SELECTED_BACKUP" | awk '{print $1}')
        
        if [[ "$STORED_CHECKSUM" == "$CURRENT_CHECKSUM" ]]; then
            echo -e "${GREEN}✅ Checksum verified${NC}"
        else
            echo -e "${RED}❌ Checksum mismatch! Backup may be corrupted.${NC}"
            read -p "Continue anyway? (yes/no): " FORCE
            if [[ "$FORCE" != "yes" ]]; then
                exit 1
            fi
        fi
    fi
    
    # Backup current database before restoring
    if [[ -f "$DB_PATH" ]]; then
        echo
        echo -e "${YELLOW}📦 Backing up current database before restore...${NC}"
        SAFETY_BACKUP="$BACKUP_DIR/brln-passwords-before-restore-$(date +%Y%m%d_%H%M%S).db"
        sudo cp "$DB_PATH" "$SAFETY_BACKUP"
        echo -e "${GREEN}✅ Safety backup created: $SAFETY_BACKUP${NC}"
    fi
    
    # Restore database
    echo
    echo -e "${YELLOW}🔄 Restoring database...${NC}"
    sudo cp "$SELECTED_BACKUP" "$DB_PATH"
    sudo chmod 666 "$DB_PATH"
    sudo chown brln-api:brln-api "$DB_PATH"
    
    echo -e "${GREEN}✅ Database restored successfully!${NC}"
    echo
    echo -e "${BLUE}ℹ️  Next steps:${NC}"
    echo -e "  1. Restart brln-api service: sudo systemctl restart brln-api"
    echo -e "  2. Test password retrieval to verify master password"
    echo
}

# Function to clean old backups
cleanup_old_backups() {
    echo -e "${YELLOW}🧹 Cleaning old backups (keeping last 10)...${NC}"
    
    BACKUPS=($(ls -t "$BACKUP_DIR"/*.db 2>/dev/null || true))
    
    if [[ ${#BACKUPS[@]} -gt 10 ]]; then
        for i in $(seq 10 $((${#BACKUPS[@]}-1))); do
            BACKUP="${BACKUPS[$i]}"
            echo -e "  🗑️  Removing: $(basename "$BACKUP")"
            sudo rm -f "$BACKUP" "$BACKUP.sha256"
        done
        echo -e "${GREEN}✅ Cleanup complete${NC}"
    else
        echo -e "${GREEN}✅ No cleanup needed (${#BACKUPS[@]} backups)${NC}"
    fi
}

# Function to list backups
list_backups() {
    echo -e "${BLUE}🔐 BRLN-OS Password Manager Backups${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    BACKUPS=($(ls -t "$BACKUP_DIR"/*.db 2>/dev/null || true))
    
    if [[ ${#BACKUPS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No backups found${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}Found ${#BACKUPS[@]} backup(s):${NC}"
    echo
    
    for BACKUP in "${BACKUPS[@]}"; do
        TIMESTAMP=$(basename "$BACKUP" | sed 's/brln-passwords-backup-\(.*\)\.db/\1/')
        SIZE=$(du -h "$BACKUP" | cut -f1)
        DATE=$(echo "$TIMESTAMP" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
        
        # Get password count from backup
        PASSWORD_COUNT=$(sudo sqlite3 "$BACKUP" "SELECT COUNT(*) FROM passwords;" 2>/dev/null || echo "?")
        
        echo -e "${BLUE}📦 $(basename "$BACKUP")${NC}"
        echo -e "   Date: $DATE"
        echo -e "   Size: $SIZE"
        echo -e "   Passwords: $PASSWORD_COUNT"
        
        # Check for checksum
        if [[ -f "$BACKUP.sha256" ]]; then
            CHECKSUM=$(cat "$BACKUP.sha256")
            echo -e "   Checksum: ${CHECKSUM:0:16}..."
        fi
        echo
    done
}

# Function to export passwords (encrypted)
export_passwords() {
    echo -e "${BLUE}🔐 Export Passwords (Encrypted)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    if [[ ! -f "$DB_PATH" ]]; then
        echo -e "${RED}❌ Database not found${NC}"
        exit 1
    fi
    
    read -p "Export location [default: $HOME/brln-passwords-export.tar.gz.gpg]: " EXPORT_PATH
    EXPORT_PATH="${EXPORT_PATH:-$HOME/brln-passwords-export.tar.gz.gpg}"
    
    echo
    echo -e "${YELLOW}📦 Creating encrypted export...${NC}"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    
    # Copy database
    sudo cp "$DB_PATH" "$TEMP_DIR/"
    
    # Create README
    cat > "$TEMP_DIR/README.txt" << EOF
BRLN-OS Secure Password Manager Export
======================================

Date: $(date)
Hostname: $(hostname)

Contents:
- brln-secure-passwords.db : Encrypted password database

Recovery Instructions:
1. Extract this archive to a secure location
2. Restore database: sudo cp brln-secure-passwords.db /data/
3. Set permissions: sudo chmod 666 /data/brln-secure-passwords.db
4. Restart service: sudo systemctl restart brln-api

IMPORTANT: 
- Keep this file in a SECURE location!
- You will need your master password to access the stored passwords
- The master password is NOT stored on the system
EOF
    
    # Create tar archive and encrypt with GPG
    cd "$TEMP_DIR"
    tar czf - * | gpg --symmetric --cipher-algo AES256 -o "$EXPORT_PATH"
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}✅ Export created: $EXPORT_PATH${NC}"
    echo
    echo -e "${YELLOW}⚠️  This export is encrypted with GPG${NC}"
    echo -e "  You'll need the passphrase to decrypt it"
    echo
}

# Function to show help
show_help() {
    cat << EOF
${BLUE}BRLN-OS Secure Password Manager - Backup & Restore${NC}

Usage: $0 <command>

Commands:
  backup          Create a backup of the password database
  restore         Restore from a backup
  list            List all available backups
  export          Export database and credentials (GPG encrypted)
  cleanup         Remove old backups (keep last 10)
  help            Show this help message

Examples:
  $0 backup       # Create new backup
  $0 restore      # Interactive restore from backup
  $0 list         # Show all backups
  $0 export       # Create GPG-encrypted export

Backup Location: $BACKUP_DIR

EOF
}

# Main execution
case "${1:-help}" in
    backup)
        backup_database
        ;;
    restore)
        restore_database
        ;;
    list)
        list_backups
        ;;
    export)
        export_passwords
        ;;
    cleanup)
        cleanup_old_backups
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
