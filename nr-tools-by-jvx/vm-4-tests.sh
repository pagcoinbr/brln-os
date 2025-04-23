#!/bin/bash

# This script automates the process of managing a Multipass virtual machine (VM).
# It performs the following steps:
# 1. Installs Multipass using Snap if not already installed.
# 2. Defines the VM name as "brlnbolt".
# 3. Stops and deletes any existing VM with the same name, then purges unused data.
# 4. Creates a new VM with the specified name, allocating 4GB of RAM and 25GB of disk space.
# 5. Outputs instructions to access the newly created VM using the Multipass shell command and tests in a invoriment that not affects your main system.

if [[ ! $(command -v multipass) ]]; then
    echo "🔄 Multipass não encontrado. Instalando via Snap..."
    if [[ $(command -v snap) ]]; then
        sudo snap install multipass
    else
        echo "❌ Snap não encontrado. Instale o Snap e execute"

VM_NAME="brlnbolt"

echo "⛔ Parando e apagando a VM '$VM_NAME' se existir..."
multipass stop "$VM_NAME" 2>/dev/null
multipass delete "$VM_NAME" 2>/dev/null
multipass purge

echo "✅ VM anterior removida com sucesso."

echo "🚀 Criando nova VM '$VM_NAME' com 4GB RAM e 20GB de disco..."
multipass launch --name "$VM_NAME" --memory 4G --disk 25G

echo "🎉 VM '$VM_NAME' criada com sucesso!"
echo "🔑 Acesse o root com: multipass exec $VM_NAME -- sudo -i"