# BRLN-OS Services Migration

⚠️ **IMPORTANT CHANGE**: Static service files in this directory are deprecated!

## What Changed

Previously, BRLN-OS used static systemd service files that were copied from this directory. This approach had several limitations:
- Hardcoded paths
- No dynamic configuration
- Difficult to maintain consistency
- Required manual updates for different user configurations

## New Approach

All systemd services are now **dynamically generated** using `scripts/services.sh`:

```bash
# Create all services
./scripts/services.sh all

# Create specific service
./scripts/services.sh create bitcoind

# List available services
./scripts/services.sh list
```

## Benefits

✅ **Dynamic Configuration**: Services adapt to current user and system configuration
✅ **Consistent Security**: All services follow the same security patterns  
✅ **Dedicated Users**: Each service runs under its own dedicated user (bitcoin, lnd, elements, peerswap, brln-api)
✅ **Centralized Management**: All service definitions in one place
✅ **Easy Maintenance**: Update once, applies everywhere

## Migration Status

The following scripts have been updated to use `services.sh`:

- ✅ `brunel.sh` - brln-api service
- ✅ `scripts/bitcoin.sh` - bitcoind and lnd services  
- ✅ `scripts/elements.sh` - elementsd service
- ✅ `scripts/peerswap.sh` - peerswapd and psweb services
- ✅ `scripts/lightning.sh` - thunderhub, lndg, lndg-controller, bos-telegram services
- ✅ `scripts/gotty.sh` - gotty-fullauto service

## Supported Services

| Service | User | Purpose |
|---------|------|---------|  
| `bitcoind` | bitcoin | Bitcoin Core daemon |
| `lnd` | lnd | Lightning Network daemon |
| `elementsd` | elements | Elements/Liquid daemon |
| `peerswapd` | peerswap | PeerSwap daemon |
| `psweb` | peerswap | PeerSwap Web UI |
| `brln-api` | brln-api | BRLN-OS API service |
| `messager-monitor` | brln-api | Lightning message monitor |
| `gotty-fullauto` | root | Terminal web interface |
| `bos-telegram` | admin | Balance of Satoshis bot |
| `thunderhub` | admin | ThunderHub wallet |
| `lnbits` | admin | LNbits wallet |
| `lndg` | admin | Lightning dashboard |
| `lndg-controller` | admin | LNDG backend controller |

## Legacy Files

The static service files in this directory are kept for reference but are no longer used in active deployments. They will be removed in a future version.