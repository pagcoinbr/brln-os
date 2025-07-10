#!/bin/bash

# Script de configuração principal do BRLN Full Auto Container Stack
# Este script simplifica o processo de instalação para usuários finais

echo "Deseja exibir o filtro de falhas? (y/N)"
read -r -p "Digite 'YES' para continuar: " SHOW_FILTER
if [[ "$SHOW_FILTER" != "y" && "$SHOW_FILTER" != "Y" && "$SHOW_FILTER" != "yes" && "$SHOW_FILTER" != "YES" ]]; then
set -e
else
    echo "Filtro de falhas desativado."
fi
# Solicitar autenticação sudo no início do script
if ! sudo -v; then
    echo -e "${RED}Falha na autenticação sudo. Saindo...${NC}"
    exit 1
fi
# Manter a sessão sudo ativa durante a execução do script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

        printf "\r\033[KInstalando seu BRLN bolt...${YELLOW}%s${NC} ${CYAN}[%s]${NC}" "$emoji" "$spin_char"
        sleep "$delay"
    done

    wait "$pid" 2>/dev/null
    exit_code=$?

    tput cnorm
    if [[ $exit_code -eq 0 ]]; then
        printf "\r\033[K${GREEN}✔️ Processo finalizado com sucesso!${NC}\n"
    else
        printf "\r\033[K${RED}❌ Processo finalizado com erro (código: $exit_code)${NC}\n"
    fi

    return $exit_code
}

# Funções de logging
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Verificar se há containers ativos e parar se necessário
if [[ $(docker ps -q | wc -l) -gt 0 ]]; then
    warning "Existem containers Docker ativos. Parando todos os containers..."
    echo "Este processo pode apagar os volumes de projetos em execução, tenha cuidado ao prosseguir."
    read -p "Deseja continuar e parar todos os containers? (y/N): " -n 1 -r
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
██╗     ██╗ ██████╗ ██╗  ██╗████████╗███╗   ██╗██╗███╗   ██╗ ██████╗     ███╗   ██╗ ██████╗ ██████╗ ███████╗
██║     ██║██╔════╝ ██║  ██║╚══██╔══╝████╗  ██║██║████╗  ██║██╔════╝     ████╗  ██║██╔═══██╗██╔══██╗██╔════╝
██║     ██║██║  ███╗███████║   ██║   ██╔██╗ ██║██║██╔██╗ ██║██║  ███╗    ██╔██╗ ██║██║   ██║██║  ██║█████╗  
██║     ██║██║   ██║██╔══██║   ██║   ██║╚██╗██║██║██║╚██╗██║██║   ██║    ██║╚██╗██║██║   ██║██║  ██║██╔══╝  
███████╗██║╚██████╔╝██║  ██║   ██║   ██║ ╚████║██║██║ ╚████║╚██████╔╝    ██║ ╚████║╚██████╔╝██████╔╝███████╗
╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝     ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝ 

                                                                                                                
    🚀 Container Stack - Bitcoin, Lightning & Liquid Network
EOF
echo -e "${NC}"

echo ""
log "Iniciando configuração do BRLN Full Auto Container Stack..."

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
    read -p "Deseja que eu instale o Docker automaticamente? (y/N): " -n 1 -r
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
    read -p "Deseja que eu instale o Docker Compose automaticamente? (y/N): " -n 1 -r
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
        log "Docker Compose (plugin) encontrado: v$COMPOSE_VERSION ✓"
    fi
fi

# Verificar espaço em disco
log "Verificando espaço em disco..."
AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

if [[ $AVAILABLE_GB -lt 100 ]]; then
    warning "Espaço em disco baixo: ${AVAILABLE_GB}GB disponível"
    warning "Recomendado: pelo menos 100GB para blockchain completa"
    echo ""
    read -p "Deseja continuar mesmo assim? (y/N): " -n 1 -r
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
echo ""
read -p "Deseja continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operação cancelada pelo usuário."
    exit 0
fi

log "Executando configuração completa..."
echo ""
read -p "Deseja exibir os logs em tempo real durante a configuração? (y/N): " -n 1 -r
echo

