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

// === FUNÇÕES UTILITÁRIAS PARA CÁLCULO DE VBYTES ===
function getInputVbytes(addressType) {
  // Retorna vbytes precisos baseado no tipo de endereço da UTXO
  switch (addressType?.toLowerCase()) {
    case 'p2tr':
    case 'witness_v1_taproot':
      return 57.5; // Taproot input
    case 'p2wpkh':
    case 'witness_v0_keyhash':
      return 68; // SegWit v0 P2WPKH
    case 'p2wsh':
    case 'witness_v0_scripthash':
      return 104; // SegWit v0 P2WSH
    case 'p2pkh':
      return 148; // Legacy P2PKH
    case 'p2sh':
    case 'scripthash':
      return 91; // Legacy P2SH
    default:
      return 68; // Default para P2WPKH (mais comum)
  }
}

function getOutputVbytes(addressType) {
  // Retorna vbytes precisos para outputs baseado no tipo
  switch (addressType?.toLowerCase()) {
    case 'p2tr':
    case 'witness_v1_taproot':
      return 43; // Taproot output
    case 'p2wpkh':
    case 'witness_v0_keyhash':
      return 31; // SegWit v0 P2WPKH
    case 'p2wsh':
    case 'witness_v0_scripthash':
      return 43; // SegWit v0 P2WSH
    case 'p2pkh':
      return 34; // Legacy P2PKH
    case 'p2sh':
    case 'scripthash':
      return 32; // Legacy P2SH
    default:
      return 31; // Default para P2WPKH
  }
}

function calculateTransactionVbytes(utxos, outputCount = 1, changeOutput = false) {
  // Overhead base da transação
  let totalVbytes = 10.5;
  
  // Somar vbytes de todos os inputs
  utxos.forEach(utxo => {
    const inputVbytes = getInputVbytes(utxo.address_type);
    totalVbytes += inputVbytes;
  });
  
  // Somar vbytes dos outputs
  totalVbytes += outputCount * getOutputVbytes('p2tr'); // Output principal
  if (changeOutput) {
    totalVbytes += getOutputVbytes('p2wpkh'); // Output de troco
  }
  
  return Math.ceil(totalVbytes);
}

function calculatePreciseFee(vbytes, feeRatePerVbyte) {
  return Math.ceil(vbytes * feeRatePerVbyte);
}

function calculateChangeThreshold(feeRate) {
  // Calcular threshold dinâmico para decidir se cria output de troco
  // Baseado no custo real do output (31 vbytes) com margem de segurança 2x
  // Sempre respeitando o dust limit mínimo de 546 sats
  const changeOutputCost = Math.ceil(31 * feeRate * 2); // 2x margem de segurança
  return Math.max(546, changeOutputCost); // dust limit ou custo com margem
}

