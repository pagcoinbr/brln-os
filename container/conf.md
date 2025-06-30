# Configuration Files

## Security Notice
⚠️ **IMPORTANT**: Never commit files with real credentials to the repository!

## Setup Instructions

1. Copy the `.example` files and rename them removing the `.example` extension:
   ```bash
   cp bitcoin.conf.example bitcoin.conf
   cp elements.conf.example elements.conf
   cp peerswap.conf.example peerswap.conf
   ```

2. Edit each configuration file with your actual credentials

3. The real configuration files are automatically ignored by git to prevent accidental commits

## Files Structure
- `*.conf.example` - Template files (safe to commit)
- `*.conf` - Real configuration files (automatically ignored by git)

## What's Protected
The following sensitive information is automatically excluded from git:
- RPC usernames and passwords
- Host addresses and ports
- ZMQ endpoints
- Mainchain credentials
- Elements daemon credentials
