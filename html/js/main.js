function atualizarStatus() {
  fetch('/cgi-bin/status.sh')
      .then(res => {
          if (!res.ok) {
              throw new Error('Erro ao obter status do sistema.');
          }
          return res.text(); // ✅ <- Aqui trocamos para texto simples
      })
      .then(text => {
          const lines = text.split('\n');
          for (const line of lines) {
              if (line.includes("CPU:")) {
                  const cpuElement = document.getElementById("cpu");
                  if (cpuElement) cpuElement.innerText = line;
              } else if (line.includes("RAM:")) {
                  const ramElement = document.getElementById("ram");
                  if (ramElement) ramElement.innerText = line;
              } else if (line.includes("LND:")) {
                  const lndElement = document.getElementById("lnd");
                  if (lndElement) lndElement.innerText = line;
              } else if (line.includes("Bitcoind:")) {
                  const bitcoindElement = document.getElementById("bitcoind");
                  if (bitcoindElement) bitcoindElement.innerText = line;
              } else if (line.includes("Tor:")) {
                  const torElement = document.getElementById("tor");
                  if (torElement) torElement.innerText = line;
              } else if (line.includes("Blockchain:")) {
                  const blockchainElement = document.getElementById("blockchain");
                  if (blockchainElement) blockchainElement.innerText = line;
              }
          }
      })
      .catch(error => {
          console.error("Erro ao atualizar status:", error.message);
          // Removido o alert para não incomodar o usuário
      });
}

  // Atualiza a cada 5 segundos quando 5000ms
  setInterval(atualizarStatus, 50000);
  window.onload = atualizarStatus;

// Base URL do BRLN-RPC-Server JavaScript (substituindo o Flask Python)
const flaskBaseURL = `http://${window.location.hostname}:5003`;

// Lista dos apps que aparecem no menu principal
const appsPrincipais = [
  { id: 'lndg-btn', porta: 8889 },
  { id: 'thunderhub-btn', porta: 3000 },
  { id: 'lnbits-btn', porta: 5000 },
  { id: 'peerswap-btn', porta: 1984 },
];

// Lista completa de serviços disponíveis no BRLN-OS
const servicosDisponiveis = [
  { name: 'brln-rpc-server', displayName: 'BRLN-RPC-Server', icon: '🚀', type: 'systemd' },
  { name: 'bitcoin', displayName: 'Bitcoin Core', icon: '🪙', type: 'docker' },
  { name: 'lnd', displayName: 'LND', icon: '⚡', type: 'docker' },
  { name: 'elements', displayName: 'Elements', icon: '💧', type: 'docker' },
  { name: 'tor', displayName: 'Tor', icon: '🧅', type: 'docker' },
  { name: 'lnbits', displayName: 'LNBits', icon: '💰', type: 'docker' },
  { name: 'thunderhub', displayName: 'ThunderHub', icon: '🌩️', type: 'docker' },
  { name: 'lndg', displayName: 'LNDg', icon: '📊', type: 'docker' },
  { name: 'peerswap', displayName: 'PeerSwap', icon: '💱', type: 'docker' },
  { name: 'psweb', displayName: 'PeerSwap Web', icon: '🌐', type: 'docker' },
  { name: 'grafana', displayName: 'Grafana', icon: '📈', type: 'docker' },
  // Futuro Electrum Server
  { name: 'electrum', displayName: 'Electrum Server', icon: '🔌', type: 'docker', available: false }
];

// Gerar lista de serviços dinamicamente (apenas os disponíveis)
const appsServicos = servicosDisponiveis
  .filter(service => service.available !== false)
  .map(service => service.name);

document.addEventListener('DOMContentLoaded', () => {
  // Aplica o tema salvo
  const temaSalvo = localStorage.getItem('temaAtual') || 'dark';
  document.body.classList.add(`${temaSalvo}-theme`);

  // Gera interface de serviços dinamicamente
  generateServiceControls();

  // Atualiza status dos botões
  updateButtons();

  // Atualiza saldos das carteiras
  updateWalletBalances();

  // Verifica status do servidor BRLN-RPC
  checkBRLNRPCServerStatus();

  // Verifica status dos serviços principais
  checkMainServicesStatus();

  // Verifica o status dos apps principais (de navegação)
  setTimeout(verificarServicosPrincipais, 50000);

  // Atualiza status dos botões de serviços a cada 30 segundos
  setInterval(updateButtons, 30000);

  // Atualiza saldos das carteiras a cada 5 minutos (300000ms)
  setInterval(updateWalletBalances, 300000);

  // Verifica status do servidor BRLN-RPC a cada 30 segundos
  setInterval(checkBRLNRPCServerStatus, 30000);

  // Verifica status dos serviços principais a cada 30 segundos
  setInterval(checkMainServicesStatus, 30000);
});

