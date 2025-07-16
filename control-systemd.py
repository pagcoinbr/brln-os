from flask import Flask, request, jsonify
from flask_cors import CORS
import subprocess
import os


app = Flask(__name__)
CORS(app)  # <- liberação de CORS

# Mapeamento de apps para serviços systemd
APP_TO_SERVICE = {
    "control-systemd": "control-systemd.service",
    "gotty-fullauto": "gotty-fullauto.service",
    "gotty-logs-bitcoind": "gotty-logs-bitcoind.service",
    "gotty-logs-lnd": "gotty-logs-lnd.service",
}

# Função auxiliar para verificar o status do serviço usando docker ps
def get_service_status(service_name):
    try:
        # Remove a extensão .service do nome para usar como nome do container
        container_name = service_name.replace('.service', '')
        
        result = subprocess.run(
            ['docker', 'ps', '--filter', f'name={container_name}', '--format', '{{.Names}}'],
            capture_output=True,
            text=True
        )
        
        # Se o container aparecer na lista do docker ps, está ativo
        output = result.stdout.strip()
        if output and container_name in output:
            return True
        else:
            return False

    except Exception as e:
        # Se der qualquer erro no subprocess, é falso também
        return False

@app.route('/service-status')
def service_status():
    app_name = request.args.get('app')
    if not app_name or app_name not in APP_TO_SERVICE:
        return jsonify({"error": "App inválido ou não informado"}), 400

    service_name = APP_TO_SERVICE[app_name]
    is_active = get_service_status(service_name)
    return jsonify({"active": is_active})

@app.route('/toggle-service', methods=['POST'])
def toggle_service():
    app_name = request.args.get('app')
    if not app_name or app_name not in APP_TO_SERVICE:
        return jsonify({"error": "App inválido ou não informado"}), 400

    service_name = APP_TO_SERVICE[app_name]
    container_name = service_name.replace('.service', '')
    is_active = get_service_status(service_name)

    try:
        if is_active:
            # Parar o container
            subprocess.run(
                ['docker', 'stop', container_name],
                check=True,
                capture_output=True,
                text=True
            )
        else:
            # Iniciar o container
            subprocess.run(
                ['docker', 'start', container_name],
                check=True,
                capture_output=True,
                text=True
            )
        
        return jsonify({"success": True, "new_status": not is_active})
    except subprocess.CalledProcessError as e:
        return jsonify({"success": False, "error": e.stderr}), 500
    
@app.route("/status_novidade")
def status_novidade():
    flag_path = "/var/www/html/radio/update_available.flag"
    if os.path.exists(flag_path):
        with open(flag_path, "r") as f:
            timestamp = f.read().strip()
        return jsonify({"novidade": True, "timestamp": timestamp})
    return jsonify({"novidade": False})

@app.route('/wallet-balances')
def wallet_balances():
    """Endpoint para obter saldos das carteiras LND e Elements"""
    try:
        # Verificar se o cliente existe
        client_path = os.path.join(os.path.dirname(__file__), 'lnd_balance_client_v2.py')
        if not os.path.exists(client_path):
            return jsonify({"success": False, "error": "Cliente LND não encontrado"}), 404
        
        # Executar o cliente Python para obter saldos
        result = subprocess.run(
            ['python3', client_path],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=os.path.dirname(__file__)
        )
        
        if result.returncode == 0:
            # Parse da saída para extrair informações relevantes
            output_lines = result.stdout.strip().split('\n')
            
            # Extrair informações básicas (implementação simplificada)
            data = {
                "success": True,
                "timestamp": subprocess.run(['date', '+%Y-%m-%d %H:%M:%S'], 
                                          capture_output=True, text=True).stdout.strip(),
                "raw_output": result.stdout,
                "connections": {
                    "lnd": "✅ Conectado" in result.stdout,
                    "elements": "✅ Conectado" in result.stdout and "Elements" in result.stdout
                }
            }
            
            return jsonify(data)
        else:
            return jsonify({
                "success": False, 
                "error": result.stderr or "Erro ao executar cliente",
                "returncode": result.returncode
            }), 500
            
    except subprocess.TimeoutExpired:
        return jsonify({"success": False, "error": "Timeout ao executar cliente"}), 408
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/wallet-balances-json')
def wallet_balances_json():
    """Endpoint para obter saldos em formato JSON estruturado"""
    try:
        client_path = os.path.join(os.path.dirname(__file__), 'lnd_balance_client_v2.py')
        if not os.path.exists(client_path):
            return jsonify({"success": False, "error": "Cliente LND não encontrado"}), 404
        
        # Executar cliente com flag --json (a ser implementada)
        result = subprocess.run(
            ['python3', client_path],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=os.path.dirname(__file__)
        )
        
        if result.returncode == 0:
            return jsonify({
                "success": True,
                "data": {
                    "output": result.stdout,
                    "timestamp": subprocess.run(['date', '+%Y-%m-%d %H:%M:%S'], 
                                              capture_output=True, text=True).stdout.strip()
                }
            })
        else:
            return jsonify({
                "success": False, 
                "error": result.stderr,
                "returncode": result.returncode
            }), 500
            
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)


