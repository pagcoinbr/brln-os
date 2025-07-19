#!/bin/bash

# Source das funções básicas
source "$(dirname "$0")/.env"
basics

app="lnd"
REPO_DIR="/root/brln-os"

# Função para escolher a rede Bitcoin
choose_bitcoin_network() {
    echo ""
    info "═══════════════════════════════════════════════════════════════"
    log "🔗 Escolha da Rede Bitcoin"
    info "═══════════════════════════════════════════════════════════════"
    echo ""
    
    info "Escolha qual rede Bitcoin você deseja usar:"
    echo ""
    echo "1. 🧪 TESTNET (Recomendado para testes)"
    echo "   • Rede de teste do Bitcoin"
    echo "   • Bitcoins não têm valor real"
    echo "   • Perfeito para aprendizado e testes"
    echo "   • Sincronização mais rápida"
    echo ""
    echo "2. 💰 MAINNET (Rede principal)"
    echo "   • Rede principal do Bitcoin"
    echo "   • Bitcoins têm valor real"
    echo "   • Requer maior cuidado com segurança"
    echo "   • Sincronização mais lenta"
    echo ""
    
    while true; do
        read -p "Escolha a rede (1 para TESTNET, 2 para MAINNET) [1]: " -n 1 -r
        echo
        
        case $REPLY in
            "1"|"" ) 
                export BITCOIN_NETWORK="testnet"
                log "🧪 Rede TESTNET selecionada"
                echo ""
                info "Você escolheu a rede TESTNET:"
                echo "• Os bitcoins não têm valor monetário real"
                echo "• Perfeito para testes e aprendizado"
                echo "• Transações mais rápidas e baratas"
                break
                ;;
            "2" )
                export BITCOIN_NETWORK="mainnet"
                log "💰 Rede MAINNET selecionada"
                echo ""
                warning "⚠️  ATENÇÃO: Você escolheu a rede MAINNET!"
                warning "• Os bitcoins têm valor monetário REAL"
                warning "• Mantenha suas chaves privadas SEGURAS"
                warning "• Faça backup da sua seed phrase"
                echo ""
                read -p "Você tem certeza que deseja usar MAINNET? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    break
                else
                    echo "Voltando para seleção de rede..."
                    echo ""
                    continue
                fi
                ;;
            * )
                echo "Por favor, escolha 1 para TESTNET ou 2 para MAINNET."
                ;;
        esac
    done
    
    # Salvar a escolha da rede em um arquivo para o docker-compose usar
    echo "BITCOIN_NETWORK=$BITCOIN_NETWORK" > "$REPO_DIR/container/.env"
    log "✅ Configuração de rede salva em .env"
    echo ""
}

brln_credentials() {
    echo ""
    log "🔑 Configuração das credenciais BRLN Club"
    echo ""
    
    # Solicitar credenciais
    echo "Digite as credenciais fornecidas pela BRLN Club:"
    echo ""
    
    while true; do
        read -p "👤 Usuário RPC: " brln_rpc_user
        if [[ -n "$brln_rpc_user" ]]; then
            break
        else
            error "Usuário não pode estar vazio!"
        fi
    done
    
    while true; do
        read -p "🔐 Senha RPC: " brln_rpc_pass
        echo
        if [[ -n "$brln_rpc_pass" ]]; then
            break
        else
            error "Senha não pode estar vazia!"
        fi
    done
    
    echo ""
    log "✅ Credenciais capturadas com sucesso!"
    
    # Ir para o diretório do repositório para as configurações
    cd "$REPO_DIR"
    
    # Configurar arquivos
    configure_lnd_conf_remote "$brln_rpc_user" "$brln_rpc_pass"
    configure_elements_remote "$brln_rpc_user" "$brln_rpc_pass"
    
    # Salvar credenciais RPC no arquivo .env para o container LND
    echo "BITCOIN_RPC_USER=$brln_rpc_user" >> "$REPO_DIR/container/.env"
    echo "BITCOIN_RPC_PASS=$brln_rpc_pass" >> "$REPO_DIR/container/.env"
    log "✅ Credenciais RPC salvas no arquivo .env"
    
    log "🎯 Configuração remota concluída!"
    echo ""
    info "Os arquivos foram configurados para usar a blockchain remota da BRLN Club."
    warning "⚠️  Certifique-se de que as credenciais estão corretas antes de iniciar os containers."
    echo ""
}

