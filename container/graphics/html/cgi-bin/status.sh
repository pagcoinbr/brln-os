#!/bin/bash
echo "Content-type: text/plain"
echo ""

cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "%"}')
ram_usage=$(free -h | awk '/Mem:/ {print $3 "/" $2}')

# Função para verificar status de container Docker
check_container() {
    local container_name="$1"
    if docker inspect "$container_name" &>/dev/null; then
        if docker inspect -f '{{.State.Running}}' "$container_name" | grep -q true; then
            echo "ativo"
        else
            echo "parado"
        fi
    else
        echo "inexistente"
    fi
}

echo "CPU: $cpu_usage"
echo "RAM: $ram_usage"
echo "LND: $(check_container lnd)"
echo "Bitcoind: $(check_container bitcoin)"
echo "Elementsd: $(check_container elements)"
echo "Tor: $(check_container tor)"

# Verifica se bitcoind.rpchost está ativo ou comentado
CONF_PATH="/data/lnd/lnd.conf"
if [ -f "$CONF_PATH" ]; then
    if grep -q "^bitcoind.rpchost=REDACTED_HOST:8085" "$CONF_PATH"; then
        echo "Blockchain: Remoto"
    elif grep -q "^#bitcoind.rpchost=REDACTED_HOST:8085" "$CONF_PATH"; then
        echo "Blockchain: Local"
    else
        echo "Blockchain: Desconhecida"
    fi
else
    echo "Blockchain: Configuração não encontrada"
fi
