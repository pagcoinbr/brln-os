#!/bin/bash
# Setup SystemD Encrypted Credentials for BRLN-OS
# Uses systemd-creds to securely store master password

set -e

CRED_NAME="brln-master-password"
CRED_DIR="/etc/credstore"
CRED_FILE="$CRED_DIR/${CRED_NAME}"

echo "=== BRLN-OS SystemD Credentials Setup ==="
echo

# Check if systemd-creds is available
if ! command -v systemd-creds &> /dev/null; then
    echo "✗ systemd-creds not found!"
    echo "  This feature requires systemd v250+"
    echo "  Your version: $(systemctl --version | head -1)"
    exit 1
fi

echo "✓ systemd-creds available"

# Create credential directory
sudo mkdir -p "$CRED_DIR"
sudo chmod 700 "$CRED_DIR"

echo
echo "This will create an encrypted credential for the master password."
echo "The password will be encrypted with the system's TPM2 or machine-id."
echo

# Check if credential already exists
if [[ -f "$CRED_FILE" ]]; then
    echo "⚠️  Credential already exists: $CRED_FILE"
    read -p "Do you want to replace it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
fi

# Prompt for master password with validation loop
echo "Enter the master password for secure password manager:"
echo "(Password must be at least 12 characters)"

# Check if we're running in an interactive terminal
if [[ ! -t 0 ]]; then
    echo "✗ Not running in an interactive terminal!"
    echo "  Please run this script directly: sudo bash $0"
    exit 1
fi

# Loop until valid password is entered
while true; do
    read -s -p "Master Password: " MASTER_PASSWORD
    echo
    read -s -p "Confirm Password: " CONFIRM_PASSWORD
    echo
    
    # Check if passwords match
    if [[ "$MASTER_PASSWORD" != "$CONFIRM_PASSWORD" ]]; then
        echo "✗ Passwords do not match! Please try again."
        echo
        continue
    fi
    
    # Check if password is empty
    if [[ -z "$MASTER_PASSWORD" ]]; then
        echo "✗ Password cannot be empty! Please try again."
        echo
        continue
    fi
    
    # Check password length
    if [[ ${#MASTER_PASSWORD} -lt 12 ]]; then
        echo "✗ Password must be at least 12 characters! (Received: ${#MASTER_PASSWORD})"
        echo "  Please try again with a longer password."
        echo
        continue
    fi
    
    # Password is valid, break the loop
    echo "✓ Password accepted (${#MASTER_PASSWORD} characters)"
    break
done

# Create encrypted credential
echo
echo "Creating encrypted credential..."

# Create temp file first, then rename (systemd-creds expects no extension in final path)
TEMP_CRED="${CRED_FILE}.tmp"

# Try TPM2 first, fallback to machine-id encryption
if sudo systemd-creds encrypt --name="$CRED_NAME" --with-key=tpm2 - "$TEMP_CRED" <<< "$MASTER_PASSWORD" 2>/dev/null; then
    sudo mv "$TEMP_CRED" "$CRED_FILE"
    echo "✓ Credential encrypted with TPM2"
    ENCRYPTION_METHOD="TPM2"
elif sudo systemd-creds encrypt --name="$CRED_NAME" --with-key=host - "$TEMP_CRED" <<< "$MASTER_PASSWORD" 2>/dev/null; then
    sudo mv "$TEMP_CRED" "$CRED_FILE"
    echo "✓ Credential encrypted with machine-id"
    ENCRYPTION_METHOD="machine-id"
else
    echo "✗ Failed to encrypt credential!"
    rm -f "$TEMP_CRED"
    exit 1
fi

# Set secure permissions
sudo chmod 600 "$CRED_FILE"
sudo chown root:root "$CRED_FILE"

echo
echo "✓ Encrypted credential created: $CRED_FILE"
echo "  Encryption: $ENCRYPTION_METHOD"
echo "  Size: $(du -h "$CRED_FILE" | cut -f1)"

# Verify decryption works
echo
echo "Verifying decryption..."
if sudo systemd-creds decrypt "$CRED_FILE" > /dev/null 2>&1; then
    echo "✓ Credential can be decrypted"
else
    echo "✗ Failed to decrypt credential!"
    exit 1
fi

# Update service file
SERVICE_FILE="/etc/systemd/system/brln-api.service"

if [[ -f "$SERVICE_FILE" ]]; then
    echo
    echo "Updating brln-api.service..."
    
    # Backup original
    sudo cp "$SERVICE_FILE" "${SERVICE_FILE}.backup-$(date +%s)"
    
    # Check if LoadCredential already exists
    if grep -q "LoadCredential=" "$SERVICE_FILE"; then
        echo "  Service already has LoadCredential directive"
    else
        # Add LoadCredential after [Service] (without .cred extension)
        sudo sed -i '/^\[Service\]/a LoadCredential=brln-master-password:/etc/credstore/brln-master-password' "$SERVICE_FILE"
        echo "✓ Added LoadCredential to service file"
    fi
    
    # Reload systemd
    sudo systemctl daemon-reload
    echo "✓ SystemD daemon reloaded"
    
    echo
    echo "Service file updated. Restart the service to apply:"
    echo "  sudo systemctl restart brln-api.service"
else
    echo
    echo "⚠️  Service file not found: $SERVICE_FILE"
    echo "  You'll need to manually add to your service:"
    echo "  LoadCredential=brln-master-password:/etc/credstore/brln-master-password"
fi

echo
echo "=== Setup Complete ==="
echo
echo "The master password is now securely stored as an encrypted credential."
echo "The service will load it from: \$CREDENTIALS_DIRECTORY/brln-master-password"
echo
echo "To view the encrypted credential:"
echo "  sudo systemd-creds decrypt $CRED_FILE"
echo
echo "To update the password, run this script again."
echo

# Clear sensitive variables
unset MASTER_PASSWORD
unset CONFIRM_PASSWORD