# Função para configurar credenciais locais
local_credentials() {
    echo ""
    log "🔑 Configuração das credenciais para Bitcoin Node Local"
    echo ""
    
    # Solicitar usuário e senha RPC
    echo "Configure as credenciais RPC para o Bitcoin Core local:"
    echo ""
    
    while true; do
        read -p "👤 Nome de usuário RPC (ex: btcuser): " local_rpc_user
        if [[ -n "$local_rpc_user" ]]; then
            break
        else
            error "Usuário não pode estar vazio!"
        fi
    done
    
    while true; do
        read -p "🔐 Senha RPC: " local_rpc_pass
        echo
        if [[ -n "$local_rpc_pass" ]]; then
            break
        else
            error "Senha não pode estar vazia!"
        fi
    done
    
    echo ""
    log "🔧 Gerando rpcauth usando rpcauth.py..."
    
    # Gerar rpcauth usando o rpcauth.py
    cd "$REPO_DIR/container/bitcoin"
    rpcauth_output=$(python3 rpcauth.py "$local_rpc_user" "$local_rpc_pass" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        # Extrair apenas a linha rpcauth= do output
        rpcauth_line=$(echo "$rpcauth_output" | grep "^rpcauth=")
        log "✅ rpcauth gerado com sucesso!"
        
        # Voltar para o diretório do repositório para as configurações
        cd "$REPO_DIR"
        
        # Salvar credenciais RPC no arquivo .env para uso do container
        echo "BITCOIN_RPC_USER=$local_rpc_user" >> "$REPO_DIR/container/.env"
        echo "BITCOIN_RPC_PASS=$local_rpc_pass" >> "$REPO_DIR/container/.env"
        log "✅ Credenciais RPC salvas no arquivo .env"
        
        # Configurar arquivos
        configure_bitcoin_conf "$rpcauth_line"
        configure_lnd_conf_local "$local_rpc_user" "$local_rpc_pass"
        configure_elements_local "$local_rpc_user" "$local_rpc_pass"
        
        # Salvar credenciais RPC no arquivo .env para o container LND
        echo "BITCOIN_RPC_USER=$local_rpc_user" >> "$REPO_DIR/container/.env"
        echo "BITCOIN_RPC_PASS=$local_rpc_pass" >> "$REPO_DIR/container/.env"
        log "✅ Credenciais RPC salvas no arquivo .env"
        
        log "🎯 Configuração local concluída!"
        echo ""
        info "Os arquivos foram configurados para usar o Bitcoin Node local."
        warning "⚠️  O Bitcoin Core precisará sincronizar a blockchain completa."
        echo ""
    else
        error "❌ Erro ao gerar rpcauth. Verifique se o Python3 está instalado."
        exit 1
    fi
}
# Função para configurar blockchain remota
configure_remote_blockchain() {
    
    # Primeiro, escolher a rede
    choose_bitcoin_network
    echo ""
    info "═══════════════════════════════════════════════════════════════"
    log "🔗 Configuração da Fonte Blockchain"
    info "═══════════════════════════════════════════════════════════════"
    echo ""
    
    warning "⚠️  ATENÇÃO: Se você escolheu a rede TESTNET e esta configuração apenas permite conexão com bitcoin node local!"
    echo ""
    
    info "Escolha a fonte da blockchain que deseja usar:"
    echo ""
    echo "y. ☁️  Blockchain Remota BRLN Club"
    echo "   • Conecta ao node Bitcoin da BRLN Club"
    echo "   • Sincronização mais rápida"
    echo "   • Requer credenciais da BRLN Club"
    echo ""
    echo "n. 🏠 Blockchain Local (Padrão)"
    echo "   • Sincronização completa da blockchain Bitcoin"
    echo "   • Maior privacidade e controle total"
    echo "   • Requer mais tempo e espaço em disco"
    echo ""
    
    # Mudar para o diretório do repositório para as configurações
    cd "$REPO_DIR"
    
    while true; do
        read -p "Deseja usar a blockchain remota da BRLN Club? (y/N): " -n 1 -r
        echo
        case $REPLY in
            [Yy]* )
                log "📡 Configurando conexão com blockchain remota BRLN Club..."
                brln_credentials
                break
                ;;
            [Nn]* | "" )
                log "🏠 Usando blockchain local (configuração padrão)"
                info "A sincronização da blockchain Bitcoin será realizada localmente."
                warning "⚠️  Isso pode levar várias horas para sincronizar completamente."
                local_credentials
                break
                ;;
            * )
                echo "Por favor, responda y (sim) ou n (não)."
                ;;
        esac
    done
}

