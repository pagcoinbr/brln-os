#!/bin/bash
echo "Content-type: application/json"
echo ""

cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "%"}')
ram_usage=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
check_service() {
    systemctl is-active "$1" &>/dev/null && echo "🟢 ativo" || echo "🔴 inativo"
}

echo "{
    \"cpu\": \"$cpu_usage\",
    \"ram\": \"$ram_usage\",
    \"lnd\": \"$(check_service lnd)\",
    \"bitcoind\": \"$(check_service bitcoind)\",
    \"tor\": \"$(check_service tor)\"
}"
