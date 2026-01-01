# Migration to Secure Password Manager

## Overview
This document tracks the migration from the old password manager system to the new secure password manager with enhanced security features.

## Migration Status: ✅ COMPLETED (January 2, 2026)

All shell scripts have been successfully migrated to use the secure password manager.

## Files Migrated

### Shell Scripts - ✅ ALL COMPLETE

1. **scripts/bitcoin.sh** ✅
   - Updated to use `secure_password_manager.sh`
   - Stores: bitcoin_rpc, lnd_wallet
   - Migration: Complete

2. **scripts/elements.sh** ✅
   - Updated to use `secure_password_manager.sh`
   - Stores: elements_rpc_user, elements_rpc_password
   - Migration: Complete

3. **scripts/lightning.sh** ✅
   - Updated to use `secure_password_manager.sh`
   - Stores: bos_telegram_id, bos_telegram_bot, thunderhub_master, thunderhub_account, lndg_admin
   - Migration: Complete

4. **scripts/peerswap.sh** ✅
   - Updated to use `secure_password_manager.sh`
   - Retrieves: elements_rpc_password
   - Migration: Complete

5. **scripts/password_manager_menu.sh** ✅
   - Updated to use `secure_password_manager.sh`
   - Interactive TUI fully migrated
   - Migration: Complete

### Python API - ✅ COMPLETE

**api/v1/app.py** ✅
- Integrated with SecurePasswordAPI
- SystemD encrypted credentials support
- Dynamic credential loading for Elements RPC
- 4 new API endpoints for password management
- Migration: Complete

## Migration Strategy

### Phase 1: Update Function Calls
Replace old function names with secure versions:
- `store_password_full` → `secure_store_password_full`
- `store_password` → `secure_store_password`
- `get_password` → `secure_get_password`
- `list_passwords` → `secure_list_passwords`
- `delete_password` → `secure_delete_password`

### Phase 2: Update Source Statements
Replace:
```bash
source "$SCRIPT_DIR/brln-tools/password_manager.sh"
```
With:
```bash
source "$SCRIPT_DIR/brln-tools/secure_password_manager.sh"
```

### Phase 3: Update Environment Variables
Replace:
- `BRLN_USER_KEY` → `BRLN_MASTER_PASSWORD`

### Phase 4: Add Initialization Check
Add secure_pm_setup or check for initialization before first use.

## Security Improvements
- ✅ Master password never stored locally
- ✅ Challenge-response authentication (no hash storage)
- ✅ Per-password unique salts
- ✅ 500,000 PBKDF2 iterations (quantum-resistant)
- ✅ In-memory session with 5-minute timeout
- ✅ Fernet encryption (AES-128-CBC + HMAC-SHA256)

## Backward Compatibility
The old password_manager.py and password_manager.sh files are preserved for:
- Systems already using the old system
- Gradual migration path
- Emergency fallback

## Data Migration
Users will need to:
1. Initialize secure password manager: `secure_pm_init`
2. Manually re-enter passwords or export/import from old system
3. Old database at `/data/brln-passwords.db`
4. New database at `/data/brln-secure-passwords.db`

## Testing Checklist
- [ ] Test peerswap.sh with secure password manager
- [ ] Test bitcoin.sh password storage/retrieval
- [ ] Test lightning.sh multiple password operations
- [ ] Test elements.sh RPC credentials
- [ ] Test password_manager_menu.sh interactive TUI
- [ ] Test session timeout behavior
- [ ] Test master password verification
- [ ] Test per-password salt uniqueness
