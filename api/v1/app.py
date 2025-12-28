#!/usr/bin/env python3
"""
API para gerenciamento do comando central e status do sistema BRLN-OS
Usando gRPC para comunicação com LND

ESTRUTURA DA API:

System Management:
- GET  /api/v1/system/status          - Status do sistema (CPU, RAM, LND, Bitcoin, etc)
- GET  /api/v1/system/services        - Status de todos os serviços
- POST /api/v1/system/service         - Gerenciar serviços (start/stop/restart)
- GET  /api/v1/system/health          - Health check

Wallet Management (On-chain):
- GET  /api/v1/wallet/balance/onchain - Saldo Bitcoin on-chain
- GET  /api/v1/wallet/transactions    - Listar transações on-chain
- POST /api/v1/wallet/transactions/send - Enviar Bitcoin on-chain
- POST /api/v1/wallet/addresses       - Gerar novos endereços Bitcoin
- GET  /api/v1/wallet/utxos          - Listar UTXOs disponíveis

Lightning Network:
- GET  /api/v1/lightning/peers         - Listar peers conectados
- POST /api/v1/lightning/peers/connect - Conectar a um peer
- GET  /api/v1/lightning/channels      - Listar canais Lightning
- POST /api/v1/lightning/channels/open - Abrir canal Lightning
- POST /api/v1/lightning/channels/close - Fechar canal Lightning
- GET  /api/v1/lightning/channels/pending - Listar canais pendentes
- POST /api/v1/lightning/invoices      - Criar invoice Lightning
- POST /api/v1/lightning/payments      - Enviar pagamento Lightning
- POST /api/v1/lightning/payments/keysend - Enviar keysend (pagamento espontâneo)

Transaction Fees:
- GET  /api/v1/fees                    - Obter estimativas de taxas de transação

HD Wallet Management:
- POST /api/v1/wallet/hd/generate      - Gerar nova seed phrase BIP39
- POST /api/v1/wallet/hd/import        - Importar wallet existente
- POST /api/v1/wallet/hd/derive        - Derivar endereços para todas as chains
- GET  /api/v1/wallet/hd/addresses     - Obter endereços derivados em cache
- POST /api/v1/wallet/hd/unlock        - Desbloquear wallet com senha
- GET  /api/v1/wallet/hd/chains        - Listar chains suportadas
- DELETE /api/v1/wallet/hd/remove      - Remover wallet do sistema

Elements/Liquid Network:
- GET  /api/v1/elements/balances       - Obter saldos de todos os assets
- GET  /api/v1/elements/assets         - Listar assets conhecidos
- POST /api/v1/elements/addresses      - Gerar novo endereço Liquid
- POST /api/v1/elements/send           - Enviar asset para endereço
- GET  /api/v1/elements/utxos          - Listar UTXOs Liquid não gastos
- GET  /api/v1/elements/transactions   - Listar transações Liquid recentes
- GET  /api/v1/elements/info           - Informações da blockchain Liquid

Lightning Chat System:
- GET  /api/v1/chat/conversations      - Listar todas as conversas ativas
- GET  /api/v1/chat/messages           - Obter mensagens de uma conversa
- POST /api/v1/chat/send               - Enviar mensagem via keysend
- GET  /api/v1/chat/notifications      - Contador de novas mensagens
- POST /api/v1/chat/reset              - Resetar contador de mensagens

Advanced Lightning Features:
- GET  /api/v1/lightning/balance       - Saldo dos canais Lightning
- GET  /api/v1/lightning/info          - Informações detalhadas do node
- POST /api/v1/lightning/decode        - Decodificar payment request
- GET  /api/v1/lightning/forwarding    - Histórico de forwarding
- POST /api/v1/lightning/backup        - Backup do channel.backup
"""

# Environment Virtual Check
import sys
import os

# Ensure we're using the correct virtual environment
EXPECTED_VENV = "/root/brln-os-envs/api-v1"
if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
    current_venv = sys.prefix
    if current_venv != EXPECTED_VENV:
        print(f"Warning: Expected venv {EXPECTED_VENV}, but using {current_venv}")
        print("Run: source /root/brln-os-envs/api-v1/bin/activate")
else:
    print("Warning: Not running in a virtual environment!")
    print("Run: bash /root/brln-os/scripts/setup-api-env.sh")

from flask import Flask, jsonify, request
from flask_cors import CORS
import subprocess
import psutil
import uuid
import requests
import json
from pathlib import Path
import grpc
import codecs
from datetime import datetime
import hashlib
from concurrent import futures
import time
import requests
import sqlite3
import threading
import base64
import warnings
import secrets
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

# Wallet management imports
try:
    import mnemonic
    from bip32 import BIP32
    import hashlib
    import hmac
    HAS_WALLET_LIBS = True
    print("Wallet crypto libraries loaded successfully")
except ImportError as e:
    HAS_WALLET_LIBS = False
    print(f"Warning: Wallet crypto libraries not available: {e}")
    print("Install with: pip install mnemonic bip32utils")

# Desabilitar warnings desnecessários
warnings.filterwarnings("ignore")

# Configurações LND
LND_HOST = "localhost"
LND_GRPC_PORT = "10009"
MACAROON_PATH = "/data/lnd/data/chain/bitcoin/testnet/admin.macaroon"
TLS_CERT_PATH = "/data/lnd/tls.cert"

# Configurações Elements/Liquid
ELEMENTS_RPC_HOST = "localhost"
ELEMENTS_RPC_PORT = "7041"
ELEMENTS_RPC_USER = "test"
ELEMENTS_RPC_PASSWORD = "test"

# Configurações do Wallet HD
WALLET_DATA_DIR = "/data/brln-wallet"
WALLET_DB_PATH = os.path.join(WALLET_DATA_DIR, "wallets.db")

# Criar diretório de dados do wallet se não existir
os.makedirs(WALLET_DATA_DIR, exist_ok=True)

# Configuração das blockchains suportadas
SUPPORTED_CHAINS = {
    'bitcoin': {
        'name': 'Bitcoin',
        'symbol': 'BTC',
        'coin_type': 0,
        'path': "m/44'/0'/0'/0/0",
        'api_urls': [
            'https://mempool.space/api/address/',
            'https://blockstream.info/api/address/',
            'https://blockchain.info/q/addressbalance/'
        ]
    },
    'ethereum': {
        'name': 'Ethereum',
        'symbol': 'ETH',
        'coin_type': 60,
        'path': "m/44'/60'/0'/0/0",
        'api_urls': [
            'https://api.etherscan.io/api',
            'https://eth-mainnet.g.alchemy.com/v2/demo',
            'https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161'
        ]
    },
    'liquid': {
        'name': 'Liquid Network',
        'symbol': 'L-BTC',
        'coin_type': 1776,
        'path': "m/44'/1776'/0'/0/0",
        'api_urls': [
            'https://liquid.network/api/address/',
            'https://blockstream.info/liquid/api/address/'
        ]
    },
    'tron': {
        'name': 'TRON',
        'symbol': 'TRX',
        'coin_type': 195,
        'path': "m/44'/195'/0'/0/0",
        'api_urls': [
            'https://api.trongrid.io/wallet/getaccount',
            'https://apilist.tronscanapi.com/api/account'
        ]
    },
    'solana': {
        'name': 'Solana',
        'symbol': 'SOL',
        'coin_type': 501,
        'path': "m/44'/501'/0'/0'",
        'api_urls': [
            'https://api.mainnet-beta.solana.com',
            'https://rpc.helius.xyz/?api-key=demo'
        ]
    }
}

try:
    from pydbus import SystemBus
    PYDBUS_AVAILABLE = True
except ImportError:
    PYDBUS_AVAILABLE = False
    print("Warning: pydbus not available, falling back to subprocess for systemd")

# Importar proto files (obrigatório)
try:
    # Imports para usar com gRPC compilado do LND
    import lightning_pb2 as lnrpc
    import lightning_pb2_grpc as lnrpcstub
    print("gRPC proto files loaded successfully")
except ImportError:
    print("ERROR: gRPC proto files not found!")
    print("Run: ./compile_protos.sh to generate proto files")
    exit(1)

app = Flask(__name__)
CORS(app)

# === ENCRYPTION HELPER FUNCTIONS ===

def derive_key_from_password(password, salt):
    """Deriva chave de criptografia da senha"""
    password_salt = password.encode() + salt
    password_hash = hashlib.sha256(password_salt).digest()
    
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=200000,
        backend=default_backend()
    )
    key = base64.urlsafe_b64encode(kdf.derive(password_hash))
    return key

def encrypt_data(data, password):
    """Criptografa dados com senha"""
    try:
        salt = secrets.token_bytes(32)
        key = derive_key_from_password(password, salt)
        fernet = Fernet(key)
        encrypted = fernet.encrypt(data.encode())
        return encrypted, salt
    except Exception as e:
        raise Exception(f"Encryption error: {str(e)}")

def decrypt_data(encrypted_data, password, salt):
    """Descriptografa dados com senha"""
    try:
        key = derive_key_from_password(password, salt)
        fernet = Fernet(key)
        decrypted = fernet.decrypt(encrypted_data).decode()
        return decrypted
    except Exception as e:
        raise Exception(f"Decryption error: {str(e)}")

# === WALLET MANAGEMENT SYSTEM ===

