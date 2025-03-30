#!/bin/bash
echo "Content-type: application/json"
echo ""

read -r POST_DATA

acao=$(echo "$POST_DATA" | grep -oP '(?<="acao":")[^"]+')

case "$acao" in
    restart-lnd)
        systemctl restart lnd && echo '{"resultado":"LND reiniciado."}' || echo '{"resultado":"Erro ao reiniciar LND."}'
        ;;
    restart-bitcoind)
        systemctl restart bitcoind && echo '{"resultado":"Bitcoind reiniciado."}' || echo '{"resultado":"Erro ao reiniciar Bitcoind."}'
        ;;
    restart-tor)
        systemctl restart tor && echo '{"resultado":"Tor reiniciado."}' || echo '{"resultado":"Erro ao reiniciar Tor."}'
        ;;
    editar-lndconf)
        nano /home/admin/.lnd/lnd.conf  # ou abrir com alguma interface web se quiser algo mais visual
        echo '{"resultado":"Editor de lnd.conf iniciado (no terminal)."}'
        ;;
    abrir-ssh)
        x-terminal-emulator -e "ssh admin@minibolt" &> /dev/null &
        echo '{"resultado":"Tentando abrir terminal SSH..."}'
        ;;
    *)
        echo '{"resultado":"Ação não reconhecida."}'
        ;;
esac
