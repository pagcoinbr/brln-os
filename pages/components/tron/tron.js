// TRON Gas-Free Wallet JavaScript
const API_BASE = '/api/v1/tron';

// Global state
let walletAddress = null;
let isLoadingBalance = false;
let isLoadingHistory = false;

// Initialize page
document.addEventListener('DOMContentLoaded', function() {
  console.log('Initializing TRON Gas-Free Wallet...');
  initWallet();
});

// Initialize wallet and load data
async function initWallet() {
  try {
    await loadWalletAddress();
    await refreshBalance();
    await refreshHistory();
    console.log('TRON wallet initialized successfully');
  } catch (error) {
    console.error('Error initializing wallet:', error);
    showMessage('Error initializing wallet: ' + error.message, 'error');
  }
}

// Load wallet address
async function loadWalletAddress() {
  try {
    const response = await fetch(`${API_BASE}/wallet/address`);
    const data = await response.json();
    
    if (data.status === 'success') {
      walletAddress = data.address;
      document.getElementById('walletAddress').textContent = walletAddress;
      generateQR(walletAddress);
    } else {
      // Wallet not configured - show initialization button
      document.getElementById('walletAddress').innerHTML = 
        '<button onclick="showInitializeWallet()" class="action-btn" style="margin: 10px 0;">🔧 Initialize TRON Wallet</button>';
      throw new Error(data.message || 'Failed to load wallet address');
    }
  } catch (error) {
    console.error('Error loading wallet address:', error);
    document.getElementById('walletAddress').innerHTML = 
      '<button onclick="showInitializeWallet()" class="action-btn" style="margin: 10px 0;">🔧 Initialize TRON Wallet</button>';
    throw error;
  }
}

// Generate QR Code
function generateQR(address) {
  try {
    const canvas = document.getElementById('qrCode');
    const qr = new QRious({
      element: canvas,
      value: address,
      size: 200,
      level: 'H'
    });
  } catch (error) {
    console.error('Error generating QR code:', error);
  }
}

// Copy address to clipboard
function copyAddress() {
  const address = document.getElementById('walletAddress').textContent;
  navigator.clipboard.writeText(address).then(() => {
    showMessage('Address copied to clipboard!', 'success');
  }).catch(err => {
    console.error('Failed to copy:', err);
    showMessage('Failed to copy address', 'error');
  });
}

// Refresh balance
async function refreshBalance() {
  if (isLoadingBalance) return;
  
  isLoadingBalance = true;
  try {
    const response = await fetch(`${API_BASE}/wallet/balance`);
    const data = await response.json();
    
    if (data.status === 'success') {
      document.getElementById('usdtBalance').textContent = parseFloat(data.usdt_balance).toFixed(6);
      console.log('Balance updated');
    } else {
      throw new Error(data.message || 'Failed to load balance');
    }
  } catch (error) {
    console.error('Error refreshing balance:', error);
    showMessage('Error loading balance: ' + error.message, 'error');
  } finally {
    isLoadingBalance = false;
  }
}

