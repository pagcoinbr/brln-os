#!/bin/bash

# BRLN-OS Wallet Manager - Terminal Interface
# Interactive menu for wallet creation and management
# Designed to run after Bitcoin sync is complete

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Source config if available
if [[ -f "$SCRIPT_DIR/scripts/config.sh" ]]; then
    source "$SCRIPT_DIR/scripts/config.sh"
fi

# Detect Bitcoin network
detect_network() {
    if [[ -f "/data/bitcoin/bitcoin.conf" ]]; then
        if grep -q "testnet=1\|chain=test" /data/bitcoin/bitcoin.conf 2>/dev/null; then
            echo "testnet"
            return
        elif grep -q "signet=1\|chain=signet" /data/bitcoin/bitcoin.conf 2>/dev/null; then
            echo "signet"
            return
        elif grep -q "regtest=1\|chain=regtest" /data/bitcoin/bitcoin.conf 2>/dev/null; then
            echo "regtest"
            return
        fi
    fi
    
    # Check for network directories
    if [[ -d "/data/bitcoin/testnet3" ]] || [[ -d "/data/bitcoin/testnet4" ]]; then
        echo "testnet"
    elif [[ -d "/data/bitcoin/signet" ]]; then
        echo "signet"
    elif [[ -d "/data/bitcoin/regtest" ]]; then
        echo "regtest"
    else
        echo "mainnet"
    fi
}

# Get bitcoin-cli command with correct network flag
get_bitcoin_cli() {
    local network=$(detect_network)
    local cmd="bitcoin-cli -datadir=/data/bitcoin"
    
    case "$network" in
        testnet) echo "$cmd -testnet" ;;
        signet) echo "$cmd -signet" ;;
        regtest) echo "$cmd -regtest" ;;
        *) echo "$cmd" ;;
    esac
}

# Print banner
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║   ██████╗ ██████╗ ██╗     ███╗   ██╗       ██████╗ ███████╗   ║"
    echo "║   ██╔══██╗██╔══██╗██║     ████╗  ██║      ██╔═══██╗██╔════╝   ║"
    echo "║   ██████╔╝██████╔╝██║     ██╔██╗ ██║█████╗██║   ██║███████╗   ║"
    echo "║   ██╔══██╗██╔══██╗██║     ██║╚██╗██║╚════╝██║   ██║╚════██║   ║"
    echo "║   ██████╔╝██║  ██║███████╗██║ ╚████║      ╚██████╔╝███████║   ║"
    echo "║   ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝       ╚═════╝ ╚══════╝   ║"
    echo "║                                                               ║"
    echo "║              🔐 WALLET MANAGER - Terminal Edition             ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check Bitcoin sync status
check_bitcoin_sync() {
    echo -e "${YELLOW}📊 Verificando status do Bitcoin...${NC}"
    
    if ! systemctl is-active --quiet bitcoind; then
        echo -e "${RED}❌ Bitcoin Core não está rodando${NC}"
        echo -e "${YELLOW}💡 Execute: sudo systemctl start bitcoind${NC}"
        return 1
    fi
    
    local btc_cli=$(get_bitcoin_cli)
    local info=$($btc_cli getblockchaininfo 2>/dev/null)
    
    if [[ -z "$info" ]]; then
        echo -e "${RED}❌ Não foi possível conectar ao Bitcoin Core${NC}"
        return 1
    fi
    
    local blocks=$(echo "$info" | jq -r '.blocks')
    local headers=$(echo "$info" | jq -r '.headers')
    local progress=$(echo "$info" | jq -r '.verificationprogress')
    local ibd=$(echo "$info" | jq -r '.initialblockdownload')
    local chain=$(echo "$info" | jq -r '.chain')
    
    local progress_pct=$(echo "$progress * 100" | bc -l 2>/dev/null | cut -d. -f1)
    [[ -z "$progress_pct" ]] && progress_pct="0"
    
    echo -e "${GREEN}✅ Bitcoin Core está rodando${NC}"
    echo -e "${BLUE}   Rede: ${CYAN}$chain${NC}"
    echo -e "${BLUE}   Blocos: ${CYAN}$blocks / $headers${NC}"
    echo -e "${BLUE}   Progresso: ${CYAN}${progress_pct}%${NC}"
    
    if [[ "$ibd" == "true" ]]; then
        echo -e "${YELLOW}⚠️  Sincronização inicial em andamento${NC}"
        return 2
    fi
    
    echo -e "${GREEN}✅ Blockchain sincronizada!${NC}"
    return 0
}

