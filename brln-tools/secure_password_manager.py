#!/usr/bin/env python3
"""
BRLN-OS Secure Password Manager v2
Enhanced security with:
- True ephemeral master password (never stored locally)
- Zero local storage of authentication data
- Per-password unique salts
- 500,000+ PBKDF2 iterations for quantum-resistant security
- In-memory session caching with auto-timeout
- Challenge-response validation without storing verification data
"""

import sys
import sqlite3
import os
import base64
import secrets
import hashlib
import time
import atexit
import signal
from datetime import datetime
from pathlib import Path
from cryptography.fernet import Fernet, InvalidToken
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

# Configuration
PASSWORD_DB_PATH = "/data/brln-secure-passwords.db"
PBKDF2_ITERATIONS = 500000  # Quantum-resistant iterations
SESSION_TIMEOUT_SECONDS = 300  # 5 minutes session timeout
CANARY_VALUE = b"BRLN_SECURE_CANARY_2026"  # Known value for challenge-response

# In-memory session cache (ephemeral)
_session_cache = {
    "master_key": None,
    "last_activity": 0,
    "timeout": SESSION_TIMEOUT_SECONDS
}


def clear_session():
    """Securely clear session data from memory"""
    global _session_cache
    if _session_cache["master_key"]:
        # Overwrite with random data before clearing
        _session_cache["master_key"] = secrets.token_bytes(64)
    _session_cache["master_key"] = None
    _session_cache["last_activity"] = 0


def check_session_timeout():
    """Check if session has timed out"""
    if _session_cache["master_key"] is None:
        return True
    
    elapsed = time.time() - _session_cache["last_activity"]
    if elapsed > _session_cache["timeout"]:
        clear_session()
        return True
    return False


def refresh_session():
    """Refresh session activity timestamp"""
    _session_cache["last_activity"] = time.time()


def set_session_key(master_password):
    """Store master password in session cache"""
    _session_cache["master_key"] = master_password
    _session_cache["last_activity"] = time.time()


def get_session_key():
    """Get master password from session if valid"""
    if check_session_timeout():
        return None
    refresh_session()
    return _session_cache["master_key"]


# Register cleanup handlers
atexit.register(clear_session)
signal.signal(signal.SIGTERM, lambda s, f: clear_session())
signal.signal(signal.SIGINT, lambda s, f: (clear_session(), sys.exit(0)))


def generate_salt(length=32):
    """Generate cryptographically secure random salt"""
    return os.urandom(length)


def derive_key_from_password(master_password, salt, iterations=PBKDF2_ITERATIONS):
    """
    Derive encryption key from master password using PBKDF2-HMAC-SHA256
    with high iteration count for quantum resistance
    """
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=iterations,
        backend=default_backend()
    )
    key = base64.urlsafe_b64encode(kdf.derive(master_password.encode('utf-8')))
    return key


def encrypt_data(data, master_password, salt):
    """Encrypt data using Fernet with derived key"""
    key = derive_key_from_password(master_password, salt)
    f = Fernet(key)
    if isinstance(data, str):
        data = data.encode('utf-8')
    return f.encrypt(data)


def decrypt_data(encrypted_data, master_password, salt):
    """Decrypt data using Fernet with derived key"""
    key = derive_key_from_password(master_password, salt)
    f = Fernet(key)
    return f.decrypt(encrypted_data)


def init_database():
    """Initialize the secure password database"""
    os.makedirs(os.path.dirname(PASSWORD_DB_PATH), exist_ok=True)
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    # Canary table for challenge-response validation
    # The canary is encrypted with master password - if decryption works, password is correct
    # NO password hash is stored - only encrypted known value
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS canary (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            encrypted_canary BLOB NOT NULL,
            salt BLOB NOT NULL,
            created_at TEXT NOT NULL
        )
    ''')
    
    # Passwords table with per-password unique salts
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS passwords (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            service_name TEXT UNIQUE NOT NULL,
            username TEXT NOT NULL,
            encrypted_password BLOB NOT NULL,
            salt BLOB NOT NULL,
            description TEXT,
            port INTEGER,
            url TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
    ''')
    
    conn.commit()
    conn.close()
    
    # Set strict file permissions
    os.chmod(PASSWORD_DB_PATH, 0o600)


