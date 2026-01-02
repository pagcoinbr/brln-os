# SystemD Encrypted Credentials for Secure Password Manager

This guide explains how to securely store and use the master password for the BRLN-OS secure password manager using SystemD's encrypted credentials feature.

## Overview

SystemD encrypted credentials provide a secure way to store sensitive data that services need at startup. The credentials are:

- **Encrypted with TPM2** (if available) or machine-id as fallback
- **Stored in `/etc/credstore/`** with strict permissions (600)
- **Automatically decrypted** by SystemD when service starts
- **Available in environment** via `$CREDENTIALS_DIRECTORY`
- **Never exposed** in systemctl status or process list

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Master Password (Plain Text - User Input)                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  systemd-creds encrypt                                      │
│  • Uses TPM2 chip (hardware encryption)                     │
│  • Falls back to machine-id (software encryption)           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  /etc/credstore/brln-master-password.cred                   │
│  • Binary encrypted file (600 permissions)                  │
│  • Only readable by root                                    │
│  • Machine-specific encryption                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  brln-api.service (SystemD Unit)                            │
│  LoadCredential=brln-master-password                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Service Runtime Environment                                │
│  • $CREDENTIALS_DIRECTORY/brln-master-password              │
│  • Decrypted automatically by SystemD                       │
│  • Only accessible by service process                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Flask API (app.py)                                         │
│  • Reads from $CREDENTIALS_DIRECTORY/brln-master-password   │
│  • Initializes SecurePasswordAPI                            │
│  • Never stores in logs or memory dumps                     │
└─────────────────────────────────────────────────────────────┘
```

## Setup Process

### 1. Run the Setup Script

```bash
sudo bash /root/brln-os/scripts/setup-systemd-credentials.sh
```

The script will:
1. Check for systemd-creds tool (systemd v250+)
2. Prompt for master password (min 12 characters)
3. Encrypt password with TPM2 or machine-id
4. Store encrypted credential in `/etc/credstore/`
5. Update `brln-api.service` with `LoadCredential` directive
6. Reload SystemD daemon
7. Verify credential can be decrypted
8. Create backup of service file

### 2. What Happens During Setup

**Input Validation:**
```
Enter master password (min 12 chars): ****************
Confirm master password: ****************
```

**Encryption (TPM2):**
```
Encrypting with TPM2...
Credential stored: /etc/credstore/brln-master-password.cred
Encryption: TPM2 hardware-backed
```

**Service Update:**
```
[Service]
LoadCredential=brln-master-password:/etc/credstore/brln-master-password.cred
```

**Verification:**
```
✅ Credential successfully decrypted
✅ Setup completed successfully
```

### 3. Restart Service

```bash
sudo systemctl restart brln-api.service
```

### 4. Verify Loading

```bash
# Check service logs
sudo journalctl -u brln-api.service -n 20

# Expected output:
# "Master password loaded from SystemD encrypted credentials"
# "Secure Password Manager API initialized"
```

## Security Features

### Encryption Methods

**TPM2 (Preferred):**
- Hardware-backed encryption using Trusted Platform Module
- Cryptographic keys never leave TPM chip
- Protection against offline attacks
- Machine-specific binding

**Machine-ID Fallback:**
- Uses `/etc/machine-id` as encryption key
- Software-based encryption (AES-256-GCM)
- Machine-specific binding
- Protects against credential theft to other machines

### File Permissions

```bash
# Credential store directory
drwx------ root root /etc/credstore/

# Encrypted credential file
-rw------- root root /etc/credstore/brln-master-password.cred
```

### Runtime Security

- Credential only decrypted when service starts
- Available only to service process (not parent shell)
- Not visible in `systemctl status` or `ps aux`
- Not included in core dumps
- Automatically removed when service stops

## API Integration

### Automatic Master Password Loading

The Flask API (`app.py`) automatically loads master password from SystemD credentials:

```python
def get_master_password_from_credentials():
    """
    Get master password from SystemD encrypted credentials or environment variable.
    Priority: SystemD Credentials -> Environment Variable
    """
    # Try SystemD credentials first
    credentials_dir = os.environ.get('CREDENTIALS_DIRECTORY')
    if credentials_dir:
        cred_file = Path(credentials_dir) / 'brln-master-password'
        if cred_file.exists():
            with open(cred_file, 'r') as f:
                password = f.read().strip()
                return password
    
    # Fallback to environment variable
    return os.environ.get('BRLN_MASTER_PASSWORD')
