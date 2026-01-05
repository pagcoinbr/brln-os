#!/usr/bin/env python3
"""
BRLN-OS Session Authentication Module
Provides session-based authentication using the master password from secure_password_manager

This module integrates with the existing secure_password_manager to provide:
- Session-based authentication via HTTP-only cookies
- Master password validation using canary challenge-response
- Automatic session timeout (5 minutes)
- Secure session storage with encrypted passwords
"""

import time
import secrets
import os
import sys
from functools import wraps
from flask import request, jsonify, g

# Add brln-tools to path for secure_password_manager
sys.path.insert(0, '/root/brln-os/brln-tools')

try:
    from secure_password_manager import (
        verify_master_password,
        set_session_key,
        get_session_key,
        check_session_timeout,
        SESSION_TIMEOUT_SECONDS,
        is_initialized
    )
    HAS_SECURE_PM = True
except ImportError as e:
    print(f"Warning: Could not import secure_password_manager: {e}")
    HAS_SECURE_PM = False
    SESSION_TIMEOUT_SECONDS = 300

# In-memory session storage
# In production, consider using Redis for multi-process support
_sessions = {}


class SessionManager:
    """
    Manages user sessions with master password encryption.
    
    Security features:
    - Sessions stored with master password for encryption operations
    - Automatic timeout after SESSION_TIMEOUT_SECONDS (5 minutes)
    - Secure session ID generation using secrets module
    - Memory cleanup on session destruction
    """
    
    def __init__(self):
        self.session_timeout = SESSION_TIMEOUT_SECONDS
    
    def authenticate(self, master_password):
        """
        Authenticate user with master password.
        
        Uses secure_password_manager's canary challenge-response validation.
        NO password hash is compared - we decrypt a known value instead.
        
        Args:
            master_password: The user's master password
            
        Returns:
            tuple: (session_id, error_message)
        """
        if not HAS_SECURE_PM:
            return None, "Secure password manager not available"
        
        if not is_initialized():
            return None, "Password manager not initialized. Run brunel.sh first."
        
        # Verify password using canary decryption (challenge-response)
        if not verify_master_password(master_password, silent=True):
            # Log failed attempt
            self._log_auth_attempt(False, request.remote_addr if request else 'unknown')
            return None, "Invalid master password"
        
        # Create new session
        session_id = secrets.token_urlsafe(32)
        
        _sessions[session_id] = {
            'master_password': master_password,
            'created_at': time.time(),
            'last_access': time.time(),
            'ip_address': request.remote_addr if request else 'unknown'
        }
        
        # Log successful authentication
        self._log_auth_attempt(True, request.remote_addr if request else 'unknown')
        
        # Also set in secure_password_manager's session (for CLI compatibility)
        set_session_key(master_password)
        
        return session_id, None
    
    def get_session(self, session_id):
        """
        Get session data if valid and not expired.
        
        Args:
            session_id: The session ID from cookie
            
        Returns:
            dict: Session data or None if expired/invalid
        """
        if not session_id or session_id not in _sessions:
            return None
        
        session = _sessions[session_id]
        
        # Check timeout
        elapsed = time.time() - session['last_access']
        if elapsed > self.session_timeout:
            self.destroy_session(session_id)
            return None
        
        # Refresh last access time
        session['last_access'] = time.time()
        
        return session
    
    def get_master_password(self, session_id):
        """
        Get master password from session for encryption operations.
        
        Args:
            session_id: The session ID
            
        Returns:
            str: Master password or None
        """
        session = self.get_session(session_id)
        if session:
            return session['master_password']
        return None
    
    def extend_session(self, session_id):
        """
        Extend session timeout by resetting last_access time.
        
        Args:
            session_id: The session ID
            
        Returns:
            dict: Result with success status and new expiration
        """
        if session_id not in _sessions:
            return {'success': False, 'error': 'Session not found'}
        
        session = _sessions[session_id]
        elapsed = time.time() - session['last_access']
        
        if elapsed > self.session_timeout:
            # Session already expired
            self.destroy_session(session_id)
            return {'success': False, 'error': 'Session expired'}
        
        # Reset last_access to extend timeout
        import datetime
        session['last_access'] = time.time()
        new_expires = datetime.datetime.now() + datetime.timedelta(seconds=self.session_timeout)
        
        return {
            'success': True,
            'new_expires': new_expires.isoformat()
        }
    
    def destroy_session(self, session_id):
        """
        Destroy session and securely clear password from memory.
        
        Args:
            session_id: The session ID to destroy
        """
        if session_id in _sessions:
            # Overwrite password with random data before deletion
            _sessions[session_id]['master_password'] = secrets.token_bytes(64)
            del _sessions[session_id]
    
    def is_authenticated(self, session_id):
        """
        Check if session is valid without refreshing.
        
        Args:
            session_id: The session ID
            
        Returns:
            bool: True if authenticated
        """
        if not session_id or session_id not in _sessions:
            return False
        
        session = _sessions[session_id]
        elapsed = time.time() - session['last_access']
        
        return elapsed <= self.session_timeout
    
    def get_session_info(self, session_id):
        """
        Get session info (without password) for status check.
        
        Args:
            session_id: The session ID
            
        Returns:
            dict: Session info or None
        """
        import datetime
        session = self.get_session(session_id)
        if session:
            expires_in = self.session_timeout - (time.time() - session['last_access'])
            expires_at = datetime.datetime.now() + datetime.timedelta(seconds=expires_in)
            return {
                'created_at': session['created_at'],
                'last_access': session['last_access'],
                'ip_address': session['ip_address'],
                'expires_in': expires_in,
                'expires': expires_at.isoformat()
            }
        return None
    
    def _log_auth_attempt(self, success, ip_address):
        """Log authentication attempt for audit trail"""
        import datetime
        
        log_file = '/var/log/brln-auth.log'
        timestamp = datetime.datetime.now().isoformat()
        status = 'SUCCESS' if success else 'FAILED'
        
        try:
            with open(log_file, 'a') as f:
                f.write(f"{timestamp} | {status} | IP: {ip_address}\n")
        except Exception as e:
            print(f"Warning: Could not log auth attempt: {e}")


