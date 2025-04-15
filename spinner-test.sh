# Cores
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # Reset

# Função de spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    echo -n " "
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Simulação de função "system update"
system_update() {
    apt-get update # Verifica atualizacoes do sistema
    apt-get upgrade -y # Faz atualização do sistema
}

# Exemplo completo
echo -e "${CYAN}🚀 Instalando preparações do sistema...${NC}"
echo -e "${YELLOW}Digite a senha do usuário admin caso solicitado.${NC}" 
read -p "Deseja exibir logs? (y/n): " verbose_mode

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


