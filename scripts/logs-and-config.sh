#!/bin/bash

# BRLN-OS Logs and Configuration Manager
# Interactive script to view logs and edit configuration files for all BRLN-OS services

# Import common functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Service configuration mapping
# Format: service_name:user:config_paths:description
declare -A SERVICE_CONFIG=(
    ["bitcoind"]="bitcoin:/data/bitcoin/bitcoin.conf:Bitcoin Core daemon configuration"
    ["lnd"]="lnd:/data/lnd/lnd.conf:Lightning Network daemon configuration" 
    ["elementsd"]="elements:/data/elements/elements.conf:Elements/Liquid daemon configuration"
    ["peerswapd"]="peerswap:/home/peerswap/.peerswap/peerswap.conf:PeerSwap daemon configuration"
    ["psweb"]="peerswap:/home/peerswap/.peerswap/psweb.conf:PeerSwap Web UI configuration"
    ["brln-api"]="brln-api:${BRLN_OS_DIR}/api/v1/app.py,/data/brln-wallet/:BRLN-OS API configuration and data"
    ["messager-monitor"]="brln-api:${BRLN_OS_DIR}/api/v1/messager_monitor_grpc.py:Lightning message monitor configuration"
    ["gotty-fullauto"]="root:${BRLN_OS_DIR}/scripts/menu.sh:Terminal web interface script"
    ["bos-telegram"]="$atual_user:/home/$atual_user/.bos/:Balance of Satoshis Telegram bot credentials"
    ["thunderhub"]="$atual_user:/home/$atual_user/thunderhub/thubConfig.yaml:ThunderHub configuration"
    ["lnbits"]="$atual_user:/home/$atual_user/lnbits/.env:LNbits environment configuration"
    ["lndg"]="$atual_user:/home/$atual_user/lndg/lndg/settings.py:LNDG Dashboard Django settings"
    ["lndg-controller"]="$atual_user:/home/$atual_user/lndg/data/:LNDG Controller data directory"
)

# Function to show main menu
show_main_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                📊 LOGS E CONFIGURAÇÕES BRLN-OS 📊                  ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}📋 Opções disponíveis:${NC}"
    echo -e "${GREEN}1.${NC} 📋 Ver logs de serviços (journalctl)"
    echo -e "${GREEN}2.${NC} ⚙️ Gerenciar arquivos de configuração"
    echo -e "${GREEN}3.${NC} 📊 Status detalhado dos serviços"
    echo -e "${GREEN}4.${NC} 🔍 Buscar arquivos de configuração"
    echo -e "${GREEN}5.${NC} 📁 Explorar diretórios de dados"
    echo ""
    echo -e "${BLUE}0.${NC} ↩️ Voltar ao menu anterior"
    echo ""
    echo -n "Escolha uma opção: "
}

# Function to list available services for logs
show_services_for_logs() {
    clear
    echo -e "${CYAN}📋 LOGS DOS SERVIÇOS BRLN-OS${NC}"
    echo ""
    echo -e "${YELLOW}Serviços disponíveis para visualização de logs:${NC}"
    echo ""
    
    local index=1
    local services=()
    
    for service_name in $(printf '%s\\n' "${!SERVICE_CONFIG[@]}" | sort); do
        local status=$(systemctl is-active "$service_name" 2>/dev/null || echo "not-found")
        local status_icon
        case "$status" in
            active) status_icon="${GREEN}●${NC}" ;;
            inactive) status_icon="${YELLOW}●${NC}" ;;
            failed) status_icon="${RED}●${NC}" ;;
            *) status_icon="${GRAY}●${NC}" ;;
        esac
        
        echo -e "${GREEN}${index}.${NC} $status_icon $service_name"
        services[$index]="$service_name"
        ((index++))
    done
    
    echo ""
    echo -e "${BLUE}0.${NC} ↩️ Voltar"
    echo ""
    echo -n "Escolha um serviço para ver os logs: "
    
    read choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ -n "${services[$choice]}" ]]; then
        show_service_logs "${services[$choice]}"
    else
        echo -e "${RED}❌ Opção inválida${NC}"
        sleep 2
        show_services_for_logs
    fi
}

