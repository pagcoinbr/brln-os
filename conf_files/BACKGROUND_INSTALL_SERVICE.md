# BRLN Background Installation Service

## Overview
The BRLN Background Installation Service is a systemd daemon that monitors blockchain synchronization and automatically installs remaining components (LND, LNDG, PeerSwap, PSweb) when the system is ready.

## Features
- **Automatic Monitoring**: Continuously checks Bitcoin blockchain sync status
- **Smart Installation**: Installs LND when blockchain is synced, then waits for LND graph sync
- **Auto-Cleanup**: Removes itself automatically when all installations complete
- **Network Aware**: Supports both mainnet and testnet configurations

## Installation Flow

1. **Initial Setup**: Service is installed and started after `show_installation_summary()` in brunel.sh
2. **Blockchain Monitoring**: Checks blockchain sync every hour
3. **LND Installation**: Downloads and installs LND when blockchain is fully synced
4. **Graph Sync Wait**: Monitors LND graph synchronization
5. **Final Components**: Installs LNDG, PeerSwap, and PSweb
6. **Self-Removal**: Disables and removes the service automatically

## Service Management

### Check Service Status
```bash
systemctl status brln-background-install.service
```

### View Live Logs
```bash
journalctl -u brln-background-install.service -f
```

### View All Logs
```bash
journalctl -u brln-background-install.service
```

### Manual Service Control (if needed)

Stop the service:
```bash
systemctl stop brln-background-install.service
```

Restart the service:
```bash
systemctl restart brln-background-install.service
```

## Files

- **Service File**: Dynamically created at `/etc/systemd/system/brln-background-install.service`
- **Creation Function**: `create_background_install_service()` in [scripts/services.sh](../scripts/services.sh)
- **Script**: `/root/brln-os/scripts/install_in_background.sh`
- **Template** (deprecated): `/root/brln-os/conf_files/brln-background-install.service`

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

### Service Won't Start
Check logs for errors:
```bash
journalctl -u brln-background-install.service -n 50
```

### Manual Cleanup (if service fails to auto-remove)
```bash
systemctl stop brln-background-install.service
systemctl disable brln-background-install.service
rm /etc/systemd/system/brln-background-install.service
systemctl daemon-reload
```

### Re-run Manually
```bash
cd /root/brln-os
bash scripts/install_in_background.sh mainnet
# or for testnet:
bash scripts/install_in_background.sh testnet
```

## Timing Expectations

- **Blockchain Sync**: Hours to days (depends on hardware and network)
- **LND Download**: 5-10 minutes
- **LND Graph Sync**: 30 minutes to several hours
- **Component Installation**: 10-20 minutes total

## Security

The service runs with:
- `NoNewPrivileges=true` - Cannot gain new privileges
- `PrivateTmp=true` - Isolated temporary directory
- Root access required for system-wide installations

## Auto-Removal

When all installations complete successfully, the service:
1. Stops itself
2. Disables itself from auto-start
3. Removes the service file
4. Reloads systemd daemon

No manual cleanup required!
