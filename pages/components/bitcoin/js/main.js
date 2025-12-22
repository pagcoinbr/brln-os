// Central de Controle Bitcoin BRLN-OS
// Integração com API local para funcionalidades Bitcoin

// Base URL da API
const API_BASE_URL = '/api/v1';

// Variáveis globais
let currentAddressType = 'p2tr';
let selectedFeeOption = 'normal';
let feeMode = 'recommended'; // 'recommended' ou 'manual'
let mempoolFees = {
  slow: 0,
  normal: 0,
  fast: 0
};

// === FUNÇÕES UTILITÁRIAS (mantidas para compatibilidade com outras funcionalidades) ===
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
      const confirmedSats = parseInt(data.confirmed_balance || 0);
      const unconfirmedSats = parseInt(data.unconfirmed_balance || 0);
      const totalSats = confirmedSats + unconfirmedSats;
      
      document.getElementById('totalBalance').textContent = `Total: ${totalSats.toLocaleString()} sats`;
      document.getElementById('confirmedBalance').textContent = `Confirmado: ${confirmedSats.toLocaleString()} sats`;
      document.getElementById('unconfirmedBalance').textContent = `Não Confirmado: ${unconfirmedSats.toLocaleString()} sats`;
    } else {
      console.error('Erro ao carregar saldo:', data.error);
      document.getElementById('totalBalance').textContent = 'Erro ao carregar';
      document.getElementById('confirmedBalance').textContent = 'N/A';
      document.getElementById('unconfirmedBalance').textContent = 'N/A';
    }
  } catch (error) {
    console.error('Erro na requisição de saldo:', error);
    document.getElementById('totalBalance').textContent = 'Erro de conexão';
    document.getElementById('confirmedBalance').textContent = 'N/A';
    document.getElementById('unconfirmedBalance').textContent = 'N/A';
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
      <div class="utxo-amount">${sats.toLocaleString()} sats</div>
      <div class="utxo-sats">${utxo.confirmations} confs</div>
    `;
    
    // Adicionar tooltip com informações da UTXO
    utxoElement.title = `TXID: ${utxo.outpoint.txid_str}\nOutput: ${utxo.outpoint.output_index}\nConfirmações: ${utxo.confirmations}\n\nClique para ver no mempool.space`;
    
    // Adicionar evento de clique para abrir no mempool.space
    utxoElement.style.cursor = 'pointer';
    utxoElement.addEventListener('click', () => {
      openMempoolUtxo(utxo.outpoint.txid_str, utxo.outpoint.output_index);
    });
    
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
  
  transactions.slice(0, 30).forEach(tx => { // Mostrar apenas as últimas 10
    const date = new Date(tx.time_stamp * 1000);
    const dateStr = date.toLocaleDateString('pt-BR');
    const timeStr = date.toLocaleTimeString('pt-BR');
    
    const amount = parseInt(tx.amount);
    const fee = parseInt(tx.total_fees);
    
    const isReceived = tx.type === 'received';
    
    const txElement = document.createElement('div');
    txElement.className = 'transaction-item';
    txElement.innerHTML = `
      <div class="tx-datetime">
        ${dateStr}<br/>
        ${timeStr}
      </div>
      <div class="tx-id" title="${tx.tx_hash}\n\nClique para ver no mempool.space" onclick="openMempoolTransaction('${tx.tx_hash}')">
        ${tx.tx_hash.substring(0, 16)}...
      </div>
      <div class="tx-amount ${isReceived ? 'received' : 'sent'}">
        ${isReceived ? '+' : '-'}${Math.abs(amount).toLocaleString()} sats
      </div>
      <div class="tx-fee">
        ${fee > 0 ? `${fee.toLocaleString()} sats` : '-'}
      </div>
    `;
    
    // Adicionar evento de clique para toda a transação também abrir no mempool.space
    txElement.style.cursor = 'pointer';
    txElement.addEventListener('click', (e) => {
      // Se não clicou especificamente no TXID, também abrir o mempool
      if (!e.target.classList.contains('tx-id')) {
        openMempoolTransaction(tx.tx_hash);
      }
    });
    
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
        slow: data.fees.economy?.sat_per_vbyte,
        normal: data.fees.standard?.sat_per_vbyte, 
        fast: data.fees.priority?.sat_per_vbyte
      };
      
      // Atualizar display das taxas
      document.getElementById('slowFee').textContent = `${mempoolFees.slow} sat/vB`;
      document.getElementById('normalFee').textContent = `${mempoolFees.normal} sat/vB`;
      document.getElementById('fastFee').textContent = `${mempoolFees.fast} sat/vB`;
      
      // Selecionar opção normal por padrão
      selectFeeOption('normal');
    } else {
      throw new Error('Invalid API response');
    }
    
  } catch (error) {
    console.error('Erro ao carregar taxas da API local:', error);
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
  
  // Validações básicas
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
    const targetAmount = parseInt(amount);
    
    // Confirmar envio
    const feeText = feeMode === 'recommended' 
      ? `taxa ${selectedFeeOption} (${feeRate} sat/vB)` 
      : `taxa manual de ${feeRate} sat/vB`;
    
    const confirmed = confirm(
      `Confirma o envio?\n\n` +
      `Destino: ${address.substring(0, 30)}...\n` +
      `Valor: ${targetAmount.toLocaleString()} sats\n` +
      `Taxa: ${feeRate} sat/vB\n\n` +
      `LND selecionará automaticamente as UTXOs e calculará as taxas precisas.`
    );
    
    if (!confirmed) return;
    
    // Enviar transação usando a API
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
        `Taxa: ${feeRate} sat/vB\n` +
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

// === MEMPOOL.SPACE INTEGRATION ===
function openMempoolTransaction(txid) {
  const mempoolUrl = `https://mempool.space/tx/${txid}`;
  window.open(mempoolUrl, '_blank');
  showNotification('Abrindo transação no mempool.space', 'info');
}

