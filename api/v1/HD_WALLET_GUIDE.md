# HD Wallet Implementation Guide (BIP39/BIP32/BIP44)

## Understanding the Standards

### BIP39 - Mnemonic Code for Generating Deterministic Keys
- Converts random entropy (128-256 bits) into human-readable words (12-24 words)
- Adds checksum for error detection
- Uses PBKDF2 to stretch mnemonic + passphrase into 512-bit seed

### BIP32 - Hierarchical Deterministic Wallets
- Creates tree structure of keys from a single seed
- Master private key + chain code = Extended Private Key (xprv)
- Master public key + chain code = Extended Public Key (xpub)
- Allows deriving child keys deterministically

### BIP44 - Multi-Account Hierarchy
- Defines standard derivation path structure
- Format: `m / purpose' / coin_type' / account' / change / address_index`
- Purpose = 44' (for BIP44)

## Correct Implementation Flow

### 1. Generate Entropy (128 or 256 bits)

```python
import secrets

# For 12-word mnemonic (recommended minimum)
entropy_128 = secrets.token_bytes(16)  # 128 bits = 16 bytes

# For 24-word mnemonic (more secure)
entropy_256 = secrets.token_bytes(32)  # 256 bits = 32 bytes
```

**Why this is secure:**
- `secrets.token_bytes()` uses OS-level cryptographically secure random number generator
- No need to mix multiple entropy sources (can reduce entropy if done incorrectly)
- 128 bits provides 2^128 possibilities (astronomically large)

### 2. Convert Entropy to Mnemonic (BIP39)

```python
from mnemonic import Mnemonic

mnemo = Mnemonic("english")
seed_phrase = mnemo.to_mnemonic(entropy_128)
# Returns: "army van defense carry jealous true garbage claim echo media make crunch"

# Verify mnemonic is valid
is_valid = mnemo.check(seed_phrase)
```

**What happens internally:**
1. Takes entropy bits
2. Calculates SHA256 hash of entropy
3. Adds first few bits of hash as checksum
4. Splits combined bits into 11-bit segments
5. Maps each segment to word from 2048-word list

### 3. Generate Seed from Mnemonic (PBKDF2)

```python
# Optional passphrase adds additional security layer
passphrase = ""  # or "MySecretPassphrase"

# Generate 512-bit seed using PBKDF2-HMAC-SHA512
seed = mnemo.to_seed(seed_phrase, passphrase)
# Returns 64 bytes (512 bits)
```

**Important notes:**
- **Every passphrase is valid** - different passphrases create different wallets
- No passphrase = salt is "mnemonic"
- With passphrase = salt is "mnemonic" + passphrase
- 2048 rounds of PBKDF2-HMAC-SHA512

### 4. Create BIP32 Master Keys from Seed

```python
from bip32 import BIP32

# Generate master private key and chain code
bip32 = BIP32.from_seed(seed)

# Access master keys
master_private_key = bip32.get_privkey_from_path("m")
master_public_key = bip32.get_pubkey_from_path("m")

# Extended keys include chain code
xprv = bip32.get_xpriv_from_path("m")  # Base58check encoded
xpub = bip32.get_xpub_from_path("m")   # Base58check encoded
```

**Master key generation:**
```
I = HMAC-SHA512(Key = "Bitcoin seed", Data = seed)
master_secret_key = I_L (left 256 bits)
master_chain_code = I_R (right 256 bits)
```

### 5. Derive Child Keys Using BIP44 Paths

```python
# BIP44 Standard Paths:
# m / 44' / coin_type' / account' / change / address_index

# Bitcoin paths
bitcoin_receiving = "m/44'/0'/0'/0/0"   # First Bitcoin receiving address
bitcoin_change = "m/44'/0'/0'/1/0"       # First Bitcoin change address
bitcoin_account2 = "m/44'/0'/1'/0/0"     # Second account, first address

# Ethereum
ethereum_path = "m/44'/60'/0'/0/0"

# Derive keys
private_key = bip32.get_privkey_from_path(bitcoin_receiving)
public_key = bip32.get_pubkey_from_path(bitcoin_receiving)
```

