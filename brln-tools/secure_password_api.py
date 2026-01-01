#!/usr/bin/env python3
"""
Secure Password Manager API Integration Module
Provides Python API for integrating secure password manager into applications
"""

import os
import sys
import time
import subprocess
from pathlib import Path
from typing import Optional, Dict, Tuple

# Path to secure password manager script
SCRIPT_DIR = Path(__file__).parent
SECURE_PM_SCRIPT = SCRIPT_DIR / "secure_password_manager.py"

# In-memory cache for retrieved passwords
_password_cache: Dict[str, Tuple[str, float]] = {}
_cache_ttl: int = 300  # 5 minutes cache TTL (matches session timeout)


class SecurePasswordManagerError(Exception):
    """Custom exception for password manager errors"""
    pass


class SecurePasswordAPI:
    """
    Python API for secure password manager integration
    Provides methods to retrieve, store, and manage passwords programmatically
    """
    
    def __init__(self, master_password: Optional[str] = None, cache_enabled: bool = True):
        """
        Initialize the Secure Password Manager API
        
        Args:
            master_password: Master password for authentication (optional if set in env)
            cache_enabled: Whether to cache retrieved passwords in memory
        """
        self.master_password = master_password or os.environ.get('BRLN_MASTER_PASSWORD')
        self.cache_enabled = cache_enabled
        self.script_path = str(SECURE_PM_SCRIPT)
        
        # Verify script exists
        if not SECURE_PM_SCRIPT.exists():
            raise SecurePasswordManagerError(
                f"Secure password manager script not found at {self.script_path}"
            )
    
    def _run_command(self, *args, timeout: int = 10) -> Tuple[bool, str]:
        """
        Run secure password manager command
        
        Args:
            *args: Command arguments
            timeout: Command timeout in seconds
            
        Returns:
            Tuple of (success: bool, output: str)
        """
        try:
            env = os.environ.copy()
            if self.master_password:
                env['BRLN_MASTER_PASSWORD'] = self.master_password
            
            result = subprocess.run(
                ['python3', self.script_path, *args],
                capture_output=True,
                text=True,
                timeout=timeout,
                env=env
            )
            
            if result.returncode == 0:
                return True, result.stdout.strip()
            else:
                return False, result.stderr.strip()
                
        except subprocess.TimeoutExpired:
            return False, "Command timeout expired"
        except Exception as e:
            return False, f"Command execution error: {str(e)}"
    
    def is_initialized(self) -> bool:
        """
        Check if password manager is initialized
        
        Returns:
            True if initialized, False otherwise
        """
        success, output = self._run_command('status')
        if success:
            return 'Initialized: Yes' in output
        return False
    
    def get_password(self, service_name: str, use_cache: bool = True) -> Optional[str]:
        """
        Retrieve a password from the secure password manager
        
        Args:
            service_name: Name of the service to retrieve password for
            use_cache: Whether to use cached password if available
            
        Returns:
            Password string if found, None otherwise
        """
        # Check cache first
        if use_cache and self.cache_enabled:
            cached = self._get_from_cache(service_name)
            if cached:
                return cached
        
        # Retrieve from password manager
        success, output = self._run_command('get', service_name)
        
        if success and output and not output.startswith('✗'):
            # Cache the password
            if self.cache_enabled:
                self._add_to_cache(service_name, output)
            return output
        
        return None
    
    def store_password(
        self, 
        service_name: str, 
        username: str, 
        password: str,
        description: str = "",
        port: int = 0,
        url: str = ""
    ) -> bool:
        """
        Store a password in the secure password manager
        
        Args:
            service_name: Name of the service
            username: Username for the service
            password: Password to store
            description: Optional description
            port: Optional port number
            url: Optional URL
            
        Returns:
            True if successful, False otherwise
        """
        args = [
            'store',
            service_name,
            username,
            password,
            description,
            str(port),
            url
        ]
        
        if self.master_password:
            args.append(self.master_password)
        
        success, _ = self._run_command(*args)
        
        # Clear cache for this service
        if success and self.cache_enabled:
            self._remove_from_cache(service_name)
        
        return success
    
    def delete_password(self, service_name: str) -> bool:
        """
        Delete a password from the secure password manager
        
        Args:
            service_name: Name of the service to delete
            
        Returns:
            True if successful, False otherwise
        """
        success, _ = self._run_command('delete', service_name)
        
        # Clear cache
        if success and self.cache_enabled:
            self._remove_from_cache(service_name)
        
        return success
    
    def list_services(self) -> list:
        """
        List all stored services
        
        Returns:
            List of service names
        """
        success, output = self._run_command('list')
        
        if not success:
            return []
        
        # Parse the table output
        services = []
        lines = output.strip().split('\n')
        
        for line in lines:
            # Skip header and separator lines
            if line.startswith('Service') or line.startswith('=') or not line.strip():
                continue
            
            # Extract service name (first column)
            parts = line.split()
            if parts:
                services.append(parts[0])
        
        return services
    
    def unlock_session(self, master_password: Optional[str] = None) -> bool:
        """
        Unlock the password manager session
        
        Args:
            master_password: Master password (optional if set in instance or env)
            
        Returns:
            True if successful, False otherwise
        """
        password = master_password or self.master_password
        if not password:
            return False
        
        # Temporarily set master password
        old_password = self.master_password
        self.master_password = password
        
        success, _ = self._run_command('unlock', password)
        
        # Restore old password if unlock failed
        if not success:
            self.master_password = old_password
        
        return success
    
    def lock_session(self) -> bool:
        """
        Lock the password manager session
        
        Returns:
            True if successful, False otherwise
        """
        success, _ = self._run_command('lock')
        
        # Clear all cached passwords
        if success:
            self.clear_cache()
        
        return success
    
    def get_status(self) -> Dict[str, any]:
        """
        Get password manager status information
        
        Returns:
            Dictionary with status information
        """
        success, output = self._run_command('status')
        
        if not success:
            return {'initialized': False, 'error': output}
        
        # Parse status output
        status = {
            'initialized': False,
            'session_active': False,
            'stored_passwords': 0,
            'iterations': 500000,
            'session_timeout': 300
        }
        
        for line in output.split('\n'):
            if 'Initialized:' in line:
                status['initialized'] = 'Yes' in line
            elif 'Session Active:' in line:
                status['session_active'] = 'Yes' in line
            elif 'Stored Passwords:' in line:
                parts = line.split(':')
                if len(parts) > 1:
                    try:
                        status['stored_passwords'] = int(parts[1].strip())
                    except ValueError:
                        pass
        
        return status
    
    def _get_from_cache(self, service_name: str) -> Optional[str]:
        """Get password from cache if not expired"""
        if service_name in _password_cache:
            password, timestamp = _password_cache[service_name]
            if time.time() - timestamp < _cache_ttl:
                return password
            else:
                # Expired, remove from cache
                del _password_cache[service_name]
        return None
    
    def _add_to_cache(self, service_name: str, password: str):
        """Add password to cache with current timestamp"""
        _password_cache[service_name] = (password, time.time())
    
    def _remove_from_cache(self, service_name: str):
        """Remove password from cache"""
        if service_name in _password_cache:
            del _password_cache[service_name]
    
    def clear_cache(self):
        """Clear all cached passwords"""
        _password_cache.clear()
    
    def set_cache_ttl(self, ttl: int):
        """
        Set cache time-to-live
        
        Args:
            ttl: Time-to-live in seconds
        """
        global _cache_ttl
        _cache_ttl = ttl