// Função para abrir apps principais
function abrirApp(porta) {
  const ip = window.location.hostname;
  window.open(`http://${ip}:${porta}`, '_blank');
}

// Gerar controles de serviços dinamicamente
function generateServiceControls() {
  const serviceGrid = document.getElementById('service-grid');
  if (!serviceGrid) return;

  // Limpar conteúdo existente
  serviceGrid.innerHTML = '';

  // Gerar um botão para cada serviço disponível
  servicosDisponiveis
    .filter(service => service.available !== false)
    .forEach(service => {
      const serviceRow = document.createElement('div');
      serviceRow.className = 'service-row';
      
      serviceRow.innerHTML = `
        <label for="${service.name}-button">
          ${service.icon} ${service.displayName}
          <span class="service-type">(${service.type})</span>
        </label>
        <label class="switch">
          <input type="checkbox" id="${service.name}-button" onchange="toggleService('${service.name}')">
          <span class="slider"></span>
        </label>
      `;
      
      serviceGrid.appendChild(serviceRow);
    });
}

// Verificar status dos serviços principais no painel de status
async function checkMainServicesStatus() {
  const mainServices = ['lnd', 'bitcoin', 'elements', 'tor'];
  
  for (const serviceName of mainServices) {
    const statusElement = document.getElementById(`${serviceName}-service-status`);
    if (!statusElement) continue;

    try {
      const response = await fetch(`${flaskBaseURL}/service-status?app=${serviceName}`);
      const data = await response.json();
      
      const service = servicosDisponiveis.find(s => s.name === serviceName);
      const icon = service ? service.icon : '🔧';
      const displayName = service ? service.displayName : serviceName;
      
      if (data.active) {
        statusElement.textContent = `${icon} ${displayName}: 🟢 Online`;
        statusElement.style.color = '#4CAF50';
      } else {
        statusElement.textContent = `${icon} ${displayName}: 🔴 Offline`;
        statusElement.style.color = '#f44336';
      }
    } catch (error) {
      const service = servicosDisponiveis.find(s => s.name === serviceName);
      const icon = service ? service.icon : '🔧';
      const displayName = service ? service.displayName : serviceName;
      
      statusElement.textContent = `${icon} ${displayName}: ❓ Erro de conexão`;
      statusElement.style.color = '#ff9800';
      console.warn(`❌ Erro ao verificar ${serviceName}:`, error);
    }
  }
}

function verificarServicosPrincipais() {
  const apps = [
    { id: 'lndg-btn', porta: 8889 },
    { id: 'thunderhub-btn', porta: 3000 },
    { id: 'lnbits-btn', porta: 5000 },
    { id: 'simple-btn', porta: 1984 },
  ];

  const ip = window.location.hostname;
  const timeout = 51000;

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
          setTimeout(checkService, 51000);
        });
    };

    checkService();
  });
}

// Atualiza status dos botões de serviços
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

async function toggleService(appName) {
  try {
    const response = await fetch(`${flaskBaseURL}/toggle-service?app=${appName}`, {
      method: 'POST'
    });
    const data = await response.json();
    if (data.success) {
      await updateButtons();
    } else {
      alert('Erro: ' + (data.error || 'Ação falhou'));
    }
  } catch (error) {
    console.error(error);
    alert('Erro ao enviar ação');
  }
}

