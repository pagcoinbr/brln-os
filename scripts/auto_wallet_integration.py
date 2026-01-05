#!/usr/bin/env python3
"""
Auto Wallet Integration Module
=============================

This module provides functions to automatically integrate newly created wallets
with LND services when they are saved as system default.
"""

import subprocess
import os
import shutil
import time
import json
import sqlite3
from pathlib import Path

# Configuration
BITCOIN_NETWORK = os.environ.get("BITCOIN_NETWORK", "mainnet")
LND_DATA_PATH = f"/data/lnd/data/chain/bitcoin/{BITCOIN_NETWORK}"
BACKUP_SUFFIX = f".backup-{int(time.time())}"

def backup_existing_wallets():
    """Create backups of existing wallet files"""
    print("💾 Creating backups of existing wallets...")
    
    backups_created = []
    
    try:
        # Backup LND wallet
        lnd_wallet_path = f"{LND_DATA_PATH}/wallet.db"
        if os.path.exists(lnd_wallet_path):
            backup_path = f"{lnd_wallet_path}{BACKUP_SUFFIX}"
            shutil.copy2(lnd_wallet_path, backup_path)
            backups_created.append(backup_path)
            print(f"   ✅ LND wallet backed up to: {backup_path}")
    
    except Exception as e:
        print(f"⚠️ Warning during backup: {str(e)}")
    
    return backups_created