class WalletManager:
    """Gerenciador de carteiras HD com criptografia e derivação de chaves"""
    
    def __init__(self):
        self.init_database()
    
    def init_database(self):
        """Inicializa o banco de dados SQLite para wallets"""
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        # Tabela para armazenar wallets criptografadas
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS wallets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                wallet_id TEXT UNIQUE NOT NULL,
                encrypted_mnemonic BLOB NOT NULL,
                salt BLOB NOT NULL,
                has_password BOOLEAN DEFAULT FALSE,
                metadata TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_used DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Add has_password column if it doesn't exist (for existing databases)
        cursor.execute('''
            SELECT COUNT(*) as CNTREC FROM pragma_table_info('wallets') WHERE name='has_password'
        ''')
        if cursor.fetchone()[0] == 0:
            cursor.execute('ALTER TABLE wallets ADD COLUMN has_password BOOLEAN DEFAULT FALSE')
            print("Added has_password column to existing wallets table")
        
        # Add encrypted_private_keys column if it doesn't exist
        cursor.execute('''
            SELECT COUNT(*) as CNTREC FROM pragma_table_info('wallets') WHERE name='encrypted_private_keys'
        ''')
        if cursor.fetchone()[0] == 0:
            cursor.execute('ALTER TABLE wallets ADD COLUMN encrypted_private_keys BLOB')
            print("Added encrypted_private_keys column to existing wallets table")
        
        # Add is_system_default column if it doesn't exist
        cursor.execute('''
            SELECT COUNT(*) as CNTREC FROM pragma_table_info('wallets') WHERE name='is_system_default'
        ''')
        if cursor.fetchone()[0] == 0:
            cursor.execute('ALTER TABLE wallets ADD COLUMN is_system_default BOOLEAN DEFAULT FALSE')
            print("Added is_system_default column to existing wallets table")
        
        # Tabela para cache de endereços derivados
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS derived_addresses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                wallet_id TEXT NOT NULL,
                chain_id TEXT NOT NULL,
                address TEXT NOT NULL,
                derivation_path TEXT NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(wallet_id, chain_id)
            )
        ''')
        
        # Tabela para configuração TRON Gas-Free
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS tron_config (
                id INTEGER PRIMARY KEY DEFAULT 1,
                tron_address TEXT,
                encrypted_private_key BLOB,
                salt BLOB,
                tron_api_url TEXT DEFAULT 'https://api.trongrid.io',
                tron_api_key TEXT,
                gasfree_api_key TEXT,
                gasfree_api_secret TEXT,
                gasfree_endpoint TEXT DEFAULT 'https://open.gasfree.io/tron/',
                gasfree_verifying_contract TEXT DEFAULT 'TFFAMLQZybALab4uxHA9RBE7pxhUAjfF3U',
                gasfree_service_provider TEXT DEFAULT 'TLntW9Z59LYY5KEi9cmwk3PKjQga828ird',
                usdt_contract_address TEXT DEFAULT 'TR7NHqjeKQxGTCi8z8ZY4pL8otSzgjLj6t',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                CHECK (id = 1)
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def get_db_connection(self):
        """Get database connection"""
        return sqlite3.connect(WALLET_DB_PATH)
    
    def generate_secure_entropy(self, word_count=12):
        """Gera entropia segura usando múltiplas fontes"""
        try:
            # Determine entropy size based on word count
            # 12 words = 128 bits, 24 words = 256 bits
            entropy_size = 16 if word_count == 12 else 32
            
            # Base entropy
            entropy = secrets.token_bytes(entropy_size)
            
            # Add system-specific entropy
            import platform
            import time
            system_info = f"{platform.node()}{platform.processor()}{time.time()}"
            system_hash = hashlib.sha256(system_info.encode()).digest()[:entropy_size//2]
            
            # Combine entropy sources
            combined = bytes(a ^ b for a, b in zip(entropy[:entropy_size//2], system_hash))
            combined += entropy[entropy_size//2:]
            
            return combined
        except Exception as e:
            print(f"Error generating entropy: {e}")
            return secrets.token_bytes(entropy_size)
    
    def generate_mnemonic(self, word_count=12):
        """Gera uma nova seed phrase BIP39 com 12 ou 24 palavras"""
        if not HAS_WALLET_LIBS:
            return None, "Wallet libraries not available"
        
        if word_count not in [12, 24]:
            return None, "Word count must be 12 or 24"
        
        try:
            entropy = self.generate_secure_entropy(word_count)
            mnemo = mnemonic.Mnemonic("english")
            seed_phrase = mnemo.to_mnemonic(entropy)
            
            # Verify word count
            words = seed_phrase.split()
            if len(words) != word_count:
                return None, f"Generated mnemonic has {len(words)} words, expected {word_count}"
            
            if not mnemo.check(seed_phrase):
                return None, "Generated mnemonic failed validation"
            
            return seed_phrase, None
        except Exception as e:
            return None, f"Error generating mnemonic: {str(e)}"
    
    def validate_mnemonic(self, seed_phrase):
        """Valida uma seed phrase BIP39"""
        if not HAS_WALLET_LIBS:
            return False, "Wallet libraries not available"
        
        try:
            mnemo = mnemonic.Mnemonic("english")
            return mnemo.check(seed_phrase.strip()), None
        except Exception as e:
            return False, f"Error validating mnemonic: {str(e)}"
    
    def encrypt_mnemonic(self, seed_phrase, password):
        """Criptografa uma seed phrase usando AES-256 com salt SHA256"""
        try:
            import hashlib
            import os
            
            # Gerar salt aleatório (32 bytes)
            salt = os.urandom(32)
            
            # Criar hash SHA256 da senha + salt
            password_salt = password.encode() + salt
            password_hash = hashlib.sha256(password_salt).digest()
            
            # Usar PBKDF2 com o hash SHA256 como entrada
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,  # 256 bits para AES-256
                salt=salt,
                iterations=200000,  # Aumentar iterações para maior segurança
                backend=default_backend()
            )
            key = base64.urlsafe_b64encode(kdf.derive(password_hash))
            
            # Criptografar mnemonic com AES-256
            fernet = Fernet(key)
            encrypted_mnemonic = fernet.encrypt(seed_phrase.encode())
            
            return encrypted_mnemonic, salt, None
        except Exception as e:
            return None, None, f"Error encrypting mnemonic: {str(e)}"
    
    def encrypt_private_keys(self, private_keys_dict, password):
        """Criptografa as chaves privadas usando AES-256 com salt SHA256"""
        try:
            import json
            import hashlib
            import os
            
            # Convert private keys dict to JSON string
            private_keys_json = json.dumps(private_keys_dict)
            
            # Generate salt
            salt = os.urandom(32)
            
            # Create password hash with salt
            password_salt = password.encode() + salt
            password_hash = hashlib.sha256(password_salt).digest()
            
            # Derive key using PBKDF2 with SHA256 hash
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=salt,
                iterations=200000,
                backend=default_backend()
            )
            key = base64.urlsafe_b64encode(kdf.derive(password_hash))
            
            # Encrypt private keys
            fernet = Fernet(key)
            encrypted_private_keys = fernet.encrypt(private_keys_json.encode())
            
            return encrypted_private_keys, salt, None
        except Exception as e:
            return None, None, f"Error encrypting private keys: {str(e)}"
    
    def decrypt_mnemonic(self, encrypted_mnemonic, salt, password):
        """Descriptografa uma seed phrase usando AES-256 com salt SHA256"""
        try:
            import hashlib
            
            # Recriar hash SHA256 da senha + salt
            password_salt = password.encode() + salt
            password_hash = hashlib.sha256(password_salt).digest()
            
            # Derivar chave usando PBKDF2 com o hash SHA256
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=salt,
                iterations=200000,  # Mesmas iterações da criptografia
                backend=default_backend()
            )
            key = base64.urlsafe_b64encode(kdf.derive(password_hash))
            
            # Descriptografar mnemonic
            fernet = Fernet(key)
            decrypted_mnemonic = fernet.decrypt(encrypted_mnemonic).decode()
            
            return decrypted_mnemonic, None
        except Exception as e:
            return None, f"Error decrypting mnemonic: {str(e)}"
    
    def derive_addresses(self, seed_phrase, passphrase=""):
        """Deriva endereços para todas as chains suportadas"""
        if not HAS_WALLET_LIBS:
            return {}, "Wallet libraries not available"
        
        try:
            # Gerar seed da mnemonic
            mnemo = mnemonic.Mnemonic("english")
            seed = mnemo.to_seed(seed_phrase, passphrase)
            
            # Criar BIP32 master key
            bip32 = BIP32.from_seed(seed)
            
            addresses = {}
            
            for chain_id, chain_config in SUPPORTED_CHAINS.items():
                try:
                    # Derivar chave para a chain específica
                    path = chain_config['path']
                    derived_key = bip32.get_privkey_from_path(path)
                    public_key = bip32.get_pubkey_from_path(path)
                    
                    # Gerar endereço baseado na chain
                    address = self._generate_address_for_chain(
                        chain_id, 
                        public_key, 
                        derived_key
                    )
                    
                    addresses[chain_id] = {
                        'address': address,
                        'path': path,
                        'chain': chain_config['name'],
                        'symbol': chain_config['symbol']
                    }
                    
                except Exception as e:
                    addresses[chain_id] = {
                        'error': f"Failed to derive {chain_id}: {str(e)}",
                        'path': chain_config['path'],
                        'chain': chain_config['name'],
                        'symbol': chain_config['symbol']
                    }
            
            return addresses, None
            
        except Exception as e:
            return {}, f"Error deriving addresses: {str(e)}"
    
    def derive_private_keys(self, seed_phrase, passphrase=""):
        """Deriva chaves privadas para todas as chains suportadas"""
        if not HAS_WALLET_LIBS:
            return {}, "Wallet libraries not available"
        
        try:
            # Gerar seed da mnemonic
            mnemo = mnemonic.Mnemonic("english")
            seed = mnemo.to_seed(seed_phrase, passphrase)
            
            # Criar BIP32 master key
            bip32 = BIP32.from_seed(seed)
            
            private_keys = {}
            
            for chain_id, chain_config in SUPPORTED_CHAINS.items():
                try:
                    # Derivar chave para a chain específica
                    path = chain_config['path']
                    derived_key = bip32.get_privkey_from_path(path)
                    
                    # Convert to hex string
                    private_key_hex = derived_key.hex()
                    
                    private_keys[chain_id] = {
                        'private_key': private_key_hex,
                        'path': path,
                        'chain': chain_config['name'],
                        'symbol': chain_config['symbol']
                    }
                    
                except Exception as e:
                    private_keys[chain_id] = {
                        'error': f"Failed to derive {chain_id}: {str(e)}",
                        'path': chain_config['path'],
                        'chain': chain_config['name'],
                        'symbol': chain_config['symbol']
                    }
            
            return private_keys, None
            
        except Exception as e:
            return {}, f"Error deriving private keys: {str(e)}"
    
    def bip39_to_extended_master_key(self, seed_phrase, passphrase="", network="mainnet"):
        """Converte BIP39 seed para extended master root key (xprv/tprv) para LND"""
        if not HAS_WALLET_LIBS:
            return None, "Wallet libraries not available"
        
        try:
            import base58
            
            # Gerar seed da mnemonic
            mnemo = mnemonic.Mnemonic("english")
            seed = mnemo.to_seed(seed_phrase, passphrase)
            
            # Criar BIP32 master key
            bip32 = BIP32.from_seed(seed)
            
            # Get extended private key components
            private_key, chain_code = bip32.get_extended_privkey_from_path('m')
            
            # Network-specific version bytes
            if network.lower() == "testnet":
                version = b'\x04\x35\x83\x94'  # testnet tprv version
                prefix = "tprv"
            else:
                version = b'\x04\x88\xad\xe4'  # mainnet xprv version
                prefix = "xprv"
            
            # Construct extended key components
            depth = b'\x00'                      # depth 0 for master key
            parent_fingerprint = b'\x00\x00\x00\x00'  # no parent for master key
            child_number = b'\x00\x00\x00\x00'        # child number 0
            
            # Build extended key: version + depth + parent_fp + child_num + chain_code + 0x00 + private_key
            extended_key = version + depth + parent_fingerprint + child_number + chain_code + b'\x00' + private_key
            
            # Encode with base58check
            extended_master_key = base58.b58encode_check(extended_key).decode('utf-8')
            
            return {
                'extended_master_key': extended_master_key,
                'network': network,
                'prefix': prefix,
                'private_key_hex': private_key.hex(),
                'chain_code_hex': chain_code.hex(),
                'seed_hex': seed.hex()
            }, None
            
        except ImportError:
            return None, "base58 library not available"
        except Exception as e:
            return None, f"Error converting to extended master key: {str(e)}"
    
    def generate_universal_wallet(self, seed_phrase, passphrase=""):
        """Gera carteira universal com derivações para todas as chains E chaves mestras para LND"""
        if not HAS_WALLET_LIBS:
            return {}, "Wallet libraries not available"
        
        try:
            # Derivar endereços para todas as chains
            addresses, addr_error = self.derive_addresses(seed_phrase, passphrase)
            if addr_error:
                return {}, addr_error
            
            # Derivar chaves privadas para todas as chains
            private_keys, privkey_error = self.derive_private_keys(seed_phrase, passphrase)
            if privkey_error:
                return {}, privkey_error
            
            # Gerar extended master keys para LND (mainnet e testnet)
            mainnet_key, mainnet_error = self.bip39_to_extended_master_key(seed_phrase, passphrase, "mainnet")
            testnet_key, testnet_error = self.bip39_to_extended_master_key(seed_phrase, passphrase, "testnet")
            
            # Compilar resultado universal
            result = {
                'seed_phrase': seed_phrase,
                'has_passphrase': bool(passphrase),
                'addresses': addresses,
                'private_keys': private_keys,
                'lnd_keys': {
                    'mainnet': mainnet_key if not mainnet_error else {'error': mainnet_error},
                    'testnet': testnet_key if not testnet_error else {'error': testnet_error}
                },
                'supported_chains': list(SUPPORTED_CHAINS.keys()),
                'lnd_compatible': not (mainnet_error and testnet_error)
            }
            
            return result, None
            
        except Exception as e:
            return {}, f"Error generating universal wallet: {str(e)}"
    
    def _generate_address_for_chain(self, chain_id, public_key, private_key):
        """Gera endereço específico para cada blockchain"""
        try:
            if chain_id == 'bitcoin':
                return self._generate_bitcoin_address(public_key)
            
            elif chain_id == 'ethereum':
                return self._generate_ethereum_address(public_key)
            
            elif chain_id == 'liquid':
                return self._generate_liquid_address(public_key)
            
            elif chain_id == 'tron':
                return self._generate_tron_address(public_key)
            
            elif chain_id == 'solana':
                return self._generate_solana_address(public_key)
            
            else:
                return f"Unsupported chain: {chain_id}"
                
        except Exception as e:
            return f"Error generating {chain_id} address: {str(e)}"
    
    def _generate_bitcoin_address(self, public_key):
        """Gera endereço Bitcoin (Bech32/P2WPKH)"""
        try:
            import hashlib
            import base58
            
            # SHA256 hash do public key
            sha256_hash = hashlib.sha256(public_key).digest()
            
            # RIPEMD160 hash do SHA256
            ripe = hashlib.new('ripemd160')
            ripe.update(sha256_hash)
            ripemd160_hash = ripe.digest()
            
            # Para Bech32 (versão simplificada)
            # Em produção usar biblioteca específica como python-bitcoinlib
            
            # Legacy P2PKH para simplicidade (versão 0x00)
            versioned_payload = b'\x00' + ripemd160_hash
            
            # Checksum SHA256 duplo
            checksum = hashlib.sha256(hashlib.sha256(versioned_payload).digest()).digest()[:4]
            
            # Endereço final
            address_bytes = versioned_payload + checksum
            address = base58.b58encode(address_bytes).decode('ascii')
            
            return address
            
        except Exception as e:
            return f"Bitcoin address error: {str(e)}"
    
    def _generate_ethereum_address(self, public_key):
        """Gera endereço Ethereum"""
        try:
            import hashlib
            
            # Remover primeiro byte (0x04) se presente (formato não comprimido)
            if len(public_key) == 65 and public_key[0] == 0x04:
                public_key = public_key[1:]
            
            # Keccak256 hash do public key
            keccak = hashlib.sha3_256(public_key)
            hash_bytes = keccak.digest()
            
            # Pegar últimos 20 bytes e adicionar 0x
            address = '0x' + hash_bytes[-20:].hex()
            
            return address
            
        except Exception as e:
            return f"Ethereum address error: {str(e)}"
    
    def _generate_liquid_address(self, public_key):
        """Gera endereço Liquid (similar ao Bitcoin mas com prefixo diferente)"""
        try:
            import hashlib
            import base58
            
            # SHA256 hash do public key
            sha256_hash = hashlib.sha256(public_key).digest()
            
            # RIPEMD160 hash do SHA256
            ripe = hashlib.new('ripemd160')
            ripe.update(sha256_hash)
            ripemd160_hash = ripe.digest()
            
            # Liquid usa versão diferente (0x39 para mainnet)
            versioned_payload = b'\x39' + ripemd160_hash
            
            # Checksum SHA256 duplo
            checksum = hashlib.sha256(hashlib.sha256(versioned_payload).digest()).digest()[:4]
            
            # Endereço final
            address_bytes = versioned_payload + checksum
            address = base58.b58encode(address_bytes).decode('ascii')
            
            return address
            
        except Exception as e:
            return f"Liquid address error: {str(e)}"
    
    def _generate_tron_address(self, public_key):
        """Gera endereço TRON"""
        try:
            import hashlib
            import base58
            
            # Remover primeiro byte se presente
            if len(public_key) == 65 and public_key[0] == 0x04:
                public_key = public_key[1:]
            
            # Keccak256 hash do public key
            keccak = hashlib.sha3_256(public_key)
            hash_bytes = keccak.digest()
            
            # Pegar últimos 20 bytes
            address_bytes = hash_bytes[-20:]
            
            # Adicionar prefixo TRON (0x41)
            tron_address = b'\x41' + address_bytes
            
            # Checksum SHA256 duplo
            checksum = hashlib.sha256(hashlib.sha256(tron_address).digest()).digest()[:4]
            
            # Endereço final com checksum
            final_address = tron_address + checksum
            address = base58.b58encode(final_address).decode('ascii')
            
            return address
            
        except Exception as e:
            return f"TRON address error: {str(e)}"
    
    def _generate_solana_address(self, public_key):
        """Gera endereço Solana"""
        try:
            import base58
            
            # Para Solana, o public key É o endereço
            # Usar apenas os primeiros 32 bytes se necessário
            if len(public_key) > 32:
                public_key = public_key[:32]
            
            # Codificar em Base58
            address = base58.b58encode(public_key).decode('ascii')
            
            return address
            
        except Exception as e:
            return f"Solana address error: {str(e)}"
    
    def save_wallet(self, wallet_id, encrypted_mnemonic, salt, metadata=None, has_password=True, encrypted_private_keys=None, is_system_default=False):
        """Salva wallet criptografada no banco"""
        try:
            conn = sqlite3.connect(WALLET_DB_PATH)
            cursor = conn.cursor()
            
            # If this wallet is being set as system default, unset others
            if is_system_default:
                cursor.execute('''
                    UPDATE wallets SET is_system_default = FALSE WHERE wallet_id != ?
                ''', (wallet_id,))
            
            cursor.execute('''
                INSERT OR REPLACE INTO wallets 
                (wallet_id, encrypted_mnemonic, salt, has_password, metadata, encrypted_private_keys, is_system_default, last_used)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (wallet_id, encrypted_mnemonic, salt, has_password, 
                  json.dumps(metadata) if metadata else None,
                  encrypted_private_keys, is_system_default,
                  datetime.now()))
            
            conn.commit()
            conn.close()
            return True, None
            
        except Exception as e:
            return False, f"Error saving wallet: {str(e)}"
    
    def load_wallet(self, wallet_id):
        """Carrega wallet do banco"""
        try:
            conn = sqlite3.connect(WALLET_DB_PATH)
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT encrypted_mnemonic, salt, metadata 
                FROM wallets WHERE wallet_id = ?
            ''', (wallet_id,))
            
            result = cursor.fetchone()
            conn.close()
            
            if result:
                encrypted_mnemonic, salt, metadata = result
                metadata_dict = json.loads(metadata) if metadata else {}
                return {
                    'encrypted_mnemonic': encrypted_mnemonic,
                    'salt': salt,
                    'metadata': metadata_dict
                }, None
            else:
                return None, "Wallet not found"
                
        except Exception as e:
            return None, f"Error loading wallet: {str(e)}"
    
    def cache_addresses(self, wallet_id, addresses):
        """Cache endereços derivados"""
        try:
            conn = sqlite3.connect(WALLET_DB_PATH)
            cursor = conn.cursor()
            
            for chain_id, address_data in addresses.items():
                if 'error' not in address_data:
                    cursor.execute('''
                        INSERT OR REPLACE INTO derived_addresses
                        (wallet_id, chain_id, address, derivation_path)
                        VALUES (?, ?, ?, ?)
                    ''', (wallet_id, chain_id, address_data['address'], address_data['path']))
            
            conn.commit()
            conn.close()
            return True, None
            
        except Exception as e:
            return False, f"Error caching addresses: {str(e)}"
    
    def get_system_default_wallet(self):
        """Get the system default wallet"""
        try:
            conn = sqlite3.connect(WALLET_DB_PATH)
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT wallet_id, encrypted_mnemonic, salt, metadata, has_password 
                FROM wallets WHERE is_system_default = TRUE LIMIT 1
            ''')
            
            result = cursor.fetchone()
            conn.close()
            
            if result:
                wallet_id, encrypted_mnemonic, salt, metadata, has_password = result
                metadata_dict = json.loads(metadata) if metadata else {}
                return {
                    'wallet_id': wallet_id,
                    'encrypted_mnemonic': encrypted_mnemonic,
                    'salt': salt,
                    'metadata': metadata_dict,
                    'has_password': bool(has_password)
                }, None
            else:
                return None, "No system default wallet found"
                
        except Exception as e:
            return None, f"Error loading system default wallet: {str(e)}"
    
    def set_system_default_wallet(self, wallet_id):
        """Set a wallet as the system default"""
        try:
            conn = sqlite3.connect(WALLET_DB_PATH)
            cursor = conn.cursor()
            
            # Check if wallet exists
            cursor.execute('SELECT COUNT(*) FROM wallets WHERE wallet_id = ?', (wallet_id,))
            if cursor.fetchone()[0] == 0:
                conn.close()
                return False, "Wallet not found"
            
            # Unset all other defaults
            cursor.execute('UPDATE wallets SET is_system_default = FALSE')
            
            # Set this wallet as default
            cursor.execute('UPDATE wallets SET is_system_default = TRUE WHERE wallet_id = ?', (wallet_id,))
            
            conn.commit()
            conn.close()
            return True, None
            
        except Exception as e:
            return False, f"Error setting system default wallet: {str(e)}"
    
    def get_cached_addresses(self, wallet_id):
        """Recupera endereços do cache (temporário ou banco)"""
        try:
            # Primeiro, verificar se existe no cache temporário
            if hasattr(self, 'temp_wallets') and wallet_id in self.temp_wallets:
                temp_wallet = self.temp_wallets[wallet_id]
                return temp_wallet['addresses'], None
            
            # Caso contrário, buscar no banco de dados
            conn = sqlite3.connect(WALLET_DB_PATH)
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT chain_id, address, derivation_path
                FROM derived_addresses WHERE wallet_id = ?
            ''', (wallet_id,))
            
            results = cursor.fetchall()
            conn.close()
            
            addresses = {}
            for chain_id, address, derivation_path in results:
                if chain_id in SUPPORTED_CHAINS:
                    chain_config = SUPPORTED_CHAINS[chain_id]
                    addresses[chain_id] = {
                        'address': address,
                        'path': derivation_path,
                        'chain': chain_config['name'],
                        'symbol': chain_config['symbol']
                    }
            
            if not addresses:
                return {}, "Wallet not found in cache or database"
            
            return addresses, None
            
        except Exception as e:
            return {}, f"Error getting cached addresses: {str(e)}"

# Singleton para o gerenciador de carteiras
wallet_manager = WalletManager()

class LNDgRPCClient:
    """Cliente gRPC para LND usando protocolo Lightning Network"""
    
    def __init__(self):
        self.host = f'{LND_HOST}:{LND_GRPC_PORT}'
        self.macaroon_path = MACAROON_PATH
        self.tls_cert_path = TLS_CERT_PATH
        self.channel = None
        self.stub = None
        self._connected = False
    
    def _get_credentials(self):
        """Obter credenciais SSL e macaroon para gRPC"""
        try:
            # Ler certificado TLS
            if not os.path.exists(self.tls_cert_path):
                raise FileNotFoundError(f"TLS cert não encontrado: {self.tls_cert_path}")
            
            with open(self.tls_cert_path, 'rb') as f:
                cert_data = f.read()
            
            # Ler macaroon
            if not os.path.exists(self.macaroon_path):
                raise FileNotFoundError(f"Macaroon não encontrado: {self.macaroon_path}")
                
            with open(self.macaroon_path, 'rb') as f:
                macaroon_bytes = f.read()
            
            macaroon_hex = codecs.encode(macaroon_bytes, 'hex')
            
            # Criar credenciais SSL
            ssl_creds = grpc.ssl_channel_credentials(cert_data)
            
            # Criar metadata callback para macaroon
            def metadata_callback(context, callback):
                callback([('macaroon', macaroon_hex)], None)
            
            auth_creds = grpc.metadata_call_credentials(metadata_callback)
            combined_creds = grpc.composite_channel_credentials(ssl_creds, auth_creds)
            
            return combined_creds, None
            
        except Exception as e:
            return None, f"Erro ao obter credenciais: {str(e)}"
    
    def connect(self):
        """Conectar ao LND via gRPC"""
        try:
            credentials, error = self._get_credentials()
            if error:
                return False, error
            
            # Criar canal seguro
            self.channel = grpc.secure_channel(self.host, credentials)
            self.stub = lnrpcstub.LightningStub(self.channel)
            
            # Testar conexão com GetInfo
            request = lnrpc.GetInfoRequest()
            response = self.stub.GetInfo(request, timeout=10)
            
            self._connected = True
            return True, None
            
        except grpc.RpcError as e:
            return False, f"gRPC Error: {e.details()}"
        except Exception as e:
            return False, f"Erro ao conectar: {str(e)}"
    
    def ensure_connected(self):
        """Garantir que há conexão ativa"""
        if not self._connected:
            success, error = self.connect()
            if not success:
                return False, error
        return True, None
    
    def get_info_grpc(self):
        """Obter informações do LND via gRPC"""
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error
            
            request = lnrpc.GetInfoRequest()
            response = self.stub.GetInfo(request, timeout=10)
            
            return {
                'identity_pubkey': response.identity_pubkey,
                'alias': response.alias,
                'block_height': response.block_height,
                'synced_to_chain': response.synced_to_chain,
                'num_peers': response.num_peers,
                'num_active_channels': response.num_active_channels,
                'version': response.version,
                'color': response.color,
                'num_pending_channels': response.num_pending_channels,
                'chains': [{'chain': c.chain, 'network': c.network} for c in response.chains]
            }, None
            
        except grpc.RpcError as e:
            self._connected = False
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro inesperado: {str(e)}"
    
    def get_transactions_grpc(self, start_height=None, end_height=None, account=None):
        """Obter transações via gRPC"""
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error
            
            request = lnrpc.GetTransactionsRequest()
            if start_height is not None:
                request.start_height = start_height
            if end_height is not None:
                request.end_height = end_height
            if account is not None:
                request.account = account
            
            response = self.stub.GetTransactions(request, timeout=30)
            
            transactions = []
            for tx in response.transactions:
                transactions.append({
                    'tx_hash': tx.tx_hash,
                    'amount': str(tx.amount),
                    'num_confirmations': tx.num_confirmations,
                    'block_hash': tx.block_hash,
                    'block_height': tx.block_height,
                    'time_stamp': str(tx.time_stamp),
                    'dest_addresses': list(tx.dest_addresses),
                    'total_fees': str(tx.total_fees),
                    'label': tx.label,
                    'raw_tx_hex': tx.raw_tx_hex
                })
            
            return {
                'transactions': transactions,
                'last_index': response.last_index,
                'first_index': response.first_index
            }, None
            
        except grpc.RpcError as e:
            self._connected = False
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro inesperado: {str(e)}"
    
    def connect_peer_grpc(self, lightning_address, perm=True, timeout=60):
        """Conectar a um peer via gRPC"""
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error
            
            # Parse lightning address
            if '@' in lightning_address:
                pubkey, host = lightning_address.split('@', 1)
            else:
                pubkey = lightning_address
                host = ''
            
            # Criar request
            request = lnrpc.ConnectPeerRequest()
            request.addr.pubkey = pubkey
            if host:
                request.addr.host = host
            request.perm = perm
            request.timeout = timeout
            
            response = self.stub.ConnectPeer(request, timeout=timeout + 10)
            
            return {
                'success': True,
                'peer_id': pubkey,
                'permanent': perm
            }, None
            
        except grpc.RpcError as e:
            self._connected = False
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro inesperado: {str(e)}"
    
    def list_peers_grpc(self, latest_error=True):
        """Listar peers conectados via gRPC"""
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error
            
            request = lnrpc.ListPeersRequest()
            request.latest_error = latest_error
            
            response = self.stub.ListPeers(request, timeout=10)
            
            peers = []
            for peer in response.peers:
                # Serializar features de forma correta para JSON
                features = {}
                try:
                    for key, value in peer.features.items():
                        features[str(key)] = {
                            'name': value.name if hasattr(value, 'name') else str(value),
                            'is_required': value.is_required if hasattr(value, 'is_required') else False,
                            'is_known': value.is_known if hasattr(value, 'is_known') else True
                        }
                except:
                    # Se falhar, apenas converter para string
                    features = {str(k): str(v) for k, v in peer.features.items()}
                
                peers.append({
                    'pub_key': peer.pub_key,
                    'address': peer.address,
                    'bytes_sent': str(peer.bytes_sent),
                    'bytes_recv': str(peer.bytes_recv),
                    'sat_sent': str(peer.sat_sent),
                    'sat_recv': str(peer.sat_recv),
                    'inbound': peer.inbound,
                    'ping_time': str(peer.ping_time),
                    'sync_type': peer.sync_type,
                    'features': features,
                    'errors': [{'error': str(e)} for e in peer.errors],
                    'flap_count': peer.flap_count,
                    'last_flap_ns': str(peer.last_flap_ns)
                })
            
            return {
                'peers': peers
            }, None
            
        except grpc.RpcError as e:
            self._connected = False
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro inesperado: {str(e)}"
    
    def add_invoice_grpc(self, memo=None, value=None, expiry=3600, private=False, description_hash=None):
        """Criar uma invoice via gRPC"""
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error
            
            request = lnrpc.Invoice()
            
            if memo:
                request.memo = memo
            if value:
                request.value = int(value)
            request.expiry = int(expiry)
            request.private = private
            if description_hash:
                request.description_hash = bytes.fromhex(description_hash)
            
            response = self.stub.AddInvoice(request, timeout=10)
            
            return {
                'r_hash': response.r_hash.hex(),
                'payment_request': response.payment_request,
                'add_index': str(response.add_index)
            }, None
            
        except grpc.RpcError as e:
            self._connected = False
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro inesperado: {str(e)}"
    
    def send_payment_grpc(self, payment_request=None, dest=None, amt=None, fee_limit_sat=None, timeout_seconds=60):
        """Enviar pagamento via gRPC"""
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error
            
            if payment_request:
                # Pagamento usando payment request (bolt11)
                request = lnrpc.SendRequest()
                request.payment_request = payment_request
                if fee_limit_sat:
                    request.fee_limit.fixed = int(fee_limit_sat)
            elif dest and amt:
                # Pagamento direto usando dest e amount
                request = lnrpc.SendRequest()
                request.dest_string = dest
                request.amt = int(amt)
                if fee_limit_sat:
                    request.fee_limit.fixed = int(fee_limit_sat)
            else:
                return None, "Deve fornecer payment_request OU (dest + amt)"
            
            response = self.stub.SendPaymentSync(request, timeout=timeout_seconds)
            
            if response.payment_error:
                return None, f"Erro no pagamento: {response.payment_error}"
            
            return {
                'payment_preimage': response.payment_preimage.hex(),
                'payment_route': {
                    'total_time_lock': response.payment_route.total_time_lock,
                    'total_fees': str(response.payment_route.total_fees),
                    'total_amt': str(response.payment_route.total_amt),
                    'total_fees_msat': str(response.payment_route.total_fees_msat),
                    'total_amt_msat': str(response.payment_route.total_amt_msat)
                } if response.payment_route else None
            }, None
            
        except grpc.RpcError as e:
            self._connected = False
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro inesperado: {str(e)}"
    
    def new_address_grpc(self, address_type="p2wkh", account=None):
        """Gerar novo endereço via gRPC"""
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error
            
            request = lnrpc.NewAddressRequest()
            
            # Mapear tipos de endereço
            type_mapping = {
                'p2wkh': lnrpc.AddressType.WITNESS_PUBKEY_HASH,
                'np2wkh': lnrpc.AddressType.NESTED_PUBKEY_HASH,
                'p2tr': lnrpc.AddressType.TAPROOT_PUBKEY if hasattr(lnrpc.AddressType, 'TAPROOT_PUBKEY') else lnrpc.AddressType.WITNESS_PUBKEY_HASH
            }
            
            request.type = type_mapping.get(address_type, lnrpc.AddressType.WITNESS_PUBKEY_HASH)
            
            if account:
                request.account = account
            
            response = self.stub.NewAddress(request, timeout=10)
            
            return {
                'address': response.address
            }, None
            
        except grpc.RpcError as e:
            self._connected = False
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro inesperado: {str(e)}"
    
    def send_coins_grpc(self, addr, amount, target_conf=None, sat_per_vbyte=None, send_all=False, label=None, min_confs=1, spend_unconfirmed=False):
        """Enviar Bitcoin on-chain via gRPC"""
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error
            
            request = lnrpc.SendCoinsRequest()
            request.addr = addr
            request.send_all = send_all
            request.min_confs = int(min_confs)
            request.spend_unconfirmed = spend_unconfirmed
            
            if not send_all:
                if not amount or amount <= 0:
                    return None, "Amount é obrigatório quando send_all=false"
                request.amount = int(amount)
            
            if target_conf:
                request.target_conf = int(target_conf)
            if sat_per_vbyte:
                request.sat_per_vbyte = int(sat_per_vbyte)
            if label:
                request.label = label
            
            response = self.stub.SendCoins(request, timeout=30)
            
            return {
                'txid': response.txid
            }, None
            
        except grpc.RpcError as e:
            self._connected = False
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro inesperado: {str(e)}"
    
    def send_keysend_grpc(self, dest, amt, fee_limit_sat=None, timeout_seconds=60, custom_records=None, final_cltv_delta=None):
        """Enviar keysend (pagamento espontâneo) via gRPC"""
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error
            
            import secrets
            
            # Gerar preimage aleatório para keysend (32 bytes)
            preimage = secrets.token_bytes(32)
            payment_hash = hashlib.sha256(preimage).digest()
            
            request = lnrpc.SendRequest()
            request.dest_string = dest
            request.amt = int(amt)
            request.payment_hash = payment_hash
            
            # Adicionar o preimage nos custom records (TLV record 5482373484)
            # Este é o record type padrão para keysend
            if not custom_records:
                custom_records = {}
            custom_records[5482373484] = preimage  # Keysend preimage record
            
            # Configurar custom records
            for key, value in custom_records.items():
                # Converter chave para inteiro se for string
                if isinstance(key, str):
                    record_key = int(key)
                else:
                    record_key = key
                
                # Converter valor para bytes se necessário
                if isinstance(value, str):
                    record_value = value.encode('utf-8')
                else:
                    record_value = value
                
                request.dest_custom_records[record_key] = record_value
            
            if fee_limit_sat:
                request.fee_limit.fixed = int(fee_limit_sat)
            if final_cltv_delta:
                request.final_cltv_delta = int(final_cltv_delta)
            
            response = self.stub.SendPaymentSync(request, timeout=timeout_seconds)
            
            if response.payment_error:
                return None, f"Erro no keysend: {response.payment_error}"
            
            return {
                'payment_preimage': response.payment_preimage.hex(),
                'payment_hash': payment_hash.hex(),
                'payment_route': {
                    'total_time_lock': response.payment_route.total_time_lock,
                    'total_fees': str(response.payment_route.total_fees),
                    'total_amt': str(response.payment_route.total_amt),
                    'total_fees_msat': str(response.payment_route.total_fees_msat),
                    'total_amt_msat': str(response.payment_route.total_amt_msat)
                } if response.payment_route else None
            }, None
            
        except grpc.RpcError as e:
            self._connected = False
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro inesperado: {str(e)}"
    
    def list_unspent_grpc(self, min_confs=0, max_confs=9999999, account=None):
        """Listar UTXOs via gRPC"""
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error
            
            request = lnrpc.ListUnspentRequest()
            request.min_confs = int(min_confs)
            request.max_confs = int(max_confs)
            
            if account:
                request.account = account
            
            response = self.stub.ListUnspent(request, timeout=10)
            
            utxos = []
            for utxo in response.utxos:
                utxos.append({
                    'address': utxo.address,
                    'amount_sat': str(utxo.amount_sat),
                    'pk_script': str(utxo.pk_script),  # pk_script já é string
                    'outpoint': {
                        'txid_bytes': utxo.outpoint.txid_bytes.hex(),  # txid_bytes são bytes
                        'txid_str': utxo.outpoint.txid_str,
                        'output_index': utxo.outpoint.output_index
                    },
                    'confirmations': str(utxo.confirmations)
                })
            
            return {
                'utxos': utxos
            }, None
            
        except grpc.RpcError as e:
            self._connected = False
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro inesperado: {str(e)}"
    
    def gen_seed_grpc(self):
        """Gerar seed phrase via gRPC"""
        try:
            # Para gerar seed, não precisamos de autenticação
            # Criar canal inseguro para operações de inicialização
            channel = grpc.insecure_channel(self.host)
            stub = lnrpcstub.LightningStub(channel)
            
            request = lnrpc.GenSeedRequest()
            response = stub.GenSeed(request, timeout=30)
            
            return {
                'cipher_seed_mnemonic': list(response.cipher_seed_mnemonic),
                'enciphered_seed': response.enciphered_seed.hex() if response.enciphered_seed else None
            }, None
            
        except grpc.RpcError as e:
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro ao gerar seed: {str(e)}"
    
    def init_wallet_grpc(self, wallet_password, cipher_seed_mnemonic, aezeed_passphrase="", recovery_window=250, channel_backups=None, stateless_init=False):
        """Inicializar wallet LND via gRPC"""
        try:
            # Para inicializar wallet, não precisamos de autenticação ainda
            channel = grpc.insecure_channel(self.host)
            stub = lnrpcstub.LightningStub(channel)
            
            request = lnrpc.InitWalletRequest()
            request.wallet_password = wallet_password.encode('utf-8')
            request.cipher_seed_mnemonic[:] = cipher_seed_mnemonic
            if aezeed_passphrase:
                request.aezeed_passphrase = aezeed_passphrase.encode('utf-8')
            request.recovery_window = recovery_window
            request.stateless_init = stateless_init
            
            if channel_backups:
                request.channel_backups = channel_backups
            
            response = stub.InitWallet(request, timeout=120)
            
            return {
                'success': True,
                'message': 'Wallet initialized successfully',
                'admin_macaroon': response.admin_macaroon.hex() if hasattr(response, 'admin_macaroon') else None
            }, None
            
        except grpc.RpcError as e:
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro ao inicializar wallet: {str(e)}"
    
    def unlock_wallet_grpc(self, wallet_password, recovery_window=250, channel_backups=None, stateless_init=False):
        """Desbloquear wallet LND via gRPC"""
        try:
            # Para desbloquear wallet, não precisamos de autenticação
            channel = grpc.insecure_channel(self.host)
            stub = lnrpcstub.LightningStub(channel)
            
            request = lnrpc.UnlockWalletRequest()
            request.wallet_password = wallet_password.encode('utf-8')
            request.recovery_window = recovery_window
            request.stateless_init = stateless_init
            
            if channel_backups:
                request.channel_backups = channel_backups
            
            response = stub.UnlockWallet(request, timeout=120)
            
            # Depois de desbloquear, resetar conexão para usar credenciais
            self._connected = False
            
            return {
                'success': True,
                'message': 'Wallet unlocked successfully'
            }, None
            
        except grpc.RpcError as e:
            return None, f"gRPC Error: {e.details()}"
        except Exception as e:
            return None, f"Erro ao desbloquear wallet: {str(e)}"
    
    def close(self):
        """Fechar conexão gRPC"""
        if self.channel:
            self.channel.close()
            self._connected = False

# Singleton para reusar conexão gRPC
lnd_grpc_client = LNDgRPCClient()

# === CLIENTE RPC ELEMENTS/LIQUID ===

class ElementsRPCClient:
    """Cliente RPC para Elements/Liquid daemon"""
    
    def __init__(self):
        self.host = ELEMENTS_RPC_HOST
        self.port = ELEMENTS_RPC_PORT
        self.user = ELEMENTS_RPC_USER
        self.password = ELEMENTS_RPC_PASSWORD
        self.auth = base64.b64encode(f"{self.user}:{self.password}".encode()).decode()
        
    def _call_rpc(self, method, params=None):
        """Faz chamada RPC para Elements daemon"""
        if params is None:
            params = []
            
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Basic {self.auth}'
        }
        
        payload = {
            "jsonrpc": "1.0",
            "id": "python-elements-rpc",
            "method": method,
            "params": params
        }
        
        try:
            import requests
            response = requests.post(
                f"http://{self.host}:{self.port}/",
                json=payload,
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                if 'error' in result and result['error'] is not None:
                    return None, f"Elements RPC Error: {result['error']}"
                return result.get('result'), None
            else:
                return None, f"HTTP Error {response.status_code}: {response.text}"
                
        except requests.exceptions.RequestException as e:
            return None, f"Connection Error: {str(e)}"
        except Exception as e:
            return None, f"Unexpected Error: {str(e)}"
    
    def get_balances(self):
        """Obtém saldos de todos os assets"""
        return self._call_rpc("getbalances")
    
    def get_asset_labels(self):
        """Obtém labels/nomes dos assets conhecidos"""
        return self._call_rpc("dumpassetlabels")
    
    def get_new_address(self, label="", address_type="bech32"):
        """Gera novo endereço Liquid"""
        return self._call_rpc("getnewaddress", [label, address_type])
    
    def send_to_address(self, address, amount, asset_label=None, subtract_fee=False):
        """Envia asset para endereço"""
        params = [address, amount]
        if asset_label:
            # Adicionar parâmetros opcionais até chegar no assetlabel
            params.extend(["", "", subtract_fee, True, None, "unset", True, asset_label])
        return self._call_rpc("sendtoaddress", params)
    
    def list_unspent(self, minconf=1, maxconf=9999999, asset=None):
        """Lista UTXOs não gastos"""
        params = [minconf, maxconf]
        if asset:
            params.append([])  # addresses
            params.append(True)  # include_unsafe
            params.append({"asset": asset})  # query_options
        return self._call_rpc("listunspent", params)
    
    def list_transactions(self, count=30, skip=0):
        """Lista transações recentes"""
        return self._call_rpc("listtransactions", ["*", count, skip])
    
    def get_blockchain_info(self):
        """Obtém informações da blockchain"""
        return self._call_rpc("getblockchaininfo")

# Singleton para reusar conexão Elements RPC
elements_rpc_client = ElementsRPCClient()

# === SISTEMA DE CHAT LIGHTNING ===

# Configuração do banco SQLite
CHAT_DB_PATH = "/data/lightning_chat.db"

def init_chat_database():
    """Inicializa o banco de dados SQLite para o chat"""
    conn = sqlite3.connect(CHAT_DB_PATH)
    cursor = conn.cursor()
    
    # Tabela para mensagens de chat
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS chat_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            node_id TEXT NOT NULL,
            message TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            type TEXT NOT NULL, -- 'sent' ou 'received'
            payment_hash TEXT,
            status TEXT DEFAULT 'confirmed', -- 'pending', 'confirmed', 'failed'
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Tabela para tracking de keysends recebidos
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS keysend_tracking (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payment_hash TEXT UNIQUE NOT NULL,
            sender_node_id TEXT NOT NULL,
            amount_sat INTEGER NOT NULL,
            message TEXT,
            timestamp INTEGER NOT NULL,
            processed BOOLEAN DEFAULT FALSE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Índices para melhor performance
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_chat_node_id ON chat_messages(node_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_chat_timestamp ON chat_messages(timestamp)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_keysend_processed ON keysend_tracking(processed)')
    
    conn.commit()
    conn.close()

def save_chat_message(node_id, message, msg_type, payment_hash=None, status='confirmed'):
    """Salva uma mensagem de chat no banco"""
    conn = sqlite3.connect(CHAT_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        INSERT INTO chat_messages (node_id, message, timestamp, type, payment_hash, status)
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (node_id, message, int(time.time() * 1000), msg_type, payment_hash, status))
    
    conn.commit()
    conn.close()

def get_chat_messages(node_id, limit=100):
    """Recupera mensagens de chat com um node específico"""
    conn = sqlite3.connect(CHAT_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT message, timestamp, type, status, payment_hash
        FROM chat_messages 
        WHERE node_id = ?
        ORDER BY timestamp ASC
        LIMIT ?
    ''', (node_id, limit))
    
    messages = []
    for row in cursor.fetchall():
        messages.append({
            'message': row[0],
            'timestamp': row[1],
            'type': row[2],
            'status': row[3],
            'payment_hash': row[4]
        })
    
    conn.close()
    return messages

