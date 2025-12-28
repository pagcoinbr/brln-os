#!/usr/bin/env python3
"""
Monitor para Keysends recebidos via Lightning Network (versão gRPC)
Este script monitora keysends recebidos usando gRPC e processa mensagens de chat

Usage: python3 lightning_monitor_grpc.py
"""

import time
import grpc
import os
import sys
import requests
import logging
import base64
from datetime import datetime

# Importar os módulos gRPC gerados
import lightning_pb2 as lightning
import lightning_pb2_grpc as lightningstub

# Configurações
API_BASE_URL = "http://localhost:2121/api/v1"
CHECK_INTERVAL = 5  # segundos

# Configurações gRPC do LND (valores padrão)
LND_HOST = os.getenv('LND_HOST', 'localhost')
LND_PORT = os.getenv('LND_PORT', '10009')
MACAROON_PATH = os.getenv('MACAROON_PATH', '/root/.lnd/data/chain/bitcoin/mainnet/admin.macaroon')
TLS_CERT_PATH = os.getenv('TLS_CERT_PATH', '/root/.lnd/tls.cert')

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class LNDGRPCClient:
    """Cliente gRPC para conectar ao LND"""
    
    def __init__(self):
        self.channel = None
        self.stub = None
        self.metadata = None
        
    def connect(self):
        """Conecta ao LND via gRPC"""
        try:
            # Ler o certificado TLS
            if os.path.exists(TLS_CERT_PATH):
                with open(TLS_CERT_PATH, 'rb') as f:
                    cert = f.read()
                credentials = grpc.ssl_channel_credentials(cert)
            else:
                logger.warning(f"Certificado TLS não encontrado em {TLS_CERT_PATH}, usando conexão insegura")
                credentials = grpc.local_channel_credentials()
                
            # Criar channel
            self.channel = grpc.secure_channel(f'{LND_HOST}:{LND_PORT}', credentials)
            
            # Criar stub
            self.stub = lightningstub.LightningStub(self.channel)
            
            # Ler macaroon para autenticação
            if os.path.exists(MACAROON_PATH):
                with open(MACAROON_PATH, 'rb') as f:
                    macaroon_bytes = f.read()
                    macaroon = macaroon_bytes.hex()
                self.metadata = [('macaroon', macaroon)]
            else:
                logger.warning(f"Macaroon não encontrado em {MACAROON_PATH}")
                self.metadata = []
                
            # Testar conexão
            info_request = lightning.GetInfoRequest()
            response = self.stub.GetInfo(info_request, metadata=self.metadata)
            logger.info(f"Conectado ao LND - Node: {response.alias} ({response.identity_pubkey[:16]}...)")
            
            return True
            
        except Exception as e:
            logger.error(f"Erro ao conectar ao LND via gRPC: {e}")
            return False
            
    def get_info(self):
        """Obtém informações do nó"""
        try:
            request = lightning.GetInfoRequest()
            response = self.stub.GetInfo(request, metadata=self.metadata)
            return response
        except Exception as e:
            logger.error(f"Erro ao obter informações do nó: {e}")
            return None
            
    def list_invoices(self, index_offset=0, num_max_invoices=50, reversed=True):
        """Lista invoices"""
        try:
            request = lightning.ListInvoiceRequest(
                index_offset=index_offset,
                num_max_invoices=num_max_invoices,
                reversed=reversed
            )
            response = self.stub.ListInvoices(request, metadata=self.metadata)
            return response
        except Exception as e:
            logger.error(f"Erro ao listar invoices: {e}")
            return None
            
    def close(self):
        """Fecha a conexão"""
        if self.channel:
            self.channel.close()

