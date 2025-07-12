#! /bin/bash

# Definir cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

sudo -v
echo "Iniciando instalação do BRLN-OS..."
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
        i=0
        while [ "$i" -le "$count" ]; do
            emoji="${emoji}⚡"
            i=$((i + 1))
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

(git clone https://github.com/pagcoinbr/brln-os.git) > /dev/null 2>&1 & spinner $!

cd brln-os || { echo "Diretório brln-os não encontrado"; exit 1; }

./setup.sh