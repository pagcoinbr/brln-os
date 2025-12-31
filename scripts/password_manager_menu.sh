#!/bin/bash
# BRLN-OS Password Manager Menu
# Interactive menu for managing stored passwords

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../brln-tools/password_manager.sh"

show_password_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "╔══════════════════════════════════════════════════════════════════════╗"
        echo "║                    🔐 GERENCIADOR DE SENHAS 🔐                      ║"
        echo "╚══════════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        echo -e "${GREEN}1.${NC} 📋 Listar todas as senhas armazenadas"
        echo -e "${GREEN}2.${NC} ➕ Adicionar nova senha"
        echo -e "${GREEN}3.${NC} 🔍 Buscar senha específica"
        echo -e "${GREEN}4.${NC} 🗑️  Deletar senha"
        echo -e "${GREEN}0.${NC} ↩️  Voltar ao menu anterior"
        echo ""
        echo -n "Escolha uma opção: "
        read choice
        
        case $choice in
            1)
                clear
                echo -e "${CYAN}📋 SENHAS ARMAZENADAS${NC}"
                echo ""
                list_passwords
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
            2)
                clear
                echo -e "${CYAN}➕ ADICIONAR NOVA SENHA${NC}"
                echo ""
                read -p "Nome do serviço: " service_name
                read -p "Usuário: " username
                read -sp "Senha: " password
                echo ""
                read -p "Descrição: " description
                read -p "Porta (0 se não aplicável): " port
                read -p "URL (opcional): " url
                
                username="${username:-admin}"
                port="${port:-0}"
                
                echo ""
                store_password_full "$service_name" "$password" "$description" "$username" "$port" "$url"
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
            3)
                clear
                echo -e "${CYAN}🔍 BUSCAR SENHA${NC}"
                echo ""
                read -p "Nome do serviço: " service_name
                echo ""
                get_password "$service_name"
                echo ""
                echo -e "${YELLOW}Nota: Por segurança, apenas informações sobre o serviço são exibidas.${NC}"
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
            4)
                clear
                echo -e "${CYAN}🗑️  DELETAR SENHA${NC}"
                echo ""
                read -p "Nome do serviço: " service_name
                echo ""
                read -p "Tem certeza que deseja deletar '$service_name'? (s/N): " confirm
                
                if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
                    delete_password "$service_name"
                else
                    echo "Operação cancelada"
                fi
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${RED}Opção inválida!${NC}"
                sleep 2
                ;;
        esac
    done
}

# If script is run directly, show menu
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_password_menu
fi