configure_elements_remote() {
    local user="$1"
    local pass="$2"
    local elements_conf="container/elements/elements.conf"
    
    log "📝 Configurando elements.conf para conexão remota..."
    
    # Verificar se o arquivo existe
    if [[ ! -f "$elements_conf" ]]; then
        # Copiar do exemplo se não existir
        if [[ -f "container/elements/elements.conf.example" ]]; then
            cp "container/elements/elements.conf.example" "$elements_conf"
            log "Arquivo elements.conf criado a partir do exemplo"
        else
            error "Arquivo elements.conf.example não encontrado!"
            return 1
        fi
    fi
    
    # Atualizar credenciais para conexão remota
    sed -i "s/mainchainrpcuser=<brln_rpc_user>/mainchainrpcuser=$user/g" "$elements_conf"
    sed -i "s/mainchainrpcpassword=<brln_rpc_pass>/mainchainrpcpassword=$pass/g" "$elements_conf"
    
    log "✅ elements.conf configurado para conexão remota!"
}

# Função para configurar elements.conf para conexão local
configure_elements_local() {
    local user="$1"
    local pass="$2"
    local elements_conf="container/elements/elements.conf"
    
    log "📝 Configurando elements.conf para conexão local..."
    
    # Verificar se o arquivo existe
    if [[ ! -f "$elements_conf" ]]; then
        # Copiar do exemplo se não existir
        if [[ -f "container/elements/elements.conf.example" ]]; then
            cp "container/elements/elements.conf.example" "$elements_conf"
            log "Arquivo elements.conf criado a partir do exemplo"
        else
            error "Arquivo elements.conf.example não encontrado!"
            return 1
        fi
    fi
    
    # Configurar para conexão local - atualizar host e credenciais
    sed -i "s/mainchainrpchost=bitcoin.br-ln.com/mainchainrpchost=bitcoin/g" "$elements_conf"
    sed -i "s/mainchainrpcport=8085/mainchainrpcport=8332/g" "$elements_conf"
    sed -i "s/mainchainrpcuser=<brln_rpc_user>/mainchainrpcuser=$user/g" "$elements_conf"
    sed -i "s/mainchainrpcpassword=<brln_rpc_pass>/mainchainrpcpassword=$pass/g" "$elements_conf"
    
    log "✅ elements.conf configurado para conexão local!"
}

configure_lnd_conf_remote() {
    local user="$1"
    local pass="$2"
    local lnd_conf="container/lnd/lnd.conf"
    
    log "📝 Configurando lnd.conf para conexão remota ($BITCOIN_NETWORK)..."
    
    # Verificar se o arquivo existe
    if [[ ! -f "$lnd_conf" ]]; then
        # Copiar do exemplo remoto se não existir
        if [[ -f "container/lnd/lnd.conf.example.remote" ]]; then
            cp "container/lnd/lnd.conf.example.remote" "$lnd_conf"
            log "Arquivo lnd.conf criado a partir do exemplo remoto"
        else
            error "Arquivo lnd.conf.example.remote não encontrado!"
            return 1
        fi
    fi
    
    # Atualizar credenciais para conexão remota
    sed -i "s/bitcoind.rpcuser=<brln_rpc_user>/bitcoind.rpcuser=$user/g" "$lnd_conf"
    sed -i "s/bitcoind.rpcpass=<brln_rpc_pass>/bitcoind.rpcpass=$pass/g" "$lnd_conf"
    
    # Configurar para a rede escolhida
    if [[ "$BITCOIN_NETWORK" == "mainnet" ]]; then
        log "Configurando LND para MAINNET remota..."
        sed -i 's/bitcoin.mainnet=false/bitcoin.mainnet=true/' "$lnd_conf"
        sed -i 's/bitcoin.testnet=true/bitcoin.testnet=false/' "$lnd_conf"
        # Portas para mainnet (as portas remotas já devem estar corretas no template)
    else
        log "Configurando LND para TESTNET remota..."
        sed -i 's/bitcoin.mainnet=true/bitcoin.mainnet=false/' "$lnd_conf"
        sed -i 's/bitcoin.testnet=false/bitcoin.testnet=true/' "$lnd_conf"
        # Portas para testnet (as portas remotas já devem estar corretas no template)
    fi
    
    log "✅ lnd.conf configurado para conexão remota ($BITCOIN_NETWORK)!"
}

