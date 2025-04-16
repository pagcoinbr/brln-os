# Cores
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # Reset

# Spinner com ⚡ piscando, largura estável
spinner() {
    local pid=$!
    local delay=0.2
    local spinstr='|/-\'
    local spinlen=${#spinstr}
    local i=0
    local j=0

    tput civis  # Esconde o cursor

    while kill -0 $pid 2>/dev/null; do
        # Gira o emoji e o spinner
        local emoji=""
        if (( i % 2 == 0 )); then
            emoji="⚡"
        else
            emoji="  "  # dois espaços para compensar a largura do ⚡
        fi

        local spin_char="${spinstr:j:1}"

        printf "\rBR%sLN a instalar... [%c]" "$emoji" "$spin_char"

        sleep $delay
        i=$(( (i + 1) % 4 ))
        j=$(( (j + 1) % spinlen ))
    done

    printf "\r✅ BRLN instalado com sucesso!     \n"
    tput cnorm  # Mostra o cursor de volta
}



# Simulação de função "system update"
system_update() {
    sudo apt-get update # Verifica atualizacoes do sistema
    sudo apt-get upgrade -y # Faz atualização do sistema
}

# Exemplo completo
echo -e "${CYAN}🚀 Instalando preparações do sistema...${NC}"
echo -e "${YELLOW}Digite a senha do usuário admin caso solicitado.${NC}" 
read -p "Deseja exibir logs? (y/n): " verbose_mode

# Força pedido de password antes do background
sudo -v

if [[ "$verbose_mode" == "y" ]]; then
    system_update
elif [[ "$verbose_mode" == "n" ]]; then
    echo -e "${YELLOW}🕒 A instalação está sendo executada em segundo plano...${NC}"
    system_update >> /dev/null 2>&1 & spinner
    clear
else
    echo "Opção inválida."
    exit 1
fi

wait
echo -e "\033[43m\033[30m ✅ Instalação da interface gráfica e interface de rede concluída! \033[0m"
# menu  # Se quiser testar, comenta ou define esta função


