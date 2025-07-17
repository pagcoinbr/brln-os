#!/bin/bash

# Source das funções básicas
source "$(dirname "$0")/basic.sh"
basics

app="lnd"
REPO_DIR="/home/$USER/brln-os"
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
    
    # Configurar arquivos
    configure_lnd_conf "$brln_rpc_user" "$brln_rpc_pass"
    configure_elements "$brln_rpc_user" "$brln_rpc_pass"
    
    log "🎯 Configuração remota concluída!"
    echo ""
    info "Os arquivos foram configurados para usar a blockchain remota da BRLN Club."
    warning "⚠️  Certifique-se de que as credenciais estão corretas antes de iniciar os containers."
    echo ""
}
# Função para configurar blockchain remota
configure_remote_blockchain() {
    sudo -v
    echo ""
    info "═══════════════════════════════════════════════════════════════"
    log "🔗 Configuração da Fonte Blockchain"
    info "═══════════════════════════════════════════════════════════════"
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
                break
                ;;
            * )
                echo "Por favor, responda y (sim) ou n (não)."
                ;;
        esac
    done
    echo ""
    read -p "Deseja exibir logs da instalação? (y/n): " verbose_mode
    if [[ "$verbose_mode" == "y" ]]; then
        cd "$REPO_DIR/container"
        sudo docker-compose build $app
        sudo docker-compose up -d $app
    elif [[ "$verbose_mode" == "n" ]]; then
        warning " 🕒 Aguarde..."
        cd "$REPO_DIR/container"
        sudo docker-compose build $app >> /dev/null 2>&1 & spinner
        sudo docker-compose up -d $app >> /dev/null 2>&1 & spinner
        clear
    else
        error "Opção inválida."
        sudo bash "$REPO_DIR/brunel.sh"
    fi
}

configure_elements() {
    local user="$1"
    local pass="$2"
    local elements_conf="container/elements/elements.conf"
    
    log "📝 Configurando elements.conf..."
    
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
    
    # Atualizar credenciais no elements.conf
    sed -i "s/mainchainrpcuser=<brln_rpc_user>/mainchainrpcuser=$user/g" "$elements_conf"
    sed -i "s/mainchainrpcpassword=<brln_rpc_pass>/mainchainrpcpassword=$pass/g" "$elements_conf"
    
    log "✅ elements.conf configurado com sucesso!"
}

configure_lnd_conf() {
    local user="$1"
    local pass="$2"
    local lnd_conf="container/lnd/lnd.conf"
    
    log "📝 Configurando lnd.conf..."
    
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
    
    # Atualizar credenciais no lnd.conf
    sed -i "s/bitcoind.rpcuser=<brln_rpc_user>/bitcoind.rpcuser=$user/g" "$lnd_conf"
    sed -i "s/bitcoind.rpcpass=<brln_rpc_user>/bitcoind.rpcpass=$pass/g" "$lnd_conf"
    
    log "✅ lnd.conf configurado com sucesso!"
}

# Função para capturar seed do LND
capture_lnd_seed() {
    # Tentar capturar a seed do LND
    warning "⚠️ IMPORTANTE: PEGUE PAPEL E CANETA PARA ANOTAR A SUA FRASE DE 24 PALAVRAS SEED DO LND"
    warning "Extraindo seed LND dos logs..."
    
    # Tentar capturar a seed múltiplas vezes se necessário
    MAX_ATTEMPTS=1
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

# Função para capturar senhas
capture_passwords() {
    echo "capturando as senhas do lndg e do thunderhub..."
    sleep 10 & spinner $!
    docker logs lndg 2>/dev/null | grep "FIRST TIME LOGIN PASSWORD" | awk -F': ' '{print $2}' > ../passwords.txt
    
    echo ""
    echo "Senha do LNDG: $(cat ../passwords.txt | grep -oP 'FIRST TIME LOGIN PASSWORD: \K.*')"
    echo ""
    
    echo ""
    warning "Anote agora as informações mostradas acima, caso você não o faça, elas não serão exibidas novamente no futuro!"
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
    echo "⚠️  ATENÇÃO: Se escolher autodestruição, você já anotado frase de 24 palavras seed do LND ou você não poderá recuperar seus bitcoins!"
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

# Função principal
main() {
    capture_lnd_seed
    capture_passwords
    display_and_confirm_seed
    auto_destruction_menu
}

# Executar função principal se o script for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
