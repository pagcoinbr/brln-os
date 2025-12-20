// Central de Controle Bitcoin BRLN-OS
// Integração com API local para funcionalidades Bitcoin

// Base URL da API
const API_BASE_URL = `http://${window.location.hostname}:2121/api/v1`;

// Variáveis globais
let currentAddressType = 'p2tr';
let selectedFeeOption = 'normal';
let feeMode = 'recommended'; // 'recommended' ou 'manual'
let mempoolFees = {
  slow: 0,
  normal: 0,
  fast: 0
};

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
  loadMempoolFees();
}

function setupEventListeners() {
  // Slider de modo de taxa
  const feeModeSlider = document.getElementById('feeModeSlider');
  if (feeModeSlider) {
    feeModeSlider.addEventListener('click', toggleFeeMode);
  }

  // Slider de tipo de endereço
  const addressSlider = document.getElementById('addressTypeSlider');
  if (addressSlider) {
    addressSlider.addEventListener('click', toggleAddressType);
  }

  // Botão de gerar endereço
  const generateBtn = document.getElementById('generateAddressButton');
  if (generateBtn) {
    generateBtn.addEventListener('click', generateNewAddress);
  }

  // Botão de enviar Bitcoin
  const sendBtn = document.getElementById('sendButton');
  if (sendBtn) {
    sendBtn.addEventListener('click', sendBitcoin);
  }

  // Opções de taxa da mempool (apenas quando em modo recomendado)
  const feeOptions = document.querySelectorAll('.fee-option');
  feeOptions.forEach(option => {
    option.addEventListener('click', function() {
      if (feeMode === 'recommended') {
        selectFeeOption(this.dataset.priority);
      }
    });
  });
}

// === ATUALIZAÇÃO DE DADOS ===
async function updateAllData() {
  await Promise.all([
    loadWalletBalance(),
    loadUTXOs(),
    loadTransactionHistory()
  ]);
}

// === SALDO DA CARTEIRA ===
async function loadWalletBalance() {
  try {
    const response = await fetch(`${API_BASE_URL}/wallet/balance/onchain`);
    const data = await response.json();
    
    if (data.status === 'success') {
      const totalSats = parseInt(data.confirmed_balance);
      const totalBTC = (totalSats / 100000000).toFixed(8);
      
      document.getElementById('totalBalance').textContent = `${totalSats.toLocaleString()} sats`;
      document.getElementById('totalBalanceBTC').textContent = `${totalBTC} BTC`;
    } else {
      console.error('Erro ao carregar saldo:', data.error);
      document.getElementById('totalBalance').textContent = 'Erro ao carregar';
      document.getElementById('totalBalanceBTC').textContent = 'N/A';
    }
  } catch (error) {
    console.error('Erro na requisição de saldo:', error);
    document.getElementById('totalBalance').textContent = 'Erro de conexão';
    document.getElementById('totalBalanceBTC').textContent = 'N/A';
  }
}

// === UTXOS ===
async function loadUTXOs() {
  try {
    const response = await fetch(`${API_BASE_URL}/wallet/utxos`);
    const data = await response.json();
    
    if (data.status === 'success' && data.utxos) {
      displayUTXOs(data.utxos);
    } else {
      console.error('Erro ao carregar UTXOs:', data.error);
    }
  } catch (error) {
    console.error('Erro na requisição de UTXOs:', error);
  }
}

