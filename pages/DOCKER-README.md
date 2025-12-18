# 🐳 PAGCOIN.ORG - Deploy com Docker + Cloudflared

## 📋 O que foi criado

Este projeto agora pode ser executado em um container Docker que:

- ✅ Serve o site usando **Nginx**
- ✅ Expõe o site publicamente através do **Cloudflare Tunnel (cloudflared)**
- ✅ Não requer configuração de portas ou DNS
- ✅ Gera URL pública automaticamente

## 🚀 Como usar

### Pré-requisitos

- Docker instalado
- Docker Compose instalado (opcional, mas recomendado)

### ⚙️ Configuração do Token (IMPORTANTE)

O projeto já está configurado com um **túnel fixo** que mantém a mesma URL sempre!

**Arquivo `.env` já criado com seu token:**

```env
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiYjAzYWY0ZjRl...
```

✅ **Vantagens do túnel fixo:**

- URL sempre a mesma (não muda a cada reinício)
- Mais profissional para compartilhar
- Configurável no dashboard do Cloudflare

⚠️ **Se quiser usar túnel temporário**, remova ou comente a linha `CLOUDFLARE_TUNNEL_TOKEN` no arquivo `.env`

### Opção 1: Usando Docker Compose (Recomendado)

```bash
# Construir e iniciar o container
docker-compose up --build

# Ou em modo detached (background)
docker-compose up -d --build
```

### Opção 2: Usando Docker diretamente

```bash
# Construir a imagem
docker build -t pagcoin-web .

# Executar o container
docker run -p 8080:80 pagcoin-web
```

## 🌐 Acessando o site

### Com Túnel Fixo (Token configurado)

Seu site estará disponível na **URL configurada no seu dashboard do Cloudflare**.

Para ver a URL:

1. Acesse: https://one.dash.cloudflare.com/
2. Vá em "Zero Trust" → "Networks" → "Tunnels"
3. Encontre seu túnel e copie a URL pública

✅ **Esta URL é permanente e não muda!**

### Com Túnel Temporário (sem token)

Se não configurou o token, verá no terminal:

```
| Your quick Tunnel has been created! Visit it at:
| https://xxxxx-xxx-xxx-xxx.trycloudflare.com
```

⚠️ **Esta URL muda a cada reinício do container**

### Acesso Local (Opcional)

- O site também estará disponível em: `http://localhost:8080`

## 🛑 Parar o container

```bash
# Se usou docker-compose
docker-compose down

# Se usou docker run
docker stop <container-id>
```

## 📝 Comandos úteis

```bash
# Ver logs em tempo real
docker-compose logs -f

# Reconstruir após alterações
docker-compose up --build

# Parar e remover tudo
docker-compose down -v

# Ver containers rodando
docker ps

# Entrar no container
docker exec -it pagcoin-cloudflared /bin/bash
```

## 🔧 Personalização

### Alterar porta local

Edite o arquivo `docker-compose.yml`:

```yaml
ports:
  - "3000:80" # Mude 8080 para a porta desejada
```

### Desenvolvimento com hot-reload

Descomente as linhas de volumes no `docker-compose.yml` para refletir alterações sem rebuild:

```yaml
volumes:
  - ./pages:/usr/share/nginx/html/pages:ro
  - ./main.html:/usr/share/nginx/html/main.html:ro
```

## ⚙️ Cloudflare Tunnel Permanente (Opcional)

Para criar um túnel permanente com domínio customizado:

1. Instale cloudflared localmente
2. Faça login: `cloudflared tunnel login`
3. Crie um túnel: `cloudflared tunnel create pagcoin`
4. Configure seu domínio no dashboard do Cloudflare
5. Ajuste o `entrypoint.sh` para usar o túnel nomeado

Documentação: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/

## 📦 Estrutura de arquivos Docker

```
├── Dockerfile           # Definição da imagem Docker
├── docker-compose.yml   # Orquestração simplificada
├── nginx.conf          # Configuração do servidor web
├── entrypoint.sh       # Script de inicialização
├── .dockerignore       # Arquivos ignorados no build
└── DOCKER-README.md    # Esta documentação
```

## 🐛 Troubleshooting

**Container não inicia:**

```bash
docker-compose logs
```

**Túnel não cria URL pública:**

- Verifique sua conexão com a internet
- Aguarde alguns segundos (pode demorar)
- Veja os logs: `docker-compose logs -f`

**Erro de permissão no entrypoint.sh:**

```bash
chmod +x entrypoint.sh
docker-compose up --build
```

## 🌟 Vantagens desta solução

- ✅ **Portabilidade**: Roda em qualquer lugar com Docker
- ✅ **Zero configuração de rede**: Cloudflare cuida do túnel
- ✅ **Sem necessidade de IP público ou abrir portas**
- ✅ **HTTPS gratuito**: Cloudflare fornece SSL automaticamente
- ✅ **Fácil deploy**: Um comando para subir tudo

## 📚 Próximos passos

1. **Deploy em produção**:
   - Configure um túnel nomeado no Cloudflare
   - Use um domínio customizado
2. **CI/CD**:

   - Configure GitHub Actions para deploy automático
   - Use Docker Hub ou GitHub Container Registry

3. **Monitoramento**:
   - Adicione logs centralizados
   - Configure alertas de disponibilidade
