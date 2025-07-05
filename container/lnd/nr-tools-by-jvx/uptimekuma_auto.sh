#!/bin/bash
# Script de instalação e configuração automatizada do Uptime Kuma com Podman rootless
# Autor: Luis @ BRLN

# Passo 1: Instalar Podman
sudo apt update && sudo apt install -y podman

# Passo 2: Verificar se o Podman está funcionando em modo rootless
export XDG_RUNTIME_DIR=/run/user/$(id -u)
mkdir -p "$XDG_RUNTIME_DIR"

# Adiciona export permanente no ~/.bashrc, se ainda não existir
if ! grep -q XDG_RUNTIME_DIR ~/.bashrc; then
  echo "export XDG_RUNTIME_DIR=/run/user/\$(id -u)" >> ~/.bashrc
fi

# Passo 3: Resetar o ambiente do Podman (caso já tenha sido usado antes)
podman system reset -f

# Passo 4: Criar volume persistente para o Uptime Kuma
podman volume create uptime-kuma

# Passo 5: Rodar o container rootless do Uptime Kuma
podman run -d \
  --name uptime-kuma \
  -p 0.0.0.0:3001:3001 \
  -v uptime-kuma:/app/data:Z \
  docker.io/louislam/uptime-kuma:1

# Passo 6: Gerar arquivo systemd para automatizar no boot
podman generate systemd \
  --name uptime-kuma \
  --files \
  --restart-policy=always \
  --container-prefix=

# Passo 7: Mover o arquivo para o local correto do systemd do usuario
mkdir -p ~/.config/systemd/user
mv ~/uptime-kuma.service ~/.config/systemd/user/

# Passo 8: Habilitar linger para permitir start automatico mesmo sem login
sudo loginctl enable-linger $USER

# Passo 9: Ativar o serviço para iniciar no boot do sistema
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable uptime-kuma
systemctl --user start uptime-kuma

# Fim: Status
systemctl --user status uptime-kuma
