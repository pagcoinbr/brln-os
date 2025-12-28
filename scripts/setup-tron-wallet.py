#!/usr/bin/env python3
"""
TRON Gas-Free Wallet Setup Script
Derives TRON address from system wallet seed phrase and stores it encrypted
"""

import sys
import sqlite3
import hashlib
import secrets
from pathlib import Path
from getpass import getpass
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
import base64

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent / 'api' / 'v1'))

try:
    from mnemonic import Mnemonic
    from bip32 import BIP32
    HAS_LIBS = True
except ImportError:
    print("Error: Required libraries not found")
    print("Install with: pip3 install mnemonic bip32utils")
    HAS_LIBS = False
    sys.exit(1)

# Paths
WALLET_DB_PATH = "/data/brln-wallet/wallets.db"

def derive_key_from_password(password: str, salt: bytes) -> bytes:
    """Deriva uma chave de criptografia a partir de uma senha"""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,
        backend=default_backend()
    )
    return base64.urlsafe_b64encode(kdf.derive(password.encode()))

def encrypt_data(data: str, password: str, salt: bytes = None) -> tuple:
    """Criptografa dados usando a senha fornecida"""
    if salt is None:
        salt = secrets.token_bytes(16)
    
    key = derive_key_from_password(password, salt)
    f = Fernet(key)
    encrypted = f.encrypt(data.encode())
    return encrypted, salt

def decrypt_data(encrypted_data: bytes, password: str, salt: bytes) -> str:
    """Descriptografa dados usando a senha fornecida"""
    key = derive_key_from_password(password, salt)
    f = Fernet(key)
    return f.decrypt(encrypted_data).decode()

def get_system_wallet_mnemonic(password: str) -> str:
    """Obtém a mnemonic do wallet do sistema"""
    try:
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT encrypted_mnemonic, salt FROM wallets 
            WHERE is_system_default = 1 
            LIMIT 1
        """)
        
        result = cursor.fetchone()
        conn.close()
        
        if not result:
            print("Error: System wallet not found")
            print("Please create a system wallet first using the HD Wallet interface")
            return None
        
        encrypted_mnemonic, salt = result
        
        # Decrypt mnemonic
        mnemonic = decrypt_data(encrypted_mnemonic, password, salt)
        return mnemonic
        
    except Exception as e:
        print(f"Error retrieving system wallet: {e}")
        return None

def derive_tron_address(mnemonic: str) -> tuple:
    """Deriva endereço TRON da seed phrase BIP39"""
    try:
        # Generate seed from mnemonic
        mnemo = Mnemonic("english")
        seed = mnemo.to_seed(mnemonic)
        
        # Derive TRON key using BIP44 path: m/44'/195'/0'/0/0
        # 195 is TRON's coin type
        bip32 = BIP32.from_seed(seed)
        
        # TRON derivation path
        tron_path = "m/44'/195'/0'/0/0"
        derived_key = bip32.get_privkey_from_path(tron_path)
        
        # Convert to TRON address format
        # TRON uses secp256k1 like Bitcoin, but with different address encoding
        private_key_hex = derived_key.hex()
        
        # For now, return the private key hex
        # In production, you would convert this to TRON address format
        # using tronpy or similar library
        
        print("\nDerived TRON Private Key:")
        print(f"Private Key: {private_key_hex}")
        print(f"Derivation Path: {tron_path}")
        
        # Note: You'll need to convert this to a TRON address
        # This requires additional TRON-specific libraries
        
        return private_key_hex, tron_path
        
    except Exception as e:
        print(f"Error deriving TRON address: {e}")
        return None, None

def save_tron_config(address: str, private_key: str, password: str):
    """Salva configuração TRON no banco de dados"""
    try:
        # Encrypt private key
        encrypted_key, salt = encrypt_data(private_key, password)
        
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        # Check if config exists
        cursor.execute("SELECT id FROM tron_config WHERE id = 1")
        exists = cursor.fetchone()
        
        if exists:
            # Update existing
            cursor.execute("""
                UPDATE tron_config 
                SET tron_address = ?, encrypted_private_key = ?, salt = ?
                WHERE id = 1
            """, (address, encrypted_key, salt))
        else:
            # Insert new
            cursor.execute("""
                INSERT INTO tron_config 
                (id, tron_address, encrypted_private_key, salt)
                VALUES (1, ?, ?, ?)
            """, (address, encrypted_key, salt))
        
        conn.commit()
        conn.close()
        
        print("\n✅ TRON configuration saved successfully!")
        print(f"Address: {address}")
        
    except Exception as e:
        print(f"Error saving TRON configuration: {e}")

def main():
    print("=" * 60)
    print("TRON Gas-Free Wallet Setup")
    print("=" * 60)
    print()
    
    if not HAS_LIBS:
        return
    
    # Get password
    password = getpass("Enter your wallet password (same as LND unlock): ")
    if not password:
        print("Error: Password is required")
        return
    
    # Get system wallet mnemonic
    print("\nRetrieving system wallet...")
    mnemonic = get_system_wallet_mnemonic(password)
    if not mnemonic:
        return
    
    print("✅ System wallet retrieved successfully")
    
    # Derive TRON address
    print("\nDeriving TRON address from seed phrase...")
    private_key, derivation_path = derive_tron_address(mnemonic)
    if not private_key:
        return
    
    # Manual address input (until we implement proper TRON address derivation)
    print("\n" + "=" * 60)
    print("IMPORTANT: TRON Address Conversion Required")
    print("=" * 60)
    print()
    print("The private key has been derived, but you need to convert it")
    print("to a TRON address format using an external tool.")
    print()
    print("Options:")
    print("1. Use TronLink wallet to import the private key")
    print("2. Use tronpy library to convert")
    print("3. Use online tool (NOT RECOMMENDED for mainnet)")
    print()
    
    tron_address = input("Enter the TRON address (starts with T): ").strip()
    
    if not tron_address.startswith('T') or len(tron_address) != 34:
        print("Error: Invalid TRON address format")
        return
    
    # Confirm
    print("\n" + "=" * 60)
    print("Configuration Summary")
    print("=" * 60)
    print(f"TRON Address: {tron_address}")
    print(f"Derivation Path: {derivation_path}")
    print(f"Private Key: {private_key[:10]}...{private_key[-10:]}")
    print()
    
    confirm = input("Save this configuration? (yes/no): ").lower()
    if confirm != 'yes':
        print("Configuration cancelled")
        return
    
    # Save configuration
    save_tron_config(tron_address, private_key, password)
    
    print("\n" + "=" * 60)
    print("Setup Complete!")
    print("=" * 60)
    print()
    print("Next steps:")
    print("1. Configure TRON API settings in the web interface")
    print("2. Add TronGrid API key")
    print("3. Add Gas-Free API credentials")
    print("4. Start sending and receiving USDT!")
    print()

if __name__ == "__main__":
    main()
