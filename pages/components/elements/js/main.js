// Central de Controle Elements/Liquid BRLN-OS
// Integração com API local para funcionalidades Elements/Liquid

// Base URL da API
const API_BASE_URL = '/api/v1';

// Variáveis globais
let currentAddressType = 'confidential';
let selectedAsset = 'lbtc';
let currentFilter = 'all';

// Mapeamento de assets
const ASSETS = {
  lbtc: {
    name: 'Bitcoin (L-BTC)',
    symbol: 'L-BTC',
    assetId: '6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d',
    decimals: 8
  },
  depix: {
    name: 'DePix',
    symbol: 'DePix', 
    assetId: '02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189',
    decimals: 0
  },
  usdt: {
    name: 'Tether (USDT)',
    symbol: 'USDT',
    assetId: 'ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2',
    decimals: 8
  }
};

// === FUNÇÕES UTILITÁRIAS ===
function formatAssetAmount(amount, asset) {
  const assetInfo = ASSETS[asset];
  if (!assetInfo) return amount.toString();
  
  const decimals = assetInfo.decimals;
  const numAmount = parseFloat(amount);
  
  if (decimals === 0) {
    return Math.floor(numAmount).toString();
  }
  
  return numAmount.toFixed(decimals);
}

function getAssetSize(amount, asset) {
  const numAmount = parseFloat(amount);
  
  // Tamanhos baseados na quantidade (ajustar conforme necessário)
  if (asset === 'lbtc') {
    if (numAmount >= 1) return 'huge';
    if (numAmount >= 0.1) return 'large';
    if (numAmount >= 0.01) return 'medium';
    if (numAmount >= 0.001) return 'small';
    return 'tiny';
  } else if (asset === 'depix') {
    if (numAmount >= 1000) return 'huge';
    if (numAmount >= 100) return 'large';
    if (numAmount >= 10) return 'medium';
    if (numAmount >= 1) return 'small';
    return 'tiny';
  } else if (asset === 'usdt') {
    if (numAmount >= 1000) return 'huge';
    if (numAmount >= 100) return 'large';
    if (numAmount >= 10) return 'medium';
    if (numAmount >= 1) return 'small';
    return 'tiny';
  }
  
  return 'small';
}

function identifyAssetFromId(assetId) {
  for (const [key, asset] of Object.entries(ASSETS)) {
    if (asset.assetId === assetId) {
      return key;
    }
  }
  return 'unknown';
}