**Path notation:**
- `'` (apostrophe) = hardened derivation (uses 0x80000000 + index)
- No `'` = normal derivation
- Hardened = more secure, prevents parent key recovery from child
- Use hardened for purpose, coin_type, and account levels

### 6. Generate Addresses from Public Keys

Different blockchains use different address formats:

```python
import hashlib
import base58

def generate_bitcoin_p2wpkh_address(public_key):
    """Generate native SegWit (bech32) address"""
    # Public key hash
    sha256_hash = hashlib.sha256(public_key).digest()
    ripemd160_hash = hashlib.new('ripemd160', sha256_hash).digest()
    
    # Bech32 encoding with witness version 0
    # This is simplified - use proper bech32 library
    return encode_bech32("bc", 0, ripemd160_hash)

def generate_ethereum_address(public_key):
    """Generate Ethereum address from public key"""
    # Remove 0x04 prefix if present
    if len(public_key) == 65:
        public_key = public_key[1:]
    
    # Keccak-256 hash
    from Crypto.Hash import keccak
    k = keccak.new(digest_bits=256)
    k.update(public_key)
    address_bytes = k.digest()[-20:]  # Last 20 bytes
    
    # Checksum (EIP-55)
    address_hex = address_bytes.hex()
    checksum = keccak.new(digest_bits=256, data=address_hex.encode()).hexdigest()
    
    checksummed = '0x'
    for i, char in enumerate(address_hex):
        if char in '0123456789':
            checksummed += char
        else:
            checksummed += char.upper() if int(checksum[i], 16) >= 8 else char
    
    return checksummed
```

## Security Best Practices

### 1. Entropy Generation
- ✅ Use `secrets.token_bytes()` - it's designed for cryptographic use
- ❌ Don't use `random.randint()` - not cryptographically secure
- ❌ Don't let users type their own words - humans are bad random sources
- ✅ 128 bits (12 words) is sufficient security for most use cases
- ✅ 256 bits (24 words) provides extra security margin

### 2. Mnemonic Storage
- ✅ Write on paper, store in safe place
- ✅ Use metal plates for fire/water resistance
- ✅ Consider multi-location backup
- ❌ Don't store in plain text on computer
- ❌ Don't take photos of it
- ❌ Don't store in cloud without encryption

### 3. Passphrase Usage
- ✅ Adds second factor of security
- ✅ Every passphrase creates valid (but different) wallet
- ⚠️ If forgotten, funds are lost forever
- ⚠️ Can't prove you forgot it (plausible deniability problem)
- ✅ Use for high-value wallets
- ❌ Don't use for wallets meant to be inherited easily

