#!/usr/bin/env python3
"""
BRLN-OS Password Manager
Secure credential storage using SQLite with Fernet encryption
Master password derived using PBKDF2-HMAC-SHA256 with salt
"""

import sys
import sqlite3
import os
import base64
import getpass
from datetime import datetime
from pathlib import Path
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

# Password database location
PASSWORD_DB_PATH = "/data/brln-passwords.db"

# Salt file location (salt is not secret, just ensures uniqueness)
SALT_FILE = "/data/.brln-salt"

def get_or_create_salt():
    """Get or create the salt for key derivation"""
    if os.path.exists(SALT_FILE):
        with open(SALT_FILE, 'rb') as f:
            return f.read()
    else:
        # Create new salt (32 bytes)
        salt = os.urandom(32)
        os.makedirs(os.path.dirname(SALT_FILE), exist_ok=True)
        with open(SALT_FILE, 'wb') as f:
            f.write(salt)
        os.chmod(SALT_FILE, 0o644)  # Salt doesn't need to be secret
        return salt

def derive_key_from_password(master_password):
    """Derive encryption key from master password using PBKDF2-HMAC-SHA256"""
    salt = get_or_create_salt()
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=200000,  # High iteration count for security
        backend=default_backend()
    )
    key = base64.urlsafe_b64encode(kdf.derive(master_password.encode('utf-8')))
    return key

def encrypt_password(password, master_password):
    """Encrypt a password using Fernet with user's master password"""
    key = derive_key_from_password(master_password)
    f = Fernet(key)
    return f.encrypt(password.encode('utf-8'))

def decrypt_password(encrypted_password, master_password):
    """Decrypt a password using Fernet with user's master password"""
    key = derive_key_from_password(master_password)
    f = Fernet(key)
    return f.decrypt(encrypted_password).decode('utf-8')

def init_database():
    """Initialize password database with proper schema"""
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(PASSWORD_DB_PATH), exist_ok=True)
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS passwords (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            service_name TEXT UNIQUE NOT NULL,
            username TEXT NOT NULL,
            encrypted_password BLOB NOT NULL,
            description TEXT,
            port INTEGER,
            url TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
    ''')
    
    conn.commit()
    conn.close()
    
    # Set proper permissions
    os.chmod(PASSWORD_DB_PATH, 0o600)

def store_password(service_name, username, password, description="", port=0, url="", master_password=None):
    """Store or update a password in the database"""
    if master_password is None:
        master_password = getpass.getpass("Enter master password: ")
    
    init_database()
    
    # Encrypt password with Fernet using master password
    encrypted_password = encrypt_password(password, master_password)
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    now = datetime.now().isoformat()
    
    try:
        # Check if service already exists
        cursor.execute('SELECT id FROM passwords WHERE service_name = ?', (service_name,))
        existing = cursor.fetchone()
        
        if existing:
            # Update existing entry
            cursor.execute('''
                UPDATE passwords 
                SET username = ?, encrypted_password = ?, description = ?, port = ?, url = ?, updated_at = ?
                WHERE service_name = ?
            ''', (username, encrypted_password, description, port, url, now, service_name))
            print(f"✓ Updated password for '{service_name}'")
        else:
            # Insert new entry
            cursor.execute('''
                INSERT INTO passwords (service_name, username, encrypted_password, description, port, url, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (service_name, username, encrypted_password, description, port, url, now, now))
            print(f"✓ Stored password for '{service_name}'")
        
        conn.commit()
    except Exception as e:
        print(f"✗ Error storing password: {e}", file=sys.stderr)
        return False
    finally:
        conn.close()
    
    return True

def get_password(service_name, master_password=None):
    """Retrieve a password from the database (returns the plaintext password)"""
    if master_password is None:
        master_password = getpass.getpass("Enter master password: ")
    
    if not os.path.exists(PASSWORD_DB_PATH):
        print(f"✗ Password database not found", file=sys.stderr)
        return None
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('SELECT encrypted_password FROM passwords WHERE service_name = ?', (service_name,))
    result = cursor.fetchone()
    conn.close()
    
    if result:
        try:
            encrypted_password = result[0]
            password = decrypt_password(encrypted_password, master_password)
            return password
        except Exception as e:
            print(f"✗ Error decrypting password (wrong master password?): {e}", file=sys.stderr)
            return None
    else:
        print(f"✗ Service '{service_name}' not found", file=sys.stderr)
        return None

def list_passwords():
    """List all stored services"""
    if not os.path.exists(PASSWORD_DB_PATH):
        print("No passwords stored yet")
        return
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT service_name, username, description, port, url, created_at 
        FROM passwords 
        ORDER BY service_name
    ''')
    
    results = cursor.fetchall()
    conn.close()
    
    if not results:
        print("No passwords stored yet")
        return
    
    print(f"\n{'Service':<25} {'Username':<20} {'Description':<40}")
    print("=" * 85)
    for row in results:
        service, username, desc, port, url, created = row
        desc_short = desc[:37] + "..." if len(desc) > 40 else desc
        print(f"{service:<25} {username:<20} {desc_short:<40}")
    print()

def delete_password(service_name):
    """Delete a password from the database"""
    if not os.path.exists(PASSWORD_DB_PATH):
        print(f"✗ Password database not found", file=sys.stderr)
        return False
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('DELETE FROM passwords WHERE service_name = ?', (service_name,))
    
    if cursor.rowcount > 0:
        conn.commit()
        print(f"✓ Deleted password for '{service_name}'")
        result = True
    else:
        print(f"✗ Service '{service_name}' not found", file=sys.stderr)
        result = False
    
    conn.close()
    return result

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  password_manager.py store <service> <username> <password> [description] [port] [url]")
        print("  password_manager.py get <service>")
        print("  password_manager.py list")
        print("  password_manager.py delete <service>")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "store":
        if len(sys.argv) < 5:
            print("✗ Usage: store <service> <username> <password> [description] [port] [url] [master_password]", file=sys.stderr)
            sys.exit(1)
        
        service = sys.argv[2]
        username = sys.argv[3]
        password = sys.argv[4]
        description = sys.argv[5] if len(sys.argv) > 5 else ""
        port = int(sys.argv[6]) if len(sys.argv) > 6 else 0
        url = sys.argv[7] if len(sys.argv) > 7 else ""
        master_password = sys.argv[8] if len(sys.argv) > 8 else None
        
        store_password(service, username, password, description, port, url, master_password)
    
    elif command == "get":
        if len(sys.argv) < 3:
            print("✗ Usage: get <service> [master_password]", file=sys.stderr)
            sys.exit(1)
        
        service = sys.argv[2]
        master_password = sys.argv[3] if len(sys.argv) > 3 else None
        password = get_password(service, master_password)
        if password:
            print(password)
    
    elif command == "list":
        list_passwords()
    
    elif command == "delete":
        if len(sys.argv) < 3:
            print("✗ Usage: delete <service>", file=sys.stderr)
            sys.exit(1)
        
        service = sys.argv[2]
        delete_password(service)
    
    else:
        print(f"✗ Unknown command: {command}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