```

### API Endpoints

**Check Status:**
```bash
curl http://localhost:2121/api/v1/system/passwords/status
```

**Unlock Session (Manual):**
```bash
curl -X POST http://localhost:2121/api/v1/system/passwords/unlock \
  -H "Content-Type: application/json" \
  -d '{"master_password": "your_master_password"}'
```

**Store Password:**
```bash
curl -X POST http://localhost:2121/api/v1/system/passwords/store \
  -H "Content-Type: application/json" \
  -d '{
    "service_name": "bitcoin_rpc",
    "username": "admin",
    "password": "secure_password_here"
  }'
```

**List Services:**
```bash
curl http://localhost:2121/api/v1/system/passwords/list
```

## Troubleshooting

### Master Password Not Loading

**Check service environment:**
```bash
sudo systemctl show brln-api.service | grep -i credential
```

Expected output:
```
LoadCredential=brln-master-password:/etc/credstore/brln-master-password.cred
```

**Check credential file exists:**
```bash
ls -la /etc/credstore/brln-master-password.cred
```

**Manual decryption test:**
```bash
sudo systemd-creds decrypt /etc/credstore/brln-master-password.cred -
```

### Service Won't Start

**Check logs:**
```bash
sudo journalctl -u brln-api.service -n 50 --no-pager
```

**Common issues:**
- Credential file missing or wrong permissions
- SystemD version too old (need v250+)
- TPM2 device not accessible

**Fix permissions:**
```bash
sudo chmod 600 /etc/credstore/brln-master-password.cred
sudo chown root:root /etc/credstore/brln-master-password.cred
```

### Re-encrypt Credential

If you need to change master password:

```bash
# Delete old credential
sudo rm /etc/credstore/brln-master-password.cred

# Run setup again
sudo bash /root/brln-os/scripts/setup-systemd-credentials.sh

# Restart service
sudo systemctl restart brln-api.service
```

## Migration from Environment Variable

If you previously stored master password in environment variable:

**Old method (in service file):**
```ini
[Service]
Environment="BRLN_MASTER_PASSWORD=your_password"
```

**New method (encrypted credential):**
```ini
[Service]
LoadCredential=brln-master-password:/etc/credstore/brln-master-password.cred
```

**Migration steps:**
1. Run `setup-systemd-credentials.sh`
2. Remove `Environment="BRLN_MASTER_PASSWORD=..."` from service file
3. Restart service

The API code supports both methods with automatic fallback.

## Backup and Recovery

### Backup Credential

```bash
# Encrypted credential (safe to backup)
sudo cp /etc/credstore/brln-master-password.cred \
       /backup/brln-master-password.cred.backup

# Service file backup (created automatically by setup script)
/etc/systemd/system/brln-api.service.backup.<timestamp>
```

### Recovery

```bash
# Restore encrypted credential
sudo cp /backup/brln-master-password.cred.backup \
       /etc/credstore/brln-master-password.cred

sudo chmod 600 /etc/credstore/brln-master-password.cred
sudo chown root:root /etc/credstore/brln-master-password.cred

# Restart service
sudo systemctl restart brln-api.service
```

**Important:** Encrypted credentials are machine-specific. Restoring to a different machine requires re-encryption with `setup-systemd-credentials.sh`.

## Best Practices

1. **Never store plain text password** in service files or scripts
2. **Use TPM2 encryption** when available (hardware security)
3. **Backup encrypted credential** regularly
4. **Rotate master password** periodically
5. **Monitor service logs** for authentication issues
6. **Test credential loading** after any system updates
7. **Document recovery procedures** for disaster recovery

## Security Comparison

| Method | Security | Convenience | Migration |
|--------|----------|-------------|-----------|
| **SystemD Credentials (TPM2)** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Complex |
| **SystemD Credentials (machine-id)** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Complex |
| **Environment Variable** | ⭐⭐ | ⭐⭐⭐⭐⭐ | None |
| **Config File** | ⭐ | ⭐⭐⭐ | Simple |

## References

- [SystemD Credentials Documentation](https://systemd.io/CREDENTIALS/)
- [systemd-creds man page](https://www.freedesktop.org/software/systemd/man/systemd-creds.html)
- [TPM2 Security Features](https://trustedcomputinggroup.org/resource/tpm-2-0-a-brief-introduction/)

## Support

For issues or questions:
1. Check service logs: `sudo journalctl -u brln-api.service`
2. Verify credential decryption: `sudo systemd-creds decrypt <file> -`
3. Review this guide: `/root/brln-os/SYSTEMD_CREDENTIALS_GUIDE.md`
4. Check API status: `curl http://localhost:2121/api/v1/system/passwords/status`
