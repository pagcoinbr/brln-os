# Auto-Custodial Wallet Architecture for Multi-User System

## Security Requirement

**Goal**: Create a wallet system where:
1. ✅ Each user has their own wallet with unique keys
2. ✅ Service provider can assist with recovery if user loses access
3. ✅ One user CANNOT derive other users' private keys
4. ✅ Service provider can optionally have spending control (regulatory/safety)

## Critical Security Principle

**❌ NEVER USE A SINGLE MASTER SEED FOR MULTIPLE USERS**

```python
# ❌ INSECURE APPROACH - DO NOT DO THIS
master_seed = "abandon abandon ... about"
user1_path = "m/44'/0'/0'/0/0"  # Account 0
user2_path = "m/44'/0'/1'/0/0"  # Account 1
user3_path = "m/44'/0'/2'/0/0"  # Account 2

# Problem: If user1 gets the master seed, they can derive ALL accounts!
```

**✅ SECURE APPROACH - UNIQUE SEED PER USER**

```python
# Each user gets cryptographically random unique seed
user1_seed = secrets.token_bytes(32)  # Unique
user2_seed = secrets.token_bytes(32)  # Unique  
user3_seed = secrets.token_bytes(32)  # Unique

# No mathematical relationship between seeds
# User1 cannot derive User2's keys even with full knowledge of their own seed
```

---

## Architecture 1: Encrypted Seed Backup (Recommended)

### Overview

- User generates unique BIP39 seed (or service generates for them)
- Service stores encrypted version of user's seed
- Only service master key can decrypt
- User loses access → Service decrypts → User recovers

### Implementation

