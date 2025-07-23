// ===================================================================
// EXTENSÕES PARA main.js - Lightning + Elements Integration
// Adicione este código ao seu main.js existente
// ===================================================================

// Adicionar ao seu main.js existente - NOVAS FUNCIONALIDADES

// 1. Função para obter saldos das carteiras
async function atualizarSaldos() {
  try {
    const response = await fetch(`${flaskBaseURL}/api/wallets/balances`);
    if (!response.ok) throw new Error('Erro ao obter saldos');
    
    const balances = await response.json();
    
    // Atualizar UI com saldos Lightning
    if (balances.lightning && !balances.lightning.error) {
      const lnBalanceElement = document.getElementById('lightning-balance');
      if (lnBalanceElement) {
        lnBalanceElement.innerHTML = `
          <strong>⚡ Lightning:</strong> ${balances.lightning.channel_balance} sats
          <small>(Pendente: ${balances.lightning.pending_balance} sats)</small>
        `;
      }
    }
    
    // Atualizar UI com saldos Bitcoin
    if (balances.bitcoin && !balances.bitcoin.error) {
      const btcBalanceElement = document.getElementById('bitcoin-balance');
      if (btcBalanceElement) {
        btcBalanceElement.innerHTML = `
          <strong>₿ Bitcoin:</strong> ${balances.bitcoin.confirmed_balance} sats
          <small>(Não confirmado: ${balances.bitcoin.unconfirmed_balance} sats)</small>
        `;
      }
    }
    
    // Atualizar UI com saldos Liquid
    if (balances.liquid && !balances.liquid.error) {
      const liquidBalanceElement = document.getElementById('liquid-balance');
      if (liquidBalanceElement) {
        liquidBalanceElement.innerHTML = `
          <strong>🌊 Liquid:</strong> ${balances.liquid.lbtc_balance} L-BTC
          <small>(${balances.liquid.assets_count} assets)</small>
        `;
      }
      
      // Mostrar assets principais
      const assetsElement = document.getElementById('liquid-assets');
      if (assetsElement && balances.liquid.assets) {
        assetsElement.innerHTML = balances.liquid.assets
          .map(asset => `<div class="asset-item">${asset.name || asset.asset_id.substring(0,8)}...</div>`)
          .join('');
      }
    }
    
    console.log('💰 Saldos atualizados:', balances);
  } catch (error) {
    console.error('❌ Erro ao atualizar saldos:', error);
  }
}

// 2. Função para obter informações detalhadas das blockchains
async function atualizarBlockchainInfo() {
  try {
    const response = await fetch(`${flaskBaseURL}/api/blockchain/info`);
    if (!response.ok) throw new Error('Erro ao obter info blockchain');
    
    const info = await response.json();
    
    // Atualizar informações Lightning
    if (info.lightning && !info.lightning.error) {
      const lnInfoElement = document.getElementById('lightning-info');
      if (lnInfoElement) {
        lnInfoElement.innerHTML = `
          <div class="blockchain-info">
            <h4>⚡ Lightning Network</h4>
            <p><strong>Alias:</strong> ${info.lightning.alias || 'Não definido'}</p>
            <p><strong>Peers:</strong> ${info.lightning.peers}</p>
            <p><strong>Canais:</strong> ${info.lightning.channels}</p>
            <p><strong>Pubkey:</strong> ${info.lightning.identity_pubkey.substring(0,20)}...</p>
          </div>
        `;
      }
    }
    
    // Atualizar informações Liquid
    if (info.liquid && !info.liquid.error) {
      const liquidInfoElement = document.getElementById('liquid-info');
      if (liquidInfoElement) {
        liquidInfoElement.innerHTML = `
          <div class="blockchain-info">
            <h4>🌊 Liquid Network</h4>
            <p><strong>Chain:</strong> ${info.liquid.chain}</p>
            <p><strong>Blocos:</strong> ${info.liquid.blocks}</p>
            <p><strong>Progresso:</strong> ${(info.liquid.verification_progress * 100).toFixed(1)}%</p>
          </div>
        `;
      }
    }
    
    console.log('📊 Blockchain info atualizada:', info);
  } catch (error) {
    console.error('❌ Erro ao atualizar blockchain info:', error);
  }
}