./setup-docker-smartsystem.sh > /tmp/setup.log 2>&1 &
SETUP_PID=$!

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Exibindo logs em tempo real..."
    tail -f /tmp/setup.log --pid=$SETUP_PID
    wait $SETUP_PID
    SETUP_EXIT_CODE=$?
else
    log "Executando configuração em background..."
    spinner $SETUP_PID
    SETUP_EXIT_CODE=$?
fi

# Verificar se houve erro no processo
if [[ $SETUP_EXIT_CODE -ne 0 ]]; then
    error "Erro durante a configuração. Verifique o log em /tmp/setup.log"
    echo ""
    error "Últimas linhas do log:"
    tail -20 /tmp/setup.log
    exit 1
fi

# Verificar se a configuração foi bem-sucedida
echo ""
log "Verificando status dos serviços..."
if command -v docker-compose &> /dev/null; then
    docker-compose ps
else
    docker compose ps
fi
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

                                                                                                                
    🚀 Container Stack - Bitcoin, Lightning & Liquid Network
EOF
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
echo "  • Ver logs: docker-compose logs -f [serviço]"
echo "  • Parar tudo: docker-compose down"
echo "  • Reiniciar: docker-compose restart [serviço]"
echo "  • Status: docker-compose ps"
echo ""
warning "🔐 IMPORTANTE: Salve as seeds das carteiras que apareceram nos logs!"
warning "🔐 Faça backup regular dos dados em /data/"
echo ""

