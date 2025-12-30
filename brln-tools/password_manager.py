#!/usr/bin/env python3
"""
BRLN-OS Password Manager
Secure credential storage using SQLite with Fernet encryption
Auto-generated user keys with SHA-256 hashing and salt
"""

import sys
import sqlite3
import os
import base64
import secrets
import hashlib
import uuid
from datetime import datetime
from pathlib import Path
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

# Password database location
PASSWORD_DB_PATH = "/data/brln-passwords.db"

def generate_16_digit_key():
    """Generate a random 16-digit key"""
    return ''.join([str(secrets.randbelow(10)) for _ in range(16)])

def generate_user_id():
    """Generate a unique user ID"""
    return str(uuid.uuid4())

def hash_key_with_salt(key, salt=None):
    """Hash a key with SHA-256 and salt"""
    if salt is None:
        salt = os.urandom(32)
    
    # Combine key and salt
    key_salt = key.encode('utf-8') + salt
    key_hash = hashlib.sha256(key_salt).digest()
    
    return key_hash, salt

def derive_key_from_key(user_key, salt):
    """Derive encryption key from user key using PBKDF2-HMAC-SHA256"""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,  # Moderate iterations for performance
        backend=default_backend()
    )
    key = base64.urlsafe_b64encode(kdf.derive(user_key.encode('utf-8')))
    return key

def init_database():
    """Initialize the password database with proper schema"""
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(PASSWORD_DB_PATH), exist_ok=True)
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    # User keys table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_keys (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT UNIQUE NOT NULL,
            key_hash BLOB NOT NULL,
            salt BLOB NOT NULL,
            created_at TEXT NOT NULL,
            last_used TEXT NOT NULL
        )
    ''')
    
    # Passwords table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS passwords (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            service_name TEXT NOT NULL,
            username TEXT NOT NULL,
            encrypted_password BLOB NOT NULL,
            description TEXT,
            port INTEGER,
            url TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE(user_id, service_name),
            FOREIGN KEY(user_id) REFERENCES user_keys(user_id)
        )
    ''')
    
    conn.commit()
    conn.close()
    
    # Set proper permissions
    os.chmod(PASSWORD_DB_PATH, 0o600)

def create_or_get_user():
    """Create or get the system user and key"""
    init_database()
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    # Check if we already have a user
    cursor.execute('SELECT user_id, key_hash, salt FROM user_keys LIMIT 1')
    result = cursor.fetchone()
    
    if result:
        user_id, stored_hash, salt = result
        conn.close()
        return user_id, None, salt  # Don't return the hash
    else:
        # Create new user
        user_id = generate_user_id()
        user_key = generate_16_digit_key()
        key_hash, salt = hash_key_with_salt(user_key)
        
        now = datetime.now().isoformat()
        
        cursor.execute('''
            INSERT INTO user_keys (user_id, key_hash, salt, created_at, last_used)
            VALUES (?, ?, ?, ?, ?)
        ''', (user_id, key_hash, salt, now, now))
        
        conn.commit()
        conn.close()
        
        print(f"✓ Generated new user: {user_id}")
        print(f"✓ User key: {user_key}")
        print(f"⚠️  IMPORTANT: Save this key securely - it won't be shown again!")
        
        return user_id, user_key, salt

def verify_user_key(user_id, user_key):
    """Verify if the provided key is correct for the user"""
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('SELECT key_hash, salt FROM user_keys WHERE user_id = ?', (user_id,))
    result = cursor.fetchone()
    conn.close()
    
    if not result:
        return False
    
    stored_hash, salt = result
    key_hash, _ = hash_key_with_salt(user_key, salt)
    
    return key_hash == stored_hash

def encrypt_password(password, user_key, salt):
    """Encrypt a password using Fernet with user key"""
    key = derive_key_from_key(user_key, salt)
    f = Fernet(key)
    return f.encrypt(password.encode('utf-8'))

def decrypt_password(encrypted_password, user_key, salt):
    """Decrypt a password using Fernet with user key"""
    key = derive_key_from_key(user_key, salt)
    f = Fernet(key)
    return f.decrypt(encrypted_password).decode('utf-8')

