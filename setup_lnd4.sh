#!/bin/bash

# Cria links simbólicos
ln -s /data/lnd /home/lnd/.lnd
ln -s /data/bitcoin /home/lnd/.bitcoin

# Lista os arquivos e diretórios com detalhes
ls -la

# Exibe aviso ao usuário sobre a senha
echo "AVISO: Salve a senha que você escolher para a carteira Lightning. Caso contrário, você pode perder seus fundos. A senha deve ter pelo menos 8 caracteres."

# Solicita a senha ao usuário
while true; do
    read -s -p "Escolha uma senha para a carteira Lightning: " password
    echo
    if [ ${#password} -ge 8 ]; then
        break
    else
        echo "A senha deve ter pelo menos 8 caracteres. Tente novamente."
    fi
done

# Salva a senha no arquivo password.txt
echo "$password" > /data/lnd/password.txt

# Define permissões adequadas para o arquivo de senha
chmod 600 /data/lnd/password.txt

# Solicita ao usuário as variáveis necessárias
read -p "Digite o alias: " alias
read -p "Digite o bitcoind.rpchost: " bitcoind_rpchost
read -p "Digite o bitcoind.rpcuser: " bitcoind_rpcuser
read -s -p "Digite o bitcoind.rpcpass: " bitcoind_rpcpass
echo
read -p "Digite o bitcoind.zmqpubrawblock: " bitcoind_zmqpubrawblock
read -p "Digite o bitcoind.zmqpubrawtx: " bitcoind_zmqpubrawtx

# Cria o arquivo de configuração lnd.conf
cat << EOF > /data/lnd/lnd.conf
# MiniBolt: lnd configuration
# /data/lnd/lnd.conf

[Application Options]
# Up to 32 UTF-8 characters, accepts emojis i.e ⚡🧡​ https://emojikeyboard.top/
alias=$alias
# You can choose the color you want at https://www.color-hex.com/
color=#ff9900

# Automatically unlock wallet with the password in this file
wallet-unlock-password-file=/data/lnd/password.txt
wallet-unlock-allow-create=true

# The TLS private key will be encrypted to the node's seed
tlsencryptkey=true

# Automatically regenerate certificate when near expiration
tlsautorefresh=true

# Do not include the interface IPs or the system hostname in TLS certificate
tlsdisableautofill=true

## Channel settings
# (Optional) Minimum channel size. Uncomment and set whatever you want
# (default: 20000 sats)
#minchansize=20000

## High fee environment (Optional)
# (default: 10 sat/byte)
#max-commit-fee-rate-anchors=50
#max-channel-fee-allocation=1

## Communication
accept-keysend=true
accept-amp=true

## Rebalancing
allow-circular-route=true

## Performance
gc-canceled-invoices-on-startup=true
gc-canceled-invoices-on-the-fly=true
ignore-historical-gossip-filters=true

[Bitcoin]
bitcoin.mainnet=true
bitcoin.node=bitcoind

# Fee settings - default LND base fee = 1000 (mSat), fee rate = 1 (ppm)
# You can choose whatever you want e.g ZeroFeeRouting (0,0) or ZeroBaseFee (0,X)
#bitcoin.basefee=1000
#bitcoin.feerate=1

# The CLTV delta we will subtract from a forwarded HTLC's timelock value
# (default: 80)
#bitcoin.timelockdelta=144

[Bitcoind]
bitcoind.rpchost=$bitcoind_rpchost
bitcoind.rpcuser=$bitcoind_rpcuser
bitcoind.rpcpass=$bitcoind_rpcpass
bitcoind.zmqpubrawblock=$bitcoind_zmqpubrawblock
bitcoind.zmqpubrawtx=$bitcoind_zmqpubrawtx

[protocol]
protocol.wumbo-channels=true
protocol.option-scid-alias=true
protocol.simple-taproot-chans=true

[wtclient]
## Watchtower client settings
wtclient.active=true

# (Optional) Specify the fee rate with which justice transactions will be signed
# (default: 10 sat/byte)
#wtclient.sweep-fee-rate=10

[watchtower]
## Watchtower server settings
watchtower.active=true

[routing]
routing.strictgraphpruning=true

[bolt]
## Database
# Set the next value to false to disable auto-compact DB
# and fast boot and comment the next line
db.bolt.auto-compact=true
# Uncomment to do DB compact at every LND reboot (default: 168h)
#db.bolt.auto-compact-min-age=0h

## High fee environment (Optional)
# (default: CONSERVATIVE) Uncomment the next 2 lines
#[Bitcoind]
#bitcoind.estimatemode=ECONOMICAL

[tor]
tor.active=true
tor.v3=true
tor.streamisolation=true
EOF

echo "Configuração concluída com sucesso!"