# Função para configurar lnd.conf para conexão local
configure_lnd_conf_local() {
    local user="$1"
    local pass="$2"
    local lnd_conf="container/lnd/lnd.conf"
    
    log "📝 Configurando lnd.conf para conexão local ($BITCOIN_NETWORK)..."
    
    # Verificar se o arquivo existe
    if [[ ! -f "$lnd_conf" ]]; then
        # Copiar do exemplo local se não existir
        if [[ -f "container/lnd/lnd.conf.example.local" ]]; then
            cp "container/lnd/lnd.conf.example.local" "$lnd_conf"
            log "Arquivo lnd.conf criado a partir do exemplo local"
        else
            error "Arquivo lnd.conf.example.local não encontrado!"
            return 1
        fi
    fi
    
    # Atualizar credenciais para conexão local
    sed -i "s/<seu_user_rpc>/$user/g" "$lnd_conf"
    sed -i "s/<sua_senha_rpc>/$pass/g" "$lnd_conf"
    
    # Substituir a variável ${network} com o valor correto da rede
    if [[ "$BITCOIN_NETWORK" == "mainnet" ]]; then
        sed -i "s/\${network}/mainnet/g" "$lnd_conf"
    else
        sed -i "s/\${network}/testnet/g" "$lnd_conf"
    fi
    
    # Configurar para a rede escolhida
    if [[ "$BITCOIN_NETWORK" == "mainnet" ]]; then
        log "Configurando LND para MAINNET local..."
        sed -i 's/bitcoin.mainnet=false/bitcoin.mainnet=true/' "$lnd_conf"
        sed -i 's/bitcoin.testnet=true/bitcoin.testnet=false/' "$lnd_conf"
        # Ajustar portas ZMQ para mainnet
        sed -i "s/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28432/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28332/" "$lnd_conf" 2>/dev/null || true
        sed -i "s/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28433/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28333/" "$lnd_conf" 2>/dev/null || true
    else
        log "Configurando LND para TESTNET local..."
        sed -i 's/bitcoin.mainnet=true/bitcoin.mainnet=false/' "$lnd_conf"
        sed -i 's/bitcoin.testnet=false/bitcoin.testnet=true/' "$lnd_conf"
        # Ajustar portas ZMQ para testnet
        sed -i "s/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28332/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28432/" "$lnd_conf" 2>/dev/null || true
        sed -i "s/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28333/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28433/" "$lnd_conf" 2>/dev/null || true
    fi
    
    log "✅ lnd.conf configurado para conexão local ($BITCOIN_NETWORK)!"
}

# Função para configurar bitcoin.conf com rpcauth
configure_bitcoin_conf() {
    local rpcauth_line="$1"
    
    log "📝 Configurando arquivos bitcoin.conf para $BITCOIN_NETWORK..."
    
    # Escolher o arquivo correto baseado na rede
    if [[ "$BITCOIN_NETWORK" == "mainnet" ]]; then
        local bitcoin_conf="container/bitcoin/bitcoin.conf.mainnet.example"
        local target_conf="container/bitcoin/bitcoin.conf"
        
        if [[ -f "$bitcoin_conf" ]]; then
            # Copiar o template mainnet para o arquivo final
            cp "$bitcoin_conf" "$target_conf"
            # Substituir a linha rpcauth
            sed -i "s/^rpcauth=.*/$rpcauth_line/" "$target_conf"
            log "✅ bitcoin.conf configurado para MAINNET!"
        else
            warning "⚠️  Arquivo bitcoin.conf.mainnet.example não encontrado!"
            return 1
        fi
    else
        local bitcoin_conf="container/bitcoin/bitcoin.conf.testnet.example"
        local target_conf="container/bitcoin/bitcoin.conf"
        
        if [[ -f "$bitcoin_conf" ]]; then
            # Copiar o template testnet para o arquivo final
            cp "$bitcoin_conf" "$target_conf"
            # Substituir a linha rpcauth
            sed -i "s/^rpcauth=.*/$rpcauth_line/" "$target_conf"
            log "✅ bitcoin.conf configurado para TESTNET!"
        else
            warning "⚠️  Arquivo bitcoin.conf.testnet.example não encontrado!"
            return 1
        fi
    fi
}

