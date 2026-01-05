# BRLN Background Installation Monitor

## Overview
The BRLN Background Installation Monitor is a cron-based task that periodically checks blockchain synchronization and automatically installs remaining components (LND, LNDG, PeerSwap, PSweb) when the system is ready.

## Features
- **Periodic Monitoring**: Checks Bitcoin blockchain sync status every hour via cron
- **Smart Installation**: Installs LND when blockchain is synced, then waits for LND graph sync
- **Auto-Cleanup**: Removes cron job automatically when all installations complete
- **Network Aware**: Supports both mainnet and testnet configurations
- **Lock File Protection**: Prevents multiple instances from running simultaneously
- **Detailed Logging**: All activities logged to `/var/log/brln-background-install.log`

## Installation Flow

1. **Initial Setup**: Cron job is installed after `show_installation_summary()` in brunel.sh
2. **Hourly Checks**: Cron runs the script every hour (0 * * * *)
3. **Blockchain Monitoring**: Checks blockchain sync status
4. **LND Installation**: Downloads and installs LND when blockchain is fully synced
5. **Graph Sync Wait**: Monitors LND graph synchronization
6. **Final Components**: Installs LNDG, PeerSwap, and PSweb
7. **Self-Removal**: Removes cron job automatically

## Cron Management

### Check Cron Job Status
```bash
crontab -l | grep install_in_background
```

### View Live Logs
```bash
tail -f /var/log/brln-background-install.log
```

### View All Logs
```bash
cat /var/log/brln-background-install.log
```

### Manual Control

Remove cron job manually:
```bash
crontab -l | grep -v "install_in_background.sh" | crontab -
```

Run script manually:
```bash
/bin/bash /root/brln-os/scripts/install_in_background.sh mainnet
```

Check if script is running:
```bash
ps aux | grep install_in_background
# or check lock file
cat /tmp/brln_background_install.lock
```

## Files

- **Script**: `/root/brln-os/scripts/install_in_background.sh`
- **Log File**: `/var/log/brln-background-install.log`
- **Lock File**: `/tmp/brln_background_install.lock`
- **Cron Job**: Installed in root's crontab

## Network Detection

The service automatically detects the network configuration:
- Checks `/data/bitcoin/bitcoin.conf` for `testnet=1`
- Defaults to mainnet if not specified
- Can be overridden by passing network as argument

## What Gets Installed

1. **LND** (Lightning Network Daemon)
   - Downloaded when blockchain is synced
   - Waits for graph synchronization

2. **LNDG** (LND GUI)
   - Web interface for LND management

3. **PeerSwap**
   - Submarine swap service for Lightning

4. **PSweb**
   - Web interface for PeerSwap

## Troubleshooting

### Cron Job Won't Run
Check cron service:
```bash
systemctl status cron
```

Check logs for errors:
```bash
tail -f /var/log/brln-background-install.log
```

### Manual Cleanup (if cron fails to auto-remove)
```bash
crontab -l | grep -v "install_in_background.sh" | crontab -
rm -f /tmp/brln_background_install.lock
```

### Re-run Manually
```bash
cd /root/brln-os
bash scripts/install_in_background.sh mainnet
# or for testnet:
bash scripts/install_in_background.sh testnet
```

### Check Lock File
If script won't run, check for stale lock:
```bash
cat /tmp/brln_background_install.lock
# If PID doesn't exist, remove it:
rm -f /tmp/brln_background_install.lock
```

## Timing Expectations

- **Blockchain Sync**: Hours to days (depends on hardware and network)
- **Cron Check Interval**: Every hour
- **LND Download**: 5-10 minutes
- **LND Graph Sync**: 30 minutes to several hours
- **Component Installation**: 10-20 minutes total

## Security

- Lock file prevents multiple instances
- Detailed logging for audit trail
- Runs as root (required for system-wide installations)
- Auto-cleanup when complete

## Auto-Removal

When all installations complete successfully, the script:
1. Removes the cron job from crontab
2. Cleans up lock file
3. Logs completion message

No manual cleanup required!
