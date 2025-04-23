# 🖥️ Script de Instalação Automatizada do Uptime Kuma com Podman (Rootless)

Este script instala e configura automaticamente o [Uptime Kuma](https://github.com/louislam/uptime-kuma), uma alternativa ao Uptime Robot, usando o [Podman](https://podman.io/) em modo rootless, com inicialização automática via `systemd --user`.

---

## ✅ O que o script faz?

1. **Atualiza os pacotes e instala o Podman**
2. **Configura corretamente o ambiente `XDG_RUNTIME_DIR`** para uso rootless
3. **Garante que a variável de ambiente seja persistente** via `.bashrc`
4. **Reseta o ambiente Podman** (opcional, para garantir um setup limpo)
5. **Cria volume persistente** para armazenar os dados do Uptime Kuma
6. **Executa o container em modo rootless**, escutando na porta `3001` em todas as interfaces (`0.0.0.0`)
7. **Gera automaticamente um arquivo `.service` do systemd** usando `podman generate systemd`
8. **Move o serviço para o local correto do usuário (`~/.config/systemd/user/`)**
9. **Ativa o `linger`** para que o serviço inicie mesmo após reboot sem login
10. **Ativa e inicia o serviço Uptime Kuma via systemd --user**
11. **Mostra o status final** do serviço

---

## 🚀 Como usar

1. Clone este repositório:
   ```bash
   git clone https://github.com/pagcoinbr/uptime-kuma-podman.git
   cd uptime-kuma-podman
   chmod +x uptimekuma_auto.sh
   ./uptimekuma_auto.sh
