#!/bin/bash
set -euo pipefail

# Source das funções básicas
source "$(dirname "$0")/.env"
basics

app="lnd"
REPO_DIR="/root/brln-os"
CONTAINER_DIR="$REPO_DIR/container"

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
    
    # Criar arquivo de senha do LND
    create_password_file
    
    # Ir para o diretório do repositório para as configurações
    cd "$REPO_DIR"
    
    # Configurar arquivos
    echo "📝 Criando bitcoin.conf..."
    configure_bitcoin_conf_remote
    echo "📝 Criando lnd.conf..."
    configure_lnd_conf_remote "$brln_rpc_user" "$brln_rpc_pass"
    echo "📝 Criando elements.conf..."
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
    echo "Configure as credenciais locais:"
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
        
        # Criar arquivo de senha do LND
        create_password_file
        
        # Salvar credenciais RPC no arquivo .env para uso do container
        echo "BITCOIN_RPC_USER=$local_rpc_user" >> "$REPO_DIR/container/.env"
        echo "BITCOIN_RPC_PASS=$local_rpc_pass" >> "$REPO_DIR/container/.env"
        log "✅ Credenciais RPC salvas no arquivo .env"
        
        # Configurar arquivos
        echo "📝 Criando bitcoin.conf..."
        configure_bitcoin_conf "$rpcauth_line"
        echo "📝 Criando lnd.conf..."
        configure_lnd_conf_local "$local_rpc_user" "$local_rpc_pass"
        echo "📝 Criando elements.conf..."
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
    cd -
}
# Função para configurar blockchain remota
configure_remote_blockchain() {
    
    # Configuração sempre para mainnet
    BITCOIN_NETWORK="mainnet"
    echo ""
    info "═══════════════════════════════════════════════════════════════"
    log "🔗 Configuração da Fonte Blockchain (MAINNET)"
    info "═══════════════════════════════════════════════════════════════"
    echo ""
    
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
                btc_mode="remote"
                brln_credentials
                break
                ;;
            [Nn]* | "" )
                log "🏠 Usando blockchain local (configuração padrão)"
                info "A sincronização da blockchain Bitcoin será realizada localmente."
                warning "⚠️  Isso pode levar várias horas para sincronizar completamente."
                btc_mode="local"
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
    local lnd_conf="/data/lnd/lnd.conf"
    
    log "📝 Configurando lnd.conf para conexão remota ($BITCOIN_NETWORK)..."
    
    # Verificar se o arquivo existe
    # Copiar do exemplo se não existir
    if [[ -f "container/lnd/lnd.conf.example" ]]; then
        cp "container/lnd/lnd.conf.example" "$lnd_conf"
        log "Arquivo lnd.conf criado a partir do exemplo de configuração"
    else
        error "Arquivo lnd.conf.example não encontrado!"
        return 1
    fi
    
    # Para conexão remota: comentar configuração local e descomentar configuração remota
    # Comentar linhas locais
    sed -i "s/bitcoind.rpcuser=<seu_user_rpc>/#bitcoind.rpcuser=<seu_user_rpc>/g" "$lnd_conf"
    sed -i "s/bitcoind.rpcpass=<sua_senha_rpc>/#bitcoind.rpcpass=<sua_senha_rpc>/g" "$lnd_conf"
    sed -i "s/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28332/#bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28332/g" "$lnd_conf"
    sed -i "s/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28333/#bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28333/g" "$lnd_conf"
    
    # Descomentar e configurar linhas remotas
    sed -i "s/#bitcoind.rpchost=bitcoin.br-ln.com:8085/bitcoind.rpchost=bitcoin.br-ln.com:8085/g" "$lnd_conf"
    sed -i "s/#bitcoind.rpcuser=<seu_user_rpc>/bitcoind.rpcuser=$user/g" "$lnd_conf"
    sed -i "s/#bitcoind.rpcpass=<sua_senha_rpc>/bitcoind.rpcpass=$pass/g" "$lnd_conf"
    sed -i "s/#bitcoind.zmqpubrawblock=tcp:\/\/bitcoin.br-ln.com:28332/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin.br-ln.com:28332/g" "$lnd_conf"
    sed -i "s/#bitcoind.zmqpubrawtx=tcp:\/\/bitcoin.br-ln.com:28333/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin.br-ln.com:28333/g" "$lnd_conf"
    
    log "Configurando LND para MAINNET remota..."
    log "✅ lnd.conf configurado para conexão remota ($BITCOIN_NETWORK)!"
}

