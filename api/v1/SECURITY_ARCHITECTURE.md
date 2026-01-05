# BRLN-OS Security Architecture
## Master Password & Encryption System

---

## 🔐 Overview

BRLN-OS uses a **session-based authentication system** with a **master password** to secure all sensitive data including seed phrases, private keys, and application passwords.

---

## 🎯 Security Model

### Master Password Purpose

The master password created during `brunel.sh` installation is used to:

1. **Encrypt seed phrases** stored in the system
2. **Encrypt private keys** for all chains
3. **Encrypt application passwords** (LND, Elements, etc.)
4. **Create authenticated sessions** for API access

### Why Session-Based Authentication?

✅ **Password sent only once** via HTTPS during login  
✅ **Session encrypted server-side** with automatic expiration  
✅ **HTTP-only secure cookies** prevent XSS attacks  
✅ **No password in frontend** after authentication  
✅ **Automatic re-authentication** when session expires  
✅ **Audit trail** of all authentication events  

---

## 📋 Authentication Flow

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       │ 1. POST /api/v1/auth/login
       │    Body: { password: "master_password" }
       │    HTTPS (encrypted in transit)
       ▼
┌─────────────────┐
│   Backend API   │
└────────┬────────┘
         │
         │ 2. Validate password against stored hash
         │    (Password hashed with bcrypt/argon2)
         │
         │ 3. Create encrypted session
         │    - Generate session ID (UUID)
         │    - Encrypt master password with session key
         │    - Store in Redis/memory (TTL: 30 min)
         │
         │ 4. Set HTTP-only cookie
         │    - Name: session_id
         │    - Flags: HttpOnly, Secure, SameSite=Strict
         │
         ▼
┌─────────────┐
│   Browser   │ ← Cookie: session_id=abc123...
└─────────────┘
```

### Subsequent Requests

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       │ POST /api/v1/wallet/save
       │ Cookie: session_id=abc123...
       │ Body: { mnemonic: "seed words..." }
       ▼
┌─────────────────┐
│   Backend API   │
└────────┬────────┘
         │
         │ 1. Read session_id from cookie
         │ 2. Retrieve encrypted session from Redis
         │ 3. Decrypt session to get master password
         │ 4. Use master password to encrypt seed phrase
         │ 5. Store encrypted seed phrase in database
         │
         ▼
    Database: { wallet_id, encrypted_data, iv, salt }
```

---

## 🔒 Encryption Details

### Password Storage (Master Password Hash)

```python
# Stored in system during brunel.sh installation
master_password_hash = argon2.hash(user_password, salt, iterations=100000)

# Location: /home/brln-api/.brln/master_password_hash
# Permissions: 0600 (owner read/write only)
```

### Session Encryption

```python
# When user authenticates:
session_data = {
    'master_password': user_entered_password,  # Plain text in session
    'user_id': 'admin',
    'created_at': timestamp,
    'expires_at': timestamp + 1800  # 30 minutes
}

# Encrypt session data with session key
session_key = os.urandom(32)  # Random key per session
encrypted_session = AES256_GCM.encrypt(session_data, session_key)

# Store in Redis with TTL
redis.setex(
    f'session:{session_id}',
    1800,  # 30 minutes TTL
    encrypted_session
)
```

### Wallet Data Encryption

```python
# When saving wallet:
def save_wallet(mnemonic, wallet_id, session_id):
    # 1. Retrieve master password from session
    session = get_session(session_id)
    master_password = session['master_password']
    
    # 2. Derive encryption key from master password
    salt = os.urandom(16)
    key = PBKDF2(master_password, salt, iterations=600000, keylen=32)
    
    # 3. Encrypt mnemonic with AES-256-GCM
    iv = os.urandom(12)
    cipher = AES.new(key, AES.MODE_GCM, nonce=iv)
    encrypted_mnemonic, tag = cipher.encrypt_and_digest(mnemonic.encode())
    
    # 4. Store encrypted data
    wallet_data = {
        'wallet_id': wallet_id,
        'encrypted_data': base64.encode(encrypted_mnemonic),
        'salt': base64.encode(salt),
        'iv': base64.encode(iv),
        'tag': base64.encode(tag),
        'encryption_method': 'AES-256-GCM'
    }
    
    database.save(wallet_data)
```

### Decryption (Loading Wallet)

