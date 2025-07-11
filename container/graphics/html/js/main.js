// ===============================
// SISTEMA DE WEBSOCKETS EM TEMPO REAL
// ===============================

// Conexão WebSocket
let socket = null;
let connectionStatus = 'disconnected';
let reconnectAttempts = 0;
const maxReconnectAttempts = 5;

// Função para inicializar WebSocket
function initializeWebSocket() {
  const wsURL = `http://${window.location.hostname}:80`;
  
  try {
    // Carrega a biblioteca Socket.IO dinamicamente se não estiver disponível
    if (typeof io === 'undefined') {
      loadSocketIOLibrary().then(() => {
        connectWebSocket(wsURL);
      });
    } else {
      connectWebSocket(wsURL);
    }
  } catch (error) {
    console.error('Erro ao inicializar WebSocket:', error);
    // Fallback para polling se WebSocket falhar
    fallbackToPolling();
  }
}

function loadSocketIOLibrary() {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://cdn.socket.io/4.7.4/socket.io.min.js';
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

function connectWebSocket(wsURL) {
  try {
    socket = io(wsURL);
    
    socket.on('connect', () => {
      console.log('[WebSocket] Conectado ao servidor');
      connectionStatus = 'connected';
      reconnectAttempts = 0;
      updateConnectionIndicator(true);
      
      // Solicita status inicial
      socket.emit('request_status_update');
    });
    
    socket.on('disconnect', () => {
      console.log('[WebSocket] Desconectado do servidor');
      connectionStatus = 'disconnected';
      updateConnectionIndicator(false);
      
      // Tenta reconectar automaticamente
      if (reconnectAttempts < maxReconnectAttempts) {
        setTimeout(() => {
          reconnectAttempts++;
          console.log(`[WebSocket] Tentativa de reconexão ${reconnectAttempts}/${maxReconnectAttempts}`);
          socket.connect();
        }, 3000 * reconnectAttempts);
      } else {
        console.log('[WebSocket] Máximo de tentativas de reconexão atingido. Usando polling.');
        fallbackToPolling();
      }
    });
    
    // Eventos de status dos containers
    socket.on('container_status_update', (data) => {
      console.log('[WebSocket] Status dos containers atualizado:', data);
      updateContainerStatusUI(data);
    });
    
    // Eventos de status do sistema
    socket.on('system_status_update', (data) => {
      console.log('[WebSocket] Status do sistema atualizado:', data);
      updateSystemStatusUI(data);
    });
    
    // Eventos de saldos
    socket.on('balance_update', (data) => {
      console.log('[WebSocket] Saldos atualizados:', data);
      updateBalanceUI(data);
    });
    
    socket.on('connect_error', (error) => {
      console.error('[WebSocket] Erro de conexão:', error);
      updateConnectionIndicator(false);
    });
    
  } catch (error) {
    console.error('Erro ao conectar WebSocket:', error);
    fallbackToPolling();
  }
}

// Função para atualizar indicador de conexão
function updateConnectionIndicator(connected) {
  let indicator = document.getElementById('connection-indicator');
  
  if (!indicator) {
    // Cria indicador se não existir
    indicator = document.createElement('div');
    indicator.id = 'connection-indicator';
    indicator.style.cssText = `
      position: fixed;
      top: 10px;
      right: 10px;
      padding: 5px 10px;
      border-radius: 15px;
      font-size: 12px;
      font-weight: bold;
      z-index: 1000;
      transition: all 0.3s ease;
    `;
    document.body.appendChild(indicator);
  }
  
  if (connected) {
    indicator.textContent = '🟢 Tempo Real';
    indicator.style.backgroundColor = 'rgba(76, 175, 80, 0.9)';
    indicator.style.color = 'white';
  } else {
    indicator.textContent = '🔴 Desconectado';
    indicator.style.backgroundColor = 'rgba(244, 67, 54, 0.9)';
    indicator.style.color = 'white';
  }
}

// Fallback para polling se WebSocket falhar
function fallbackToPolling() {
  console.log('[Sistema] Usando sistema de polling como fallback');
  updateConnectionIndicator(false);
  
  // Atualiza status a cada 10 segundos (menos frequente que antes)
  setInterval(() => {
    updateButtons();
    atualizarStatus();
  }, 10000);
}

// Atualiza UI dos containers baseado nos dados do WebSocket
function updateContainerStatusUI(data) {
  Object.entries(data).forEach(([appName, info]) => {
    const button = document.getElementById(`${appName}-button`);
    if (button) {
      button.checked = info.running;
      button.dataset.action = info.running ? "stop" : "start";
    }
    
    // Atualiza status na seção de status do sistema
    const statusElement = document.getElementById(appName);
    if (statusElement && appName in info) {
      const status = info.running ? "Ativo" : "Inativo";
      statusElement.innerText = `${formatAppName(appName)}: ${status}`;
    }
  });
  
  // Atualiza grid de status detalhado se estiver visível
  const containerGrid = document.getElementById('containers-grid');
  if (containerGrid && containerGrid.children.length > 0) {
    updateDetailedContainerStatus(data);
  }
}

// Atualiza UI do sistema baseado nos dados do WebSocket
function updateSystemStatusUI(data) {
  Object.entries(data).forEach(([key, value]) => {
    const element = document.getElementById(key);
    if (element) {
      element.innerText = `${key.toUpperCase()}: ${value}`;
    }
  });
}

// Atualiza UI dos saldos baseado nos dados do WebSocket
function updateBalanceUI(data) {
  Object.entries(data).forEach(([type, balance]) => {
    const element = document.getElementById(`${type}-balance`);
    if (element) {
      element.textContent = balance || "N/A";
      element.className = "balance-value";
    }
  });
}

// Função para solicitar atualização manual via WebSocket
function requestManualUpdate(type = 'status') {
  if (socket && socket.connected) {
    if (type === 'balance') {
      socket.emit('request_balance_update', { type: 'all' });
    } else {
      socket.emit('request_status_update');
    }
  } else {
    // Fallback para HTTP se WebSocket não estiver disponível
    if (type === 'balance') {
      carregarTodosSaldos();
    } else {
      updateButtons();
    }
  }
}

function atualizarStatus() {
  // Se WebSocket estiver conectado, não faz polling HTTP
  if (socket && socket.connected) {
    return;
  }
  
  // Fallback para HTTP via Flask backend (não mais CGI)
  fetch(`${flaskBaseURL}/system-status`)
      .then(res => safeJsonResponse(res))
      .then(data => {
          // Atualiza elementos de status do sistema
          Object.entries(data).forEach(([key, value]) => {
              const element = document.getElementById(key.toLowerCase());
              if (element) {
                  element.innerText = `${key.toUpperCase()}: ${value}`;
              }
          });
      })
      .catch(error => {
          console.error("Erro ao atualizar status do sistema:", error);
      });
}

// Base URL do Flask - now served through nginx proxy
const flaskBaseURL = '/api';

// Helper function for safe JSON parsing
async function safeJsonResponse(response) {
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  
  const text = await response.text();
  
  // Check if response looks like HTML (common error page)
  if (text.trim().startsWith('<!DOCTYPE') || text.trim().startsWith('<html')) {
    throw new Error(`Server returned HTML instead of JSON. Possible server error.`);
  }
  
  try {
    return JSON.parse(text);
  } catch (jsonError) {
    throw new Error(`Invalid JSON response: ${text.substring(0, 200)}...`);
  }
}

// Lista dos apps que aparecem no menu principal
const appsPrincipais = [
  { id: 'lndg-btn', porta: 8889 },
  { id: 'thunderhub-btn', porta: 3000 },
  { id: 'lnbits-btn', porta: 5000 },
  { id: 'simple-btn', porta: 35671 },
  { id: 'peerswap-btn', porta: 1984 },
];

// Lista dos apps gerenciados no painel de serviços
const appsServicos = ["peerswap", "lnbits", "thunderhub", "simple", "lndg", "lndg-controller", "lnd", "bitcoind", "elementsd", "bos-telegram", "tor"];

document.addEventListener('DOMContentLoaded', () => {
  // Aplica o tema salvo
  const temaSalvo = localStorage.getItem('temaAtual') || 'dark';
  document.body.classList.add(`${temaSalvo}-theme`);

  // Inicializa WebSocket para monitoramento em tempo real
  initializeWebSocket();

  // Atualiza status dos botões inicialmente (fallback)
  setTimeout(() => {
    if (!socket || !socket.connected) {
      updateButtons();
      atualizarStatus();
    }
  }, 2000);

  // Verifica o status dos apps principais (de navegação)
  setTimeout(verificarServicosPrincipais, 1000);

  // Carrega saldos iniciais via WebSocket ou HTTP
  setTimeout(() => {
    if (socket && socket.connected) {
      socket.emit('request_balance_update', { type: 'all' });
    } else {
      carregarTodosSaldos();
    }
  }, 3000);
});

// Função para abrir apps principais
function abrirApp(porta) {
  const ip = window.location.hostname;
  window.open(`http://${ip}:${porta}`, '_blank');
}

function verificarServicosPrincipais() {
  const apps = [
    { id: 'lndg-btn', porta: 8889 },
    { id: 'thunderhub-btn', porta: 3000 },
    { id: 'lnbits-btn', porta: 5000 },
    { id: 'simple-btn', porta: 35671 },
    { id: 'peerswap-btn', porta: 1984 },
  ];

  const ip = window.location.hostname;
  const timeout = 2000;

  apps.forEach(app => {
    const botao = document.getElementById(app.id);
    if (botao) {
      botao.disabled = true;
      botao.style.opacity = "0.5";
      botao.style.cursor = "not-allowed";
      botao.title = "Seviço Desativado.";
    }

    const url = `http://${ip}:${app.porta}`;

    const checkService = () => {
      const fetchWithTimeout = new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject('Timeout'), timeout);
        fetch(url, { method: 'HEAD', mode: 'no-cors' })
          .then(response => {
            clearTimeout(timer);
            resolve(response);
          })
          .catch(reject);
      });

      fetchWithTimeout
        .then(() => {
          const botao = document.getElementById(app.id);
          if (botao) {
            botao.disabled = false;
            botao.style.opacity = "1";
            botao.style.cursor = "pointer";
            botao.title = "Serviço disponível";
          }
        })
        .catch(() => {
          setTimeout(checkService, 2000);
        });
    };

    checkService();
  });
}