# Check LND status
check_lnd_status() {
    echo -e "${YELLOW}⚡ Verificando status do LND...${NC}"
    
    if ! systemctl is-active --quiet lnd; then
        echo -e "${RED}❌ LND não está rodando${NC}"
        return 1
    fi
    
    local status=$(systemctl show -p StatusText lnd | cut -d= -f2)
    echo -e "${BLUE}   Status: ${CYAN}$status${NC}"
    
    if [[ "$status" == "Wallet locked" ]]; then
        echo -e "${YELLOW}🔒 Carteira bloqueada - precisa ser criada ou desbloqueada${NC}"
        return 2
    fi
    
    # Try to get info
    if lncli getinfo &>/dev/null; then
        local info=$(lncli getinfo)
        local pubkey=$(echo "$info" | jq -r '.identity_pubkey')
        local alias=$(echo "$info" | jq -r '.alias')
        local synced=$(echo "$info" | jq -r '.synced_to_chain')
        
        echo -e "${GREEN}✅ LND está operacional${NC}"
        echo -e "${BLUE}   Alias: ${CYAN}$alias${NC}"
        echo -e "${BLUE}   Pubkey: ${CYAN}${pubkey:0:20}...${NC}"
        echo -e "${BLUE}   Sincronizado: ${CYAN}$synced${NC}"
        return 0
    fi
    
    return 1
}

# Get LND password from file
get_lnd_password() {
    local password_file="/data/lnd/password.txt"
    
    if [[ -f "$password_file" ]]; then
        cat "$password_file"
        return 0
    fi
    
    echo ""
    return 1
}

# Create new LND wallet with LND-generated seed
create_lnd_wallet_new() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🆕 Criar Nova Carteira LND (Seed Novo)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    # Check if LND is running and waiting
    if ! systemctl is-active --quiet lnd; then
        echo -e "${YELLOW}🚀 Iniciando LND...${NC}"
        sudo systemctl start lnd
        sleep 3
    fi
    
    local status=$(systemctl show -p StatusText lnd | cut -d= -f2)
    if [[ "$status" != "Wallet locked" ]]; then
        echo -e "${RED}❌ LND não está esperando criação de carteira${NC}"
        echo -e "${BLUE}   Status atual: $status${NC}"
        return 1
    fi
    
    # Get password
    local password=$(get_lnd_password)
    if [[ -z "$password" ]]; then
        echo -e "${YELLOW}🔐 Digite a senha para a carteira LND:${NC}"
        read -s password
        echo
        echo -e "${YELLOW}🔐 Confirme a senha:${NC}"
        read -s password_confirm
        echo
        
        if [[ "$password" != "$password_confirm" ]]; then
            echo -e "${RED}❌ Senhas não coincidem!${NC}"
            return 1
        fi
        
        # Save password
        echo -n "$password" | sudo tee /data/lnd/password.txt > /dev/null
        sudo chmod 640 /data/lnd/password.txt
        sudo chown lnd:lnd /data/lnd/password.txt
    else
        echo -e "${GREEN}✅ Usando senha salva em /data/lnd/password.txt${NC}"
    fi
    
    echo
    echo -e "${YELLOW}🚀 Criando carteira com novo seed...${NC}"
    echo -e "${MAGENTA}⚠️  IMPORTANTE: Anote o seed que será exibido!${NC}"
    echo
    echo -e "${YELLOW}Pressione ENTER para continuar...${NC}"
    read
    
    # Use expect script if available
    if [[ -f "$SCRIPT_DIR/scripts/auto-lnd-create-new.exp" ]]; then
        export LND_WALLET_PASSWORD="$password"
        expect "$SCRIPT_DIR/scripts/auto-lnd-create-new.exp"
        unset LND_WALLET_PASSWORD
    else
        # Manual creation
        echo -e "${BLUE}Execute manualmente: lncli create${NC}"
        lncli create
    fi
    
    echo
    echo -e "${GREEN}✅ Processo de criação concluído!${NC}"
    sleep 2
    
    # Check if wallet was created
    check_lnd_status
}

