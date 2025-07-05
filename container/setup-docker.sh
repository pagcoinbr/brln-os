#!/bin/bash

# Script para criar diretórios e arquivos necessários para o docker-compose
# com as permissões corretas usando arrays e laços de repetição

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Arquivo de configuração de usuários e grupos
USERS_CONFIG_FILE="users_groups.txt"

# Arrays para armazenar informações dos usuários
declare -a USERNAMES
declare -a USER_UIDS
declare -a GROUPNAMES
declare -a GROUP_GIDS
declare -a DATA_DIRS
declare -a CONFIG_FILES

# Arrays para arquivos e diretórios
declare -a REQUIRED_FILES
declare -a DOCKERFILES
declare -a BINARIES

# Função para logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Verificar se estamos no diretório correto
if [[ ! -f "docker-compose.yml" ]]; then
    error "docker-compose.yml não encontrado. Execute este script no diretório container/"
    exit 1
fi

# Verificar se arquivo de configuração existe
if [[ ! -f "$USERS_CONFIG_FILE" ]]; then
    error "Arquivo de configuração $USERS_CONFIG_FILE não encontrado"
    exit 1
fi

# Função para carregar configuração dos usuários
load_users_config() {
    log "Carregando configuração de usuários e grupos..."
    local index=0
    
    while IFS=':' read -r username uid groupname gid datadir configfiles; do
        # Ignorar linhas vazias e comentários
        [[ -z "$username" || "$username" =~ ^#.*$ ]] && continue
        
        USERNAMES[$index]="$username"
        USER_UIDS[$index]="$uid"
        GROUPNAMES[$index]="$groupname"
        GROUP_GIDS[$index]="$gid"
        DATA_DIRS[$index]="$datadir"
        CONFIG_FILES[$index]="$configfiles"
        
        ((index++))
    done < "$USERS_CONFIG_FILE"
    
    info "Carregados ${#USERNAMES[@]} usuários da configuração"
}

# Função para inicializar arrays de arquivos
initialize_file_arrays() {
    # Dockerfiles
    DOCKERFILES=(
        "lnd/Dockerfile.lnd"
        "elements/Dockerfile.elements"
        "peerswap/Dockerfile.peerswap"
        "tor/Dockerfile.tor"
    )
    
    # Binários
    BINARIES=(
        "lnd/lnd-linux-amd64-v0.18.5-beta.tar.gz"
        "elements/elements-23.2.7-x86_64-linux-gnu.tar.gz"
        "peerswap/peerswap-4.0rc1.tar.gz"
    )
}

log "=== Configurando diretórios e arquivos para Docker Compose ==="

# Carregar configuração
load_users_config
initialize_file_arrays

# Criar usuários e grupos do sistema
log "Criando usuários e grupos do sistema..."
for i in "${!USERNAMES[@]}"; do
    username="${USERNAMES[$i]}"
    uid="${USER_UIDS[$i]}"
    groupname="${GROUPNAMES[$i]}"
    gid="${GROUP_GIDS[$i]}"
    
    # Criar grupo se não existir
    if ! getent group "$groupname" >/dev/null 2>&1; then
        sudo groupadd -g "$gid" "$groupname"
        info "Grupo $groupname criado com GID $gid"
    else
        info "Grupo $groupname já existe"
        # Verificar se o GID está correto
        current_gid=$(getent group "$groupname" | cut -d: -f3)
        if [[ "$current_gid" != "$gid" ]]; then
            warning "Grupo $groupname existe com GID $current_gid, esperado $gid"
        fi
    fi
    
    # Criar usuário se não existir
    if ! id "$username" >/dev/null 2>&1; then
        sudo useradd -r -u "$uid" -g "$groupname" -s /bin/false "$username"
        info "Usuário $username criado com UID $uid"
    else
        info "Usuário $username já existe"
        # Verificar se o UID está correto
        current_uid=$(id -u "$username")
        if [[ "$current_uid" != "$uid" ]]; then
            warning "Usuário $username existe com UID $current_uid, esperado $uid"
        fi
    fi
done

# Criar diretórios de dados principais
log "Criando diretórios de dados principais..."
sudo mkdir -p /data
for i in "${!USERNAMES[@]}"; do
    username="${USERNAMES[$i]}"
    uid="${USER_UIDS[$i]}"
    gid="${GROUP_GIDS[$i]}"
    datadir="${DATA_DIRS[$i]}"
    
    sudo mkdir -p "$datadir"
    sudo chown -R "$uid:$gid" "$datadir"
    sudo chmod -R 755 "$datadir"
    info "Diretório $datadir criado e configurado para $username"
done

# Criar estruturas específicas por serviço
log "Configurando estruturas específicas dos serviços..."
for i in "${!USERNAMES[@]}"; do
    username="${USERNAMES[$i]}"
    uid="${USER_UIDS[$i]}"
    gid="${GROUP_GIDS[$i]}"
    datadir="${DATA_DIRS[$i]}"
    
    case "$username" in
        "lnd")
            log "Configurando estrutura específica do LND..."
            sudo mkdir -p "$datadir"/{data/chain/bitcoin/mainnet,logs/bitcoin/mainnet}
            sudo chown -R "$uid:$gid" "$datadir"
            sudo chmod -R 755 "$datadir"
            ;;
        "elements")
            log "Configurando estrutura específica do Elements..."
            sudo mkdir -p "$datadir"/{blocks,chainstate,database,wallets,liquidv1}
            sudo chown -R "$uid:$gid" "$datadir"
            sudo chmod -R 755 "$datadir"
            ;;
        "peerswap"|"lnbits")
            # Já criados anteriormente
            info "Estrutura básica de $username já configurada"
            ;;
    esac