// Send USDT
async function sendUSDT(event) {
  event.preventDefault();
  
  const recipientAddress = document.getElementById('recipientAddress').value.trim();
  const amount = parseFloat(document.getElementById('amount').value);
  const password = document.getElementById('password').value;
  
  // Validate inputs
  if (!recipientAddress || !recipientAddress.match(/^T[A-Za-z1-9]{33}$/)) {
    showMessage('Invalid recipient address', 'error');
    return;
  }
  
  if (isNaN(amount) || amount < 1.01) {
    showMessage('Minimum amount is 1.01 USDT (1 USDT fee + 0.01 USDT transfer)', 'error');
    return;
  }
  
  if (!password) {
    showMessage('Please enter your wallet password', 'error');
    return;
  }
  
  // Confirm transaction
  const netAmount = (amount - 1).toFixed(6);
  if (!confirm(`Send ${netAmount} USDT to ${recipientAddress}?\n\nFee: 1 USDT\nTotal: ${amount.toFixed(6)} USDT`)) {
    return;
  }
  
  // Disable button
  const sendButton = document.getElementById('sendButton');
  sendButton.disabled = true;
  sendButton.innerHTML = '<div class="service-card"><div class="service-title">Sending...</div></div>';
  
  try {
    const response = await fetch(`${API_BASE}/wallet/send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        to_address: recipientAddress,
        amount: amount,
        password: password
      })
    });
    
    const data = await response.json();
    
    if (data.status === 'success') {
      showMessage(`Transaction sent successfully!\nTxID: ${data.txid}`, 'success');
      
      // Clear form
      document.getElementById('sendForm').reset();
      
      // Refresh balance and history
      setTimeout(() => {
        refreshBalance();
        refreshHistory();
      }, 2000);
    } else {
      throw new Error(data.message || 'Transaction failed');
    }
  } catch (error) {
    console.error('Error sending USDT:', error);
    showMessage('Error sending USDT: ' + error.message, 'error');
  } finally {
    // Re-enable button
    sendButton.disabled = false;
    sendButton.innerHTML = '<div class="service-card"><div class="service-title">Send USDT</div></div>';
  }
}

// Refresh transaction history
async function refreshHistory() {
  if (isLoadingHistory) return;
  
  isLoadingHistory = true;
  const historyContainer = document.getElementById('transactionHistory');
  const header = historyContainer.querySelector('.transaction-header');
  
  // Show loading
  historyContainer.innerHTML = '';
  if (header) historyContainer.appendChild(header);
  historyContainer.innerHTML += '<div class="loading-message">Loading transactions...</div>';
  
  try {
    const response = await fetch(`${API_BASE}/wallet/transactions?limit=30`);
    const data = await response.json();
    
    historyContainer.innerHTML = '';
    if (header) historyContainer.appendChild(header);
    
    if (data.status === 'success' && data.transactions && data.transactions.length > 0) {
      data.transactions.forEach(tx => {
        const txElement = createTransactionElement(tx);
        historyContainer.appendChild(txElement);
      });
    } else {
      historyContainer.innerHTML += '<div class="empty-message">No transactions found</div>';
    }
  } catch (error) {
    console.error('Error loading transaction history:', error);
    historyContainer.innerHTML += '<div class="empty-message">Error loading transactions</div>';
  } finally {
    isLoadingHistory = false;
  }
}

// Create transaction element
function createTransactionElement(tx) {
  const div = document.createElement('div');
  div.className = 'transaction-item';
  
  // Determine if sent or received
  const isSent = tx.from_address && tx.from_address.toLowerCase() === walletAddress.toLowerCase();
  const type = isSent ? 'sent' : 'received';
  const address = isSent ? tx.to_address : tx.from_address;
  const amount = parseFloat(tx.amount);
  
  // Format date
  const date = new Date(tx.timestamp * 1000);
  const dateStr = date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  
  // Status
  let status = 'confirmed';
  let statusText = 'Confirmed';
  if (tx.status === 'pending') {
    status = 'pending';
    statusText = 'Pending';
  } else if (tx.status === 'failed') {
    status = 'failed';
    statusText = 'Failed';
  }
  
  div.innerHTML = `
    <div class="tx-datetime">${dateStr}</div>
    <div class="tx-type ${type}">${type}</div>
    <div class="tx-address" title="${address}">${address}</div>
    <div class="tx-amount ${type}">${isSent ? '-' : '+'}${amount.toFixed(6)}</div>
    <div class="tx-status ${status}">${statusText}</div>
  `;
  
  return div;
}

// Save configuration
async function saveConfig(event) {
  event.preventDefault();
  
  const config = {
    tron_api_url: document.getElementById('tronApiUrl').value.trim(),
    tron_api_key: document.getElementById('tronApiKey').value.trim(),
    gasfree_api_key: document.getElementById('gasfreeApiKey').value.trim(),
    gasfree_api_secret: document.getElementById('gasfreeApiSecret').value.trim(),
    gasfree_endpoint: document.getElementById('gasfreeEndpoint').value.trim(),
    password: document.getElementById('configPassword').value
  };
  
  if (!config.password) {
    showMessage('Please enter your wallet password', 'error');
    return;
  }
  
  try {
    const response = await fetch(`${API_BASE}/config/save`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(config)
    });
    
    const data = await response.json();
    
    if (data.status === 'success') {
      showMessage('Configuration saved successfully!', 'success');
      document.getElementById('configPassword').value = '';
    } else {
      throw new Error(data.message || 'Failed to save configuration');
    }
  } catch (error) {
    console.error('Error saving configuration:', error);
    showMessage('Error saving configuration: ' + error.message, 'error');
  }
}

// Load configuration
async function loadConfig() {
  try {
    const response = await fetch(`${API_BASE}/config/load`);
    const data = await response.json();
    
    if (data.status === 'success' && data.config) {
      const config = data.config;
      
      if (config.tron_api_url) {
        document.getElementById('tronApiUrl').value = config.tron_api_url;
      }
      if (config.tron_api_key) {
        document.getElementById('tronApiKey').value = config.tron_api_key;
      }
      if (config.gasfree_api_key) {
        document.getElementById('gasfreeApiKey').value = config.gasfree_api_key;
      }
      if (config.gasfree_api_secret) {
        document.getElementById('gasfreeApiSecret').value = '••••••••••••';
      }
      if (config.gasfree_endpoint) {
        document.getElementById('gasfreeEndpoint').value = config.gasfree_endpoint;
      }
      
      showMessage('Configuration loaded successfully!', 'success');
    } else {
      showMessage('No saved configuration found', 'info');
    }
  } catch (error) {
    console.error('Error loading configuration:', error);
    showMessage('Error loading configuration: ' + error.message, 'error');
  }
}

// Show message
function showMessage(message, type = 'info') {
  // Remove any existing message
  const existing = document.querySelector('.status-message');
  if (existing) {
    existing.remove();
  }
  
  // Create new message
  const div = document.createElement('div');
  div.className = `status-message ${type}`;
  div.textContent = message;
  document.body.appendChild(div);
  
  // Auto remove after 5 seconds
  setTimeout(() => {
    div.style.animation = 'slideIn 0.3s ease reverse';
    setTimeout(() => div.remove(), 300);
  }, 5000);
}

// Show initialize wallet prompt
function showInitializeWallet() {
  const password = prompt('Enter your wallet password (same as LND unlock password):');
  
  if (!password) {
    showMessage('Password is required to initialize wallet', 'error');
    return;
  }
  
  initializeTronWallet(password);
}

// Initialize TRON wallet from system wallet
async function initializeTronWallet(password) {
  try {
    showMessage('Initializing TRON wallet...', 'info');
    
    const response = await fetch(`${API_BASE}/wallet/initialize`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ password: password })
    });
    
    const data = await response.json();
    
    if (data.status === 'success') {
      showMessage('TRON wallet initialized successfully!', 'success');
      
      // Reload wallet
      setTimeout(() => {
        location.reload();
      }, 2000);
    } else {
      throw new Error(data.message || 'Failed to initialize wallet');
    }
  } catch (error) {
    console.error('Error initializing wallet:', error);
    showMessage('Error initializing wallet: ' + error.message, 'error');
  }
}

// Auto-refresh balance every 30 seconds
setInterval(() => {
  if (!isLoadingBalance) {
    refreshBalance();
  }
}, 30000);

// Auto-refresh history every 60 seconds
setInterval(() => {
  if (!isLoadingHistory) {
    refreshHistory();
  }
}, 60000);