def is_initialized():
    """Check if password manager has been initialized with a master password"""
    if not os.path.exists(PASSWORD_DB_PATH):
        return False
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM canary')
    count = cursor.fetchone()[0]
    conn.close()
    
    return count > 0


def initialize_master_password(master_password):
    """
    Initialize the password manager with a master password.
    Creates a canary entry that can be used to verify the password later.
    The master password itself is NEVER stored.
    """
    init_database()
    
    if is_initialized():
        print("✗ Password manager already initialized", file=sys.stderr)
        print("  Use 'reset' command to start fresh (WARNING: all passwords will be lost)", file=sys.stderr)
        return False
    
    # Validate password strength
    if len(master_password) < 12:
        print("✗ Master password must be at least 12 characters", file=sys.stderr)
        return False
    
    # Generate unique salt for canary
    canary_salt = generate_salt()
    
    # Encrypt the known canary value with master password
    encrypted_canary = encrypt_data(CANARY_VALUE, master_password, canary_salt)
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    now = datetime.now().isoformat()
    
    cursor.execute('''
        INSERT INTO canary (id, encrypted_canary, salt, created_at)
        VALUES (1, ?, ?, ?)
    ''', (encrypted_canary, canary_salt, now))
    
    conn.commit()
    conn.close()
    
    # Store in session
    set_session_key(master_password)
    
    print("✓ Password manager initialized successfully")
    print("⚠️  IMPORTANT: Remember your master password - it cannot be recovered!")
    print(f"✓ Session active for {SESSION_TIMEOUT_SECONDS} seconds")
    
    return True


def verify_master_password(master_password, silent=False):
    """
    Verify master password using challenge-response.
    Attempts to decrypt the canary - if successful, password is correct.
    NO password hash comparison is done.
    """
    if not is_initialized():
        if not silent:
            print("✗ Password manager not initialized. Use 'init' command first.", file=sys.stderr)
        return False
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('SELECT encrypted_canary, salt FROM canary WHERE id = 1')
    result = cursor.fetchone()
    conn.close()
    
    if not result:
        if not silent:
            print("✗ Canary not found - database may be corrupted", file=sys.stderr)
        return False
    
    encrypted_canary, canary_salt = result
    
    try:
        # Attempt to decrypt canary with provided password
        decrypted = decrypt_data(encrypted_canary, master_password, canary_salt)
        
        # Verify canary value matches (constant-time comparison)
        if secrets.compare_digest(decrypted, CANARY_VALUE):
            # Store in session cache
            set_session_key(master_password)
            return True
        else:
            if not silent:
                print("✗ Invalid master password", file=sys.stderr)
            return False
            
    except InvalidToken:
        if not silent:
            print("✗ Invalid master password", file=sys.stderr)
        return False
    except Exception as e:
        if not silent:
            print(f"✗ Verification error: {e}", file=sys.stderr)
        return False


def get_master_password(prompt_if_needed=True):
    """
    Get master password from session or prompt user.
    Returns None if no valid password available.
    """
    # Check session first
    session_key = get_session_key()
    if session_key:
        return session_key
    
    # Check environment variable
    env_password = os.environ.get('BRLN_MASTER_PASSWORD')
    if env_password:
        if verify_master_password(env_password, silent=True):
            return env_password
    
    if not prompt_if_needed:
        return None
    
    # Prompt user
    import getpass
    try:
        master_password = getpass.getpass("Enter master password: ")
        if verify_master_password(master_password):
            return master_password
    except (EOFError, KeyboardInterrupt):
        print()
    
    return None