// Formatar nome dos apps (função legacy, agora usa servicosDisponiveis)
function formatAppName(appName) {
  const service = servicosDisponiveis.find(s => s.name === appName);
  if (service) {
    return `${service.icon} ${service.displayName}`;
  }
  
  // Fallback para serviços não mapeados
  switch (appName) {
    case "bitcoind": return "🪙 Bitcoin Core";
    case "bos-telegram": return "📱 BOS Telegram";
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

// Verificar status do servidor BRLN-RPC
async function checkBRLNRPCServerStatus() {
  const statusElement = document.getElementById('brln-rpc-server');
  if (!statusElement) return;

  try {
    const response = await fetch(`${flaskBaseURL}/health`);
    const data = await response.json();
    
    if (data.status === 'ok') {
      statusElement.textContent = `🚀 BRLN-RPC-Server: 🟢 Online (v${data.version || '1.0.0'})`;
      statusElement.style.color = '#4CAF50';
    } else {
      throw new Error('Status não OK');
    }
  } catch (error) {
    statusElement.textContent = '🚀 BRLN-RPC-Server: 🔴 Offline';
    statusElement.style.color = '#f44336';
    console.warn('❌ Servidor BRLN-RPC não disponível:', error);
  }
}

// Atualizar saldos das carteiras usando nova API JavaScript
async function updateWalletBalances() {
  try {
    const response = await fetch(`${flaskBaseURL}/wallet-balances`);
    const data = await response.json();
    
    if (data.success) {
      // Atualizar Lightning balance
      const lightningElement = document.getElementById('lightning-balance');
      if (lightningElement) {
        const lightningBalance = data.lightning ? `${(data.lightning / 100000000).toFixed(8)} BTC` : 'Não disponível';
        lightningElement.textContent = `⚡ Lightning: ${lightningBalance}`;
      }
      
      // Atualizar Bitcoin balance
      const bitcoinElement = document.getElementById('bitcoin-balance');
      if (bitcoinElement) {
        const bitcoinBalance = data.bitcoin ? `${(data.bitcoin / 100000000).toFixed(8)} BTC` : 'Não disponível';
        bitcoinElement.textContent = `₿ Bitcoin On-Chain: ${bitcoinBalance}`;
      }
      
      // Atualizar Elements/Liquid balance - NOVO!
      const liquidElement = document.getElementById('liquid-balance');
      if (liquidElement) {
        const liquidBalance = data.elements ? `${parseFloat(data.elements).toFixed(8)} L-BTC` : 'Não disponível';
        liquidElement.textContent = `🌊 Liquid/Elements: ${liquidBalance}`;
      }

      // NOVO: Atualizar assets Liquid se disponível
      const assetsElement = document.getElementById('liquid-assets');
      if (assetsElement && data.liquid_assets) {
        const assetsCount = Array.isArray(data.liquid_assets) ? data.liquid_assets.length : 0;
        assetsElement.textContent = `💎 Liquid Assets: ${assetsCount} ativos`;
      }
      
      // Atualizar status indicators
      const lndStatusElement = document.getElementById('lnd-status');
      if (lndStatusElement) {
        const status = data.lnd_status === 'connected' ? '🟢 Conectado' : '🔴 Desconectado';
        lndStatusElement.textContent = `🔗 LND: ${status}`;
      }
      
      const elementsStatusElement = document.getElementById('elements-status');
      if (elementsStatusElement) {
        const status = data.elements_status === 'connected' ? '🟢 Conectado' : '🔴 Desconectado';
        elementsStatusElement.textContent = `🔗 Elements: ${status}`;
      }
      
      // Atualizar timestamp
      const walletStatusElement = document.getElementById('wallet-status');
      if (walletStatusElement) {
        const timestamp = new Date(data.timestamp).toLocaleString('pt-BR');
        walletStatusElement.textContent = `🔄 Última atualização: ${timestamp}`;
      }
      
      console.log('✅ Saldos atualizados com sucesso');
    } else {
      console.warn('⚠️ Erro ao obter saldos:', data.error || 'Erro desconhecido');
      
      // Mostrar erro nos elementos
      ['lightning-balance', 'bitcoin-balance', 'liquid-balance'].forEach(id => {
        const element = document.getElementById(id);
        if (element) {
          const type = id.includes('lightning') ? '⚡ Lightning' : 
                      id.includes('bitcoin') ? '₿ Bitcoin On-Chain' : 
                      '🌊 Liquid/Elements';
          element.textContent = `${type}: Erro na conexão`;
        }
      });
    }
  } catch (error) {
    console.error('❌ Erro ao atualizar saldos:', error);
    
    // Mostrar erro nos elementos se existirem
    ['lightning-balance', 'bitcoin-balance', 'liquid-balance'].forEach(id => {
      const element = document.getElementById(id);
      if (element) {
        const type = id.includes('lightning') ? '⚡ Lightning' : 
                    id.includes('bitcoin') ? '₿ Bitcoin On-Chain' : 
                    '🌊 Liquid/Elements';
        element.textContent = `${type}: Erro na conexão`;
      }
    });
    
    // Atualizar status de conexão
    const lndStatusElement = document.getElementById('lnd-status');
    if (lndStatusElement) {
      lndStatusElement.textContent = '🔗 LND: 🔴 Erro de conexão';
    }
    
    const elementsStatusElement = document.getElementById('elements-status');
    if (elementsStatusElement) {
      elementsStatusElement.textContent = '🔗 Elements: 🔴 Erro de conexão';
    }
  }
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

// ====================================================================
// NOVAS FUNÇÕES PARA LIGHTNING + ELEMENTS INTEGRATION
// ====================================================================

// Criar endereço Liquid/Elements
async function createLiquidAddress() {
  try {
    const response = await fetch(`${flaskBaseURL}/create-address`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        network: 'liquid',
        type: 'bech32'
      })
    });

    const data = await response.json();
    
    if (data.success) {
      const addressElement = document.getElementById('liquid-address');
      if (addressElement) {
        addressElement.value = data.address;
        addressElement.title = `Endereço criado: ${new Date().toLocaleString('pt-BR')}`;
      }
      console.log('✅ Endereço Liquid criado:', data.address);
    } else {
      console.error('❌ Erro ao criar endereço Liquid:', data.error);
      alert('Erro ao criar endereço: ' + data.error);
    }
  } catch (error) {
    console.error('❌ Erro na requisição:', error);
    alert('Erro de conexão ao criar endereço');
  }
}