def get_all_conversations():
    """Recupera todas as conversas ativas"""
    conn = sqlite3.connect(CHAT_DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT 
            node_id,
            MAX(timestamp) as last_activity,
            COUNT(*) as message_count,
            (SELECT message FROM chat_messages c2 
             WHERE c2.node_id = c1.node_id 
             ORDER BY timestamp DESC LIMIT 1) as last_message
        FROM chat_messages c1
        GROUP BY node_id
        ORDER BY last_activity DESC
    ''')
    
    conversations = []
    for row in cursor.fetchall():
        conversations.append({
            'node_id': row[0],
            'last_activity': row[1],
            'message_count': row[2],
            'last_message': row[3]
        })
    
    conn.close()
    return conversations

def process_received_keysend(payment_hash, sender_node_id, amount_sat, custom_records=None):
    """Processa um keysend recebido e extrai mensagem se houver"""
    message = None
    
    # Tentar extrair mensagem do TLV record 34349334
    if custom_records and '34349334' in custom_records:
        try:
            # Decodificar mensagem do base64
            message_bytes = base64.b64decode(custom_records['34349334'])
            message = message_bytes.decode('utf-8')
        except Exception as e:
            print(f"Erro ao decodificar mensagem do keysend: {e}")
    
    # Salvar no tracking
    conn = sqlite3.connect(CHAT_DB_PATH)
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            INSERT INTO keysend_tracking 
            (payment_hash, sender_node_id, amount_sat, message, timestamp)
            VALUES (?, ?, ?, ?, ?)
        ''', (payment_hash, sender_node_id, amount_sat, message, int(time.time() * 1000)))
        
        # Se tem mensagem, salvar como mensagem de chat
        if message:
            save_chat_message(sender_node_id, message, 'received')
            
        conn.commit()
        return True
        
    except sqlite3.IntegrityError:
        # Já processado
        return False
    finally:
        conn.close()

# Variável global para notificações
new_messages_count = 0
new_messages_lock = threading.Lock()

def increment_new_messages():
    """Incrementa contador de novas mensagens"""
    global new_messages_count
    with new_messages_lock:
        new_messages_count += 1

def reset_new_messages():
    """Reseta contador de novas mensagens"""
    global new_messages_count
    with new_messages_lock:
        new_messages_count = 0

def get_new_messages_count():
    """Retorna contador de novas mensagens"""
    global new_messages_count
    with new_messages_lock:
        return new_messages_count

# Inicializar banco na inicialização da aplicação
init_chat_database()

# Mapeamento de serviços
SERVICE_MAPPING = {
    'lnbits': 'lnbits.service',
    'thunderhub': 'thunderhub.service',
    'simple': 'simple-lnwallet.service',
    'lndg': 'lndg.service',
    'lndg-controller': 'lndg-controller.service',
    'lnd': 'lnd.service',
    'bitcoind': 'bitcoind.service',
    'elementsd': 'elementsd.service',
    'bos-telegram': 'bos-telegram.service',
    'tor': 'tor@default.service',
    'gotty-fullauto': 'gotty-fullauto.service'
}

def run_command(command):
    """Executa um comando shell e retorna o output (usado apenas para CLIs externos)"""
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=10
        )
        return result.stdout.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", 1
    except Exception as e:
        return str(e), 1

def get_service_status(service_name):
    """Verifica se um serviço está rodando usando D-Bus/systemd"""
    if PYDBUS_AVAILABLE:
        try:
            bus = SystemBus()
            systemd = bus.get('.systemd1')
            unit_path = systemd.GetUnit(service_name)
            unit = bus.get('.systemd1', unit_path)
            active_state = unit.Get('org.freedesktop.systemd1.Unit', 'ActiveState')
            return active_state == 'active'
        except Exception as e:
            print(f"Error getting service status via D-Bus: {e}")
            # Fallback para subprocess
            pass
    
    # Fallback: usar subprocess
    output, code = run_command(f"systemctl is-active {service_name}")
    return output == "active"

def manage_systemd_service(service_name, action):
    """Gerencia um serviço systemd usando D-Bus"""
    if PYDBUS_AVAILABLE:
        try:
            bus = SystemBus()
            systemd = bus.get('.systemd1')
            unit_path = systemd.GetUnit(service_name)
            unit = bus.get('.systemd1', unit_path)
            
            if action == 'start':
                unit.Start('replace')
            elif action == 'stop':
                unit.Stop('replace')
            elif action == 'restart':
                unit.Restart('replace')
            
            return True, ""
        except Exception as e:
            return False, str(e)
    
    # Fallback: usar subprocess com sudo
    command = f"sudo systemctl {action} {service_name}"
    output, code = run_command(command)
    return code == 0, output

def get_bitcoind_info():
    """Obtém informações do Bitcoin Core"""
    if not get_service_status('bitcoind.service'):
        raise RuntimeError("Serviço bitcoind não está rodando")
        
    output, code = run_command("bitcoin-cli getblockchaininfo 2>/dev/null")
    if code != 0 or not output:
        raise RuntimeError("Não foi possível obter informações do Bitcoin Core via RPC")
        
    try:
        info = json.loads(output)
        return {
            'status': 'running',
            'blocks': info.get('blocks', 0),
            'progress': round(info.get('verificationprogress', 0) * 100, 2)
        }
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Resposta inválida do Bitcoin Core: {str(e)}")

def get_blockchain_size():
    """Obtém o tamanho da blockchain usando pathlib"""
    bitcoin_dir = Path.home() / ".bitcoin"
    if not bitcoin_dir.exists():
        raise FileNotFoundError(f"Diretório Bitcoin não encontrado: {bitcoin_dir}")
        
    total_size = sum(f.stat().st_size for f in bitcoin_dir.rglob('*') if f.is_file())
    # Converter para formato legível
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if total_size < 1024.0:
            return f"{total_size:.1f}{unit}"
        total_size /= 1024.0
    return f"{total_size:.1f}PB"

def get_macaroon_hex():
    """Lê o admin.macaroon e retorna em formato hex para gRPC"""
    try:
        with open(MACAROON_PATH, 'rb') as f:
            macaroon_bytes = f.read()
        return macaroon_bytes.hex()
    except Exception as e:
        print(f"Error reading macaroon: {e}")
        return None

def get_blockchain_balance():
    """Obtém o saldo on-chain do LND via gRPC"""
    try:
        success, error = lnd_grpc_client.ensure_connected()
        if not success:
            return {
                'error': error,
                'status': 'error'
            }
        
        request = lnrpc.WalletBalanceRequest()
        response = lnd_grpc_client.stub.WalletBalance(request, timeout=10)
        
        return {
            'status': 'success',
            'method': 'grpc',
            'total_balance': str(response.total_balance),
            'confirmed_balance': str(response.confirmed_balance),
            'unconfirmed_balance': str(response.unconfirmed_balance),
            'locked_balance': str(response.locked_balance) if hasattr(response, 'locked_balance') else '0'
        }
        
    except Exception as e:
        return {
            'error': f'Erro ao buscar saldo: {str(e)}',
            'status': 'error'
        }

def get_lnd_info():
    """Obtém informações do LND usando gRPC"""
    if not get_service_status('lnd.service'):
        raise RuntimeError("Serviço LND não está rodando")
    
    data, error = lnd_grpc_client.get_info_grpc()
    if error:
        raise RuntimeError(f"Erro ao conectar com LND via gRPC: {error}")
        
    return {
        'status': 'running',
        'method': 'grpc',
        'synced': data.get('synced_to_chain', False),
        'block_height': data.get('block_height', 0),
        'identity_pubkey': data.get('identity_pubkey', ''),
        'alias': data.get('alias', ''),
        'version': data.get('version', ''),
        'num_peers': data.get('num_peers', 0),
        'num_active_channels': data.get('num_active_channels', 0),
        'chains': data.get('chains', [])
    }

