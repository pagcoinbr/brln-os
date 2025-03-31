#!/bin/bash
echo "Content-type: text/plain"
echo ""

read -r POST_DATA
acao=$(echo "$POST_DATA" | grep -oP '(?<="acao":")[^"]+')

case "$acao" in
    log-lnd)
        journalctl -u lnd -n 50 --no-pager 2>/dev/null
        ;;
    log-bitcoind)
        journalctl -u bitcoind -n 50 --no-pager 2>/dev/null
        ;;
    log-tor)
        journalctl -u tor -n 50 --no-pager 2>/dev/null
        ;;
    update-lnd)
        OUT=$(sudo /usr/local/bin/update-lnd.sh 2>&1)
        echo "{\"log\": \"$(echo "$OUT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\\n/\\\\n/g')\"}"
        ;;
    toggle-bitcoin)
        OUT=$(sudo /usr/local/bin/toggle_bitcoin.sh 2>&1)
        echo "$OUT"
        ;;
    *)
        echo "Ação não reconhecida."
        ;;
esac
