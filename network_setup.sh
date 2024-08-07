#!/bin/bash

# Atualiza a lista de pacotes e faz upgrade
sudo apt update && sudo apt full-upgrade -y

# Instala apt-transport-https
sudo apt install -y apt-transport-https

# Cria o arquivo de repositório do Tor e adiciona o conteúdo
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org jammy main
deb-src [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org jammy main" | sudo tee /etc/apt/sources.list.d/tor.list

# Baixa e instala a chave GPG do repositório Tor
sudo su -c "wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null"

# Atualiza a lista de pacotes e instala o Tor e a chave do Tor Project
sudo apt update && sudo apt install -y tor deb.torproject.org-keyring

# Edita o arquivo de configuração do Tor para descomentar a linha ControlPort 9051
sudo sed -i 's/^#ControlPort 9051/ControlPort 9051/' /etc/tor/torrc

# Recarrega o serviço do Tor
sudo systemctl reload tor

# Verifica se o Tor está ouvindo nas portas corretas
TOR_PORTS=$(sudo ss -tulpn | grep LISTEN | grep tor)

if echo "$TOR_PORTS" | grep -q "127.0.0.1:9050" && echo "$TOR_PORTS" | grep -q "127.0.0.1:9051"; then
    echo "Tor está configurado corretamente e ouvindo nas portas 9050 e 9051."
    # Adiciona o repositório e instala o i2pd
    wget -q -O - https://repo.i2pd.xyz/.help/add_repo | sudo bash -s -
    sudo apt update && sudo apt install -y i2pd
    echo "i2pd instalado com sucesso."
else
    echo "Erro: Tor não está ouvindo nas portas corretas."
fi
