# Backup and Recovery Guide - BRLN-OS Secure Password Manager

## Risk Assessment

### ⚠️ What Happens If Database Is Lost?

**YES - All stored passwords are PERMANENTLY LOST** if the database file is deleted or corrupted without backups:

```
/data/brln-secure-passwords.db is lost
    ↓
All encrypted passwords are GONE
    ↓
Must manually re-enter all service passwords
    ↓
Services may be inaccessible
```

### However, Some Redundancy Exists:

| Password | Primary Storage | Backup Location | Recovery |
|----------|----------------|-----------------|----------|
| Master Password | SystemD credentials | `/etc/credstore/brln-master-password.cred` | ✅ Recoverable |
| LND Wallet | Password Manager | `/data/lnd/password.txt` | ✅ Recoverable |
| Bitcoin RPC | Password Manager | `/data/bitcoin/bitcoin.conf` | ✅ Recoverable (if stored) |
| Elements RPC | Password Manager | `/data/elements/elements.conf` | ✅ Recoverable (if stored) |
| Other Services | Password Manager | ❌ No backup | ❌ **LOST** |

## Backup Strategy

### 1. Manual Backup

Create immediate backup:

```bash
sudo bash /root/brln-os/scripts/backup-password-manager.sh backup
```

**Output:**
```
🔐 BRLN-OS Password Manager Backup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Backup created successfully!

Backup Information:
  📁 File: /data/backups/passwords/brln-passwords-backup-20260102_001753.db
  📊 Size: 20K
  🔑 Passwords: 5
  🔐 Checksum: c7ae265c9acf5739...
```

### 2. List Available Backups

```bash
sudo bash /root/brln-os/scripts/backup-password-manager.sh list
```

### 3. Restore from Backup

```bash
sudo bash /root/brln-os/scripts/backup-password-manager.sh restore
```

Interactive restore process:
1. Lists available backups
2. Verifies checksum
3. Creates safety backup of current database
4. Restores selected backup
5. Sets proper permissions

### 4. Export (GPG Encrypted)

Create encrypted export with database + master password:

```bash
sudo bash /root/brln-os/scripts/backup-password-manager.sh export
```

Creates: `~/brln-passwords-export.tar.gz.gpg`

**Includes:**
- Password database
- SystemD master password credential
- Recovery instructions

## Automated Backups

### Cron Job (Daily at 2 AM)

```bash
# Add to root crontab
sudo crontab -e

# Add this line:
0 2 * * * /root/brln-os/scripts/backup-password-manager.sh backup >> /var/log/brln-password-backup.log 2>&1
```

### SystemD Timer (Recommended)

**Create timer unit:**

```bash
sudo tee /etc/systemd/system/brln-password-backup.timer << 'EOF'
[Unit]
Description=BRLN-OS Password Manager Daily Backup
Requires=brln-password-backup.service

[Timer]
OnCalendar=daily
OnBootSec=10min
Persistent=true

[Install]
WantedBy=timers.target
EOF
```

**Create service unit:**

```bash
sudo tee /etc/systemd/system/brln-password-backup.service << 'EOF'
[Unit]
Description=BRLN-OS Password Manager Backup

[Service]
Type=oneshot
ExecStart=/root/brln-os/scripts/backup-password-manager.sh backup
StandardOutput=journal
StandardError=journal
EOF
```

**Enable timer:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable brln-password-backup.timer
sudo systemctl start brln-password-backup.timer
```

**Check status:**

```bash
sudo systemctl status brln-password-backup.timer
sudo journalctl -u brln-password-backup.service
```

## Recovery Scenarios

### Scenario 1: Database Deleted

```bash
# 1. List backups
sudo bash /root/brln-os/scripts/backup-password-manager.sh list

# 2. Restore most recent
sudo bash /root/brln-os/scripts/backup-password-manager.sh restore

# 3. Restart API
sudo systemctl restart brln-api.service

# 4. Verify
curl http://localhost:2121/api/v1/system/passwords/status
```

### Scenario 2: Database Corrupted

```bash
# 1. Check integrity
sudo sqlite3 /data/brln-secure-passwords.db "PRAGMA integrity_check;"

# 2. If corrupted, restore from backup
sudo bash /root/brln-os/scripts/backup-password-manager.sh restore

# 3. Restart service
sudo systemctl restart brln-api.service
```

### Scenario 3: Master Password Lost

**If master password is lost but database exists:**

❌ **UNRECOVERABLE** - Encryption cannot be broken

**Options:**
1. Restore SystemD credential from backup export
2. Re-initialize password manager (lose all passwords)
3. Manually re-enter all service passwords

### Scenario 4: Complete System Failure

**With GPG export backup:**

```bash
# 1. Decrypt export
gpg -d brln-passwords-export.tar.gz.gpg | tar xz

# 2. Restore database
sudo cp brln-secure-passwords.db /data/
sudo chmod 666 /data/brln-secure-passwords.db
sudo chown brln-api:brln-api /data/brln-secure-passwords.db