def get_recent_payments(lnd_client, last_index_offset=None):
    """Obtém pagamentos recebidos recentes via gRPC"""
    try:
        index_offset = last_index_offset if last_index_offset else 0
        invoices_response = lnd_client.list_invoices(
            index_offset=index_offset,
            num_max_invoices=50,
            reversed=True
        )
        
        if not invoices_response:
            return []
            
        # Filtrar apenas invoices pagos recentemente
        recent_payments = []
        current_time = int(time.time())
        
        for invoice in invoices_response.invoices:
            if invoice.settled:
                settle_date = int(invoice.settle_date)
                # Verificar se foi pago nos últimos 60 segundos
                if current_time - settle_date <= 60:
                    # Verificar se é um keysend (tem custom records)
                    for htlc in invoice.htlcs:
                        custom_records = dict(htlc.custom_records)
                        if custom_records:  # É um keysend
                            recent_payments.append({
                                'payment_hash': invoice.r_hash.hex(),
                                'amount_sat': int(invoice.value),
                                'settle_date': settle_date,
                                'custom_records': {str(k): v.hex() for k, v in custom_records.items()}
                            })
                            break
        
        return recent_payments
        
    except Exception as e:
        logger.error(f"Erro ao obter pagamentos recentes: {e}")
        return []

def extract_sender_from_htlcs(invoice_data):
    """Extrai o node_id do sender dos HTLCs"""
    try:
        # Em uma implementação real, seria necessário fazer lookup do channel
        # para descobrir o peer. Por enquanto, usamos um placeholder.
        return "unknown_sender"
    except Exception as e:
        logger.error(f"Erro ao extrair sender: {e}")
        return "unknown_sender"

def process_keysend_payment(payment):
    """Processa um pagamento keysend recebido"""
    try:
        payment_hash = payment['payment_hash']
        amount_sat = payment['amount_sat']
        custom_records = payment['custom_records']
        
        # Para uma implementação real, precisaríamos descobrir o node_id do sender
        sender_node_id = extract_sender_from_htlcs(payment)
        
        # Enviar para a API para processamento
        data = {
            'payment_hash': payment_hash,
            'sender_node_id': sender_node_id,
            'amount_sat': amount_sat,
            'custom_records': custom_records
        }
        
        response = requests.post(
            f"{API_BASE_URL}/lightning/chat/keysends/check",
            json=data,
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            if result.get('processed'):
                logger.info(f"Keysend processado: {payment_hash[:16]}...")
                
                # Se tem mensagem, logar (TLV record 34349334 é para mensagens)
                message_data = custom_records.get('34349334')
                if message_data:
                    try:
                        # Converter de hex para bytes e decodificar
                        message_bytes = bytes.fromhex(message_data)
                        message = message_bytes.decode('utf-8')
                        logger.info(f"Mensagem recebida: {message}")
                    except Exception as e:
                        logger.info(f"Mensagem recebida (não decodificável): {e}")
            else:
                logger.debug(f"Keysend já processado: {payment_hash[:16]}...")
        else:
            logger.error(f"Erro ao processar keysend na API: {response.status_code}")
            
    except Exception as e:
        logger.error(f"Erro ao processar keysend: {e}")

def main():
    """Loop principal do monitor"""
    logger.info("Iniciando monitor de Lightning keysends (gRPC)...")
    
    # Inicializar cliente gRPC
    lnd_client = LNDGRPCClient()
    
    if not lnd_client.connect():
        logger.error("Não foi possível conectar ao LND")
        sys.exit(1)
    
    try:
        while True:
            try:
                # Verificar se LND está rodando
                info = lnd_client.get_info()
                if not info:
                    logger.warning("LND não está acessível, aguardando...")
                    time.sleep(CHECK_INTERVAL)
                    continue
                
                # Obter pagamentos recentes
                recent_payments = get_recent_payments(lnd_client)
                
                for payment in recent_payments:
                    process_keysend_payment(payment)
                
                # Aguardar próxima verificação
                time.sleep(CHECK_INTERVAL)
                
            except KeyboardInterrupt:
                logger.info("Monitor interrompido pelo usuário")
                break
            except Exception as e:
                logger.error(f"Erro no loop principal: {e}")
                time.sleep(CHECK_INTERVAL)
                
    finally:
        # Fechar conexão gRPC
        lnd_client.close()

if __name__ == "__main__":
    main()