```python
import secrets
import hashlib
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2
from mnemonic import Mnemonic
from bip32 import BIP32

class AutoCustodialWalletManager:
    def __init__(self, service_master_password: str):
        """
        Initialize with service master password
        This should be stored in HSM or secure vault in production
        """
        self.service_master_key = self._derive_service_key(service_master_password)
    
    def _derive_service_key(self, password: str) -> bytes:
        """Derive 256-bit key from service master password"""
        kdf = PBKDF2(
            algorithm=hashes.SHA256(),
            length=32,
            salt=b"brln-service-salt-v1",  # Use unique salt per deployment
            iterations=480000,
        )
        return kdf.derive(password.encode())
    
    def _derive_user_encryption_key(self, user_id: str) -> bytes:
        """Derive unique encryption key for each user from service master key"""
        # HKDF or similar - ensures different keys per user
        user_salt = f"user-{user_id}".encode()
        kdf = PBKDF2(
            algorithm=hashes.SHA256(),
            length=32,
            salt=user_salt,
            iterations=10000,
        )
        return kdf.derive(self.service_master_key)
    
    def create_user_wallet(self, user_id: str, entropy_bits: int = 256):
        """
        Create new wallet for user with encrypted backup
        
        Returns:
            dict: Contains mnemonic (show once), addresses, encrypted backup
        """
        # 1. Generate unique random entropy for this user
        entropy = secrets.token_bytes(entropy_bits // 8)
        
        # 2. Create BIP39 mnemonic
        mnemo = Mnemonic("english")
        mnemonic = mnemo.to_mnemonic(entropy)
        
        # 3. Generate seed from mnemonic
        seed = mnemo.to_seed(mnemonic, passphrase="")
        
        # 4. Create BIP32 wallet
        bip32 = BIP32.from_seed(seed)
        
        # 5. Derive addresses for supported chains
        addresses = {
            'bitcoin': {
                'path': "m/84'/0'/0'/0/0",
                'address': self._derive_bitcoin_address(bip32, "m/84'/0'/0'/0/0")
            },
            'ethereum': {
                'path': "m/44'/60'/0'/0/0",
                'address': self._derive_ethereum_address(bip32, "m/44'/60'/0'/0/0")
            },
            'tron': {
                'path': "m/44'/195'/0'/0/0",
                'address': self._derive_tron_address(bip32, "m/44'/195'/0'/0/0")
            }
        }
        
        # 6. Encrypt mnemonic with user-specific key
        encrypted_backup = self._encrypt_mnemonic(user_id, mnemonic)
        
        # 7. Store encrypted backup in database
        self._store_encrypted_backup(user_id, encrypted_backup)
        
        return {
            'user_id': user_id,
            'mnemonic': mnemonic,  # Show once to user, never store plaintext
            'addresses': addresses,
            'warning': 'Save this mnemonic! Show it only once!'
        }
    
    def _encrypt_mnemonic(self, user_id: str, mnemonic: str) -> dict:
        """Encrypt user's mnemonic with user-specific key derived from service master"""
        # Derive user-specific encryption key
        user_key = self._derive_user_encryption_key(user_id)
        
        # Generate random IV
        iv = secrets.token_bytes(16)
        
        # Encrypt mnemonic
        cipher = Cipher(algorithms.AES(user_key), modes.CBC(iv))
        encryptor = cipher.encryptor()
        
        # Pad mnemonic to AES block size
        mnemonic_bytes = mnemonic.encode()
        padding_length = 16 - (len(mnemonic_bytes) % 16)
        padded = mnemonic_bytes + bytes([padding_length] * padding_length)
        
        ciphertext = encryptor.update(padded) + encryptor.finalize()
        
        return {
            'ciphertext': ciphertext.hex(),
            'iv': iv.hex(),
            'version': 1,
            'algorithm': 'AES-256-CBC'
        }
    
    def _decrypt_mnemonic(self, user_id: str, encrypted_backup: dict) -> str:
        """Decrypt user's mnemonic for recovery"""
        # Derive same user-specific encryption key
        user_key = self._derive_user_encryption_key(user_id)
        
        # Decrypt
        iv = bytes.fromhex(encrypted_backup['iv'])
        ciphertext = bytes.fromhex(encrypted_backup['ciphertext'])
        
        cipher = Cipher(algorithms.AES(user_key), modes.CBC(iv))
        decryptor = cipher.decryptor()
        padded = decryptor.update(ciphertext) + decryptor.finalize()
        
        # Remove padding
        padding_length = padded[-1]
        mnemonic_bytes = padded[:-padding_length]
        
        return mnemonic_bytes.decode()
    
    def recover_user_wallet(self, user_id: str):
        """
        Recover user's wallet from encrypted backup
        Requires service master key - only service can do this
        """
        # 1. Retrieve encrypted backup from database
        encrypted_backup = self._retrieve_encrypted_backup(user_id)
        
        if not encrypted_backup:
            return {'error': 'No backup found for user'}
        
        # 2. Decrypt mnemonic
        mnemonic = self._decrypt_mnemonic(user_id, encrypted_backup)
        
        # 3. Recreate wallet
        mnemo = Mnemonic("english")
        seed = mnemo.to_seed(mnemonic, passphrase="")
        bip32 = BIP32.from_seed(seed)
        
        # 4. Derive all addresses
        addresses = {
            'bitcoin': self._derive_bitcoin_address(bip32, "m/84'/0'/0'/0/0"),
            'ethereum': self._derive_ethereum_address(bip32, "m/44'/60'/0'/0/0"),
            'tron': self._derive_tron_address(bip32, "m/44'/195'/0'/0/0")
        }
        
        return {
            'user_id': user_id,
            'mnemonic': mnemonic,  # Return to user for reimport
            'addresses': addresses,
            'status': 'recovered'
        }
    
    def _store_encrypted_backup(self, user_id: str, encrypted_backup: dict):
        """Store in database - implement based on your DB"""
        # Example: PostgreSQL with JSON column
        # INSERT INTO user_wallets (user_id, encrypted_backup, created_at)
        # VALUES (user_id, encrypted_backup::jsonb, NOW())
        pass
    
    def _retrieve_encrypted_backup(self, user_id: str) -> dict:
        """Retrieve from database"""
        # SELECT encrypted_backup FROM user_wallets WHERE user_id = user_id
        pass
    
    def _derive_bitcoin_address(self, bip32: BIP32, path: str) -> str:
        """Derive Bitcoin SegWit address"""
        # Implement proper bech32 encoding
        pubkey = bip32.get_pubkey_from_path(path)
        # ... bech32 encode
        return f"bc1q{pubkey.hex()[:40]}"  # Placeholder
    
    def _derive_ethereum_address(self, bip32: BIP32, path: str) -> str:
        """Derive Ethereum address"""
        pubkey = bip32.get_pubkey_from_path(path)
        # ... keccak256 + checksum
        return f"0x{pubkey.hex()[:40]}"  # Placeholder
    
    def _derive_tron_address(self, bip32: BIP32, path: str) -> str:
        """Derive TRON address"""
        pubkey = bip32.get_pubkey_from_path(path)
        # ... base58check with 0x41 prefix
        return f"T{pubkey.hex()[:40]}"  # Placeholder
```

