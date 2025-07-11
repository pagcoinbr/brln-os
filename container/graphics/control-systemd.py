from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import subprocess
import os
import json
import threading
import time


app = Flask(__name__)
app.config['SECRET_KEY'] = 'brln-realtime-key'
CORS(app, origins="*")  # <- liberação de CORS
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Mapeamento de apps para containers Docker
APP_TO_CONTAINER = {
    "peerswap": "peerswap",
    "lnbits": "lnbits",
    "thunderhub": "thunderhub",
    "simple": "simple-lnwallet",  # Mantido o nome original caso exista
    "lndg": "lndg",
    "lndg-controller": "lndg",  # Mesmo container que lndg
    "lnd": "lnd",
    "bitcoind": "bitcoin",
    "tor": "tor",
    "elementsd": "elements",
    "bos-telegram": "bos-telegram",  # Caso exista
}

# Função auxiliar para verificar o status do container
def get_container_status(container_name):
    try:
        # Verifica se o container existe e está rodando
        result = subprocess.run(
            ['docker', 'inspect', '-f', '{{.State.Running}}', container_name],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            # Se o comando foi bem-sucedido, o container existe
            is_running = result.stdout.strip().lower() == 'true'
            return is_running
        else:
            # Container não existe
            return False

    except Exception as e:
        # Se der qualquer erro no subprocess, é falso também
        return False

# Função auxiliar para obter o status do container com mais detalhes
def get_container_detailed_status(container_name):
    try:
        # Verifica se o container existe
        result = subprocess.run(
            ['docker', 'inspect', '-f', '{{.State.Status}}', container_name],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            status = result.stdout.strip().lower()
            return status
        else:
            return "not_found"

    except Exception as e:
        return "error"

@app.route('/service-status')
def service_status():
    app_name = request.args.get('app')
    if not app_name or app_name not in APP_TO_CONTAINER:
        return jsonify({"error": "App inválido ou não informado"}), 400

    container_name = APP_TO_CONTAINER[app_name]
    is_active = get_container_status(container_name)
    status = get_container_detailed_status(container_name)
    
    return jsonify({
        "active": is_active, 
        "status": status,
        "container": container_name
    })

@app.route('/toggle-service', methods=['POST'])
def toggle_service():
    app_name = request.args.get('app')
    if not app_name or app_name not in APP_TO_CONTAINER:
        return jsonify({"error": "App inválido ou não informado"}), 400

    container_name = APP_TO_CONTAINER[app_name]
    is_active = get_container_status(container_name)

    # Define a ação baseada no status atual
    if is_active:
        action = "stop"
        docker_command = ['docker', 'stop', container_name]
    else:
        action = "start"
        # Primeiro tenta start, se falhar tenta com docker-compose up
        docker_command = ['docker', 'start', container_name]

    try:
        # Tenta executar o comando docker
        result = subprocess.run(
            docker_command,
            check=True,
            capture_output=True,
            text=True,
            cwd='/home/admin/brlnfullauto/container'  # Diretório onde está o docker-compose.yml
        )
        
        # Verifica o novo status
        new_status = get_container_status(container_name)
        
        # Atualiza cache e emite evento WebSocket
        container_status_cache[app_name] = {
            "container": container_name,
            "running": new_status,
            "status": get_container_detailed_status(container_name)
        }
        
        # Emite update imediato via WebSocket
        socketio.emit('container_status_update', {app_name: container_status_cache[app_name]})
        
        return jsonify({
            "success": True, 
            "new_status": new_status,
            "action": action,
            "container": container_name
        })
        
    except subprocess.CalledProcessError as e:
        # Se falhar no start, tenta com docker-compose
        if action == "start":
            try:
                compose_command = ['docker-compose', 'up', '-d', container_name]
                subprocess.run(
                    compose_command,
                    check=True,
                    capture_output=True,
                    text=True,
                    cwd='/home/admin/brlnfullauto/container'
                )
                
                new_status = get_container_status(container_name)
                
                # Atualiza cache e emite evento WebSocket
                container_status_cache[app_name] = {
                    "container": container_name,
                    "running": new_status,
                    "status": get_container_detailed_status(container_name)
                }
                
                socketio.emit('container_status_update', {app_name: container_status_cache[app_name]})
                
                return jsonify({
                    "success": True, 
                    "new_status": new_status,
                    "action": "compose_up",
                    "container": container_name
                })
                
            except subprocess.CalledProcessError as compose_error:
                return jsonify({
                    "success": False, 
                    "error": f"Falha no docker start e compose up: {compose_error.stderr}",
                    "container": container_name
                }), 500
        
        return jsonify({
            "success": False, 
            "error": f"Falha no comando docker {action}: {e.stderr}",
            "container": container_name
        }), 500

@app.route("/status_novidade")
def status_novidade():
    flag_path = "/var/www/html/radio/update_available.flag"
    if os.path.exists(flag_path):
        with open(flag_path, "r") as f:
            timestamp = f.read().strip()
        return jsonify({"novidade": True, "timestamp": timestamp})
    return jsonify({"novidade": False})

@app.route('/containers/status')
def containers_status():
    """Retorna o status de todos os containers mapeados"""
    status_all = {}
    for app_name, container_name in APP_TO_CONTAINER.items():
        status_all[app_name] = {
            "container": container_name,
            "running": get_container_status(container_name),
            "status": get_container_detailed_status(container_name)
        }
    
    return jsonify(status_all)

@app.route('/containers/logs/<container_name>')
def container_logs(container_name):
    """Retorna os últimos logs de um container"""
    lines = request.args.get('lines', '50')  # Default 50 linhas
    
    try:
        result = subprocess.run(
            ['docker', 'logs', '--tail', lines, container_name],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            return jsonify({
                "success": True,
                "logs": result.stdout,
                "container": container_name
            })
        else:
            return jsonify({
                "success": False,
                "error": result.stderr,
                "container": container_name
            }), 400
            
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e),
            "container": container_name
        }), 500

