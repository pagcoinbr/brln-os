#!/bin/bash
echo "Content-type: application/json"
echo ""

cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "%"}')
ram_usage=$(free -h | awk '/Mem:/ {print $3 "/" $2}')

check_service() {
    systemctl is-active "$1" &>/dev/null && echo "ativo" || echo "inativo"
}

# Verifica a sincronização do blockchain e do gráfico
if command -v lncli &>/dev/null; then
    lncli_output=$(lncli getinfo 2>/dev/null)
    synced_to_chain=$(echo "$lncli_output" | grep -o '"synced_to_chain":[^,]*' | cut -d ':' -f2 | tr -d ' ')
    synced_to_graph=$(echo "$lncli_output" | grep -o '"synced_to_graph":[^,]*' | cut -d ':' -f2 | tr -d ' ')
else
    synced_to_chain="null"
    synced_to_graph="null"
fi

echo "{
    \"cpu\": \"$cpu_usage\",
    \"ram\": \"$ram_usage\",
    \"lnd\": \"$(check_service lnd)\",
    \"bitcoind\": \"$(check_service bitcoind)\",
    \"tor\": \"$(check_service tor)\",
    \"synced_to_chain\": $synced_to_chain,
    \"synced_to_graph\": $synced_to_graph
}"