function displayUTXOs(utxos) {
  const container = document.getElementById('utxosContainer');
  if (!container) return;
  
  // Limpar UTXOs existentes
  container.innerHTML = '';
  
  utxos.forEach(utxo => {
    const sats = parseInt(utxo.amount_sat);
    const btc = (sats / 100000000).toFixed(8);
    
    // Determinar tamanho baseado na quantidade
    let sizeClass = 'utxo-small';
    if (sats >= 1000000) sizeClass = 'utxo-xlarge'; // > 1M sats
    else if (sats >= 100000) sizeClass = 'utxo-large';  // > 100k sats
    else if (sats >= 50000) sizeClass = 'utxo-medium';   // > 50k sats
    
    const utxoElement = document.createElement('div');
    utxoElement.className = `utxo-square ${sizeClass}`;
    utxoElement.innerHTML = `
      <div class="utxo-amount">${btc} BTC</div>
      <div class="utxo-sats">${sats.toLocaleString()} sats</div>
    `;
    
    // Adicionar tooltip com informações da UTXO
    utxoElement.title = `TXID: ${utxo.outpoint.txid_str}\nOutput: ${utxo.outpoint.output_index}\nConfirmações: ${utxo.confirmations}`;
    
    container.appendChild(utxoElement);
  });
  
  if (utxos.length === 0) {
    container.innerHTML = '<div style="text-align: center; color: #666; padding: 20px;">Nenhuma UTXO disponível</div>';
  }
}

// === HISTÓRICO DE TRANSAÇÕES ===
async function loadTransactionHistory() {
  try {
    const response = await fetch(`${API_BASE_URL}/wallet/transactions`);
    const data = await response.json();
    
    if (data.status === 'success' && data.transactions) {
      displayTransactions(data.transactions);
    } else {
      console.error('Erro ao carregar transações:', data.error);
    }
  } catch (error) {
    console.error('Erro na requisição de transações:', error);
  }
}

function displayTransactions(transactions) {
  const historyContainer = document.querySelector('.transactions-history');
  if (!historyContainer) return;
  
  // Manter o header, remover apenas os itens
  const header = historyContainer.querySelector('.transaction-header');
  historyContainer.innerHTML = '';
  if (header) historyContainer.appendChild(header);
  
  transactions.slice(0, 10).forEach(tx => { // Mostrar apenas as últimas 10
    const date = new Date(tx.time_stamp * 1000);
    const dateStr = date.toLocaleDateString('pt-BR');
    const timeStr = date.toLocaleTimeString('pt-BR');
    
    const amount = parseInt(tx.amount);
    const fee = parseInt(tx.total_fees);
    
    const isReceived = amount > 0;
    
    const txElement = document.createElement('div');
    txElement.className = 'transaction-item';
    txElement.innerHTML = `
      <div class="tx-datetime">
        ${dateStr}<br/>
        ${timeStr}
      </div>
      <div class="tx-id" title="${tx.tx_hash}" onclick="copyToClipboard('${tx.tx_hash}')">
        ${tx.tx_hash.substring(0, 16)}...
      </div>
      <div class="tx-amount ${isReceived ? 'received' : 'sent'}">
        ${isReceived ? '+' : ''}${Math.abs(amount).toLocaleString()} sats
      </div>
      <div class="tx-fee">
        ${isReceived ? '-' : `${fee.toLocaleString()} sats`}
      </div>
    `;
    
    historyContainer.appendChild(txElement);
  });
  
  if (transactions.length === 0) {
    const noTxElement = document.createElement('div');
    noTxElement.style.cssText = 'text-align: center; color: #666; padding: 20px;';
    noTxElement.textContent = 'Nenhuma transação encontrada';
    historyContainer.appendChild(noTxElement);
  }
}

// === TAXAS DA MEMPOOL ===
async function loadMempoolFees() {
  try {
    const response = await fetch('https://mempool.space/api/v1/fees/recommended');
    const data = await response.json();
    
    mempoolFees = {
      slow: data.hourFee || 1,
      normal: data.halfHourFee || 2, 
      fast: data.fastestFee || 5
    };
    
    // Atualizar display das taxas
    document.getElementById('slowFee').textContent = `${mempoolFees.slow} sat/vB`;
    document.getElementById('normalFee').textContent = `${mempoolFees.normal} sat/vB`;
    document.getElementById('fastFee').textContent = `${mempoolFees.fast} sat/vB`;
    
    // Selecionar opção normal por padrão
    selectFeeOption('normal');
    
  } catch (error) {
    console.error('Erro ao carregar taxas da mempool:', error);
    // Usar valores padrão em caso de erro
    mempoolFees = { slow: 1, normal: 2, fast: 5 };
    document.getElementById('slowFee').textContent = '1 sat/vB';
    document.getElementById('normalFee').textContent = '2 sat/vB';
    document.getElementById('fastFee').textContent = '5 sat/vB';
  }
}