// Atualiza status dos botões de serviços
async function updateButtons() {
  // Se WebSocket estiver conectado, não faz requisições HTTP desnecessárias
  if (socket && socket.connected) {
    return;
  }

  // Fallback HTTP quando WebSocket não está disponível
  // Remove a chamada para o CGI status.sh que não existe mais
  console.log("Atualizando status via Flask backend...");

  // Atualiza status dos serviços via HTTP
  for (const appName of appsServicos) {
    const button = document.getElementById(`${appName}-button`);
    if (!button) continue;
    try {
      const response = await fetch(`${flaskBaseURL}/service-status?app=${appName}`);
      const data = await safeJsonResponse(response);

      button.checked = data.active;
      button.dataset.action = data.active ? "stop" : "start";

    } catch (error) {
      console.error(`Erro ao verificar status de ${appName}:`, error);
    }
  }
}

async function toggleService(appName) {
  try {
    const response = await fetch(`${flaskBaseURL}/toggle-service?app=${appName}`, {
      method: 'POST'
    });
    
    const data = await safeJsonResponse(response);
    
    if (data.success) {
      // Se WebSocket não estiver conectado, atualiza manualmente
      if (!socket || !socket.connected) {
        await updateButtons();
      }
      // Se WebSocket estiver conectado, o update será automático via evento
    } else {
      alert('Erro: ' + (data.error || 'Ação falhou'));
    }
  } catch (error) {
    console.error(error);
    alert('Erro ao enviar ação: ' + error.message);
  }
}