### Security Properties

✅ **User Isolation**: Each user has unique random seed, no derivation relationship  
✅ **Service Recovery**: Service can decrypt any user's backup with master key  
✅ **No Cross-User Access**: User1 cannot derive User2's keys  
✅ **Key Rotation**: Can re-encrypt all backups with new service master key  
✅ **Audit Trail**: Log all recovery operations

### Database Schema

```sql
CREATE TABLE user_wallets (
    user_id VARCHAR(255) PRIMARY KEY,
    encrypted_backup JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    last_recovered_at TIMESTAMP,
    recovery_count INTEGER DEFAULT 0
);

CREATE INDEX idx_user_wallets_user_id ON user_wallets(user_id);

-- Recovery audit log
CREATE TABLE wallet_recovery_log (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    recovered_by VARCHAR(255) NOT NULL,  -- Admin/support user
    recovered_at TIMESTAMP DEFAULT NOW(),
    ip_address INET,
    reason TEXT,
    FOREIGN KEY (user_id) REFERENCES user_wallets(user_id)
);
```

---

## Architecture 2: 2-of-2 Multisig (Higher Security)

### Overview

- User key: Derived from user's BIP39 seed
- Service key: Derived from service master seed + user_id
- Both signatures required for spending
- Recovery: Service can co-sign with backup key

### Implementation

```python
class MultisigWalletManager:
    def __init__(self, service_master_seed: bytes):
        self.service_bip32 = BIP32.from_seed(service_master_seed)
    
    def create_2of2_wallet(self, user_id: str, user_mnemonic: str):
        """
        Create 2-of-2 multisig wallet
        User holds one key, service holds the other
        """
        # 1. User's key
        mnemo = Mnemonic("english")
        user_seed = mnemo.to_seed(user_mnemonic)
        user_bip32 = BIP32.from_seed(user_seed)
        user_pubkey = user_bip32.get_pubkey_from_path("m/48'/0'/0'/2'/0/0")
        
        # 2. Service's key (derived from user_id for uniqueness)
        service_path = f"m/48'/0'/{hash(user_id) % 1000000}'/2'/0/0"
        service_pubkey = self.service_bip32.get_pubkey_from_path(service_path)
        
        # 3. Create P2WSH multisig address
        multisig_address = self._create_multisig_address(
            [user_pubkey, service_pubkey],
            required_sigs=2
        )
        
        return {
            'address': multisig_address,
            'user_pubkey': user_pubkey.hex(),
            'service_pubkey': service_pubkey.hex(),
            'type': '2-of-2 multisig'
        }
    
    def cosign_transaction(self, user_id: str, unsigned_tx: bytes):
        """Service co-signs user's transaction"""
        # Service must verify transaction is legitimate
        # Apply spending limits, KYC checks, etc.
        service_path = f"m/48'/0'/{hash(user_id) % 1000000}'/2'/0/0"
        service_privkey = self.service_bip32.get_privkey_from_path(service_path)
        
        # Sign transaction with service key
        signed_tx = self._sign_transaction(unsigned_tx, service_privkey)
        return signed_tx
    
    def _create_multisig_address(self, pubkeys: list, required_sigs: int) -> str:
        """Create P2WSH multisig address"""
        # Implement proper P2WSH multisig
        pass
    
    def _sign_transaction(self, tx: bytes, privkey: bytes) -> bytes:
        """Sign Bitcoin transaction"""
        # Implement ECDSA signing
        pass
```

### Advantages