# 3. Restore master password (if available)
sudo mkdir -p /etc/credstore
sudo cp brln-master-password.cred /etc/credstore/
sudo chmod 600 /etc/credstore/brln-master-password.cred

# 4. Restart services
sudo systemctl daemon-reload
sudo systemctl restart brln-api.service
```

## Backup Best Practices

### ✅ DO:

1. **Regular Backups**: Daily automated backups
2. **Off-site Storage**: Copy exports to external location
3. **Test Restores**: Periodically verify backups work
4. **Monitor Logs**: Check backup job logs regularly
5. **Secure Storage**: Protect backup files (they're encrypted but sensitive)
6. **Version Control**: Keep multiple backup versions (script keeps 10)

### ❌ DON'T:

1. **Store unencrypted**: Never store database in plaintext
2. **Share backups**: Don't email or upload to public cloud
3. **Ignore failures**: Monitor backup job status
4. **Delete all backups**: Always keep multiple versions
5. **Forget master password**: Store securely (password manager, vault)

## Backup Storage Locations

### Local (Default)
```
/data/backups/passwords/
├── brln-passwords-backup-20260102_001753.db
├── brln-passwords-backup-20260102_001753.db.sha256
├── brln-passwords-backup-20260101_020000.db
└── brln-passwords-backup-20260101_020000.db.sha256
```

### Remote (Recommended)

**Option 1: rsync to remote server**
```bash
# Add to cron after backup
rsync -avz --delete /data/backups/passwords/ user@backup-server:/backups/brln-os/
```

**Option 2: Cloud storage (encrypted)**
```bash
# Using rclone
rclone sync /data/backups/passwords/ remote:brln-backups/passwords/
```

**Option 3: USB drive**
```bash
# Mount USB
sudo mount /dev/sdb1 /mnt/usb

# Copy backups
sudo cp -r /data/backups/passwords/ /mnt/usb/brln-backups/

# Unmount
sudo umount /mnt/usb
```

## Monitoring and Alerts

### Check Last Backup

```bash
# List backups with dates
sudo bash /root/brln-os/scripts/backup-password-manager.sh list

# Check age of last backup
LAST_BACKUP=$(ls -t /data/backups/passwords/*.db 2>/dev/null | head -1)
if [[ -n "$LAST_BACKUP" ]]; then
    BACKUP_AGE=$(($(date +%s) - $(stat -c %Y "$LAST_BACKUP")))
    BACKUP_HOURS=$((BACKUP_AGE / 3600))
    echo "Last backup: $BACKUP_HOURS hours ago"
fi
```

### Alert if backup is old

```bash
# Add to monitoring script
if [[ $BACKUP_HOURS -gt 48 ]]; then
    echo "⚠️  WARNING: No backup in last 48 hours!"
    # Send alert (email, telegram, etc.)
fi
```

## Integration with brunel.sh

Add backup to installation:

```bash
# After password manager setup
echo "Creating initial backup..."
bash /root/brln-os/scripts/backup-password-manager.sh backup

# Setup automatic backups
sudo systemctl enable brln-password-backup.timer
sudo systemctl start brln-password-backup.timer
```

## Recovery Checklist

- [ ] Locate most recent backup
- [ ] Verify backup checksum
- [ ] Stop brln-api service
- [ ] Backup current database (if exists)
- [ ] Restore backup database
- [ ] Set correct permissions (666, brln-api:brln-api)
- [ ] Restart brln-api service
- [ ] Test password retrieval
- [ ] Verify all services can access passwords

## Emergency Contacts

If complete data loss occurs:

1. Check `/data/backups/passwords/` for local backups
2. Check off-site backup locations
3. Check SystemD credentials: `/etc/credstore/brln-master-password.cred`
4. Check service config files for hardcoded passwords:
   - `/data/bitcoin/bitcoin.conf`
   - `/data/elements/elements.conf`
   - `/data/lnd/password.txt`
5. Re-initialize password manager if no recovery possible
6. Manually re-enter all service passwords

## Security Considerations

### Backup Encryption

**Database:** Already encrypted with master password
**Export:** Additionally encrypted with GPG passphrase
**Transport:** Use encrypted channels (SSH, HTTPS)

### Access Control

```bash
# Backup directory permissions
sudo chmod 700 /data/backups/passwords/

# Backup file permissions
sudo chmod 600 /data/backups/passwords/*.db
```

### Audit Trail

Check backup operations:
```bash
# SystemD logs
sudo journalctl -u brln-password-backup.service -n 50

# Custom log
tail -f /var/log/brln-password-backup.log
```

## Related Documentation

- [Secure Password Manager](SECURE_PASSWORD_MANAGER.md)
- [SystemD Credentials](SYSTEMD_CREDENTIALS_GUIDE.md)
- [LND Password Automation](LND_PASSWORD_AUTOMATION.md)
