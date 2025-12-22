#!/usr/bin/env python3
"""
Monitor para Keysends recebidos via Lightning Network
Este script monitora keysends recebidos e processa mensagens de chat

Usage: python3 lightning_monitor.py
"""

import time
import subprocess
import json
import sys
import requests
import logging
from datetime import datetime

# Configurações
API_BASE_URL = "http://localhost:2121/api/v1"
LND_CLI = "lncli"  # Assumindo que lncli está disponível no PATH
CHECK_INTERVAL = 5  # segundos

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def run_lncli_command(command):
    """Executa comando lncli e retorna o resultado"""
    try:
        full_command = f"{LND_CLI} {command}"
        result = subprocess.run(
            full_command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode != 0:
            logger.error(f"Erro no comando lncli: {result.stderr}")
            return None
            
        return json.loads(result.stdout) if result.stdout.strip() else None
        
    except subprocess.TimeoutExpired:
        logger.error(f"Timeout no comando: {command}")
        return None
    except json.JSONDecodeError as e:
        logger.error(f"Erro ao decodificar JSON: {e}")
        return None
    except Exception as e:
        logger.error(f"Erro inesperado: {e}")
        return None

def get_recent_payments(last_index_offset=None):
    """Obtém pagamentos recebidos recentes"""
    try:
        # Listar invoices recentes
        cmd = "listinvoices --index_offset=0 --num_max_invoices=50 --reversed=true"
        if last_index_offset:
            cmd = f"listinvoices --index_offset={last_index_offset} --num_max_invoices=50 --reversed=true"
            
        invoices_data = run_lncli_command(cmd)
        if not invoices_data:
            return []
            
        # Filtrar apenas invoices pagos recentemente
        recent_payments = []
        current_time = int(time.time())
        
        for invoice in invoices_data.get('invoices', []):
            if invoice.get('settled', False):
                settle_date = int(invoice.get('settle_date', 0))
                # Verificar se foi pago nos últimos 60 segundos
                if current_time - settle_date <= 60:
                    # Verificar se é um keysend (tem custom records)
                    htlcs = invoice.get('htlcs', [])
                    for htlc in htlcs:
                        custom_records = htlc.get('custom_records', {})
                        if custom_records:  # É um keysend
                            recent_payments.append({
                                'payment_hash': invoice.get('r_hash'),
                                'amount_sat': int(invoice.get('value', 0)),
                                'settle_date': settle_date,
                                'custom_records': custom_records
                            })
                            break
        
        return recent_payments
        
    except Exception as e:
        logger.error(f"Erro ao obter pagamentos recentes: {e}")
        return []

def extract_sender_from_htlcs(invoice_data):
    """Extrai o node_id do sender dos HTLCs"""
    try:
        htlcs = invoice_data.get('htlcs', [])
        for htlc in htlcs:
            # O chan_id pode ser usado para descobrir o peer
            # Por enquanto, vamos usar um placeholder
            # Em implementação real, precisaria fazer lookup do channel
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
        # Por enquanto, vamos usar um placeholder
        sender_node_id = "unknown_sender"
        
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
                
                # Se tem mensagem, logar
                message_data = custom_records.get('34349334')
                if message_data:
                    try:
                        import base64
                        message = base64.b64decode(message_data).decode('utf-8')
                        logger.info(f"Mensagem recebida: {message}")
                    except:
                        logger.info("Mensagem recebida (não decodificável)")
            else:
                logger.debug(f"Keysend já processado: {payment_hash[:16]}...")
        else:
            logger.error(f"Erro ao processar keysend na API: {response.status_code}")
            
    except Exception as e:
        logger.error(f"Erro ao processar keysend: {e}")

def main():
    """Loop principal do monitor"""
    logger.info("Iniciando monitor de Lightning keysends...")
    
    last_check_time = int(time.time())
    
    while True:
        try:
            # Verificar se LND está rodando
            info = run_lncli_command("getinfo")
            if not info:
                logger.warning("LND não está acessível, aguardando...")
                time.sleep(CHECK_INTERVAL)
                continue
            
            # Obter pagamentos recentes
            recent_payments = get_recent_payments()
            
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

if __name__ == "__main__":
    main()