# Função para configurar lnd.conf para conexão local
configure_lnd_conf_local() {
    local user="$1"
    local pass="$2"
    local lnd_conf="/data/lnd/lnd.conf"

    log "📝 Configurando lnd.conf para conexão local ($BITCOIN_NETWORK)..."
    
    if [[ -f "container/lnd/lnd.conf.example" ]]; then
        cp "container/lnd/lnd.conf.example" "$lnd_conf"
        log "Arquivo lnd.conf criado a partir do exemplo"
    else
        error "Arquivo lnd.conf.example não encontrado!"
        return 1
    fi
    
    # Para conexão local: manter configuração local ativa e configurar credenciais
    # Substituir placeholders nas linhas locais (descomentadas)
    sed -i "s/<seu_user_rpc>/$user/g" "$lnd_conf"
    sed -i "s/<sua_senha_rpc>/$pass/g" "$lnd_conf"
    
    # Não precisa ajustar portas ZMQ pois já estão corretas no template (28332/28333)
    
    log "✅ lnd.conf configurado para conexão local ($BITCOIN_NETWORK)!"
}

# Função para configurar bitcoin.conf com rpcauth
configure_bitcoin_conf() {
    local rpcauth_line="$1"
    log "📝 Configurando arquivos bitcoin.conf"
    local bitcoin_conf="container/bitcoin/bitcoin.conf.example"
    local target_conf="container/bitcoin/bitcoin.conf"
    
    if [[ -f "$bitcoin_conf" ]]; then
        # Copiar o template exemplo para o arquivo final
        cp "$bitcoin_conf" "$target_conf"
        # Substituir a linha rpcauth placeholder
        sed -i "s/rpcauth=<PLACEHOLDER_RPCAUTH>/$rpcauth_line/" "$target_conf"
        log "✅ bitcoin.conf configurado para MAINNET!"
    else
        error "⚠️  Arquivo bitcoin.conf.example não encontrado!"
        return 1
    fi
}

# Função para configurar bitcoin.conf para conexão remota (sem RPC local)
configure_bitcoin_conf_remote() {
    log "📝 Configurando arquivos bitcoin.conf para conexão remota"
    local bitcoin_conf="container/bitcoin/bitcoin.conf.example"
    local target_conf="container/bitcoin/bitcoin.conf"
    
    if [[ -f "$bitcoin_conf" ]]; then
        # Copiar o template exemplo para o arquivo final
        cp "$bitcoin_conf" "$target_conf"
        # Para conexão remota, comentar ou remover a linha rpcauth já que não usaremos RPC local
        sed -i "s/rpcauth=<PLACEHOLDER_RPCAUTH>/#rpcauth=# Not needed for remote connection/" "$target_conf"
        log "✅ bitcoin.conf configurado para conexão remota!"
    else
        error "⚠️  Arquivo bitcoin.conf.example não encontrado!"
        return 1
    fi
}