def stop_services():
    """Stop LND and related services"""
    print("⏹️ Stopping services for wallet replacement...")
    
    services = ["lnd", "messager-monitor"]
    stopped_services = []
    
    for service in services:
        try:
            result = subprocess.run(["sudo", "systemctl", "stop", service], 
                                  capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                stopped_services.append(service)
                print(f"   ✅ {service} stopped")
        except Exception as e:
            print(f"   ⚠️ Could not stop {service}: {str(e)}")
    
    return stopped_services

def start_services(services_to_start):
    """Start the previously stopped services"""
    print("🔄 Starting services...")
    
    for service in services_to_start:
        try:
            subprocess.run(["sudo", "systemctl", "start", service], 
                          capture_output=True, text=True, timeout=30)
            print(f"   ✅ {service} started")
        except Exception as e:
            print(f"   ⚠️ Could not start {service}: {str(e)}")

def integrate_lnd_wallet(mnemonic):
    """Replace LND wallet with unified mnemonic using REST API"""
    print("⚡ Integrating LND wallet via REST API...")
    
    try:
        import requests
        import base64
        import json
        
        # LND REST API endpoint
        lnd_rest_url = "https://localhost:8080"
        
        # Remove existing wallet.db to force new wallet creation
        wallet_db_path = f"{LND_DATA_PATH}/wallet.db"
        if os.path.exists(wallet_db_path):
            os.remove(wallet_db_path)
        
        # Remove macaroons to force regeneration
        macaroon_files = [
            f"{LND_DATA_PATH}/admin.macaroon",
            f"{LND_DATA_PATH}/readonly.macaroon", 
            f"{LND_DATA_PATH}/invoice.macaroon",
            f"{LND_DATA_PATH}/macaroons.db"
        ]
        for macaroon_file in macaroon_files:
            if os.path.exists(macaroon_file):
                os.remove(macaroon_file)
        
        print("   🗑️ Cleaned existing LND wallet files")
        
        # Start LND service
        subprocess.run(["sudo", "systemctl", "start", "lnd"], check=True)
        print("   🔄 LND service started")
        
        # Wait for LND to initialize
        print("   ⏳ Waiting for LND to initialize...")
        time.sleep(15)
        
        # Check if LND is responding (may fail initially without TLS verification)
        session = requests.Session()
        session.verify = False  # Disable TLS verification for localhost
        
        # Get LND password
        password_file = "/data/lnd/password.txt"
        if os.path.exists(password_file):
            with open(password_file, "r") as f:
                lnd_password = f.read().strip()
        else:
            lnd_password = "brln123456"
            with open(password_file, "w") as f:
                f.write(lnd_password)
        
        # Try to get wallet status first
        max_retries = 30
        for attempt in range(max_retries):
            try:
                response = session.get(f"{lnd_rest_url}/v1/getinfo", timeout=10)
                if response.status_code == 200:
                    print("   ⚠️ LND already has a wallet, need to restore instead")
                    return restore_lnd_wallet_via_api(session, lnd_rest_url, mnemonic, lnd_password)
                elif response.status_code == 400 or "wallet not found" in response.text.lower():
                    print("   ✅ LND ready for wallet initialization")
                    break
                else:
                    time.sleep(2)
            except requests.exceptions.RequestException:
                if attempt < max_retries - 1:
                    time.sleep(2)
                else:
                    print(f"   ❌ LND not responding after {max_retries} attempts")
                    return False
        
        # Initialize wallet using the REST API
        print("   🔑 Creating LND wallet via REST API...")
        
        # Convert mnemonic to list of words
        cipher_seed_mnemonic = mnemonic.split()
        
        # Prepare initwallet request
        init_wallet_data = {
            "wallet_password": base64.b64encode(lnd_password.encode()).decode(),
            "cipher_seed_mnemonic": cipher_seed_mnemonic,
            "recovery_window": 2500
        }
        
        # Send initwallet request
        response = session.post(
            f"{lnd_rest_url}/v1/initwallet",
            json=init_wallet_data,
            timeout=60
        )
        
        if response.status_code == 200:
            print("   ✅ LND wallet initialized successfully")
            
            # Wait a moment for wallet to be ready
            time.sleep(5)
            
            # Verify wallet is working
            response = session.get(f"{lnd_rest_url}/v1/getinfo", timeout=10)
            if response.status_code == 200:
                info = response.json()
                print(f"   🎯 LND node ID: {info.get('identity_pubkey', '')[:16]}...")
                return True
            else:
                print("   ⚠️ Wallet created but verification failed")
                return True  # Still consider success
                
        else:
            print(f"   ❌ Failed to initialize wallet: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"   ❌ LND integration error: {str(e)}")
        return False

def restore_lnd_wallet_via_api(session, lnd_rest_url, mnemonic, lnd_password):
    """Restore existing LND wallet with new mnemonic"""
    print("   🔄 Restoring existing LND wallet...")
    
    try:
        import base64
        
        # First, try to unlock the current wallet to delete it
        unlock_data = {
            "wallet_password": base64.b64encode(lnd_password.encode()).decode()
        }
        
        response = session.post(f"{lnd_rest_url}/v1/unlockwallet", json=unlock_data, timeout=30)
        
        if response.status_code == 200:
            print("   ✅ Current wallet unlocked")
            
            # Stop LND to remove wallet files
            subprocess.run(["sudo", "systemctl", "stop", "lnd"], check=True)
            time.sleep(5)
            
            # Remove wallet files
            wallet_files = [
                f"{LND_DATA_PATH}/wallet.db",
                f"{LND_DATA_PATH}/macaroons.db"
            ]
            for wallet_file in wallet_files:
                if os.path.exists(wallet_file):
                    os.remove(wallet_file)
            
            # Restart LND
            subprocess.run(["sudo", "systemctl", "start", "lnd"], check=True)
            time.sleep(15)
            
            # Now initialize with new mnemonic
            return integrate_lnd_wallet(mnemonic)
        else:
            print(f"   ❌ Failed to unlock current wallet: {response.text}")
            return False
            
    except Exception as e:
        print(f"   ❌ Restore error: {str(e)}")
        return False

def auto_integrate_wallet(mnemonic, wallet_id):
    """
    Automatically integrate a newly created wallet with LND
    Called when a wallet is saved as system default
    """
    print(f"?Ys? Auto-integrating wallet '{wallet_id}' with system services...")

    # Step 1: Create backups
    backups = backup_existing_wallets()

    # Step 2: Stop services
    stopped_services = stop_services()

    # Step 3: Integrate LND
    lnd_success = integrate_lnd_wallet(mnemonic)

    # Step 4: Start dependent services
    if "lnd" in stopped_services:
        stopped_services.remove("lnd")  # LND already started in integration

    start_services(stopped_services)

    # Create integration log
    log_entry = {
        "timestamp": int(time.time()),
        "wallet_id": wallet_id,
        "lnd_integrated": lnd_success,
        "backups_created": backups
    }

    log_file = "/data/wallet-integration.log"
    with open(log_file, "a") as f:
        f.write(json.dumps(log_entry) + "
")

    success = lnd_success

    if success:
        print(f"?YZ% Wallet '{wallet_id}' successfully integrated with all services!")
    else:
        print(f"?s???? Wallet '{wallet_id}' integration completed with some issues")

    return {
        "success": success,
        "lnd_integrated": lnd_success,
        "backups_created": backups
    }


def check_integration_dependencies():
    """Check if required tools are available for integration"""
    required_tools = []
    missing = []
    
    for tool in required_tools:
        if not shutil.which(tool):
            missing.append(tool)
    
    # Check Python requests library
    try:
        import requests
    except ImportError:
        missing.append("python3-requests")
    
    if missing:
        print(f"⚠️ Missing required tools: {', '.join(missing)}")
        if "python3-requests" in missing:
            print("Install with: sudo apt install python3-requests")
        return False
    
    return True

if __name__ == "__main__":
    print("Auto Wallet Integration Module")
    print("This module is designed to be imported by the BRLN API")
