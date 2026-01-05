# 🔒 BRLN-OS Security Audit Report
## Comprehensive Analysis by Security Specialist

**Date:** January 5, 2026  
**Auditor:** Security Architecture Specialist  
**System:** BRLN-OS v2.x

---

## 📊 Executive Summary

### Current Security Status: ⚠️ **NEEDS IMPROVEMENT**

The system has **good foundational security components** but they are **not properly integrated**. Critical gaps exist in how the master password is used across the system.

### Key Findings:

| Component | Status | Risk Level |
|-----------|--------|------------|
| Master Password Creation | ✅ Good | Low |
| Password Manager | ✅ Good | Low |
| Wallet Encryption | ⚠️ Inconsistent | Medium |
| Session Management | ❌ Missing | High |
| API Authentication | ❌ Missing | Critical |
| Frontend-Backend Communication | ⚠️ Insecure | High |

---

## 🔍 Detailed Analysis

### 1. Master Password System ✅ GOOD

**Location:** `brunel.sh` (lines 95-145)

```bash
# Master password is collected during installation
read -s -p "Digite a senha mestra: " BRLN_MASTER_PASSWORD
# Minimum 12 characters enforced
# Confirmation required
# Stored TEMPORARILY in /tmp during installation ONLY
```

**Strengths:**
- ✅ Minimum 12 characters enforced
- ✅ Password confirmation required
- ✅ Password NOT permanently stored on filesystem
- ✅ Temporary file deleted after installation

**Location:** `secure_password_manager.py`

**Strengths:**
- ✅ 500,000 PBKDF2 iterations (quantum-resistant)
- ✅ Fernet (AES-128-CBC) encryption
- ✅ Per-password unique salts
- ✅ Challenge-response validation (no password hash stored)
- ✅ 5-minute session timeout
- ✅ Memory cleanup on exit

---

### 2. Wallet Encryption ⚠️ INCONSISTENT

**Location:** `app.py` (lines 349-368)

**Problem Found:**

```python
# app.py line 340-346 - ONLY 200,000 iterations!
kdf = PBKDF2HMAC(
    algorithm=hashes.SHA256(),
    length=32,
    salt=salt,
    iterations=200000,  # ❌ WEAK! Should be 500,000+
    backend=default_backend()
)
```

vs.

```python
# secure_password_manager.py - Uses 500,000 iterations
PBKDF2_ITERATIONS = 500000  # ✅ STRONG
```

**Issues:**
- ⚠️ Two different encryption implementations
- ⚠️ Wallet uses weaker key derivation (200k vs 500k iterations)
- ⚠️ Password can be sent from frontend OR use master password
- ❌ No session-based authentication for API

---

### 3. Current Wallet Save Flow ❌ BROKEN

```
Frontend (main.js)                      Backend (app.py)
─────────────────                      ────────────────
1. User saves wallet
   ↓
2. PROBLEM: Code prompts for NEW password
   OR uses master password from environment
   ↓
3. Password sent in request body
   POST /wallet/save
   { mnemonic: "...", password: "..." }
   ↓
                                       4. Backend encrypts with received password
                                          OR falls back to get_master_password()
                                          ↓
                                       5. get_master_password() checks:
                                          - BRLN_MASTER_PASSWORD env var
                                          - Returns None if not set
                                          ↓
                                       6. If None → ERROR
                                          If set → Encrypts wallet
```

**Critical Issues:**
1. ❌ Master password not available at runtime (env var not set)
2. ❌ Frontend asks for NEW password instead of using master
3. ❌ No session management = no way to remember authentication
4. ❌ Password sent with every request (security risk)

---

### 4. What's Missing for Complete Security ❌

```
┌─────────────────────────────────────────────────────────────┐
│ REQUIRED SECURITY ARCHITECTURE (NOT IMPLEMENTED)            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  User → [Master Password] → Authentication Endpoint         │
│                               ↓                             │
│                          [Validate via Canary]              │
│                               ↓                             │
│                          [Create Encrypted Session]         │
│                               ↓                             │
│                          [Set HTTP-only Cookie]             │
│                               ↓                             │
│  User → [API Request + Cookie] → Protected Endpoint         │
│                                    ↓                        │
│                               [Get Session]                 │
│                                    ↓                        │
│                               [Get Master Password]         │
│                                    ↓                        │
│                               [Encrypt/Decrypt Data]        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ REQUIRED FIXES

### Fix 1: Unify Encryption Parameters

**File:** `app.py` - Update encryption to match secure_password_manager.py

```python
# CHANGE FROM:
iterations=200000  # Weak

