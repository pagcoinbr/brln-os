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


#### ⚡ ThunderHub
- **Senha Master**: `4664211779`
- **Usuário da Conta**: `BRLNBolt`
- **URL de Acesso**: http://localhost:3000
- **Arquivo de Configuração**: `/data/thunderhub/config/thubConfig_runtime.yaml`
- **Como Alterar**: Defina a variável `THUB_PASSWORD` no docker-compose.yml ou edite o arquivo de configuração
- **Documentação**: [ThunderHub Documentation](https://thunderhub.io/)


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

