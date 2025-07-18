#! /bin/bash
local user="$1"
local pass="$2"
local bitcoin_conf="bitcoin/bitcoin.conf.example"
local lnd_conf="lnd/lnd.conf.example"

log "📝 Configurando bitcoin.conf..."
echo "Você deseja conectar mainnet ou testnet com o sistema?"
warning "⚠️ A configuração testnet somente pode ser utilizado com conexão com Bitcoin Node local."
read -p "Digite 'mainnet' ou 'testnet': " network_choice

# Determinar qual arquivo exemplo usar baseado na escolha da rede
local example_file
if [[ "$network_choice" == "testnet" ]]; then
    example_file="bitcoin/bitcoin.conf.testnet.example"
    example_file2="lnd/lnd.conf.example.local"
else
    example_file="bitcoin/bitcoin.conf.mainnet.example"
fi

# Verificar se o arquivo exemplo existe
if [[ ! -f "$example_file" ]]; then
    error "Arquivo exemplo não encontrado: $example_file"
    return 1
fi

# Copiar o arquivo exemplo apropriado para bitcoin.conf
cp "$example_file" "$bitcoin_conf"
if [[ "$network_choice" == "testnet" ]]; then

    cp "$example_file2" "$lnd_conf"
    log "Arquivo lnd.conf criado a partir de $example_file2 por testnet só permitir com conexão local"
else
    example_file="bitcoin/bitcoin.conf.mainnet.example"
fi
log "Arquivo bitcoin.conf criado a partir de $example_file"

# Gerar rpcauth usando rpcauth.py
cd bitcoin
rpcauth_output=$(python3 rpcauth.py brlnbitcoin)
cd - > /dev/null

# Extrair rpcauth line do output
rpcauth_line=$(echo "$rpcauth_output" | grep "^rpcauth=")

# Atualizar credenciais no bitcoin.conf
sed -i "s/^rpcauth=.*/$rpcauth_line/g" "$bitcoin_conf"

log "✅ bitcoin.conf configurado com sucesso!"