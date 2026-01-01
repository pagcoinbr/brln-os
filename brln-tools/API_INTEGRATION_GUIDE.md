# Secure Password Manager API Integration

## Quick Start Guide

### 1. Import the Module

Add to your Python application:

```python
import sys
sys.path.insert(0, '/root/brln-os/brln-tools')
from secure_password_api import SecurePasswordAPI, get_password
```

### 2. Initialize the API

```python
import os
from secure_password_api import SecurePasswordAPI

# Option A: Use environment variable
password_api = SecurePasswordAPI()  # Reads BRLN_MASTER_PASSWORD from env

# Option B: Pass master password directly
password_api = SecurePasswordAPI(master_password="your_master_password")
```

### 3. Basic Usage

#### Retrieve Password
```python
# Get Elements RPC password
elements_password = password_api.get_password('elements_rpc_password')

if elements_password:
    print(f"Password: {elements_password}")
else:
    print("Password not found")
```

#### Store Password
```python
# Store a new password
success = password_api.store_password(
    service_name='my_service',
    username='admin',
    password='secure_password_123',
    description='My Service Credentials',
    port=8080,
    url='https://myservice.local'
)
```

#### List Services
```python
services = password_api.list_services()
print(f"Stored services: {services}")
```

### 4. Flask API Integration Example

```python
from flask import Flask, jsonify
from secure_password_api import SecurePasswordAPI
import os

app = Flask(__name__)

# Initialize password API at startup
password_api = SecurePasswordAPI(
    master_password=os.environ.get('BRLN_MASTER_PASSWORD'),
    cache_enabled=True
)

# Load dynamic credentials
ELEMENTS_RPC_USER = password_api.get_password('elements_rpc_user') or 'elements'
ELEMENTS_RPC_PASSWORD = password_api.get_password('elements_rpc_password') or 'changeme'

@app.route('/api/config')
def get_config():
    return jsonify({
        'elements_user': ELEMENTS_RPC_USER,
        'has_password': ELEMENTS_RPC_PASSWORD != 'changeme'
    })
```

### 5. Features

#### Automatic Caching
```python
# First call - retrieves from password manager
password1 = password_api.get_password('service')  # ~10ms

# Second call - uses cache
password2 = password_api.get_password('service')  # ~0.01ms

# Cache expires after 5 minutes (matches session timeout)
```

#### Session Management
```python
# Unlock session
password_api.unlock_session('master_password')

# Lock session (clears cache)
password_api.lock_session()

# Check status
status = password_api.get_status()
print(f"Session active: {status['session_active']}")
```

#### Error Handling
```python
try:
    password = password_api.get_password('service')
    if password:
        # Use password
        pass
    else:
        # Password not found - use fallback
        password = 'default_password'
except Exception as e:
    print(f"Error: {e}")
```

### 6. Environment Setup

Set master password in environment:

```bash
# Option A: Export for session
export BRLN_MASTER_PASSWORD="your_master_password"

# Option B: Add to systemd service
[Service]
Environment="BRLN_MASTER_PASSWORD=your_master_password"

# Option C: Use .env file (with python-dotenv)
echo "BRLN_MASTER_PASSWORD=your_master_password" > .env
```

### 7. Security Best Practices

✅ **DO:**
- Store master password in environment variable
- Use cache to reduce password manager calls
- Check if password manager is initialized before use
- Use fallback defaults for critical services

❌ **DON'T:**
- Hardcode master password in source code
- Log retrieved passwords
- Store passwords in plain text config files
- Share master password

### 8. API Reference

#### SecurePasswordAPI Class

| Method | Description | Returns |
|--------|-------------|---------|
| `get_password(service_name)` | Retrieve password | `str` or `None` |
| `store_password(...)` | Store password | `bool` |
| `delete_password(service_name)` | Delete password | `bool` |
| `list_services()` | List all services | `list[str]` |
| `is_initialized()` | Check initialization | `bool` |
| `unlock_session(password)` | Unlock session | `bool` |
| `lock_session()` | Lock session | `bool` |
| `get_status()` | Get status info | `dict` |
| `clear_cache()` | Clear password cache | `None` |

#### Convenience Functions

```python
from secure_password_api import get_password, store_password, is_initialized

# Simple password retrieval
password = get_password('service_name')

# Simple password storage
store_password('service', 'user', 'pass')

# Check initialization
if is_initialized():
    # Use password manager
    pass
```

### 9. Complete Flask Integration Example

See: `/root/brln-os/brln-tools/api_integration_examples.py`

### 10. Testing

Run the test suite:
```bash
cd /root/brln-os/brln-tools
BRLN_MASTER_PASSWORD="your_password" python3 secure_password_api.py
```

### 11. Troubleshooting

**Problem:** "Master password required"
- **Solution:** Set `BRLN_MASTER_PASSWORD` environment variable

**Problem:** "Password manager not initialized"
- **Solution:** Run `python3 secure_password_manager.py init`

**Problem:** "Password not found"
- **Solution:** Store the password first using `store_password()`

**Problem:** Slow password retrieval
- **Solution:** Enable caching: `SecurePasswordAPI(cache_enabled=True)`

### 12. Migration from Hardcoded Credentials

Before:
```python
ELEMENTS_RPC_PASSWORD = "test"
```

After:
```python
from secure_password_api import get_password
ELEMENTS_RPC_PASSWORD = get_password('elements_rpc_password') or 'test'
```

---

For more examples, see `api_integration_examples.py`