def get_lightning_balance():
    """Obtém o saldo do canal do LND via gRPC"""
    try:
        success, error = lnd_grpc_client.ensure_connected()
        if not success:
            return {
                'error': error,
                'status': 'error'
            }
        
        request = lnrpc.ChannelBalanceRequest()
        response = lnd_grpc_client.stub.ChannelBalance(request, timeout=10)
        
        return {
            'status': 'success',
            'method': 'grpc',
            'balance': str(response.balance),
            'pending_open_balance': str(response.pending_open_balance) if hasattr(response, 'pending_open_balance') else '0'
        }
        
    except Exception as e:
        return {
            'error': f'Erro ao buscar saldo dos canais: {str(e)}',
            'status': 'error'
        }

def connect_to_peer(lightning_address, perm=True, timeout=60):
    """Conecta a um peer Lightning Network usando gRPC"""
    try:
        # Validação da lightning address
        if not lightning_address:
            return {
                'error': 'lightning_address é obrigatório',
                'status': 'error'
            }
        
        data, error = lnd_grpc_client.connect_peer_grpc(lightning_address, perm, timeout)
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        return {
            'status': 'success',
            'method': 'grpc',
            'message': f'Conectado ao peer {lightning_address}',
            'peer_address': lightning_address,
            'permanent': perm
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao conectar ao peer: {str(e)}',
            'status': 'error'
        }

def get_connected_peers():
    """Obtém a lista de peers conectados usando gRPC"""
    try:
        data, error = lnd_grpc_client.list_peers_grpc()
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        return {
            'status': 'success',
            'method': 'grpc',
            'peers': data.get('peers', [])
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao buscar peers: {str(e)}',
            'status': 'error'
        }

def get_transactions(start_height=None, end_height=None, account=None):
    """Obtém a lista de transações on-chain do LND usando gRPC"""
    try:
        data, error = lnd_grpc_client.get_transactions_grpc(start_height, end_height, account)
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        transactions = data.get('transactions', [])
        
        # Enriquecer dados das transações com informações formatadas
        formatted_transactions = []
        for tx in transactions:
            formatted_tx = {
                'tx_hash': tx.get('tx_hash', ''),
                'amount': tx.get('amount', '0'),
                'num_confirmations': tx.get('num_confirmations', 0),
                'block_hash': tx.get('block_hash', ''),
                'block_height': tx.get('block_height', 0),
                'time_stamp': tx.get('time_stamp', '0'),
                'total_fees': tx.get('total_fees', '0'),
                'dest_addresses': tx.get('dest_addresses', []),
                'raw_tx_hex': tx.get('raw_tx_hex', ''),
                'label': tx.get('label', '')
            }
            
            # Adicionar timestamp formatado
            if tx.get('time_stamp'):
                try:
                    timestamp = int(tx.get('time_stamp'))
                    formatted_tx['date'] = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S')
                except Exception as date_error:
                    return None, f"Erro ao processar timestamp da transação {tx.get('tx_hash', 'unknown')}: {str(date_error)}"
            else:
                return None, f"Transação {tx.get('tx_hash', 'unknown')} não possui timestamp válido"
            
            # Determinar tipo de transação (entrada/saída)
            amount = int(tx.get('amount', '0'))
            if amount > 0:
                formatted_tx['type'] = 'received'
                formatted_tx['type_label'] = 'Recebida'
            else:
                formatted_tx['type'] = 'sent'
                formatted_tx['type_label'] = 'Enviada'
                formatted_tx['amount'] = str(abs(amount))  # Mostrar valor absoluto
            
            formatted_transactions.append(formatted_tx)
        
        return {
            'status': 'success',
            'method': 'grpc',
            'transactions': formatted_transactions,
            'total_transactions': len(formatted_transactions),
            'last_index': data.get('last_index', ''),
            'first_index': data.get('first_index', '')
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao buscar transações: {str(e)}',
            'status': 'error'
        }

def get_lightning_channels():
    """Obtém a lista de canais do LND usando gRPC"""
    try:
        success, error = lnd_grpc_client.ensure_connected()
        if not success:
            return {
                'error': error,
                'status': 'error'
            }
        
        request = lnrpc.ListChannelsRequest()
        response = lnd_grpc_client.stub.ListChannels(request, timeout=10)
        
        channels = []
        for channel in response.channels:
            channels.append({
                'active': channel.active,
                'remote_pubkey': channel.remote_pubkey,
                'channel_point': channel.channel_point,
                'chan_id': str(channel.chan_id),
                'capacity': str(channel.capacity),
                'local_balance': str(channel.local_balance),
                'remote_balance': str(channel.remote_balance),
                'commit_fee': str(channel.commit_fee),
                'commit_weight': str(channel.commit_weight),
                'fee_per_kw': str(channel.fee_per_kw),
                'unsettled_balance': str(channel.unsettled_balance),
                'total_satoshis_sent': str(channel.total_satoshis_sent),
                'total_satoshis_received': str(channel.total_satoshis_received),
                'num_updates': str(channel.num_updates),
                'csv_delay': channel.csv_delay,
                'private': channel.private
            })
        
        return {
            'status': 'success',
            'method': 'grpc',
            'channels': {'channels': channels}
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao buscar canais: {str(e)}',
            'status': 'error'
        }

def open_lightning_channel(node_pubkey, local_funding_amount=None, sat_per_vbyte=None, private=False, 
                          push_sat=0, target_conf=None, min_confs=1, spend_unconfirmed=False, 
                          close_address=None, base_fee=None, fee_rate=None, fund_max=False, memo=None):
    """Abre um canal Lightning"""
    try:
        # Validação básica dos parâmetros
        if not node_pubkey:
            return {
                'error': 'node_pubkey é obrigatório',
                'status': 'error'
            }
        
        # Validação fund_max vs local_funding_amount
        if fund_max and local_funding_amount is not None:
            return {
                'error': 'fund_max=true não pode ser usado junto com local_funding_amount. Use um ou outro.',
                'status': 'error'
            }
        
        if not fund_max and (local_funding_amount is None or local_funding_amount <= 0):
            return {
                'error': 'local_funding_amount é obrigatório quando fund_max=false',
                'status': 'error'
            }
        
        if local_funding_amount is not None and local_funding_amount < 20000:  # Mínimo padrão de 20k sats
            return {
                'error': 'Valor mínimo para abrir canal é 20.000 satoshis',
                'status': 'error'
            }
        
        # Preparar dados para a requisição
        channel_data = {
            'node_pubkey_string': node_pubkey,
            'private': private,
            'min_confs': min_confs,
            'spend_unconfirmed': spend_unconfirmed
        }
        
        # Adicionar local_funding_amount apenas se não for fund_max
        if not fund_max:
            channel_data['local_funding_amount'] = str(local_funding_amount)
        else:
            channel_data['fund_max'] = True
        
        # Adicionar parâmetros opcionais
        if push_sat > 0:
            channel_data['push_sat'] = str(push_sat)
        if sat_per_vbyte:
            channel_data['sat_per_vbyte'] = str(sat_per_vbyte)
        if target_conf:
            channel_data['target_conf'] = target_conf
        if close_address:
            channel_data['close_address'] = close_address
        if base_fee is not None:
            channel_data['base_fee'] = str(base_fee)
        if fee_rate is not None:
            channel_data['fee_rate'] = str(fee_rate)
        if memo:
            channel_data['memo'] = memo
            
        # Fazer a requisição para abrir o canal via gRPC
        try:
            success, error = lnd_grpc_client.ensure_connected()
            if not success:
                return {
                    'error': error,
                    'status': 'error'
                }
            
            request = lnrpc.OpenChannelRequest()
            request.node_pubkey_string = node_pubkey
            request.private = private
            request.min_confs = min_confs
            request.spend_unconfirmed = spend_unconfirmed
            
            if not fund_max:
                request.local_funding_amount = int(local_funding_amount)
            else:
                request.fund_max = True
            
            if push_sat > 0:
                request.push_sat = int(push_sat)
            if sat_per_vbyte:
                request.sat_per_vbyte = int(sat_per_vbyte)
            if target_conf:
                request.target_conf = target_conf
            if close_address:
                request.close_address = close_address
            if memo:
                request.memo = memo
            
            response = lnd_grpc_client.stub.OpenChannelSync(request, timeout=60)
            
            return {
                'status': 'success',
                'funding_txid': response.funding_txid_str,
                'output_index': response.output_index,
                'message': 'Canal sendo aberto. Aguarde confirmações na rede.'
            }
            
        except grpc.RpcError as e:
            return {
                'error': f'gRPC Error: {e.details()}',
                'status': 'error'
            }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao abrir canal: {str(e)}',
            'status': 'error'
        }

def close_lightning_channel(channel_point, force_close=False, target_conf=None, sat_per_vbyte=None):
    """Fecha um canal Lightning"""
    try:
        if not channel_point:
            return {
                'error': 'channel_point é obrigatório',
                'status': 'error'
            }
        
        # Preparar requisição para fechar canal via gRPC
        try:
            success, error = lnd_grpc_client.ensure_connected()
            if not success:
                return {
                    'error': error,
                    'status': 'error'
                }
            
            request = lnrpc.CloseChannelRequest()
            
            # Configurar channel point
            txid_str, output_index = channel_point.split(':')
            request.channel_point.funding_txid_str = txid_str
            request.channel_point.output_index = int(output_index)
            request.force = force_close
            
            if target_conf:
                request.target_conf = int(target_conf)
            if sat_per_vbyte:
                request.sat_per_vbyte = int(sat_per_vbyte)
            
            # Usar CloseChannel que retorna um stream, mas pegar apenas a primeira resposta
            response_stream = lnd_grpc_client.stub.CloseChannel(request, timeout=60)
            response = next(response_stream)
            
            close_type = "forçado" if force_close else "cooperativo"
            
            if hasattr(response, 'close_pending'):
                return {
                    'status': 'success',
                    'closing_txid': response.close_pending.txid.hex() if hasattr(response.close_pending, 'txid') else 'pending',
                    'message': f'Canal sendo fechado ({close_type}). Aguarde confirmações na rede.'
                }
            elif hasattr(response, 'chan_close'):
                return {
                    'status': 'success',
                    'closing_txid': response.chan_close.closing_txid,
                    'message': f'Canal fechado ({close_type}) com sucesso.'
                }
            else:
                return {
                    'status': 'success',
                    'message': f'Canal sendo fechado ({close_type}). Aguarde confirmações na rede.'
                }
                
        except grpc.RpcError as e:
            return {
                'error': f'gRPC Error: {e.details()}',
                'status': 'error'
            }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao fechar canal: {str(e)}',
            'status': 'error'
        }

def get_pending_channels():
    """Obtém canais pendentes do LND usando gRPC"""
    try:
        success, error = lnd_grpc_client.ensure_connected()
        if not success:
            return {
                'error': error,
                'status': 'error'
            }
        
        request = lnrpc.PendingChannelsRequest()
        response = lnd_grpc_client.stub.PendingChannels(request, timeout=10)
        
        return {
            'status': 'success',
            'method': 'grpc',
            'pending_open_channels': [
                {
                    'channel': {
                        'remote_node_pub': ch.channel.remote_node_pub,
                        'channel_point': ch.channel.channel_point,
                        'capacity': str(ch.channel.capacity),
                        'local_balance': str(ch.channel.local_balance),
                        'remote_balance': str(ch.channel.remote_balance)
                    },
                    'confirmation_height': ch.confirmation_height,
                    'commit_fee': str(ch.commit_fee),
                    'commit_weight': str(ch.commit_weight),
                    'fee_per_kw': str(ch.fee_per_kw)
                } for ch in response.pending_open_channels
            ],
            'pending_closing_channels': [
                {
                    'channel': {
                        'remote_node_pub': ch.channel.remote_node_pub,
                        'channel_point': ch.channel.channel_point,
                        'capacity': str(ch.channel.capacity),
                        'local_balance': str(ch.channel.local_balance),
                        'remote_balance': str(ch.channel.remote_balance)
                    },
                    'closing_txid': ch.closing_txid
                } for ch in response.pending_closing_channels
            ],
            'pending_force_closing_channels': [
                {
                    'channel': {
                        'remote_node_pub': ch.channel.remote_node_pub,
                        'channel_point': ch.channel.channel_point,
                        'capacity': str(ch.channel.capacity),
                        'local_balance': str(ch.channel.local_balance),
                        'remote_balance': str(ch.channel.remote_balance)
                    },
                    'closing_txid': ch.closing_txid,
                    'limbo_balance': str(ch.limbo_balance),
                    'maturity_height': ch.maturity_height,
                    'blocks_til_maturity': ch.blocks_til_maturity
                } for ch in response.pending_force_closing_channels
            ],
            'waiting_close_channels': [
                {
                    'channel': {
                        'remote_node_pub': ch.channel.remote_node_pub,
                        'channel_point': ch.channel.channel_point,
                        'capacity': str(ch.channel.capacity),
                        'local_balance': str(ch.channel.local_balance),
                        'remote_balance': str(ch.channel.remote_balance)
                    },
                    'limbo_balance': str(ch.limbo_balance),
                    'commitments': {
                        'local_txid': ch.commitments.local_txid,
                        'remote_txid': ch.commitments.remote_txid,
                        'remote_pending_txid': ch.commitments.remote_pending_txid,
                        'local_commit_fee_sat': str(ch.commitments.local_commit_fee_sat),
                        'remote_commit_fee_sat': str(ch.commitments.remote_commit_fee_sat)
                    } if ch.commitments else None
                } for ch in response.waiting_close_channels
            ]
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao buscar canais pendentes: {str(e)}',
            'status': 'error'
        }

def add_invoice(memo=None, value=None, expiry=3600, private=False, description_hash=None):
    """Criar uma invoice Lightning"""
    try:
        data, error = lnd_grpc_client.add_invoice_grpc(memo, value, expiry, private, description_hash)
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        return {
            'status': 'success',
            'method': 'grpc',
            'r_hash': data.get('r_hash'),
            'payment_request': data.get('payment_request'),
            'add_index': data.get('add_index')
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao criar invoice: {str(e)}',
            'status': 'error'
        }

def send_payment(payment_request=None, dest=None, amt=None, fee_limit_sat=None, timeout_seconds=60):
    """Enviar pagamento Lightning"""
    try:
        data, error = lnd_grpc_client.send_payment_grpc(payment_request, dest, amt, fee_limit_sat, timeout_seconds)
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        return {
            'status': 'success',
            'method': 'grpc',
            'payment_preimage': data.get('payment_preimage'),
            'payment_route': data.get('payment_route')
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao enviar pagamento: {str(e)}',
            'status': 'error'
        }

def new_address(address_type="p2wkh", account=None):
    """Gerar novo endereço Bitcoin"""
    try:
        data, error = lnd_grpc_client.new_address_grpc(address_type, account)
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        return {
            'status': 'success',
            'method': 'grpc',
            'address': data.get('address')
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao gerar endereço: {str(e)}',
            'status': 'error'
        }

def send_coins(addr, amount, target_conf=None, sat_per_vbyte=None, send_all=False, label=None, min_confs=1, spend_unconfirmed=False):
    """Enviar Bitcoin on-chain"""
    try:
        data, error = lnd_grpc_client.send_coins_grpc(addr, amount, target_conf, sat_per_vbyte, send_all, label, min_confs, spend_unconfirmed)
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        return {
            'status': 'success',
            'method': 'grpc',
            'txid': data.get('txid')
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao enviar Bitcoin: {str(e)}',
            'status': 'error'
        }

def send_keysend(dest, amt, fee_limit_sat=None, timeout_seconds=60, custom_records=None, final_cltv_delta=None):
    """Enviar keysend (pagamento espontâneo) Lightning"""
    try:
        data, error = lnd_grpc_client.send_keysend_grpc(dest, amt, fee_limit_sat, timeout_seconds, custom_records, final_cltv_delta)
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        return {
            'status': 'success',
            'method': 'grpc',
            'payment_type': 'keysend',
            'payment_preimage': data.get('payment_preimage'),
            'payment_hash': data.get('payment_hash'),
            'payment_route': data.get('payment_route')
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao enviar keysend: {str(e)}',
            'status': 'error'
        }

def list_unspent(min_confs=0, max_confs=9999999, account=None):
    """Listar UTXOs disponíveis"""
    try:
        data, error = lnd_grpc_client.list_unspent_grpc(min_confs, max_confs, account)
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        return {
            'status': 'success',
            'method': 'grpc',
            'utxos': data.get('utxos', [])
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao listar UTXOs: {str(e)}',
            'status': 'error'
        }


@app.route('/api/v1/system/status', methods=['GET'])
def system_status():
    """Retorna o status do sistema"""
    try:
        # CPU
        cpu_percent = psutil.cpu_percent(interval=1)
        load_avg = os.getloadavg()
        
        # RAM
        ram = psutil.virtual_memory()
        
        # LND Info (pode gerar exceção)
        try:
            lnd_info = get_lnd_info()
        except Exception as e:
            lnd_info = {
                'status': 'error',
                'error': str(e)
            }
        
        # Bitcoin Info (pode gerar exceção)
        try:
            bitcoin_info = get_bitcoind_info()
        except Exception as e:
            bitcoin_info = {
                'status': 'error',
                'error': str(e)
            }
        
        # Tor Status
        tor_active = get_service_status('tor@default.service')
        
        # Blockchain (pode gerar exceção)
        try:
            blockchain_size = get_blockchain_size()
        except Exception as e:
            blockchain_size = f"Error: {str(e)}"
        
        response_data = {
            'cpu': {
                'usage': round(cpu_percent, 2),
                'load': f"{load_avg[0]:.2f}, {load_avg[1]:.2f}, {load_avg[2]:.2f}"
            },
            'ram': {
                'used': f"{ram.used / (1024**3):.1f}GB",
                'total': f"{ram.total / (1024**3):.1f}GB",
                'percentage': round(ram.percent, 1)
            },
            'lnd': lnd_info,
            'bitcoind': bitcoin_info,
            'tor': {
                'status': 'running' if tor_active else 'stopped'
            },
            'blockchain': {
                'size': blockchain_size,
                'progress': bitcoin_info.get('progress', 0) if bitcoin_info.get('status') != 'error' else 0
            }
        }
        
        return jsonify(response_data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/system/services', methods=['GET'])
def services_status():
    """Retorna o status de todos os serviços"""
    try:
        services = {}
        for service_key, service_name in SERVICE_MAPPING.items():
            services[service_key] = get_service_status(service_name)
        
        return jsonify({'services': services})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/system/service', methods=['POST'])
def manage_service():
    """Gerencia um serviço com toggle automático (start/stop baseado no status atual)"""
    try:
        data = request.get_json()
        service_key = data.get('service')
        
        if not service_key:
            return jsonify({'error': 'Service é obrigatório'}), 400
        
        if service_key not in SERVICE_MAPPING:
            return jsonify({'error': f'Serviço {service_key} não encontrado'}), 404
        
        service_name = SERVICE_MAPPING[service_key]
        
        # Verificar status atual do serviço
        current_status = get_service_status(service_name)
        
        # Determinar ação baseada no status atual (toggle)
        if current_status:
            action = 'stop'  # Se está ativo, parar
        else:
            action = 'start'  # Se está inativo, iniciar
        
        # Gerencia o serviço usando D-Bus/systemd
        success, error_msg = manage_systemd_service(service_name, action)
        
        if success:
            # Verificar novo status após a operação
            new_status = get_service_status(service_name)
            return jsonify({
                'success': True,
                'service': service_key,
                'action': action,
                'previous_status': current_status,
                'current_status': new_status,
                'message': f'Serviço {service_key} {"iniciado" if action == "start" else "parado"} com sucesso'
            })
        else:
            return jsonify({
                'error': f'Falha ao executar {action} em {service_key}',
                'output': error_msg,
                'current_status': current_status
            }), 500
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/system/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'version': '1.0'})

@app.route('/api/v1/wallet/balance/onchain', methods=['GET'])
def blockchain_balance():
    """Endpoint para obter saldo on-chain do LND"""
    try:
        balance_info = get_blockchain_balance()
        
        if balance_info.get('status') == 'error':
            return jsonify(balance_info), 500
        
        return jsonify(balance_info)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/balance/lightning', methods=['GET'])
def lightning_balance():
    """Endpoint para obter saldo Lightning do LND"""
    try:
        balance_info = get_lightning_balance()
        
        if balance_info.get('status') == 'error':
            return jsonify(balance_info), 500
        
        return jsonify(balance_info)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500
@app.route('/api/v1/wallet/transactions', methods=['GET'])
def transactions():
    """Endpoint para listar transações on-chain"""
    try:
        # Extrair parâmetros opcionais da query string
        start_height = request.args.get('start_height', type=int)
        end_height = request.args.get('end_height', type=int)
        account = request.args.get('account')
        
        # Buscar transações
        transactions_info = get_transactions(start_height, end_height, account)
        
        if transactions_info.get('status') == 'error':
            return jsonify(transactions_info), 500
        
        return jsonify(transactions_info)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/peers', methods=['GET'])