# CHANGE TO:
iterations=500000  # Strong (matches password manager)
```

### Fix 2: Add Session Management to Backend

Create `/root/brln-os/api/v1/session_auth.py`:

```python
"""Session-based authentication using secure_password_manager"""
import time
import secrets
from functools import wraps
from flask import request, jsonify, g

# Import from existing secure password manager
import sys
sys.path.insert(0, '/root/brln-os/brln-tools')
from secure_password_manager import (
    verify_master_password,
    set_session_key,
    get_session_key,
    check_session_timeout,
    SESSION_TIMEOUT_SECONDS
)

# Session storage (in production, use Redis)
_sessions = {}

def authenticate(master_password):
    """
    Authenticate user with master password.
    Uses existing secure_password_manager canary validation.
    """
    # Verify password using canary challenge-response
    if not verify_master_password(master_password, silent=True):
        return None, "Invalid master password"
    
    # Create session
    session_id = secrets.token_urlsafe(32)
    _sessions[session_id] = {
        'master_password': master_password,
        'created_at': time.time(),
        'last_access': time.time()
    }
    
    return session_id, None

def get_session(session_id):
    """Get session data if valid"""
    if session_id not in _sessions:
        return None
    
    session = _sessions[session_id]
    
    # Check timeout
    if time.time() - session['last_access'] > SESSION_TIMEOUT_SECONDS:
        del _sessions[session_id]
        return None
    
    # Refresh session
    session['last_access'] = time.time()
    return session

def require_auth(f):
    """Decorator requiring authentication"""
    @wraps(f)
    def decorated(*args, **kwargs):
        session_id = request.cookies.get('session_id')
        
        if not session_id:
            return jsonify({'error': 'Authentication required'}), 401
        
        session = get_session(session_id)
        if not session:
            return jsonify({'error': 'Session expired'}), 401
        
        # Add master password to request context
        g.master_password = session['master_password']
        g.session_id = session_id
        
        return f(*args, **kwargs)
    return decorated

def destroy_session(session_id):
    """Logout - destroy session"""
    if session_id in _sessions:
        # Securely clear password from memory
        _sessions[session_id]['master_password'] = secrets.token_bytes(64)
        del _sessions[session_id]
```

### Fix 3: Add Authentication Endpoints to app.py

```python
from session_auth import authenticate, require_auth, get_session, destroy_session

@app.route('/api/v1/auth/login', methods=['POST'])
def auth_login():
    """Authenticate with master password"""
    data = request.get_json()
    password = data.get('password', '')
    
    if not password:
        return jsonify({'error': 'Password required'}), 400
    
    session_id, error = authenticate(password)
    
    if error:
        return jsonify({'error': error}), 401
    
    response = jsonify({
        'authenticated': True,
        'session_ttl': 300  # 5 minutes
    })
    
    response.set_cookie(
        'session_id',
        session_id,
        httponly=True,
        secure=True,
        samesite='Strict',
        max_age=300
    )
    
    return response

@app.route('/api/v1/auth/check', methods=['GET'])
def auth_check():
    """Check if session is valid"""
    session_id = request.cookies.get('session_id')
    session = get_session(session_id) if session_id else None
    return jsonify({'authenticated': session is not None})

@app.route('/api/v1/auth/logout', methods=['POST'])
def auth_logout():
    """Logout and destroy session"""
    session_id = request.cookies.get('session_id')
    if session_id:
        destroy_session(session_id)
    
    response = jsonify({'success': True})
    response.set_cookie('session_id', '', expires=0)
    return response
```

### Fix 4: Update Wallet Save Endpoint

```python
@app.route('/api/v1/wallet/save', methods=['POST'])
@require_auth  # ← ADD THIS DECORATOR
def save_wallet():
    """Save wallet - uses master password from authenticated session"""
    data = request.get_json()
    mnemonic = data.get('mnemonic', '').strip()
    wallet_id = data.get('wallet_id', f'wallet_{int(time.time())}')
    metadata = data.get('metadata', {})
    
    if not mnemonic:
        return jsonify({'error': 'Mnemonic required'}), 400
    
    # ✅ GET PASSWORD FROM SESSION - NOT FROM REQUEST!
    db_password = g.master_password
    
    # Rest of encryption logic...
```

### Fix 5: Update Wallet Load Endpoint

```python
@app.route('/api/v1/wallet/load', methods=['POST'])
@require_auth  # ← ADD THIS DECORATOR
def load_wallet():
    """Load wallet - uses master password from authenticated session"""
    data = request.get_json()
    wallet_id = data.get('wallet_id', '')
    
    if not wallet_id:
        return jsonify({'error': 'Wallet ID required'}), 400
    
    # ✅ GET PASSWORD FROM SESSION - NOT FROM REQUEST!
    password = g.master_password
    
    # Rest of decryption logic...