// Enviar transação Liquid/Elements
async function sendLiquidTransaction() {
  const address = document.getElementById('liquid-send-address')?.value;
  const amount = document.getElementById('liquid-send-amount')?.value;
  
  if (!address || !amount) {
    alert('Por favor, preencha o endereço e valor');
    return;
  }

  try {
    const response = await fetch(`${flaskBaseURL}/send-transaction`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        network: 'liquid',
        address: address,
        amount: parseFloat(amount),
        asset: 'bitcoin' // L-BTC
      })
    });

    const data = await response.json();
    
    if (data.success) {
      alert(`✅ Transação enviada!\nTXID: ${data.txid}`);
      // Limpar campos
      document.getElementById('liquid-send-address').value = '';
      document.getElementById('liquid-send-amount').value = '';
      // Atualizar saldos
      updateWalletBalances();
    } else {
      alert('❌ Erro ao enviar transação: ' + data.error);
    }
  } catch (error) {
    console.error('❌ Erro na transação:', error);
    alert('Erro de conexão ao enviar transação');
  }
}

// Visualizar assets Liquid
async function showLiquidAssets() {
  try {
    const response = await fetch(`${flaskBaseURL}/liquid-assets`);
    const data = await response.json();
    
    if (data.success && data.assets) {
      const assetsContainer = document.getElementById('liquid-assets-list');
      if (!assetsContainer) return;

      assetsContainer.innerHTML = '';
      
      if (data.assets.length === 0) {
        assetsContainer.innerHTML = '<p>Nenhum asset encontrado</p>';
        return;
      }

      data.assets.forEach(asset => {
        const assetDiv = document.createElement('div');
        assetDiv.className = 'asset-item';
        assetDiv.innerHTML = `
          <strong>${asset.name || 'Asset Desconhecido'}</strong><br>
          <small>ID: ${asset.asset_id.substring(0, 16)}...</small><br>
          <span>Ticker: ${asset.ticker || 'N/A'}</span>
        `;
        assetsContainer.appendChild(assetDiv);
      });
    } else {
      console.error('❌ Erro ao obter assets:', data.error);
    }
  } catch (error) {
    console.error('❌ Erro na requisição de assets:', error);
  }
}

// Verificar conectividade Lightning + Elements
async function checkNetworkConnectivity() {
  try {
    const response = await fetch(`${flaskBaseURL}/network-info`);
    const data = await response.json();
    
    const connectivityStatus = document.getElementById('network-connectivity');
    if (!connectivityStatus) return;

    let statusHtml = '<h4>🔗 Status da Conectividade</h4>';
    
    // LND Status
    if (data.lnd) {
      const lndStatus = data.lnd.connected ? '🟢 Conectado' : '🔴 Desconectado';
      statusHtml += `<p>⚡ LND: ${lndStatus}`;
      if (data.lnd.connected && data.lnd.peers) {
        statusHtml += ` (${data.lnd.peers} peers)`;
      }
      statusHtml += '</p>';
    }

    // Elements Status
    if (data.elements) {
      const elementsStatus = data.elements.connected ? '🟢 Conectado' : '🔴 Desconectado';
      statusHtml += `<p>🌊 Elements: ${elementsStatus}`;
      if (data.elements.connected && data.elements.chain) {
        statusHtml += ` (${data.elements.chain})`;
      }
      statusHtml += '</p>';
    }

    connectivityStatus.innerHTML = statusHtml;
    
  } catch (error) {
    console.error('❌ Erro ao verificar conectividade:', error);
  }
}

// Auto-executar verificação de conectividade a cada 60 segundos
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    // Verificar conectividade na inicialização
    setTimeout(checkNetworkConnectivity, 2000);
    // E a cada 60 segundos
    setInterval(checkNetworkConnectivity, 60000);
  });
} else {
  // Se o DOM já carregou
  setTimeout(checkNetworkConnectivity, 2000);
  setInterval(checkNetworkConnectivity, 60000);
}