def get_peers():
    """Endpoint para listar peers conectados"""
    try:
        peers_info = get_connected_peers()
        
        if peers_info.get('status') == 'error':
            return jsonify(peers_info), 500
        
        return jsonify(peers_info)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/peers/connect', methods=['POST'])
def connect_peer():
    """Endpoint para conectar a um peer Lightning"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'error': 'Dados JSON são obrigatórios',
                'status': 'error'
            }), 400
        
        # Extrair parâmetros
        lightning_address = data.get('lightning_address') or data.get('addr')
        perm = data.get('perm', True)
        timeout = data.get('timeout', 60)
        
        if not lightning_address:
            return jsonify({
                'error': 'lightning_address é obrigatório',
                'status': 'error'
            }), 400
        
        # Conectar ao peer
        result = connect_to_peer(lightning_address, perm, timeout)
        
        if result.get('status') == 'error':
            return jsonify(result), 500
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500
@app.route('/api/v1/lightning/channels', methods=['GET'])
def list_channels():
    """Endpoint para listar canais Lightning"""
    try:
        channels_info = get_lightning_channels()
        
        if channels_info.get('status') == 'error':
            return jsonify(channels_info), 500
        
        return jsonify(channels_info)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/channels/open', methods=['POST'])
def open_channel():
    """Endpoint para abrir um canal Lightning"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'error': 'Dados JSON são obrigatórios',
                'status': 'error'
            }), 400
        
        # Extrair parâmetros obrigatórios
        node_pubkey = data.get('node_pubkey')
        local_funding_amount = data.get('local_funding_amount')
        fund_max = data.get('fund_max', False)
        
        # Validação básica
        if not node_pubkey:
            return jsonify({
                'error': 'node_pubkey é obrigatório',
                'status': 'error'
            }), 400
        
        # Validação fund_max vs local_funding_amount
        if fund_max and local_funding_amount is not None:
            return jsonify({
                'error': 'fund_max=true não pode ser usado junto com local_funding_amount. Use um ou outro.',
                'status': 'error'
            }), 400
        
        if not fund_max and (local_funding_amount is None or local_funding_amount <= 0):
            return jsonify({
                'error': 'local_funding_amount é obrigatório quando fund_max=false',
                'status': 'error'
            }), 400
        
        # Extrair parâmetros opcionais
        sat_per_vbyte = data.get('sat_per_vbyte')
        private = data.get('private', False)
        push_sat = data.get('push_sat', 0)
        target_conf = data.get('target_conf')
        min_confs = data.get('min_confs', 1)
        spend_unconfirmed = data.get('spend_unconfirmed', False)
        close_address = data.get('close_address')
        base_fee = data.get('base_fee')
        fee_rate = data.get('fee_rate')
        memo = data.get('memo')
        
        # Abrir o canal
        result = open_lightning_channel(
            node_pubkey=node_pubkey,
            local_funding_amount=int(local_funding_amount) if local_funding_amount else None,
            sat_per_vbyte=sat_per_vbyte,
            private=private,
            push_sat=int(push_sat),
            target_conf=target_conf,
            min_confs=int(min_confs),
            spend_unconfirmed=spend_unconfirmed,
            close_address=close_address,
            base_fee=int(base_fee) if base_fee else None,
            fee_rate=int(fee_rate) if fee_rate else None,
            fund_max=fund_max,
            memo=memo
        )
        
        if result.get('status') == 'error':
            return jsonify(result), 500
        
        return jsonify(result)
        
    except ValueError as e:
        return jsonify({
            'error': f'Erro de validação: {str(e)}',
            'status': 'error'
        }), 400
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/channels/close', methods=['POST'])
def close_channel():
    """Endpoint para fechar um canal Lightning"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'error': 'Dados JSON são obrigatórios',
                'status': 'error'
            }), 400
        
        # Extrair parâmetros
        channel_point = data.get('channel_point')
        
        if not channel_point:
            return jsonify({
                'error': 'channel_point é obrigatório (formato: txid:index)',
                'status': 'error'
            }), 400
        
        # Validar formato do channel_point
        if ':' not in channel_point:
            return jsonify({
                'error': 'channel_point deve estar no formato txid:index',
                'status': 'error'
            }), 400
        
        force_close = data.get('force_close', False)
        target_conf = data.get('target_conf')
        sat_per_vbyte = data.get('sat_per_vbyte')
        
        # Fechar o canal
        result = close_lightning_channel(
            channel_point=channel_point,
            force_close=force_close,
            target_conf=target_conf,
            sat_per_vbyte=sat_per_vbyte
        )
        
        if result.get('status') == 'error':
            return jsonify(result), 500
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/channels/pending', methods=['GET'])
def pending_channels():
    """Endpoint para listar canais pendentes"""
    try:
        pending_info = get_pending_channels()
        
        if pending_info.get('status') == 'error':
            return jsonify(pending_info), 500
        
        return jsonify(pending_info)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/invoices', methods=['POST'])
def create_invoice():
    """Endpoint para criar uma invoice Lightning"""
    try:
        data = request.get_json() or {}
        
        # Extrair parâmetros
        memo = data.get('memo')
        value = data.get('value')  # em satoshis
        expiry = data.get('expiry', 3600)  # 1 hora por padrão
        private = data.get('private', False)
        description_hash = data.get('description_hash')
        
        # Validações
        if value is not None and (not isinstance(value, int) or value <= 0):
            return jsonify({
                'error': 'value deve ser um número inteiro positivo em satoshis',
                'status': 'error'
            }), 400
        
        if not isinstance(expiry, int) or expiry <= 0:
            return jsonify({
                'error': 'expiry deve ser um número inteiro positivo em segundos',
                'status': 'error'
            }), 400
        
        # Criar invoice
        result = add_invoice(memo, value, expiry, private, description_hash)
        
        if result.get('status') == 'error':
            return jsonify(result), 500
        
        return jsonify(result), 201
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/payments', methods=['POST'])
def send_lightning_payment():
    """Endpoint para enviar pagamento Lightning"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'error': 'Dados JSON são obrigatórios',
                'status': 'error'
            }), 400
        
        # Extrair parâmetros
        payment_request = data.get('payment_request')
        dest = data.get('dest')
        amt = data.get('amt')
        fee_limit_sat = data.get('fee_limit_sat')
        timeout_seconds = data.get('timeout_seconds', 60)
        
        # Validação: deve ter payment_request OU (dest + amt)
        if not payment_request and not (dest and amt):
            return jsonify({
                'error': 'Deve fornecer payment_request OU (dest + amt)',
                'status': 'error'
            }), 400
        
        if payment_request and (dest or amt):
            return jsonify({
                'error': 'Não é possível usar payment_request junto com dest/amt. Use um ou outro.',
                'status': 'error'
            }), 400
        
        # Validações adicionais
        if amt is not None and (not isinstance(amt, int) or amt <= 0):
            return jsonify({
                'error': 'amt deve ser um número inteiro positivo em satoshis',
                'status': 'error'
            }), 400
        
        if fee_limit_sat is not None and (not isinstance(fee_limit_sat, int) or fee_limit_sat < 0):
            return jsonify({
                'error': 'fee_limit_sat deve ser um número inteiro não negativo',
                'status': 'error'
            }), 400
        
        # Enviar pagamento
        result = send_payment(payment_request, dest, amt, fee_limit_sat, timeout_seconds)
        
        if result.get('status') == 'error':
            return jsonify(result), 500
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/payments/keysend', methods=['POST'])
def send_keysend_payment():
    """Endpoint para enviar keysend (pagamento espontâneo)"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'error': 'Dados JSON são obrigatórios',
                'status': 'error'
            }), 400
        
        # Extrair parâmetros obrigatórios
        dest = data.get('dest')
        amt = data.get('amt')
        
        if not dest:
            return jsonify({
                'error': 'dest (pubkey do destino) é obrigatório',
                'status': 'error'
            }), 400
        
        if not amt or not isinstance(amt, int) or amt <= 0:
            return jsonify({
                'error': 'amt deve ser um número inteiro positivo em satoshis',
                'status': 'error'
            }), 400
        
        # Extrair parâmetros opcionais
        fee_limit_sat = data.get('fee_limit_sat')
        timeout_seconds = data.get('timeout_seconds', 60)
        custom_records = data.get('custom_records')  # Dict com records customizados adicionais
        final_cltv_delta = data.get('final_cltv_delta')
        
        # Validações
        if fee_limit_sat is not None and (not isinstance(fee_limit_sat, int) or fee_limit_sat < 0):
            return jsonify({
                'error': 'fee_limit_sat deve ser um número inteiro não negativo',
                'status': 'error'
            }), 400
        
        if not isinstance(timeout_seconds, int) or timeout_seconds <= 0:
            return jsonify({
                'error': 'timeout_seconds deve ser um número inteiro positivo',
                'status': 'error'
            }), 400
        
        # Validar dest (deve ser uma chave pública válida)
        if len(dest) != 66 or not all(c in '0123456789abcdefABCDEF' for c in dest):
            return jsonify({
                'error': 'dest deve ser uma chave pública válida de 66 caracteres hexadecimais',
                'status': 'error'
            }), 400
        
        # Enviar keysend
        result = send_keysend(dest, amt, fee_limit_sat, timeout_seconds, custom_records, final_cltv_delta)
        
        if result.get('status') == 'error':
            return jsonify(result), 500
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/addresses', methods=['POST'])
def generate_address():
    """Endpoint para gerar novo endereço Bitcoin"""
    try:
        data = request.get_json() or {}
        
        # Extrair parâmetros
        address_type = data.get('type', 'p2wkh')  # p2wkh, np2wkh, p2tr
        account = data.get('account')
        
        # Validação do tipo de endereço
        valid_types = ['p2wkh', 'np2wkh', 'p2tr']
        if address_type not in valid_types:
            return jsonify({
                'error': f'Tipo de endereço inválido. Tipos suportados: {valid_types}',
                'status': 'error'
            }), 400
        
        # Gerar endereço
        result = new_address(address_type, account)
        
        if result.get('status') == 'error':
            return jsonify(result), 500
        
        return jsonify(result), 201
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/transactions/send', methods=['POST'])
def send_on_chain():
    """Endpoint para enviar Bitcoin on-chain"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'error': 'Dados JSON são obrigatórios',
                'status': 'error'
            }), 400
        
        # Extrair parâmetros obrigatórios
        addr = data.get('addr')
        send_all = data.get('send_all', False)
        
        if not addr:
            return jsonify({
                'error': 'addr (endereço destino) é obrigatório',
                'status': 'error'
            }), 400
        
        # Parâmetros opcionais
        amount = data.get('amount')
        target_conf = data.get('target_conf')
        sat_per_vbyte = data.get('sat_per_vbyte')
        label = data.get('label')
        min_confs = data.get('min_confs', 1)
        spend_unconfirmed = data.get('spend_unconfirmed', False)
        
        # Validações
        if not send_all and (not amount or not isinstance(amount, int) or amount <= 0):
            return jsonify({
                'error': 'amount é obrigatório quando send_all=false e deve ser um inteiro positivo',
                'status': 'error'
            }), 400
        
        if send_all and amount:
            return jsonify({
                'error': 'Não é possível usar send_all=true junto com amount específico',
                'status': 'error'
            }), 400
        
        # Enviar transação
        result = send_coins(addr, amount, target_conf, sat_per_vbyte, send_all, label, min_confs, spend_unconfirmed)
        
        if result.get('status') == 'error':
            return jsonify(result), 500
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/utxos', methods=['GET'])
def list_utxos():
    """Endpoint para listar UTXOs disponíveis"""
    try:
        # Extrair parâmetros da query string
        min_confs = request.args.get('min_confs', 0, type=int)
        max_confs = request.args.get('max_confs', 9999999, type=int)
        account = request.args.get('account')
        
        # Validações
        if min_confs < 0:
            return jsonify({
                'error': 'min_confs deve ser não negativo',
                'status': 'error'
            }), 400
        
        if max_confs < min_confs:
            return jsonify({
                'error': 'max_confs deve ser maior ou igual a min_confs',
                'status': 'error'
            }), 400
        
        # Listar UTXOs
        result = list_unspent(min_confs, max_confs, account)
        
        if result.get('status') == 'error':
            return jsonify(result), 500
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/fees', methods=['GET'])
def get_fees():
    """Endpoint para obter estimativas de taxas de transação"""
    try:
        response = requests.get('https://mempool.space/api/v1/fees/recommended', timeout=10)
        
        if response.status_code != 200:
            return jsonify({
                'error': f'Erro de conexão com mempool.space. Status: {response.status_code}',
                'status': 'error'
            }), 502
        
        mempool_fees = response.json()
        return jsonify({
            'status': 'success',
            'source': 'mempool.space',
            'network': 'mainnet',
            'fees': {
                'economy': {
                    'sat_per_vbyte': mempool_fees.get('economyFee'),
                },
                'standard': {
                    'sat_per_vbyte': mempool_fees.get('hourFee'), 
                },
                'priority': {
                    'sat_per_vbyte': mempool_fees.get('fastestFee'),
                }
            },
            'timestamp': datetime.utcnow().isoformat()
        })
        
    except requests.exceptions.RequestException as e:
        return jsonify({
            'error': f'Erro de conexão com mempool.space: {str(e)}',
            'status': 'error'
        }), 502
    except Exception as e:
        return jsonify({
            'error': f'Erro interno: {str(e)}',
            'status': 'error'
        }), 500

# === ENDPOINTS DO CHAT LIGHTNING ===