# Convenience functions for simple usage
_default_api: Optional[SecurePasswordAPI] = None


def get_default_api() -> SecurePasswordAPI:
    """Get or create default API instance"""
    global _default_api
    if _default_api is None:
        _default_api = SecurePasswordAPI()
    return _default_api


def get_password(service_name: str, master_password: Optional[str] = None) -> Optional[str]:
    """
    Simple function to retrieve a password
    
    Args:
        service_name: Name of the service
        master_password: Optional master password
        
    Returns:
        Password string or None
    """
    api = get_default_api()
    if master_password and api.master_password != master_password:
        api.master_password = master_password
    return api.get_password(service_name)


def store_password(
    service_name: str, 
    username: str, 
    password: str,
    master_password: Optional[str] = None,
    **kwargs
) -> bool:
    """
    Simple function to store a password
    
    Args:
        service_name: Name of the service
        username: Username
        password: Password to store
        master_password: Optional master password
        **kwargs: Additional arguments (description, port, url)
        
    Returns:
        True if successful
    """
    api = get_default_api()
    if master_password and api.master_password != master_password:
        api.master_password = master_password
    
    return api.store_password(
        service_name,
        username,
        password,
        kwargs.get('description', ''),
        kwargs.get('port', 0),
        kwargs.get('url', '')
    )


def is_initialized() -> bool:
    """Check if password manager is initialized"""
    return get_default_api().is_initialized()


def unlock_session(master_password: str) -> bool:
    """Unlock password manager session"""
    return get_default_api().unlock_session(master_password)


def lock_session() -> bool:
    """Lock password manager session"""
    return get_default_api().lock_session()


# Example usage and testing
if __name__ == "__main__":
    print("Secure Password Manager API Integration Module")
    print("=" * 60)
    
    # Initialize API
    api = SecurePasswordAPI()
    
    # Check status
    print("\n1. Checking status...")
    status = api.get_status()
    print(f"   Initialized: {status['initialized']}")
    print(f"   Session Active: {status['session_active']}")
    print(f"   Stored Passwords: {status['stored_passwords']}")
    
    # List services
    if status['initialized']:
        print("\n2. Listing services...")
        services = api.list_services()
        if services:
            for service in services:
                print(f"   - {service}")
        else:
            print("   No services stored")
        
        # Test password retrieval
        if services:
            print(f"\n3. Testing password retrieval for '{services[0]}'...")
            password = api.get_password(services[0])
            if password:
                print(f"   ✓ Password retrieved successfully (length: {len(password)})")
            else:
                print("   ✗ Failed to retrieve password")
    else:
        print("\n⚠️  Password manager not initialized")
        print("   Run: python3 secure_password_manager.py init")