# Function to show logs for a specific service
show_service_logs() {
    local service_name="$1"
    
    clear
    echo -e "${CYAN}📋 LOGS: $service_name${NC}"
    echo ""
    echo -e "${YELLOW}Opções de visualização:${NC}"
    echo -e "${GREEN}1.${NC} 📄 Últimas 50 linhas"
    echo -e "${GREEN}2.${NC} 📄 Últimas 100 linhas" 
    echo -e "${GREEN}3.${NC} 📄 Últimas 500 linhas"
    echo -e "${GREEN}4.${NC} 🔄 Acompanhar logs em tempo real (follow)"
    echo -e "${GREEN}5.${NC} ❌ Logs de erro apenas"
    echo -e "${GREEN}6.${NC} 📅 Logs desde ontem"
    echo ""
    echo -e "${BLUE}0.${NC} ↩️ Voltar"
    echo ""
    echo -n "Escolha uma opção: "
    
    read log_choice
    
    case "$log_choice" in
        1)
            echo -e "${BLUE}📋 Últimas 50 linhas de $service_name:${NC}"
            journalctl -u "$service_name" --no-pager -n 50
            echo ""
            read -p "Pressione Enter para continuar..."
            show_service_logs "$service_name"
            ;;
        2)
            echo -e "${BLUE}📋 Últimas 100 linhas de $service_name:${NC}"
            journalctl -u "$service_name" --no-pager -n 100
            echo ""
            read -p "Pressione Enter para continuar..."
            show_service_logs "$service_name"
            ;;
        3)
            echo -e "${BLUE}📋 Últimas 500 linhas de $service_name:${NC}"
            journalctl -u "$service_name" --no-pager -n 500 | less
            show_service_logs "$service_name"
            ;;
        4)
            echo -e "${BLUE}🔄 Acompanhando logs de $service_name (Ctrl+C para sair):${NC}"
            echo ""
            journalctl -u "$service_name" -f
            show_service_logs "$service_name"
            ;;
        5)
            echo -e "${BLUE}❌ Logs de erro de $service_name:${NC}"
            journalctl -u "$service_name" --no-pager -p err
            echo ""
            read -p "Pressione Enter para continuar..."
            show_service_logs "$service_name"
            ;;
        6)
            echo -e "${BLUE}📅 Logs de $service_name desde ontem:${NC}"
            journalctl -u "$service_name" --since yesterday --no-pager | less
            show_service_logs "$service_name"
            ;;
        0)
            show_services_for_logs
            ;;
        *)
            echo -e "${RED}❌ Opção inválida${NC}"
            sleep 2
            show_service_logs "$service_name"
            ;;
    esac
}

# Function to show configuration management menu
show_config_menu() {
    clear
    echo -e "${CYAN}⚙️ GERENCIAMENTO DE CONFIGURAÇÕES${NC}"
    echo ""
    echo -e "${YELLOW}Serviços disponíveis para edição:${NC}"
    echo ""
    
    local index=1
    local services=()
    
    for service_name in $(printf '%s\\n' "${!SERVICE_CONFIG[@]}" | sort); do
        IFS=':' read -r user config_paths description <<< "${SERVICE_CONFIG[$service_name]}"
        echo -e "${GREEN}${index}.${NC} $service_name - $description"
        services[$index]="$service_name"
        ((index++))
    done
    
    echo ""
    echo -e "${BLUE}0.${NC} ↩️ Voltar"
    echo ""
    echo -n "Escolha um serviço para editar configuração: "
    
    read choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ -n "${services[$choice]}" ]]; then
        edit_service_config "${services[$choice]}"
    else
        echo -e "${RED}❌ Opção inválida${NC}"
        sleep 2
        show_config_menu
    fi
}

