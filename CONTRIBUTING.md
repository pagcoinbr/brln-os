# 📘 Documentação Técnica - BR⚡LN Bolt

> Guia detalhado para desenvolvedores e colaboradores do projeto BR⚡LN Bolt.

## 🏗️ Estrutura do Projeto

```
brlnfullauto/
├── brunel.sh                # Script principal de instalação
├── control-systemd.py       # Controle Python para serviços systemd
├── README.md                # Documentação principal
├── run.sh                   # Script de entrada principal
├── conf_files/              # Arquivos de configuração para serviços
│   ├── bitcoin.conf
│   ├── elements.conf
│   ├── lnd.conf
│   └── peerswap.conf
├── docker/                  # Arquivos relacionados a containers
├── docs/                    # Documentação específica por componente
├── html/                    # Interface web front-end
│   ├── index.html
│   ├── main.html
│   ├── radio.html
│   ├── cgi-bin/             # Scripts CGI para controle via web
│   ├── css/
│   ├── js/
│   └── imagens/
├── local_apps/              # Binários e arquivos de aplicações
├── logs/                    # Diretório de logs
├── scripts/                 # Scripts auxiliares
├── services/                # Arquivos de configuração systemd
└── shell/                   # Scripts de shell para cada componente
    ├── .env                 # Variáveis de ambiente globais
    ├── interface.sh         # Interface gráfica e web
    ├── menu.sh              # Sistema de menus interativos
    ├── update_interface.sh  # Atualização da interface
    ├── adm_apps/            # Scripts para aplicações admin
    ├── adm_menu.sh          # Menu administrativo
    └── nodes/               # Scripts para nós Bitcoin/Lightning
        ├── bitcoind.sh
        ├── elementsd.sh
        ├── lnd.sh
        └── network.sh
```

## 🚀 Primeiros Passos para Desenvolvedores

### 1. Clonar o Repositório
```bash
git clone https://github.com/REDACTED_USERbr/brlnfullauto.git
cd brlnfullauto
```

### 2. Ambiente de Desenvolvimento
Recomendamos trabalhar em um ambiente Ubuntu similar ao de produção:
- Ubuntu 22.04 ou 24.04
- Usuário com permissões sudo
- Configuração de rede local para testes

### 3. Entendendo o Fluxo de Execução

O projeto segue este fluxo:
1. `run.sh` é o ponto de entrada inicial (criação de usuário)
2. `brunel.sh` contém o menu principal e funções core
3. `shell/menu.sh` gerencia os submenus e opções
4. `shell/interface.sh` configura a interface web
5. Scripts especializados em `shell/nodes` e `shell/adm_apps`

## 📋 Arquitetura do Sistema

### Sistema de Menu Interativo

O sistema de menus é estruturado em camadas:
1. **Menu Principal** (`menu()` em brunel.sh)
2. **Submenus** (menu1, menu2, menu3 em shell/menu.sh)
3. **Menus Específicos** (submenu_opcoes, menu_manutencao)

Cada opção de menu chama funções específicas que:
1. Solicitam inputs necessários
2. Mostram opções de log (verboso ou silencioso)
3. Executam a instalação com feedback visual (spinner)
4. Reportam sucesso/erro e retornam ao menu

#### Como o Sistema de Spinner Funciona:
```bash
function spinner() {
    local pid=$!
    local delay=0.2
    local max=${SPINNER_MAX:-20}
    local count=0
    local spinstr='|/-\\'
    local j=0

    tput civis  # Esconde o cursor

    # Monitora processo 
    while kill -0 "$pid" 2>/dev/null; do
        local emoji=""
        for ((i=0; i<=count; i++)); do
            emoji+="⚡"
        done

        # Rotaciona caracteres de spinner e emojis
        local spin_char="${spinstr:j:1}"
        j=$(( (j + 1) % 4 ))
        count=$(( (count + 1) % (max + 1) ))

        # Atualiza a linha atual com feedback visual
        printf "\r\033[KInstalando seu BRLN bolt...${YELLOW}%s${NC} ${CYAN}[%s]${NC}" "$emoji" "$spin_char"
        sleep "$delay"
    done

    wait "$pid"
    exit_code=$?

    tput cnorm  # Restaura o cursor
    # Exibe mensagem de sucesso ou erro
}
```

### Sistema de Serviços

O projeto gerencia serviços via systemd:
1. Cada aplicação tem seu arquivo `.service` em `services`
2. A ativação é feita via `systemctl enable` e `systemctl start`
3. O controle web usa `control-systemd.py` para interagir via web

### Interface Web

A interface web combina:
1. **Frontend HTML/CSS/JS** - Em `html`
2. **Backend CGI** - Scripts em `html/cgi-bin`
3. **Servidor Apache** - Configurado via `shell/update_interface.sh`
4. **API REST Flask** - Via `control-systemd.py` na porta 5001

#### Sistema de Monitoramento:
O monitoramento de serviços ocorre em várias camadas:

1. **Verificação periódica** em JavaScript (main.js):
```javascript
// Atualiza status dos botões de serviços a cada 5 segundos
async function updateButtons() {
  for (const appName of appsServicos) {
    const button = document.getElementById(`${appName}-button`);
    if (!button) continue;
    try {
      const response = await fetch(`${flaskBaseURL}/service-status?app=${appName}`);
      const data = await response.json();
      button.checked = data.active; // marca ou desmarca o switch
      button.dataset.action = data.active ? "stop" : "start";
    } catch (error) {
      console.error(`Erro ao verificar status de ${appName}:`, error);
    }
  }
}
```

