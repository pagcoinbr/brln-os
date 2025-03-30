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
    *)
        echo "Ação não reconhecida."
        ;;
esac