function showMessage(message, type = 'info') {
  // Função para mostrar mensagens ao usuário
  const messageDiv = document.createElement('div');
  messageDiv.className = `message message-${type}`;
  messageDiv.textContent = message;
  messageDiv.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    padding: 15px 20px;
    border-radius: 8px;
    color: white;
    font-weight: bold;
    z-index: 10000;
    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    background: ${type === 'error' ? '#e74c3c' : type === 'success' ? '#27ae60' : '#3498db'};
  `;
  
  document.body.appendChild(messageDiv);
  
  setTimeout(() => {
    messageDiv.remove();
  }, 5000);
}

// === INICIALIZAÇÃO ===
document.addEventListener('DOMContentLoaded', function() {
  initializePage();
  setupEventListeners();
  
  // Atualizar dados a cada 30 segundos
  setInterval(updateAllData, 30000);
});

function initializePage() {
  // Carregar todos os dados iniciais
  updateAllData();
}

function setupEventListeners() {
  // Slider de tipo de endereço (confidencial/não-confidencial)
  const addressSlider = document.getElementById('addressTypeSlider');
  if (addressSlider) {
    addressSlider.addEventListener('click', toggleAddressType);
  }

  // Botão de gerar endereço
  const generateBtn = document.getElementById('generateAddressButton');
  if (generateBtn) {
    generateBtn.addEventListener('click', generateNewAddress);
  }

  // Botão de enviar Asset
  const sendBtn = document.getElementById('sendButton');
  if (sendBtn) {
    sendBtn.addEventListener('click', sendAsset);
  }

  // Botão de copiar endereço
  const copyBtn = document.getElementById('copyAddressButton');
  if (copyBtn) {
    copyBtn.addEventListener('click', copyGeneratedAddress);
  }

  // Seletor de Assets
  const assetOptions = document.querySelectorAll('.asset-option');
  assetOptions.forEach(option => {
    option.addEventListener('click', function() {
      selectAsset(this.dataset.asset);
    });
  });

  // Filtros de UTXOs por Asset
  const assetTabs = document.querySelectorAll('.asset-tab');
  assetTabs.forEach(tab => {
    tab.addEventListener('click', function() {
      filterUTXOs(this.dataset.filter);
    });
  });
}

// === FUNÇÕES DE INTERFACE ===
function toggleAddressType() {
  const slider = document.getElementById('addressTypeSlider');
  const confidentialLabel = document.getElementById('confidentialLabel');
  const nonConfidentialLabel = document.getElementById('nonConfidentialLabel');
  
  if (currentAddressType === 'confidential') {
    currentAddressType = 'non-confidential';
    slider.classList.add('non-confidential');
    confidentialLabel.classList.remove('active');
    confidentialLabel.classList.add('inactive');
    nonConfidentialLabel.classList.remove('inactive');
    nonConfidentialLabel.classList.add('active');
  } else {
    currentAddressType = 'confidential';
    slider.classList.remove('non-confidential');
    nonConfidentialLabel.classList.remove('active');
    nonConfidentialLabel.classList.add('inactive');
    confidentialLabel.classList.remove('inactive');
    confidentialLabel.classList.add('active');
  }
}

function selectAsset(asset) {
  selectedAsset = asset;
  
  // Atualizar interface visual
  document.querySelectorAll('.asset-option').forEach(opt => {
    opt.classList.remove('active');
  });
  document.querySelector(`[data-asset="${asset}"]`).classList.add('active');
  
  console.log(`Asset selecionado: ${ASSETS[asset].name}`);
}

function filterUTXOs(filter) {
  currentFilter = filter;
  
  // Atualizar interface visual dos tabs
  document.querySelectorAll('.asset-tab').forEach(tab => {
    tab.classList.remove('active');
  });
  document.querySelector(`[data-filter="${filter}"]`).classList.add('active');
  
  // Recarregar UTXOs com filtro
  loadUTXOs();
}

// === FUNÇÕES DA API (PLACEHOLDER - serão implementadas quando a API estiver pronta) ===
async function updateAllData() {
  try {
    await Promise.all([
      loadAssetBalances(),
      loadUTXOs(),
      loadTransactions()
    ]);
  } catch (error) {
    console.error('Erro ao atualizar dados:', error);
    showMessage('Erro ao carregar dados do Elements', 'error');
  }
}

async function loadAssetBalances() {
  try {
    const response = await fetch(`${API_BASE_URL}/elements/balances`);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    if (data.status === 'error') {
      throw new Error(data.error);
    }
    
    const balances = data.balances || {};
    
    // Atualizar interface
    document.getElementById('lbtcBalance').textContent = 
      balances.lbtc ? `${balances.lbtc.trusted} L-BTC` : '0.00000000 L-BTC';
    document.getElementById('depixBalance').textContent = 
      balances.depix ? `${balances.depix.trusted} DePix` : '0 DePix';
    document.getElementById('usdtBalance').textContent = 
      balances.usdt ? `${balances.usdt.trusted} USDT` : '0.00000000 USDT';
    
    // Atualizar valores disponíveis no seletor
    document.getElementById('lbtcAvailable').textContent = 
      balances.lbtc ? `Disponível: ${balances.lbtc.trusted} L-BTC` : 'Disponível: 0.00000000 L-BTC';
    document.getElementById('depixAvailable').textContent = 
      balances.depix ? `Disponível: ${balances.depix.trusted} DePix` : 'Disponível: 0 DePix';
    document.getElementById('usdtAvailable').textContent = 
      balances.usdt ? `Disponível: ${balances.usdt.trusted} USDT` : 'Disponível: 0.00000000 USDT';
    
  } catch (error) {
    console.error('Erro ao carregar saldos:', error);
    showMessage(`Erro ao carregar saldos: ${error.message}`, 'error');
    
    // Mostrar valores de erro na interface
    document.getElementById('lbtcBalance').textContent = 'Erro';
    document.getElementById('depixBalance').textContent = 'Erro'; 
    document.getElementById('usdtBalance').textContent = 'Erro';
  }
}

async function loadUTXOs() {
  try {
    let url = `${API_BASE_URL}/elements/utxos`;
    
    // Adicionar filtro se não for 'all'
    if (currentFilter !== 'all') {
      url += `?asset=${currentFilter}`;
    }
    
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    if (data.status === 'error') {
      throw new Error(data.error);
    }
    
    displayUTXOs(data.utxos || []);
    
  } catch (error) {
    console.error('Erro ao carregar UTXOs:', error);
    showMessage(`Erro ao carregar UTXOs: ${error.message}`, 'error');
    
    const container = document.getElementById('utxosContainer');
    container.innerHTML = `
      <div style="width: 100%; text-align: center; padding: 40px; color: #e74c3c; font-style: italic;">
        Erro ao carregar UTXOs: ${error.message}
      </div>
    `;
  }
}

function displayUTXOs(utxos) {
  const container = document.getElementById('utxosContainer');
  
  // Filtrar UTXOs se necessário
  let filteredUTXOs = utxos;
  if (currentFilter !== 'all') {
    filteredUTXOs = utxos.filter(utxo => utxo.asset === currentFilter);
  }
  
  if (filteredUTXOs.length === 0) {
    container.innerHTML = `
      <div style="width: 100%; text-align: center; padding: 40px; color: #666; font-style: italic;">
        Nenhum UTXO encontrado para ${currentFilter === 'all' ? 'todos os assets' : ASSETS[currentFilter]?.name || currentFilter}
      </div>
    `;
    return;
  }
  
  container.innerHTML = filteredUTXOs.map(utxo => {
    const size = getAssetSize(utxo.amount, utxo.asset);
    const formattedAmount = formatAssetAmount(utxo.amount, utxo.asset);
    const assetInfo = ASSETS[utxo.asset];
    
    return `
      <div class="utxo-item ${utxo.asset} utxo-size-${size}" data-txid="${utxo.txid}" data-vout="${utxo.vout}">
        <div class="utxo-amount">${formattedAmount}</div>
        <div class="utxo-asset">${assetInfo?.symbol || utxo.asset.toUpperCase()}</div>
      </div>
    `;
  }).join('');
}

async function loadTransactions() {
  try {
    const response = await fetch(`${API_BASE_URL}/elements/transactions?limit=30`);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    if (data.status === 'error') {
      throw new Error(data.error);
    }
    
    displayTransactions(data.transactions || []);
    
  } catch (error) {
    console.error('Erro ao carregar transações:', error);
    showMessage(`Erro ao carregar transações: ${error.message}`, 'error');
    
    const container = document.getElementById('transactionsContainer');
    container.innerHTML = `
      <div style="width: 100%; text-align: center; padding: 40px; color: #e74c3c; font-style: italic;">
        Erro ao carregar transações: ${error.message}
      </div>
    `;
  }
}

function displayTransactions(transactions) {
  const container = document.getElementById('transactionsContainer');
  
  if (transactions.length === 0) {
    container.innerHTML = `
      <div style="width: 100%; text-align: center; padding: 40px; color: #666; font-style: italic;">
        Nenhuma transação encontrada
      </div>
    `;
    return;
  }
  
  container.innerHTML = transactions.map(tx => {
    const date = new Date(tx.time * 1000).toLocaleString('pt-BR'); // Elements retorna time em segundos
    const shortTxid = tx.txid.substring(0, 8) + '...' + tx.txid.substring(tx.txid.length - 8);
    const assetInfo = ASSETS[tx.asset];
    const amount = parseFloat(tx.amount);
    const amountClass = amount > 0 ? 'positive' : 'negative';
    const amountText = amount > 0 ? `+${formatAssetAmount(Math.abs(amount), tx.asset)}` : `-${formatAssetAmount(Math.abs(amount), tx.asset)}`;
    const fee = Math.abs(parseFloat(tx.fee || 0));
    
    return `
      <div class="transaction-item">
        <div class="transaction-date">${date}</div>
        <div class="transaction-txid" title="${tx.txid}">${shortTxid}</div>
        <div class="transaction-asset">${assetInfo?.symbol || tx.symbol || tx.asset.toUpperCase()}</div>
        <div class="transaction-amount ${amountClass}">${amountText}</div>
        <div class="transaction-fee">${fee.toFixed(8)} L-BTC</div>
      </div>
    `;
  }).join('');
}

// === FUNÇÕES DE AÇÃO (PLACEHOLDER) ===
async function generateNewAddress() {
  try {
    const response = await fetch(`${API_BASE_URL}/elements/addresses`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        type: currentAddressType === 'confidential' ? 'bech32' : 'legacy',
        label: `Generated ${new Date().toISOString()}`
      })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    if (data.status === 'error') {
      throw new Error(data.error);
    }
    
    // Mostrar endereço gerado
    document.getElementById('generatedAddressType').textContent = 
      currentAddressType === 'confidential' ? 'Confidencial' : 'Legacy';
    document.getElementById('generatedAddressText').textContent = data.address;
    document.getElementById('addressDisplay').style.display = 'block';
    
    // Gerar QR Code real usando API externa
    const qrContainer = document.getElementById('qrCode');
    const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(data.address)}`;
    qrContainer.innerHTML = `<img src="${qrApiUrl}" alt="QR Code" style="width: 100%; height: auto; max-width: 150px; max-height: 150px;" onload="console.log('QR Code loaded successfully')" onerror="console.error('QR Code failed to load'); this.style.display='none'; this.nextSibling.style.display='block';" /><div style="display: none; color: #666; text-align: center; font-size: 12px; padding: 10px;">QR Code indisponível</div>`;
    
    showMessage('Endereço Liquid gerado com sucesso!', 'success');
    
  } catch (error) {
    console.error('Erro ao gerar endereço:', error);
    showMessage(`Erro ao gerar endereço: ${error.message}`, 'error');
  }
}