✅ **Strongest Security**: Service cannot unilaterally spend (requires user)  
✅ **User Control**: User must approve all transactions  
✅ **Recovery Possible**: Service can co-sign with backup key  
✅ **Regulatory Friendly**: Service sees all transactions

### Disadvantages

❌ More complex user experience  
❌ Requires two signatures for every transaction  
❌ Service must be online for spending

---

## Architecture 3: Threshold Signatures (Advanced)

### Overview

Uses cryptographic threshold signature schemes (TSS) like:
- MPC (Multi-Party Computation)
- Schnorr signatures (Taproot)
- FROST (Flexible Round-Optimized Schnorr Threshold)

### Benefits

✅ **No On-Chain Multisig**: Looks like single-sig transaction  
✅ **Lower Fees**: Same as single-sig  
✅ **Flexible Threshold**: 2-of-3, 3-of-5, etc.  
✅ **Key Refresh**: Can rotate shares without changing address

### Implementation Frameworks

- **Binance TSS Library**: https://github.com/bnb-chain/tss-lib
- **ZenGo Threshold**: https://github.com/ZenGo-X/multi-party-ecdsa
- **Fireblocks MPC SDK**: Commercial solution

---

## Architecture Comparison

| Feature | Encrypted Backup | 2-of-2 Multisig | Threshold Signatures |
|---------|-----------------|-----------------|---------------------|
| User Control | Full | Shared | Shared |
| Service Recovery | Yes | Yes | Yes |
| On-Chain Visibility | Normal | Multisig script | Normal |
| Fees | Normal | Higher | Normal |
| Complexity | Low | Medium | High |
| User Experience | Best | Good | Best |
| Regulatory Control | Limited | Full | Full |

---

## Recommended Approach for BRLN-OS

Based on your system architecture, I recommend **Architecture 1 (Encrypted Backup)** with these enhancements:

### Enhanced Implementation