function selectFeeOption(priority) {
  // Apenas funciona em modo recomendado
  if (feeMode !== 'recommended') return;
  
  selectedFeeOption = priority;
  
  // Remover seleção anterior
  document.querySelectorAll('.fee-option').forEach(option => {
    option.classList.remove('selected');
  });
  
  // Adicionar seleção atual
  const selectedElement = document.querySelector(`[data-priority="${priority}"]`);
  if (selectedElement) {
    selectedElement.classList.add('selected');
  }
  
  // Atualizar campo de taxa personalizada (oculto)
  const customFeeInput = document.getElementById('customFee');
  if (customFeeInput) {
    customFeeInput.value = mempoolFees[priority];
  }
}

// === CONTROLE DE MODO DE TAXA ===
function toggleFeeMode() {
  const track = document.getElementById('feeModeTrack');
  const recommendedLabel = document.getElementById('recommendedLabel');
  const manualLabel = document.getElementById('manualLabel');
  const recommendedSection = document.getElementById('recommendedFeeSection');
  const manualSection = document.getElementById('manualFeeSection');
  
  if (feeMode === 'recommended') {
    // Mudar para modo manual
    feeMode = 'manual';
    track.classList.add('manual');
    recommendedLabel.classList.remove('active');
    recommendedLabel.classList.add('inactive');
    manualLabel.classList.remove('inactive');
    manualLabel.classList.add('active');
    
    // Mostrar seção manual, esconder recomendada
    recommendedSection.classList.add('hidden');
    manualSection.classList.add('show');
    
  } else {
    // Mudar para modo recomendado
    feeMode = 'recommended';
    track.classList.remove('manual');
    manualLabel.classList.remove('active');
    manualLabel.classList.add('inactive');
    recommendedLabel.classList.remove('inactive');
    recommendedLabel.classList.add('active');
    
    // Mostrar seção recomendada, esconder manual
    manualSection.classList.remove('show');
    recommendedSection.classList.remove('hidden');
    
    // Reselecionar opção atual se já carregadas as taxas
    if (mempoolFees.normal > 0) {
      selectFeeOption(selectedFeeOption);
    }
  }
}

// === GERAÇÃO DE ENDEREÇOS ===
function toggleAddressType() {
  const track = document.getElementById('sliderTrack');
  const p2trLabel = document.getElementById('p2trLabel');
  const p2wshLabel = document.getElementById('p2wshLabel');
  
  if (currentAddressType === 'p2tr') {
    currentAddressType = 'p2wsh';
    track.classList.add('p2wsh');
    p2trLabel.classList.remove('active');
    p2trLabel.classList.add('inactive');
    p2wshLabel.classList.remove('inactive');
    p2wshLabel.classList.add('active');
  } else {
    currentAddressType = 'p2tr';
    track.classList.remove('p2wsh');
    p2wshLabel.classList.remove('active');
    p2wshLabel.classList.add('inactive');
    p2trLabel.classList.remove('inactive');
    p2trLabel.classList.add('active');
  }
  
  // Ocultar endereço gerado quando trocar tipo
  const addressDisplay = document.getElementById('addressDisplay');
  if (addressDisplay) {
    addressDisplay.classList.remove('show');
  }
}