async function sendAsset() {
  const address = document.getElementById('sendAddress').value;
  const amount = document.getElementById('sendAmount').value;
  const fee = document.getElementById('liquidFee').value;
  
  if (!address || !amount) {
    showMessage('Por favor, preencha endereço e quantidade', 'error');
    return;
  }
  
  if (parseFloat(amount) <= 0) {
    showMessage('Quantidade deve ser maior que zero', 'error');
    return;
  }
  
  try {
    const response = await fetch(`${API_BASE_URL}/elements/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        asset: selectedAsset,
        address: address,
        amount: parseFloat(amount),
        subtract_fee: false
      })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    if (data.status === 'error') {
      throw new Error(data.error);
    }
    
    showMessage(`✅ Transação enviada com sucesso!\nTXID: ${data.txid}`, 'success');
    console.log('Transação enviada:', data);
    
    // Limpar formulário
    document.getElementById('sendAddress').value = '';
    document.getElementById('sendAmount').value = '';
    
    // Atualizar dados após 2 segundos
    setTimeout(updateAllData, 2000);
    
  } catch (error) {
    console.error('Erro ao enviar asset:', error);
    showMessage(`Erro ao enviar transação: ${error.message}`, 'error');
  }
}

function copyGeneratedAddress() {
  const addressText = document.getElementById('generatedAddressText').textContent;
  
  if (addressText && addressText !== 'Endereço será gerado aqui...') {
    navigator.clipboard.writeText(addressText).then(() => {
      showMessage('Endereço copiado!', 'success');
    }).catch(() => {
      showMessage('Erro ao copiar endereço', 'error');
    });
  }
}

// === LOG DE DEBUG ===
console.log('Elements/Liquid Control Panel carregado');
console.log('Assets configurados:', ASSETS);