done

# Configurar arquivos de configuração para todos os serviços
log "Configurando arquivos de configuração..."
for i in "${!USERNAMES[@]}"; do
    username="${USERNAMES[$i]}"
    uid="${USER_UIDS[$i]}"
    gid="${GROUP_GIDS[$i]}"
    datadir="${DATA_DIRS[$i]}"
    configfiles="${CONFIG_FILES[$i]}"
    
    # Separar múltiplos arquivos de configuração
    IFS=',' read -ra FILES <<< "$configfiles"
    
    for configfile in "${FILES[@]}"; do
        # Determinar diretório de origem baseado no username
        source_dir="$username"
        
        # Casos especiais para nomes de arquivos
        case "$configfile" in
            *.conf.example)
                # Remover .example do nome de destino
                dest_file=$(basename "$configfile" .example)
                source_path="$source_dir/$configfile"
                dest_path="$datadir/$dest_file"
                ;;
            *)
                dest_file="$configfile"
                source_path="$source_dir/$configfile"
                dest_path="$datadir/$dest_file"
                ;;
        esac
        
        # Verificar se arquivo de origem existe
        if [[ -f "$source_path" ]]; then
            sudo cp "$source_path" "$dest_path"
            sudo chown "$uid:$gid" "$dest_path"
            
            # Definir permissões específicas
            case "$dest_file" in
                "password.txt")
                    sudo chmod 600 "$dest_path"
                    ;;
                "entrypoint.sh")
                    sudo chmod +x "$dest_path"
                    ;;
                *)
                    sudo chmod 644 "$dest_path"
                    ;;
            esac
            
            info "Arquivo $dest_file configurado para $username em $dest_path"
        else
            warning "Arquivo de origem não encontrado: $source_path"
        fi
    done
done

# Verificar se todos os arquivos de configuração necessários existem
log "Verificando arquivos de configuração necessários..."

# Construir array de arquivos necessários dinamicamente
REQUIRED_FILES=()
for i in "${!USERNAMES[@]}"; do
    username="${USERNAMES[$i]}"
    datadir="${DATA_DIRS[$i]}"
    configfiles="${CONFIG_FILES[$i]}"
    
    IFS=',' read -ra FILES <<< "$configfiles"
    for configfile in "${FILES[@]}"; do
        case "$configfile" in
            *.conf.example)
                dest_file=$(basename "$configfile" .example)
                ;;
            *)
                dest_file="$configfile"
                ;;
        esac
        REQUIRED_FILES+=("$datadir/$dest_file")
    done