# Extrair senhas dos logs e gerar arquivo de documentação
log "📄 Gerando arquivo de senhas e credenciais..."
if [[ -f "../extract_passwords.sh" ]]; then
    ../extract_passwords.sh
    echo ""
    
    # Capturar a saída completa para o arquivo startup.md
    {
        echo "# � BRLN Full Auto Stack - Inicialização Completa"
        echo ""
        echo "**Data/Hora:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo "**Sistema:** $(uname -a)"
        echo ""
        echo "## 🎉 Instalação Concluída com Sucesso!"
        echo ""
        echo "### 📱 Interfaces Web Disponíveis:"
        echo "- **LNDG Dashboard:** http://localhost:8889"
        echo "- **Thunderhub:** http://localhost:3000"
        echo "- **LNbits:** http://localhost:5000"
        echo "- **PeerSwap Web:** http://localhost:1984"
        echo "- **Grafana:** http://localhost:3010"
        echo ""
        echo "### 📋 Comandos Úteis:"
        echo "- Ver logs: \`docker-compose logs -f [serviço]\`"
        echo "- Parar tudo: \`docker-compose down\`"
        echo "- Reiniciar: \`docker-compose restart [serviço]\`"
        echo "- Status: \`docker-compose ps\`"
        echo ""
        echo "---"
        echo ""
        
        # Adicionar o conteúdo do arquivo de senhas
        if [[ -f "../passwords.md" ]]; then
            ../extract_passwords.sh --display-only
        else
            echo "❌ Arquivo de senhas não encontrado"
        fi
        
        echo ""
        echo "---"
        echo ""
        echo "## ⚠️ AVISOS IMPORTANTES"
        echo ""
        echo "🔐 **SALVE AS SEEDS** das carteiras que apareceram nos logs!"
        echo "🔐 **FAÇA BACKUP REGULAR** dos dados em /data/"
        echo "� **ALTERE AS SENHAS PADRÃO** antes de usar em produção!"
        echo ""
        echo "---"
        echo "*Arquivo gerado automaticamente pelo setup.sh*"
    } > ../startup.md
    
    # Exibir na tela também
    echo ""
    echo "=========================================="
    echo "🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    echo "=========================================="
    echo ""
    echo "📱 Interfaces web disponíveis:"
    echo "  • LNDG Dashboard: http://localhost:8889"
    echo "  • Thunderhub: http://localhost:3000"
    echo "  • LNbits: http://localhost:5000"
    echo "  • PeerSwap Web: http://localhost:1984"
    echo "  • Grafana: http://localhost:3010"
    echo ""
    echo "📋 Comandos úteis (execute no diretório 'container'):"
    echo "  • Ver logs: docker-compose logs -f [serviço]"
    echo "  • Parar tudo: docker-compose down"
    echo "  • Reiniciar: docker-compose restart [serviço]"
    echo "  • Status: docker-compose ps"
    echo ""
    echo "=========================================="
    echo "🔐 CREDENCIAIS E SENHAS ENCONTRADAS:"
    echo "=========================================="
    echo ""
    
    # Mostrar as senhas na tela
    if [[ -f "../passwords.md" ]]; then
        ../extract_passwords.sh --display-only
    else
        warning "Arquivo de senhas não encontrado"
    fi
    
    echo ""
    echo "=========================================="
    echo ""
    warning "🔐 IMPORTANTE: Salve as seeds das carteiras que apareceram nos logs!"
    warning "🔐 Faça backup regular dos dados em /data/"
    warning "🔒 Altere as senhas padrão antes de usar em produção!"
    echo ""
    info "📄 Informações completas salvas em: startup.md"
    info "📋 Senhas documentadas em: passwords.md e passwords.txt"
    echo ""
    
    # Exibir conteúdo do arquivo passwords.txt
    if [[ -f "../passwords.txt" ]]; then
        echo "=========================================="
        echo "📄 CONTEÚDO DO ARQUIVO passwords.txt:"
        echo "=========================================="
        echo ""
        cat /home/admin/brlnfullauto/passwords.txt
        echo ""
        echo "=========================================="
        echo ""
        
        # Perguntar sobre autodestruição
        warning "🔥 OPÇÃO DE SEGURANÇA: Autodestruição dos arquivos de senha"
        echo ""
        echo "Por segurança, você pode optar por:"
        echo "1. 📁 Manter os arquivos salvos (passwords.md, passwords.txt, startup.md)"
        echo "2. 🔥 Fazer autodestruição dos arquivos após esta visualização"
        echo ""
        echo "⚠️  ATENÇÃO: Se escolher autodestruição, você deve COPIAR E SALVAR"
        echo "    as informações mostradas acima AGORA, pois elas serão apagadas!"
        echo ""
        
        while true; do
            read -p "Deseja fazer autodestruição dos arquivos de senha? (y/N): " -n 1 -r
            echo
            case $REPLY in
                [Yy]* ) 
                    echo ""
                    warning "🔥 ÚLTIMA CHANCE: Os arquivos serão apagados em 10 segundos!"
                    warning "📋 Certifique-se de que copiou todas as informações importantes!"
                    echo ""
                    echo "Arquivos que serão apagados:"
                    echo "  • passwords.md"
                    echo "  • passwords.txt"
                    echo "  • startup.md"
                    echo ""
                    
                    for i in {10..1}; do
                        echo -ne "\rIniciando autodestruição em: ${i}s (Ctrl+C para cancelar)"
                        sleep 1
                    done
                    echo ""
                    echo ""
                    
                    log "🔥 Iniciando autodestruição dos arquivos de senha..."
                    
                    # Apagar arquivos
                    if [[ -f "../passwords.md" ]]; then
                        rm -f "../passwords.md"
                        log "❌ passwords.md apagado"
                    fi
                    
                    if [[ -f "../passwords.txt" ]]; then
                        rm -f "../passwords.txt"
                        log "❌ passwords.txt apagado"
                    fi
                    
                    if [[ -f "../startup.md" ]]; then
                        rm -f "../startup.md"
                        log "❌ startup.md apagado"
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
                    echo "  • startup.md"
                    echo ""
                    info "💡 Dica: Faça backup destes arquivos em local seguro!"
                    break
                    ;;
                * ) 
                    echo "Por favor, responda y (sim) ou n (não)."
                    ;;
            esac
        done
    else
        warning "❌ Arquivo passwords.txt não encontrado"
    fi
    
else
    warning "Script de extração de senhas não encontrado: ../extract_passwords.sh"
fi

echo ""
log "Para mais informações, consulte o README.md e startup.md"