// Formata o nome dos apps bonitinho
function formatAppName(appName) {
  switch (appName) {
    case "peerswap": return "PeerSwap";
    case "lnbits": return "LNbits";
    case "thunderhub": return "Thunderhub";
    case "simple": return "Simple LNWallet";
    case "lndg": return "LNDG";
    case "lndg-controller": return "LNDG Controller";
    case "lnd": return "LND";
    default: return appName;
  }
}

// Alternar tema claro/escuro
function alternarTema() {
  const body = document.body;
  const temaAtual = body.classList.contains('dark-theme') ? 'dark' : 'light';
  const novoTema = temaAtual === 'dark' ? 'light' : 'dark';

  body.classList.remove(`${temaAtual}-theme`);
  body.classList.add(`${novoTema}-theme`);

  localStorage.setItem('temaAtual', novoTema);
}

// Salvar última página aberta (opcional)
function salvarPagina(pagina) {
  localStorage.setItem('ultimaPaginaMainFrame', pagina);
}

function toggleExtras(button) {
  const extras = document.getElementById("extras");
  const isHidden = extras.style.display === "none";
  extras.style.display = isHidden ? "block" : "none";
  button.classList.toggle("rotate", isHidden);
}

// ===============================
// NOVAS FUNCIONALIDADES ADICIONADAS
// ===============================

