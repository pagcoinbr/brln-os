#!/usr/bin/env python3
"""
API para gerenciamento do comando central e status do sistema BRLN-OS
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import subprocess
import psutil
import os
import json
import requests
import urllib3
from pathlib import Path

# Desabilitar warnings de SSL para requests locais
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configurações LND
LND_HOST = "localhost"
LND_PORT = "8080"
MACAROON_PATH = "/data/lnd/data/chain/bitcoin/testnet/admin.macaroon"
try:
    from pydbus import SystemBus
    PYDBUS_AVAILABLE = True
except ImportError:
    PYDBUS_AVAILABLE = False
    print("Warning: pydbus not available, falling back to subprocess for systemd")

app = Flask(__name__)
CORS(app)

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
    try:
        output, code = run_command("bitcoin-cli getblockchaininfo 2>/dev/null")
        if code == 0 and output:
            info = json.loads(output)
            return {
                'status': 'running',
                'blocks': info.get('blocks', 0),
                'progress': round(info.get('verificationprogress', 0) * 100, 2)
            }
    except:
        pass
    return {
        'status': 'stopped' if not get_service_status('bitcoind.service') else 'error',
        'blocks': 0,
        'progress': 0
    }

def get_blockchain_size():
    """Obtém o tamanho da blockchain usando pathlib"""
    try:
        bitcoin_dir = Path.home() / ".bitcoin"
        if bitcoin_dir.exists():
            total_size = sum(f.stat().st_size for f in bitcoin_dir.rglob('*') if f.is_file())
            # Converter para formato legível
            for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
                if total_size < 1024.0:
                    return f"{total_size:.1f}{unit}"
                total_size /= 1024.0
            return f"{total_size:.1f}PB"
    except Exception as e:
        print(f"Error calculating blockchain size: {e}")
    return "N/A"

def get_macaroon_hex():
    """Lê o admin.macaroon e retorna em formato hex"""
    try:
        with open(MACAROON_PATH, 'rb') as f:
            macaroon_bytes = f.read()
        return macaroon_bytes.hex()
    except Exception as e:
        print(f"Error reading macaroon: {e}")
        return None

def make_lnd_request(endpoint, method="GET", data=None):
    """Faz requisição para o LND REST API"""
    try:
        macaroon_hex = get_macaroon_hex()
        if not macaroon_hex:
            return None, "Erro ao ler macaroon"
        
        url = f"https://{LND_HOST}:{LND_PORT}{endpoint}"
        headers = {
            "Grpc-Metadata-macaroon": macaroon_hex,
            "Content-Type": "application/json"
        }
        
        if method == "GET":
            response = requests.get(
                url, 
                headers=headers, 
                verify=False,
                timeout=10
            )
        elif method == "POST":
            response = requests.post(
                url, 
                headers=headers, 
                data=json.dumps(data) if data else None,
                verify=False,
                timeout=30  # Timeout maior para operações de canal
            )
        elif method == "DELETE":
            response = requests.delete(
                url, 
                headers=headers, 
                data=json.dumps(data) if data else None,
                verify=False,
                timeout=30
            )
        else:
            return None, f"Método HTTP {method} não suportado"
        
        if response.status_code in [200, 201]:
            try:
                return response.json(), None
            except json.JSONDecodeError:
                # Algumas operações podem retornar resposta vazia
                return {"success": True}, None
        else:
            return None, f"Erro HTTP {response.status_code}: {response.text}"
            
    except requests.exceptions.RequestException as e:
        return None, f"Erro de conexão: {str(e)}"
    except Exception as e:
        return None, f"Erro inesperado: {str(e)}"

def get_blockchain_balance():
    """Obtém o saldo on-chain do LND"""
    data, error = make_lnd_request("/v1/balance/blockchain")
    
    if error:
        return {
            'error': error,
            'status': 'error'
        }
    
    if data:
        return {
            'status': 'success',
            'total_balance': data.get('total_balance', '0'),
            'confirmed_balance': data.get('confirmed_balance', '0'),
            'unconfirmed_balance': data.get('unconfirmed_balance', '0'),
            'locked_balance': data.get('locked_balance', '0')
        }
    
    return {
        'error': 'Resposta vazia do LND',
        'status': 'error'
    }

def get_lnd_info():
    """Obtém informações do LND"""
    try:
        info, error = make_lnd_request("/v1/getinfo")
        if not error and info:
            return {
                'status': 'running',
                'synced': info.get('synced_to_chain', False),
                'block_height': info.get('block_height', 0)
            }
    except:
        pass
    return {
        'status': 'stopped' if not get_service_status('lnd.service') else 'error',
        'synced': False,
        'block_height': 0
    }

def get_lightning_balance():
    """Obtém o saldo do canal do LND"""
    data, error = make_lnd_request("/v1/balance/channels")
    
    if error:
        return {
            'error': error,
            'status': 'error'
        }
    
    if data:
        return {
            'status': 'success',
            'balance': data.get('balance', '0'),
            'pending_open_balance': data.get('pending_open_balance', '0')
        }
    
    return {
        'error': 'Resposta vazia do LND',
        'status': 'error'
    }

def get_lightning_channels():
    """Obtém a lista de canais do LND"""
    data, error = make_lnd_request("/v1/channels")
    
    if error:
        return {
            'error': error,
            'status': 'error'
        }

    if data:
        return {
            'status': 'success',
            'channels': data
        }
    
    return {
        'error': 'Resposta vazia do LND',
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
            
        # Fazer a requisição para abrir o canal
        data, error = make_lnd_request("/v1/channels", method="POST", data=channel_data)
        
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        if data:
            return {
                'status': 'success',
                'funding_txid': data.get('funding_txid_str'),
                'output_index': data.get('output_index'),
                'message': 'Canal sendo aberto. Aguarde confirmações na rede.'
            }
        
        return {
            'error': 'Resposta vazia do LND',
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
        
        # Preparar dados para fechar canal
        close_data = {
            'channel_point': {
                'funding_txid_str': channel_point.split(':')[0],
                'output_index': int(channel_point.split(':')[1])
            },
            'force': force_close
        }
        
        # Adicionar parâmetros opcionais
        if target_conf:
            close_data['target_conf'] = target_conf
        if sat_per_vbyte:
            close_data['sat_per_vbyte'] = str(sat_per_vbyte)
        
        # Escolher endpoint baseado no tipo de fechamento
        endpoint = "/v1/channels/close"
        
        data, error = make_lnd_request(endpoint, method="DELETE", data=close_data)
        
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        if data:
            close_type = "forçado" if force_close else "cooperativo"
            return {
                'status': 'success',
                'closing_txid': data.get('closing_txid'),
                'message': f'Canal sendo fechado ({close_type}). Aguarde confirmações na rede.'
            }
        
        return {
            'error': 'Resposta vazia do LND',
            'status': 'error'
        }
        
    except Exception as e:
        return {
            'error': f'Erro inesperado ao fechar canal: {str(e)}',
            'status': 'error'
        }

def get_pending_channels():
    """Obtém canais pendentes do LND"""
    data, error = make_lnd_request("/v1/channels/pending")
    
    if error:
        return {
            'error': error,
            'status': 'error'
        }
    
    if data:
        return {
            'status': 'success',
            'pending_channels': data
        }
    
    return {
        'error': 'Resposta vazia do LND',
        'status': 'error'
    }

def get_channel_info(channel_id):
    """Obtém informações detalhadas de um canal específico"""
    try:
        data, error = make_lnd_request(f"/v1/graph/edge/{channel_id}")
        
        if error:
            return {
                'error': error,
                'status': 'error'
            }
        
        if data:
            return {
                'status': 'success',
                'channel_info': data
            }
        
        return {
            'error': 'Canal não encontrado',
            'status': 'error'
        }
        
    except Exception as e:
        return {
            'error': f'Erro ao obter informações do canal: {str(e)}',
            'status': 'error'
        }

@app.route('/api/v1/config/system-status', methods=['GET'])
def system_status():
    """Retorna o status do sistema"""
    try:
        # CPU
        cpu_percent = psutil.cpu_percent(interval=1)
        load_avg = os.getloadavg()
        
        # RAM
        ram = psutil.virtual_memory()
        
        # LND Info
        lnd_info = get_lnd_info()
        
        # Bitcoin Info
        bitcoin_info = get_bitcoind_info()
        
        # Tor Status
        tor_active = get_service_status('tor@default.service')
        
        # Blockchain
        blockchain_size = get_blockchain_size()
        
        return jsonify({
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
                'progress': bitcoin_info.get('progress', 0)
            }
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/config/services-status', methods=['GET'])
def services_status():
    """Retorna o status de todos os serviços"""
    try:
        services = {}
        for service_key, service_name in SERVICE_MAPPING.items():
            services[service_key] = get_service_status(service_name)
        
        return jsonify({'services': services})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/config/service', methods=['POST'])
def manage_service():
    """Gerencia um serviço (start/stop)"""
    try:
        data = request.get_json()
        service_key = data.get('service')
        action = data.get('action')  # 'start' ou 'stop'
        
        if not service_key or not action:
            return jsonify({'error': 'Service e action são obrigatórios'}), 400
        
        if service_key not in SERVICE_MAPPING:
            return jsonify({'error': f'Serviço {service_key} não encontrado'}), 404
        
        if action not in ['start', 'stop', 'restart']:
            return jsonify({'error': 'Action deve ser start, stop ou restart'}), 400
        
        service_name = SERVICE_MAPPING[service_key]
        
        # Gerencia o serviço usando D-Bus/systemd
        success, error_msg = manage_systemd_service(service_name, action)
        
        if success:
            return jsonify({
                'success': True,
                'service': service_key,
                'action': action,
                'status': get_service_status(service_name)
            })
        else:
            return jsonify({
                'error': f'Falha ao executar {action} em {service_key}',
                'output': error_msg
            }), 500
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/config/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'version': '1.0'})

@app.route('/api/v1/balance/blockchain', methods=['GET'])
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

@app.route('/api/v1/channels', methods=['GET'])
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

@app.route('/api/v1/channels/open', methods=['POST'])
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

@app.route('/api/v1/channels/close', methods=['POST'])
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

@app.route('/api/v1/channels/pending', methods=['GET'])
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

@app.route('/api/v1/channels/<channel_id>', methods=['GET'])
def channel_info(channel_id):
    """Endpoint para obter informações de um canal específico"""
    try:
        if not channel_id:
            return jsonify({
                'error': 'channel_id é obrigatório',
                'status': 'error'
            }), 400
        
        info = get_channel_info(channel_id)
        
        if info.get('status') == 'error':
            return jsonify(info), 500
        
        return jsonify(info)
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

if __name__ == '__main__':
    # Roda na porta 2121 (para não conflitar com LNBits que usa 5000)
    app.run(host='0.0.0.0', port=2121, debug=False)
