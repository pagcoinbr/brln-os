#!/bin/bash
[ "$EUID" -ne 0 ] && exec sudo bash "$0" "$@"
# Script de configuração principal do BRLN Full Auto Container Stack
# Este script simplifica o processo de instalação para usuários finais
# Solicitar autenticação sudo no início do script
#set -e
spinner() {
    local pid=${1:-$!}
    local delay=0.2
    local max=${SPINNER_MAX:-20}
    local count=0
    local spinstr='|/-\\'
    local j=0

    tput civis

    # Monitorar processo
    while kill -0 "$pid" 2>/dev/null; do
        local emoji=""
        for ((i=0; i<=count; i++)); do
            emoji+="⚡"
        done

        local spin_char="${spinstr:j:1}"
        j=$(( (j + 1) % 4 ))
        count=$(( (count + 1) % (max + 1) ))

        printf "\r\033[KAguarde...${YELLOW}%s${NC} ${CYAN}[%s]${NC}" "$emoji" "$spin_char"
        sleep "$delay"
    done

    wait "$pid" 2>/dev/null
    exit_code=$?

    tput cnorm
    if [[ $exit_code -eq 0 ]]; then
        printf "\r\033[K${GREEN}✔️ Processo finalizado com sucesso!${NC}\n"
    else
        printf "\r\033[K${RED}❌ Processo finalizado com erro - código: $exit_code${NC}\n"
    fi

    return $exit_code
}

# Manter a sessão sudo ativa durante a execução do script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "Iniciando a Instalação do BRLN-OS..."
(sudo apt update && sudo apt upgrade -y && sudo apt install -y docker-compose) > /dev/null 2>&1 & spinner $!

# Verificar e adicionar usuário ao grupo docker no início para evitar problemas de permissão
if command -v docker &> /dev/null; then
    if ! groups $USER | grep -q docker; then
        echo "Adicionando usuário $USER ao grupo docker..."
        sudo usermod -aG docker $USER
        echo "Usuário adicionado ao grupo docker. Aplicando as mudanças de grupo..."
        exec sg docker "$0 $*"
    fi
fi

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funções de logging
clear
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Função para configurar senha do Thunderhub
configure_thunderhub_password() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    log "🔐 Configuração da Senha do Thunderhub"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    info "Configure uma senha personalizada para o Thunderhub Lightning Dashboard:"
    echo ""
    echo "• A senha será usada para acessar o Thunderhub na interface web"
    echo "• Por padrão, a senha é 'changeme123'"
    echo "• Recomendamos usar uma senha forte e única"
    echo ""
    
    while true; do
        read -p "Deseja definir uma senha personalizada para o Thunderhub? (y/N): " -n 1 -r
        echo
        case $REPLY in
            [Yy]* )
                echo ""
                while true; do
                    read -p "🔐 Digite a nova senha para o Thunderhub: " thunderhub_password
                    if [[ -n "$thunderhub_password" && ${#thunderhub_password} -ge 8 ]]; then
                        echo ""
                        read -p "🔐 Confirme a senha: " thunderhub_password_confirm
                        if [[ "$thunderhub_password" == "$thunderhub_password_confirm" ]]; then
                            log "✅ Senha do Thunderhub definida com sucesso!"
                            configure_thunderhub_yaml "$thunderhub_password"
                            break 2
                        else
                            error "❌ As senhas não coincidem! Tente novamente."
                            echo ""
                        fi
                    else
                        error "❌ A senha deve ter pelo menos 8 caracteres!"
                        echo ""
                    fi
                done
                ;;
            [Nn]* | "" )
                log "🔐 Usando senha padrão do Thunderhub (changeme123)"
                warning "⚠️  Recomendamos alterar a senha padrão antes de usar em produção!"
                # Ainda assim, criar o arquivo de configuração padrão se não existir
                if [[ ! -f "container/thunderhub/thubConfig.yaml" ]]; then
                    if [[ -f "container/thunderhub/thubConfig.yaml.example" ]]; then
                        cp "container/thunderhub/thubConfig.yaml.example" "container/thunderhub/thubConfig.yaml"
                        log "📝 Arquivo thubConfig.yaml criado com configuração padrão"
                    fi
                fi
                break
                ;;
            * )
                echo "Por favor, responda y (sim) ou n (não)."
                ;;
        esac
    done
    echo ""
}