async function generateNewAddress() {
  try {
    const response = await fetch(`${API_BASE_URL}/wallet/addresses`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        address_type: currentAddressType
      })
    });
    
    const data = await response.json();
    
    if (data.status === 'success') {
      // Atualizar display do endereço gerado
      document.getElementById('generatedAddressType').textContent = currentAddressType.toUpperCase();
      document.getElementById('generatedAddressText').textContent = data.address;
      
      // Gerar QR Code (simulado - em produção usaria uma biblioteca de QR)
      const qrContainer = document.getElementById('qrCode');
      qrContainer.innerHTML = `<div style="font-size: 10px; text-align: center;">QR para:<br/>${data.address.substring(0, 20)}...</div>`;
      
      // Mostrar o display do endereço
      document.getElementById('addressDisplay').classList.add('show');
      
      // Mostrar mensagem de sucesso
      showNotification('Endereço gerado com sucesso!', 'success');
      
    } else {
      showNotification(`Erro ao gerar endereço: ${data.error}`, 'error');
    }
  } catch (error) {
    console.error('Erro ao gerar endereço:', error);
    showNotification('Erro de conexão ao gerar endereço', 'error');
  }
}

// === ENVIO DE BITCOIN ===
async function sendBitcoin() {
  const address = document.getElementById('sendAddress').value.trim();
  const amount = document.getElementById('sendAmount').value;
  
  // Determinar taxa baseada no modo
  let feeRate;
  if (feeMode === 'recommended') {
    feeRate = mempoolFees[selectedFeeOption];
  } else {
    feeRate = document.getElementById('manualFeeInput').value;
  }
  
  // Validações
  if (!address) {
    showNotification('Por favor, insira um endereço de destino', 'error');
    return;
  }
  
  if (!amount || amount <= 0) {
    showNotification('Por favor, insira uma quantidade válida', 'error');
    return;
  }
  
  if (!feeRate || feeRate <= 0) {
    const modeText = feeMode === 'recommended' ? 'uma opção de taxa' : 'uma taxa manual';
    showNotification(`Por favor, selecione ${modeText}`, 'error');
    return;
  }
  
  // Confirmar envio
  const feeText = feeMode === 'recommended' 
    ? `taxa ${selectedFeeOption} (${feeRate} sat/vB)` 
    : `taxa manual de ${feeRate} sat/vB`;
  
  const confirmed = confirm(`Confirma o envio de ${parseInt(amount).toLocaleString()} sats para ${address.substring(0, 20)}...?\n\nUsando ${feeText}`);
  if (!confirmed) return;
  
  try {
    const response = await fetch(`${API_BASE_URL}/wallet/transactions/send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        addr: address,
        amount: parseInt(amount),
        sat_per_vbyte: parseInt(feeRate)
      })
    });
    
    const data = await response.json();
    
    if (data.status === 'success') {
      showNotification('Transação enviada com sucesso!', 'success');
      
      // Limpar formulário
      document.getElementById('sendAddress').value = '';
      document.getElementById('sendAmount').value = '';
      if (feeMode === 'manual') {
        document.getElementById('manualFeeInput').value = '';
      }
      
      // Atualizar dados
      setTimeout(updateAllData, 2000);
      
    } else {
      showNotification(`Erro ao enviar: ${data.error}`, 'error');
    }
  } catch (error) {
    console.error('Erro ao enviar Bitcoin:', error);
    showNotification('Erro de conexão ao enviar transação', 'error');
  }
}

// === UTILITÁRIOS ===
function copyToClipboard(text) {
  navigator.clipboard.writeText(text).then(() => {
    showNotification('TXID copiado para a área de transferência', 'success');
  }).catch(err => {
    console.error('Erro ao copiar:', err);
  });
}

function showNotification(message, type = 'info') {
  // Criar elemento de notificação
  const notification = document.createElement('div');
  notification.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    background: ${type === 'error' ? '#ff4444' : type === 'success' ? '#44ff44' : '#4444ff'};
    color: white;
    padding: 15px 20px;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    z-index: 9999;
    font-weight: bold;
    max-width: 300px;
  `;
  notification.textContent = message;
  
  document.body.appendChild(notification);
  
  // Remover após 3 segundos
  setTimeout(() => {
    notification.remove();
  }, 3000);
}

// === FUNÇÕES LEGADAS (manter compatibilidade) ===
function abrirApp(porta) {
  const url = `http://${window.location.hostname}:${porta}`;
  window.open(url, '_blank');
}