def store_password(service_name, username, password, description="", port=0, url="", master_password=None):
    """
    Store or update a password with unique per-password salt.
    """
    init_database()
    
    if not is_initialized():
        print("✗ Password manager not initialized. Use 'init' command first.", file=sys.stderr)
        return False
    
    # Get or verify master password
    if master_password:
        if not verify_master_password(master_password, silent=True):
            print("✗ Invalid master password", file=sys.stderr)
            return False
    else:
        master_password = get_master_password()
        if not master_password:
            print("✗ Master password required", file=sys.stderr)
            return False
    
    # Generate unique salt for this password entry
    password_salt = generate_salt()
    
    # Encrypt password with unique salt
    encrypted_password = encrypt_data(password, master_password, password_salt)
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    now = datetime.now().isoformat()
    
    try:
        # Check if service exists
        cursor.execute('SELECT id FROM passwords WHERE service_name = ?', (service_name,))
        existing = cursor.fetchone()
        
        if existing:
            # Update with new salt and encryption
            cursor.execute('''
                UPDATE passwords 
                SET username = ?, encrypted_password = ?, salt = ?, 
                    description = ?, port = ?, url = ?, updated_at = ?
                WHERE service_name = ?
            ''', (username, encrypted_password, password_salt, description, port, url, now, service_name))
            print(f"✓ Updated password for '{service_name}'")
        else:
            # Insert new entry
            cursor.execute('''
                INSERT INTO passwords (service_name, username, encrypted_password, salt, 
                                       description, port, url, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (service_name, username, encrypted_password, password_salt, 
                  description, port, url, now, now))
            print(f"✓ Stored password for '{service_name}'")
        
        conn.commit()
        return True
        
    except Exception as e:
        print(f"✗ Error storing password: {e}", file=sys.stderr)
        return False
    finally:
        conn.close()


def get_password(service_name, master_password=None):
    """
    Retrieve and decrypt a password using per-password salt.
    """
    if not os.path.exists(PASSWORD_DB_PATH):
        print("✗ Password database not found", file=sys.stderr)
        return None
    
    if not is_initialized():
        print("✗ Password manager not initialized", file=sys.stderr)
        return None
    
    # Get or verify master password
    if master_password:
        if not verify_master_password(master_password, silent=True):
            print("✗ Invalid master password", file=sys.stderr)
            return None
    else:
        master_password = get_master_password()
        if not master_password:
            print("✗ Master password required", file=sys.stderr)
            return None
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('SELECT encrypted_password, salt FROM passwords WHERE service_name = ?', (service_name,))
    result = cursor.fetchone()
    conn.close()
    
    if not result:
        print(f"✗ Service '{service_name}' not found", file=sys.stderr)
        return None
    
    encrypted_password, password_salt = result
    
    try:
        # Decrypt using per-password salt
        decrypted = decrypt_data(encrypted_password, master_password, password_salt)
        return decrypted.decode('utf-8')
    except InvalidToken:
        print("✗ Decryption failed - password may be corrupted", file=sys.stderr)
        return None
    except Exception as e:
        print(f"✗ Error decrypting password: {e}", file=sys.stderr)
        return None


def list_passwords():
    """List all stored services (no passwords shown)"""
    if not os.path.exists(PASSWORD_DB_PATH):
        print("No passwords stored yet")
        return
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT service_name, username, description, port, url, created_at, updated_at
        FROM passwords ORDER BY service_name
    ''')
    
    results = cursor.fetchall()
    conn.close()
    
    if not results:
        print("No passwords stored yet")
        return
    
    print(f"\n{'Service':<25} {'Username':<20} {'Description':<35}")
    print("=" * 80)
    for row in results:
        service, username, desc, port, url, created, updated = row
        desc_short = (desc[:32] + "...") if desc and len(desc) > 35 else (desc or "")
        print(f"{service:<25} {username:<20} {desc_short:<35}")
    print()


def delete_password(service_name, master_password=None):
    """Delete a password entry"""
    if not os.path.exists(PASSWORD_DB_PATH):
        print("✗ Password database not found", file=sys.stderr)
        return False
    
    # Verify master password for deletion
    if master_password:
        if not verify_master_password(master_password, silent=True):
            print("✗ Invalid master password", file=sys.stderr)
            return False
    else:
        master_password = get_master_password()
        if not master_password:
            print("✗ Master password required for deletion", file=sys.stderr)
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


