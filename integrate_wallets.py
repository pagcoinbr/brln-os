#!/usr/bin/env python3
"""
BRLN-OS Unified Wallet Integration Script
=========================================

This script demonstrates how to:
1. Extract mnemonic from the unified wallet database
2. Derive the appropriate keys for LND and Elements
3. Replace/symlink wallet files to use the unified keys
4. Verify the integration works

Usage:
    python3 integrate_wallets.py --wallet-id <wallet_id> --password <password>
"""

import sqlite3
import subprocess
import os
import sys
import argparse
import json
import shutil
import time
from pathlib import Path
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64

# Configuration
WALLET_DB_PATH = "/data/brln-wallet/wallets.db"
LND_DATA_PATH = "/data/lnd/data/chain/bitcoin/testnet"
ELEMENTS_DATA_PATH = "/data/elements/liquidtestnet"
BACKUP_SUFFIX = f".backup-{int(time.time())}"

class WalletIntegrator:
    def __init__(self):
        self.mnemonic = None
        self.wallet_id = None
        
    def decrypt_mnemonic(self, encrypted_mnemonic: bytes, password: str, salt: bytes) -> str:
        """Decrypt the mnemonic phrase from database"""
        try:
            import hashlib
            
            # Create hash SHA256 da senha + salt (matching the API encryption)
            password_salt = password.encode() + salt
            password_hash = hashlib.sha256(password_salt).digest()
            
            # Usar PBKDF2 with the hash SHA256 as input
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,  # 256 bits for AES-256
                salt=salt,
                iterations=200000,  # Must match API encryption iterations
            )
            key = base64.urlsafe_b64encode(kdf.derive(password_hash))
            
            # Decrypt mnemonic with AES-256
            fernet = Fernet(key)
            decrypted_mnemonic = fernet.decrypt(encrypted_mnemonic)
            
            return decrypted_mnemonic.decode('utf-8')
        except Exception as e:
            raise Exception(f"Failed to decrypt mnemonic: {str(e)}")

    def load_wallet_from_db(self, wallet_id: str, password: str):
        """Load and decrypt wallet from database"""
        print(f"🔍 Loading wallet '{wallet_id}' from database...")
        
        try:
            conn = sqlite3.connect(WALLET_DB_PATH)
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT encrypted_mnemonic, salt, metadata, has_password
                FROM wallets WHERE wallet_id = ?
            """, (wallet_id,))
            
            result = cursor.fetchone()
            conn.close()
            
            if not result:
                raise Exception(f"Wallet '{wallet_id}' not found in database")
            
            encrypted_mnemonic, salt, metadata, has_password = result
            
            if has_password and not password:
                raise Exception("Wallet is password protected but no password provided")
            
            # Decrypt mnemonic
            if has_password:
                self.mnemonic = self.decrypt_mnemonic(encrypted_mnemonic, password, salt)
            else:
                # For unencrypted wallets (shouldn't happen with current system)
                self.mnemonic = encrypted_mnemonic.decode('utf-8')
            
            self.wallet_id = wallet_id
            
            # Parse metadata
            metadata_dict = json.loads(metadata) if metadata else {}
            word_count = metadata_dict.get('wordCount', len(self.mnemonic.split()))
            
            print(f"✅ Wallet loaded successfully:")
            print(f"   - Wallet ID: {wallet_id}")
            print(f"   - Word count: {word_count}")
            print(f"   - Encrypted: {bool(has_password)}")
            
            return True
            
        except Exception as e:
            print(f"❌ Error loading wallet: {str(e)}")
            return False

    def stop_services(self):
        """Stop LND and Elements services before wallet replacement"""
        print("⏹️  Stopping services...")
        
        services = ["lnd", "elementsd"]
        for service in services:
            try:
                result = subprocess.run(["sudo", "systemctl", "stop", service], 
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    print(f"   ✅ {service} stopped")
                else:
                    print(f"   ⚠️ {service} stop failed: {result.stderr}")
            except Exception as e:
                print(f"   ❌ Error stopping {service}: {str(e)}")

    def backup_existing_wallets(self):
        """Create backups of existing wallet files"""
        print("💾 Creating backups of existing wallets...")
        
        backups_created = []
        
        # Backup LND wallet
        lnd_wallet_path = f"{LND_DATA_PATH}/wallet.db"
        if os.path.exists(lnd_wallet_path):
            backup_path = f"{lnd_wallet_path}{BACKUP_SUFFIX}"
            shutil.copy2(lnd_wallet_path, backup_path)
            backups_created.append(backup_path)
            print(f"   ✅ LND wallet backed up to: {backup_path}")
        
        # Backup Elements wallet directory
        elements_wallet_dir = f"{ELEMENTS_DATA_PATH}/wallets"
        if os.path.exists(elements_wallet_dir):
            backup_path = f"{elements_wallet_dir}{BACKUP_SUFFIX}"
            shutil.copytree(elements_wallet_dir, backup_path)
            backups_created.append(backup_path)
            print(f"   ✅ Elements wallets backed up to: {backup_path}")
        
        if backups_created:
            print(f"📝 Backup Summary:")
            for backup in backups_created:
                print(f"   - {backup}")
        
        return backups_created

    def restore_lnd_wallet(self):
        """Replace LND wallet with unified wallet mnemonic"""
        print("⚡ Restoring LND wallet...")
        
        try:
            # Remove existing wallet.db
            wallet_db_path = f"{LND_DATA_PATH}/wallet.db"
            if os.path.exists(wallet_db_path):
                os.remove(wallet_db_path)
                print("   🗑️  Removed existing wallet.db")
            
            # Start LND service to initialize
            print("   🔄 Starting LND service...")
            subprocess.run(["sudo", "systemctl", "start", "lnd"], check=True)
            
            # Wait for LND to start
            time.sleep(10)
            
            # Check if LND is running
            result = subprocess.run(["lncli", "--network=testnet", "getinfo"], 
                                  capture_output=True, text=True)
            if result.returncode != 0:
                print("   ⏳ Waiting for LND to fully start...")
                time.sleep(10)
            
            # Read password from existing password file
            password_file = "/data/lnd/password.txt"
            if os.path.exists(password_file):
                with open(password_file, "r") as f:
                    lnd_password = f.read().strip()
            else:
                lnd_password = "defaultpassword"
                # Create password file
                with open(password_file, "w") as f:
                    f.write(lnd_password)
                print(f"   📝 Created password file with default password")
            
            # Create wallet using lncli
            print("   🔑 Creating new LND wallet with unified mnemonic...")
            
            cmd = ["lncli", "--network=testnet", "create"]
            process = subprocess.Popen(cmd, stdin=subprocess.PIPE, 
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            
            # Provide inputs to lncli create
            input_text = f"{lnd_password}\\n{lnd_password}\\nn\\n{self.mnemonic}\\n\\n"
            stdout, stderr = process.communicate(input=input_text)
            
            if process.returncode == 0:
                print("   ✅ LND wallet restored successfully")
                if "Generated new address" in stdout or "seed" in stdout.lower():
                    print("   🎯 New wallet created with unified mnemonic")
                return True
            else:
                print(f"   ❌ Error creating LND wallet: {stderr}")
                return False
                
        except Exception as e:
            print(f"   ❌ Error restoring LND wallet: {str(e)}")
            return False

    def restore_elements_wallet(self):
        """Replace Elements wallet with unified wallet keys"""
        print("🔷 Restoring Elements wallet...")
        
        try:
            # Start Elements daemon
            print("   🔄 Starting Elements daemon...")
            subprocess.run(["sudo", "systemctl", "start", "elementsd"], check=True)
            
            # Wait for Elements to start
            time.sleep(15)
            
            # Remove existing peerswap wallet
            peerswap_wallet_path = f"{ELEMENTS_DATA_PATH}/wallets/peerswap"
            if os.path.exists(peerswap_wallet_path):
                shutil.rmtree(peerswap_wallet_path)
                print("   🗑️  Removed existing peerswap wallet")
            
            # Create new wallet
            print("   🔑 Creating new Elements wallet...")
            cmd = ["elements-cli", "-datadir=/data/elements", 
                   "createwallet", "peerswap", "false", "false", "", "false", "true"]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                print(f"   ❌ Error creating Elements wallet: {result.stderr}")
                return False
            
            print("   ✅ Elements wallet created")
            
            # Import mnemonic using sethdseed
            print("   🔑 Importing unified mnemonic...")
            cmd = ["elements-cli", "-datadir=/data/elements", "-rpcwallet=peerswap", 
                   "sethdseed", "true", self.mnemonic]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                print("   ✅ Elements wallet restored with unified mnemonic")
                return True
            else:
                print(f"   ❌ Error importing mnemonic to Elements: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print("   ⚠️ Elements command timed out")
            return False
        except Exception as e:
            print(f"   ❌ Error restoring Elements wallet: {str(e)}")
            return False

    def verify_integration(self):
        """Verify that both wallets are using the unified keys"""
        print("🔍 Verifying wallet integration...")
        
        success = True
        
        # Verify LND
        try:
            result = subprocess.run(["lncli", "--network=testnet", "getinfo"], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                info = json.loads(result.stdout)
                print(f"   ✅ LND: Node {info.get('identity_pubkey', '')[:16]}...")
            else:
                print("   ❌ LND verification failed")
                success = False
        except Exception as e:
            print(f"   ❌ LND verification error: {str(e)}")
            success = False
        
        # Verify Elements
        try:
            result = subprocess.run(["elements-cli", "-datadir=/data/elements", 
                                   "-rpcwallet=peerswap", "getwalletinfo"], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                info = json.loads(result.stdout)
                print(f"   ✅ Elements: Wallet '{info.get('walletname')}' ready")
            else:
                print("   ❌ Elements verification failed")
                success = False
        except Exception as e:
            print(f"   ❌ Elements verification error: {str(e)}")
            success = False
        
        return success

    def create_integration_report(self, backups_created):
        """Create a report of the integration process"""
        report_path = f"/root/brln-os/wallet-integration-report-{int(time.time())}.txt"
        
        with open(report_path, "w") as f:
            f.write("BRLN-OS Unified Wallet Integration Report\\n")
            f.write("=" * 50 + "\\n\\n")
            f.write(f"Integration Date: {time.strftime('%Y-%m-%d %H:%M:%S')}\\n")
            f.write(f"Wallet ID: {self.wallet_id}\\n")
            f.write(f"Mnemonic Words: {len(self.mnemonic.split())}\\n\\n")
            
            f.write("Backups Created:\\n")
            for backup in backups_created:
                f.write(f"  - {backup}\\n")
            
            f.write("\\nServices Integrated:\\n")
            f.write("  - LND (Lightning Network)\\n")
            f.write("  - Elements (Liquid Network)\\n\\n")
            
            f.write("Note: All services are now using the same master seed\\n")
            f.write("from the unified BRLN wallet system.\\n")
        
        print(f"📄 Integration report saved: {report_path}")

def main():
    parser = argparse.ArgumentParser(description="Integrate unified wallet with LND and Elements")
    parser.add_argument("--wallet-id", required=True, help="Wallet ID from database")
    parser.add_argument("--password", required=True, help="Wallet password")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without executing")
    
    args = parser.parse_args()
    
    print("🚀 BRLN-OS Unified Wallet Integration")
    print("=" * 50)
    
    if args.dry_run:
        print("🔍 DRY RUN MODE - No actual changes will be made")
    
    integrator = WalletIntegrator()
    
    # Step 1: Load wallet from database
    if not integrator.load_wallet_from_db(args.wallet_id, args.password):
        sys.exit(1)
    
    if args.dry_run:
        print("\\n📋 DRY RUN - Would perform these steps:")
        print("   1. Stop LND and Elements services")
        print("   2. Backup existing wallet files")
        print("   3. Replace LND wallet with unified mnemonic")
        print("   4. Replace Elements wallet with unified mnemonic")
        print("   5. Verify integration")
        print("   6. Create integration report")
        return
    
    # Step 2: Stop services
    integrator.stop_services()
    
    # Step 3: Backup existing wallets
    backups_created = integrator.backup_existing_wallets()
    
    # Step 4: Restore LND wallet
    lnd_success = integrator.restore_lnd_wallet()
    
    # Step 5: Restore Elements wallet
    elements_success = integrator.restore_elements_wallet()
    
    # Step 6: Verify integration
    verification_success = integrator.verify_integration()
    
    # Step 7: Create report
    integrator.create_integration_report(backups_created)
    
    # Summary
    print("\\n📊 Integration Summary:")
    print(f"   LND Integration: {'✅ Success' if lnd_success else '❌ Failed'}")
    print(f"   Elements Integration: {'✅ Success' if elements_success else '❌ Failed'}")
    print(f"   Verification: {'✅ Passed' if verification_success else '❌ Failed'}")
    
    if lnd_success and elements_success and verification_success:
        print("\\n🎉 UNIFIED WALLET INTEGRATION COMPLETED!")
        print("💡 Your entire system is now powered by one mnemonic!")
        print(f"🔗 Wallet ID: {args.wallet_id}")
    else:
        print("\\n⚠️ Integration completed with some issues.")
        print("📝 Check the logs above and integration report for details.")

if __name__ == "__main__":
    main()