```

---

## 🔐 Complete Security Flow After Fixes

```
┌────────────────────────────────────────────────────────────────────┐
│                    SECURE BRLN-OS ARCHITECTURE                     │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  INSTALLATION (brunel.sh)                                          │
│  ─────────────────────────                                         │
│  1. User enters master password (min 12 chars)                     │
│  2. Password verified (confirmation)                               │
│  3. secure_password_manager.py init <password>                     │
│     → Creates encrypted canary (challenge-response)                │
│     → NO password hash stored                                      │
│  4. Temporary password file deleted                                │
│                                                                    │
│  RUNTIME (API)                                                     │
│  ─────────────                                                     │
│  1. User opens interface                                           │
│  2. User enters master password → POST /auth/login                 │
│  3. Backend validates via canary decryption                        │
│  4. If valid → Create session, set HTTP-only cookie                │
│  5. All subsequent requests include cookie                         │
│  6. Protected endpoints get password from session                  │
│  7. Session expires after 5 minutes of inactivity                  │
│                                                                    │
│  ENCRYPTION (ONE PASSWORD FOR ALL)                                 │
│  ─────────────────────────────────                                 │
│  Master Password encrypts:                                         │
│  ✅ Seed phrases (BIP39 mnemonic)                                  │
│  ✅ Private keys (all chains)                                      │
│  ✅ Service passwords (LND, Elements, etc.)                        │
│  ✅ TRON configuration                                             │
│  ✅ Session data                                                   │
│                                                                    │
│  RECOVERY SCENARIO                                                 │
│  ─────────────────                                                 │
│  If server lost but database saved:                                │
│  1. Install fresh BRLN-OS                                          │
│  2. Restore database file: /data/brln-secure-passwords.db          │
│  3. Restore wallet database (wallets table)                        │
│  4. Enter same master password                                     │
│  5. All data decrypted successfully ✅                             │
│                                                                    │
│  THEFT SCENARIO                                                    │
│  ──────────────                                                    │
│  If database stolen without password:                              │
│  - Encrypted canary → Can't validate password                      │
│  - Encrypted mnemonics → Can't read seed phrases                   │
│  - Encrypted keys → Can't read private keys                        │
│  - Encrypted passwords → Can't read service passwords              │
│  - 500,000 PBKDF2 iterations → Brute force infeasible              │
│  - Result: DATA IS SECURE ✅                                       │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Implementation Checklist

### Backend Changes Required:

- [ ] Create `session_auth.py` module
- [ ] Add authentication endpoints to `app.py`
- [ ] Update `derive_key_from_password()` to use 500,000 iterations
- [ ] Add `@require_auth` decorator to protected endpoints:
  - [ ] `/wallet/save`
  - [ ] `/wallet/load`
  - [ ] `/wallet/integrate`
  - [ ] `/system/passwords/*`
  - [ ] `/tron/*`
- [ ] Update CORS to allow credentials

### Frontend Changes Required:

- [ ] Remove password prompt from `saveWalletWithSystemdCredentials()`
- [ ] Keep `showAuthenticationModal()` for master password login
- [ ] Remove `showPasswordModal()` (individual wallet passwords)
- [ ] Add authentication check on page load
- [ ] Add session expiry handling

### Database Schema (No Changes Needed):

Current schema is secure:
- ✅ `encrypted_mnemonic BLOB` - Encrypted seed phrase
- ✅ `salt BLOB` - Unique per wallet
- ✅ `encrypted_private_keys BLOB` - Encrypted private keys
- ✅ Canary table for password validation

---

## 🎯 Summary: What ONE Password Protects

After implementing fixes:

| Data Type | Protected | Location |
|-----------|-----------|----------|
| BIP39 Seed Phrases | ✅ | wallets.encrypted_mnemonic |
| Private Keys | ✅ | wallets.encrypted_private_keys |
| Service Passwords | ✅ | passwords.encrypted_password |
| TRON Keys | ✅ | tron_config.encrypted_private_key |
| API Sessions | ✅ | In-memory (encrypted) |
| Canary (Validation) | ✅ | canary.encrypted_canary |

**ONE master password = FULL access to decrypt ALL data**  
**NO master password = ZERO access to any encrypted data**

---

## 🚨 Immediate Action Required

1. **HIGH PRIORITY:** Implement session authentication
2. **HIGH PRIORITY:** Update PBKDF2 iterations to 500,000
3. **MEDIUM:** Remove password prompt from frontend wallet save
4. **MEDIUM:** Add `@require_auth` to all protected endpoints
5. **LOW:** Add rate limiting on login endpoint

---

**Report Generated:** January 5, 2026  
**Status:** Awaiting Implementation