# Função para verificar sincronização do Bitcoin Core
check_bitcoin_sync() {
    log "🔍 Verificando sincronização do Bitcoin Core..."

    sleep 10 & spinner
    
    # Tentar conectar e verificar status de sincronização
    MAX_SYNC_ATTEMPTS=10
    sync_attempt=1
    
    while [[ $sync_attempt -le $MAX_SYNC_ATTEMPTS ]]; do
        log "Tentativa $sync_attempt de $MAX_SYNC_ATTEMPTS para verificar sincronização..."
        
        # Tentar obter informações da blockchain via RPC
        sync_info=$(docker exec bitcoin bitcoin-cli getblockchaininfo 2>/dev/null | grep -E '"initialblockdownload"|"verificationprogress"' 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$sync_info" ]]; then
            # Extrair valores usando grep e cut
            initial_download=$(echo "$sync_info" | grep "initialblockdownload" | cut -d':' -f2 | tr -d ' ,')
            verification_progress=$(echo "$sync_info" | grep "verificationprogress" | cut -d':' -f2 | tr -d ' ,')
            
            # Converter progresso para porcentagem
            if [[ -n "$verification_progress" ]]; then
                progress_percent=$(echo "$verification_progress * 100" | bc -l 2>/dev/null | cut -d'.' -f1)
                if [[ -z "$progress_percent" ]]; then
                    progress_percent="0"
                fi
            else
                progress_percent="0"
            fi
            
            log "📊 Progresso da sincronização: ${progress_percent}%"
            
            # Verificar se ainda está em download inicial
            if [[ "$initial_download" == "true" ]]; then
                warning "⏳ Bitcoin Core ainda está sincronizando a blockchain..."
                warning "📊 Progresso atual: ${progress_percent}%"
                echo ""
                warning "🚫 O LND não pode ser iniciado enquanto o Bitcoin Core estiver sincronizando!"
                warning "⏰ Aguarde a sincronização completa antes de continuar."
                echo ""
                echo "💡 Opções:"
                echo "1. ⏸️  Pausar e aguardar (recomendado)"
                echo "2. 🔄 Tentar novamente em 30 segundos"
                echo "3. ❌ Cancelar instalação"
                echo ""
                
                while true; do
                    read -p "Escolha uma opção (1/2/3): " -n 1 -r
                    echo
                    case $REPLY in
                        "1" )
                            echo ""
                            info "⏸️  Instalação pausada. Execute novamente quando a sincronização estiver completa."
                            echo ""
                            info "💡 Para verificar o progresso manualmente:"
                            echo "   docker exec bitcoin bitcoin-cli getblockchaininfo"
                            echo ""
                            exit 0
                            ;;
                        "2" )
                            log "🔄 Aguardando 30 segundos antes de verificar novamente..."
                            sleep 30
                            break
                            ;;
                        "3" )
                            error "❌ Instalação cancelada pelo usuário"
                            exit 1
                            ;;
                        * )
                            echo "Por favor, escolha 1, 2 ou 3."
                            ;;
                    esac
                done
            else
                log "✅ Bitcoin Core sincronizado! Progresso: ${progress_percent}%"
                log "🚀 Prosseguindo com a inicialização do LND..."
                return 0
            fi
        else
            warning "⚠️ Não foi possível conectar ao Bitcoin Core (tentativa $sync_attempt)"
            if [[ $sync_attempt -lt $MAX_SYNC_ATTEMPTS ]]; then
                log "Aguardando 10 segundos antes da próxima tentativa..."
                sleep 10
            fi
        fi
        
        ((sync_attempt++))
    done
    
    warning "⚠️ Não foi possível verificar o status de sincronização do Bitcoin Core"
    warning "   Possíveis causas:"
    warning "   - Container Bitcoin não está executando"
    warning "   - RPC não está acessível"
    warning "   - Credenciais RPC incorretas"
    echo ""
    
    read -p "Deseja continuar mesmo assim? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Operação cancelada pelo usuário"
        exit 1
    fi
}