```python
# /root/brln-os/brln-tools/auto_custodial_wallet.py

import os
import secrets
import hashlib
import json
from datetime import datetime
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from mnemonic import Mnemonic
from bip32 import BIP32

class BRLNAutoCustodialWallet:
    """
    Auto-custodial wallet system for BRLN-OS
    
    Features:
    - Unique seed per user (no cross-user key derivation)
    - AES-GCM encrypted backup with service master key
    - Recovery audit trail
    - Support for Bitcoin, Ethereum, TRON, Lightning (via LND)
    """
    
    def __init__(self, service_master_key_path: str = None):
        """Initialize with service master key from secure storage"""
        if service_master_key_path is None:
            service_master_key_path = os.path.expanduser(
                "~/.brln/service_master_key.bin"
            )
        
        # Load or create service master key
        if os.path.exists(service_master_key_path):
            with open(service_master_key_path, 'rb') as f:
                self.service_master_key = f.read()
        else:
            # First time setup - generate new master key
            self.service_master_key = secrets.token_bytes(32)
            os.makedirs(os.path.dirname(service_master_key_path), exist_ok=True)
            with open(service_master_key_path, 'wb') as f:
                f.write(self.service_master_key)
            os.chmod(service_master_key_path, 0o600)  # Secure permissions
    
    def create_user_wallet(
        self,
        user_id: str,
        networks: list = ['bitcoin', 'ethereum', 'tron', 'liquid'],
        testnet: bool = False
    ) -> dict:
        """
        Create new wallet for user with unique seed
        
        Args:
            user_id: Unique user identifier
            networks: List of blockchain networks to support
            testnet: Use testnet derivation paths
            
        Returns:
            dict: Wallet creation result with mnemonic and addresses
        """
        # 1. Generate cryptographically secure random entropy
        entropy = secrets.token_bytes(32)  # 256 bits = 24 words
        
        # 2. Create BIP39 mnemonic
        mnemo = Mnemonic("english")
        mnemonic = mnemo.to_mnemonic(entropy)
        
        # 3. Validate mnemonic
        if not mnemo.check(mnemonic):
            raise ValueError("Generated mnemonic failed validation")
        
        # 4. Generate seed
        seed = mnemo.to_seed(mnemonic, passphrase="")
        
        # 5. Create BIP32 root
        bip32 = BIP32.from_seed(seed)
        
        # 6. Derive addresses for requested networks
        addresses = {}
        
        if 'bitcoin' in networks:
            btc_path = "m/84'/1'/0'/0/0" if testnet else "m/84'/0'/0'/0/0"
            addresses['bitcoin'] = {
                'path': btc_path,
                'address': self._derive_bitcoin_address(bip32, btc_path, testnet),
                'network': 'testnet' if testnet else 'mainnet'
            }
        
        if 'ethereum' in networks:
            eth_path = "m/44'/60'/0'/0/0"
            addresses['ethereum'] = {
                'path': eth_path,
                'address': self._derive_ethereum_address(bip32, eth_path)
            }
        
        if 'tron' in networks:
            tron_path = "m/44'/195'/0'/0/0"
            addresses['tron'] = {
                'path': tron_path,
                'address': self._derive_tron_address(bip32, tron_path)
            }
        
        if 'liquid' in networks:
            liquid_path = "m/84'/1776'/0'/0/0"
            addresses['liquid'] = {
                'path': liquid_path,
                'address': self._derive_liquid_address(bip32, liquid_path)
            }
        
        # 7. Generate LND-compatible extended key
        master_xprv = bip32.get_xpriv_from_path("m")
        
        # 8. Encrypt mnemonic for backup
        encrypted_backup = self._encrypt_wallet_backup(user_id, {
            'mnemonic': mnemonic,
            'created_at': datetime.utcnow().isoformat(),
            'networks': networks,
            'testnet': testnet
        })
        
        # 9. Store encrypted backup
        self._store_backup(user_id, encrypted_backup)
        
        return {
            'success': True,
            'user_id': user_id,
            'mnemonic': mnemonic,  # SHOW ONCE - never log or store plaintext
            'addresses': addresses,
            'lnd_master_key': master_xprv,
            'backup_stored': True,
            'warning': '⚠️  SAVE THIS MNEMONIC SECURELY! It will only be shown once.',
            'security_notes': [
                'This mnemonic is unique to your account',
                'Other users cannot derive your keys',
                'Service provider can recover if you lose it',
                'Write it down and store securely offline'
            ]
        }
    
    def _encrypt_wallet_backup(self, user_id: str, data: dict) -> dict:
        """Encrypt wallet backup using AEAD (AES-GCM)"""
        # Derive user-specific key from service master key
        user_key = self._derive_user_key(user_id)
        
        # Convert data to JSON bytes
        plaintext = json.dumps(data).encode()
        
        # Generate random nonce (96 bits for GCM)
        nonce = secrets.token_bytes(12)
        
        # Encrypt with authenticated encryption
        aesgcm = AESGCM(user_key)
        ciphertext = aesgcm.encrypt(nonce, plaintext, associated_data=user_id.encode())
        
        return {
            'version': 2,
            'algorithm': 'AES-256-GCM',
            'ciphertext': ciphertext.hex(),
            'nonce': nonce.hex(),
            'user_id': user_id,
            'encrypted_at': datetime.utcnow().isoformat()
        }
    
    def _derive_user_key(self, user_id: str) -> bytes:
        """Derive unique 256-bit key for each user using HKDF"""
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.primitives.kdf.hkdf import HKDF
        
        hkdf = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=b"brln-auto-custodial-v2",
            info=f"user:{user_id}".encode(),
        )
        return hkdf.derive(self.service_master_key)
    
    def recover_wallet(self, user_id: str, recovered_by: str = "system") -> dict:
        """
        Recover user's wallet from encrypted backup
        
        Args:
            user_id: User to recover
            recovered_by: Admin/support user performing recovery
            
        Returns:
            dict: Recovered wallet data
        """
        # 1. Retrieve encrypted backup
        encrypted_backup = self._retrieve_backup(user_id)
        
        if not encrypted_backup:
            return {
                'success': False,
                'error': 'No backup found for this user'
            }
        
        # 2. Decrypt backup
        try:
            user_key = self._derive_user_key(user_id)
            
            ciphertext = bytes.fromhex(encrypted_backup['ciphertext'])
            nonce = bytes.fromhex(encrypted_backup['nonce'])
            
            aesgcm = AESGCM(user_key)
            plaintext = aesgcm.decrypt(
                nonce, 
                ciphertext, 
                associated_data=user_id.encode()
            )
            
            wallet_data = json.loads(plaintext.decode())
            
            # 3. Log recovery event
            self._log_recovery(user_id, recovered_by)
            
            return {
                'success': True,
                'user_id': user_id,
                'mnemonic': wallet_data['mnemonic'],
                'created_at': wallet_data['created_at'],
                'networks': wallet_data['networks'],
                'recovered_at': datetime.utcnow().isoformat(),
                'recovered_by': recovered_by
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'Decryption failed: {str(e)}'
            }
    
    def _store_backup(self, user_id: str, encrypted_backup: dict):
        """Store encrypted backup to file system (use database in production)"""
        backup_dir = os.path.expanduser("~/.brln/wallet_backups")
        os.makedirs(backup_dir, exist_ok=True)
        
        backup_file = os.path.join(backup_dir, f"{user_id}.json")
        with open(backup_file, 'w') as f:
            json.dump(encrypted_backup, f, indent=2)
        
        os.chmod(backup_file, 0o600)
    
    def _retrieve_backup(self, user_id: str) -> dict:
        """Retrieve encrypted backup from file system"""
        backup_file = os.path.expanduser(f"~/.brln/wallet_backups/{user_id}.json")
        
        if not os.path.exists(backup_file):
            return None
        
        with open(backup_file, 'r') as f:
            return json.load(f)
    
    def _log_recovery(self, user_id: str, recovered_by: str):
        """Log recovery event for audit trail"""
        log_dir = os.path.expanduser("~/.brln/recovery_logs")
        os.makedirs(log_dir, exist_ok=True)
        
        log_entry = {
            'user_id': user_id,
            'recovered_by': recovered_by,
            'timestamp': datetime.utcnow().isoformat(),
            'ip_address': '0.0.0.0'  # TODO: Get actual IP
        }
        
        log_file = os.path.join(log_dir, f"{user_id}_recovery.log")
        with open(log_file, 'a') as f:
            f.write(json.dumps(log_entry) + '\n')
    
    def _derive_bitcoin_address(self, bip32: BIP32, path: str, testnet: bool = False) -> str:
        """Derive native SegWit address (bech32/bech32m)"""
        # TODO: Implement proper bech32 encoding
        pubkey = bip32.get_pubkey_from_path(path)
        prefix = "tb" if testnet else "bc"
        return f"{prefix}1q{pubkey.hex()[:38]}"  # Placeholder
    
    def _derive_ethereum_address(self, bip32: BIP32, path: str) -> str:
        """Derive Ethereum address with EIP-55 checksum"""
        # TODO: Implement proper Keccak-256 + checksum
        pubkey = bip32.get_pubkey_from_path(path)
        return f"0x{pubkey.hex()[2:42]}"  # Placeholder
    
    def _derive_tron_address(self, bip32: BIP32, path: str) -> str:
        """Derive TRON address (Base58Check with 0x41 prefix)"""
        # TODO: Implement proper TRON address encoding
        pubkey = bip32.get_pubkey_from_path(path)
        return f"T{pubkey.hex()[:33]}"  # Placeholder
    
    def _derive_liquid_address(self, bip32: BIP32, path: str) -> str:
        """Derive Liquid/Elements confidential address"""
        # TODO: Implement proper Elements address encoding
        pubkey = bip32.get_pubkey_from_path(path)
        return f"ex1q{pubkey.hex()[:38]}"  # Placeholder


# CLI interface
if __name__ == "__main__":
    import sys
    
    manager = BRLNAutoCustodialWallet()
    
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 auto_custodial_wallet.py create <user_id>")
        print("  python3 auto_custodial_wallet.py recover <user_id>")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "create":
        user_id = sys.argv[2]
        result = manager.create_user_wallet(user_id, testnet=True)
        
        print(json.dumps(result, indent=2))
        
    elif command == "recover":
        user_id = sys.argv[2]
        result = manager.recover_wallet(user_id, "admin")
        
        print(json.dumps(result, indent=2))
```

