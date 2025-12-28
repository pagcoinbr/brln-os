#!/usr/bin/env python3
"""
Script to restore LND and Elements wallets from the unified BRLN wallet
"""
import sqlite3
import getpass
import subprocess
import os
import sys
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64
import json

def derive_key_from_password(password: str, salt: bytes) -> bytes:
    """Derive encryption key from password and salt"""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,
    )
    return base64.urlsafe_b64encode(kdf.derive(password.encode()))

def decrypt_mnemonic(encrypted_mnemonic: bytes, password: str, salt: bytes) -> str:
    """Decrypt the mnemonic phrase"""
    try:
        key = derive_key_from_password(password, salt)
        f = Fernet(key)
        decrypted = f.decrypt(encrypted_mnemonic)
        return decrypted.decode('utf-8')
    except Exception as e:
        raise Exception(f"Failed to decrypt mnemonic: {str(e)}")

def get_wallet_info(db_path: str):
    """Get wallet information from the database"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT wallet_id, encrypted_mnemonic, salt, has_password, metadata 
        FROM wallets 
        ORDER BY created_at DESC 
        LIMIT 1
    """)
    
    result = cursor.fetchone()
    conn.close()
    
    if not result:
        raise Exception("No wallet found in database")
    
    return result

def restore_lnd_wallet(mnemonic: str):
    """Restore LND wallet using the mnemonic"""
    print("🔥 Restoring LND wallet...")
    
    # Remove existing wallet.db
    wallet_db_path = "/data/lnd/data/chain/bitcoin/testnet/wallet.db"
    if os.path.exists(wallet_db_path):
        os.remove(wallet_db_path)
        print("   Removed existing wallet.db")
    
    # Start LND service to initialize
    subprocess.run(["sudo", "systemctl", "start", "lnd"], check=True)
    print("   Started LND service")
    
    # Wait a moment for LND to start
    import time
    time.sleep(5)
    
    # Create new wallet with mnemonic
    mnemonic_words = mnemonic.split()
    print(f"   Using mnemonic with {len(mnemonic_words)} words")
    
    # Use lncli to create wallet
    cmd = ["lncli", "--network=testnet", "create"]
    process = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    
    # Read password from existing password file
    with open("/data/lnd/password.txt", "r") as f:
        lnd_password = f.read().strip()
    
    # Provide inputs to lncli create
    input_text = f"{lnd_password}\n{lnd_password}\nn\n{mnemonic}\n\n"
    stdout, stderr = process.communicate(input=input_text)
    
    if process.returncode != 0:
        print(f"   Error creating LND wallet: {stderr}")
        return False
    
    print("   ✅ LND wallet restored successfully")
    return True

def restore_elements_wallet(mnemonic: str):
    """Restore Elements wallet using the mnemonic"""
    print("🔥 Restoring Elements wallet...")
    
    # Start Elements daemon
    subprocess.run(["sudo", "systemctl", "start", "elementsd"], check=True)
    print("   Started Elements daemon")
    
    # Wait for Elements to start
    import time
    time.sleep(10)
    
    # Remove existing peerswap wallet
    peerswap_wallet_path = "/data/elements/liquidtestnet/wallets/peerswap"
    if os.path.exists(peerswap_wallet_path):
        import shutil
        shutil.rmtree(peerswap_wallet_path)
        print("   Removed existing peerswap wallet")
    
    # Create new wallet using mnemonic
    try:
        # Create wallet with mnemonic
        cmd = ["elements-cli", "-datadir=/data/elements", "createwallet", "peerswap", "false", "false", "", "false", "true"]
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        print("   Created new peerswap wallet")
        
        # Import mnemonic
        cmd = ["elements-cli", "-datadir=/data/elements", "-rpcwallet=peerswap", "sethdseed", "true", mnemonic]
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print("   ✅ Elements wallet restored with mnemonic")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"   Error restoring Elements wallet: {e.stderr}")
        return False

def main():
    db_path = "/data/brln-wallet/wallets.db"
    
    if not os.path.exists(db_path):
        print(f"❌ Wallet database not found at {db_path}")
        sys.exit(1)
    
    print("🚀 BRLN Wallet Restoration Tool")
    print("================================")
    
    try:
        # Get wallet info
        wallet_id, encrypted_mnemonic, salt, has_password, metadata = get_wallet_info(db_path)
        metadata_dict = json.loads(metadata) if metadata else {}
        
        print(f"📱 Found wallet: {wallet_id}")
        print(f"🔢 Word count: {metadata_dict.get('wordCount', 'Unknown')}")
        print(f"🔐 Password protected: {bool(has_password)}")
        
        # For now, let's manually enter the mnemonic
        print("\n🔑 Please enter your 12-word mnemonic phrase:")
        mnemonic = input("Mnemonic: ").strip()
        
        if len(mnemonic.split()) != 12:
            print("❌ Please enter exactly 12 words")
            sys.exit(1)
        
        print("✅ Mnemonic entered successfully")
        
        # Restore wallets
        print("\n🔄 Starting wallet restoration process...")
        
        # Restore LND
        lnd_success = restore_lnd_wallet(mnemonic)
        
        # Restore Elements
        elements_success = restore_elements_wallet(mnemonic)
        
        # Summary
        print(f"\n📊 Restoration Summary:")
        print(f"   LND: {'✅ Success' if lnd_success else '❌ Failed'}")
        print(f"   Elements: {'✅ Success' if elements_success else '❌ Failed'}")
        
        if lnd_success and elements_success:
            print("\n🎉 Unified wallet restoration completed successfully!")
            print("💡 Your entire system is now powered by one mnemonic!")
        else:
            print("\n⚠️ Some wallets failed to restore. Check the logs above.")
            
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()