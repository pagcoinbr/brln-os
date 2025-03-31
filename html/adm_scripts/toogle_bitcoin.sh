#!/bin/bash
LND_CONF="/home/admin/.lnd/lnd.conf"
FILES=(
    "/home/admin/.lnd/tls.cert"
    "/home/admin/.lnd/tls.key"
    "/home/admin/.lnd/v3_onion_private_key"
)

# Verifica se as linhas estão comentadas (modo local)
if sed -n '73,78p' "$LND_CONF" | grep -q '^#'; then
    MODE="remote"
    sed -i '73,78 s/^#//' "$LND_CONF"
else
    MODE="local"
    sed -i '73,78 s/^/#/' "$LND_CONF"
fi

for file in "${FILES[@]}"; do
    [ -f "$file" ] && rm -f "$file"
done

sudo systemctl restart lnd

echo "{\"modo\": \"$MODE\"}"