// Função para atualizar saldos das carteiras (otimizada para WebSocket)
async function atualizarSaldo(tipo) {
  const elementId = `${tipo}-balance`;
  const element = document.getElementById(elementId);
  
  if (!element) return;
  
  element.textContent = "Carregando...";
  
  // Tenta usar WebSocket primeiro
  if (socket && socket.connected) {
    socket.emit('request_balance_update', { type: tipo });
    return;
  }
  
  // Fallback para HTTP
  try {
    const response = await fetch(`${flaskBaseURL}/saldo/${tipo}`);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const text = await response.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch (jsonError) {
      throw new Error(`Resposta inválida: ${text}`);
    }
    
    if (data.error) {
      element.textContent = `Erro: ${data.error}`;
      element.className = "balance-value status-error";
    } else {
      const key = `${tipo}_balance`;
      element.textContent = data[key] || "N/A";
      element.className = "balance-value";
    }
  } catch (error) {
    element.textContent = `Erro: ${error.message}`;
    element.className = "balance-value status-error";
    console.error(`Erro ao buscar saldo ${tipo}:`, error);
  }
}

// Função para carregar todos os saldos (otimizada)
function carregarTodosSaldos() {
  if (socket && socket.connected) {
    socket.emit('request_balance_update', { type: 'all' });
  } else {
    // Fallback HTTP
    atualizarSaldo('lightning');
    atualizarSaldo('onchain');
    atualizarSaldo('liquid');
  }
}

// Função para criar invoice Lightning
async function criarInvoice() {
  const amount = document.getElementById('invoice-amount').value;
  const resultElement = document.getElementById('invoice-result');
  
  if (!amount || amount <= 0) {
    resultElement.textContent = "Por favor, insira um valor válido";
    resultElement.className = "result-area status-error";
    return;
  }
  
  resultElement.textContent = "Criando invoice...";
  resultElement.className = "result-area";
  
  try {
    const response = await fetch(`${flaskBaseURL}/lightning/invoice`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ amount: parseInt(amount) })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const text = await response.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch (jsonError) {
      throw new Error(`Resposta inválida: ${text}`);
    }
    
    if (data.error) {
      resultElement.textContent = `Erro: ${data.error}`;
      resultElement.className = "result-area status-error";
    } else {
      resultElement.textContent = data.invoice;
      resultElement.className = "result-area";
      
      // Limpa o campo de valor
      document.getElementById('invoice-amount').value = '';
    }
  } catch (error) {
    resultElement.textContent = `Erro: ${error.message}`;
    resultElement.className = "result-area status-error";
  }
}

// Função para pagar invoice Lightning
async function pagarInvoice() {
  const invoice = document.getElementById('payment-invoice').value.trim();
  const resultElement = document.getElementById('payment-result');
  
  if (!invoice) {
    resultElement.textContent = "Por favor, cole um invoice válido";
    resultElement.className = "result-area status-error";
    return;
  }
  
  resultElement.textContent = "Processando pagamento...";
  resultElement.className = "result-area";
  
  try {
    const response = await fetch(`${flaskBaseURL}/lightning/pay`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ invoice: invoice })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const text = await response.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch (jsonError) {
      throw new Error(`Resposta inválida: ${text}`);
    }
    
    if (data.error) {
      resultElement.textContent = `Erro: ${data.error}`;
      resultElement.className = "result-area status-error";
    } else {
      resultElement.textContent = `Pagamento realizado: ${data.pagamento}`;
      resultElement.className = "result-area status-running";
      
      // Limpa o campo de invoice
      document.getElementById('payment-invoice').value = '';
      
      // Atualiza o saldo Lightning após o pagamento
      setTimeout(() => atualizarSaldo('lightning'), 2000);
    }
  } catch (error) {
    resultElement.textContent = `Erro: ${error.message}`;
    resultElement.className = "result-area status-error";
  }
}

