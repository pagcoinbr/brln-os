# LND Password Automation with Secure Password Manager

## Overview
The BRLN-OS system now automatically manages LND wallet passwords using the secure password manager, eliminating the need for users to manually create and remember passwords.

## How It Works

### Automatic Password Generation Flow

```
┌─────────────────────────────────────────────────────────────┐
│  User clicks "Auto-Configure LND" in Wallet Interface       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  System checks for existing LND password in                 │
│  Secure Password Manager (service: lnd_wallet)              │
└────────────────────┬────────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
     Password              Password
      EXISTS               NOT FOUND
          │                     │
          ▼                     ▼
┌─────────────────────┐  ┌──────────────────────────────────┐
│  Retrieve existing  │  │  Generate new 24-char password   │
│  password from      │  │  using crypto.getRandomValues()  │
│  password manager   │  │                                  │
└──────┬──────────────┘  └──────────┬───────────────────────┘
       │                            │
       │                            ▼
       │                  ┌──────────────────────────────────┐
       │                  │  Store new password in           │
       │                  │  Secure Password Manager         │
       │                  │  via API: POST /system/passwords │
       │                  └──────────┬───────────────────────┘
       │                             │
       └──────────┬──────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│  Use password to create LND wallet via expect script        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  LND wallet configured with secure password                 │
└─────────────────────────────────────────────────────────────┘
```

## API Endpoints

### Get Password (Retrieve Existing)
```bash
GET /api/v1/system/passwords/get/<service_name>
```

**Example:**
```bash
curl http://localhost:2121/api/v1/system/passwords/get/lnd_wallet
```

**Response (Success):**
```json
{
  "success": true,
  "service_name": "lnd_wallet",
  "password": "ABC123def456GHI789jkl012"
}
```

**Response (Not Found):**
```json
{
  "success": false,
  "error": "Password not found for lnd_wallet"
}
```

### Store Password (New Password)
```bash
POST /api/v1/system/passwords/store
Content-Type: application/json

{
  "service_name": "lnd_wallet",
  "username": "lnd",
  "password": "your_secure_password",
  "description": "LND Wallet Password",
  "port": 8080,
  "url": "https://127.0.0.1:8080"
}
```

## JavaScript Implementation

The wallet interface automatically handles password management:

```javascript
// Get or generate LND wallet password
let walletPassword;

try {
  // Try to get existing password
  const passwordResponse = await fetch(`${API_BASE_URL}/system/passwords/get/lnd_wallet`);
  
  if (passwordResponse.ok) {
    const passwordData = await passwordResponse.json();
    if (passwordData.password) {
      walletPassword = passwordData.password;
      console.log('Retrieved existing LND wallet password');
    }
  }
} catch (error) {
  console.log('No existing LND password found');
}

// If no password exists, generate and store a new one
if (!walletPassword) {
  // Generate cryptographically secure 24-character password
  const array = new Uint8Array(18);
  crypto.getRandomValues(array);
  walletPassword = btoa(String.fromCharCode.apply(null, array)).substring(0, 24);
  
  // Store in secure password manager
  await fetch(`${API_BASE_URL}/system/passwords/store`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      service_name: 'lnd_wallet',
      username: 'lnd',
      password: walletPassword,
      description: 'LND Wallet Password',
      port: 8080,
      url: 'https://127.0.0.1:8080'
    })
  });
}

// Use password for LND configuration
await configureLND(walletPassword);
```

## Shell Script Integration

The LND setup script (bitcoin.sh) also uses the secure password manager:

```bash
# Generate wallet password
WALLET_PASS=$(openssl rand -base64 24)

# Store password securely in password manager
source "$SCRIPT_DIR/brln-tools/secure_password_manager.sh"
secure_store_password_full "lnd_wallet" "$WALLET_PASS" \
  "LND Wallet Password" "lnd" 8080 "https://127.0.0.1:8080"
```

## Security Features

1. **Automatic Generation**: 24-character passwords using cryptographically secure random values
2. **Secure Storage**: Passwords encrypted with PBKDF2-HMAC-SHA256 (500,000 iterations)
3. **Per-Password Salts**: Each password has a unique 32-byte salt
4. **No Plaintext Storage**: Passwords never stored in plaintext anywhere
5. **Session Management**: 5-minute in-memory cache with automatic timeout
6. **SystemD Integration**: Master password stored in encrypted SystemD credentials

## Benefits

### For Users:
- ✅ No need to remember LND wallet password
- ✅ No manual password entry during setup
- ✅ Passwords automatically generated and secured
- ✅ Seamless wallet integration

### For Administrators:
- ✅ Centralized password management
- ✅ Audit trail of password access
- ✅ Easy password rotation if needed
- ✅ Integration with other system services

## Password Retrieval

To retrieve the LND password from command line:

```bash
# Using Python
python3 /root/brln-os/brln-tools/secure_password_manager.py get lnd_wallet

# Using Shell wrapper
source /root/brln-os/brln-tools/secure_password_manager.sh
secure_get_password lnd_wallet

# Using API
curl http://localhost:2121/api/v1/system/passwords/get/lnd_wallet
```

## Troubleshooting

### Password Not Found
If the password is not found, the system will:
1. Generate a new secure password
2. Store it in the password manager
3. Use it for LND configuration

### Session Expired
If you get "session expired" errors:
1. The system will prompt for master password
2. Or use the unlock endpoint: `POST /api/v1/system/passwords/unlock`

### Permission Denied
Check database permissions:
```bash
sudo chmod 666 /data/brln-secure-passwords.db
sudo chown brln-api:brln-api /data/brln-secure-passwords.db
```

## Future Enhancements

- [ ] Automatic password rotation
- [ ] Password strength requirements configuration
- [ ] Multi-factor authentication for password retrieval
- [ ] Backup/restore of encrypted password database
- [ ] Integration with hardware security modules (HSM)

## Related Documentation

- [Secure Password Manager Guide](SECURE_PASSWORD_MANAGER.md)
- [SystemD Credentials Guide](SYSTEMD_CREDENTIALS_GUIDE.md)
- [Migration Guide](MIGRATION_TO_SECURE_PASSWORD_MANAGER.md)