# Create LND wallet with existing seed
create_lnd_wallet_restore() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🔄 Restaurar Carteira LND (Seed Existente)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    # Check if LND is running and waiting
    if ! systemctl is-active --quiet lnd; then
        echo -e "${YELLOW}🚀 Iniciando LND...${NC}"
        sudo systemctl start lnd
        sleep 3
    fi
    
    local status=$(systemctl show -p StatusText lnd | cut -d= -f2)
    if [[ "$status" != "Wallet locked" ]]; then
        echo -e "${RED}❌ LND não está esperando criação de carteira${NC}"
        echo -e "${BLUE}   Status atual: $status${NC}"
        return 1
    fi
    
    # Get password
    local password=$(get_lnd_password)
    if [[ -z "$password" ]]; then
        echo -e "${YELLOW}🔐 Digite a senha para a carteira LND:${NC}"
        read -s password
        echo
        echo -e "${YELLOW}🔐 Confirme a senha:${NC}"
        read -s password_confirm
        echo
        
        if [[ "$password" != "$password_confirm" ]]; then
            echo -e "${RED}❌ Senhas não coincidem!${NC}"
            return 1
        fi
        
        # Save password
        echo -n "$password" | sudo tee /data/lnd/password.txt > /dev/null
        sudo chmod 640 /data/lnd/password.txt
        sudo chown lnd:lnd /data/lnd/password.txt
    else
        echo -e "${GREEN}✅ Usando senha salva em /data/lnd/password.txt${NC}"
    fi
    
    echo
    echo -e "${YELLOW}📝 Digite seu seed de 24 palavras (em uma linha):${NC}"
    read seed_phrase
    
    if [[ -z "$seed_phrase" ]]; then
        echo -e "${RED}❌ Seed não pode estar vazio!${NC}"
        return 1
    fi
    
    # Count words
    local word_count=$(echo "$seed_phrase" | wc -w)
    if [[ $word_count -ne 24 ]]; then
        echo -e "${YELLOW}⚠️  Seed tem $word_count palavras (esperado 24)${NC}"
        echo -e "${YELLOW}Continuar mesmo assim? (s/N):${NC}"
        read confirm
        if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
            return 1
        fi
    fi
    
    echo
    echo -e "${YELLOW}🚀 Restaurando carteira...${NC}"
    
    # Use expect script if available
    if [[ -f "$SCRIPT_DIR/scripts/auto-lnd-create.exp" ]]; then
        export LND_WALLET_PASSWORD="$password"
        expect "$SCRIPT_DIR/scripts/auto-lnd-create.exp" "$seed_phrase"
        unset LND_WALLET_PASSWORD
    else
        # Manual creation
        echo -e "${BLUE}Execute manualmente: lncli create${NC}"
        echo -e "${BLUE}Responda 'y' para usar seed existente${NC}"
        lncli create
    fi
    
    echo
    echo -e "${GREEN}✅ Processo de restauração concluído!${NC}"
    sleep 2
    
    check_lnd_status
}

# Unlock LND wallet
unlock_lnd_wallet() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🔓 Desbloquear Carteira LND${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    local password=$(get_lnd_password)
    if [[ -z "$password" ]]; then
        echo -e "${YELLOW}🔐 Digite a senha da carteira LND:${NC}"
        read -s password
        echo
    else
        echo -e "${GREEN}✅ Usando senha salva${NC}"
    fi
    
    echo -e "${YELLOW}🔓 Desbloqueando carteira...${NC}"
    
    if [[ -f "$SCRIPT_DIR/scripts/auto-lnd-unlock.exp" ]]; then
        export LND_WALLET_PASSWORD="$password"
        expect "$SCRIPT_DIR/scripts/auto-lnd-unlock.exp"
        unset LND_WALLET_PASSWORD
    else
        echo "$password" | lncli unlock --stdin
    fi
    
    sleep 3
    check_lnd_status
}