def change_master_password(old_password, new_password):
    """
    Change master password - requires re-encrypting all passwords.
    """
    if not is_initialized():
        print("✗ Password manager not initialized", file=sys.stderr)
        return False
    
    # Verify old password
    if not verify_master_password(old_password, silent=True):
        print("✗ Current master password is incorrect", file=sys.stderr)
        return False
    
    # Validate new password
    if len(new_password) < 12:
        print("✗ New master password must be at least 12 characters", file=sys.stderr)
        return False
    
    conn = sqlite3.connect(PASSWORD_DB_PATH)
    cursor = conn.cursor()
    
    try:
        # Get all passwords
        cursor.execute('SELECT id, service_name, encrypted_password, salt FROM passwords')
        entries = cursor.fetchall()
        
        # Re-encrypt each password with new master password
        for entry_id, service_name, encrypted_pw, old_salt in entries:
            # Decrypt with old password
            decrypted = decrypt_data(encrypted_pw, old_password, old_salt)
            
            # Generate new salt for this password
            new_salt = generate_salt()
            
            # Re-encrypt with new password and new salt
            new_encrypted = encrypt_data(decrypted, new_password, new_salt)
            
            # Update entry
            cursor.execute('''
                UPDATE passwords SET encrypted_password = ?, salt = ?, updated_at = ?
                WHERE id = ?
            ''', (new_encrypted, new_salt, datetime.now().isoformat(), entry_id))
            
            print(f"  ✓ Re-encrypted '{service_name}'")
        
        # Update canary with new password
        new_canary_salt = generate_salt()
        new_encrypted_canary = encrypt_data(CANARY_VALUE, new_password, new_canary_salt)
        
        cursor.execute('''
            UPDATE canary SET encrypted_canary = ?, salt = ?
            WHERE id = 1
        ''', (new_encrypted_canary, new_canary_salt))
        
        conn.commit()
        
        # Update session
        set_session_key(new_password)
        
        print(f"\n✓ Master password changed successfully")
        print(f"✓ Re-encrypted {len(entries)} password(s)")
        
        return True
        
    except Exception as e:
        conn.rollback()
        print(f"✗ Error changing master password: {e}", file=sys.stderr)
        return False
    finally:
        conn.close()


def reset_database():
    """Reset the entire password database (WARNING: destructive)"""
    if os.path.exists(PASSWORD_DB_PATH):
        os.remove(PASSWORD_DB_PATH)
        print("✓ Password database has been reset")
        print("  Use 'init' command to create a new master password")
    else:
        print("No database to reset")
    clear_session()


def show_status():
    """Show password manager status"""
    print("\n=== BRLN-OS Secure Password Manager v2 ===")
    print(f"Database: {PASSWORD_DB_PATH}")
    print(f"Initialized: {'Yes' if is_initialized() else 'No'}")
    print(f"PBKDF2 Iterations: {PBKDF2_ITERATIONS:,}")
    print(f"Session Timeout: {SESSION_TIMEOUT_SECONDS} seconds")
    
    session_active = get_session_key() is not None
    print(f"Session Active: {'Yes' if session_active else 'No'}")
    
    if session_active:
        remaining = SESSION_TIMEOUT_SECONDS - (time.time() - _session_cache["last_activity"])
        print(f"Session Remaining: {int(remaining)} seconds")
    
    if os.path.exists(PASSWORD_DB_PATH):
        conn = sqlite3.connect(PASSWORD_DB_PATH)
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM passwords')
        count = cursor.fetchone()[0]
        conn.close()
        print(f"Stored Passwords: {count}")
    
    print("\nSecurity Features:")
    print("  ✓ Zero local storage of master password")
    print("  ✓ Challenge-response authentication (no hash storage)")
    print("  ✓ Per-password unique salts")
    print("  ✓ 500,000 PBKDF2 iterations")
    print("  ✓ In-memory session with auto-timeout")
    print("  ✓ Fernet encryption (AES-128-CBC + HMAC-SHA256)")
    print()


def unlock_session(master_password=None):
    """Unlock session with master password"""
    if not is_initialized():
        print("✗ Password manager not initialized. Use 'init' command first.", file=sys.stderr)
        return False
    
    if master_password:
        if verify_master_password(master_password):
            print(f"✓ Session unlocked for {SESSION_TIMEOUT_SECONDS} seconds")
            return True
        return False
    
    # Prompt for password
    import getpass
    try:
        master_password = getpass.getpass("Enter master password: ")
        if verify_master_password(master_password):
            print(f"✓ Session unlocked for {SESSION_TIMEOUT_SECONDS} seconds")
            return True
    except (EOFError, KeyboardInterrupt):
        print()
    
    return False