# Função para capturar seed do LND
capture_lnd_seed() {
    # Verificar sincronização do Bitcoin Core antes de iniciar o LND
    check_bitcoin_sync
    
    # Tentar capturar a seed do LND
    warning "⚠️ IMPORTANTE: PEGUE PAPEL E CANETA PARA ANOTAR A SUA FRASE DE 24 PALAVRAS SEED DO LND"
    warning "Extraindo seed LND dos logs..."

    sleep 15 & spinner
    
    # Tentar capturar a seed múltiplas vezes se necessário
    MAX_ATTEMPTS=3
    attempt=1
    
    while [[ $attempt -le $MAX_ATTEMPTS ]]; do
        log "Tentativa $attempt de $MAX_ATTEMPTS para capturar seed do LND..."
        
        # Captura as linhas de início e fim do seed, o aviso e as palavras numeradas do LND
        docker logs lnd 2>/dev/null | head -200 | \
            awk '
                /!!!YOU MUST WRITE DOWN THIS SEED TO BE ABLE TO RESTORE THE WALLET!!!/ {print; next}
                /-+BEGIN LND CIPHER SEED-+/ {in_seed=1; print; next}
                /-+END LND CIPHER SEED-+/ {print; in_seed=0; next}
                in_seed && /^[[:space:]]*[0-9]+\./ {print}
            ' > ../seeds.txt
    
        # Verificar se conseguiu capturar a seed
        if [[ -s ../seeds.txt ]]; then
            log "Seed do LND capturada com sucesso!"
            break
        else
            warning "Não foi possível capturar a seed do LND na tentativa $attempt"
            if [[ $attempt -lt $MAX_ATTEMPTS ]]; then
                log "Aguardando 5 segundos antes da próxima tentativa..."
                sleep 5
            fi
        fi
        
        ((attempt++))
    done
}

# Função para exibir e confirmar seed
display_and_confirm_seed() {
    # Exibir conteúdo do arquivo de seeds se existir
    if [[ -f "../seeds.txt" && -s "../seeds.txt" ]]; then
        echo "=========================================="
        echo "📜 SEED PHRASE DE RECUPERAÇÃO:"
        echo "=========================================="
        echo ""
        warning "🚨 ATENÇÃO CRÍTICA: ANOTE ESTAS PALAVRAS AGORA!"
        warning "🔐 Sem essas palavras você PERDERÁ ACESSO aos seus bitcoins!"
        warning "📝 Escreva as 24 palavras em PAPEL e guarde em local SEGURO!"
        echo ""
        cat ../seeds.txt
        echo ""
        echo "=========================================="
        echo ""
        
        while true; do
            read -p "Você já anotou a seed em local seguro? y/N: " -n 1 -r
            echo
            case $REPLY in
                [Yy]* ) 
                    log "✅ Seed confirmada como anotada em local seguro"
                    echo ""
                    break
                    ;;
                [Nn]* ) 
                    echo ""
                    error "❌ PARE AGORA! Não continue sem anotar a seed!"
                    warning "🚨 ANOTE AS 24 PALAVRAS ACIMA EM PAPEL ANTES DE CONTINUAR!"
                    echo ""
                    echo "Pressione qualquer tecla quando tiver anotado..."
                    read -n 1 -s
                    echo ""
                    ;;
                * ) 
                    echo "Por favor, responda y sim ou n não."
                    ;;
            esac
        done
    else
        warning "⚠️ Nenhuma seed foi capturada no arquivo seeds.txt após $MAX_ATTEMPTS tentativas"
        warning "   Possíveis causas:"
        warning "   - Container LND ainda não iniciou completamente"
        warning "   - LND já foi inicializado anteriormente"
        warning "   - Erro nos logs do container"
        echo ""
        info "💡 Para verificar manualmente:"
        echo "   docker logs lnd | grep -A 30 'CIPHER SEED'"
        echo ""
        read -p "Deseja continuar mesmo assim? y/N: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Operação cancelada pelo usuário"
            exit 1
        fi
    fi
}

