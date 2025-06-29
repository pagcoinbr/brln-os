#!/bin/bash
echo "Content-type: text/plain"
echo ""

cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "%"}')
ram_usage=$(free -h | awk '/Mem:/ {print $3 "/" $2}')

check_service() {
    systemctl is-active "$1" &>/dev/null && echo "ativo" || echo "inativo"
}

echo "CPU: $cpu_usage"
echo "RAM: $ram_usage"
echo "LND: $(check_service lnd)"
echo "Bitcoind: $(check_service bitcoind)"
echo "Elementsd: $(check_service elementsd)"
echo "Tor: $(check_service tor)"

# Verifica se bitcoind.rpchost está ativo ou comentado
CONF_PATH="/data/lnd/lnd.conf"
if grep -q "^bitcoind.rpchost=bitcoin.br-ln.com:8085" "$CONF_PATH"; then
    echo "Blockchain: Remoto"
elif grep -q "^#bitcoind.rpchost=bitcoin.br-ln.com:8085" "$CONF_PATH"; then
    echo "Blockchain: Local"
else
    echo "Blockchain: Desconhecida"
fi