# Configure Elements/Liquid wallet
configure_elements_wallet() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}💧 Configurar Carteira Elements/Liquid${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    if ! systemctl is-active --quiet elementsd; then
        echo -e "${YELLOW}🚀 Iniciando Elements...${NC}"
        sudo systemctl start elementsd
        sleep 5
    fi
    
    if ! systemctl is-active --quiet elementsd; then
        echo -e "${RED}❌ Elements não está rodando${NC}"
        echo -e "${YELLOW}💡 Verifique se o Elements está instalado${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Verificando carteira Elements...${NC}"
    
    # Check if wallet exists
    local wallets=$(elements-cli listwallets 2>/dev/null)
    
    if [[ "$wallets" == "[]" ]]; then
        echo -e "${YELLOW}📦 Criando carteira Elements...${NC}"
        elements-cli createwallet "default" false false "" false false
        echo -e "${GREEN}✅ Carteira criada!${NC}"
    else
        echo -e "${GREEN}✅ Carteira já existe${NC}"
    fi
    
    # Get new address
    echo -e "${YELLOW}🔑 Gerando novo endereço Liquid...${NC}"
    local address=$(elements-cli getnewaddress 2>/dev/null)
    
    if [[ -n "$address" ]]; then
        echo -e "${GREEN}✅ Endereço Liquid:${NC}"
        echo -e "${CYAN}   $address${NC}"
    fi
    
    echo
    echo -e "${YELLOW}Pressione ENTER para continuar...${NC}"
    read
}

# Configure TRON wallet
configure_tron_wallet() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🔴 Configurar Carteira TRON${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    echo -e "${YELLOW}🔐 Digite a senha de criptografia:${NC}"
    read -s encryption_password
    echo
    
    if [[ -z "$encryption_password" ]]; then
        echo -e "${RED}❌ Senha não pode estar vazia!${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🚀 Inicializando carteira TRON via API...${NC}"
    
    local response=$(curl -s -k -X POST https://localhost/api/v1/tron/wallet/initialize \
        -H "Content-Type: application/json" \
        -d "{\"encryption_password\": \"$encryption_password\"}")
    
    if echo "$response" | jq -e '.address' &>/dev/null; then
        local address=$(echo "$response" | jq -r '.address')
        echo -e "${GREEN}✅ Carteira TRON criada!${NC}"
        echo -e "${CYAN}   Endereço: $address${NC}"
    else
        local error=$(echo "$response" | jq -r '.error // .message // "Erro desconhecido"')
        echo -e "${RED}❌ Erro: $error${NC}"
    fi
    
    echo
    echo -e "${YELLOW}Pressione ENTER para continuar...${NC}"
    read
}

# View service status
view_service_status() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📊 Status dos Serviços${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    local services="bitcoind lnd elementsd peerswapd brln-api apache2 tor"
    
    for svc in $services; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            local status_text=$(systemctl show -p StatusText "$svc" 2>/dev/null | cut -d= -f2)
            [[ -z "$status_text" ]] && status_text="Running"
            echo -e "${GREEN}✅ $svc${NC}: ${CYAN}$status_text${NC}"
        elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            echo -e "${YELLOW}⏸️  $svc${NC}: Parado (habilitado)"
        else
            echo -e "${RED}❌ $svc${NC}: Não instalado/configurado"
        fi
    done
    
    echo
    echo -e "${YELLOW}Pressione ENTER para continuar...${NC}"
    read
}