# Function to edit configuration for a specific service
edit_service_config() {
    local service_name="$1"
    IFS=':' read -r user config_paths description <<< "${SERVICE_CONFIG[$service_name]}"
    
    clear
    echo -e "${CYAN}⚙️ CONFIGURAÇÃO: $service_name${NC}"
    echo -e "${BLUE}Usuário: $user${NC}"
    echo -e "${BLUE}Descrição: $description${NC}"
    echo ""
    
    # Split config paths by comma
    IFS=',' read -ra PATH_ARRAY <<< "$config_paths"
    
    echo -e "${YELLOW}Arquivos/diretórios de configuração:${NC}"
    local index=1
    local valid_paths=()
    
    for config_path in "${PATH_ARRAY[@]}"; do
        config_path=$(echo "$config_path" | xargs) # trim whitespace
        if [[ -e "$config_path" ]]; then
            if [[ -d "$config_path" ]]; then
                echo -e "${GREEN}${index}.${NC} 📁 $config_path (diretório)"
            else
                echo -e "${GREEN}${index}.${NC} 📄 $config_path (arquivo)"
            fi
            valid_paths[$index]="$config_path"
            ((index++))
        else
            echo -e "${GRAY}${index}.${NC} ❌ $config_path (não encontrado)"
            valid_paths[$index]="$config_path:missing"
            ((index++))
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Opções adicionais:${NC}"
    echo -e "${GREEN}90.${NC} 🔍 Buscar outros arquivos de configuração"
    echo -e "${GREEN}91.${NC} 📊 Ver status do serviço"
    echo -e "${GREEN}92.${NC} 🔄 Reiniciar serviço"
    echo ""
    echo -e "${BLUE}0.${NC} ↩️ Voltar"
    echo ""
    echo -n "Escolha uma opção: "
    
    read choice
    
    case "$choice" in
        0)
            show_config_menu
            ;;
        90)
            find_service_configs "$service_name" "$user"
            ;;
        91)
            show_service_status "$service_name"
            ;;
        92)
            restart_service "$service_name"
            ;;
        *)
            if [[ -n "${valid_paths[$choice]}" ]]; then
                local selected_path="${valid_paths[$choice]}"
                if [[ "$selected_path" =~ :missing$ ]]; then
                    selected_path="${selected_path%:missing}"
                    echo -e "${YELLOW}⚠️ Arquivo não encontrado: $selected_path${NC}"
                    echo -n "Deseja criá-lo? (s/N): "
                    read create_choice
                    if [[ "$create_choice" =~ ^[Ss]$ ]]; then
                        create_config_file "$selected_path" "$user"
                    fi
                else
                    edit_config_file "$selected_path" "$user"
                fi
                edit_service_config "$service_name"
            else
                echo -e "${RED}❌ Opção inválida${NC}"
                sleep 2
                edit_service_config "$service_name"
            fi
            ;;
    esac
}

# Function to edit a configuration file as the appropriate user
edit_config_file() {
    local config_path="$1"
    local user="$2"
    
    if [[ -d "$config_path" ]]; then
        echo -e "${BLUE}📁 Explorando diretório: $config_path${NC}"
        echo ""
        ls -la "$config_path"
        echo ""
        echo -n "Digite o nome do arquivo para editar (ou Enter para voltar): "
        read filename
        if [[ -n "$filename" ]]; then
            edit_config_file "$config_path/$filename" "$user"
        fi
        return
    fi
    
    echo -e "${YELLOW}📝 Editando: $config_path${NC}"
    echo -e "${BLUE}Como usuário: $user${NC}"
    echo ""
    
    # Check if file exists and is readable
    if [[ ! -r "$config_path" ]]; then
        echo -e "${RED}❌ Arquivo não pode ser lido ou não existe${NC}"
        sleep 2
        return
    fi
    
    # Choose editor
    echo -e "${YELLOW}Escolha o editor:${NC}"
    echo -e "${GREEN}1.${NC} nano (simples)"
    echo -e "${GREEN}2.${NC} vim (avançado)"
    echo -e "${GREEN}3.${NC} cat (apenas visualizar)"
    echo ""
    echo -n "Escolha (1-3): "
    read editor_choice
    
    case "$editor_choice" in
        1)
            if [[ "$user" == "root" ]]; then
                nano "$config_path"
            else
                sudo -u "$user" nano "$config_path"
            fi
            ;;
        2)
            if [[ "$user" == "root" ]]; then
                vim "$config_path"
            else
                sudo -u "$user" vim "$config_path"
            fi
            ;;
        3)
            echo -e "${BLUE}📄 Conteúdo de $config_path:${NC}"
            cat "$config_path"
            echo ""
            read -p "Pressione Enter para continuar..."
            ;;
        *)
            echo -e "${RED}❌ Opção inválida${NC}"
            sleep 1
            edit_config_file "$config_path" "$user"
            ;;
    esac
}