// 3. Função para criar invoice Lightning
async function criarInvoiceLightning() {
  const amount = document.getElementById('invoice-amount')?.value;
  const description = document.getElementById('invoice-description')?.value;
  
  if (!amount || amount <= 0) {
    alert('Por favor, insira um valor válido');
    return;
  }
  
  try {
    const response = await fetch(`${flaskBaseURL}/api/lightning/invoice`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        amount: parseInt(amount), 
        description: description || 'Fatura BRLN-OS' 
      })
    });
    
    if (!response.ok) throw new Error('Erro ao criar invoice');
    
    const invoice = await response.json();
    
    // Mostrar o invoice criado
    const invoiceResult = document.getElementById('invoice-result');
    if (invoiceResult) {
      invoiceResult.innerHTML = `
        <div class="invoice-created">
          <h4>⚡ Invoice Criado!</h4>
          <p><strong>Valor:</strong> ${amount} sats</p>
          <p><strong>Hash:</strong> ${invoice.payment_hash.substring(0,20)}...</p>
          <textarea readonly onclick="this.select()">${invoice.payment_request}</textarea>
          <button onclick="copyToClipboard('${invoice.payment_request}')">📋 Copiar</button>
        </div>
      `;
    }
    
    console.log('⚡ Invoice criado:', invoice);
  } catch (error) {
    console.error('❌ Erro ao criar invoice:', error);
    alert('Erro ao criar invoice: ' + error.message);
  }
}

// 4. Função para criar endereço Liquid
async function criarEnderecoLiquid() {
  const label = document.getElementById('address-label')?.value;
  
  try {
    const response = await fetch(`${flaskBaseURL}/api/liquid/address`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ label: label || 'Endereço BRLN-OS' })
    });
    
    if (!response.ok) throw new Error('Erro ao criar endereço');
    
    const address = await response.json();
    
    // Mostrar o endereço criado
    const addressResult = document.getElementById('address-result');
    if (addressResult) {
      addressResult.innerHTML = `
        <div class="address-created">
          <h4>🌊 Endereço Liquid Criado!</h4>
          <p><strong>Formato:</strong> ${address.format}</p>
          <input type="text" readonly value="${address.address}" onclick="this.select()">
          <button onclick="copyToClipboard('${address.address}')">📋 Copiar</button>
        </div>
      `;
    }
    
    console.log('🌊 Endereço criado:', address);
  } catch (error) {
    console.error('❌ Erro ao criar endereço:', error);
    alert('Erro ao criar endereço: ' + error.message);
  }
}

// 5. Função para controlar containers Docker
async function controlarContainer(containerName, action) {
  try {
    const response = await fetch(`${flaskBaseURL}/api/docker/container/${containerName}/${action}`, {
      method: 'POST'
    });
    
    if (!response.ok) throw new Error(`Erro ao ${action} container`);
    
    const result = await response.json();
    console.log(`🐳 Container ${containerName} ${action}:`, result);
    
    // Atualizar status após ação
    setTimeout(atualizarStatus, 2000);
    
  } catch (error) {
    console.error(`❌ Erro ao ${action} container ${containerName}:`, error);
    alert(`Erro ao ${action} container: ` + error.message);
  }
}

// 6. Função para testar integração
async function testarIntegracao() {
  try {
    const response = await fetch(`${flaskBaseURL}/api/test/integration`);
    const result = await response.json();
    
    const testResult = document.getElementById('integration-test');
    if (testResult) {
      testResult.innerHTML = `
        <div class="test-result ${result.status === 'success' ? 'success' : 'error'}">
          <h4>🧪 Teste de Integração</h4>
          <p><strong>Status:</strong> ${result.message}</p>
          <p><strong>Lightning Integration:</strong> ${result.tests.lightning_integration ? '✅' : '❌'}</p>
          <p><strong>Elements Integration:</strong> ${result.tests.elements_integration ? '✅' : '❌'}</p>
          <p><strong>LND Connection:</strong> ${result.tests.lnd_connection ? '✅' : '❌'}</p>
          <p><strong>Elements Connection:</strong> ${result.tests.elements_connection ? '✅' : '❌'}</p>
          <details>
            <summary>Métodos Disponíveis</summary>
            <pre>${JSON.stringify(result.tests.available_methods, null, 2)}</pre>
          </details>
        </div>
      `;
    }
    
    console.log('🧪 Teste de integração:', result);
  } catch (error) {
    console.error('❌ Erro no teste:', error);
  }
}