function detectAddressType(address) {
  // Detectar tipo de endereço baseado no prefixo
  if (!address) return 'p2wpkh';
  
  if (address.startsWith('bc1p') || address.startsWith('tb1p')) {
    return 'p2tr'; // Taproot
  } else if (address.startsWith('bc1') || address.startsWith('tb1')) {
    return address.length > 42 ? 'p2wsh' : 'p2wpkh'; // SegWit v0
  } else if (address.startsWith('3') || address.startsWith('2')) {
    return 'p2sh'; // Legacy P2SH
  } else if (address.startsWith('1') || address.startsWith('m') || address.startsWith('n')) {
    return 'p2pkh'; // Legacy P2PKH
  }
  
  return 'p2wpkh'; // Default
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

  // Botão de copiar endereço
  const copyBtn = document.getElementById('copyAddressButton');
  if (copyBtn) {
    copyBtn.addEventListener('click', copyGeneratedAddress);
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

  // Botões de consolidação
  const consolidateBtn = document.getElementById('consolidateButton');
  if (consolidateBtn) {
    consolidateBtn.addEventListener('click', showConsolidateForm);
  }

  const consolidateSendBtn = document.getElementById('consolidateSendButton');
  if (consolidateSendBtn) {
    consolidateSendBtn.addEventListener('click', executeConsolidation);
  }
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
    const response = await fetch(`${API_BASE_URL}/fees`);
    const data = await response.json();
    
    if (data.status === 'success' && data.fees) {
      mempoolFees = {
        slow: data.fees.economy?.sat_per_vbyte || 1,
        normal: data.fees.standard?.sat_per_vbyte || 2, 
        fast: data.fees.priority?.sat_per_vbyte || 5
      };
      
      // Atualizar display das taxas
      document.getElementById('slowFee').textContent = `${mempoolFees.slow} sat/vB`;
      document.getElementById('normalFee').textContent = `${mempoolFees.normal} sat/vB`;
      document.getElementById('fastFee').textContent = `${mempoolFees.fast} sat/vB`;
      
      // Atualizar tempos estimados da API
      const slowTimeElement = document.getElementById('slowFeeTime');
      const normalTimeElement = document.getElementById('normalFeeTime');
      const fastTimeElement = document.getElementById('fastFeeTime');
      
      if (slowTimeElement && data.fees.economy?.description) {
        slowTimeElement.textContent = data.fees.economy.description;
      }
      if (normalTimeElement && data.fees.standard?.description) {
        normalTimeElement.textContent = data.fees.standard.description;
      }
      if (fastTimeElement && data.fees.priority?.description) {
        fastTimeElement.textContent = data.fees.priority.description;
      }
      
      // Selecionar opção normal por padrão
      selectFeeOption('normal');
    } else {
      throw new Error('Invalid API response');
    }
    
  } catch (error) {
    console.error('Erro ao carregar taxas da API local:', error);
    // Usar valores padrão em caso de erro
    mempoolFees = { slow: 1, normal: 2, fast: 5 };
    document.getElementById('slowFee').textContent = '1 sat/vB';
    document.getElementById('normalFee').textContent = '2 sat/vB';
    document.getElementById('fastFee').textContent = '5 sat/vB';
    
    // Tempos padrão de fallback
    const slowTimeElement = document.getElementById('slowFeeTime');
    const normalTimeElement = document.getElementById('normalFeeTime');
    const fastTimeElement = document.getElementById('fastFeeTime');
    
    if (slowTimeElement) slowTimeElement.textContent = '~60 min';
    if (normalTimeElement) normalTimeElement.textContent = '~30 min';
    if (fastTimeElement) fastTimeElement.textContent = '~10 min';
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
  // (removido - usando manualFeeInput)
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
      
      // Gerar QR Code real usando API externa
      const qrContainer = document.getElementById('qrCode');
      const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(data.address)}`;
      qrContainer.innerHTML = `<img src="${qrApiUrl}" alt="QR Code para ${data.address}" style="width: 100%; height: 100%; object-fit: contain;" onerror="this.parentElement.innerHTML='<div>Erro ao carregar QR Code</div>'">`;
      
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
  
  try {
    // Obter UTXOs para calcular taxa precisa
    const utxosResponse = await fetch(`${API_BASE_URL}/wallet/utxos`);
    const utxosData = await utxosResponse.json();
    
    if (utxosData.status !== 'success' || !utxosData.utxos) {
      throw new Error('Erro ao obter UTXOs para cálculo de taxa');
    }
    
    // Simular seleção de UTXOs necessárias para o valor solicitado
    const targetAmount = parseInt(amount);
    let selectedUtxos = [];
    let accumulatedValue = 0;
    
    // Ordenar UTXOs do maior para o menor (estratégia de seleção simples)
    const sortedUtxos = [...utxosData.utxos].sort((a, b) => 
      parseInt(b.amount_sat) - parseInt(a.amount_sat)
    );
    
    // Selecionar UTXOs suficientes
    for (const utxo of sortedUtxos) {
      selectedUtxos.push({
        ...utxo,
        address_type: detectAddressType(utxo.address || '')
      });
      accumulatedValue += parseInt(utxo.amount_sat);
      
      // Calcular threshold dinâmico para troco baseado na taxa atual
      const changeThreshold = calculateChangeThreshold(parseFloat(feeRate));
      
      // Calcular vbytes com as UTXOs selecionadas até agora
      const estimatedVbytes = calculateTransactionVbytes(
        selectedUtxos, 
        1, // 1 output para destino
        accumulatedValue > targetAmount + changeThreshold // troco se sobrar mais que threshold dinâmico
      );
      
      const estimatedFee = calculatePreciseFee(estimatedVbytes, parseFloat(feeRate));
      const totalNeeded = targetAmount + estimatedFee;
      
      if (accumulatedValue >= totalNeeded) {
        break;
      }
    }
    
    // Calcular threshold dinâmico para o cálculo final
    const changeThreshold = calculateChangeThreshold(parseFloat(feeRate));
    
    // Calcular valores finais
    const finalVbytes = calculateTransactionVbytes(
      selectedUtxos,
      1,
      accumulatedValue > targetAmount + changeThreshold // usar threshold dinâmico
    );
    
    const finalFee = calculatePreciseFee(finalVbytes, parseFloat(feeRate));
    const totalRequired = targetAmount + finalFee;
    
    if (accumulatedValue < totalRequired) {
      throw new Error(
        `Saldo insuficiente. Necessário: ${totalRequired.toLocaleString()} sats ` +
        `(${targetAmount.toLocaleString()} + ${finalFee.toLocaleString()} taxa), ` +
        `Disponível: ${accumulatedValue.toLocaleString()} sats`
      );
    }
    
    // Confirmar envio com informações precisas
    const feeText = feeMode === 'recommended' 
      ? `taxa ${selectedFeeOption} (${feeRate} sat/vB)` 
      : `taxa manual de ${feeRate} sat/vB`;
    
    const confirmed = confirm(
      `Confirma o envio?\n\n` +
      `Destino: ${address.substring(0, 30)}...\n` +
      `Valor: ${targetAmount.toLocaleString()} sats\n` +
      `Taxa: ${finalFee.toLocaleString()} sats (${finalVbytes} vbytes × ${feeRate} sat/vB)\n` +
      `UTXOs usadas: ${selectedUtxos.length}\n` +
      `Total: ${totalRequired.toLocaleString()} sats`
    );
    
    if (!confirmed) return;
    
    // Enviar transação
    const response = await fetch(`${API_BASE_URL}/wallet/transactions/send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        addr: address,
        amount: targetAmount,
        sat_per_vbyte: parseInt(feeRate)
      })
    });
    
    const data = await response.json();
    
    if (data.status === 'success') {
      showNotification(
        `Transação enviada com sucesso!\n\n` +
        `Valor: ${targetAmount.toLocaleString()} sats\n` +
        `Taxa: ${finalFee.toLocaleString()} sats\n` +
        `TXID: ${data.txid ? data.txid.substring(0, 16) + '...' : 'N/A'}`,
        'success'
      );
      
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
    showNotification(`Erro: ${error.message}`, 'error');
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

function copyGeneratedAddress() {
  const addressElement = document.getElementById('generatedAddressText');
  const address = addressElement.textContent.trim();
  
  if (address && address !== 'Endereço será gerado aqui...') {
    navigator.clipboard.writeText(address).then(() => {
      showNotification('Endereço copiado para a área de transferência!', 'success');
    }).catch(err => {
      console.error('Erro ao copiar endereço:', err);
      showNotification('Erro ao copiar endereço', 'error');
    });
  } else {
    showNotification('Nenhum endereço para copiar', 'error');
  }
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

// === CONSOLIDAÇÃO DE UTXOS ===
function showConsolidateForm() {
  const form = document.getElementById('consolidateForm');
  const feeInput = document.getElementById('consolidateFeeInput');
  
  if (form && feeInput) {
    form.style.display = 'none';
    feeInput.style.display = 'flex';
    
    // Focar no campo de taxa
    const feeField = document.getElementById('consolidateFee');
    if (feeField) {
      setTimeout(() => feeField.focus(), 100);
    }
  }
}

function hideConsolidateForm() {
  const form = document.getElementById('consolidateForm');
  const feeInput = document.getElementById('consolidateFeeInput');
  
  if (form && feeInput) {
    feeInput.style.display = 'none';
    form.style.display = 'flex';
    
    // Limpar campo de taxa
    const feeField = document.getElementById('consolidateFee');
    if (feeField) {
      feeField.value = '';
    }
  }
}

async function executeConsolidation() {
  const feeRateInput = document.getElementById('consolidateFee');
  const feeRate = parseFloat(feeRateInput.value);
  
  // Validações
  if (!feeRate || feeRate <= 0) {
    showNotification('Por favor, insira uma taxa válida', 'error');
    return;
  }
  
  try {
    // Primeiro, obter UTXOs individuais para calcular valor e vbytes precisos
    const utxosResponse = await fetch(`${API_BASE_URL}/wallet/utxos`);
    const utxosData = await utxosResponse.json();
    
    if (utxosData.status !== 'success' || !utxosData.utxos) {
      throw new Error('Erro ao obter UTXOs da carteira');
    }
    
    if (utxosData.utxos.length === 0) {
      throw new Error('Nenhuma UTXO disponível para consolidação');
    }
    
    if (utxosData.utxos.length === 1) {
      throw new Error('Apenas uma UTXO disponível, consolidação não necessária');
    }
    
    // Enriquecer UTXOs com tipo de endereço detectado
    const enrichedUtxos = utxosData.utxos.map(utxo => ({
      ...utxo,
      address_type: detectAddressType(utxo.address || '')
    }));
    
    // Somar valor total de todas as UTXOs
    const totalUtxosValue = enrichedUtxos.reduce((total, utxo) => {
      return total + parseInt(utxo.amount_sat);
    }, 0);
    
    // Calcular vbytes exatos para consolidação (N inputs -> 1 output P2TR)
    const consolidationVbytes = calculateTransactionVbytes(enrichedUtxos, 1, false);
    
    // Calcular taxa exata
    const exactFee = calculatePreciseFee(consolidationVbytes, feeRate);
    
    const consolidationAmount = totalUtxosValue - exactFee;
    
    // Validar se há valor suficiente (dust limit + margem)
    if (consolidationAmount <= 546) {
      throw new Error(
        `Saldo insuficiente para consolidação após deduzir taxas.\n\n` +
        `Valor total das UTXOs: ${totalUtxosValue.toLocaleString()} sats\n` +
        `Taxa calculada: ${exactFee.toLocaleString()} sats (${consolidationVbytes} vbytes × ${feeRate} sat/vB)\n` +
        `Valor resultante: ${consolidationAmount.toLocaleString()} sats`
      );
    }
    
    // Confirmar consolidação com informações precisas
    const confirmed = confirm(
      `Confirma a consolidação de UTXOs?\n\n` +
      `UTXOs a consolidar: ${enrichedUtxos.length}\n` +
      `Valor total: ${totalUtxosValue.toLocaleString()} sats\n` +
      `Tamanho da transação: ${consolidationVbytes} vbytes\n` +
      `Taxa: ${exactFee.toLocaleString()} sats (${feeRate} sat/vB)\n` +
      `Valor final consolidado: ${consolidationAmount.toLocaleString()} sats\n\n` +
      `Será criado um novo endereço P2TR para receber a UTXO consolidada.`
    );
    
    if (!confirmed) {
      hideConsolidateForm();
      return;
    }
    
    // Gerar novo endereço P2TR para a consolidação
    const addressResponse = await fetch(`${API_BASE_URL}/wallet/addresses`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        address_type: 'p2tr'
      })
    });
    
    const addressData = await addressResponse.json();
    
    if (addressData.status !== 'success') {
      throw new Error(`Erro ao gerar endereço: ${addressData.error}`);
    }
    
    const consolidationAddress = addressData.address;
    
    // Executar a transação de consolidação
    const sendResponse = await fetch(`${API_BASE_URL}/wallet/transactions/send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        addr: consolidationAddress,
        amount: consolidationAmount,
        sat_per_vbyte: feeRate
      })
    });
    
    const sendData = await sendResponse.json();
    
    if (sendData.status === 'success') {
      showNotification(
        `Consolidação executada com sucesso!\n\n` +
        `UTXOs consolidadas: ${enrichedUtxos.length}\n` +
        `Valor total original: ${totalUtxosValue.toLocaleString()} sats\n` +
        `Taxa paga: ${exactFee.toLocaleString()} sats (${consolidationVbytes} vbytes)\n` +
        `Valor consolidado: ${consolidationAmount.toLocaleString()} sats\n` +
        `Novo endereço: ${consolidationAddress.substring(0, 20)}...\n` +
        `TXID: ${sendData.txid ? sendData.txid.substring(0, 16) + '...' : 'N/A'}`,
        'success'
      );
      
      // Atualizar dados da interface
      setTimeout(() => {
        updateAllData();
      }, 2000);
      
    } else {
      throw new Error(sendData.error || 'Erro desconhecido na transação');
    }
    
  } catch (error) {
    console.error('Erro na consolidação:', error);
    showNotification(`Erro na consolidação: ${error.message}`, 'error');
  } finally {
    // Esconder formulário de consolidação
    hideConsolidateForm();
  }
}

// === FUNÇÕES LEGADAS (manter compatibilidade) ===
function abrirApp(porta) {
  const url = `http://${window.location.hostname}:${porta}`;
  window.open(url, '_blank');
}