```python
def load_wallet(wallet_id, session_id):
    # 1. Get encrypted wallet from database
    wallet_data = database.get(wallet_id)
    
    # 2. Retrieve master password from session
    session = get_session(session_id)
    master_password = session['master_password']
    
    # 3. Derive same encryption key
    key = PBKDF2(
        master_password,
        base64.decode(wallet_data['salt']),
        iterations=600000,
        keylen=32
    )
    
    # 4. Decrypt mnemonic
    cipher = AES.new(key, AES.MODE_GCM, nonce=base64.decode(wallet_data['iv']))
    decrypted_mnemonic = cipher.decrypt_and_verify(
        base64.decode(wallet_data['encrypted_data']),
        base64.decode(wallet_data['tag'])
    )
    
    return decrypted_mnemonic.decode()
```

---

## 🛡️ Security Features

### 1. Defense in Depth

| Layer | Protection |
|-------|-----------|
| **Transport** | HTTPS/TLS 1.3 (all API requests encrypted) |
| **Authentication** | Master password + session management |
| **Authorization** | Session validation on every request |
| **Encryption** | AES-256-GCM for data at rest |
| **Key Derivation** | PBKDF2 with 600,000 iterations |
| **Session Storage** | Encrypted Redis with TTL |
| **Cookie Security** | HttpOnly, Secure, SameSite=Strict |

### 2. Session Security

- **Automatic Expiration**: Sessions expire after 30 minutes of inactivity
- **Encrypted Storage**: Session data encrypted at rest
- **Secure Cookies**: HTTP-only prevents JavaScript access
- **CSRF Protection**: SameSite=Strict prevents cross-site requests
- **Session Invalidation**: Logout immediately destroys session

### 3. Password Security

- **Never Logged**: Master password never written to logs
- **Hashed Storage**: Password hash stored with Argon2id
- **Salt Per User**: Unique salt for each password hash
- **High Iterations**: 100,000+ iterations for key derivation
- **Memory Protection**: Password cleared from memory after use

### 4. Audit Trail

All authentication events logged:
- Login attempts (success/failure)
- Session creation/expiration
- Password changes
- Encryption/decryption operations

---

## 🔄 Session Lifecycle

```
User Action              Backend State                    Session Status
─────────────────────────────────────────────────────────────────────────
Initial page load        No session                       ❌ Not authenticated
   ▼
Enter master password    Validate password                🔄 Authenticating
   ▼                     Create encrypted session
   ▼                     Set HTTP-only cookie             ✅ Authenticated
User saves wallet        Retrieve password from session   ✅ Active
   ▼                     Encrypt seed phrase
   ▼                     Save to database                 ✅ Active
30 minutes pass          Session expires in Redis         ⏱️  Expired
   ▼
User tries to save       Session not found                ❌ Re-authentication required
   ▼
Re-enter password        Create new session               ✅ Authenticated again
```

---

## 🚨 Threat Model & Mitigations

### Threat: Password Interception

**Attack**: Man-in-the-middle captures password during transmission  
**Mitigation**: HTTPS/TLS 1.3 encrypts all traffic  
**Additional**: Certificate pinning (optional)  

### Threat: Session Hijacking

**Attack**: Attacker steals session cookie  
**Mitigation**: HTTP-only cookies prevent JavaScript access  
**Additional**: Secure flag ensures HTTPS-only transmission  

### Threat: XSS (Cross-Site Scripting)

**Attack**: Malicious JavaScript tries to read password/session  
**Mitigation**: HTTP-only cookies, CSP headers  
**Additional**: Input sanitization on all forms  

### Threat: CSRF (Cross-Site Request Forgery)

**Attack**: Malicious site makes requests to API  
**Mitigation**: SameSite=Strict cookie flag  
**Additional**: CSRF tokens on state-changing requests  

### Threat: Database Breach

**Attack**: Attacker gains access to database  
**Mitigation**: All seed phrases encrypted with master password  
**Impact**: Attacker cannot decrypt without master password  

### Threat: Memory Dump

**Attack**: Attacker dumps server memory  
**Mitigation**: Sessions encrypted at rest  
**Additional**: Memory protection flags, session short TTL  

### Threat: Brute Force

**Attack**: Attacker tries many passwords  
**Mitigation**: Rate limiting on login endpoint (5 attempts/hour)  
**Additional**: Account lockout after 10 failed attempts  

---

## 🔧 Backend Implementation Requirements

### 1. Authentication Endpoint