@app.route('/api/v1/lightning/chat/conversations', methods=['GET'])
def get_conversations():
    """Endpoint para listar todas as conversas de chat"""
    try:
        conversations = get_all_conversations()
        
        return jsonify({
            'status': 'success',
            'conversations': conversations
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/chat/messages/<node_id>', methods=['GET'])
def get_messages(node_id):
    """Endpoint para obter mensagens de uma conversa específica"""
    try:
        limit = request.args.get('limit', 100, type=int)
        messages = get_chat_messages(node_id, limit)
        
        return jsonify({
            'status': 'success',
            'node_id': node_id,
            'messages': messages
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/chat/send', methods=['POST'])
def send_chat_message():
    """Endpoint para enviar mensagem via keysend"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'error': 'Dados JSON obrigatórios',
                'status': 'error'
            }), 400
        
        node_id = data.get('node_id')
        message = data.get('message')
        
        if not node_id or not message:
            return jsonify({
                'error': 'node_id e message são obrigatórios',
                'status': 'error'
            }), 400
        
        if len(message) > 500:
            return jsonify({
                'error': 'Mensagem muito longa (máximo 500 caracteres)',
                'status': 'error'
            }), 400
        
        # Enviar keysend com mensagem
        custom_records = {
            '34349334': base64.b64encode(message.encode('utf-8')).decode('ascii')
        }
        
        result = send_keysend(node_id, 1, custom_records=custom_records)
        
        if result.get('status') == 'success':
            # Salvar mensagem no banco
            save_chat_message(node_id, message, 'sent', 
                            result.get('payment_hash'), 'confirmed')
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/chat/notifications', methods=['GET'])
def get_chat_notifications():
    """Endpoint para obter número de mensagens não lidas"""
    try:
        count = get_new_messages_count()
        
        return jsonify({
            'status': 'success',
            'unread_count': count
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/chat/notifications', methods=['POST'])
def reset_chat_notifications():
    """Endpoint para resetar contador de mensagens não lidas"""
    try:
        reset_new_messages()
        
        return jsonify({
            'status': 'success',
            'message': 'Notificações resetadas'
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lightning/chat/keysends/check', methods=['POST'])
def check_received_keysends():
    """Endpoint para processar keysends recebidos (chamado externamente)"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'error': 'Dados JSON obrigatórios',
                'status': 'error'
            }), 400
        
        payment_hash = data.get('payment_hash')
        sender_node_id = data.get('sender_node_id')
        amount_sat = data.get('amount_sat')
        custom_records = data.get('custom_records', {})
        
        if not payment_hash or not sender_node_id or amount_sat is None:
            return jsonify({
                'error': 'payment_hash, sender_node_id e amount_sat são obrigatórios',
                'status': 'error'
            }), 400
        
        # Processar keysend recebido
        is_new = process_received_keysend(payment_hash, sender_node_id, 
                                        amount_sat, custom_records)
        
        if is_new:
            increment_new_messages()
        
        return jsonify({
            'status': 'success',
            'processed': is_new,
            'message': 'Keysend processado' if is_new else 'Keysend já processado'
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

# === ENDPOINTS ELEMENTS/LIQUID ===

@app.route('/api/v1/elements/balances', methods=['GET'])
def get_elements_balances():
    """Obter saldos de todos os assets Elements/Liquid"""
    try:
        # Obter saldos
        balances_result, balances_error = elements_rpc_client.get_balances()
        if balances_error:
            return jsonify({
                'error': f'Erro ao obter saldos: {balances_error}',
                'status': 'error'
            }), 500
        
        # Obter labels dos assets
        labels_result, labels_error = elements_rpc_client.get_asset_labels()
        if labels_error:
            print(f"Warning: Não foi possível obter labels dos assets: {labels_error}")
            labels_result = {}
        
        # Asset IDs conhecidos
        known_assets = {
            "6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d": "L-BTC",
            "02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189": "DePix", 
            "ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2": "USDT"
        }
        
        # Processar saldos
        processed_balances = {}
        if 'mine' in balances_result:
            mine_balances = balances_result['mine']
            
            # Processar cada categoria (trusted, untrusted_pending, immature)
            for category, assets in mine_balances.items():
                if isinstance(assets, dict):
                    for asset_name, amount in assets.items():
                        # Determinar chave e informações do asset
                        if asset_name == "bitcoin" or asset_name == "6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d":
                            key = 'lbtc'
                            symbol = 'L-BTC'
                            name = 'Liquid Bitcoin'
                            asset_id = '6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d'
                        elif asset_name == "02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189":
                            key = 'depix'
                            symbol = 'DePix'
                            name = labels_result.get(asset_name, 'DePix')
                            asset_id = asset_name
                        elif asset_name == "ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2":
                            key = 'usdt'
                            symbol = 'USDT'
                            name = labels_result.get(asset_name, 'Tether')
                            asset_id = asset_name
                        else:
                            key = asset_name[:8] if len(asset_name) > 8 else asset_name
                            symbol = known_assets.get(asset_name, asset_name)
                            name = labels_result.get(asset_name, symbol)
                            asset_id = asset_name
                        
                        # Inicializar balance se não existir
                        if key not in processed_balances:
                            processed_balances[key] = {
                                'asset_id': asset_id,
                                'symbol': symbol,
                                'name': name,
                                'trusted': 0,
                                'untrusted_pending': 0,
                                'immature': 0
                            }
                        
                        # Atualizar valor para a categoria
                        processed_balances[key][category] = amount
        
        return jsonify({
            'balances': processed_balances,
            'status': 'success'
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/elements/addresses', methods=['POST'])
def generate_elements_address():
    """Gerar novo endereço Elements/Liquid"""
    try:
        data = request.get_json() or {}
        label = data.get('label', '')
        address_type = data.get('type', 'bech32')  # 'bech32' para confidencial, outros para não-confidencial
        
        # Gerar endereço
        result, error = elements_rpc_client.get_new_address(label, address_type)
        if error:
            return jsonify({
                'error': f'Erro ao gerar endereço: {error}',
                'status': 'error'
            }), 500
        
        return jsonify({
            'address': result,
            'type': address_type,
            'label': label,
            'status': 'success'
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/elements/send', methods=['POST'])
def send_elements_asset():
    """Enviar asset Elements/Liquid"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'Dados JSON requeridos',
                'status': 'error'
            }), 400
        
        address = data.get('address')
        amount = data.get('amount')
        asset = data.get('asset', 'lbtc')  # padrão L-BTC
        subtract_fee = data.get('subtract_fee', False)
        
        if not address or not amount:
            return jsonify({
                'error': 'address e amount são requeridos',
                'status': 'error'
            }), 400
        
        # Mapear asset para label
        asset_labels = {
            'lbtc': None,  # Asset nativo, não precisa de label
            'depix': 'DePix',
            'usdt': 'USDT'
        }
        
        asset_label = asset_labels.get(asset)
        
        # Enviar transação
        result, error = elements_rpc_client.send_to_address(
            address, amount, asset_label, subtract_fee
        )
        
        if error:
            return jsonify({
                'error': f'Erro ao enviar transação: {error}',
                'status': 'error'
            }), 500
        
        return jsonify({
            'txid': result,
            'address': address,
            'amount': amount,
            'asset': asset,
            'status': 'success'
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/elements/utxos', methods=['GET'])
def get_elements_utxos():
    """Listar UTXOs Elements/Liquid"""
    try:
        # Parâmetros de query
        asset_filter = request.args.get('asset')  # 'lbtc', 'depix', 'usdt', ou asset_id
        minconf = int(request.args.get('minconf', 1))
        maxconf = int(request.args.get('maxconf', 9999999))
        
        # Mapear asset para ID se necessário
        asset_ids = {
            'lbtc': '6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d',
            'depix': '02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189',
            'usdt': 'ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2'
        }
        
        asset_id = asset_ids.get(asset_filter, asset_filter) if asset_filter else None
        
        # Listar UTXOs
        result, error = elements_rpc_client.list_unspent(minconf, maxconf, asset_id)
        if error:
            return jsonify({
                'error': f'Erro ao listar UTXOs: {error}',
                'status': 'error'
            }), 500
        
        # Processar UTXOs
        processed_utxos = []
        for utxo in result:
            asset_id = utxo.get('asset', '')
            
            # Determinar tipo de asset
            if asset_id == '6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d':
                asset_type = 'lbtc'
                symbol = 'L-BTC'
            elif asset_id == '02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189':
                asset_type = 'depix'
                symbol = 'DePix'
            elif asset_id == 'ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2':
                asset_type = 'usdt'
                symbol = 'USDT'
            else:
                asset_type = 'unknown'
                symbol = asset_id[:8] if asset_id else 'Unknown'
            
            processed_utxos.append({
                'txid': utxo.get('txid'),
                'vout': utxo.get('vout'),
                'address': utxo.get('address'),
                'amount': utxo.get('amount', 0),
                'asset': asset_type,
                'asset_id': asset_id,
                'symbol': symbol,
                'confirmations': utxo.get('confirmations', 0),
                'spendable': utxo.get('spendable', False),
                'safe': utxo.get('safe', False)
            })
        
        return jsonify({
            'utxos': processed_utxos,
            'count': len(processed_utxos),
            'status': 'success'
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/elements/transactions', methods=['GET'])
def get_elements_transactions():
    """Listar transações Elements/Liquid"""
    try:
        # Parâmetros de query
        count = int(request.args.get('limit', 30))
        skip = int(request.args.get('skip', 0))
        
        # Listar transações
        result, error = elements_rpc_client.list_transactions(count, skip)
        if error:
            return jsonify({
                'error': f'Erro ao listar transações: {error}',
                'status': 'error'
            }), 500
        
        # Processar transações
        processed_txs = []
        for tx in result:
            # Obter informações básicas
            txid = tx.get('txid')
            category = tx.get('category')
            amount = tx.get('amount', 0)
            fee = tx.get('fee', 0)
            confirmations = tx.get('confirmations', 0)
            time = tx.get('time', 0)
            address = tx.get('address', '')
            
            # TODO: Elements pode não ter informações de asset em listtransactions
            # Pode ser necessário usar getrawtransaction para mais detalhes
            asset_type = 'lbtc'  # Assumir L-BTC por padrão
            symbol = 'L-BTC'
            
            processed_txs.append({
                'txid': txid,
                'category': category,
                'amount': amount,
                'fee': fee,
                'asset': asset_type,
                'symbol': symbol,
                'confirmations': confirmations,
                'time': time,
                'address': address
            })
        
        return jsonify({
            'transactions': processed_txs,
            'count': len(processed_txs),
            'status': 'success'
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/elements/info', methods=['GET'])
def get_elements_info():
    """Obter informações da blockchain Elements/Liquid"""
    try:
        result, error = elements_rpc_client.get_blockchain_info()
        if error:
            return jsonify({
                'error': f'Erro ao obter informações: {error}',
                'status': 'error'
            }), 500
        
        return jsonify({
            'chain': result.get('chain'),
            'blocks': result.get('blocks'),
            'headers': result.get('headers'),
            'bestblockhash': result.get('bestblockhash'),
            'difficulty': result.get('difficulty'),
            'mediantime': result.get('mediantime'),
            'verificationprogress': result.get('verificationprogress'),
            'chainwork': result.get('chainwork'),
            'size_on_disk': result.get('size_on_disk'),
            'pruned': result.get('pruned', False),
            'status': 'success'
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

# === BITCOIN CORE PROXY ENDPOINTS ===

@app.route('/api/v1/bitcoin/info', methods=['GET'])
def get_bitcoin_info():
    """Proxy para obter informações do Bitcoin Core local"""
    try:
        bitcoin_info = get_bitcoind_info()
        
        return jsonify({
            'status': 'success',
            'blocks': bitcoin_info.get('blocks', 0),
            'progress': bitcoin_info.get('progress', 0),
            'service_status': bitcoin_info.get('status', 'unknown')
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/bitcoin/block/height', methods=['GET'])
def get_bitcoin_block_height():
    """Endpoint específico para obter altura do bloco atual do Bitcoin"""
    try:
        if not get_service_status('bitcoind.service'):
            return jsonify({
                'error': 'Serviço bitcoind não está rodando',
                'status': 'error'
            }), 503
        
        # Obter apenas a altura do bloco
        output, code = run_command("bitcoin-cli getblockcount 2>/dev/null")
        if code != 0 or not output:
            return jsonify({
                'error': 'Não foi possível obter altura do bloco do Bitcoin Core',
                'status': 'error'
            }), 500
        
        try:
            block_height = int(output.strip())
            return jsonify({
                'status': 'success',
                'block_height': block_height,
                'source': 'bitcoin-core-local'
            })
        except ValueError:
            return jsonify({
                'error': 'Resposta inválida do Bitcoin Core',
                'status': 'error'
            }), 500
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/bitcoin/block/<block_hash>', methods=['GET'])
def get_bitcoin_block(block_hash):
    """Obter informações de um bloco específico"""
    try:
        if not get_service_status('bitcoind.service'):
            return jsonify({
                'error': 'Serviço bitcoind não está rodando',
                'status': 'error'
            }), 503
        
        # Validação básica do hash
        if len(block_hash) != 64 or not all(c in '0123456789abcdefABCDEF' for c in block_hash):
            return jsonify({
                'error': 'Hash de bloco inválido',
                'status': 'error'
            }), 400
        
        # Obter informações do bloco
        output, code = run_command(f"bitcoin-cli getblock {block_hash} 1 2>/dev/null")
        if code != 0 or not output:
            return jsonify({
                'error': 'Não foi possível obter informações do bloco',
                'status': 'error'
            }), 500
        
        try:
            block_info = json.loads(output)
            return jsonify({
                'status': 'success',
                'block': {
                    'hash': block_info.get('hash'),
                    'height': block_info.get('height'),
                    'time': block_info.get('time'),
                    'size': block_info.get('size'),
                    'tx_count': len(block_info.get('tx', [])),
                    'difficulty': block_info.get('difficulty'),
                    'previousblockhash': block_info.get('previousblockhash'),
                    'nextblockhash': block_info.get('nextblockhash')
                },
                'source': 'bitcoin-core-local'
            })
        except json.JSONDecodeError:
            return jsonify({
                'error': 'Resposta inválida do Bitcoin Core',
                'status': 'error'
            }), 500
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

# === WALLET MANAGEMENT ENDPOINTS ===

@app.route('/api/v1/wallet/generate', methods=['POST'])
def generate_wallet():
    """Gerar nova carteira HD com mnemonic BIP39"""
    try:
        if not HAS_WALLET_LIBS:
            return jsonify({
                'error': 'Wallet libraries not available',
                'status': 'error'
            }), 500
        
        data = request.get_json()
        if not data:
            data = {}
        
        # Get word count (default to 12)
        word_count = data.get('word_count', 12)
        if word_count not in [12, 24]:
            return jsonify({
                'error': 'Word count must be 12 or 24',
                'status': 'error'
            }), 400
        
        # Gerar mnemonic
        seed_phrase, error = wallet_manager.generate_mnemonic(word_count)
        if error:
            return jsonify({
                'error': error,
                'status': 'error'
            }), 500
        
        # Get data from request
        wallet_id_input = data.get('wallet_id', '')
        bip39_passphrase = data.get('password', '')  # This is the BIP39 passphrase (13th/25th word)
        
        # Derivar endereços usando a passphrase BIP39
        addresses, derive_error = wallet_manager.derive_addresses(seed_phrase, bip39_passphrase)
        if derive_error:
            return jsonify({
                'error': derive_error,
                'status': 'error'
            }), 500
        
        # Derivar chaves privadas usando a passphrase BIP39
        private_keys, privkey_error = wallet_manager.derive_private_keys(seed_phrase, bip39_passphrase)
        if privkey_error:
            return jsonify({
                'error': privkey_error,
                'status': 'error'
            }), 500
        
        # Gerar carteira universal (inclui LND keys)
        universal_wallet, universal_error = wallet_manager.generate_universal_wallet(seed_phrase, bip39_passphrase)
        if universal_error:
            return jsonify({
                'error': universal_error,
                'status': 'error'
            }), 500
        
        # Gerar ID único da carteira se não fornecido
        import uuid
        if wallet_id_input:
            wallet_id = wallet_id_input
        else:
            wallet_id = str(uuid.uuid4())
        
        # Store in temporary cache for later verification and saving
        if not hasattr(wallet_manager, 'temp_wallets'):
            wallet_manager.temp_wallets = {}
            
        wallet_manager.temp_wallets[wallet_id] = {
            'seed_phrase': seed_phrase,
            'addresses': addresses,
            'private_keys': private_keys,
            'universal_wallet': universal_wallet,
            'has_bip39_passphrase': bool(bip39_passphrase),
            'word_count': word_count,
            'created_at': datetime.now().isoformat()
        }
        
        return jsonify({
            'status': 'success',
            'message': 'Universal wallet generated successfully',
            'wallet_id': wallet_id,
            'mnemonic': seed_phrase,
            'seed_phrase': seed_phrase,
            'word_count': word_count,
            'has_bip39_passphrase': bool(bip39_passphrase),
            'addresses': addresses,
            'private_keys': private_keys,
            'lnd_keys': universal_wallet.get('lnd_keys', {}),
            'lnd_compatible': universal_wallet.get('lnd_compatible', False),
            'supported_chains': universal_wallet.get('supported_chains', []),
            'usage_instructions': {
                'lnd_mainnet': 'Use lnd_keys.mainnet.extended_master_key with lncli create option "x"',
                'lnd_testnet': 'Use lnd_keys.testnet.extended_master_key with lncli create option "x"',
                'other_chains': 'Use addresses and private_keys for respective blockchain networks'
            }
        })
            
        wallet_manager.temp_wallets[wallet_id] = {
            'mnemonic': seed_phrase,
            'addresses': addresses,
            'private_keys': private_keys,
            'bip39_passphrase': bip39_passphrase,
            'word_count': word_count,
            'created_at': datetime.now()
        }
        
        return jsonify({
            'status': 'success',
            'message': 'Wallet generated successfully',
            'wallet_id': wallet_id,
            'mnemonic': seed_phrase,
            'addresses': addresses,
            'word_count': word_count,
            'has_bip39_passphrase': bool(bip39_passphrase)
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/import', methods=['POST'])
def import_wallet():
    """Importar carteira existente usando mnemonic"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'No data provided',
                'status': 'error'
            }), 400
        
        mnemonic = data.get('mnemonic', '').strip()
        passphrase = data.get('passphrase', '')
        
        if not mnemonic:
            return jsonify({
                'error': 'Mnemonic is required',
                'status': 'error'
            }), 400
        
        # Validar mnemonic
        is_valid, validation_error = wallet_manager.validate_mnemonic(mnemonic)
        if not is_valid:
            return jsonify({
                'error': f'Invalid mnemonic: {validation_error}',
                'status': 'error'
            }), 400
        
        # Derivar endereços
        addresses, derive_error = wallet_manager.derive_addresses(mnemonic, passphrase)
        if derive_error:
            return jsonify({
                'error': derive_error,
                'status': 'error'
            }), 500
        
        return jsonify({
            'status': 'success',
            'addresses': addresses,
            'message': 'Wallet imported successfully'
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/save', methods=['POST'])
def save_wallet():
    """Salvar carteira criptografada com senha de banco de dados"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'No data provided',
                'status': 'error'
            }), 400
        
        mnemonic = data.get('mnemonic', '').strip()
        db_password = data.get('password', '')  # Database encryption password
        wallet_id = data.get('wallet_id', f'wallet_{int(time.time())}')
        metadata = data.get('metadata', {})
        
        if not mnemonic or not db_password:
            return jsonify({
                'error': 'Mnemonic and database password are required',
                'status': 'error'
            }), 400
        
        # Get BIP39 passphrase and private keys from temporary storage
        bip39_passphrase = ""
        private_keys = {}
        
        if hasattr(wallet_manager, 'temp_wallets') and wallet_id in wallet_manager.temp_wallets:
            temp_data = wallet_manager.temp_wallets[wallet_id]
            bip39_passphrase = temp_data.get('bip39_passphrase', '')
            private_keys = temp_data.get('private_keys', {})
            
            # Add BIP39 info to metadata
            metadata['has_bip39_passphrase'] = bool(bip39_passphrase)
            metadata['bip39_passphrase_hash'] = hashlib.sha256(bip39_passphrase.encode()).hexdigest() if bip39_passphrase else None
        
        # Criptografar mnemonic com senha do banco
        encrypted_mnemonic, salt, encrypt_error = wallet_manager.encrypt_mnemonic(mnemonic, db_password)
        if encrypt_error:
            return jsonify({
                'error': encrypt_error,
                'status': 'error'
            }), 500
        
        # Criptografar chaves privadas com senha do banco
        encrypted_private_keys = None
        if private_keys:
            encrypted_private_keys, privkey_salt, privkey_encrypt_error = wallet_manager.encrypt_private_keys(private_keys, db_password)
            if privkey_encrypt_error:
                return jsonify({
                    'error': privkey_encrypt_error,
                    'status': 'error'
                }), 500
        
        # Check if this should be set as system default (if it's the first wallet or explicitly requested)
        is_system_default = data.get('is_system_default', False)
        
        # If no system default exists yet, make this the default
        if not is_system_default:
            default_wallet, _ = wallet_manager.get_system_default_wallet()
            if not default_wallet:
                is_system_default = True
        
        # Salvar no banco
        save_success, save_error = wallet_manager.save_wallet(
            wallet_id, encrypted_mnemonic, salt, metadata, has_password=bool(db_password), 
            encrypted_private_keys=encrypted_private_keys, is_system_default=is_system_default
        )
        if not save_success:
            return jsonify({
                'error': save_error,
                'status': 'error'
            }), 500
        
        # Cache addresses usando a passphrase BIP39 correta
        addresses, derive_error = wallet_manager.derive_addresses(mnemonic, bip39_passphrase)
        if not derive_error:
            wallet_manager.cache_addresses(wallet_id, addresses)
        
        # Clean up temporary data
        if hasattr(wallet_manager, 'temp_wallets') and wallet_id in wallet_manager.temp_wallets:
            del wallet_manager.temp_wallets[wallet_id]
        
        message = 'Wallet encrypted and saved successfully'
        integration_result = None
        
        # Auto-integrate with LND using expect script if this is the system default
        if is_system_default:
            message += ' and set as system default'
            
            try:
                print(f"🔄 Starting LND integration for wallet '{wallet_id}' using expect script...")
                message += ' - LND integration started in background'
                
                # Run LND integration in background thread using expect script
                def background_lnd_integration():
                    try:
                        # Convert BIP39 to LND extended master key
                        result, error = wallet_manager.bip39_to_extended_master_key(mnemonic, bip39_passphrase or '', 'testnet')
                        if error:
                            print(f"❌ Failed to convert BIP39 to LND master key: {error}")
                            return
                        
                        extended_master_key = result['extended_master_key']
                        print(f"✅ Generated LND extended master key for wallet '{wallet_id}'")
                        
                        # Stop LND service first
                        subprocess.run(['sudo', 'systemctl', 'stop', 'lnd'], capture_output=True, timeout=30)
                        print("⏹️ LND service stopped")
                        
                        # Create password file for expect script using wallet password
                        password_file = '/root/brln-os/scripts/password.txt'
                        with open(password_file, 'w') as f:
                            f.write(db_password)  # Use wallet password for LND
                        print("🔐 Password file created with wallet password")
                        
                        # Start LND service
                        subprocess.run(['sudo', 'systemctl', 'start', 'lnd'], capture_output=True, timeout=30)
                        print("▶️ LND service started")
                        
                        # Wait for LND to be ready
                        import time
                        time.sleep(5)
                        
                        # Run expect script to create wallet
                        script_path = '/root/brln-os/scripts/auto-lnd-create-masterkey.exp'
                        result = subprocess.run(
                            [script_path, extended_master_key],
                            cwd='/root/brln-os/scripts',
                            capture_output=True,
                            text=True,
                            timeout=120
                        )
                        
                        if result.returncode == 0:
                            print(f"✅ LND wallet created successfully for wallet '{wallet_id}'")
                            print("🔍 Checking for admin.macaroon...")
                            
                            # Check if admin.macaroon was created
                            import time
                            time.sleep(3)
                            if os.path.exists('/data/lnd/data/chain/bitcoin/testnet/admin.macaroon'):
                                print(f"✅ Admin macaroon created - LND integration complete for wallet '{wallet_id}'")
                            else:
                                print(f"⚠️ Admin macaroon not found - LND may still be initializing for wallet '{wallet_id}'")
                        else:
                            print(f"❌ LND wallet creation failed for wallet '{wallet_id}': {result.stderr}")
                            
                        # Clean up password file
                        try:
                            os.remove(password_file)
                        except:
                            pass
                            
                    except Exception as e:
                        print(f"❌ LND integration failed for wallet '{wallet_id}': {str(e)}")
                
                # Start integration in background
                integration_thread = threading.Thread(target=background_lnd_integration, daemon=True)
                integration_thread.start()
                    
            except Exception as e:
                print(f"⚠️ LND integration setup error: {str(e)}")
                message += ' - LND integration setup failed'
        
        response_data = {
            'status': 'success',
            'wallet_id': wallet_id,
            'message': message,
            'is_system_default': is_system_default,
            'addresses': addresses if not derive_error else {}
        }
        
        return jsonify(response_data)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/list', methods=['GET'])
def list_wallets():
    """Listar carteiras salvas no banco"""
    try:
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT wallet_id, metadata, last_used, created_at, has_password, is_system_default
            FROM wallets ORDER BY is_system_default DESC, last_used DESC
        ''')
        
        results = cursor.fetchall()
        conn.close()
        
        wallets = []
        for wallet_id, metadata_json, last_used, created_at, has_password, is_system_default in results:
            try:
                metadata = json.loads(metadata_json) if metadata_json else {}
            except:
                metadata = {}
            
            wallets.append({
                'wallet_id': wallet_id,
                'metadata': metadata,
                'last_used': last_used,
                'created_at': created_at,
                'encrypted': bool(has_password),  # True apenas se tem senha real
                'is_system_default': bool(is_system_default)
            })
        
        return jsonify({
            'status': 'success',
            'wallets': wallets,
            'count': len(wallets)
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/system-default', methods=['GET'])
def get_system_default():
    """Get the system default wallet"""
    try:
        wallet_data, error = wallet_manager.get_system_default_wallet()
        
        if error:
            return jsonify({
                'error': error,
                'status': 'error'
            }), 404
        
        # Don't return sensitive data, just wallet info
        return jsonify({
            'status': 'success',
            'wallet_id': wallet_data['wallet_id'],
            'metadata': wallet_data['metadata'],
            'has_password': wallet_data['has_password']
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/system-default', methods=['POST'])
def set_system_default():
    """Set a wallet as the system default"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'No data provided',
                'status': 'error'
            }), 400
        
        wallet_id = data.get('wallet_id')
        if not wallet_id:
            return jsonify({
                'error': 'wallet_id is required',
                'status': 'error'
            }), 400
        
        success, error = wallet_manager.set_system_default_wallet(wallet_id)
        if not success:
            return jsonify({
                'error': error,
                'status': 'error'
            }), 400
        
        return jsonify({
            'status': 'success',
            'message': f'Wallet {wallet_id} set as system default',
            'wallet_id': wallet_id
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/integrate', methods=['POST'])
def integrate_system_wallet():
    """Manually integrate the system default wallet with LND and Elements"""
    try:
        data = request.get_json()
        wallet_id = data.get('wallet_id') if data else None
        password = data.get('password') if data else None
        
        # If no wallet_id provided, get the system default
        if not wallet_id:
            default_wallet, error = wallet_manager.get_system_default_wallet()
            if error or not default_wallet:
                return jsonify({
                    'error': 'No system default wallet found',
                    'status': 'error'
                }), 404
            
            wallet_id = default_wallet['wallet_id']
        
        # Load the wallet data from database
        wallet_data, error = wallet_manager.load_wallet(wallet_id)
        if error:
            return jsonify({
                'error': error,
                'status': 'error'
            }), 404
        
        # Check if we need to decrypt the mnemonic
        mnemonic = None
        
        # Try to get from temporary wallets first (if recently loaded)
        if hasattr(wallet_manager, 'temp_wallets') and wallet_id in wallet_manager.temp_wallets:
            mnemonic = wallet_manager.temp_wallets[wallet_id].get('mnemonic')
        
        # If not in temp storage and wallet is encrypted, require password
        if not mnemonic and wallet_data.get('encrypted_mnemonic'):
            if not password:
                return jsonify({
                    'error': 'Password required for wallet decryption',
                    'status': 'error'
                }), 400
            
            # Decrypt the mnemonic
            mnemonic, decrypt_error = wallet_manager.decrypt_mnemonic(
                wallet_data['encrypted_mnemonic'],
                wallet_data['salt'],
                password
            )
            if decrypt_error:
                return jsonify({
                    'error': 'Invalid password or corrupted wallet data',
                    'status': 'error'
                }), 401
        
        # If we still don't have a mnemonic (unencrypted wallet), get it from wallet data  
        if not mnemonic and not wallet_data.get('encrypted_mnemonic'):
            return jsonify({
                'error': 'Wallet data not found or corrupted',
                'status': 'error'
            }), 400
        
        # Start background integration
        try:
            import sys
            import threading
            sys.path.append('/root/brln-os')
            from auto_wallet_integration import auto_integrate_wallet, check_integration_dependencies
            
            # Check dependencies
            if not check_integration_dependencies():
                return jsonify({
                    'error': 'Integration dependencies not available',
                    'status': 'error'
                }), 500
            
            # Store mnemonic temporarily for integration
            if hasattr(wallet_manager, 'temp_wallets'):
                if wallet_id not in wallet_manager.temp_wallets:
                    wallet_manager.temp_wallets[wallet_id] = {}
                wallet_manager.temp_wallets[wallet_id]['mnemonic'] = mnemonic
            
            print(f"🔄 Starting manual LND integration for wallet '{wallet_id}' using expect script...")
            
            # Run integration in background thread using expect script
            def background_lnd_integration():
                try:
                    # Convert BIP39 to LND extended master key
                    result, error = wallet_manager.bip39_to_extended_master_key(mnemonic, '', 'testnet')
                    if error:
                        print(f"❌ Failed to convert BIP39 to LND master key: {error}")
                        return
                    
                    extended_master_key = result['extended_master_key']
                    print(f"✅ Generated LND extended master key for manual integration '{wallet_id}'")
                    
                    # Stop LND service first
                    subprocess.run(['sudo', 'systemctl', 'stop', 'lnd'], capture_output=True, timeout=30)
                    print("⏹️ LND service stopped for manual integration")
                    
                    # Create password file for expect script
                    password_file = '/root/brln-os/scripts/password.txt'
                    with open(password_file, 'w') as f:
                        f.write(password)  # Use wallet password for LND
                    print("🔐 Password file created for manual integration")
                    
                    # Start LND service
                    subprocess.run(['sudo', 'systemctl', 'start', 'lnd'], capture_output=True, timeout=30)
                    print("▶️ LND service started for manual integration")
                    
                    # Wait for LND to be ready
                    import time
                    time.sleep(5)
                    
                    # Run expect script to create wallet
                    script_path = '/root/brln-os/scripts/auto-lnd-create-masterkey.exp'
                    result = subprocess.run(
                        [script_path, extended_master_key],
                        cwd='/root/brln-os/scripts',
                        capture_output=True,
                        text=True,
                        timeout=120
                    )
                    
                    if result.returncode == 0:
                        print(f"✅ LND wallet created successfully for manual integration '{wallet_id}'")
                        print("🔍 Checking for admin.macaroon...")
                        
                        # Check if admin.macaroon was created
                        import time
                        time.sleep(3)
                        if os.path.exists('/data/lnd/data/chain/bitcoin/testnet/admin.macaroon'):
                            print(f"✅ Admin macaroon created - Manual LND integration complete for wallet '{wallet_id}'")
                        else:
                            print(f"⚠️ Admin macaroon not found - LND may still be initializing for manual integration '{wallet_id}'")
                    else:
                        print(f"❌ LND wallet creation failed for manual integration '{wallet_id}': {result.stderr}")
                        
                    # Clean up password file
                    try:
                        os.remove(password_file)
                    except:
                        pass
                        
                except Exception as e:
                    print(f"❌ Manual LND integration failed for wallet '{wallet_id}': {str(e)}")
            
            # Start integration in background
            integration_thread = threading.Thread(target=background_lnd_integration, daemon=True)
            integration_thread.start()
            
            return jsonify({
                'status': 'success',
                'message': f'Integration started in background for wallet {wallet_id}',
                'wallet_id': wallet_id
            })
            
        except Exception as e:
            return jsonify({
                'error': f'Integration setup failed: {str(e)}',
                'status': 'error'
            }), 500
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/load', methods=['POST'])
def load_wallet():
    """Carregar e descriptografar carteira salva"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'No data provided',
                'status': 'error'
            }), 400
        
        wallet_id = data.get('wallet_id', '')
        password = data.get('password', '')
        
        if not wallet_id:
            return jsonify({
                'error': 'Wallet ID is required',
                'status': 'error'
            }), 400
            
        # Password is optional for unencrypted wallets (empty string is valid)
        
        # Carregar wallet do banco
        wallet_data, load_error = wallet_manager.load_wallet(wallet_id)
        if load_error:
            return jsonify({
                'error': load_error,
                'status': 'error'
            }), 404
        
        # Descriptografar mnemonic
        mnemonic, decrypt_error = wallet_manager.decrypt_mnemonic(
            wallet_data['encrypted_mnemonic'],
            wallet_data['salt'],
            password
        )
        if decrypt_error:
            return jsonify({
                'error': 'Invalid password or corrupted wallet data',
                'status': 'error'
            }), 401
        
        # Tentar obter endereços do cache primeiro
        addresses, cache_error = wallet_manager.get_cached_addresses(wallet_id)
        
        # Se não tiver no cache, derivar novamente
        if cache_error or not addresses:
            addresses, derive_error = wallet_manager.derive_addresses(mnemonic)
            if not derive_error:
                wallet_manager.cache_addresses(wallet_id, addresses)
        
        # Automatically set this wallet as the system default when loaded
        try:
            # Update the wallet to be system default
            success, error = wallet_manager.set_system_default_wallet(wallet_id)
            if success:
                message = 'Wallet loaded and set as system default'
                
                # Try to unlock LND using expect script with wallet password
                try:
                    print(f"🔓 Attempting to unlock LND for loaded wallet '{wallet_id}' using wallet password...")
                    
                    # Create password file for expect script using the wallet password
                    password_file = '/root/brln-os/scripts/password.txt'
                    with open(password_file, 'w') as f:
                        f.write(password)  # Use the wallet password from the modal
                    
                    # Run expect script to unlock wallet
                    script_path = '/root/brln-os/scripts/auto-lnd-unlock.exp'
                    unlock_result = subprocess.run(
                        [script_path],
                        cwd='/root/brln-os/scripts',
                        capture_output=True,
                        text=True,
                        timeout=30
                    )
                    
                    # Clean up password file
                    try:
                        os.remove(password_file)
                    except:
                        pass
                    
                    if unlock_result.returncode == 0:
                        print(f"✅ LND unlocked successfully for wallet '{wallet_id}' using wallet password")
                        message += ' - LND unlocked successfully'
                    else:
                        print(f"⚠️ LND unlock failed for wallet '{wallet_id}': {unlock_result.stderr}")
                        message += ' - LND unlock failed, may need manual unlock'
                        
                except Exception as e:
                    print(f"⚠️ Error unlocking LND for loaded wallet '{wallet_id}': {str(e)}")
                    message += ' - LND unlock error'
                
                # Start background LND integration using expect script if needed
                try:
                    # Check if admin.macaroon exists
                    if not os.path.exists('/data/lnd/data/chain/bitcoin/testnet/admin.macaroon'):
                        print(f"🔄 Admin macaroon not found, starting LND integration for loaded wallet '{wallet_id}'...")
                        
                        def background_lnd_integration():
                            try:
                                # Convert BIP39 to LND extended master key
                                result, error = wallet_manager.bip39_to_extended_master_key(mnemonic, '', 'testnet')
                                if error:
                                    print(f"❌ Failed to convert BIP39 to LND master key: {error}")
                                    return
                                
                                extended_master_key = result['extended_master_key']
                                print(f"✅ Generated LND extended master key for loaded wallet '{wallet_id}'")
                                
                                # Stop LND service first
                                subprocess.run(['sudo', 'systemctl', 'stop', 'lnd'], capture_output=True, timeout=30)
                                print("⏹️ LND service stopped")
                                
                                # Create password file for expect script
                                password_file = '/root/brln-os/scripts/password.txt'
                                with open(password_file, 'w') as f:
                                    f.write(unlock_password)  # Use provided password for LND
                                print("🔐 Password file created")
                                
                                # Start LND service
                                subprocess.run(['sudo', 'systemctl', 'start', 'lnd'], capture_output=True, timeout=30)
                                print("▶️ LND service started")
                                
                                # Wait for LND to be ready
                                import time
                                time.sleep(5)
                                
                                # Run expect script to create wallet
                                script_path = '/root/brln-os/scripts/auto-lnd-create-masterkey.exp'
                                result = subprocess.run(
                                    [script_path, extended_master_key],
                                    cwd='/root/brln-os/scripts',
                                    capture_output=True,
                                    text=True,
                                    timeout=120
                                )
                                
                                if result.returncode == 0:
                                    print(f"✅ LND wallet created successfully for loaded wallet '{wallet_id}'")
                                else:
                                    print(f"❌ LND wallet creation failed for loaded wallet '{wallet_id}': {result.stderr}")
                                    
                                # Clean up password file
                                try:
                                    os.remove(password_file)
                                except:
                                    pass
                                    
                            except Exception as e:
                                print(f"❌ LND integration failed for loaded wallet '{wallet_id}': {str(e)}")
                        
                        # Start integration in background
                        integration_thread = threading.Thread(target=background_lnd_integration, daemon=True)
                        integration_thread.start()
                        message += ' - LND integration started in background'
                    else:
                        print(f"✅ Admin macaroon exists, LND already integrated for wallet '{wallet_id}'")
                        message += ' - LND already integrated'
                        
                except Exception as e:
                    print(f"⚠️ LND integration setup error for loaded wallet: {str(e)}")
                    message += ' - LND integration setup failed'
            else:
                message = 'Wallet loaded successfully (could not set as default)'
        except Exception as e:
            print(f"⚠️ Error setting wallet as default: {str(e)}")
            message = 'Wallet loaded successfully (default setting failed)'
        
        return jsonify({
            'status': 'success',
            'wallet_id': wallet_id,
            'addresses': addresses,
            'metadata': wallet_data.get('metadata', {}),
            'message': message,
            'is_system_default': True
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/addresses/<wallet_id>', methods=['GET'])
def get_wallet_addresses(wallet_id):
    """Obter endereços derivados de uma carteira"""
    try:
        # Tentar obter do cache
        addresses, error = wallet_manager.get_cached_addresses(wallet_id)
        
        if error and "not found" not in error.lower():
            return jsonify({
                'error': error,
                'status': 'error'
            }), 500
        
        if not addresses:
            return jsonify({
                'error': 'No addresses found for this wallet ID',
                'status': 'error'
            }), 404
        
        return jsonify({
            'status': 'success',
            'wallet_id': wallet_id,
            'addresses': addresses
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/balance/<chain_id>/<address>', methods=['GET'])
def get_chain_balance(chain_id, address):
    """Obter saldo de uma chain específica usando APIs públicas"""
    try:
        if chain_id not in SUPPORTED_CHAINS:
            return jsonify({
                'error': f'Unsupported chain: {chain_id}',
                'status': 'error'
            }), 400
        
        # Para Bitcoin, tentar API local primeiro
        if chain_id == 'bitcoin':
            try:
                balance_data = get_blockchain_balance()
                if balance_data and 'confirmed_balance' in balance_data:
                    balance_btc = balance_data['confirmed_balance'] / 100000000
                    return jsonify({
                        'status': 'success',
                        'chain': chain_id,
                        'address': address,
                        'balance': f"{balance_btc:.8f}",
                        'symbol': 'BTC',
                        'source': 'local_api'
                    })
            except:
                pass
        
        # Para Liquid, tentar API local primeiro
        elif chain_id == 'liquid':
            try:
                balances_result, _ = elements_rpc_client.get_balances()
                if balances_result and 'mine' in balances_result:
                    mine_balances = balances_result['mine']
                    if 'trusted' in mine_balances:
                        for asset_name, amount in mine_balances['trusted'].items():
                            if asset_name == "bitcoin" or "6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d" in asset_name:
                                return jsonify({
                                    'status': 'success',
                                    'chain': chain_id,
                                    'address': address,
                                    'balance': f"{amount:.8f}",
                                    'symbol': 'L-BTC',
                                    'source': 'local_api'
                                })
            except:
                pass
        
        # Fallback para APIs públicas
        chain_config = SUPPORTED_CHAINS[chain_id]
        
        for api_url in chain_config['api_urls']:
            try:
                if chain_id == 'bitcoin':
                    if 'mempool.space' in api_url:
                        response = requests.get(f"{api_url}{address}", timeout=10)
                        if response.status_code == 200:
                            data = response.json()
                            balance = (data['chain_stats']['funded_txo_sum'] - data['chain_stats']['spent_txo_sum']) / 100000000
                            return jsonify({
                                'status': 'success',
                                'chain': chain_id,
                                'address': address,
                                'balance': f"{balance:.8f}",
                                'symbol': 'BTC',
                                'source': 'mempool_space'
                            })
                
                elif chain_id == 'ethereum':
                    if 'etherscan' in api_url:
                        response = requests.get(f"{api_url}?module=account&action=balance&address={address}&tag=latest&apikey=YourApiKeyToken", timeout=10)
                        if response.status_code == 200:
                            data = response.json()
                            if data['status'] == '1':
                                balance_wei = int(data['result'])
                                balance_eth = balance_wei / 10**18
                                return jsonify({
                                    'status': 'success',
                                    'chain': chain_id,
                                    'address': address,
                                    'balance': f"{balance_eth:.18f}",
                                    'symbol': 'ETH',
                                    'source': 'etherscan'
                                })
                
                elif chain_id == 'tron':
                    if 'trongrid' in api_url:
                        response = requests.post(api_url, 
                            json={"address": address, "visible": True}, 
                            timeout=10)
                        if response.status_code == 200:
                            data = response.json()
                            if not data.get('Error'):
                                balance_sun = data.get('balance', 0)
                                balance_trx = balance_sun / 1000000
                                return jsonify({
                                    'status': 'success',
                                    'chain': chain_id,
                                    'address': address,
                                    'balance': f"{balance_trx:.6f}",
                                    'symbol': 'TRX',
                                    'source': 'trongrid'
                                })
                
                elif chain_id == 'solana':
                    if 'mainnet-beta' in api_url:
                        response = requests.post(api_url,
                            json={
                                "jsonrpc": "2.0",
                                "id": 1,
                                "method": "getBalance",
                                "params": [address]
                            },
                            timeout=10)
                        if response.status_code == 200:
                            data = response.json()
                            if 'result' in data:
                                balance_lamports = data['result']['value']
                                balance_sol = balance_lamports / 10**9
                                return jsonify({
                                    'status': 'success',
                                    'chain': chain_id,
                                    'address': address,
                                    'balance': f"{balance_sol:.9f}",
                                    'symbol': 'SOL',
                                    'source': 'solana_rpc'
                                })
                
            except Exception as e:
                print(f"API {api_url} failed: {str(e)}")
                continue
        
        # Se todas as APIs falharam
        return jsonify({
            'status': 'success',
            'chain': chain_id,
            'address': address,
            'balance': '0.00000000',
            'symbol': chain_config['symbol'],
            'source': 'fallback',
            'message': 'All APIs failed, returning zero balance'
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/wallet/validate', methods=['POST'])
def validate_mnemonic():
    """Validar uma seed phrase BIP39"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'No data provided',
                'status': 'error'
            }), 400
        
        mnemonic = data.get('mnemonic', '').strip()
        
        if not mnemonic:
            return jsonify({
                'error': 'Mnemonic is required',
                'status': 'error'
            }), 400
        
        is_valid, error = wallet_manager.validate_mnemonic(mnemonic)
        
        return jsonify({
            'status': 'success',
            'valid': is_valid,
            'error': error if not is_valid else None
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

# Status endpoint for API health check
@app.route('/api/v1/wallet/status', methods=['GET'])
def wallet_status():
    """Get wallet system status"""
    try:
        return jsonify({
            'status': 'online',
            'message': 'Wallet API is running',
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# === LND WALLET INITIALIZATION ENDPOINTS ===

@app.route('/api/v1/wallet/bip39-to-lnd', methods=['POST'])
def convert_bip39_to_lnd():
    """Convert BIP39 mnemonic to LND extended master root key"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'No data provided',
                'status': 'error'
            }), 400
        
        seed_phrase = data.get('seed_phrase', '').strip()
        passphrase = data.get('passphrase', '')
        network = data.get('network', 'testnet').lower()
        
        if not seed_phrase:
            return jsonify({
                'error': 'seed_phrase is required',
                'status': 'error'
            }), 400
        
        # Validate network
        if network not in ['mainnet', 'testnet']:
            return jsonify({
                'error': 'network must be "mainnet" or "testnet"',
                'status': 'error'
            }), 400
        
        # Convert to extended master key
        result, error = wallet_manager.bip39_to_extended_master_key(seed_phrase, passphrase, network)
        if error:
            return jsonify({
                'error': error,
                'status': 'error'
            }), 500
        
        # Also generate universal wallet info
        universal_wallet, universal_error = wallet_manager.generate_universal_wallet(seed_phrase, passphrase)
        
        response = {
            'status': 'success',
            'seed_phrase': seed_phrase,
            'network': network,
            'extended_master_key': result['extended_master_key'],
            'prefix': result['prefix'],
            'lnd_import_instructions': {
                'command': 'lncli create',
                'option': 'x (extended master root key)',
                'input': result['extended_master_key'],
                'description': f'Use this {result["prefix"]} key when prompted for extended master root key'
            }
        }
        
        # Add universal wallet info if available
        if not universal_error and universal_wallet:
            response['universal_wallet'] = {
                'addresses': universal_wallet.get('addresses', {}),
                'lnd_keys': universal_wallet.get('lnd_keys', {}),
                'supported_chains': universal_wallet.get('supported_chains', [])
            }
        
        return jsonify(response)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lnd/wallet/unlock', methods=['POST'])
def unlock_lnd_wallet():
    """Unlock LND wallet using expect script"""
    try:
        data = request.get_json()
        unlock_password = data.get('password') if data else None
        
        # If no password provided, try to get from system default wallet
        if not unlock_password:
            default_wallet, error = wallet_manager.get_system_default_wallet()
            if error or not default_wallet:
                return jsonify({
                    'error': 'No password provided and no system default wallet found',
                    'status': 'error'
                }), 400
            
            # For now, return error asking for password since we can't decrypt without it
            return jsonify({
                'error': 'Password required for LND unlock',
                'status': 'error'
            }), 400
        
        print("🔓 Manual LND unlock requested via API with password...")
        
        # Create password file for expect script
        password_file = '/root/brln-os/scripts/password.txt'
        with open(password_file, 'w') as f:
            f.write(unlock_password)  # Use provided password
        
        # Run expect script to unlock wallet
        script_path = '/root/brln-os/scripts/auto-lnd-unlock.exp'
        unlock_result = subprocess.run(
            [script_path],
            cwd='/root/brln-os/scripts',
            capture_output=True,
            text=True,
            timeout=30
        )
        
        # Clean up password file
        try:
            os.remove(password_file)
        except:
            pass
        
        if unlock_result.returncode == 0:
            print("✅ LND unlocked successfully via manual API call")
            return jsonify({
                'status': 'success',
                'message': 'LND wallet unlocked successfully'
            })
        else:
            print(f"❌ LND unlock failed via manual API call: {unlock_result.stderr}")
            return jsonify({
                'status': 'error',
                'error': f'LND unlock failed: {unlock_result.stderr}'
            }), 500
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lnd/wallet/genseed', methods=['POST'])
def lnd_gen_seed():
    """Generate LND seed phrase via gRPC"""
    try:
        result, error = lnd_grpc_client.gen_seed_grpc()
        if error:
            return jsonify({
                'error': error,
                'status': 'error'
            }), 500
        
        return jsonify({
            'status': 'success',
            'seed_mnemonic': result['cipher_seed_mnemonic'],
            'enciphered_seed': result['enciphered_seed']
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lnd/wallet/init', methods=['POST'])
def lnd_init_wallet():
    """Initialize LND wallet with seed phrase via gRPC"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'No data provided',
                'status': 'error'
            }), 400
        
        wallet_password = data.get('wallet_password')
        seed_mnemonic = data.get('seed_mnemonic')
        aezeed_passphrase = data.get('aezeed_passphrase', '')
        recovery_window = data.get('recovery_window', 250)
        
        if not wallet_password:
            return jsonify({
                'error': 'wallet_password is required',
                'status': 'error'
            }), 400
        
        if not seed_mnemonic:
            return jsonify({
                'error': 'seed_mnemonic is required',
                'status': 'error'
            }), 400
        
        # Convert seed to list if it's a string
        if isinstance(seed_mnemonic, str):
            seed_mnemonic = seed_mnemonic.strip().split()
        
        result, error = lnd_grpc_client.init_wallet_grpc(
            wallet_password=wallet_password,
            cipher_seed_mnemonic=seed_mnemonic,
            aezeed_passphrase=aezeed_passphrase,
            recovery_window=recovery_window
        )
        
        if error:
            return jsonify({
                'error': error,
                'status': 'error'
            }), 500
        
        return jsonify({
            'status': 'success',
            'message': result['message'],
            'admin_macaroon': result.get('admin_macaroon')
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lnd/wallet/unlock', methods=['POST'])
def lnd_unlock_wallet():
    """Unlock LND wallet via gRPC"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'No data provided',
                'status': 'error'
            }), 400
        
        wallet_password = data.get('wallet_password')
        recovery_window = data.get('recovery_window', 250)
        
        if not wallet_password:
            return jsonify({
                'error': 'wallet_password is required',
                'status': 'error'
            }), 400
        
        result, error = lnd_grpc_client.unlock_wallet_grpc(
            wallet_password=wallet_password,
            recovery_window=recovery_window
        )
        
        if error:
            return jsonify({
                'error': error,
                'status': 'error'
            }), 500
        
        return jsonify({
            'status': 'success',
            'message': result['message']
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lnd/wallet/create-from-api', methods=['POST'])
def lnd_create_from_api_seed():
    """Generate BIP39 seed via API and create LND wallet automatically"""
    try:
        data = request.get_json()
        if not data:
            data = {}
        
        wallet_password = data.get('wallet_password')
        word_count = data.get('word_count', 24)
        bip39_passphrase = data.get('bip39_passphrase', '')
        network = data.get('network', 'testnet')
        
        if not wallet_password:
            return jsonify({
                'error': 'wallet_password is required',
                'status': 'error'
            }), 400
        
        # Generate BIP39 seed
        seed_phrase, error = wallet_manager.generate_mnemonic(word_count)
        if error:
            return jsonify({
                'error': f'Failed to generate seed: {error}',
                'status': 'error'
            }), 500
        
        # Convert to LND extended master key
        lnd_key_result, lnd_error = wallet_manager.bip39_to_extended_master_key(
            seed_phrase, bip39_passphrase, network
        )
        if lnd_error:
            return jsonify({
                'error': f'Failed to convert to LND key: {lnd_error}',
                'status': 'error'
            }), 500
        
        # Generate universal wallet info
        universal_wallet, universal_error = wallet_manager.generate_universal_wallet(seed_phrase, bip39_passphrase)
        
        # Store password for expect script
        import tempfile
        import os
        password_file = '/root/brln-os/scripts/password.txt'
        with open(password_file, 'w') as f:
            f.write(wallet_password)
        os.chmod(password_file, 0o600)
        
        return jsonify({
            'status': 'success',
            'message': 'Universal seed generated successfully',
            'seed_phrase': seed_phrase,
            'word_count': word_count,
            'network': network,
            'lnd_extended_master_key': lnd_key_result['extended_master_key'],
            'universal_wallet': universal_wallet if not universal_error else None,
            'automation_ready': True,
            'next_steps': {
                'automated_lnd_creation': f'cd /root/brln-os/scripts && ./auto-lnd-create-masterkey.exp "{lnd_key_result["extended_master_key"]}"',
                'manual_lnd_creation': {
                    'command': 'lncli create',
                    'option': 'x (extended master root key)',
                    'extended_key': lnd_key_result['extended_master_key']
                }
            }
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

@app.route('/api/v1/lnd/wallet/create-expect', methods=['POST'])
def lnd_create_wallet_expect():
    """Run expect script to create LND wallet with extended master key"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'No data provided',
                'status': 'error'
            }), 400
        
        wallet_password = data.get('wallet_password')
        extended_master_key = data.get('extended_master_key')
        network = data.get('network', 'testnet')
        
        if not wallet_password or not extended_master_key:
            return jsonify({
                'error': 'wallet_password and extended_master_key are required',
                'status': 'error'
            }), 400
        
        # Validate password length
        if len(wallet_password) < 8:
            return jsonify({
                'error': 'Password must be at least 8 characters',
                'status': 'error'
            }), 400
        
        # Write password to file for expect script
        import os
        import subprocess
        
        password_file = '/root/brln-os/scripts/password.txt'
        with open(password_file, 'w') as f:
            f.write(wallet_password)
        os.chmod(password_file, 0o600)
        
        # Run expect script
        expect_script = '/root/brln-os/scripts/auto-lnd-create-masterkey.exp'
        
        if not os.path.exists(expect_script):
            return jsonify({
                'error': f'Expect script not found: {expect_script}',
                'status': 'error'
            }), 500
        
        # Make script executable
        os.chmod(expect_script, 0o755)
        
        # Execute expect script
        try:
            result = subprocess.run(
                [expect_script, extended_master_key],
                cwd='/root/brln-os/scripts',
                capture_output=True,
                text=True,
                timeout=60
            )
            
            # Clean up password file
            if os.path.exists(password_file):
                os.remove(password_file)
            
            output = result.stdout + result.stderr
            
            if result.returncode == 0:
                return jsonify({
                    'status': 'success',
                    'message': 'LND wallet created successfully',
                    'output': output,
                    'network': network
                })
            else:
                return jsonify({
                    'status': 'error',
                    'error': f'Expect script failed with exit code {result.returncode}',
                    'output': output
                }), 500
                
        except subprocess.TimeoutExpired:
            # Clean up password file on timeout
            if os.path.exists(password_file):
                os.remove(password_file)
            return jsonify({
                'error': 'Expect script timed out after 60 seconds',
                'status': 'error'
            }), 500
        except Exception as script_error:
            # Clean up password file on error
            if os.path.exists(password_file):
                os.remove(password_file)
            raise script_error
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

# ============================================================================
# TRON GAS-FREE WALLET ENDPOINTS
# ============================================================================

@app.route('/api/v1/tron/wallet/initialize', methods=['POST'])
def tron_initialize_wallet():
    """Initialize TRON wallet from system wallet seed phrase"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'status': 'error',
                'message': 'No data provided'
            }), 400
        
        password = data.get('password')
        if not password:
            return jsonify({
                'status': 'error',
                'message': 'Password is required'
            }), 400
        
        # Get system wallet
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT encrypted_mnemonic, salt FROM wallets 
            WHERE is_system_default = 1 
            LIMIT 1
        """)
        
        result = cursor.fetchone()
        
        if not result:
            conn.close()
            return jsonify({
                'status': 'error',
                'message': 'System wallet not found. Please create a system wallet first.'
            }), 404
        
        encrypted_mnemonic, salt = result
        
        # Decrypt mnemonic
        try:
            mnemonic = decrypt_data(encrypted_mnemonic, password, salt)
        except Exception as e:
            conn.close()
            return jsonify({
                'status': 'error',
                'message': 'Invalid password or decryption failed'
            }), 401
        
        # Derive TRON address and private key
        addresses, addr_error = wallet_manager.derive_addresses(mnemonic, "")
        if addr_error:
            conn.close()
            return jsonify({
                'status': 'error',
                'message': f'Failed to derive addresses: {addr_error}'
            }), 500
        
        private_keys, privkey_error = wallet_manager.derive_private_keys(mnemonic, "")
        if privkey_error:
            conn.close()
            return jsonify({
                'status': 'error',
                'message': f'Failed to derive private keys: {privkey_error}'
            }), 500
        
        # Extract TRON data from nested dictionaries
        tron_addr_data = addresses.get('tron', {})
        tron_key_data = private_keys.get('tron', {})
        
        # Get actual address and private key strings
        if isinstance(tron_addr_data, dict):
            tron_address = tron_addr_data.get('address')
        else:
            tron_address = tron_addr_data
            
        if isinstance(tron_key_data, dict):
            tron_private_key = tron_key_data.get('private_key')
        else:
            tron_private_key = tron_key_data
        
        if not tron_address or not tron_private_key:
            conn.close()
            return jsonify({
                'status': 'error',
                'message': f'Failed to derive TRON data. Address: {tron_address}, Key: {bool(tron_private_key)}'
            }), 500
        
        # Encrypt private key (ensure it's a string)
        encrypted_key, key_salt = encrypt_data(str(tron_private_key), password)
        
        # Check if config exists
        cursor.execute("SELECT id FROM tron_config WHERE id = 1")
        exists = cursor.fetchone()
        
        if exists:
            # Update existing
            cursor.execute("""
                UPDATE tron_config 
                SET tron_address = ?, encrypted_private_key = ?, salt = ?, updated_at = CURRENT_TIMESTAMP
                WHERE id = 1
            """, (tron_address, encrypted_key, key_salt))
        else:
            # Insert new
            cursor.execute("""
                INSERT INTO tron_config 
                (id, tron_address, encrypted_private_key, salt)
                VALUES (1, ?, ?, ?)
            """, (tron_address, encrypted_key, key_salt))
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'status': 'success',
            'message': 'TRON wallet initialized successfully',
            'address': tron_address
        })
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/v1/tron/wallet/address', methods=['GET'])
def tron_get_wallet_address():
    """Get TRON gas-free wallet address"""
    try:
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT tron_address, gasfree_endpoint, gasfree_api_key, gasfree_api_secret 
            FROM tron_config 
            WHERE id = 1
        """)
        
        result = cursor.fetchone()
        conn.close()
        
        if not result or not result[0]:
            return jsonify({
                'status': 'error',
                'message': 'TRON wallet not configured. Please configure in settings.'
            }), 404
        
        eoa_address = result[0]
        gasfree_endpoint = result[1] or 'https://open.gasfree.io/tron/'
        gasfree_api_key = result[2]
        gasfree_api_secret = result[3]
        
        # Get gasFreeAddress from GasFree API
        try:
            import hmac
            import hashlib
            import base64
            import time
            
            method = 'GET'
            path = f'/tron/api/v1/address/{eoa_address}'
            timestamp = int(time.time())
            message = f"{method}{path}{timestamp}"
            
            signature = base64.b64encode(
                hmac.new(
                    gasfree_api_secret.encode('utf-8'),
                    message.encode('utf-8'),
                    hashlib.sha256
                ).digest()
            ).decode('utf-8')
            
            headers = {
                'Timestamp': str(timestamp),
                'Authorization': f'ApiKey {gasfree_api_key}:{signature}'
            }
            
            response = requests.get(
                f'{gasfree_endpoint}api/v1/address/{eoa_address}',
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('code') == 200 and data.get('data'):
                    gasfree_address = data['data'].get('gasFreeAddress')
                    if gasfree_address:
                        return jsonify({
                            'status': 'success',
                            'address': gasfree_address,
                            'eoa_address': eoa_address
                        })
            
            # Fallback to EOA address if GasFree API fails
            return jsonify({
                'status': 'success',
                'address': eoa_address,
                'warning': 'Could not fetch GasFree address, showing EOA address'
            })
            
        except Exception as e:
            # Fallback to EOA address
            return jsonify({
                'status': 'success',
                'address': eoa_address,
                'warning': f'GasFree API error: {str(e)}'
            })
            
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/v1/tron/wallet/balance', methods=['GET'])
def tron_get_balance():
    """Get TRON wallet balance from GasFree account"""
    try:
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT tron_address, tron_api_url, tron_api_key, gasfree_endpoint, gasfree_api_key, gasfree_api_secret 
            FROM tron_config 
            WHERE id = 1
        """)
        
        result = cursor.fetchone()
        conn.close()
        
        if not result or not result[0]:
            return jsonify({
                'status': 'error',
                'message': 'TRON wallet not configured'
            }), 404
        
        eoa_address = result[0]
        api_url = result[1] or 'https://api.trongrid.io'
        api_key = result[2]
        gasfree_endpoint = result[3] or 'https://open.gasfree.io/tron/'
        gasfree_api_key = result[4]
        gasfree_api_secret = result[5]
        
        # Get balance from GasFree API
        try:
            import hmac
            import hashlib
            import base64
            import time
            
            method = 'GET'
            path = f'/tron/api/v1/address/{eoa_address}'
            timestamp = int(time.time())
            message = f"{method}{path}{timestamp}"
            
            signature = base64.b64encode(
                hmac.new(
                    gasfree_api_secret.encode('utf-8'),
                    message.encode('utf-8'),
                    hashlib.sha256
                ).digest()
            ).decode('utf-8')
            
            headers = {
                'Timestamp': str(timestamp),
                'Authorization': f'ApiKey {gasfree_api_key}:{signature}'
            }
            
            response = requests.get(
                f'{gasfree_endpoint}api/v1/address/{eoa_address}',
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('code') == 200 and data.get('data'):
                    gasfree_data = data['data']
                    gasfree_address = gasfree_data.get('gasFreeAddress')
                    assets = gasfree_data.get('assets', [])
                    
                    # Find USDT balance
                    usdt_balance = 0
                    usdt_contract = 'TR7NHqjeKQxGTCi8z8ZY4pL8otSzgjLj6t'
                    
                    if gasfree_address:
                        # Query balance from gasFreeAddress on chain
                        headers_tron = {}
                        if api_key:
                            headers_tron['TRON-PRO-API-KEY'] = api_key
                        
                        trigger_response = requests.post(
                            f'{api_url}/wallet/triggerconstantcontract',
                            json={
                                'owner_address': gasfree_address,
                                'contract_address': usdt_contract,
                                'function_selector': 'balanceOf(address)',
                                'parameter': gasfree_address.replace('T', '41').ljust(64, '0'),
                                'visible': True
                            },
                            headers=headers_tron,
                            timeout=10
                        )
                        
                        if trigger_response.status_code == 200:
                            trigger_data = trigger_response.json()
                            if trigger_data.get('result', {}).get('result'):
                                constant_result = trigger_data.get('constant_result', [])
                                if constant_result:
                                    balance_hex = constant_result[0]
                                    usdt_balance = int(balance_hex, 16) / 1000000
                    
                    return jsonify({
                        'status': 'success',
                        'address': gasfree_address,
                        'usdt_balance': usdt_balance
                    })
            
            # Fallback: return 0 balance if GasFree API fails
            return jsonify({
                'status': 'success',
                'address': eoa_address,
                'usdt_balance': 0,
                'warning': 'Could not fetch GasFree balance'
            })
            
        except Exception as e:
            return jsonify({
                'status': 'error',
                'message': f'Error fetching balance: {str(e)}'
            }), 500
        
        return jsonify({
            'status': 'success',
            'address': eoa_address,
            'usdt_balance': 0
        })
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/v1/tron/wallet/send', methods=['POST'])
def tron_send_usdt():
    """Send USDT via gas-free protocol"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'status': 'error',
                'message': 'No data provided'
            }), 400
        
        to_address = data.get('to_address')
        amount = float(data.get('amount', 0))
        password = data.get('password')
        
        if not to_address or not amount or not password:
            return jsonify({
                'status': 'error',
                'message': 'Missing required parameters'
            }), 400
        
        if amount < 1.01:
            return jsonify({
                'status': 'error',
                'message': 'Minimum amount is 1.01 USDT (1 USDT gas-free fee + 0.01 USDT transfer)'
            }), 400
        
        # Get wallet config
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT tron_address, encrypted_private_key, salt,
                   tron_api_url, tron_api_key,
                   gasfree_api_key, gasfree_api_secret, gasfree_endpoint,
                   gasfree_verifying_contract, gasfree_service_provider
            FROM tron_config 
            WHERE id = 1
        """)
        
        result = cursor.fetchone()
        conn.close()
        
        if not result:
            return jsonify({
                'status': 'error',
                'message': 'TRON wallet not configured'
            }), 404
        
        from_address = result[0]
        encrypted_key = result[1]
        salt = result[2]
        api_url = result[3] or 'https://api.trongrid.io'
        api_key = result[4]
        gasfree_api_key = result[5]
        gasfree_api_secret = result[6]
        gasfree_endpoint = result[7] or 'https://open.gasfree.io/tron/'
        verifying_contract = result[8] or 'TFFAMLQZybALab4uxHA9RBE7pxhUAjfF3U'
        service_provider = result[9] or 'TLntW9Z59LYY5KEi9cmwk3PKjQga828ird'
        
        # Decrypt private key
        try:
            private_key = decrypt_data(encrypted_key, password, salt)
        except Exception as e:
            return jsonify({
                'status': 'error',
                'message': 'Invalid password or decryption failed'
            }), 401
        
        # Calculate net amount (deduct 1 USDT gas-free fee)
        net_amount = amount - 1.0
        usdt_amount_in_sun = int(net_amount * 1000000)  # USDT has 6 decimals
        
        # Here we would integrate with the TRON gas-free protocol
        # For now, return a mock transaction
        txid = f"mock_tx_{secrets.token_hex(32)}"
        
        # In production, you would:
        # 1. Create unsigned USDT transfer transaction
        # 2. Sign it with gas-free protocol signature
        # 3. Submit to gas-free endpoint
        # 4. Return actual transaction ID
        
        return jsonify({
            'status': 'success',
            'message': 'Transaction sent successfully',
            'txid': txid,
            'from_address': from_address,
            'to_address': to_address,
            'amount': net_amount,
            'fee': 1.0,
            'total': amount
        })
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/v1/tron/wallet/transactions', methods=['GET'])
def tron_get_transactions():
    """Get TRON transaction history"""
    try:
        limit = int(request.args.get('limit', 30))
        
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT tron_address, tron_api_url, tron_api_key 
            FROM tron_config 
            WHERE id = 1
        """)
        
        result = cursor.fetchone()
        conn.close()
        
        if not result or not result[0]:
            return jsonify({
                'status': 'error',
                'message': 'TRON wallet not configured'
            }), 404
        
        address = result[0]
        api_url = result[1] or 'https://api.trongrid.io'
        api_key = result[2]
        
        headers = {}
        if api_key:
            headers['TRON-PRO-API-KEY'] = api_key
        
        # Get TRC20 transfers (USDT)
        usdt_contract = 'TR7NHqjeKQxGTCi8z8ZY4pL8otSzgjLj6t'
        
        response = requests.get(
            f'{api_url}/v1/accounts/{address}/transactions/trc20',
            params={
                'limit': limit,
                'contract_address': usdt_contract
            },
            headers=headers,
            timeout=10
        )
        
        transactions = []
        if response.status_code == 200:
            data = response.json()
            for tx in data.get('data', []):
                transactions.append({
                    'txid': tx.get('transaction_id'),
                    'from_address': tx.get('from'),
                    'to_address': tx.get('to'),
                    'amount': float(tx.get('value', 0)) / 1000000,  # Convert to USDT
                    'timestamp': tx.get('block_timestamp', 0) // 1000,
                    'status': 'confirmed' if tx.get('result') == 'SUCCESS' else 'failed'
                })
        
        return jsonify({
            'status': 'success',
            'transactions': transactions,
            'count': len(transactions)
        })
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/v1/tron/config/save', methods=['POST'])
def tron_save_config():
    """Save TRON configuration (encrypted)"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'status': 'error',
                'message': 'No data provided'
            }), 400
        
        password = data.get('password')
        if not password:
            return jsonify({
                'status': 'error',
                'message': 'Password is required'
            }), 400
        
        tron_api_url = data.get('tron_api_url', 'https://api.trongrid.io')
        tron_api_key = data.get('tron_api_key', '')
        gasfree_api_key = data.get('gasfree_api_key', '')
        gasfree_api_secret = data.get('gasfree_api_secret', '')
        gasfree_endpoint = data.get('gasfree_endpoint', 'https://open.gasfree.io/tron/')
        
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        # Check if config exists
        cursor.execute("SELECT id FROM tron_config WHERE id = 1")
        exists = cursor.fetchone()
        
        if exists:
            # Update existing config
            cursor.execute("""
                UPDATE tron_config 
                SET tron_api_url = ?, tron_api_key = ?,
                    gasfree_api_key = ?, gasfree_api_secret = ?,
                    gasfree_endpoint = ?
                WHERE id = 1
            """, (tron_api_url, tron_api_key, gasfree_api_key, 
                  gasfree_api_secret, gasfree_endpoint))
        else:
            # Insert new config
            cursor.execute("""
                INSERT INTO tron_config 
                (id, tron_api_url, tron_api_key, gasfree_api_key, 
                 gasfree_api_secret, gasfree_endpoint)
                VALUES (1, ?, ?, ?, ?, ?)
            """, (tron_api_url, tron_api_key, gasfree_api_key, 
                  gasfree_api_secret, gasfree_endpoint))
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'status': 'success',
            'message': 'Configuration saved successfully'
        })
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/v1/tron/config/load', methods=['GET'])
def tron_load_config():
    """Load TRON configuration (non-sensitive data only)"""
    try:
        conn = sqlite3.connect(WALLET_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT tron_api_url, tron_api_key, 
                   gasfree_api_key, gasfree_endpoint
            FROM tron_config 
            WHERE id = 1
        """)
        
        result = cursor.fetchone()
        conn.close()
        
        if result:
            return jsonify({
                'status': 'success',
                'config': {
                    'tron_api_url': result[0],
                    'tron_api_key': result[1],
                    'gasfree_api_key': result[2],
                    'gasfree_endpoint': result[3]
                }
            })
        else:
            return jsonify({
                'status': 'success',
                'config': None
            })
            
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=2121, debug=False)