### 4. Key Derivation
- ✅ Use hardened derivation (') for sensitive levels
- ✅ Follow BIP44 standard for compatibility
- ✅ Use purpose=44' for standard wallets
- ✅ Use different account indices for different purposes

### 5. Extended Keys
- ⚠️ xpub can generate all receiving addresses (privacy leak)
- ⚠️ If xpub + one private child key leaked = all keys compromised
- ✅ Use hardened derivation to create "gap" for xpub distribution
- ✅ Never share xprv (contains private keys)

## Common Derivation Paths

```python
# Legacy Bitcoin (P2PKH) - starts with 1
"m/44'/0'/0'/0/0"

# SegWit P2SH (nested) - starts with 3
"m/49'/0'/0'/0/0"

# Native SegWit (bech32) - starts with bc1
"m/84'/0'/0'/0/0"

# Taproot (P2TR) - starts with bc1p
"m/86'/0'/0'/0/0"

# Ethereum
"m/44'/60'/0'/0/0"

# Testnet Bitcoin
"m/44'/1'/0'/0/0"

"m/44'/1776'/0'/0/0"

"m/44'/195'/0'/0/0"

# Solana
"m/44'/501'/0'/0'"  # Note: Solana stops at account level
```

## Error Handling

```python
def create_hd_wallet_safe():
    """Safely create HD wallet with proper error handling"""
    try:
        # 1. Generate entropy
        entropy = secrets.token_bytes(16)
        
        # 2. Create mnemonic
        mnemo = Mnemonic("english")
        mnemonic_phrase = mnemo.to_mnemonic(entropy)
        
        # 3. Validate mnemonic
        if not mnemo.check(mnemonic_phrase):
            raise ValueError("Mnemonic validation failed")
        
        # 4. Generate seed (with optional passphrase)
        passphrase = ""  # or get from user
        seed = mnemo.to_seed(mnemonic_phrase, passphrase)
        
        # 5. Create BIP32 root
        bip32 = BIP32.from_seed(seed)
        
        # 6. Derive keys for each supported chain
        derived_keys = {}
        for chain, path in CHAIN_PATHS.items():
            try:
                private_key = bip32.get_privkey_from_path(path)
                public_key = bip32.get_pubkey_from_path(path)
                address = generate_address_for_chain(chain, public_key)
                
                derived_keys[chain] = {
                    'path': path,
                    'address': address,
                    'public_key': public_key.hex()
                    # Never return private key in logs!
                }
            except Exception as e:
                print(f"Failed to derive {chain}: {e}")
                continue
        
        return {
            'mnemonic': mnemonic_phrase,
            'derived_keys': derived_keys,
            'success': True
        }
        
    except Exception as e:
        return {
            'error': str(e),
            'success': False
        }
```

## LND Integration

For LND (Lightning Network Daemon), there's a special case:

```python
def generate_lnd_compatible_seed():
    """Generate seed compatible with LND's aezeed format"""
    # LND uses aezeed, not BIP39
    # But you can import BIP39 to LND by converting to extended key
    
    # 1. Generate BIP39 mnemonic
    mnemo = Mnemonic("english")
    entropy = secrets.token_bytes(16)
    mnemonic_phrase = mnemo.to_mnemonic(entropy)
    
    # 2. Convert to seed
    seed = mnemo.to_seed(mnemonic_phrase, "")
    
    # 3. Generate master extended private key
    bip32 = BIP32.from_seed(seed)
    
    # For mainnet
    xprv = bip32.get_xpriv_from_path("m")
    # For testnet, you'd need to encode with different version bytes
    
    return {
        'mnemonic': mnemonic_phrase,
        'master_key': xprv,
        'note': 'Use master_key with lncli create --extended_key'
    }
```

## Testing Your Implementation

```python
# Test entropy generation
def test_entropy():
    ent1 = secrets.token_bytes(16)
    ent2 = secrets.token_bytes(16)
    assert ent1 != ent2, "Entropy should be unique"
    assert len(ent1) == 16, "Should be 16 bytes"

# Test mnemonic generation
def test_mnemonic():
    mnemo = Mnemonic("english")
    entropy = secrets.token_bytes(16)
    phrase = mnemo.to_mnemonic(entropy)
    
    words = phrase.split()
    assert len(words) == 12, "Should have 12 words"
    assert mnemo.check(phrase), "Should be valid"

# Test deterministic derivation
def test_deterministic():
    phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    mnemo = Mnemonic("english")
    
    # Should always produce same seed
    seed1 = mnemo.to_seed(phrase, "")
    seed2 = mnemo.to_seed(phrase, "")
    assert seed1 == seed2, "Seeds should match"
    
    # Should produce different seed with passphrase
    seed3 = mnemo.to_seed(phrase, "passphrase")
    assert seed1 != seed3, "Different passphrase = different seed"
```

## References

1. **BIP39**: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
2. **BIP32**: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
3. **BIP44**: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
4. **Bitcoin Book Chapter 5**: https://github.com/bitcoinbook/bitcoinbook/blob/develop/ch05_wallets.adoc
5. **SLIP44 Coin Types**: https://github.com/satoshilabs/slips/blob/master/slip-0044.md

## Summary

The proper order is:
1. **Random Entropy** (128-256 bits) ← Start here
2. **BIP39 Mnemonic** (12-24 words) ← For human backup
3. **512-bit Seed** (via PBKDF2) ← Feeds into BIP32
4. **Master Private Key + Chain Code** ← Root of tree
5. **Derived Child Keys** (via BIP32/BIP44 paths) ← Specific coins/accounts
6. **Addresses** (chain-specific encoding) ← What users see

Your current implementation is close to correct. The main thing to understand is the distinction between mnemonic (for backup) and seed (for key derivation), and why each step exists.