# Função para autodestruction de arquivos
auto_destruction_menu() {
    # Perguntar sobre autodestruição
    warning "🔥 OPÇÃO DE SEGURANÇA: Autodestruição dos arquivos de senha"
    echo ""
    echo "Por segurança, você pode optar por:"
    echo "1. 📁 Manter o arquivo salvo seeds.txt"
    echo "2. 🔥 Fazer autodestruição do arquivo"
    echo ""
    echo "⚠️  ATENÇÃO: Se escolher autodestruição, certifique-se de que já anotou a frase de 24 palavras seed do LND ou você não poderá recuperar seus bitcoins!"
    echo ""
    
    while true; do
        read -p "Deseja fazer autodestruição dos arquivos de seeds? y/N: " -n 1 -r
        echo
        case $REPLY in
            [Yy]* ) 
                echo ""
                warning "🔥 ÚLTIMA CHANCE: Os arquivos serão apagados em 10 segundos!"
                warning "📋 Certifique-se de que copiou todas as informações importantes!"
                echo ""
                echo "Arquivos que serão apagados:"
                echo "  • seeds.txt"
                echo ""
                
                for i in {10..1}; do
                    echo -ne "\rIniciando autodestruição em: ${i}s - Ctrl+C para cancelar"
                    sleep 1
                done
                echo ""
                echo ""
                
                log "🔥 Iniciando autodestruição dos arquivos de seed..."
                
                # Apagar arquivos
                if [[ -f "../seeds.txt" ]]; then
                    rm -f "../seeds.txt"
                    log "❌ seeds.txt apagado"
                fi
                
                echo ""
                warning "🔥 Autodestruição concluída!"
                warning "📋 Certifique-se de que salvou todas as informações importantes!"
                echo ""
                break
                ;;
            [Nn]* ) 
                log "📁 Arquivos de senha mantidos:"
                echo "  • passwords.md"
                echo "  • passwords.txt"
                echo "  • seeds.txt"
                echo "  • startup.md"
                echo ""
                info "💡 Dica: Faça backup destes arquivos em local seguro!"
                break
                ;;
            * ) 
                echo "Por favor, responda y sim ou n não."
                ;;
        esac
    done
}

start_lnd_docker() {
    app="bitcoin"
    app2="lnd"
    if sudo docker ps --format '{{.Names}}' | grep -q "^lnd$"; then
        warning "O container lnd já está em execução."
        read -p "Deseja parar e remover o container lnd e bitcoin antes de reiniciar? Isso não causará perda de dados. (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Parando e removendo o container lnd existente..."
            sudo docker stop lnd
            sudo docker rm lnd
            sudo docker stop bitcoin
            sudo docker rm bitcoin
        else
            log "Mantendo o container lnd atual."
        fi
    fi
    read -p "Deseja exibir logs da instalação? (y/n): " verbose_mode
    if [[ "$verbose_mode" == "y" ]]; then
        read -p "Deseja instalar o Bitcoin Core? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$REPO_DIR/container"
            sudo docker-compose build $app >> /dev/null 2>&1 & spinner
            sudo docker-compose up -d $app >> /dev/null 2>&1 & spinner
            echo "Aguardando $app inicializar..."
            sleep 10 & spinner
        else
            warning "Bitcoin Core não será instalado."
        fi
        sudo docker-compose build $app2
        sudo docker-compose up -d $app2
    elif [[ "$verbose_mode" == "n" ]]; then
        warning " 🕒 Aguarde..."
        read -p "Deseja instalar o Bitcoin Core? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$REPO_DIR/container"
            sudo docker-compose build $app >> /dev/null 2>&1 & spinner
            sudo docker-compose up -d $app >> /dev/null 2>&1 & spinner
            echo "Aguardando $app inicializar..."
            sleep 10 & spinner
        else
            warning "Bitcoin Core não será instalado."
        fi
        sudo docker-compose build $app2 >> /dev/null 2>&1 & spinner
        sudo docker-compose up -d $app2 >> /dev/null 2>&1 & spinner
        clear
    else
        error "Opção inválida."
        sudo bash "$REPO_DIR/brunel.sh"
    fi
}
# Função principal
main() {
    configure_remote_blockchain
    start_lnd_docker
    capture_lnd_seed
    display_and_confirm_seed
    auto_destruction_menu
}

# Executar função principal se o script for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
