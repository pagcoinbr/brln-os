#!/bin/bash

# Script para criar automaticamente um novo serviço no sistema
# Gera o arquivo service.json e estrutura básica do diretório

set -e

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Função para obter próximo UID/GID disponível
get_next_id() {
    local existing_ids=()
    
    # Buscar IDs existentes nos arquivos service.json
    for service_file in */service.json; do
        if [[ -f "$service_file" ]]; then
            local uid=$(jq -r '.uid // empty' "$service_file")
            local gid=$(jq -r '.gid // empty' "$service_file")
            [[ -n "$uid" ]] && existing_ids+=("$uid")
            [[ -n "$gid" ]] && existing_ids+=("$gid")
        fi
    done
    
    # Encontrar próximo ID disponível a partir de 1000
    local next_id=1000
    while [[ " ${existing_ids[*]} " =~ " $next_id " ]]; do
        ((next_id++))
    done
    
    echo "$next_id"
}

# Função para criar arquivo service.json
create_service_json() {
    local name="$1"
    local description="$2"
    local ports_input="$3"
    local config_files_input="$4"
    local special_dirs_input="$5"
    local binaries_input="$6"
    
    local next_id=$(get_next_id)
    
    # Converter entradas em arrays JSON
    local ports_json="[]"
    if [[ -n "$ports_input" ]]; then
        IFS=',' read -ra ports_array <<< "$ports_input"
        ports_json=$(printf '%s\n' "${ports_array[@]}" | jq -R . | jq -s .)
    fi
    
    local config_files_json="[]"
    if [[ -n "$config_files_input" ]]; then
        IFS=',' read -ra config_array <<< "$config_files_input"
        config_files_json=$(printf '%s\n' "${config_array[@]}" | jq -R . | jq -s .)
    fi
    
    local special_dirs_json="[]"
    if [[ -n "$special_dirs_input" ]]; then
        IFS=',' read -ra dirs_array <<< "$special_dirs_input"
        special_dirs_json=$(printf '%s\n' "${dirs_array[@]}" | jq -R . | jq -s .)
    fi
    
    local binaries_json="[]"
    if [[ -n "$binaries_input" ]]; then
        IFS=',' read -ra binaries_array <<< "$binaries_input"
        binaries_json=$(printf '%s\n' "${binaries_array[@]}" | jq -R . | jq -s .)
    fi
    
    # Criar JSON
    cat > "$name/service.json" << EOF
{
    "name": "$name",
    "uid": $next_id,
    "username": "$name",
    "gid": $next_id,
    "groupname": "$name",
    "data_dir": "/data/$name",
    "config_files": $config_files_json,
    "special_dirs": $special_dirs_json,
    "dockerfile": "Dockerfile.$name",
    "binaries": $binaries_json,
    "ports": $ports_json,
    "description": "$description"
}
EOF
    
    info "Arquivo service.json criado com UID/GID: $next_id"
}

# Função para criar estrutura básica do serviço
create_service_structure() {
    local name="$1"
    local config_files_input="$2"
    
    # Criar diretório do serviço
    mkdir -p "$name"
    
    # Criar Dockerfile básico
    cat > "$name/Dockerfile.$name" << EOF
FROM ubuntu:22.04

# Instalar dependências básicas
RUN apt-get update && apt-get install -y \\
    wget \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# Criar usuário do serviço
RUN groupadd -g \${SERVICE_GID:-1000} $name && \\
    useradd -r -u \${SERVICE_UID:-1000} -g $name $name

# Definir diretório de trabalho
WORKDIR /home/$name

# Copiar arquivos de configuração
COPY . /home/$name/

# Definir usuário
USER $name

# Comando padrão (ajustar conforme necessário)
CMD ["echo", "Serviço $name iniciado"]
EOF
    
    # Criar arquivos de configuração exemplo se especificados
    if [[ -n "$config_files_input" ]]; then
        IFS=',' read -ra config_files <<< "$config_files_input"
        for config_file in "${config_files[@]}"; do
            if [[ "$config_file" == *.example ]]; then
                touch "$name/$config_file"
                echo "# Arquivo de configuração para $name" > "$name/$config_file"
            elif [[ "$config_file" == "entrypoint.sh" ]]; then
                cat > "$name/entrypoint.sh" << 'EOF'
#!/bin/bash
set -e

echo "Iniciando serviço..."

# Adicionar lógica de inicialização aqui

# Manter container rodando
tail -f /dev/null
EOF
                chmod +x "$name/entrypoint.sh"
            else
                touch "$name/$config_file"
                echo "# Configuração para $name" > "$name/$config_file"
            fi
        done
    fi
    
    # Criar README básico
    cat > "$name/README.md" << EOF
# $name

Serviço $name para o sistema Docker Compose.

## Configuração

O serviço é configurado através do arquivo \`service.json\` que contém:
- Informações de usuário e grupo
- Diretórios de dados
- Arquivos de configuração
- Portas utilizadas
- Binários necessários

## Arquivos

- \`Dockerfile.$name\`: Imagem Docker do serviço
- \`service.json\`: Configuração do serviço
- Arquivos de configuração específicos do serviço

## Como usar

1. Ajuste as configurações no arquivo \`service.json\`
2. Modifique o \`Dockerfile.$name\` conforme necessário
3. Execute o script de setup: \`./setup-docker-intelligent.sh\`
4. Selecione este serviço no menu interativo

EOF
    
    info "Estrutura básica criada para o serviço $name"
}

# Função principal interativa
main() {
    echo -e "${BLUE}=== Criador de Novo Serviço ===${NC}"
    
    # Verificar se estamos no diretório correto
    if [[ ! -f "docker-compose.yml" ]]; then
        error "Execute este script no diretório container/"
        exit 1
    fi
    
    # Verificar se jq está disponível
    if ! command -v jq &> /dev/null; then
        error "jq não está instalado. Instale com: sudo apt-get install jq"
        exit 1
    fi
    
    # Coletar informações do usuário
    read -p "Nome do serviço: " service_name
    
    # Validar nome do serviço
    if [[ -z "$service_name" || ! "$service_name" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        error "Nome inválido. Use apenas letras minúsculas, números, _ e -"
        exit 1
    fi
    
    # Verificar se já existe
    if [[ -d "$service_name" ]]; then
        error "Serviço '$service_name' já existe"
        exit 1
    fi
    
    read -p "Descrição do serviço: " description
    read -p "Portas (separadas por vírgula, ex: 8080,9090): " ports
    read -p "Arquivos de configuração (separados por vírgula): " config_files
    read -p "Diretórios especiais (separados por vírgula): " special_dirs
    read -p "Binários necessários (separados por vírgula): " binaries
    
    log "Criando serviço '$service_name'..."
    
    # Criar estrutura
    create_service_structure "$service_name" "$config_files"
    create_service_json "$service_name" "$description" "$ports" "$config_files" "$special_dirs" "$binaries"
    
    log "Serviço '$service_name' criado com sucesso!"
    
    echo -e "\n${YELLOW}Próximos passos:${NC}"
    echo "1. Edite o arquivo $service_name/service.json se necessário"
    echo "2. Modifique o Dockerfile.$service_name"
    echo "3. Adicione binários necessários ao diretório $service_name/"
    echo "4. Configure arquivos de configuração em $service_name/"
    echo "5. Execute ./setup-docker-intelligent.sh para usar o serviço"
    
    # Mostrar conteúdo do service.json criado
    echo -e "\n${BLUE}Configuração criada:${NC}"
    jq . "$service_name/service.json"
}

# Executar
main "$@"