# Global session manager instance
session_manager = SessionManager()


def require_auth(f):
    """
    Decorator to require authenticated session for endpoint.
    
    Usage:
        @app.route('/api/v1/wallet/save', methods=['POST'])
        @require_auth
        def save_wallet():
            # g.master_password contains the password
            password = g.master_password
            ...
    
    The decorator:
    1. Checks for brln_session cookie
    2. Validates session is not expired
    3. Adds master_password to Flask's g object
    4. Returns 401 if not authenticated
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        session_id = request.cookies.get('brln_session')
        
        if not session_id:
            return jsonify({
                'error': 'Authentication required',
                'code': 'AUTH_REQUIRED',
                'message': 'Please login with your master password'
            }), 401
        
        session = session_manager.get_session(session_id)
        
        if not session:
            return jsonify({
                'error': 'Session expired',
                'code': 'SESSION_EXPIRED',
                'message': 'Your session has expired. Please login again.'
            }), 401
        
        # Add session data to Flask's g object for use in endpoint
        g.master_password = session['master_password']
        g.session_id = session_id
        g.session_data = session
        
        return f(*args, **kwargs)
    
    return decorated_function


def optional_auth(f):
    """
    Decorator that provides authentication if available, but doesn't require it.
    
    Useful for endpoints that can work both authenticated and unauthenticated.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        session_id = request.cookies.get('brln_session')
        
        if session_id:
            session = session_manager.get_session(session_id)
            if session:
                g.master_password = session['master_password']
                g.session_id = session_id
                g.session_data = session
                g.is_authenticated = True
            else:
                g.master_password = None
                g.session_id = None
                g.session_data = None
                g.is_authenticated = False
        else:
            g.master_password = None
            g.session_id = None
            g.session_data = None
            g.is_authenticated = False
        
        return f(*args, **kwargs)
    
    return decorated_function


# Convenience functions for use without decorator
def authenticate(master_password):
    """
    Authenticate and create session.
    
    Returns:
        dict: {
            'success': bool,
            'session_id': str (if success),
            'session_expires': str (if success),
            'error': str (if failure)
        }
    """
    import datetime
    session_id, error = session_manager.authenticate(master_password)
    
    if session_id:
        # Calculate expiration time
        expires = datetime.datetime.now() + datetime.timedelta(seconds=SESSION_TIMEOUT_SECONDS)
        return {
            'success': True,
            'session_id': session_id,
            'session_expires': expires.isoformat()
        }
    else:
        return {
            'success': False,
            'error': error or 'Authentication failed'
        }


def get_session(session_id):
    """Get session data"""
    return session_manager.get_session(session_id)


def destroy_session(session_id):
    """Destroy session"""
    session_manager.destroy_session(session_id)


def is_authenticated(session_id):
    """Check if authenticated"""
    return session_manager.is_authenticated(session_id)


def get_master_password_from_session(session_id):
    """Get master password from session"""
    return session_manager.get_master_password(session_id)


# For testing
if __name__ == '__main__':
    print("Session Authentication Module")
    print("=" * 50)
    print(f"Secure Password Manager Available: {HAS_SECURE_PM}")
    print(f"Session Timeout: {SESSION_TIMEOUT_SECONDS} seconds")
    
    if HAS_SECURE_PM:
        print(f"Password Manager Initialized: {is_initialized()}")
