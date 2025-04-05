#!/bin/bash
echo "Content-type: application/json"
echo ""

cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "%"}')
ram_usage=$(free -h | awk '/Mem:/ {print $3 "/" $2}')

check_service() {
    systemctl is-active "$1" &>/dev/null && echo "ativo" || echo "inativo"
}

# Caminho absoluto para o lncli
lncli_bin="/usr/local/bin/lncli"

# Valores padrão
synced_to_chain=false
synced_to_graph=false

# Verifica se lncli está acessível e executa corretamente
if [ -x "$lncli_bin" ]; then
    lncli_output=$("$lncli_bin" getinfo 2>/dev/null)

    # Se tiver jq instalado, usa ele (recomendado)
    if command -v jq &>/dev/null; then
        synced_to_chain=$(echo "$lncli_output" | jq -r '.synced_to_chain // false')
        synced_to_graph=$(echo "$lncli_output" | jq -r '.synced_to_graph // false')
    else
        # Alternativa usando grep/cut (menos confiável)
        synced_to_chain=$(echo "$lncli_output" | grep -o '"synced_to_chain":[^,]*' | cut -d ':' -f2 | tr -d ' ')
        synced_to_graph=$(echo "$lncli_output" | grep -o '"synced_to_graph":[^,]*' | cut -d ':' -f2 | tr -d ' ')
        [[ -z "$synced_to_chain" ]] && synced_to_chain=false
        [[ -z "$synced_to_graph" ]] && synced_to_graph=false
    fi
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