# Function to create a new configuration file
create_config_file() {
    local config_path="$1"
    local user="$2"
    
    echo -e "${YELLOW}📝 Criando arquivo: $config_path${NC}"
    echo -e "${BLUE}Como usuário: $user${NC}"
    
    # Create directory if needed
    local config_dir=$(dirname "$config_path")
    if [[ ! -d "$config_dir" ]]; then
        echo -e "${BLUE}Criando diretório: $config_dir${NC}"
        if [[ "$user" == "root" ]]; then
            sudo mkdir -p "$config_dir"
        else
            sudo -u "$user" mkdir -p "$config_dir"
        fi
    fi
    
    # Create empty file
    if [[ "$user" == "root" ]]; then
        sudo touch "$config_path"
    else
        sudo -u "$user" touch "$config_path"
    fi
    
    edit_config_file "$config_path" "$user"
}

# Function to find configuration files for a service
find_service_configs() {
    local service_name="$1"
    local user="$2"
    
    echo -e "${BLUE}🔍 Buscando arquivos de configuração para $service_name...${NC}"
    echo ""
    
    # Search in common locations
    local search_paths=(
        "/data/$service_name"
        "/home/$user"
        "/home/$user/.$service_name"
        "/etc/$service_name"
        "/usr/local/etc/$service_name"
    )
    
    for search_path in "${search_paths[@]}"; do
        if [[ -d "$search_path" ]]; then
            echo -e "${GREEN}📁 Encontrado diretório: $search_path${NC}"
            find "$search_path" -name "*.conf" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.ini" 2>/dev/null | head -10
        fi
    done
    
    echo ""
    read -p "Pressione Enter para continuar..."
}

# Function to show detailed service status
show_service_status() {
    local service_name="$1"
    
    echo -e "${BLUE}📊 Status detalhado de $service_name:${NC}"
    echo ""
    systemctl status "$service_name" --no-pager
    echo ""
    read -p "Pressione Enter para continuar..."
}

# Function to restart a service
restart_service() {
    local service_name="$1"
    
    echo -e "${YELLOW}🔄 Reiniciando $service_name...${NC}"
    echo -n "Confirma reinicialização? (s/N): "
    read confirm
    
    if [[ "$confirm" =~ ^[Ss]$ ]]; then
        sudo systemctl restart "$service_name"
        echo -e "${GREEN}✅ Serviço reiniciado${NC}"
        sleep 2
        show_service_status "$service_name"
    fi
}

