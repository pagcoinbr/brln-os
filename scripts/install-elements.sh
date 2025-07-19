#!/bin/bash

# Script para configurar Elements/Liquid
# Substitui as credenciais RPC no elements.conf.example

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Caminho para o arquivo de configuração
ELEMENTS_CONFIG_FILE_EXAMPLE="/root/brln-os/container/elements/elements.conf.example"
ELEMENTS_CONFIG_FILE="/root/brln-os/container/elements/elements.conf"
ELEMENTS_DATA_DIR="/data/elements"

# Verificar se o arquivo existe
if [ ! -f "$ELEMENTS_CONFIG_FILE_EXAMPLE" ]; then
    print_error "Arquivo $ELEMENTS_CONFIG_FILE_EXAMPLE não encontrado!"
    exit 1
fi

print_info "Configurando Elements RPC credentials..."
echo

# Solicitar credenciais do usuário
echo -n "Digite o nome de usuário RPC para Elements: "
read -r rpc_user

# Validar se o usuário não está vazio
if [ -z "$rpc_user" ]; then
    print_error "Nome de usuário não pode estar vazio!"
    exit 1
fi

echo -n "Digite a senha RPC para Elements: "
read -r rpc_password
echo  # Nova linha após entrada silenciosa

# Validar se a senha não está vazia
if [ -z "$rpc_password" ]; then
    print_error "Senha não pode estar vazia!"
    exit 1
fi

print_info "Atualizando configurações no arquivo $ELEMENTS_CONFIG_FILE_EXAMPLE..."

# Copia para oficializar o conf
cp "$ELEMENTS_CONFIG_FILE_EXAMPLE" "$ELEMENTS_CONFIG_FILE"

# Copia o .conf para o /data para ser acessado pelo container
cp "$ELEMENTS_CONFIG_FILE" "$ELEMENTS_DATA_DIR/elements.conf"

# Substituir rpcuser usando sed
sed -i "s/^rpcuser=.*/rpcuser=$rpc_user/" "$ELEMENTS_CONFIG_FILE"
if [ $? -eq 0 ]; then
    print_info "rpcuser atualizado com sucesso"
else
    print_error "Erro ao atualizar rpcuser"
    exit 1
fi

# Substituir rpcpassword usando sed
sed -i "s/^rpcpassword=.*/rpcpassword=$rpc_password/" "$ELEMENTS_CONFIG_FILE"
if [ $? -eq 0 ]; then
    print_info "rpcpassword atualizado com sucesso"
else
    print_error "Erro ao atualizar rpcpassword"
    exit 1
fi

print_info "Configuração concluída!"
print_info "As seguintes linhas foram atualizadas:"
echo "  rpcuser=$rpc_user"
echo "  rpcpassword=***"
echo
print_warning "Lembre-se de manter suas credenciais seguras!"
echo ""
echo -e "${CYAN}🚀 Instalando ThunderHub...${NC}"
read -p "Deseja exibir logs? (y/n): " verbose_mode
app="elements"
if [[ "$verbose_mode" == "y" ]]; then
docker-compose build $app
docker-compose up -d $app
elif [[ "$verbose_mode" == "n" ]]; then
echo -e "${YELLOW} 🕒 Aguarde, isso poderá demorar 10min ou mais. Seja paciente...${NC}"
docker-compose build $app >> /dev/null 2>&1 & spinner
docker-compose up -d $app >> /dev/null 2>&1 & spinner
clear
else
echo "Opção inválida."
fi 