// 7. Função utilitária para copiar texto
function copyToClipboard(text) {
  navigator.clipboard.writeText(text).then(() => {
    alert('📋 Copiado para área de transferência!');
  }).catch(err => {
    console.error('❌ Erro ao copiar:', err);
  });
}

// 8. Função para inicializar novas funcionalidades
function inicializarLightningElements() {
  console.log('🚀 Inicializando Lightning + Elements integration...');
  
  // Atualizar saldos imediatamente
  atualizarSaldos();
  atualizarBlockchainInfo();
  
  // Atualizar saldos a cada 30 segundos
  setInterval(atualizarSaldos, 30000);
  
  // Atualizar blockchain info a cada 60 segundos
  setInterval(atualizarBlockchainInfo, 60000);
  
  // Verificar integração
  testarIntegracao();
  
  console.log('✅ Lightning + Elements integration inicializada!');
}

// ===================================================================
// MODIFICAR A FUNÇÃO ORIGINAL atualizarStatus para usar o novo servidor
// ===================================================================

// Substitua sua função atualizarStatus existente por esta versão melhorada:
function atualizarStatusMelhorado() {
  // Usar o novo endpoint que integra com Lightning + Elements
  fetch(`${flaskBaseURL}/api/system/status`)
      .then(res => {
          if (!res.ok) {
              // Fallback para o endpoint original se o novo não funcionar
              return fetch('/cgi-bin/status.sh').then(r => r.text());
          }
          return res.json();
      })
      .then(data => {
          if (typeof data === 'string') {
              // Processar resposta de texto (fallback)
              const lines = data.split('\n');
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
          } else {
              // Processar resposta JSON (novo servidor)
              const cpuElement = document.getElementById("cpu");
              if (cpuElement) cpuElement.innerText = data.cpu;
              
              const ramElement = document.getElementById("ram");
              if (ramElement) ramElement.innerText = data.ram;
              
              const lndElement = document.getElementById("lnd");
              if (lndElement) lndElement.innerText = data.lnd;
              
              const bitcoindElement = document.getElementById("bitcoind");
              if (bitcoindElement) bitcoindElement.innerText = data.bitcoind;
              
              const torElement = document.getElementById("tor");
              if (torElement) torElement.innerText = data.tor;
              
              const blockchainElement = document.getElementById("blockchain");
              if (blockchainElement) blockchainElement.innerText = data.blockchain;
              
              // Adicionar status do Elements se disponível
              if (data.elements) {
                  const elementsElement = document.getElementById("elements");
                  if (elementsElement) elementsElement.innerText = data.elements;
              }
          }
      })
      .catch(error => {
          console.error("Erro ao atualizar status:", error.message);
      });
}

// ===================================================================
// INICIALIZAÇÃO AUTOMÁTICA
// ===================================================================

// Adicionar ao seu window.onload existente ou substituir:
const originalOnload = window.onload;
window.onload = function() {
  // Executar onload original se existir
  if (originalOnload) {
    originalOnload();
  }
  
  // Executar nova funcionalidade
  atualizarStatusMelhorado();
  inicializarLightningElements();
};

// ===================================================================
// ESTILOS CSS ADICIONAIS (adicionar ao seu CSS)
// ===================================================================

const additionalCSS = `
.wallet-balances {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 15px;
  margin: 20px 0;
}

.balance-card {
  background: var(--card-background, #f5f5f5);
  border: 1px solid var(--border-color, #ddd);
  border-radius: 8px;
  padding: 15px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.blockchain-info {
  background: var(--info-background, #e3f2fd);
  border-left: 4px solid var(--accent-color, #2196f3);
  padding: 15px;
  margin: 10px 0;
  border-radius: 0 8px 8px 0;
}

.invoice-created, .address-created {
  background: var(--success-background, #e8f5e8);
  border: 1px solid var(--success-color, #4caf50);
  border-radius: 8px;
  padding: 15px;
  margin: 10px 0;
}

.test-result.success {
  background: var(--success-background, #e8f5e8);
  border: 1px solid var(--success-color, #4caf50);
}

.test-result.error {
  background: var(--error-background, #ffebee);
  border: 1px solid var(--error-color, #f44336);
}

.asset-item {
  display: inline-block;
  background: var(--tag-background, #e0e0e0);
  padding: 4px 8px;
  margin: 2px;
  border-radius: 12px;
  font-size: 0.8em;
}
`;

// Adicionar CSS dinamicamente
const style = document.createElement('style');
style.textContent = additionalCSS;
document.head.appendChild(style);
