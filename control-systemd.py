from flask import Flask, request, jsonify
from flask_cors import CORS
import subprocess
import os


app = Flask(__name__)
CORS(app)  # <- liberação de CORS

# Mapeamento de apps para serviços systemd
APP_TO_SERVICE = {
    "peerswap": "peerswapd.service",
    "lnbits": "lnbits.service",
    "thunderhub": "thunderhub.service",
    "simple": "simple-lnwallet.service",
    "lndg": "lndg.service",
    "lndg-controller": "lndg-controller.service",
    "lnd": "lnd.service",
    "bitcoind": "bitcoind.service",
    "elementsd": "elementsd.service",
    "bos-telegram": "bos-telegram.service",
    "tor": "tor.service",
}

# Função auxiliar para verificar o status do serviço
def get_service_status(service_name):
    try:
        result = subprocess.run(
            ['/usr/bin/systemctl', 'is-active', service_name],
            capture_output=True,
            text=True
        )
        status = result.stdout.strip().lower()

        # Vamos considerar apenas "active" como verdadeiro
        if status == "active":
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
    is_active = get_service_status(service_name)

    action = "stop" if is_active else "start"

    try:
        subprocess.run(
            ['/usr/bin/sudo', '/usr/bin/systemctl', action, service_name],
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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)