@app.route('/saldo/lightning')
def saldo_lightning():
    """Executa lncli dentro do container LND"""
    try:
        result = subprocess.run(
            ['docker', 'exec', 'lnd', 'lncli', 'walletbalance'],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return jsonify({'lightning_balance': result.stdout.strip()})
        else:
            return jsonify({'lightning_balance': f'Erro: {result.stderr}'})
    except Exception as e:
        return jsonify({'lightning_balance': f'Erro: {str(e)}'})


@app.route('/saldo/onchain')
def saldo_onchain():
    """Executa bitcoin-cli dentro do container Bitcoin"""
    try:
        result = subprocess.run(
            ['docker', 'exec', 'bitcoin', 'bitcoin-cli', '-datadir=/data/bitcoin', 'getbalance'],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return jsonify({'onchain_balance': result.stdout.strip()})
        else:
            return jsonify({'onchain_balance': f'Erro: {result.stderr}'})
    except Exception as e:
        return jsonify({'onchain_balance': f'Erro: {str(e)}'})


@app.route('/saldo/liquid')
def saldo_liquid():
    """Executa elements-cli dentro do container Elements"""
    try:
        result = subprocess.run(
            ['docker', 'exec', 'elements', 'elements-cli', 'getbalance'],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return jsonify({'liquid_balance': result.stdout.strip()})
        else:
            return jsonify({'liquid_balance': f'Erro: {result.stderr}'})
    except Exception as e:
        return jsonify({'liquid_balance': f'Erro: {str(e)}'})


@app.route('/lightning/invoice', methods=['POST'])
def criar_invoice():
    """Cria invoice usando lncli dentro do container"""
    valor = request.json.get("amount")
    if not valor:
        return jsonify({'error': 'amount não fornecido'}), 400

    try:
        result = subprocess.run(
            ['docker', 'exec', 'lnd', 'lncli', 'addinvoice', '--amt', str(valor)],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return jsonify({'invoice': result.stdout.strip()})
        else:
            return jsonify({'error': result.stderr}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/lightning/pay', methods=['POST'])
def pagar_invoice():
    """Paga invoice usando lncli dentro do container"""
    invoice = request.json.get("invoice")
    if not invoice:
        return jsonify({'error': 'invoice não fornecida'}), 400

    try:
        result = subprocess.run(
            ['docker', 'exec', 'lnd', 'lncli', 'payinvoice', invoice],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return jsonify({'pagamento': result.stdout.strip()})
        else:
            return jsonify({'error': result.stderr}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ===============================
# SISTEMA DE MONITORAMENTO EM TEMPO REAL
# ===============================

# Cache global para status dos containers
container_status_cache = {}
system_status_cache = {}
balance_cache = {}

# Thread de monitoramento em background
monitoring_thread = None
monitoring_active = False

def monitor_system_status():
    """Thread que monitora o sistema em tempo real e emite updates via WebSocket"""
    global monitoring_active
    
    while monitoring_active:
        try:
            # Monitora status dos containers
            new_container_status = {}
            status_changed = False
            
            for app_name, container_name in APP_TO_CONTAINER.items():
                current_status = {
                    "container": container_name,
                    "running": get_container_status(container_name),
                    "status": get_container_detailed_status(container_name)
                }
                
                # Verifica se houve mudança
                if app_name not in container_status_cache or container_status_cache[app_name] != current_status:
                    container_status_cache[app_name] = current_status
                    status_changed = True
                
                new_container_status[app_name] = current_status
            
            # Emite update se houve mudança
            if status_changed:
                socketio.emit('container_status_update', new_container_status)
                print(f"[WebSocket] Status dos containers atualizado")
            
            # Monitora status do sistema (CPU, RAM, etc.) a cada 10 segundos
            if int(time.time()) % 10 == 0:
                try:
                    system_info = get_system_info()
                    if system_info != system_status_cache:
                        system_status_cache.update(system_info)
                        socketio.emit('system_status_update', system_info)
                        print(f"[WebSocket] Status do sistema atualizado")
                except Exception as e:
                    print(f"Erro ao obter status do sistema: {e}")
            
            # Monitora saldos a cada 30 segundos
            if int(time.time()) % 30 == 0:
                balance_updates = {}
                for balance_type in ['lightning', 'onchain', 'liquid']:
                    try:
                        new_balance = get_balance(balance_type)
                        if balance_type not in balance_cache or balance_cache[balance_type] != new_balance:
                            balance_cache[balance_type] = new_balance
                            balance_updates[balance_type] = new_balance
                    except Exception as e:
                        print(f"Erro ao obter saldo {balance_type}: {e}")
                
                if balance_updates:
                    socketio.emit('balance_update', balance_updates)
                    print(f"[WebSocket] Saldos atualizados: {list(balance_updates.keys())}")
            
        except Exception as e:
            print(f"Erro no monitoramento: {e}")
        
        time.sleep(2)  # Verifica a cada 2 segundos (mais eficiente que 5)

def get_system_info():
    """Obtém informações do sistema via script status.sh"""
    try:
        user = os.environ.get("USER", "admin")
        script_path = f"/home/{user}/brlnfullauto/container/graphics/html/cgi-bin/status.sh"
        result = subprocess.run([script_path], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            info = {}
            for line in lines:
                if ':' in line:
                    key, value = line.split(':', 1)
                    info[key.strip().lower()] = value.strip()
            return info
    except Exception as e:
        print(f"Erro ao obter info do sistema: {e}")
    return {}

def get_balance(balance_type):
    """Obtém saldo específico"""
    try:
        if balance_type == 'lightning':
            result = subprocess.run(['docker', 'exec', 'lnd', 'lncli', 'walletbalance'], 
                                   capture_output=True, text=True, timeout=10)
        elif balance_type == 'onchain':
            result = subprocess.run(['docker', 'exec', 'bitcoin', 'bitcoin-cli', '-datadir=/data/bitcoin', 'getbalance'], 
                                   capture_output=True, text=True, timeout=10)
        elif balance_type == 'liquid':
            result = subprocess.run(['docker', 'exec', 'elements', 'elements-cli', 'getbalance'], 
                                   capture_output=True, text=True, timeout=10)
        else:
            return None
            
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception as e:
        print(f"Erro ao obter saldo {balance_type}: {e}")
    return None

# ===============================
# EVENTOS WEBSOCKET
# ===============================

@socketio.on('connect')
def handle_connect():
    """Cliente conectou - envia status atual"""
    print(f"[WebSocket] Cliente conectado: {request.sid}")
    
    # Envia status atual dos containers
    if container_status_cache:
        emit('container_status_update', container_status_cache)
    
    # Envia status atual do sistema
    if system_status_cache:
        emit('system_status_update', system_status_cache)
    
    # Envia saldos atuais
    if balance_cache:
        emit('balance_update', balance_cache)

@socketio.on('disconnect')
def handle_disconnect():
    """Cliente desconectou"""
    print(f"[WebSocket] Cliente desconectado: {request.sid}")

@socketio.on('request_status_update')
def handle_status_request():
    """Cliente solicitou atualização manual do status"""
    print(f"[WebSocket] Atualização manual solicitada por: {request.sid}")
    
    # Força atualização dos containers
    new_container_status = {}
    for app_name, container_name in APP_TO_CONTAINER.items():
        new_container_status[app_name] = {
            "container": container_name,
            "running": get_container_status(container_name),
            "status": get_container_detailed_status(container_name)
        }
    
    container_status_cache.update(new_container_status)
    emit('container_status_update', new_container_status)

@socketio.on('request_balance_update')
def handle_balance_request(data):
    """Cliente solicitou atualização manual de saldo específico"""
    balance_type = data.get('type', 'all')
    print(f"[WebSocket] Atualização de saldo solicitada: {balance_type}")
    
    if balance_type == 'all':
        balance_types = ['lightning', 'onchain', 'liquid']
    else:
        balance_types = [balance_type]
    
    balance_updates = {}
    for bt in balance_types:
        new_balance = get_balance(bt)
        if new_balance is not None:
            balance_cache[bt] = new_balance
            balance_updates[bt] = new_balance
    
    if balance_updates:
        emit('balance_update', balance_updates)

def start_monitoring():
    """Inicia o thread de monitoramento"""
    global monitoring_thread, monitoring_active
    
    if monitoring_thread is None or not monitoring_thread.is_alive():
        monitoring_active = True
        monitoring_thread = threading.Thread(target=monitor_system_status, daemon=True)
        monitoring_thread.start()
        print("[Sistema] Monitoramento em tempo real iniciado")

def stop_monitoring():
    """Para o thread de monitoramento"""
    global monitoring_active
    monitoring_active = False
    print("[Sistema] Monitoramento em tempo real parado")

if __name__ == '__main__':
    # Inicia o monitoramento em background
    start_monitoring()
    
    # Inicia o servidor Flask com SocketIO
    print("[Sistema] Iniciando servidor Flask com WebSockets na porta 5001")
    socketio.run(app, host='0.0.0.0', port=5001, debug=False)