# Function to search for configuration files system-wide
search_config_files() {
    clear
    echo -e "${CYAN}🔍 BUSCA DE ARQUIVOS DE CONFIGURAÇÃO${NC}"
    echo ""
    echo -e "${YELLOW}Opções de busca:${NC}"
    echo -e "${GREEN}1.${NC} Buscar por nome de serviço"
    echo -e "${GREEN}2.${NC} Buscar por extensão (.conf, .yaml, etc.)"
    echo -e "${GREEN}3.${NC} Buscar em diretório específico"
    echo -e "${GREEN}4.${NC} Buscar arquivos modificados recentemente"
    echo ""
    echo -e "${BLUE}0.${NC} ↩️ Voltar"
    echo ""
    echo -n "Escolha uma opção: "
    
    read search_choice
    
    case "$search_choice" in
        1)
            echo -n "Digite o nome do serviço: "
            read service_name
            echo -e "${BLUE}Buscando arquivos relacionados a '$service_name'...${NC}"
            find /data /home /etc -name "*$service_name*" -type f 2>/dev/null | grep -E "\\.(conf|yaml|yml|json|ini|cfg)$" | head -20
            ;;
        2)
            echo -n "Digite a extensão (ex: conf, yaml): "
            read extension
            echo -e "${BLUE}Buscando arquivos .$extension...${NC}"
            find /data /home /etc -name "*.$extension" -type f 2>/dev/null | head -20
            ;;
        3)
            echo -n "Digite o diretório: "
            read directory
            if [[ -d "$directory" ]]; then
                echo -e "${BLUE}Buscando configurações em $directory...${NC}"
                find "$directory" -name "*.conf" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.ini" 2>/dev/null
            else
                echo -e "${RED}❌ Diretório não encontrado${NC}"
            fi
            ;;
        4)
            echo -e "${BLUE}Arquivos de configuração modificados nas últimas 24h:${NC}"
            find /data /home /etc -name "*.conf" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.ini" -mtime -1 2>/dev/null
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}❌ Opção inválida${NC}"
            sleep 2
            search_config_files
            ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
    search_config_files
}

# Function to explore data directories
explore_data_directories() {
    clear
    echo -e "${CYAN}📁 EXPLORAR DIRETÓRIOS DE DADOS${NC}"
    echo ""
    
    local data_dirs=(
        "/data:Diretório principal de dados"
        "/home/bitcoin:Dados do Bitcoin Core"
        "/home/lnd:Dados do LND"
        "/home/elements:Dados do Elements"
        "/home/peerswap:Dados do PeerSwap"
        "/home/brln-api:Dados da API BRLN"
        "/home/$atual_user/.bos:Credenciais BOS"
        "/home/$atual_user/thunderhub:ThunderHub"
        "/home/$atual_user/lndg:LNDG Dashboard"
        "/home/$atual_user/lnbits:LNbits"
    )
    
    echo -e "${YELLOW}Diretórios disponíveis:${NC}"
    local index=1
    local valid_dirs=()
    
    for dir_info in "${data_dirs[@]}"; do
        IFS=':' read -r dir_path description <<< "$dir_info"
        if [[ -d "$dir_path" ]]; then
            echo -e "${GREEN}${index}.${NC} 📁 $dir_path - $description"
            valid_dirs[$index]="$dir_path"
            ((index++))
        fi
    done
    
    echo ""
    echo -e "${BLUE}0.${NC} ↩️ Voltar"
    echo ""
    echo -n "Escolha um diretório para explorar: "
    
    read choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ -n "${valid_dirs[$choice]}" ]]; then
        explore_directory "${valid_dirs[$choice]}"
    else
        echo -e "${RED}❌ Opção inválida${NC}"
        sleep 2
        explore_data_directories
    fi
}