# Função para criar arquivo password.txt com senha do usuário
create_password_file() {
    echo ""
    log "🔐 Configuração de senha para o LND"
    echo ""
    
    info "Para desbloquear o LND, será necessária uma senha."
    info "Esta senha será salva no arquivo password.txt para desbloqueio automático."
    echo ""
    warning "⚠️  IMPORTANTE: Anote esta senha em local seguro!"
    warning "📝 Você precisará desta senha para acessar seus bitcoins!"
    echo ""
    
    while true; do
        read -p "🔐 Digite uma senha para o LND (mínimo 8 caracteres): " lnd_password
        
        if [[ -z "$lnd_password" ]]; then
            error "Senha não pode estar vazia!"
            continue
        fi
        
        if [[ ${#lnd_password} -lt 8 ]]; then
            error "Senha deve ter no mínimo 8 caracteres!"
            continue
        fi
        
        read -p "🔐 Confirme a senha: " lnd_password_confirm
        
        if [[ "$lnd_password" != "$lnd_password_confirm" ]]; then
            error "Senhas não conferem! Tente novamente."
            continue
        fi
        
        break
    done
    
    # Salvar senha no arquivo password.txt
    # Criar diretório se não existir
    mkdir -p "/data/lnd"
    echo "$lnd_password" > "/data/lnd/password.txt"
    chmod 600 "/data/lnd/password.txt"

    log "✅ Senha salva em password.txt com permissões restritas!"
    echo ""
    warning "🚨 BACKUP: Faça backup da senha anotando em local seguro!"
    warning "📁 O arquivo password.txt foi criado em: /data/lnd/password.txt"
    echo ""
}

# Função para verificar sincronização do Bitcoin Core
check_bitcoin_sync() {
    log "🔍 Verificando sincronização do Bitcoin Core..."

    sleep 10 & spinner
    
    # Tentar conectar e verificar status de sincronização
    MAX_SYNC_ATTEMPTS=1
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
    warning "   - Bitcoin Core em modo remoto"
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
    if [[ btc_mode == "local" ]]; then
        check_bitcoin_sync
    fi
    
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
    warning "🔥 OPÇÃO DE SEGURANÇA: Autodestruição dos arquivos sensíveis"
    echo ""
    echo "Por segurança, você pode optar por:"
    echo "1. 📁 Manter os arquivos salvos (seeds.txt e password.txt)"
    echo "2. 🔥 Fazer autodestruição dos arquivos"
    echo ""
    echo "⚠️  ATENÇÃO: Se escolher autodestruição, certifique-se de que já anotou:"
    echo "   • A frase de 24 palavras seed do LND"
    echo "   • A senha do LND"
    echo "   Ou você não poderá recuperar seus bitcoins!"
    echo ""
    
    while true; do
        read -p "Deseja fazer autodestruição dos arquivos sensíveis? y/N: " -n 1 -r
        echo
        case $REPLY in
            [Yy]* ) 
                echo ""
                warning "🔥 ÚLTIMA CHANCE: Os arquivos serão apagados em 10 segundos!"
                warning "📋 Certifique-se de que copiou todas as informações importantes!"
                echo ""
                echo "Arquivos que serão apagados:"
                echo "  • seeds.txt"
                echo "  • password.txt"
                echo ""
                
                for i in {10..1}; do
                    echo -ne "\rIniciando autodestruição em: ${i}s - Ctrl+C para cancelar"
                    sleep 1
                done
                echo ""
                echo ""
                
                log "🔥 Iniciando autodestruição dos arquivos sensíveis..."
                
                # Apagar arquivos
                if [[ -f "../seeds.txt" ]]; then
                    rm -f "../seeds.txt"
                    log "❌ seeds.txt apagado"
                fi
                
                if [[ -f "$REPO_DIR/password.txt" ]]; then
                    rm -f "$REPO_DIR/password.txt"
                    log "❌ password.txt apagado"
                fi
                
                echo ""
                warning "🔥 Autodestruição concluída!"
                warning "📋 Certifique-se de que salvou todas as informações importantes!"
                echo ""
                break
                ;;
            [Nn]* ) 
                log "📁 Arquivos sensíveis mantidos:"
                echo "  • seeds.txt"
                echo "  • password.txt"
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
    cd "$REPO_DIR/container"
    
    # Verificar e corrigir permissões antes de iniciar os containers
    log "🔧 Verificando permissões dos diretórios do LND..."
    if [[ -f "$REPO_DIR/scripts/fix-lnd-permissions.sh" ]]; then
        "$REPO_DIR/scripts/fix-lnd-permissions.sh"
    else
        warning "⚠️ Script de correção de permissões não encontrado!"
        warning "   Criando diretório LND manualmente..."
        
        # Fallback: criar diretório com permissões básicas
        mkdir -p "/data/lnd"
        
        # Tentar obter UID do usuário LND do container
        if docker-compose run --rm lnd id lnd &>/dev/null; then
            local lnd_uid_gid=$(docker-compose run --rm lnd id lnd 2>/dev/null | grep -o 'uid=[0-9]*.*gid=[0-9]*' | sed 's/uid=//;s/gid=/:/;s/(.*)//g' | tr -d ' ')
            if [[ -n "$lnd_uid_gid" ]]; then
                log "Corrigindo permissões para $lnd_uid_gid..."
                chown -R "$lnd_uid_gid" "/data/lnd" 2>/dev/null || true
            fi
        fi
        
        chmod -R 755 "/data/lnd"
        log "✅ Permissões básicas aplicadas"
    fi
    warning " 🕒 Aguarde..."
}

# Função principal
main() {
    # Primeiro configurar a blockchain e criar todos os arquivos de configuração
    configure_remote_blockchain
    
    # Depois iniciar os containers (agora os arquivos já existem)
    start_lnd_docker
    
    # Capturar e exibir seed
    capture_lnd_seed
    display_and_confirm_seed
    auto_destruction_menu
}

# Executar função principal se o script for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