done

missing_files=()
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_files+=("$file")
    fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
    warning "Arquivos de configuração não encontrados:"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    warning "Certifique-se de que estes arquivos existem antes de executar docker-compose"
fi

# Verificar e ajustar permissões de arquivos existentes
log "Verificando permissões de arquivos..."
for username in "${USERNAMES[@]}"; do
    if [[ -f "$username/entrypoint.sh" ]]; then
        chmod +x "$username/entrypoint.sh"
        info "Permissões de execução definidas para $username/entrypoint.sh"
    fi
done

# Verificar Dockerfiles
log "Verificando Dockerfiles..."
for dockerfile in "${DOCKERFILES[@]}"; do
    if [[ ! -f "$dockerfile" ]]; then
        warning "Dockerfile não encontrado: $dockerfile"
    else
        info "Dockerfile encontrado: $dockerfile"
    fi
done

# Verificar binários necessários
log "Verificando binários necessários..."
for binary in "${BINARIES[@]}"; do
    if [[ -f "$binary" ]]; then
        info "Binário encontrado: $binary"
    else
        warning "Binário não encontrado: $binary"
    fi
done

# Corrigir permissões existentes se os diretórios já existirem
log "Corrigindo permissões existentes..."
for i in "${!USERNAMES[@]}"; do
    username="${USERNAMES[$i]}"
    uid="${USER_UIDS[$i]}"
    gid="${GROUP_GIDS[$i]}"
    datadir="${DATA_DIRS[$i]}"
    
    if [[ -d "$datadir" ]]; then
        sudo chown -R "$uid:$gid" "$datadir"
        sudo chmod -R 755 "$datadir"
        info "Permissões do $username corrigidas em $datadir"
    fi
done

# Diretórios especiais para Elements
declare -a SPECIAL_DIRS=(
    "/data/.elements:${USER_UIDS[1]}:${GROUP_GIDS[1]}"
    "/data/liquidv1:${USER_UIDS[1]}:${GROUP_GIDS[1]}"
)

for dir_info in "${SPECIAL_DIRS[@]}"; do
    IFS=':' read -r dir uid gid <<< "$dir_info"
    if [[ -d "$dir" ]]; then
        sudo chown -R "$uid:$gid" "$dir"
        sudo chmod -R 755 "$dir"
        info "Permissões corrigidas para diretório especial: $dir"
    fi
done

# Configurar sistema de logs
log "Configurando sistema de logs..."
if [[ -f "logs/install-log-manager.sh" ]]; then
    cd logs
    chmod +x install-log-manager.sh
    sudo ./install-log-manager.sh
    cd ..
    info "Sistema de logs configurado e instalado"
else
    warning "Script install-log-manager.sh não encontrado em logs/"
fi

# Apresentar menu de opções
echo -e "${BLUE}=== Menu de Instalação ===${NC}"
echo "Digite abaixo os serviços que deseja instalar:"
echo -n "Opções disponíveis: "
for username in "${USERNAMES[@]}"; do
    echo -n "$username "
done
echo ""
echo "Separe-os usando espaços (ex: lnd elements peerswap)"
read -p "Escolha: " SERVICES

# Validar serviços escolhidos
declare -a VALID_SERVICES
IFS=' ' read -ra CHOSEN_SERVICES <<< "$SERVICES"
for service in "${CHOSEN_SERVICES[@]}"; do
    if [[ " ${USERNAMES[*]} " =~ " $service " ]]; then
        VALID_SERVICES+=("$service")
    else
        warning "Serviço '$service' não reconhecido, ignorando..."
    fi
done

if [[ ${#VALID_SERVICES[@]} -eq 0 ]]; then
    error "Nenhum serviço válido selecionado"
    exit 1
fi

SERVICES="${VALID_SERVICES[*]}"

log "=== Configuração concluída ==="
docker-compose down -v || true
docker-compose build ${SERVICES}
docker-compose up -d ${SERVICES}
info "Containers iniciados. O sistema de logs está coletando informações em tempo real."
info "Verifique os logs em: container/logs/"
info "Serviços iniciados: ${SERVICES}"