# Function to explore a specific directory
explore_directory() {
    local dir_path="$1"
    
    clear
    echo -e "${CYAN}📁 EXPLORANDO: $dir_path${NC}"
    echo ""
    
    if [[ ! -d "$dir_path" ]]; then
        echo -e "${RED}❌ Diretório não encontrado${NC}"
        sleep 2
        return
    fi
    
    ls -la "$dir_path"
    echo ""
    echo -e "${YELLOW}Opções:${NC}"
    echo -e "${GREEN}1.${NC} 📄 Ver arquivo específico"
    echo -e "${GREEN}2.${NC} 📁 Entrar em subdiretório"
    echo -e "${GREEN}3.${NC} 🔍 Buscar arquivos neste diretório"
    echo ""
    echo -e "${BLUE}0.${NC} ↩️ Voltar"
    echo ""
    echo -n "Escolha uma opção: "
    
    read explore_choice
    
    case "$explore_choice" in
        1)
            echo -n "Digite o nome do arquivo: "
            read filename
            if [[ -f "$dir_path/$filename" ]]; then
                echo -e "${BLUE}📄 Conteúdo de $filename:${NC}"
                cat "$dir_path/$filename"
                echo ""
                read -p "Pressione Enter para continuar..."
            else
                echo -e "${RED}❌ Arquivo não encontrado${NC}"
                sleep 2
            fi
            explore_directory "$dir_path"
            ;;
        2)
            echo -n "Digite o nome do subdiretório: "
            read subdirname
            if [[ -d "$dir_path/$subdirname" ]]; then
                explore_directory "$dir_path/$subdirname"
            else
                echo -e "${RED}❌ Subdiretório não encontrado${NC}"
                sleep 2
                explore_directory "$dir_path"
            fi
            ;;
        3)
            echo -n "Digite o padrão de busca: "
            read pattern
            echo -e "${BLUE}🔍 Resultados da busca:${NC}"
            find "$dir_path" -name "*$pattern*" 2>/dev/null
            echo ""
            read -p "Pressione Enter para continuar..."
            explore_directory "$dir_path"
            ;;
        0)
            explore_data_directories
            ;;
        *)
            echo -e "${RED}❌ Opção inválida${NC}"
            sleep 2
            explore_directory "$dir_path"
            ;;
    esac
}

# Function to show detailed status of all services
show_detailed_status() {
    clear
    echo -e "${CYAN}📊 STATUS DETALHADO DOS SERVIÇOS${NC}"
    echo ""
    
    for service_name in $(printf '%s\\n' "${!SERVICE_CONFIG[@]}" | sort); do
        IFS=':' read -r user config_paths description <<< "${SERVICE_CONFIG[$service_name]}"
        
        echo -e "${BLUE}▶ $service_name${NC}"
        echo -e "   👤 Usuário: $user"
        echo -e "   📝 Descrição: $description"
        
        local status=$(systemctl is-active "$service_name" 2>/dev/null || echo "not-found")
        case "$status" in
            active) echo -e "   ${GREEN}● Status: Ativo${NC}" ;;
            inactive) echo -e "   ${YELLOW}● Status: Inativo${NC}" ;;
            failed) echo -e "   ${RED}● Status: Falhou${NC}" ;;
            *) echo -e "   ${GRAY}● Status: Não instalado${NC}" ;;
        esac
        
        # Check if config files exist
        IFS=',' read -ra PATH_ARRAY <<< "$config_paths"
        local config_status="${GREEN}✓${NC}"
        for config_path in "${PATH_ARRAY[@]}"; do
            config_path=$(echo "$config_path" | xargs)
            if [[ ! -e "$config_path" ]]; then
                config_status="${RED}✗${NC}"
                break
            fi
        done
        echo -e "   📄 Configuração: $config_status"
        echo ""
    done
    
    read -p "Pressione Enter para continuar..."
}

# Main function
main() {
    while true; do
        show_main_menu
        read choice
        
        case "$choice" in
            1)
                show_services_for_logs
                ;;
            2)
                show_config_menu
                ;;
            3)
                show_detailed_status
                ;;
            4)
                search_config_files
                ;;
            5)
                explore_data_directories
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}❌ Opção inválida${NC}"
                sleep 2
                ;;
        esac
    done
}

# Export functions for use by other scripts
export -f show_main_menu
export -f show_services_for_logs
export -f show_service_logs
export -f show_config_menu
export -f edit_service_config
export -f main

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ============================================================================
# RESUMO DO SCRIPT LOGS-AND-CONFIG.SH
# ============================================================================
#
# DESCRIÇÃO:
# - Ferramenta interativa para ver logs (journalctl), editar arquivos de
#   configuração, reiniciar serviços e explorar diretórios de dados.
#
# CARACTERÍSTICAS:
# - Mapeia serviços para caminhos de configuração, permite edição segura de
#   arquivos e oferece status detalhado de serviços e configs
#
# ============================================================================