# Start/Stop services submenu
manage_services_menu() {
    while true; do
        print_banner
        echo -e "${BLUE}⚙️  Gerenciar Serviços${NC}"
        echo
        echo -e "${GREEN}1.${NC} Iniciar Bitcoin Core"
        echo -e "${GREEN}2.${NC} Parar Bitcoin Core"
        echo -e "${GREEN}3.${NC} Iniciar LND"
        echo -e "${GREEN}4.${NC} Parar LND"
        echo -e "${GREEN}5.${NC} Reiniciar API"
        echo -e "${GREEN}6.${NC} Ver logs (journalctl)"
        echo -e "${RED}0.${NC} Voltar"
        echo
        echo -n "Escolha uma opção: "
        read choice
        
        case $choice in
            1) sudo systemctl start bitcoind && echo -e "${GREEN}✅ Bitcoin iniciado${NC}" ;;
            2) sudo systemctl stop bitcoind && echo -e "${YELLOW}⏹️  Bitcoin parado${NC}" ;;
            3) sudo systemctl start lnd && echo -e "${GREEN}✅ LND iniciado${NC}" ;;
            4) sudo systemctl stop lnd && echo -e "${YELLOW}⏹️  LND parado${NC}" ;;
            5) sudo systemctl restart brln-api && echo -e "${GREEN}✅ API reiniciada${NC}" ;;
            6)
                echo -e "${BLUE}Qual serviço? (bitcoind/lnd/brln-api):${NC}"
                read svc
                journalctl -u "$svc" -n 50 --no-pager
                ;;
            0) return ;;
            *) echo -e "${RED}Opção inválida${NC}" ;;
        esac
        
        echo -e "${YELLOW}Pressione ENTER...${NC}"
        read
    done
}

# LND wallet submenu
lnd_wallet_menu() {
    while true; do
        print_banner
        echo -e "${BLUE}⚡ Gerenciamento de Carteira LND${NC}"
        echo
        
        check_lnd_status
        echo
        
        echo -e "${GREEN}1.${NC} Criar nova carteira (gerar seed)"
        echo -e "${GREEN}2.${NC} Restaurar carteira (seed existente)"
        echo -e "${GREEN}3.${NC} Desbloquear carteira"
        echo -e "${GREEN}4.${NC} Ver informações da carteira"
        echo -e "${GREEN}5.${NC} Gerar novo endereço"
        echo -e "${RED}0.${NC} Voltar"
        echo
        echo -n "Escolha uma opção: "
        read choice
        
        case $choice in
            1) create_lnd_wallet_new ;;
            2) create_lnd_wallet_restore ;;
            3) unlock_lnd_wallet ;;
            4)
                if lncli getinfo &>/dev/null; then
                    lncli getinfo | jq '.'
                else
                    echo -e "${RED}❌ Não foi possível conectar ao LND${NC}"
                fi
                echo -e "${YELLOW}Pressione ENTER...${NC}"
                read
                ;;
            5)
                if lncli newaddress p2wkh &>/dev/null; then
                    local addr=$(lncli newaddress p2wkh | jq -r '.address')
                    echo -e "${GREEN}✅ Novo endereço: ${CYAN}$addr${NC}"
                else
                    echo -e "${RED}❌ Erro ao gerar endereço${NC}"
                fi
                echo -e "${YELLOW}Pressione ENTER...${NC}"
                read
                ;;
            0) return ;;
            *) 
                echo -e "${RED}Opção inválida${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main menu
main_menu() {
    while true; do
        print_banner
        
        local network=$(detect_network)
        echo -e "${BLUE}📡 Rede: ${CYAN}${network^^}${NC}"
        echo
        
        echo -e "${GREEN}1.${NC} 📊 Status dos Serviços"
        echo -e "${GREEN}2.${NC} ₿  Verificar Sincronização Bitcoin"
        echo -e "${GREEN}3.${NC} ⚡ Carteira LND (Lightning)"
        echo -e "${GREEN}4.${NC} 💧 Carteira Elements/Liquid"
        echo -e "${GREEN}5.${NC} 🔴 Carteira TRON"
        echo -e "${GREEN}6.${NC} ⚙️  Gerenciar Serviços"
        echo -e "${RED}0.${NC} Sair"
        echo
        echo -n "Escolha uma opção: "
        read choice
        
        case $choice in
            1) view_service_status ;;
            2) 
                check_bitcoin_sync
                echo -e "${YELLOW}Pressione ENTER...${NC}"
                read
                ;;
            3) lnd_wallet_menu ;;
            4) configure_elements_wallet ;;
            5) configure_tron_wallet ;;
            6) manage_services_menu ;;
            0) 
                echo -e "${GREEN}👋 Até logo!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Opção inválida${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main menu
main_menu