# Função para configurar blockchain remota ou local
configure_blockchain_source() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    log "🔗 Configuração da Fonte Blockchain"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    info "Escolha a fonte da blockchain que deseja usar:"
    echo ""
    echo "1. 🏠 Blockchain Local (Padrão)"
    echo "   • Sincronização completa da blockchain Bitcoin"
    echo "   • Maior privacidade e controle total"
    echo "   • Requer mais tempo e espaço em disco"
    echo ""
    echo "2. ☁️  Blockchain Remota BRLN Club"
    echo "   • Conecta ao node Bitcoin da BRLN Club"
    echo "   • Sincronização mais rápida"
    echo "   • Requer credenciais da BRLN Club"
    echo ""
    
    while true; do
        read -p "Deseja usar a blockchain remota da BRLN Club? (y/N): " -n 1 -r
        echo
        case $REPLY in
            [Yy]* )
                log "📡 Configurando conexão com blockchain remota BRLN Club..."
                configure_remote_blockchain
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
    
    # Configurar senha do Thunderhub independente da escolha da blockchain
    configure_thunderhub_password
    echo ""
}

# Função para configurar blockchain remota
configure_remote_blockchain() {
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
    configure_bitcoin_conf
    configure_elements_conf "$brln_rpc_user" "$brln_rpc_pass"
    configure_lnd_conf "$brln_rpc_user" "$brln_rpc_pass"
    
    log "🎯 Configuração remota concluída!"
    echo ""
    info "Os arquivos foram configurados para usar a blockchain remota da BRLN Club."
    warning "⚠️  Certifique-se de que as credenciais estão corretas antes de iniciar os containers."
    echo ""
}

