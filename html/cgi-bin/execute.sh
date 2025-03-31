#!/bin/bash
echo "Content-type: text/plain"
echo ""

read -r POST_DATA
acao=$(echo "$POST_DATA" | grep -oP '(?<="acao":")[^"]+')

case "$acao" in
    update-lnd)
        OUT=$(sudo /usr/local/bin/update_lnd.sh 2>&1)
        ;;
    update-lndg)
        OUT=$(sudo /usr/local/bin/update-lndg.sh 2>&1)
        ;;
    update-thunderhub)
        OUT=$(sudo /usr/local/bin/update-thunderhub.sh 2>&1)
        ;;
    update-bitcoind)
        OUT=$(sudo /usr/local/bin/update_bitcoind.sh 2>&1)
        ;;
    update-lnbits)
        OUT=$(sudo /usr/local/bin/update_lnbits.sh 2>&1)
        ;;
    update-apt)
        OUT=$(sudo /usr/local/bin/update_apt.sh 2>&1)
        ;;
    toogle-bitcoin)
        OUT=$(sudo /usr/local/bin/toogle_bitcoin.sh 2>&1)
        ;;
    uninstall)
        OUT=$(sudo /usr/local/bin/uninstall.sh 2>&1)
        ;;
    *)
        echo "Ação não reconhecida."
        ;;
esac

echo "{\"log\": \"$(echo "$OUT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')\"}"
