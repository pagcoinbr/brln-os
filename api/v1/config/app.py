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
from pathlib import Path
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

def get_lnd_info():
    """Obtém informações do LND"""
    try:
        output, code = run_command("lncli getinfo 2>/dev/null")
        if code == 0 and output:
            info = json.loads(output)
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

if __name__ == '__main__':
    # Roda na porta 2121 (para não conflitar com LNBits que usa 5000)
    app.run(host='0.0.0.0', port=2121, debug=False)