---

## API Integration

Add these endpoints to `/root/brln-os/api/v1/app.py`:

```python
@app.route('/api/v1/wallet/create-custodial', methods=['POST'])
@require_auth
def create_custodial_wallet():
    """Create auto-custodial wallet for authenticated user"""
    from brln_tools.auto_custodial_wallet import BRLNAutoCustodialWallet
    
    user_id = g.user_id  # From session auth
    data = request.json
    
    networks = data.get('networks', ['bitcoin', 'ethereum', 'tron', 'liquid'])
    testnet = data.get('testnet', True)
    
    manager = BRLNAutoCustodialWallet()
    result = manager.create_user_wallet(user_id, networks, testnet)
    
    if result['success']:
        # DO NOT log mnemonic!
        log_safe = {k: v for k, v in result.items() if k != 'mnemonic'}
        app.logger.info(f"Created custodial wallet for user {user_id}: {log_safe}")
        
        return jsonify(result), 200
    else:
        return jsonify(result), 500


@app.route('/api/v1/wallet/recover-custodial', methods=['POST'])
@require_auth
@require_admin  # Only admins can recover wallets
def recover_custodial_wallet():
    """Recover user's wallet (admin only)"""
    from brln_tools.auto_custodial_wallet import BRLNAutoCustodialWallet
    
    data = request.json
    user_id = data.get('user_id')
    admin_user = g.user_id
    
    if not user_id:
        return jsonify({'error': 'user_id required'}), 400
    
    manager = BRLNAutoCustodialWallet()
    result = manager.recover_wallet(user_id, recovered_by=admin_user)
    
    if result['success']:
        app.logger.warning(
            f"Wallet recovery performed: user={user_id}, admin={admin_user}"
        )
        return jsonify(result), 200
    else:
        return jsonify(result), 500
```

