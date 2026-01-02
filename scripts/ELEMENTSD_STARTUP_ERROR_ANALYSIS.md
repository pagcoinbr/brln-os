# Elements Daemon Startup Error Analysis

## Summary
The Elements daemon (`elementsd`) is failing to start due to **two distinct permission/configuration issues**:

1. **Tor Control Socket Permission Error**
2. **Bitcoin Core RPC Connection Failure**

---

## Issue 1: Tor Authentication Cookie Permission Denied

### Error Message
```
2026-01-02T07:11:23Z tor: Authentication cookie /run/tor/control.authcookie could not be opened (check permissions)
```

### Root Cause
The `elements` user does not have permission to access the Tor control socket and authentication cookie.

### Current State
```
-rw-r-----  1 debian-tor debian-tor   32 Jan  2 06:47 /run/tor/control.authcookie
drwxr-sr-x  2 debian-tor debian-tor      120 Jan  2 06:47 /run/tor/
```

- **Owner**: `debian-tor` user
- **Group**: `debian-tor` group
- **Permissions**: `640` (read-write for owner, read-only for group, nothing for others)
- **Current elements user groups**: `elements` and `users`

The `elements` user is **NOT** in the `debian-tor` group, so it cannot read the cookie file.

### Solution
Add the `elements` user to the `debian-tor` group:

```bash
sudo usermod -aG debian-tor elements
```

Then restart the Elements daemon:

```bash
sudo systemctl restart elementsd
```

---

## Issue 2: Bitcoin Core RPC Connection Failure

### Error Message
```
2026-01-02T07:11:23Z ERROR: Failure connecting to mainchain daemon RPC: 
Could not locate mainchain RPC credentials. No authentication cookie could 
be found, and no mainchainrpcpassword is set in the configuration file 
(elements.conf)
```

### Root Cause Analysis

The Elements daemon is configured with `validatepegin=1` in [elements.conf](conf_files/elements.conf), which means:
- Elements wants to validate pegin transactions (side-chain to mainchain transfers)
- To do this, it needs to connect to the Bitcoin Core (`bitcoind`) RPC interface
- However, the RPC connection parameters are **not properly configured**

### Current Configuration Issues

#### 1. Bitcoin Core RPC is NOT exposed for external connections

**File**: [bitcoin.conf](conf_files/bitcoin.conf)

The Bitcoin Core configuration does not explicitly configure:
- `rpcport` (defaults to 8332)
- `rpcbind` (defaults to localhost only)
- `rpcallowip` (not configured for Elements access)

This means Elements cannot connect to Bitcoin Core's RPC even if credentials were provided.

#### 2. Elements Configuration is Incomplete

**File**: [elements.conf](conf_files/elements.conf)

```bash
validatepegin=1  # ✓ Enabled
# mainchainrpchost=bitcoin.br-ln.com  # ✗ COMMENTED OUT
# mainchainrpcport=8085               # ✗ COMMENTED OUT
# mainchainrpcuser=                   # ✗ COMMENTED OUT
# mainchainrpcpassword=               # ✗ COMMENTED OUT
```

All the Bitcoin RPC connection parameters are **commented out**, so Elements cannot connect.

### Bitcoin Core Status

**Good News**: Bitcoin Core (`bitcoind`) **IS running**:
```
● bitcoind.service - Bitcoin Core Daemon
   Active: active (running) since Fri 2026-01-02 07:51:14 CET; 24min ago
   Main PID: 35658 (/usr/local/bin/bitcoind)
```

### Solution Options

Choose **ONE** of the following approaches:

#### Option A: Disable Pegin Validation (Simpler, if pegins not needed)

Modify [elements.conf](conf_files/elements.conf):

```bash
validatepegin=0  # Change from 1 to 0
```

This disables the requirement for Bitcoin Core RPC connection.

**Pros**: Simpler setup, fewer dependencies
**Cons**: Cannot validate pegin transactions from mainchain

#### Option B: Configure Bitcoin RPC Connection (Complete Setup)

1. **Configure Bitcoin Core** to expose RPC for Elements:

   Edit `/data/bitcoin/bitcoin.conf` and add/modify:
   ```bash
   rpcport=8332
   rpcallowip=127.0.0.1
   rpcallowip=::1
   ```

   Then restart Bitcoin Core:
   ```bash
   sudo systemctl restart bitcoind
   ```

2. **Get Bitcoin RPC credentials**:

   Bitcoin uses cookie-based authentication by default. The cookie is at:
   ```bash
   cat /data/bitcoin/.cookie
   ```

   Or if using user/password authentication, check:
   ```bash
   grep -E "^rpcuser|^rpcpassword" /data/bitcoin/bitcoin.conf
   ```

3. **Configure Elements** to connect to Bitcoin Core:

   Modify [elements.conf](conf_files/elements.conf):
   ```bash
   validatepegin=1
   mainchainrpchost=127.0.0.1
   mainchainrpcport=8332
   mainchainrpcuser=bitcoin_user
   mainchainrpcpassword=your_bitcoin_rpc_password
   ```

   **Pros**: Full functionality with pegin support
   **Cons**: Requires proper RPC credential management

---

## Recommended Fix Procedure

### Step 1: Fix Tor Permission Issue

```bash
sudo usermod -aG debian-tor elements
```

### Step 2: Choose and Implement One Configuration Option

**Option A (Recommended for simple setups):**
```bash
sudo sed -i 's/validatepegin=1/validatepegin=0/' /data/elements/elements.conf
```

**Option B (Recommended for full functionality):**
- Configure Bitcoin RPC and update Elements configuration with proper credentials

### Step 3: Restart Elements

```bash
sudo systemctl restart elementsd
```

### Step 4: Verify

```bash
journalctl -u elementsd -f
# OR
systemctl status elementsd
```

---

## Files Involved

| File | Issue | Status |
|------|-------|--------|
| [conf_files/elements.conf](conf_files/elements.conf) | RPC connection commented out, `validatepegin=1` | ⚠️ Needs config update |
| [conf_files/bitcoin.conf](conf_files/bitcoin.conf) | RPC not exposed for Elements | ⚠️ May need adjustment |
| `/run/tor/control.authcookie` | Permission denied | 🔴 Permission issue |
| Elements service | User not in `debian-tor` group | 🔴 Group issue |
| `bitcoind.service` | Running normally | ✅ OK |

---

## Summary Table

| Issue | Severity | Root Cause | Fix |
|-------|----------|-----------|-----|
| Tor cookie permission | Medium | `elements` user not in `debian-tor` group | Add user to group |
| RPC connection failure | High | `validatepegin=1` but no RPC configured | Disable pegin OR configure RPC |
| Incomplete config | High | Commented-out RPC parameters | Update elements.conf |

---

## Additional Notes

- The startup error for Tor is non-fatal if Tor is not required for your use case
- The RPC connection error is fatal when `validatepegin=1` is enabled
- Bitcoin Core is running successfully and has synced blocks (currently at height 252696)
- The system has proper infrastructure; only configuration needs adjustment
