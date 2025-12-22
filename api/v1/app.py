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
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import subprocess
import psutil
import os
import json
from pathlib import Path
import grpc
import codecs
import datetime
import hashlib
from concurrent import futures
import time
import requests
import sqlite3
import threading
import base64
import warnings

# Desabilitar warnings desnecessários
import warnings
warnings.filterwarnings("ignore")

# Configurações LND
LND_HOST = "localhost"
LND_GRPC_PORT = "10009"
MACAROON_PATH = "/data/lnd/data/chain/bitcoin/testnet/admin.macaroon"
TLS_CERT_PATH = "/data/lnd/tls.cert"
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
    
    def close(self):
        """Fechar conexão gRPC"""
        if self.channel:
            self.channel.close()
            self._connected = False

# Singleton para reusar conexão gRPC
lnd_grpc_client = LNDgRPCClient()

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
    'bos-telegram': 'bos-telegram.service',
    'tor': 'tor@default.service'
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
                    formatted_tx['date'] = datetime.datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S')
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
            'timestamp': datetime.datetime.utcnow().isoformat()
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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=2121, debug=False)