def store_password(service_name, username, password, description="", port=0, url="", user_key=None):
    """Store or update a password in the database"""
    if not user_key:
        user_key = os.environ.get('BRLN_USER_KEY')
        if not user_key:
            print("✗ User key required (set BRLN_USER_KEY environment variable)", file=sys.stderr)
            return False
    
    init_database()
    
    # Get or create user
    user_id, generated_key, salt = create_or_get_user()
    
    if generated_key:
        # First time setup - use the generated key
        user_key = generated_key
    else:
        # Verify the provided key
        if not verify_user_key(user_id, user_key):
            print("✗ Invalid user key", file=sys.stderr)
            return False
    
    # Encrypt password with user key
    encrypted_password = encrypt_password(password, user_key, salt)
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    now = datetime.now().isoformat()
    
    try:
        # Check if service already exists for this user
        cursor.execute('SELECT id FROM passwords WHERE user_id = ? AND service_name = ?', (user_id, service_name))
        existing = cursor.fetchone()
        
        if existing:
            # Update existing entry
            cursor.execute('''
                UPDATE passwords 
                SET username = ?, encrypted_password = ?, description = ?, port = ?, url = ?, updated_at = ?
                WHERE user_id = ? AND service_name = ?
            ''', (username, encrypted_password, description, port, url, now, user_id, service_name))
            print(f"✓ Updated password for '{service_name}'")
        else:
            # Insert new entry
            cursor.execute('''
                INSERT INTO passwords (user_id, service_name, username, encrypted_password, description, port, url, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (user_id, service_name, username, encrypted_password, description, port, url, now, now))
            print(f"✓ Stored password for '{service_name}'")
        
        # Update last used time for user
        cursor.execute('UPDATE user_keys SET last_used = ? WHERE user_id = ?', (now, user_id))
        
        conn.commit()
        return True
    except Exception as e:
        print(f"✗ Error storing password: {e}", file=sys.stderr)
        return False
    finally:
        conn.close()

def get_password(service_name, user_key=None):
    """Retrieve a password from the database (returns the plaintext password)"""
    if not user_key:
        user_key = os.environ.get('BRLN_USER_KEY')
        if not user_key:
            print("✗ User key required (set BRLN_USER_KEY environment variable)", file=sys.stderr)
            return None
    
    if not os.path.exists(PASSWORD_DB_PATH):
        print(f"✗ Password database not found", file=sys.stderr)
        return None
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    # Get user info
    cursor.execute('SELECT user_id, salt FROM user_keys LIMIT 1')
    user_result = cursor.fetchone()
    
    if not user_result:
        print("✗ No user found in database", file=sys.stderr)
        conn.close()
        return None
    
    user_id, salt = user_result
    
    # Verify user key
    if not verify_user_key(user_id, user_key):
        print("✗ Invalid user key", file=sys.stderr)
        conn.close()
        return None
    
    # Get password
    cursor.execute('SELECT encrypted_password FROM passwords WHERE user_id = ? AND service_name = ?', (user_id, service_name))
    result = cursor.fetchone()
    conn.close()
    
    if result:
        try:
            encrypted_password = result[0]
            password = decrypt_password(encrypted_password, user_key, salt)
            return password
        except Exception as e:
            print(f"✗ Error decrypting password: {e}", file=sys.stderr)
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
        SELECT p.service_name, p.username, p.description, p.port, p.url, p.created_at, u.user_id
        FROM passwords p
        JOIN user_keys u ON p.user_id = u.user_id
        ORDER BY p.service_name
    ''')
    
    results = cursor.fetchall()
    conn.close()
    
    if not results:
        print("No passwords stored yet")
        return
    
    print(f"\n{'Service':<25} {'Username':<20} {'Description':<40}")
    print("=" * 85)
    for row in results:
        service, username, desc, port, url, created, user_id = row
        desc_short = desc[:37] + "..." if len(desc) > 40 else desc
        print(f"{service:<25} {username:<20} {desc_short:<40}")
    print()

def show_user_info():
    """Show user information"""
    if not os.path.exists(PASSWORD_DB_PATH):
        print("No user created yet")
        return
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('SELECT user_id, created_at, last_used FROM user_keys')
    result = cursor.fetchone()
    
    if result:
        user_id, created_at, last_used = result
        cursor.execute('SELECT COUNT(*) FROM passwords WHERE user_id = ?', (user_id,))
        password_count = cursor.fetchone()[0]
        
        print(f"\nUser ID: {user_id}")
        print(f"Created: {created_at}")
        print(f"Last used: {last_used}")
        print(f"Stored passwords: {password_count}")
        print()
    else:
        print("No user found")
    
    conn.close()

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
        print("  password_manager.py store <service> <username> <password> [description] [port] [url] [user_key]")
        print("  password_manager.py get <service> [user_key]")
        print("  password_manager.py list")
        print("  password_manager.py user")
        print("  password_manager.py delete <service>")
        print("")
        print("Environment: Set BRLN_USER_KEY to avoid passing user_key as parameter")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "store":
        if len(sys.argv) < 5:
            print("✗ Usage: store <service> <username> <password> [description] [port] [url] [user_key]", file=sys.stderr)
            sys.exit(1)
        
        service = sys.argv[2]
        username = sys.argv[3]
        password = sys.argv[4]
        description = sys.argv[5] if len(sys.argv) > 5 else ""
        port = int(sys.argv[6]) if len(sys.argv) > 6 else 0
        url = sys.argv[7] if len(sys.argv) > 7 else ""
        user_key = sys.argv[8] if len(sys.argv) > 8 else None
        
        store_password(service, username, password, description, port, url, user_key)
    
    elif command == "get":
        if len(sys.argv) < 3:
            print("✗ Usage: get <service> [user_key]", file=sys.stderr)
            sys.exit(1)
        
        service = sys.argv[2]
        user_key = sys.argv[3] if len(sys.argv) > 3 else None
        password = get_password(service, user_key)
        if password:
            print(password)
    
    elif command == "list":
        list_passwords()
    
    elif command == "user":
        show_user_info()
    
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