```python
@app.route('/api/v1/auth/login', methods=['POST'])
def authenticate():
    """
    Authenticate user with master password.
    Creates encrypted session.
    """
    data = request.get_json()
    password = data.get('password')
    
    # Validate password
    if not verify_master_password(password):
        log_auth_attempt(success=False, ip=request.remote_addr)
        return jsonify({'error': 'Invalid password'}), 401
    
    # Create session
    session_id = str(uuid.uuid4())
    session_data = {
        'master_password': password,  # Stored encrypted
        'created_at': time.time(),
        'user_id': 'admin'
    }
    
    # Encrypt and store session
    save_encrypted_session(session_id, session_data, ttl=1800)
    
    # Set secure cookie
    response = jsonify({'authenticated': True})
    response.set_cookie(
        'session_id',
        session_id,
        httponly=True,
        secure=True,
        samesite='Strict',
        max_age=1800
    )
    
    log_auth_attempt(success=True, ip=request.remote_addr)
    return response
```

### 2. Session Check Endpoint

```python
@app.route('/api/v1/auth/check', methods=['GET'])
def check_auth():
    """Check if current session is valid."""
    session_id = request.cookies.get('session_id')
    
    if not session_id:
        return jsonify({'authenticated': False}), 401
    
    session = get_session(session_id)
    if not session:
        return jsonify({'authenticated': False}), 401
    
    return jsonify({'authenticated': True})
```

### 3. Protected Endpoint Decorator

```python
def require_auth(f):
    """Decorator to require authentication for endpoints."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        session_id = request.cookies.get('session_id')
        
        if not session_id:
            return jsonify({'error': 'Authentication required'}), 401
        
        session = get_session(session_id)
        if not session:
            return jsonify({'error': 'Session expired'}), 401
        
        # Add session to request context
        g.session = session
        g.master_password = session['master_password']
        
        return f(*args, **kwargs)
    
    return decorated_function

# Usage:
@app.route('/api/v1/wallet/save', methods=['POST'])
@require_auth
def save_wallet():
    """Save wallet - requires authentication."""
    master_password = g.master_password  # From session
    # ... encrypt and save wallet using master_password
```

### 4. Wallet Save (Updated)

```python
@app.route('/api/v1/wallet/save', methods=['POST'])
@require_auth
def save_wallet():
    """Save encrypted wallet using session authentication."""
    data = request.get_json()
    mnemonic = data.get('mnemonic')
    wallet_id = data.get('wallet_id')
    
    # Get master password from authenticated session
    master_password = g.master_password
    
    # Encrypt wallet with master password
    encrypted_wallet = encrypt_wallet_data(mnemonic, master_password)
    
    # Save to database
    save_to_database(wallet_id, encrypted_wallet)
    
    return jsonify({
        'status': 'success',
        'wallet_id': wallet_id,
        'encrypted': True
    })
```

---

## 📊 Comparison: systemd vs Session-Based

| Feature | systemd Credentials | Session-Based Auth |
|---------|--------------------|--------------------|
| **Password Entry** | Once at boot | Once per session (30 min) |
| **Security** | High (in-memory) | High (encrypted session) |
| **User Experience** | Manual boot | Automatic re-auth |
| **Timeout** | Never | 30 minutes |
| **Revocation** | Requires reboot | Immediate logout |
| **Audit Trail** | Limited | Complete |
| **2FA Support** | Difficult | Easy to add |
| **Web Access** | Complex | Native support |
| **Remote Access** | Challenging | Designed for it |

**Recommendation**: **Session-based authentication** is better for web-based systems like BRLN-OS.

---

## 🎯 Summary

### Your Questions Answered:

1. **Why ask for password again?**  
   → You should ask ONCE per session (30 min), not every time

2. **How can frontend encrypt without password?**  
   → It shouldn't! Backend encrypts using password from session

3. **Is encryption working correctly?**  
   → After implementing session-based auth, YES:
   - Password sent once over HTTPS
   - Stored encrypted in session
   - Used by backend for encryption
   - Never exposed to frontend

### Next Steps:

1. ✅ Implement backend session endpoints (`/auth/login`, `/auth/check`, `/auth/logout`)
2. ✅ Update wallet endpoints to require authentication
3. ✅ Add session management to frontend (already done above)
4. ✅ Test complete authentication flow
5. ✅ Add session timeout notifications
6. ✅ Implement audit logging

---

**Security is not a feature, it's a requirement.** 🔐