// Função para visualizar logs dos containers
async function visualizarLogs() {
  const containerSelect = document.getElementById('container-select');
  const linesInput = document.getElementById('lines-input');
  const logsDisplay = document.getElementById('logs-display');
  
  const containerName = containerSelect.value;
  const lines = linesInput.value || 50;
  
  if (!containerName) {
    logsDisplay.textContent = "Por favor, selecione um container";
    return;
  }
  
  logsDisplay.textContent = "Carregando logs...";
  
  try {
    const response = await fetch(`${flaskBaseURL}/containers/logs/${containerName}?lines=${lines}`);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const text = await response.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch (jsonError) {
      throw new Error(`Resposta inválida: ${text}`);
    }
    
    if (data.success) {
      logsDisplay.textContent = data.logs || "Nenhum log encontrado";
    } else {
      logsDisplay.textContent = `Erro: ${data.error}`;
    }
  } catch (error) {
    logsDisplay.textContent = `Erro: ${error.message}`;
  }
}

// Função para atualizar status detalhado dos containers (otimizada)
async function atualizarStatusContainers() {
  const grid = document.getElementById('containers-grid');
  grid.innerHTML = '<div>Carregando status dos containers...</div>';
  
  // Tenta usar WebSocket primeiro
  if (socket && socket.connected) {
    socket.emit('request_status_update');
    
    // Aguarda um pouco para receber os dados via WebSocket
    setTimeout(() => {
      if (grid.innerHTML.includes('Carregando')) {
        // Se ainda está carregando, usa HTTP como fallback
        loadContainerStatusHTTP();
      }
    }, 2000);
    return;
  }
  
  // Fallback para HTTP
  loadContainerStatusHTTP();
}

async function loadContainerStatusHTTP() {
  const grid = document.getElementById('containers-grid');
  
  try {
    const response = await fetch(`${flaskBaseURL}/containers/status`);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const text = await response.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch (jsonError) {
      throw new Error(`Resposta inválida: ${text}`);
    }
    
    updateDetailedContainerStatus(data);
  } catch (error) {
    grid.innerHTML = `<div>Erro: ${error.message}</div>`;
  }
}

function updateDetailedContainerStatus(data) {
  const grid = document.getElementById('containers-grid');
  grid.innerHTML = '';
  
  Object.entries(data).forEach(([appName, info]) => {
    const card = document.createElement('div');
    card.className = 'container-card';
    
    const statusClass = info.running ? 'status-running' : 'status-stopped';
    const statusText = info.running ? '🟢 Rodando' : '🔴 Parado';
    
    card.innerHTML = `
      <div class="container-name">${formatAppName(appName)}</div>
      <div class="container-status-text ${statusClass}">${statusText}</div>
      <div style="font-size: 12px; color: #888;">Status: ${info.status}</div>
      <div style="font-size: 12px; color: #888;">Container: ${info.container}</div>
    `;
    
    grid.appendChild(card);
  });
}

// Função para toggle da seção de logs
function toggleLogs(button) {
  const logsSection = document.getElementById("logs-section");
  const isHidden = logsSection.style.display === "none";
  logsSection.style.display = isHidden ? "block" : "none";
  button.classList.toggle("rotate", isHidden);
}

// Função para toggle da seção de status dos containers
function toggleContainerStatus(button) {
  const statusSection = document.getElementById("container-status-section");
  const isHidden = statusSection.style.display === "none";
  statusSection.style.display = isHidden ? "block" : "none";
  button.classList.toggle("rotate", isHidden);
  
  // Carrega os dados quando abrir pela primeira vez
  if (isHidden) {
    atualizarStatusContainers();
  }
}

// Modificar a função DOMContentLoaded para incluir as novas funcionalidades
document.addEventListener('DOMContentLoaded', () => {
  // Aplica o tema salvo
  const temaSalvo = localStorage.getItem('temaAtual') || 'dark';
  document.body.classList.add(`${temaSalvo}-theme`);

  // Atualiza status dos botões
  updateButtons();

  // Verifica o status dos apps principais (de navegação)
  setTimeout(verificarServicosPrincipais, 1000);

  // Atualiza status dos botões de serviços a cada 5 segundos
  setInterval(updateButtons, 5000);
  
  // Carrega saldos iniciais
  setTimeout(carregarTodosSaldos, 2000);
  
  // Atualiza saldos a cada 30 segundos
  setInterval(carregarTodosSaldos, 30000);
});