2. **API Flask** que verifica status dos serviços systemd
3. **CGI Scripts** que coletam informações do sistema

## 🔌 Portas e Serviços

O sistema utiliza as seguintes portas:

| Porta | Serviço | Descrição | Acesso |
|-------|---------|-----------|--------|
| 80 | Apache | Interface Web Principal | LAN |
| 3000 | Thunderhub | Gerenciamento de LN | LAN |
| 3131 | Gotty - BRLNFullAuto | Terminal interativo web | LAN |
| 3232 | Gotty - CLI | Terminal de comandos | LAN |
| 3333 | Gotty - LND Editor | Editor de lnd.conf | LAN |
| 3434 | Gotty - Bitcoin Logs | Logs Bitcoin Core | LAN |
| 3535 | Gotty - LND Logs | Logs LND | LAN |
| 3636 | Gotty - BTC Editor | Editor de bitcoin.conf | LAN |
| 5000 | LNbits | Sistema bancário LN | LAN |
| 5001 | Control-systemd | API para controle de serviços | LAN |
| 8889 | LNDG | Dashboard e estatísticas | LAN |
| 35671 | Simple LNWallet | Interface simplificada | LAN |
| 8080 | PeerSwapWeb | Interface PeerSwap (opcional) | LAN |
| 9050/9051 | Tor SOCKS | Proxy Tor (interno) | localhost |
| 8333 | Bitcoin | P2P Bitcoin (opcional) | Externo/Tor |
| 9735 | Lightning | P2P Lightning (opcional) | Externo/Tor |

> Portas expostas externamente são configuradas via Tor Hidden Services para maior segurança.

## 🔒 Segurança e Firewall

O acesso de rede é gerenciado via UFW:
1. **SSH (22)**: Apenas da subrede local
2. **Interfaces web**: Apenas da subrede local
3. **Serviços Bitcoin/LN**: Via Tor Hidden Services

As regras são aplicadas via:
```bash
function configure_ufw() {
  # Configura IPv6=no no UFW
  sudo sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw
  
  # Reseta e habilita UFW
  sudo ufw --force reset
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  
  # Libera SSH apenas para rede local
  sudo ufw allow from $subnet to any port 22 proto tcp comment 'allow SSH from local network'
  
  # Libera interfaces web apenas para rede local
  sudo ufw allow from $subnet to any port 80 proto tcp comment 'allow Apache from local network'
  # ... outras portas
  
  # Ativa o firewall
  sudo ufw --force enable
}
```

## 🛠️ Fluxo de Desenvolvimento

### Adicionando um Novo Componente

Para adicionar um novo componente ao sistema:

1. **Crie o script de instalação**:
   - Para aplicativo de gerenciamento: `shell/adm_apps/novo_app.sh`
   - Para node/serviço core: `shell/nodes/novo_node.sh`

2. **Defina o arquivo de serviço systemd**:
   - Crie `services/novo_app.service`

3. **Adicione ao menu**:
   - Edite `shell/menu.sh` e adicione nova opção ao menu apropriado

4. **Atualize a interface web**:
   - Adicione botão em `html/main.html`
   - Adicione lógica de monitoramento em `html/js/main.js`
   - Adicione o serviço à lista `appsServicos` em `html/js/main.js`

### Estilo de Código

Seguimos estas práticas:
- **Bash**: Use funções para organizar o código
- **Comentários**: Explique seções complexas
- **Tratamento de erros**: Use verificações e retorno de código adequados
- **Variáveis de ambiente**: Defina em `shell/.env`

## 🔮 Roadmap e Melhorias Planejadas

Melhorias em desenvolvimento:

1. **Suporte a Docker** - Containerização de serviços para melhor isolamento
2. **Atualização Automática** - Sistema para atualizar componentes via cron
3. **Backup Automático** - Backup de seed e configurações em dispositivos externos
4. **Instalação multinode** - Suporte para executar múltiplos nós LND
5. **Statoshi** - Integração com métricas avançadas e Prometheus/Grafana
6. **Ampliação de Hardening** - Mais recursos de segurança e auditorias
7. **Uptime Kuma** - Monitoramento mais completo dos serviços

## 🤝 Como Contribuir

1. **Fork** o repositório
2. **Clone** seu fork localmente
3. **Crie uma branch** para sua funcionalidade: `git checkout -b feature/nova-funcionalidade`
4. **Implemente** suas alterações
5. **Teste** exaustivamente em ambiente real
6. **Commit** suas alterações: `git commit -m 'feat: adiciona nova funcionalidade'`
7. **Push** para sua branch: `git push origin feature/nova-funcionalidade`
8. Abra um **Pull Request**

### Diretrizes para Pull Requests:
- Descreva claramente o que a alteração faz
- Explique o problema que está resolvendo
- Inclua capturas de tela para alterações visuais
- Certifique-se de que o código foi testado em Ubuntu 22.04 e 24.04

## ⚖️ Informações Legais

### Licença
O projeto é licenciado sob a licença MIT. Veja o arquivo LICENSE para detalhes.

### Responsabilidade
O uso deste software é por conta e risco do usuário. Os desenvolvedores não são responsáveis por perdas de fundos ou outras consequências.
