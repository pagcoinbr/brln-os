#!/bin/bash

# Script para extrair senhas dos logs do Docker Compose
# Salva todas as senhas encontradas em um arquivo passwords.md

set -e

# Configurações
COMPOSE_FILE="/home/admin/brlnfullauto/container/docker-compose.yml"
COMPOSE_DIR="/home/admin/brlnfullauto/container"
OUTPUT_FILE="/home/admin/brlnfullauto/passwords.md"
OUTPUT_TXT_FILE="/home/admin/brlnfullauto/passwords.txt"
LOG_FILE="/tmp/docker-compose-logs.txt"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Função para logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Função para extrair logs
extract_logs() {
    log "Extraindo logs do Docker Compose..."
    
    cd "$COMPOSE_DIR"
    
    # Capturar logs de todos os serviços
    if command -v docker-compose &> /dev/null; then
        docker-compose logs --no-color > "$LOG_FILE" 2>&1
    else
        docker compose logs --no-color > "$LOG_FILE" 2>&1
    fi
    
    log "Logs extraídos para: $LOG_FILE"
}

# Função para gerar o arquivo de senhas
generate_passwords_file() {
    log "Gerando arquivo de senhas..."
    
    # Criar arquivo de saída
    cat > "$OUTPUT_FILE" << 'EOF'
# 🔐 Senhas e Credenciais do BRLN Full Auto

Este arquivo contém todas as senhas e credenciais extraídas dos logs durante a instalação.

**⚠️ IMPORTANTE: Mantenha este arquivo seguro e faça backup em local protegido!**

---

## 📋 Resumo das Senhas

### 🔑 Senhas Padrão (Definidas nos Arquivos de Configuração)

#### 🌩️ LND (Lightning Network Daemon)
- **Senha da Carteira**: `lndpassword123`
- **Arquivo de Configuração**: `/home/admin/brlnfullauto/container/lnd/password.txt`
- **Como Alterar**: Edite o arquivo `password.txt` antes de executar o setup
- **Documentação**: [LND Documentation](https://docs.lightning.engineering/)

#### ⚡ Elements (Liquid Network)
- **RPC User**: `elementsuser`
- **RPC Password**: `elementspassword123`
- **Arquivo de Configuração**: `/home/admin/brlnfullauto/container/elements/elements.conf.example`
- **Como Alterar**: Edite o arquivo `elements.conf` antes de executar o setup
- **Documentação**: [Elements Documentation](https://elementsproject.org/)

#### 🔄 PeerSwap
- **Elements RPC User**: `elementsuser`
- **Elements RPC Password**: `elementspassword123`
- **Arquivo de Configuração**: `/home/admin/brlnfullauto/container/peerswap/peerswap.conf.example`
- **Como Alterar**: Edite o arquivo `peerswap.conf` antes de executar o setup
- **Documentação**: [PeerSwap Documentation](https://github.com/ElementsProject/peerswap)

#### 🐘 PostgreSQL
- **Usuário**: `postgres`
- **Senha**: `postgres`
- **Banco de Dados**: `postgres`
- **Arquivo de Configuração**: `/home/admin/brlnfullauto/container/docker-compose.yml`
- **Como Alterar**: Edite as variáveis de ambiente no docker-compose.yml
- **Documentação**: [PostgreSQL Documentation](https://www.postgresql.org/docs/)

#### 📊 Grafana
- **Usuário Admin**: `admin`
- **Senha Admin**: `admin`
- **Arquivo de Configuração**: `/home/admin/brlnfullauto/container/docker-compose.yml`
- **Como Alterar**: Edite a variável `GF_SECURITY_ADMIN_PASSWORD` no docker-compose.yml
- **Documentação**: [Grafana Documentation](https://grafana.com/docs/)

### 🎲 Senhas Geradas Automaticamente

EOF

    # Extrair senhas geradas automaticamente dos logs
    info "Procurando senhas geradas automaticamente nos logs..."
    
    # ThunderHub
    if grep -q "Senha gerada automaticamente" "$LOG_FILE"; then
        THUB_PASSWORD=$(grep "Senha gerada automaticamente" "$LOG_FILE" | tail -1 | sed 's/.*: //' | sed 's/\x1b\[[0-9;]*m//g')
        cat >> "$OUTPUT_FILE" << EOF

#### ⚡ ThunderHub
- **Senha Master**: \`$THUB_PASSWORD\`
- **Usuário da Conta**: \`BRLNBolt\`
- **URL de Acesso**: http://localhost:3000
- **Arquivo de Configuração**: \`/data/thunderhub/config/thubConfig_runtime.yaml\`
- **Como Alterar**: Defina a variável \`THUB_PASSWORD\` no docker-compose.yml ou edite o arquivo de configuração
- **Documentação**: [ThunderHub Documentation](https://thunderhub.io/)

EOF
    fi
    
    # LNDG (procurar por senha de admin)
    if grep -q "lndg-admin" "$LOG_FILE"; then
        cat >> "$OUTPUT_FILE" << EOF

#### 📊 LNDG (Lightning Network Dashboard)
- **Usuário**: \`lndg-admin\`
- **Senha**: Execute o comando abaixo para obter a senha:
\`\`\`bash
docker exec lndg cat /app/data/lndg-admin.txt
\`\`\`
- **URL de Acesso**: http://localhost:8889
- **Como Alterar**: Consulte a documentação oficial do LNDG
- **Documentação**: [LNDG Documentation](https://github.com/cryptosharks131/lndg)

EOF
    fi
    
    # LNBits (procurar por chaves de API)
    if grep -q "LNBITS_SECRET_KEY" "$LOG_FILE"; then
        cat >> "$OUTPUT_FILE" << EOF

#### 💰 LNBits
- **URL de Acesso**: http://localhost:5000
- **Chave Secreta**: \`your-secret-key-here\` (padrão - ALTERE IMEDIATAMENTE!)
- **Arquivo de Configuração**: \`/home/admin/brlnfullauto/container/docker-compose.yml\`
- **Como Alterar**: Edite a variável \`LNBITS_SECRET_KEY\` no docker-compose.yml
- **Documentação**: [LNBits Documentation](https://docs.lnbits.org/)

EOF
    fi
    
    # Procurar por seeds/mnemonics nos logs
    if grep -iE "(seed|mnemonic|cipher seed|recovery)" "$LOG_FILE" | grep -v "cipher seed passphrase" | grep -q "word"; then
        cat >> "$OUTPUT_FILE" << EOF

### 🌱 Seeds e Frases de Recuperação

**⚠️ CRÍTICO: Estas seeds são essenciais para recuperar suas carteiras!**

EOF
        
        # Extrair seeds do LND
        if grep -q "lnd successfully initialized" "$LOG_FILE"; then
            cat >> "$OUTPUT_FILE" << EOF

#### 🌩️ LND Wallet Seed
**Esta seed foi gerada durante a criação da carteira LND. Salve-a em local seguro!**

EOF
            
            # Tentar extrair a seed dos logs (pode não estar presente se já foi criada)
            if grep -A 30 -B 5 "cipher seed" "$LOG_FILE" | grep -E "^[0-9]+\." > /dev/null; then
                echo "```" >> "$OUTPUT_FILE"
                grep -A 30 -B 5 "cipher seed" "$LOG_FILE" | grep -E "^[0-9]+\." >> "$OUTPUT_FILE"
                echo "```" >> "$OUTPUT_FILE"
            else
                cat >> "$OUTPUT_FILE" << EOF
**Seed não encontrada nos logs.** Isso pode ocorrer se:
- A carteira já foi criada anteriormente
- Os logs foram limpos
- A seed foi exibida em uma sessão anterior

Para recuperar a seed, você precisará:
1. Parar o container LND
2. Remover a carteira existente
3. Recriar a carteira manualmente

EOF
            fi
        fi
    fi
    
    # Adicionar seção de segurança e comandos úteis
    cat >> "$OUTPUT_FILE" << 'EOF'

---

## 🔒 Segurança e Boas Práticas

### 📋 Checklist de Segurança

- [ ] **Alterar todas as senhas padrão** antes de usar em produção
- [ ] **Fazer backup da seed do LND** em local seguro offline
- [ ] **Configurar firewall** para permitir apenas portas necessárias
- [ ] **Habilitar 2FA** onde disponível
- [ ] **Fazer backup regular** dos dados importantes
- [ ] **Monitorar logs** regularmente para atividades suspeitas

### 🛡️ Como Alterar Senhas

#### 1. Antes da Instalação
Edite os arquivos de configuração apropriados antes de executar o `setup.sh`:

```bash
# Editar senha do LND
echo "nova_senha_segura" > /home/admin/brlnfullauto/container/lnd/password.txt

# Editar configuração do Elements
nano /home/admin/brlnfullauto/container/elements/elements.conf

# Editar configuração do PeerSwap
nano /home/admin/brlnfullauto/container/peerswap/peerswap.conf

# Editar docker-compose.yml para outras senhas
nano /home/admin/brlnfullauto/container/docker-compose.yml
```

#### 2. Após a Instalação
Para alterar senhas após a instalação, você precisará:

1. **Parar os serviços**:
```bash
cd /home/admin/brlnfullauto/container
docker-compose down
```

2. **Alterar as configurações**

3. **Recriar os containers**:
```bash
docker-compose up -d --force-recreate
```

### 📱 Comandos Úteis

#### Ver Logs de um Serviço Específico
```bash
cd /home/admin/brlnfullauto/container
docker-compose logs -f [nome_do_serviço]
```

#### Verificar Status dos Serviços
```bash
cd /home/admin/brlnfullauto/container
docker-compose ps
```

#### Acessar Shell de um Container
```bash
docker exec -it [nome_do_container] /bin/bash
# ou
docker exec -it [nome_do_container] /bin/sh
```

#### Backup de Emergência
```bash
# Backup completo dos dados
sudo tar -czf backup-brln-$(date +%Y%m%d).tar.gz /data/

# Backup apenas das configurações
tar -czf backup-config-$(date +%Y%m%d).tar.gz /home/admin/brlnfullauto/container/
```

---

## 📞 Suporte e Documentação

### 🌐 URLs de Acesso aos Serviços

- **Grafana**: http://localhost:3010
- **ThunderHub**: http://localhost:3000
- **LNBits**: http://localhost:5000
- **LNDG**: http://localhost:8889
- **PeerSwap Web**: http://localhost:1984

### 📚 Documentação Oficial

- [Bitcoin Core](https://bitcoin.org/en/bitcoin-core/)
- [LND](https://docs.lightning.engineering/)
- [Elements](https://elementsproject.org/)
- [ThunderHub](https://thunderhub.io/)
- [LNBits](https://docs.lnbits.org/)
- [LNDG](https://github.com/cryptosharks131/lndg)
- [PeerSwap](https://github.com/ElementsProject/peerswap)

### 🆘 Em Caso de Problemas

1. **Verifique os logs** dos serviços
2. **Consulte a documentação** oficial
3. **Procure por issues** nos repositórios do GitHub
4. **Faça backup** antes de fazer alterações

---

**📅 Gerado em**: $(date '+%Y-%m-%d %H:%M:%S')
**🖥️ Sistema**: $(uname -a)
**🐳 Docker**: $(docker --version)

---

**⚠️ LEMBRETE IMPORTANTE**: Este arquivo contém informações sensíveis. Mantenha-o seguro e não o compartilhe publicamente!

EOF
    
    log "Arquivo de senhas gerado: $OUTPUT_FILE"
    
    # Gerar arquivo TXT simplificado
    generate_simple_txt_file
}

# Função para exibir resumo
show_summary() {
    info "=== RESUMO DA EXTRAÇÃO DE SENHAS ==="
    echo ""
    info "📁 Arquivos gerados:"
    echo "  📄 Arquivo completo (Markdown): $OUTPUT_FILE"
    echo "  📄 Arquivo simplificado (TXT): $OUTPUT_TXT_FILE"
    echo ""
    info "🔑 Senhas encontradas:"
    
    # Contar senhas encontradas
    local count=0
    
    if grep -q "lndpassword123" "$OUTPUT_FILE"; then
        echo "  ✓ LND Wallet Password"
        ((count++))
    fi
    
    if grep -q "elementspassword123" "$OUTPUT_FILE"; then
        echo "  ✓ Elements RPC Password"
        ((count++))
    fi
    
    if grep -q "postgres" "$OUTPUT_FILE"; then
        echo "  ✓ PostgreSQL Password"
        ((count++))
    fi
    
    if grep -q "admin" "$OUTPUT_FILE"; then
        echo "  ✓ Grafana Admin Password"
        ((count++))
    fi
    
    if grep -q "Senha gerada automaticamente" "$LOG_FILE"; then
        echo "  ✓ ThunderHub Password (gerada automaticamente)"
        ((count++))
    fi
    
    echo ""
    info "📊 Total de credenciais documentadas: $count"
    echo ""
    warning "🔒 IMPORTANTE: Leia os arquivos gerados e altere as senhas padrão!"
    echo ""
    info "📖 Para visualizar os arquivos:"
    echo "  cat $OUTPUT_FILE"
    echo "  cat $OUTPUT_TXT_FILE"
    echo ""
    info "📝 Para editar os arquivos:"
    echo "  nano $OUTPUT_FILE"
    echo "  nano $OUTPUT_TXT_FILE"
    echo ""
}

# Função para exibir conteúdo formatado para terminal
display_passwords() {
    echo "=== ARQUIVO MARKDOWN COMPLETO ==="
    if [[ -f "$OUTPUT_FILE" ]]; then
        cat "$OUTPUT_FILE"
    else
        echo "❌ Arquivo de senhas não encontrado: $OUTPUT_FILE"
    fi
    
    echo ""
    echo "=== ARQUIVO TXT SIMPLIFICADO ==="
    if [[ -f "$OUTPUT_TXT_FILE" ]]; then
        cat "$OUTPUT_TXT_FILE"
    else
        echo "❌ Arquivo de senhas TXT não encontrado: $OUTPUT_TXT_FILE"
    fi
}

# Função para gerar arquivo TXT simplificado
generate_simple_txt_file() {
    log "Gerando arquivo TXT simplificado..."
    
    # Criar arquivo TXT de saída
    cat > "$OUTPUT_TXT_FILE" << EOF
=== BRLN Full Auto - Senhas e Credenciais ===
Gerado em: $(date '+%Y-%m-%d %H:%M:%S')

IMPORTANTE: Mantenha este arquivo seguro e faça backup!

=== SENHAS PADRAO ===

LND (Lightning Network):
- Senha da Carteira: lndpassword123
- Arquivo: /home/admin/brlnfullauto/container/lnd/password.txt

Elements (Liquid Network):
- RPC User: elementsuser
- RPC Password: elementspassword123
- Arquivo: /home/admin/brlnfullauto/container/elements/elements.conf

PeerSwap:
- Elements RPC User: elementsuser
- Elements RPC Password: elementspassword123
- Arquivo: /home/admin/brlnfullauto/container/peerswap/peerswap.conf

PostgreSQL:
- Usuario: postgres
- Senha: postgres
- Banco: postgres

Grafana:
- Usuario Admin: admin
- Senha Admin: admin

=== SENHAS GERADAS AUTOMATICAMENTE ===

EOF

    # Extrair ThunderHub password
    if grep -q "Senha gerada automaticamente" "$LOG_FILE"; then
        THUB_PASSWORD=$(grep "Senha gerada automaticamente" "$LOG_FILE" | tail -1 | sed 's/.*: //' | sed 's/\x1b\[[0-9;]*m//g')
        cat >> "$OUTPUT_TXT_FILE" << EOF
ThunderHub:
- Senha Master: $THUB_PASSWORD
- Usuario da Conta: BRLNBolt
- URL: http://localhost:3000

EOF
    fi
    
    # LNDG
    if grep -q "lndg-admin" "$LOG_FILE"; then
        cat >> "$OUTPUT_TXT_FILE" << EOF
LNDG (Lightning Network Dashboard):
- Usuario: lndg-admin
- Senha: Execute 'docker exec lndg cat /app/data/lndg-admin.txt'
- URL: http://localhost:8889

EOF
    fi
    
    # LNBits
    if grep -q "LNBITS_SECRET_KEY" "$LOG_FILE"; then
        cat >> "$OUTPUT_TXT_FILE" << EOF
LNBits:
- URL: http://localhost:5000
- Chave Secreta: your-secret-key-here (ALTERE IMEDIATAMENTE!)

EOF
    fi
    
    # Verificar se há seeds nos logs
    if grep -iE "(seed|mnemonic|cipher seed|recovery)" "$LOG_FILE" | grep -v "cipher seed passphrase" | grep -q "word"; then
        cat >> "$OUTPUT_TXT_FILE" << EOF

=== SEEDS E FRASES DE RECUPERACAO ===

CRITICO: Estas seeds sao essenciais para recuperar suas carteiras!

EOF
        
        # Extrair seeds do LND
        if grep -q "lnd successfully initialized" "$LOG_FILE"; then
            cat >> "$OUTPUT_TXT_FILE" << EOF
LND Wallet Seed:
Esta seed foi gerada durante a criacao da carteira LND. Salve em local seguro!

EOF
            
            # Tentar extrair a seed dos logs
            if grep -A 30 -B 5 "cipher seed" "$LOG_FILE" | grep -E "^[0-9]+\." > /dev/null; then
                echo "Seed LND:" >> "$OUTPUT_TXT_FILE"
                grep -A 30 -B 5 "cipher seed" "$LOG_FILE" | grep -E "^[0-9]+\." | sed 's/\x1b\[[0-9;]*m//g' >> "$OUTPUT_TXT_FILE"
                echo "" >> "$OUTPUT_TXT_FILE"
            else
                cat >> "$OUTPUT_TXT_FILE" << EOF
Seed nao encontrada nos logs. Isso pode ocorrer se:
- A carteira ja foi criada anteriormente
- Os logs foram limpos
- A seed foi exibida em uma sessao anterior

EOF
            fi
        fi
    fi
    
    # Adicionar URLs de acesso
    cat >> "$OUTPUT_TXT_FILE" << EOF

=== URLS DE ACESSO ===

- Grafana: http://localhost:3010
- ThunderHub: http://localhost:3000
- LNBits: http://localhost:5000
- LNDG: http://localhost:8889
- PeerSwap Web: http://localhost:1984

=== COMANDOS UTEIS ===

Ver logs de um servico:
cd /home/admin/brlnfullauto/container && docker-compose logs -f [nome_do_servico]

Verificar status dos servicos:
cd /home/admin/brlnfullauto/container && docker-compose ps

Acessar shell de um container:
docker exec -it [nome_do_container] /bin/bash

Backup de emergencia:
sudo tar -czf backup-brln-$(date +%Y%m%d).tar.gz /data/

=== LEMBRETE IMPORTANTE ===

Este arquivo contem informacoes sensiveis. Mantenha seguro e nao compartilhe!

EOF
    
    log "Arquivo TXT simplificado gerado: $OUTPUT_TXT_FILE"
}

# Função principal
main() {
    # Verificar se foi chamado com parâmetro --display-only
    if [[ "$1" == "--display-only" ]]; then
        display_passwords
        exit 0
    fi
    
    log "=== BRLN Full Auto - Extração de Senhas ==="
    echo ""
    
    # Verificar se o diretório do docker-compose existe
    if [[ ! -d "$COMPOSE_DIR" ]]; then
        error "Diretório não encontrado: $COMPOSE_DIR"
        exit 1
    fi
    
    # Verificar se o docker-compose.yml existe
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        error "Arquivo não encontrado: $COMPOSE_FILE"
        exit 1
    fi
    
    # Extrair logs
    extract_logs
    
    # Gerar arquivo de senhas
    generate_passwords_file
    
    # Exibir resumo
    show_summary
    
    log "✅ Processo concluído com sucesso!"
}

# Executar função principal
main "$@"