# Função para configurar elements.conf
configure_elements_conf() {
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

configure_bitcoin_conf() {
    local user="$1"
    local pass="$2"
    local bitcoin_conf="container/bitcoin/bitcoin.conf"
    
    log "📝 Configurando bitcoin.conf..."
    
    # Verificar se o arquivo existe
    if [[ ! -f "$bitcoin_conf" ]]; then
        # Copiar do exemplo se não existir
        if [[ -f "container/bitcoin/bitcoin.conf.example" ]]; then
            cp "container/bitcoin/bitcoin.conf.example" "$bitcoin_conf"
            log "Arquivo bitcoin.conf criado a partir do exemplo"
        else
            error "Arquivo bitcoin.conf.example não encontrado!"
            return 1
        fi
    fi
    
    # Gerar rpcauth usando rpcauth.py
    cd container/bitcoin
    rpcauth_output=$(python3 rpcauth.py brlnbitcoin)
    cd - > /dev/null
    
    # Extrair rpcauth line do output
    rpcauth_line=$(echo "$rpcauth_output" | grep "^rpcauth=")
    
    # Atualizar credenciais no bitcoin.conf
    sed -i "s/^rpcauth=.*/$rpcauth_line/g" "$bitcoin_conf"
    
    log "✅ bitcoin.conf configurado com sucesso!"
}

# Função para configurar lnd.conf
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

# Função para configurar thubConfig.yaml
configure_thunderhub_yaml() {
    local password="$1"
    local thunderhub_config="container/thunderhub/thubConfig.yaml"
    
    log "📝 Configurando thubConfig.yaml..."
    
    # Verificar se o arquivo existe
    if [[ ! -f "$thunderhub_config" ]]; then
        # Copiar do exemplo se não existir
        if [[ -f "container/thunderhub/thubConfig.yaml.example" ]]; then
            cp "container/thunderhub/thubConfig.yaml.example" "$thunderhub_config"
            log "Arquivo thubConfig.yaml criado a partir do exemplo"
        else
            error "Arquivo thubConfig.yaml.example não encontrado!"
            return 1
        fi
    fi
    
    # Atualizar senha no thubConfig.yaml
    sed -i "s/masterPassword: 'changeme123'/masterPassword: '$password'/g" "$thunderhub_config"
    sed -i "s/password: 'changeme123'/password: '$password'/g" "$thunderhub_config"
    
    # Também atualizar a variável de ambiente no service.json
    local service_json="container/thunderhub/service.json"
    if [[ -f "$service_json" ]]; then
        sed -i "s/\"THUB_PASSWORD\": \"changeme123\"/\"THUB_PASSWORD\": \"$password\"/g" "$service_json"
        log "✅ service.json atualizado com nova senha"
    fi
    
    log "✅ thubConfig.yaml configurado com sucesso!"
}

# Verificar se há containers ativos e parar se necessário
if [[ $(docker ps -q | wc -l) -gt 0 ]]; then
    warning "Existem containers Docker ativos. Parando todos os containers..."
    echo "Este processo pode apagar os volumes de projetos em execução, tenha cuidado ao prosseguir."
    read -p "Deseja continuar e parar todos os containers? y/N: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operação cancelada pelo usuário.${NC}"
        exit 1
    else
        log "Parando todos os containers e removendo volumes..."
        cd container || exit 1
        docker-compose down -v
        cd - || exit 1
        log "Todos os containers foram parados e volumes removidos."
    fi
fi

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
██████╗ ██████╗ ██╗     ███╗   ██╗    ███████╗██╗   ██╗██╗     ██╗         █████╗ ██╗   ██╗████████╗ ██████╗ 
██╔══██╗██╔══██╗██║     ████╗  ██║    ██╔════╝██║   ██║██║     ██║        ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗
██████╔╝██████╔╝██║     ██╔██╗ ██║    █████╗  ██║   ██║██║     ██║        ███████║██║   ██║   ██║   ██║   ██║
██╔══██╗██╔══██╗██║     ██║╚██╗██║    ██╔══╝  ██║   ██║██║     ██║        ██╔══██║██║   ██║   ██║   ██║   ██║
██████╔╝██║  ██║███████╗██║ ╚████║    ██║     ╚██████╔╝███████╗███████╗   ██║  ██║╚██████╔╝   ██║   ╚██████╔╝
╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝    ╚═╝      ╚═════╝ ╚══════╝╚══════╝   ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ 
                                                                                                                
    🚀 BRLN - OS - Bitcoin, Lightning & Liquid Network
EOF
echo -e "${NC}"

echo ""
log "Iniciando configuração do BRLN-OS Container Stack..."

# Configurar fonte da blockchain (local ou remota)
configure_blockchain_source

# Verificar se estamos no diretório correto
if [[ ! -d "container" ]]; then
    error "Diretório 'container' não encontrado!"
    error "Execute este script no diretório raiz do projeto brlnfullauto"
    echo ""
    echo "Exemplo:"
    echo "  git clone https://github.com/pagcoinbr/brlnfullauto.git"
    echo "  cd brlnfullauto"
    echo "  ./setup.sh"
    exit 1
fi

# Verificar se o script principal existe
if [[ ! -f "container/setup-docker-smartsystem.sh" ]]; then
    error "Script setup-docker-smartsystem.sh não encontrado em container/"
    exit 1
fi

# Verificar pré-requisitos
log "Verificando pré-requisitos do sistema..."

# Verificar se é Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    warning "Este script foi otimizado para Linux. Pode não funcionar corretamente em outros sistemas."
fi

# Verificar Docker
if ! command -v docker &> /dev/null; then
    warning "Docker não encontrado!"
    echo ""
    echo "Para instalar o Docker, execute:"
    echo "  curl -fsSL https://get.docker.com | sh"
    echo "  sudo usermod -aG docker \$USER"
    echo "  newgrp docker"
    echo ""
    read -p "Deseja que eu instale o Docker automaticamente? y/N: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Instalando Docker..."
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker $USER
        log "Docker instalado! Você pode precisar fazer logout/login para usar sem sudo"
    else
        error "Docker é obrigatório. Instale-o antes de continuar."
        exit 1
    fi
else
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    log "Docker encontrado: v$DOCKER_VERSION ✓"
fi

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    warning "Docker Compose não encontrado!"
    echo ""
    echo "Para instalar o Docker Compose, execute:"
    echo "  sudo apt-get update && sudo apt-get install docker-compose-plugin"
    echo ""
    read -p "Deseja que eu instale o Docker Compose automaticamente? y/N: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Instalando Docker Compose..."
        sudo apt-get update && sudo apt-get install -y docker-compose-plugin
        log "Docker Compose instalado! ✓"
    else
        error "Docker Compose é obrigatório. Instale-o antes de continuar."
        exit 1
    fi
else
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        log "Docker Compose encontrado: v$COMPOSE_VERSION ✓"
    else
        COMPOSE_VERSION=$(docker compose version --short)
    log "Docker Compose plugin encontrado: v$COMPOSE_VERSION ✓"
    fi
fi

# Verificar espaço em disco
log "Verificando espaço em disco..."
AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

if [[ $AVAILABLE_GB -lt 100 ]]; then
    warning "Espaço em disco baixo: ${AVAILABLE_GB}GB disponível"
    warning "Recomendado: pelo menos 1000GB para blockchain completa"
    echo ""
    read -p "Deseja continuar mesmo assim? y/N: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Operação cancelada pelo usuário"
        exit 1
    fi
else
    log "Espaço em disco suficiente: ${AVAILABLE_GB}GB ✓"
fi

# Verificar permissões nos scripts
log "Configurando permissões dos scripts..."
chmod +x container/setup-docker-smartsystem.sh
if [[ -f "container/build.sh" ]]; then
    chmod +x container/build.sh
fi

# Entrar no diretório container
cd container

log "Iniciando configuração completa..."
echo ""
warning "⚠️  IMPORTANTE: Este processo pode demorar 30-60 minutos"
warning "⚠️  A sincronização inicial da blockchain pode levar várias horas"
warning "⚠️  Certifique-se de ter conexão estável com a internet"
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operação cancelada pelo usuário."
    exit 0
fi

log "Executando configuração completa..."
echo ""
read -p "Deseja exibir os logs em tempo real durante a configuração? y/N: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Exibindo logs em tempo real..."
    ./setup-docker-smartsystem.sh 
    SETUP_PID=$!
else
    echo "Executando configuração em segundo plano..."
    ./setup-docker-smartsystem.sh > /dev/null 2>&1 & spinner $!
    SETUP_PID=$!
fi

# Verificar se a configuração foi bem-sucedida
clear
echo ""
log "Verificando status dos serviços..."
if command -v docker-compose &> /dev/null; then
    docker-compose ps
else
    docker compose ps
fi

# Aguardar um pouco para os containers iniciarem completamente
log "Aguardando containers iniciarem completamente..."
sleep 10

# Tentar capturar a seed do LND
warning "⚠️ IMPORTANTE: PEGUE PAPEL E CANETA PARA ANOTAR A SUA FRASE DE 24 PALAVRAS SEED DO LND"
warning "Extraindo seed LND dos logs..."

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

echo "capturando as senhas do lndg e do thunderhub..."
sleep 10 & spinner $!
docker logs lndg 2>/dev/null | grep "FIRST TIME LOGIN PASSWORD" | awk -F': ' '{print $2}' > ../passwords.txt

echo ""
echo "Senha do LNDG: $(cat ../passwords.txt | grep -oP 'FIRST TIME LOGIN PASSWORD: \K.*')"
echo ""

echo ""
warning "Anote agora as informações mostradas acima, caso você não o faça, elas não serão exibidas novamente no futuro!"

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
clear
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "🖥️ Instalando Interface Gráfica Web..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Instalar interface gráfica web
install_web_interface() {
    log "📦 Instalando Apache e dependências..."
    
    # Instalar Apache e Python
    sudo apt update > /dev/null 2>&1 &
    spinner $!
    
    sudo apt install -y apache2 python3-pip python3-venv > /dev/null 2>&1 &
    spinner $!
    
    # Instalar Flask-SocketIO em ambiente virtual
    log "🐍 Configurando ambiente Python..."
    
    # Get current absolute path before changing directories
    GRAPHICS_PATH="$(pwd)/graphics"
    
    cd graphics
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv > /dev/null 2>&1 &
        spinner $!
    fi
    
    source venv/bin/activate
    pip install flask flask-cors flask-socketio > /dev/null 2>&1 &
    spinner $!
    deactivate
    
    # Configurar Apache
    log "🌐 Configurando Apache..."
    
    # Copiar arquivos da interface
    sudo cp -r html/* /var/www/html/ > /dev/null 2>&1
    sudo chown -R www-data:www-data /var/www/html/ > /dev/null 2>&1
    
    # Configurar CGI
    sudo a2enmod cgi > /dev/null 2>&1
    sudo mkdir -p /var/www/html/cgi-bin > /dev/null 2>&1
    sudo cp cgi-bin/* /var/www/html/cgi-bin/ > /dev/null 2>&1
    sudo chmod +x /var/www/html/cgi-bin/* > /dev/null 2>&1
    sudo chown -R www-data:www-data /var/www/html/cgi-bin/ > /dev/null 2>&1
    
    # Criar serviço systemd para Flask
    log "⚙️ Criando serviço Flask..."
    
    # Create a dedicated directory for the Flask service that www-data can access
    sudo mkdir -p /opt/brln-flask
    sudo cp $GRAPHICS_PATH/control-systemd.py /opt/brln-flask/
    
    # Fix the Flask-SocketIO Werkzeug production issue
    sudo sed -i 's/socketio.run(app, host='\''0.0.0.0'\'', port=5001, debug=False)/socketio.run(app, host='\''0.0.0.0'\'', port=5001, debug=False, allow_unsafe_werkzeug=True)/' /opt/brln-flask/control-systemd.py
    
    # Create a new virtual environment in /opt/brln-flask instead of copying
    sudo python3 -m venv /opt/brln-flask/venv
    sudo /opt/brln-flask/venv/bin/pip install flask flask-cors flask-socketio
    
    # Set ownership after creating everything
    sudo chown -R www-data:www-data /opt/brln-flask
    
    sudo tee /etc/systemd/system/brln-flask.service > /dev/null << EOF
[Unit]
Description=BRLN Flask API Server
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/brln-flask
Environment=PATH=/opt/brln-flask/venv/bin
ExecStart=/opt/brln-flask/venv/bin/python control-systemd.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Ajustar permissões - já foi feito durante a cópia para /opt/brln-flask
    
    # Permitir www-data executar docker
    sudo usermod -a -G docker www-data > /dev/null 2>&1
    
    # Recarregar systemd e iniciar serviços
    sudo systemctl daemon-reload > /dev/null 2>&1
    sudo systemctl enable apache2 > /dev/null 2>&1
    sudo systemctl enable brln-flask > /dev/null 2>&1
    sudo systemctl restart apache2 > /dev/null 2>&1 &
    spinner $!
    sudo systemctl start brln-flask > /dev/null 2>&1 &
    spinner $!
    
    cd - > /dev/null
}

# Executar instalação da interface
install_web_interface

# Verificar se os serviços estão funcionando
log "🔍 Verificando serviços da interface..."

sleep 3

APACHE_STATUS=$(systemctl is-active apache2)
FLASK_STATUS=$(systemctl is-active brln-flask)

if [ "$APACHE_STATUS" = "active" ] && [ "$FLASK_STATUS" = "active" ]; then
    echo ""
    echo -e "${GREEN}✅ Interface gráfica instalada com sucesso!${NC}"
    echo ""
    info "🌐 Acesse a interface em:"
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo "  • Interface Principal: http://$LOCAL_IP"
    echo "  • Interface Principal: http://localhost"
    echo ""
    info "🔧 APIs disponíveis:"
    echo "  • Flask API: http://$LOCAL_IP:5001"
    echo "  • Status Containers: http://$LOCAL_IP:5001/containers/status"
    echo ""
    info "💡 Funcionalidades da interface:"
    echo "  • ⚡ Controle de containers em tempo real WebSockets"
    echo "  • 💰 Visualização de saldos Lightning/Bitcoin/Liquid"
    echo "  • 📊 Monitoramento de sistema e logs"
    echo "  • 🔄 Ferramentas Lightning criar/pagar invoices"
    echo "  • 🐳 Status detalhado dos containers Docker"
    echo ""
else
    echo ""
    warning "⚠️ Alguns serviços da interface não iniciaram corretamente"
    if [ "$APACHE_STATUS" != "active" ]; then
        echo "  • Apache: $APACHE_STATUS"
    fi
    if [ "$FLASK_STATUS" != "active" ]; then
        echo "  • Flask API: $FLASK_STATUS"
    fi
    echo ""
    info "🔧 Para verificar o status completo:"
    echo "  cd graphics && ./check_services.sh"
fi

echo -e "${CYAN}"
cat << "EOF"
██████╗ ██████╗ ██╗     ███╗   ██╗    ███████╗██╗   ██╗██╗     ██╗         █████╗ ██╗   ██╗████████╗ ██████╗ 
██╔══██╗██╔══██╗██║     ████╗  ██║    ██╔════╝██║   ██║██║     ██║        ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗
██████╔╝██████╔╝██║     ██╔██╗ ██║    █████╗  ██║   ██║██║     ██║        ███████║██║   ██║   ██║   ██║   ██║
██╔══██╗██╔══██╗██║     ██║╚██╗██║    ██╔══╝  ██║   ██║██║     ██║        ██╔══██║██║   ██║   ██║   ██║   ██║
██████╔╝██║  ██║███████╗██║ ╚████║    ██║     ╚██████╔╝███████╗███████╗   ██║  ██║╚██████╔╝   ██║   ╚██████╔╝
╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝    ╚═╝      ╚═════╝ ╚══════╝╚══════╝   ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ 
██╗     ██╗ ██████╗ ██╗  ██╗████████╗███╗   ██╗██╗███╗   ██╗ ██████╗     ███╗   ██╗ ██████╗ ██████╗ ███████╗
██║     ██║██╔════╝ ██║  ██║╚══██╔══╝████╗  ██║██║████╗  ██║██╔════╝     ████╗  ██║██╔═══██╗██╔══██╗██╔════╝
██║     ██║██║  ███╗███████║   ██║   ██╔██╗ ██║██║██╔██╗ ██║██║  ███╗    ██╔██╗ ██║██║   ██║██║  ██║█████╗  
██║     ██║██║   ██║██╔══██║   ██║   ██║╚██╗██║██║██║╚██╗██║██║   ██║    ██║╚██╗██║██║   ██║██║  ██║██╔══╝  
███████╗██║╚██████╔╝██║  ██║   ██║   ██║ ╚████║██║██║ ╚████║╚██████╔╝    ██║ ╚████║╚██████╔╝██████╔╝███████╗
╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝     ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝ 

                                                                                                                
    🚀 BRLN - OS - Bitcoin, Lightning & Liquid Network
EOF
echo -e "${NC}"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "🎯 Instalação Completa!"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
log "🎉 Configuração concluída!"
echo ""
info "📱 Interfaces web disponíveis:"
echo "  • LNDG Dashboard: http://localhost:8889"
echo "  • Thunderhub: http://localhost:3000"
echo "  • LNbits: http://localhost:5000"
echo "  • PeerSwap Web: http://localhost:1984"
echo ""
info "📋 Comandos úteis:"
echo "  Estes comandos precisam ser executados no diretório 'container':"
echo "  • Ver logs: docker logs [serviço] -f"
echo "  • Reiniciar: docker restart [serviço]"
echo "  • Status: docker ps"
echo ""
warning "🔒 Altere as senhas padrão antes de usar em produção!"
echo ""
info "🔑 Senhas configuradas:"
echo "  • LNbits: Acesse http://localhost:5000 e crie o super usuário agora"
echo "  • Thunderhub: Configurada durante o setup (verifique container/thunderhub/thubConfig.yaml)"
echo "  • RPC Bitcoin: Gerada no container/bitcoin/bitcoin.conf pelo rpcauth.py"
echo "  • RPC Elements: Definida no container/elements/elements.conf"