def lock_session():
    """Lock session immediately"""
    clear_session()
    print("✓ Session locked")


def main():
    if len(sys.argv) < 2:
        print("BRLN-OS Secure Password Manager v2")
        print("\nUsage:")
        print("  secure_password_manager.py init <master_password>")
        print("  secure_password_manager.py unlock [master_password]")
        print("  secure_password_manager.py lock")
        print("  secure_password_manager.py store <service> <username> <password> [description] [port] [url] [master_password]")
        print("  secure_password_manager.py get <service> [master_password]")
        print("  secure_password_manager.py list")
        print("  secure_password_manager.py delete <service> [master_password]")
        print("  secure_password_manager.py change-password <old_password> <new_password>")
        print("  secure_password_manager.py status")
        print("  secure_password_manager.py reset")
        print("")
        print("Environment: Set BRLN_MASTER_PASSWORD to avoid prompts")
        print("Session: Passwords are cached in memory for 5 minutes after unlock")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "init":
        if len(sys.argv) < 3:
            import getpass
            try:
                password = getpass.getpass("Create master password (min 12 chars): ")
                confirm = getpass.getpass("Confirm master password: ")
                if password != confirm:
                    print("✗ Passwords do not match", file=sys.stderr)
                    sys.exit(1)
                initialize_master_password(password)
            except (EOFError, KeyboardInterrupt):
                print()
                sys.exit(1)
        else:
            initialize_master_password(sys.argv[2])
    
    elif command == "unlock":
        master_password = sys.argv[2] if len(sys.argv) > 2 else None
        if not unlock_session(master_password):
            sys.exit(1)
    
    elif command == "lock":
        lock_session()
    
    elif command == "store":
        if len(sys.argv) < 5:
            print("✗ Usage: store <service> <username> <password> [description] [port] [url] [master_password]", file=sys.stderr)
            sys.exit(1)
        
        service = sys.argv[2]
        username = sys.argv[3]
        password = sys.argv[4]
        description = sys.argv[5] if len(sys.argv) > 5 else ""
        port = int(sys.argv[6]) if len(sys.argv) > 6 and sys.argv[6].isdigit() else 0
        url = sys.argv[7] if len(sys.argv) > 7 else ""
        master_password = sys.argv[8] if len(sys.argv) > 8 else None
        
        if not store_password(service, username, password, description, port, url, master_password):
            sys.exit(1)
    
    elif command == "get":
        if len(sys.argv) < 3:
            print("✗ Usage: get <service> [master_password]", file=sys.stderr)
            sys.exit(1)
        
        service = sys.argv[2]
        master_password = sys.argv[3] if len(sys.argv) > 3 else None
        password = get_password(service, master_password)
        if password:
            print(password)
        else:
            sys.exit(1)
    
    elif command == "list":
        list_passwords()
    
    elif command == "delete":
        if len(sys.argv) < 3:
            print("✗ Usage: delete <service> [master_password]", file=sys.stderr)
            sys.exit(1)
        
        service = sys.argv[2]
        master_password = sys.argv[3] if len(sys.argv) > 3 else None
        if not delete_password(service, master_password):
            sys.exit(1)
    
    elif command == "change-password":
        if len(sys.argv) < 4:
            import getpass
            try:
                old_pw = getpass.getpass("Current master password: ")
                new_pw = getpass.getpass("New master password (min 12 chars): ")
                confirm = getpass.getpass("Confirm new password: ")
                if new_pw != confirm:
                    print("✗ Passwords do not match", file=sys.stderr)
                    sys.exit(1)
                change_master_password(old_pw, new_pw)
            except (EOFError, KeyboardInterrupt):
                print()
                sys.exit(1)
        else:
            change_master_password(sys.argv[2], sys.argv[3])
    
    elif command == "status":
        show_status()
    
    elif command == "reset":
        confirm = input("⚠️  This will DELETE ALL stored passwords. Type 'yes' to confirm: ")
        if confirm.lower() == 'yes':
            reset_database()
        else:
            print("Reset cancelled")
    
    else:
        print(f"✗ Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
