#!/bin/bash

# Script inteligente para configurar Docker Compose
# Lê automaticamente configurações de cada serviço através de arquivos service.json
# Usa arrays e laços de repetição para máxima eficiência

set -e

# Verificar se jq está instalado (necessário para parsing JSON)
if ! command -v jq &> /dev/null; then
    echo "Instalando jq para parsing JSON..."
    sudo apt-get update && sudo apt-get install -y jq
fi

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Arrays dinâmicos para todos os serviços
declare -a ALL_SERVICES=()
declare -A SERVICE_DATA

# Funções de logging
log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
info() { echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
debug() { echo -e "${CYAN}[DEBUG $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }

# Verificar se estamos no diretório correto
if [[ ! -f "docker-compose.yml" ]]; then
    error "docker-compose.yml não encontrado. Execute este script no diretório container/"
    exit 1
fi

# Função para descobrir automaticamente todos os serviços
discover_services() {
    log "Descobrindo serviços automaticamente..."
    
    # Encontrar todos os arquivos service.json
    local service_files=(*/service.json)
    
    for service_file in "${service_files[@]}"; do
        if [[ -f "$service_file" ]]; then
            local service_dir=$(dirname "$service_file")
            debug "Encontrado arquivo de configuração: $service_file"
            
            # Validar se o JSON é válido
            if jq empty "$service_file" 2>/dev/null; then
                ALL_SERVICES+=("$service_dir")
                # Carregar dados do serviço na memória
                SERVICE_DATA["$service_dir"]=$(cat "$service_file")
                info "Serviço $service_dir adicionado à lista"
            else
                warning "Arquivo JSON inválido: $service_file"
            fi
        fi
    done
    
    if [[ ${#ALL_SERVICES[@]} -eq 0 ]]; then
        error "Nenhum serviço encontrado. Certifique-se de que existem arquivos service.json nos diretórios dos serviços"
        exit 1
    fi
    
    log "Descobertos ${#ALL_SERVICES[@]} serviços: ${ALL_SERVICES[*]}"
}

# Função para obter propriedade de um serviço
get_service_property() {
    local service=$1
    local property=$2
    echo "${SERVICE_DATA[$service]}" | jq -r ".$property // empty"
}

# Função para obter array de propriedades de um serviço
get_service_array() {
    local service=$1
    local property=$2
    echo "${SERVICE_DATA[$service]}" | jq -r ".$property[]? // empty"
}

# Função para criar usuários e grupos usando dados dos serviços
create_users_and_groups() {
    log "Criando usuários e grupos do sistema..."
    
    for service in "${ALL_SERVICES[@]}"; do
        local username=$(get_service_property "$service" "username")
        local uid=$(get_service_property "$service" "uid")
        local groupname=$(get_service_property "$service" "groupname")
        local gid=$(get_service_property "$service" "gid")
        local description=$(get_service_property "$service" "description")
        
        [[ -z "$username" || -z "$uid" || -z "$groupname" || -z "$gid" ]] && continue
        
        debug "Processando $service: $username:$uid, $groupname:$gid"
        
        # Criar grupo se não existir
        if ! getent group "$groupname" >/dev/null 2>&1; then
            sudo groupadd -g "$gid" "$groupname"
            info "Grupo $groupname criado com GID $gid"
        else
            local current_gid=$(getent group "$groupname" | cut -d: -f3)
            if [[ "$current_gid" != "$gid" ]]; then
                warning "Grupo $groupname existe com GID $current_gid, esperado $gid"
            else
                debug "Grupo $groupname já existe com GID correto"
            fi
        fi
        
        # Criar usuário se não existir
        if ! id "$username" >/dev/null 2>&1; then
            sudo useradd -r -u "$uid" -g "$groupname" -c "$description" -s /bin/false "$username"
            info "Usuário $username criado com UID $uid"
        else
            local current_uid=$(id -u "$username")
            if [[ "$current_uid" != "$uid" ]]; then
                warning "Usuário $username existe com UID $current_uid, esperado $uid"
            else
                debug "Usuário $username já existe com UID correto"
            fi
        fi
    done
}

# Função para criar diretórios de dados
create_data_directories() {
    log "Criando diretórios de dados..."
    
    sudo mkdir -p /data
    
    for service in "${ALL_SERVICES[@]}"; do
        local username=$(get_service_property "$service" "username")
        local uid=$(get_service_property "$service" "uid")
        local gid=$(get_service_property "$service" "gid")
        local data_dir=$(get_service_property "$service" "data_dir")
        
        [[ -z "$username" || -z "$uid" || -z "$gid" || -z "$data_dir" ]] && continue
        
        sudo mkdir -p "$data_dir"
        sudo chown -R "$uid:$gid" "$data_dir"
        sudo chmod -R 755 "$data_dir"
        info "Diretório $data_dir criado para $username"
        
        # Criar diretórios especiais se definidos
        while IFS= read -r special_dir; do
            [[ -n "$special_dir" ]] || continue
            sudo mkdir -p "$data_dir/$special_dir"
            debug "Criado diretório especial: $data_dir/$special_dir"
        done < <(get_service_array "$service" "special_dirs")
        
        # Ajustar permissões após criar estruturas especiais
        sudo chown -R "$uid:$gid" "$data_dir"
        sudo chmod -R 755 "$data_dir"
    done
}

# Função para configurar arquivos de configuração
setup_config_files() {
    log "Configurando arquivos de configuração..."
    
    for service in "${ALL_SERVICES[@]}"; do
        local username=$(get_service_property "$service" "username")
        local uid=$(get_service_property "$service" "uid")
        local gid=$(get_service_property "$service" "gid")
        local data_dir=$(get_service_property "$service" "data_dir")
        
        [[ -z "$username" || -z "$uid" || -z "$gid" || -z "$data_dir" ]] && continue
        
        # Processar cada arquivo de configuração
        while IFS= read -r config_file; do
            [[ -n "$config_file" ]] || continue
            
            local source_path="$service/$config_file"
            local dest_file="$config_file"
            
            # Remover .example do nome de destino se presente
            if [[ "$config_file" == *.example ]]; then
                dest_file=$(basename "$config_file" .example)
            fi
            
            local dest_path="$data_dir/$dest_file"
            
            if [[ -f "$source_path" ]]; then
                sudo cp "$source_path" "$dest_path"
                sudo chown "$uid:$gid" "$dest_path"
                
                # Definir permissões específicas baseadas no nome do arquivo
                case "$dest_file" in
                    "password.txt")
                        sudo chmod 600 "$dest_path"
                        ;;
                    "entrypoint.sh"|*.sh)
                        sudo chmod +x "$dest_path"
                        ;;
                    *)
                        sudo chmod 644 "$dest_path"
                        ;;
                esac
                
                info "Arquivo $dest_file configurado para $service"
            else
                warning "Arquivo de configuração não encontrado: $source_path"
            fi
        done < <(get_service_array "$service" "config_files")
    done
}

# Função para verificar recursos necessários
verify_resources() {
    log "Verificando recursos necessários..."
    
    local missing_dockerfiles=()
    local missing_binaries=()
    local total_dockerfiles=0
    local total_binaries=0
    
    for service in "${ALL_SERVICES[@]}"; do
        # Verificar Dockerfile
        local dockerfile=$(get_service_property "$service" "dockerfile")
        if [[ -n "$dockerfile" ]]; then
            ((total_dockerfiles++))
            local dockerfile_path="$service/$dockerfile"
            if [[ -f "$dockerfile_path" ]]; then
                debug "Dockerfile encontrado: $dockerfile_path"
            else
                missing_dockerfiles+=("$dockerfile_path")
            fi
        fi
        
        # Verificar binários
        while IFS= read -r binary; do
            [[ -n "$binary" ]] || continue
            ((total_binaries++))
            local binary_path="$service/$binary"
            if [[ -f "$binary_path" ]]; then
                debug "Binário encontrado: $binary_path"
            else
                missing_binaries+=("$binary_path")
            fi
        done < <(get_service_array "$service" "binaries")
    done
    
    # Relatório de Dockerfiles
    info "Dockerfiles: $((total_dockerfiles - ${#missing_dockerfiles[@]}))/$total_dockerfiles encontrados"
    if [[ ${#missing_dockerfiles[@]} -gt 0 ]]; then
        warning "Dockerfiles não encontrados:"
        for dockerfile in "${missing_dockerfiles[@]}"; do
            echo "  - $dockerfile"
        done
    fi
    
    # Relatório de binários
    info "Binários: $((total_binaries - ${#missing_binaries[@]}))/$total_binaries encontrados"
    if [[ ${#missing_binaries[@]} -gt 0 ]]; then
        warning "Binários não encontrados:"
        for binary in "${missing_binaries[@]}"; do
            echo "  - $binary"
        done
    fi
}

# Função para corrigir permissões existentes
fix_existing_permissions() {
    log "Corrigindo permissões existentes..."
    
    for service in "${ALL_SERVICES[@]}"; do
        local username=$(get_service_property "$service" "username")
        local uid=$(get_service_property "$service" "uid")
        local gid=$(get_service_property "$service" "gid")
        local data_dir=$(get_service_property "$service" "data_dir")
        
        [[ -z "$username" || -z "$uid" || -z "$gid" || -z "$data_dir" ]] && continue
        
        if [[ -d "$data_dir" ]]; then
            sudo chown -R "$uid:$gid" "$data_dir"
            sudo chmod -R 755 "$data_dir"
            
            # Arquivos especiais precisam de permissões específicas
            local password_file="$data_dir/password.txt"
            if [[ -f "$password_file" ]]; then
                sudo chmod 600 "$password_file"
            fi
            
            debug "Permissões corrigidas para $service em $data_dir"
        fi
    done
}

# Função para configurar sistema de logs
setup_logging_system() {
    log "Configurando sistema de logs..."
    
    if [[ -f "logs/install-log-manager.sh" ]]; then
        cd logs
        chmod +x install-log-manager.sh
        sudo ./install-log-manager.sh
        cd ..
        info "Sistema de logs configurado"
    else
        warning "Sistema de logs não encontrado em logs/"
    fi
}

# Função para menu interativo de seleção de serviços
show_service_menu() {
    echo -e "${BLUE}=== Menu de Seleção de Serviços ===${NC}"
    echo -e "Serviços disponíveis:"
    
    for i in "${!ALL_SERVICES[@]}"; do
        local service="${ALL_SERVICES[$i]}"
        local description=$(get_service_property "$service" "description")
        local ports=$(echo "${SERVICE_DATA[$service]}" | jq -r '.ports[]?' | tr '\n' ',' | sed 's/,$//')
        
        printf "  %-2d) %-15s - %s" "$((i+1))" "$service" "$description"
        [[ -n "$ports" ]] && printf " (portas: %s)" "$ports"
        echo
    done
    
    echo ""
    echo "Opções de seleção:"
    echo "  - Digite números separados por espaços (ex: 1 3 5)"
    echo "  - Digite nomes separados por espaços (ex: lnd elements peerswap)" 
    echo "  - Digite 'all' para todos os serviços"
    echo "  - Digite 'auto' para detecção automática baseada em arquivos existentes"
    echo ""
}

# Função para validar e processar seleção de serviços
process_service_selection() {
    local input="$1"
    local selected_services=()
    
    case "$input" in
        "all")
            selected_services=("${ALL_SERVICES[@]}")
            ;;
        "auto")
            # Selecionar serviços que têm Dockerfile e pelo menos um binário/config
            for service in "${ALL_SERVICES[@]}"; do
                local dockerfile=$(get_service_property "$service" "dockerfile")
                if [[ -n "$dockerfile" && -f "$service/$dockerfile" ]]; then
                    selected_services+=("$service")
                fi
            done
            ;;
        *)
            # Processar entrada (números ou nomes)
            IFS=' ' read -ra INPUT_ARRAY <<< "$input"
            for item in "${INPUT_ARRAY[@]}"; do
                if [[ "$item" =~ ^[0-9]+$ ]]; then
                    # É um número
                    local index=$((item - 1))
                    if [[ $index -ge 0 && $index -lt ${#ALL_SERVICES[@]} ]]; then
                        selected_services+=("${ALL_SERVICES[$index]}")
                    else
                        warning "Número inválido: $item"
                    fi
                else
                    # É um nome de serviço
                    if [[ " ${ALL_SERVICES[*]} " =~ " $item " ]]; then
                        selected_services+=("$item")
                    else
                        warning "Serviço '$item' não encontrado"
                    fi
                fi
            done
            ;;
    esac
    
    # Remover duplicatas
    local unique_services=($(printf "%s\n" "${selected_services[@]}" | sort -u))
    
    if [[ ${#unique_services[@]} -eq 0 ]]; then
        error "Nenhum serviço válido selecionado"
        return 1
    fi
    
    echo "${unique_services[@]}"
}

# Função principal para executar docker-compose
run_docker_compose() {
    local services=("$@")
    
    log "Iniciando containers para os serviços: ${services[*]}"
    
    # Parar containers existentes
    docker-compose down -v 2>/dev/null || true
    
    # Build dos serviços selecionados
    log "Construindo imagens..."
    if docker-compose build "${services[@]}"; then
        info "Build concluído com sucesso"
    else
        error "Falha no build dos containers"
        return 1
    fi
    
    # Iniciar serviços
    log "Iniciando serviços..."
    if docker-compose up -d "${services[@]}"; then
        info "Containers iniciados com sucesso"
    else
        error "Falha ao iniciar containers"
        return 1
    fi
    
    # Mostrar status
    echo -e "\n${GREEN}=== Status dos Containers ===${NC}"
    docker-compose ps
    
    # Mostrar informações dos serviços iniciados
    echo -e "\n${CYAN}=== Informações dos Serviços ===${NC}"
    for service in "${services[@]}"; do
        local description=$(get_service_property "$service" "description")
        local ports=$(echo "${SERVICE_DATA[$service]}" | jq -r '.ports[]?' | tr '\n' ',' | sed 's/,$//')
        
        echo -e "${BLUE}$service${NC}: $description"
        [[ -n "$ports" ]] && echo "  Portas: $ports"
    done
}

# Função principal
main() {
    log "=== Configurador Inteligente de Docker Compose ==="
    
    # Descobrir serviços automaticamente
    discover_services
    
    # Executar todas as configurações
    create_users_and_groups
    create_data_directories
    setup_config_files
    verify_resources
    fix_existing_permissions
    setup_logging_system
    
    # Menu de seleção
    show_service_menu
    read -p "Escolha os serviços: " selection
    
    # Processar seleção
    if selected_services=($(process_service_selection "$selection")); then
        log "Serviços selecionados: ${selected_services[*]}"
        
        # Executar docker-compose
        if run_docker_compose "${selected_services[@]}"; then
            log "=== Configuração concluída com sucesso ==="
            info "Sistema de logs ativo em: container/logs/"
            info "Use 'docker-compose logs -f [serviço]' para acompanhar logs"
        else
            error "Falha na configuração dos containers"
            exit 1
        fi
    else
        error "Falha na seleção de serviços"
        exit 1
    fi
}

# Executar script principal
docker-compose down -v
docker-compose build
docker-compose up -d
main "$@"
