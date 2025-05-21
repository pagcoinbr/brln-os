# 🌐 Documentação da Interface Web - BR⚡LN Bolt

Este documento descreve a interface web do BR⚡LN Bolt, sua arquitetura e como personalizá-la.

## 📋 Visão Geral

A interface web do BR⚡LN Bolt é composta por:

1. **Painel Principal** (`index.html`)
   - Dashboard com links para todas as interfaces e ferramentas
   - Controles para iniciar/parar serviços
   - Indicadores de status dos serviços

2. **Terminal Web** (via Gotty)
   - Acesso CLI ao sistema via navegador
   - Editor de configurações
   - Visualização de logs

3. **API de Controle**
   - Backend em Python (control-systemd.py)
   - Gerencia os serviços systemd

## 🏗️ Arquitetura da Interface

```
html/
├── index.html          # Página de entrada
├── main.html           # Dashboard principal 
├── radio.html          # Interface para rádio (opcional)
├── cgi-bin/            # Scripts de backend CGI
│   ├── status.sh       # Verificação de status
│   └── ...
├── css/
│   ├── main.css        # Estilos do dashboard
│   └── ...
├── js/
│   ├── main.js         # Lógica do dashboard
│   └── ...
└── imagens/            # Recursos gráficos
```

## 🎨 Personalização

### Modificar o Dashboard

Para personalizar o dashboard principal:

1. Edite `html/main.html` para alterar a estrutura
2. Modifique `html/css/main.css` para ajustar estilos
3. Atualize `html/js/main.js` para comportamentos específicos

### Adicionar um Novo Serviço ao Dashboard

Para adicionar um novo serviço ao painel de controle:

1. **Adicione o botão em `main.html`**:
```html
<div class="app-card">
  <div class="app-description">
    <h3>Nome do Serviço</h3>
    <p>Descrição do serviço...</p>
  </div>
  <div class="app-links">
    <a href="http://<seu_ip>:<porta>" target="_blank">Acessar</a>
    <div class="toggle-container">
      <label class="toggle-switch">
        <input type="checkbox" id="novo-servico-button" data-app="novo-servico" data-action="start">
        <span class="slider round"></span>
      </label>
    </div>
  </div>
</div>
```

2. **Adicione o serviço à lista em `main.js`**:
```javascript
const appsServicos = [
  "bitcoind", 
  "lnd",
  // ... outros serviços
  "novo-servico"  // adicione seu novo serviço aqui
];
```

## 🔌 API de Controle de Serviços

A API permite iniciar, parar e verificar o status dos serviços.

### Endpoints:

- `GET /service-status?app=<nome_do_app>` - Verifica o status do serviço
- `POST /toggle-service` - Inicia ou para um serviço (parâmetros: `app`, `action`)

### Exemplo de Uso:

```javascript
// Verificar status
fetch(`${flaskBaseURL}/service-status?app=lnd`)
  .then(response => response.json())
  .then(data => console.log(data.active));

// Iniciar serviço
fetch(`${flaskBaseURL}/toggle-service`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ app: 'lnd', action: 'start' })
})
  .then(response => response.json())
  .then(data => console.log(data.message));
```

## 📱 Responsividade

A interface é responsiva e se adapta a diferentes tamanhos de tela. Os principais breakpoints são:

- **Desktop**: > 992px
- **Tablet**: 768px - 992px
- **Mobile**: < 768px

Para personalizar a responsividade, edite as media queries em `main.css`.

## 🔒 Considerações de Segurança

- A interface web deve ser acessada apenas pela LAN
- Para acesso remoto, use Tailscale ou Tor Hidden Services
- A API Flask suporta apenas requisições locais por padrão

## 🚀 Melhorias Futuras Planejadas

- Dashboard com gráficos de uso de recursos
- Tema escuro / claro alternável
- Suporte a internacionalização (i18n)
- Widgets personalizáveis
- Autenticação por senha para interface web