function openMempoolUtxo(txid, outputIndex) {
  // Abrir a página da transação e destacar a saída específica
  const mempoolUrl = `https://mempool.space/tx/${txid}#vout=${outputIndex}`;
  window.open(mempoolUrl, '_blank');
  showNotification(`Abrindo UTXO ${outputIndex} no mempool.space`, 'info');
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
  
  // Validações básicas
  if (!feeRate || feeRate <= 0) {
    showNotification('Por favor, insira uma taxa válida', 'error');
    return;
  }
  
  try {
    // Obter UTXOs para validação básica
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
    
    // Somar valor total das UTXOs (apenas para exibição)
    const totalUtxosValue = utxosData.utxos.reduce((total, utxo) => {
      return total + parseInt(utxo.amount_sat);
    }, 0);
    
    // Confirmar consolidação 
    const confirmed = confirm(
      `Confirma a consolidação de UTXOs?\n\n` +
      `UTXOs a consolidar: ${utxosData.utxos.length}\n` +
      `Valor total: ${totalUtxosValue.toLocaleString()} sats\n` +
      `Taxa: ${feeRate} sat/vB\n\n` +
      `Será criado um novo endereço P2TR para receber toda a consolidação.\n` +
      `LND calculará automaticamente as taxas precisas.`
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
    
    // Executar a transação de consolidação usando send_all (equivalente ao --sweepall do lncli)
    const sendResponse = await fetch(`${API_BASE_URL}/wallet/transactions/send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        addr: consolidationAddress,
        send_all: true,
        sat_per_vbyte: feeRate
      })
    });
    
    const sendData = await sendResponse.json();
    
    if (sendData.status === 'success') {
      showNotification(
        `Consolidação executada com sucesso!\n\n` +
        `UTXOs consolidadas: ${utxosData.utxos.length}\n` +
        `Valor total original: ${totalUtxosValue.toLocaleString()} sats\n` +
        `Novo endereço: ${consolidationAddress.substring(0, 20)}...\n` +
        `TXID: ${sendData.txid ? sendData.txid.substring(0, 16) + '...' : 'N/A'}\n\n` +
        `LND calculou automaticamente as taxas precisas.`,
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
