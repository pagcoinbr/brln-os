#!/bin/sh

# Script to close all UFW ports except SSH (port 22)
# This ensures only SSH access remains open

echo "Starting UFW port closure script..."
echo "This will close all ports except SSH (port 22)"

# Reset UFW to clear all existing rules
echo "Resetting UFW..."
ufw --force reset

# Set default policies
echo "Setting default policies..."
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (port 22) - critical to maintain access
echo "Allowing SSH (port 22) both ways..."
ufw allow 22/tcp comment 'SSH access both directions'

# Enable UFW
echo "Enabling UFW..."
ufw --force enable

# Show final status
echo "UFW configuration complete. Current status:"
ufw status verbose

echo "Script completed successfully!"
echo "Only SSH (port 22) is now open for incoming connections."