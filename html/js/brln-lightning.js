// ====================================================================
// BRLN-OS Lightning + Elements Frontend Integration
// Integração com os arquivos JS existentes do html/js/
// ====================================================================

class BRLNLightningAPI {
  constructor(baseURL = null) {
    this.baseURL = baseURL || `http://${window.location.hostname}:5010/api`;
    this.cache = new Map();
    this.cacheTimeout = 5000; // 5 segundos
  }

  // Método auxiliar para fazer requisições
  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    
    try {
      const response = await fetch(url, {
        headers: {
          'Content-Type': 'application/json',
          ...options.headers
        },
        ...options
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error(`Erro na requisição ${endpoint}:`, error);
      throw error;
    }
  }

  // Cache simples para evitar requests desnecessários
  async cachedRequest(key, requestFn, timeout = this.cacheTimeout) {
    const cached = this.cache.get(key);
    const now = Date.now();

    if (cached && (now - cached.timestamp) < timeout) {
      return cached.data;
    }

    const data = await requestFn();
    this.cache.set(key, {data, timestamp: now});
    return data;
  }

  // === STATUS E INFORMAÇÕES ===

  async getStatus() {
    return this.cachedRequest('status', () => this.request('/status'));
  }

  async getBalances() {
    return this.cachedRequest('balances', () => this.request('/balances'), 3000);
  }

  async getNodeInfo() {
    return this.cachedRequest('nodeInfo', () => this.request('/node/info'));
  }

  async getHealth() {
    return this.request('/health');
  }

  // === LIQUID NETWORK ===

  async getLiquidAssets() {
    return this.cachedRequest('liquidAssets', () => this.request('/liquid/assets'));
  }

  async createLiquidAddress(label = '', format = 'bech32') {
    return this.request('/liquid/address', {
      method: 'POST',
      body: JSON.stringify({label, format})
    });
  }

  async sendLiquid(address, amount, description = '') {
    return this.request('/liquid/send', {
      method: 'POST',
      body: JSON.stringify({address, amount, description})
    });
  }

  async getLiquidTransactions() {
    return this.request('/liquid/transactions');
  }

  // === BITCOIN NETWORK (via LND) ===

  async createBitcoinAddress(format = 'p2wpkh') {
    return this.request('/bitcoin/address', {
      method: 'POST',
      body: JSON.stringify({format})
    });
  }

  async sendBitcoin(address, amount, feeRate = 1) {
    return this.request('/bitcoin/send', {
      method: 'POST',
      body: JSON.stringify({
        address, 
        amount, 
        fee_rate: feeRate
      })
    });
  }

  // === LIGHTNING NETWORK ===

  async createInvoice(amount, description = '', expiry = 3600) {
    return this.request('/lightning/invoice', {
      method: 'POST',
      body: JSON.stringify({amount, description, expiry})
    });
  }

  async payInvoice(paymentRequest, maxFee = 100) {
    return this.request('/lightning/pay', {
      method: 'POST',
      body: JSON.stringify({
        payment_request: paymentRequest,
        max_fee: maxFee
      })
    });
  }

  // === UTILITÁRIOS PARA UI ===

  // Formatar valores em satoshis para BTC
  formatBTC(satoshis) {
    return (satoshis / 100000000).toFixed(8);
  }

  // Formatar valores para display
  formatSatoshis(satoshis) {
    return new Intl.NumberFormat('pt-BR').format(satoshis);
  }

  // Converter BTC para satoshis
  btcToSatoshis(btc) {
    return Math.round(btc * 100000000);
  }

  // Verificar se valor é válido
  isValidAmount(amount) {
    return !isNaN(amount) && amount > 0;
  }

  // Validar endereço Bitcoin/Liquid básico
  isValidAddress(address) {
    return address && address.length > 10 && /^[a-zA-Z0-9]+$/.test(address);
  }
}

// === INTEGRAÇÃO COM UI EXISTENTE ===

// Instância global da API
window.BRLN = new BRLNLightningAPI();

// Função para atualizar status na UI existente (compatível com main.js)
async function atualizarStatusBRLN() {
  try {
    const status = await window.BRLN.getStatus();
    const balances = await window.BRLN.getBalances();

    // Atualizar elementos existentes
    const elementsStatus = document.getElementById('elements');
    if (elementsStatus) {
      elementsStatus.innerText = status.elements.connected ? 
        `Elements: ✅ ${status.elements.info?.chain || 'Conectado'}` :
        'Elements: ❌ Desconectado';
    }

    // Criar novos elementos se não existirem
    updateOrCreateStatusElement('liquid-balance', 
      `L-BTC: ${balances.liquid?.lbtc || 'N/A'}`);
    
    updateOrCreateStatusElement('bitcoin-balance', 
      `BTC: ${window.BRLN.formatBTC(balances.bitcoin?.confirmed || 0)}`);
    
    updateOrCreateStatusElement('lightning-balance', 
      `Lightning: ${window.BRLN.formatSatoshis(balances.lightning?.local || 0)} sats`);

  } catch (error) {
    console.error('Erro ao atualizar status BRLN:', error);
  }
}

// Função auxiliar para criar/atualizar elementos de status
function updateOrCreateStatusElement(id, text) {
  let element = document.getElementById(id);
  if (!element) {
    element = document.createElement('div');
    element.id = id;
    element.className = 'status-item';
    
    // Adicionar ao container de status se existir
    const statusContainer = document.getElementById('status-container') || 
                           document.querySelector('.status') || 
                           document.body;
    statusContainer.appendChild(element);
  }
  element.innerText = text;
}

// === FUNÇÕES PARA WIDGETS/COMPONENTES ===

// Widget de saldos
async function createBalanceWidget(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return;

  try {
    const balances = await window.BRLN.getBalances();
    
    container.innerHTML = `
      <div class="brln-balance-widget">
        <h3>💰 Saldos</h3>
        <div class="balance-item">
          <span class="balance-label">🌊 L-BTC:</span>
          <span class="balance-value">${balances.liquid?.lbtc || '0'}</span>
        </div>
        <div class="balance-item">
          <span class="balance-label">₿ Bitcoin:</span>
          <span class="balance-value">${window.BRLN.formatBTC(balances.bitcoin?.confirmed || 0)}</span>
        </div>
        <div class="balance-item">
          <span class="balance-label">⚡ Lightning:</span>
          <span class="balance-value">${window.BRLN.formatSatoshis(balances.lightning?.local || 0)} sats</span>
        </div>
      </div>
    `;
  } catch (error) {
    container.innerHTML = `<div class="error">Erro ao carregar saldos: ${error.message}</div>`;
  }
}

// Widget de envio rápido
function createSendWidget(containerId, network = 'liquid') {
  const container = document.getElementById(containerId);
  if (!container) return;

  const networkConfig = {
    liquid: {
      title: '🌊 Enviar L-BTC',
      unit: 'L-BTC',
      placeholder: 'lq1...'
    },
    bitcoin: {
      title: '₿ Enviar Bitcoin',
      unit: 'BTC',
      placeholder: 'bc1... ou 1... ou 3...'
    }
  };

  const config = networkConfig[network];

  container.innerHTML = `
    <div class="brln-send-widget">
      <h3>${config.title}</h3>
      <form class="send-form" onsubmit="handleSend(event, '${network}')">
        <input 
          type="text" 
          id="${network}-address" 
          placeholder="${config.placeholder}"
          required
        />
        <input 
          type="number" 
          id="${network}-amount" 
          placeholder="Valor em ${config.unit}"
          step="0.00000001"
          min="0"
          required
        />
        <input 
          type="text" 
          id="${network}-description" 
          placeholder="Descrição (opcional)"
        />
        <button type="submit">Enviar ${config.unit}</button>
      </form>
      <div id="${network}-result" class="result"></div>
    </div>
  `;
}

// Handler para envio
async function handleSend(event, network) {
  event.preventDefault();
  
  const address = document.getElementById(`${network}-address`).value;
  const amount = document.getElementById(`${network}-amount`).value;
  const description = document.getElementById(`${network}-description`).value;
  const resultDiv = document.getElementById(`${network}-result`);

  try {
    resultDiv.innerHTML = '<div class="loading">Enviando...</div>';

    let result;
    if (network === 'liquid') {
      const satoshis = window.BRLN.btcToSatoshis(parseFloat(amount));
      result = await window.BRLN.sendLiquid(address, satoshis, description);
    } else if (network === 'bitcoin') {
      const satoshis = window.BRLN.btcToSatoshis(parseFloat(amount));
      result = await window.BRLN.sendBitcoin(address, satoshis);
    }

    resultDiv.innerHTML = `
      <div class="success">
        ✅ Transação enviada!<br>
        ID: ${result.id}
      </div>
    `;

    // Limpar formulário
    event.target.reset();

  } catch (error) {
    resultDiv.innerHTML = `<div class="error">❌ Erro: ${error.message}</div>`;
  }
}

// Widget de invoice Lightning
function createLightningWidget(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return;

  container.innerHTML = `
    <div class="brln-lightning-widget">
      <h3>⚡ Lightning Network</h3>
      
      <div class="lightning-section">
        <h4>Criar Invoice</h4>
        <form onsubmit="handleCreateInvoice(event)">
          <input type="number" id="invoice-amount" placeholder="Valor em satoshis" required>
          <input type="text" id="invoice-description" placeholder="Descrição">
          <button type="submit">Criar Invoice</button>
        </form>
        <div id="invoice-result" class="result"></div>
      </div>

      <div class="lightning-section">
        <h4>Pagar Invoice</h4>
        <form onsubmit="handlePayInvoice(event)">
          <input type="text" id="payment-request" placeholder="lnbc..." required>
          <input type="number" id="max-fee" placeholder="Taxa máxima (sats)" value="100">
          <button type="submit">Pagar</button>
        </form>
        <div id="payment-result" class="result"></div>
      </div>
    </div>
  `;
}

// Handlers Lightning
async function handleCreateInvoice(event) {
  event.preventDefault();
  
  const amount = document.getElementById('invoice-amount').value;
  const description = document.getElementById('invoice-description').value;
  const resultDiv = document.getElementById('invoice-result');

  try {
    resultDiv.innerHTML = '<div class="loading">Criando invoice...</div>';
    
    const invoice = await window.BRLN.createInvoice(
      parseInt(amount), 
      description || 'Invoice BRLN-OS'
    );

    resultDiv.innerHTML = `
      <div class="success">
        ✅ Invoice criado!<br>
        <textarea readonly onclick="this.select()">${invoice.request}</textarea>
      </div>
    `;
  } catch (error) {
    resultDiv.innerHTML = `<div class="error">❌ Erro: ${error.message}</div>`;
  }
}

async function handlePayInvoice(event) {
  event.preventDefault();
  
  const paymentRequest = document.getElementById('payment-request').value;
  const maxFee = document.getElementById('max-fee').value;
  const resultDiv = document.getElementById('payment-result');

  try {
    resultDiv.innerHTML = '<div class="loading">Pagando...</div>';
    
    const payment = await window.BRLN.payInvoice(paymentRequest, parseInt(maxFee));

    resultDiv.innerHTML = `
      <div class="success">
        ✅ Pagamento realizado!<br>
        Fee: ${payment.fee} sats
      </div>
    `;
  } catch (error) {
    resultDiv.innerHTML = `<div class="error">❌ Erro: ${error.message}</div>`;
  }
}

// === INICIALIZAÇÃO ===

// Integrar com sistema existente
document.addEventListener('DOMContentLoaded', function() {
  // Atualizar status incluindo BRLN
  if (typeof atualizarStatus !== 'undefined') {
    const originalAtualizarStatus = atualizarStatus;
    atualizarStatus = function() {
      originalAtualizarStatus();
      atualizarStatusBRLN();
    };
  }

  // Inicializar widgets se containers existirem
  setTimeout(() => {
    if (document.getElementById('brln-balances')) {
      createBalanceWidget('brln-balances');
    }
    if (document.getElementById('brln-send-liquid')) {
      createSendWidget('brln-send-liquid', 'liquid');
    }
    if (document.getElementById('brln-send-bitcoin')) {
      createSendWidget('brln-send-bitcoin', 'bitcoin');
    }
    if (document.getElementById('brln-lightning')) {
      createLightningWidget('brln-lightning');
    }
  }, 1000);
});

// Atualizar status a cada 30 segundos
setInterval(atualizarStatusBRLN, 30000);

// Exportar para uso global
window.BRLNLightningAPI = BRLNLightningAPI;
window.createBalanceWidget = createBalanceWidget;
window.createSendWidget = createSendWidget;
window.createLightningWidget = createLightningWidget;
window.handleSend = handleSend;
window.handleCreateInvoice = handleCreateInvoice;
window.handlePayInvoice = handlePayInvoice;