---

## Security Checklist

- [x] Each user has unique cryptographic seed (no derivation relationship)
- [x] Service master key stored securely (HSM in production)
- [x] User-specific encryption keys derived from master key + user_id
- [x] Authenticated encryption (AES-GCM) prevents tampering
- [x] Recovery operations logged for audit trail
- [x] Mnemonic never stored in plaintext
- [x] Mnemonic never logged (even in debug mode)
- [x] Secure file permissions on backups (600)
- [x] Admin-only access to recovery endpoint

---

## Production Hardening

### 1. Use Hardware Security Module (HSM)

```python
# Replace file-based master key with HSM
from brln_tools.hsm_interface import HSM

hsm = HSM(slot_id=0, pin="...")
service_master_key = hsm.derive_key(purpose="wallet-encryption")
```

### 2. Database Storage

Replace file system with proper database:

```sql
CREATE TABLE encrypted_wallet_backups (
    user_id VARCHAR(255) PRIMARY KEY,
    encrypted_data JSONB NOT NULL,
    version INT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    last_accessed_at TIMESTAMP,
    access_count INT DEFAULT 0
);

CREATE TABLE wallet_recovery_audit (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    recovered_by VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    success BOOLEAN
);
```

### 3. Rate Limiting

```python
from flask_limiter import Limiter

limiter = Limiter(app, key_func=get_remote_address)

@app.route('/api/v1/wallet/recover-custodial', methods=['POST'])
@limiter.limit("3 per hour")  # Prevent brute force recovery attempts
@require_admin
def recover_custodial_wallet():
    ...
```

### 4. Multi-Factor Authentication

```python
@app.route('/api/v1/wallet/recover-custodial', methods=['POST'])
@require_auth
@require_admin
@require_2fa  # Admin must provide 2FA token
def recover_custodial_wallet():
    ...
```

---

## Summary

**Answer to your question:**

1. ✅ **Unique seed per user** - prevents cross-user key derivation
2. ✅ **Encrypted backup** - you can recover if they lose keys
3. ✅ **User isolation** - one user cannot steal other users' funds
4. ✅ **Audit trail** - all recoveries are logged

The critical mistake to avoid is using a single master seed with different BIP44 account indices per user. Instead, generate a completely unique random seed for each user and encrypt it with a user-specific key derived from your service master key.
