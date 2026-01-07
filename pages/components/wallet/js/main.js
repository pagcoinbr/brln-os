// Central de Controle Carteira Multichain BRLN-OS
// Usando API backend para operações de carteira seguras

console.log('Main.js loading...');

// Base URL da API (using proxy path)
const API_BASE_URL = '/api/v1';

console.log('API_BASE_URL set to:', API_BASE_URL);

// Variáveis globais para a carteira
let currentWallet = null;
let walletAddresses = {};
let currentWalletId = null;
let currentMnemonicWords = [];
let verificationChallenges = [];

// Event Listeners
document.addEventListener('DOMContentLoaded', function() {
  // Word count selector buttons
  document.querySelectorAll('.word-count-btn').forEach(btn => {
    btn.addEventListener('click', function() {
      document.querySelectorAll('.word-count-btn').forEach(b => b.classList.remove('selected'));
      this.classList.add('selected');
    });
  });
  
  // Check if we should show integrations (accessed from config page)
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('showIntegrations') === 'true') {
    // Try to load and show integrations
    setTimeout(() => {
      showWalletAddressesAndIntegrations();
    }, 500);
  }
  
  // Verification section event listeners
  const backToSeedBtn = document.getElementById('backToSeedBtn');
  const verifyWordsBtn = document.getElementById('verifyWordsBtn');
  const skipVerificationBtn = document.getElementById('skipVerificationBtn');
  
  if (backToSeedBtn) {
    backToSeedBtn.addEventListener('click', function() {
      document.getElementById('verificationSection').style.display = 'none';
      document.getElementById('seedSection').style.display = 'block';
      document.getElementById('seedSection').scrollIntoView({ behavior: 'smooth' });
    });
  }
  
  if (verifyWordsBtn) {
    verifyWordsBtn.addEventListener('click', validateMnemonicWords);
  }
  
  if (skipVerificationBtn) {
    skipVerificationBtn.addEventListener('click', function() {
      // Skip verification and save wallet directly with systemd credentials
      walletService.showNotification('Skipping verification - saving wallet securely...', 'info');
      saveWalletWithSystemdCredentials();
    });
  }
});

// Classe principal do serviço de carteira (API-based)
class WalletService {
  constructor() {
    console.log('WalletService constructor called');
    this.apiBaseUrl = API_BASE_URL;
    console.log('WalletService initialized with API base URL:', this.apiBaseUrl);
  }

  // Fazer requisição para API
  async makeApiRequest(endpoint, options = {}, retryAfterAuth = true) {
    try {
      const url = `${this.apiBaseUrl}${endpoint}`;
      const defaultOptions = {
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include'  // Include cookies for session authentication
      };

      const response = await fetch(url, {
        ...defaultOptions,
        ...options
      });

      const data = await response.json();

      if (!response.ok) {
        // Check if this is an authentication error
        if (response.status === 401 && retryAfterAuth) {
          const errorCode = data.code || '';
          if (errorCode === 'AUTH_REQUIRED' || errorCode === 'SESSION_EXPIRED') {
            console.log('Authentication required, showing modal...');
            // Show authentication modal and wait for result
            const authenticated = await showAuthenticationModal();
            if (authenticated) {
              // Retry the original request (without retry to avoid infinite loop)
              console.log('Authentication successful, retrying request...');
              return this.makeApiRequest(endpoint, options, false);
            } else {
              throw new Error('Authentication cancelled');
            }
          }
        }
        throw new Error(data.error || `API request failed: ${response.status}`);
      }

      return data;
    } catch (error) {
      console.error('API request failed:', error);
      throw error;
    }
  }

  // Gerar nova carteira
  async generateWallet(walletId = null, password = null, wordCount = 12) {
    const requestBody = {};
    if (walletId) requestBody.wallet_id = walletId;
    if (password !== null) requestBody.password = password;
    if (wordCount) requestBody.word_count = wordCount;
    
    const data = await this.makeApiRequest('/wallet/generate', {
      method: 'POST',
      body: JSON.stringify(requestBody)
    });
    return data;
  }

  // Importar carteira existente
  async importWallet(mnemonic, passphrase = '') {
    const data = await this.makeApiRequest('/wallet/import', {
      method: 'POST',
      body: JSON.stringify({
        mnemonic: mnemonic.trim(),
        passphrase
      })
    });
    return data;
  }

  // Validar mnemonic
  async validateMnemonic(mnemonic) {
    const data = await this.makeApiRequest('/wallet/validate', {
      method: 'POST',
      body: JSON.stringify({
        mnemonic: mnemonic.trim()
      })
    });
    return data.valid;
  }

  // Salvar carteira criptografada
  async saveWallet(mnemonic, password, walletId = null, metadata = {}) {
    const data = await this.makeApiRequest('/wallet/save', {
      method: 'POST',
      body: JSON.stringify({
        mnemonic: mnemonic.trim(),
        password,
        wallet_id: walletId,
        metadata
      })
    });
    return data;
  }

  // Carregar carteira
  async loadWallet(walletId, password = null, useSessionAuth = false) {
    const requestBody = {
      wallet_id: walletId,
      // Password can be null if using session authentication
      password: password || '',
      use_session_auth: useSessionAuth
    };
    
    const data = await this.makeApiRequest('/wallet/load', {
      method: 'POST',
      body: JSON.stringify(requestBody)
    });
    return data;
  }

  // Obter endereços de uma carteira
  async getWalletAddresses(walletId) {
    const data = await this.makeApiRequest(`/wallet/addresses/${walletId}`);
    return data;
  }

  // Obter saldo de uma chain
  async getBalance(chainId, address) {
    try {
      const data = await this.makeApiRequest(`/wallet/balance/${chainId}/${address}`);
      return data.balance;
    } catch (error) {
      console.error(`Error getting ${chainId} balance:`, error);
      return '0.00000000';
    }
  }

  // Listar carteiras salvas
  async listSavedWallets() {
    const data = await this.makeApiRequest('/wallet/list');
    return data.wallets || [];
  }

  // Verificar status de uma carteira específica
  async getWalletStatus(walletId) {
    const data = await this.makeApiRequest(`/wallet/status/${walletId}`);
    return data;
  }

  // Mostrar notificação
  showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    document.body.appendChild(notification);
    
    setTimeout(() => {
      notification.remove();
    }, 4000);
  }

  // Integrate wallet with system services (LND and Elements)
  async integrateWallet(walletId, password) {
    const data = await this.makeApiRequest('/wallet/integrate', {
      method: 'POST',
      body: JSON.stringify({
        wallet_id: walletId,
        password: password
      })
    });
    return data;
  }

  // ✅ NEW: Authenticate user with master password
  async authenticate(masterPassword) {
    const data = await this.makeApiRequest('/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        password: masterPassword
      })
    });
    return data;
  }

  // ✅ NEW: Check if user has valid authentication session
  async checkAuthentication() {
    try {
      const data = await this.makeApiRequest('/auth/check');
      return data.authenticated === true;
    } catch (error) {
      return false;
    }
  }

  // ✅ NEW: Logout and clear session
  async logout() {
    try {
      await this.makeApiRequest('/auth/logout', { method: 'POST' });
      return true;
    } catch (error) {
      console.error('Logout failed:', error);
      return false;
    }
  }
}

// Instanciar o serviço de carteira
console.log('Creating walletService instance...');
const walletService = new WalletService();
console.log('WalletService instance created:', walletService);

// Verificar carteiras existentes no sistema
async function checkForExistingWallets() {
  try {
    console.log('Checking for existing wallets...');
    
    // Verificar se há carteiras salvas no localStorage (método antigo)
    const localWallets = JSON.parse(localStorage.getItem('brln_wallets') || '{}');
    const localWalletIds = Object.keys(localWallets);
    
    // Tentar listar carteiras da API (método novo)
    let apiWallets = [];
    try {
      const response = await walletService.listSavedWallets();
      apiWallets = response || [];
    } catch (error) {
      console.log('No API wallet list available:', error.message);
    }
    
    console.log('Local wallets found:', localWalletIds.length);
    console.log('API wallets found:', apiWallets.length);
    
    // Se houver carteiras, mostrar opções de carregamento
    if (localWalletIds.length > 0 || apiWallets.length > 0) {
      showWalletLoadingOptions(localWalletIds, apiWallets);
    } else {
      console.log('No existing wallets found');
      updateWalletStatus('Nenhuma carteira encontrada', 'Gere uma nova carteira ou importe uma existente');
      
      // Mostrar create/import section diretamente
      const walletSelectionSection = document.getElementById('walletSelectionSection');
      const createImportSection = document.getElementById('createImportSection');
      
      if (walletSelectionSection) walletSelectionSection.style.display = 'none';
      if (createImportSection) createImportSection.style.display = 'block';
    }
    
  } catch (error) {
    console.error('Error checking for existing wallets:', error);
    updateWalletStatus('Erro na verificação', 'Não foi possível verificar carteiras existentes');
  }
}

// Mostrar opções de carregamento de carteiras
function showWalletLoadingOptions(localWalletIds, apiWallets) {
  updateWalletStatus('Carteiras encontradas', 'Selecione uma carteira para carregar');
  
  // Mostrar seção de seleção e esconder create/import
  const walletSelectionSection = document.getElementById('walletSelectionSection');
  const createImportSection = document.getElementById('createImportSection');
  const backBtn = document.getElementById('backToSelectionBtn');
  
  if (walletSelectionSection) walletSelectionSection.style.display = 'block';
  if (createImportSection) createImportSection.style.display = 'none';
  if (backBtn) backBtn.style.display = 'inline-block';
  
  // Usar o container de seleção ao invés de walletsSection
  const container = document.getElementById('walletSelectionContainer');
  if (!container) return;
  
  // Limpar container anterior
  container.innerHTML = '';
  
  // Se há carteiras da API, mostrar lista da API
  if (apiWallets.length > 0) {
    showApiWalletsInContainer(apiWallets, container);
  }
  // Se há apenas carteiras locais, mostrar lista local
  else if (localWalletIds.length > 0) {
    showLocalWalletsInContainer(localWalletIds, container);
  }
}

// Mostrar lista de carteiras da API no container
function showApiWalletsInContainer(wallets, container) {
  const walletList = document.createElement('div');
  walletList.className = 'wallet-selection-list';
  walletList.innerHTML = `
    <h3>Carteiras Salvas no Sistema:</h3>
    <div class="wallet-selection-items">
      ${wallets.map(wallet => `
        <div class="wallet-selection-item">
          <div class="wallet-info">
            <div class="wallet-id-display">
              <strong>ID: ${wallet.wallet_id}</strong>
              <span class="wallet-status-badge ${wallet.encrypted ? 'encrypted' : 'unencrypted'}">
                ${wallet.encrypted ? '🔒 Encrypted' : '🔓 Unencrypted'}
              </span>
            </div>
            <small class="wallet-date">Last used: ${new Date(wallet.last_used).toLocaleString()}</small>
          </div>
          <div class="wallet-selection-actions">
            <button class="action-button load-wallet-btn" data-wallet-id="${wallet.wallet_id}" data-encrypted="${wallet.encrypted}">
              ${wallet.encrypted ? '🔐 Load (Password Required)' : '📂 Load Wallet'}
            </button>
          </div>
        </div>
      `).join('')}
    </div>
  `;
  
  container.appendChild(walletList);
  
  // Adicionar event listeners
  walletList.querySelectorAll('.load-wallet-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const walletId = e.target.dataset.walletId;
      const isEncrypted = e.target.dataset.encrypted === 'true';
      
      if (isEncrypted) {
        // Show password modal for encrypted wallets
        showPasswordModal(walletId);
      } else {
        // Load directly for unencrypted wallets with empty password
        console.log(`Loading unencrypted wallet: ${walletId}`);
        loadWalletById(walletId, '');
      }
    });
  });
}

// Mostrar lista de carteiras locais no container
function showLocalWalletsInContainer(walletIds, container) {
  const walletList = document.createElement('div');
  walletList.className = 'wallet-selection-list';
  walletList.innerHTML = `
    <h3>Carteiras Locais Encontradas:</h3>
    <div class="wallet-selection-items">
      ${walletIds.map(id => `
        <div class="wallet-selection-item">
          <div class="wallet-info">
            <div class="wallet-id-display">
              <strong>ID: ${id}</strong>
              <span class="wallet-status-badge encrypted">🔒 Criptografada</span>
            </div>
            <small class="wallet-date">Armazenada localmente</small>
          </div>
          <div class="wallet-selection-actions">
            <button class="action-button load-wallet-btn" data-wallet-id="${id}">
              🔐 Carregar Carteira
            </button>
          </div>
        </div>
      `).join('')}
    </div>
  `;
  
  container.appendChild(walletList);
  
  // Adicionar event listeners
  walletList.querySelectorAll('.load-wallet-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const walletId = e.target.dataset.walletId;
      promptForWalletPassword(walletId, true); // Assumir que carteiras locais são criptografadas
    });
  });
}

// Solicitar senha da carteira
function promptForWalletPassword(walletId, isEncrypted) {
  // Always treat wallets as potentially encrypted and show password modal
  // The API will handle whether password is actually needed
  showPasswordModal(walletId);
}

// Mostrar modal de senha
function showPasswordModal(walletId) {
  const modal = document.getElementById('passwordModal');
  const modalWalletId = document.getElementById('modalWalletId');
  const passwordInput = document.getElementById('modalPassword');
  const confirmBtn = document.getElementById('confirmPasswordBtn');
  const cancelBtn = document.getElementById('cancelPasswordBtn');
  
  // Set wallet ID in modal
  if (modalWalletId) {
    modalWalletId.textContent = walletId;
  }
  
  // Clear previous password
  if (passwordInput) {
    passwordInput.value = '';
    passwordInput.focus();
  }
  
  // Show modal
  if (modal) {
    modal.style.display = 'flex';
  }
  
  // Handle confirm button
  const handleConfirm = () => {
    const password = passwordInput.value.trim();
    hidePasswordModal();
    
    if (password) {
      console.log(`Loading wallet: ${walletId} with password`);
      loadWalletById(walletId, password);
    } else {
      console.log(`Loading wallet: ${walletId} without password`);
      loadWalletById(walletId, null);
    }
  };
  
  // Handle cancel button
  const handleCancel = () => {
    hidePasswordModal();
    walletService.showNotification('Wallet loading cancelled', 'info');
  };
  
  // Handle Enter key
  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      handleConfirm();
    } else if (e.key === 'Escape') {
      handleCancel();
    }
  };
  
  // Remove old event listeners
  confirmBtn.replaceWith(confirmBtn.cloneNode(true));
  cancelBtn.replaceWith(cancelBtn.cloneNode(true));
  passwordInput.removeEventListener('keypress', handleKeyPress);
  
  // Add new event listeners
  const newConfirmBtn = document.getElementById('confirmPasswordBtn');
  const newCancelBtn = document.getElementById('cancelPasswordBtn');
  
  newConfirmBtn.addEventListener('click', handleConfirm);
  newCancelBtn.addEventListener('click', handleCancel);
  passwordInput.addEventListener('keypress', handleKeyPress);
}

// Esconder modal de senha
function hidePasswordModal() {
  const modal = document.getElementById('passwordModal');
  if (modal) {
    modal.style.display = 'none';
  }
}

// ✅ Show authentication modal - uses global modal from parent window
async function showAuthenticationModal() {
  // Try to use the global modal from parent window (main.html)
  // This provides a consistent authentication experience across all pages
  try {
    if (window.parent && window.parent !== window && window.parent.showGlobalAuthModal) {
      console.log('Using global authentication modal from parent window');
      return await window.parent.showGlobalAuthModal();
    }
  } catch (e) {
    // Cross-origin or other error, fall back to local modal
    console.log('Cannot access parent modal, using local fallback:', e.message);
  }

  // Fallback: Local modal if not in iframe or parent modal unavailable
  return new Promise((resolve, reject) => {
    let authModal = document.getElementById('authenticationModal');

    if (!authModal) {
      authModal = document.createElement('div');
      authModal.id = 'authenticationModal';
      authModal.className = 'modal';
      authModal.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.85);
        display: flex;
        justify-content: center;
        align-items: center;
        z-index: 99999;
        font-family: Arial, sans-serif;
      `;
      authModal.innerHTML = `
        <div class="modal-content" style="
          background: linear-gradient(145deg, #1a1a2e, #16213e);
          border-radius: 16px;
          padding: 40px;
          max-width: 420px;
          width: 90%;
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.6);
          text-align: center;
        ">
          <div style="font-size: 48px; margin-bottom: 20px;">🔐</div>
          <h3 style="color: #fff; font-size: 24px; margin-bottom: 10px;">Autenticação Necessária</h3>
          <p style="color: #a0a0a0; font-size: 14px; margin-bottom: 25px;">
            Digite sua senha mestre do BRLN-OS para continuar.
          </p>
          <input
            type="password"
            id="authMasterPassword"
            placeholder="Senha mestre"
            autocomplete="current-password"
            style="
              width: 100%;
              padding: 14px 18px;
              border: 2px solid #333;
              border-radius: 10px;
              background: #0d0d1a;
              color: #fff;
              font-size: 16px;
              margin-bottom: 15px;
              box-sizing: border-box;
            "
          />
          <div id="authErrorMessage" style="color: #ff6b6b; font-size: 13px; margin-bottom: 15px; display: none;"></div>
          <div style="display: flex; gap: 12px;">
            <button id="authConfirmBtn" style="
              flex: 1;
              padding: 14px 20px;
              border: none;
              border-radius: 10px;
              font-size: 15px;
              font-weight: 600;
              cursor: pointer;
              background: linear-gradient(135deg, #007bff, #0056b3);
              color: white;
            ">Autenticar</button>
            <button id="authCancelBtn" style="
              flex: 1;
              padding: 14px 20px;
              border: none;
              border-radius: 10px;
              font-size: 15px;
              font-weight: 600;
              cursor: pointer;
              background: #2a2a3a;
              color: #ccc;
            ">Cancelar</button>
          </div>
        </div>
      `;
      document.body.appendChild(authModal);
    }

    const passwordInput = document.getElementById('authMasterPassword');
    const confirmBtn = document.getElementById('authConfirmBtn');
    const cancelBtn = document.getElementById('authCancelBtn');
    const errorMessage = document.getElementById('authErrorMessage');

    passwordInput.value = '';
    errorMessage.style.display = 'none';

    authModal.style.display = 'flex';
    setTimeout(() => passwordInput.focus(), 100);

    const handleConfirm = async () => {
      const password = passwordInput.value.trim();

      if (!password) {
        errorMessage.textContent = 'Senha é obrigatória';
        errorMessage.style.display = 'block';
        return;
      }

      try {
        confirmBtn.disabled = true;
        confirmBtn.textContent = 'Autenticando...';

        const result = await walletService.authenticate(password);

        if (result && result.success) {
          walletService.showNotification('Autenticação realizada com sucesso', 'success');
          authModal.style.display = 'none';
          passwordInput.value = '';
          resolve(true);
        } else {
          throw new Error(result.error || 'Falha na autenticação');
        }
      } catch (error) {
        console.error('Authentication error:', error);
        errorMessage.textContent = 'Senha incorreta. Tente novamente.';
        errorMessage.style.display = 'block';
        passwordInput.select();
      } finally {
        confirmBtn.disabled = false;
        confirmBtn.textContent = 'Autenticar';
      }
    };

    const handleCancel = () => {
      authModal.style.display = 'none';
      passwordInput.value = '';
      resolve(false);
    };

    const handleKeyPress = (e) => {
      if (e.key === 'Enter') {
        handleConfirm();
      } else if (e.key === 'Escape') {
        handleCancel();
      }
    };

    confirmBtn.replaceWith(confirmBtn.cloneNode(true));
    cancelBtn.replaceWith(cancelBtn.cloneNode(true));
    passwordInput.removeEventListener('keypress', handleKeyPress);

    const newConfirmBtn = document.getElementById('authConfirmBtn');
    const newCancelBtn = document.getElementById('authCancelBtn');

    newConfirmBtn.addEventListener('click', handleConfirm);
    newCancelBtn.addEventListener('click', handleCancel);
    passwordInput.addEventListener('keypress', handleKeyPress);
  });
}


// Carregar carteira por ID
async function loadWalletById(walletId, password) {
  try {
    showLoading(true);
    console.log(`Loading wallet ${walletId} with password: ${password ? '[PROVIDED]' : '[EMPTY]'}...`);
    
    // Tentar carregar da API primeiro
    let result = null;
    try {
      // For unencrypted wallets, we need to send empty string password
      // For encrypted wallets, we send the provided password
      result = await walletService.loadWallet(walletId, password || '');
      console.log('Wallet loaded from API:', result);
    } catch (error) {
      console.log('API load failed:', error.message);
      
      // Se o erro indica que é necessária senha e não foi fornecida, mostrar modal
      if (error.message.includes('password') || error.message.includes('required')) {
        if (!password || password.trim() === '') {
          // First attempt without password failed, ask for password
          walletService.showNotification('This wallet requires a password. Please enter it.', 'warning');
          setTimeout(() => showPasswordModal(walletId), 500);
          return;
        } else {
          // Password was provided but incorrect
          walletService.showNotification('Incorrect password. Please try again.', 'error');
          setTimeout(() => showPasswordModal(walletId), 500);
          return;
        }
      }
      
      // For other errors, throw them
      throw error;
    }
    
    if (result && result.addresses) {
      // Armazenar dados da carteira atual (including all data needed for integrations)
      currentWallet = {
        mnemonic: result.mnemonic || '[PROTEGIDO]',
        addresses: result.addresses || {},
        private_keys: result.private_keys || {},
        lnd_keys: result.lnd_keys || {},
        walletId: walletId,
        wallet_id: walletId,
        wordCount: result.word_count || 12,
        lnd_compatible: result.lnd_compatible || false,
        supported_chains: result.supported_chains || []
      };
      currentWalletId = walletId;
      
      // Mostrar endereços
      showAddresses(result.addresses);
      
      walletService.showNotification('Wallet loaded successfully!', 'success');
      
      // Limpar lista de carteiras se existir
      const walletList = document.querySelector('.wallet-list');
      if (walletList) {
        walletList.remove();
      }
      
    } else {
      throw new Error('Dados da carteira inválidos');
    }
    
  } catch (error) {
    console.error('Error loading wallet:', error);
    walletService.showNotification('Erro ao carregar carteira: ' + error.message, 'error');
  } finally {
    showLoading(false);
  }
}

// Atualizar status da carteira na interface
function updateWalletStatus(title, info) {
  const walletStatusCard = document.querySelector('.wallet-status');
  const titleElement = walletStatusCard?.querySelector('.service-title');
  const infoElement = walletStatusCard?.querySelector('.service-info');
  
  if (titleElement) titleElement.textContent = title;
  if (infoElement) infoElement.textContent = info;
  
  // Atualizar classe do status
  if (walletStatusCard) {
    if (title.includes('carregada') || title.includes('ativa')) {
      walletStatusCard.classList.add('active');
    } else {
      walletStatusCard.classList.remove('active');
    }
  }
}

// Funções de Gerenciamento de Carteira

// Gerar nova carteira
async function generateNewWallet() {
  try {
    console.log('Generate wallet button clicked');
    showLoading(true);
    
    // Get parameters from form
    const wordCount = parseInt(document.getElementById('wordCount').value) || 12;
    const password = document.getElementById('generatePassword').value.trim();
    const walletId = document.getElementById('generateWalletId').value.trim();
    
    // Usar API para gerar carteira universal
    console.log(`Calling API to generate ${wordCount}-word universal wallet...`);
    const result = await walletService.generateWallet(walletId || null, password || null, wordCount);
    console.log('API response:', result);
    
    if (result && result.mnemonic) {
      console.log('Universal wallet generated successfully, displaying mnemonic...');
      // Store the generated data globally for verification
      currentWallet = {
        mnemonic: result.mnemonic,
        addresses: result.addresses || {},
        private_keys: result.private_keys || {},
        lnd_keys: result.lnd_keys || {},
        walletId: result.wallet_id,
        wordCount: wordCount,
        bip39Passphrase: password,  // This is the BIP39 passphrase (13th/25th word)
        lnd_compatible: result.lnd_compatible || false,
        supported_chains: result.supported_chains || []
      };
      currentWalletId = result.wallet_id;
      
      // Show only mnemonic for user to save
      showMnemonic(result.mnemonic);
      
      // Clear form fields
      document.getElementById('wordCount').value = '12';
      document.getElementById('generatePassword').value = '';
      document.getElementById('generateWalletId').value = '';
      
      const chainCount = result.supported_chains ? result.supported_chains.length : 0;
      const lndStatus = result.lnd_compatible ? ' + LND Compatible' : '';
      const message = password ? 
        `New encrypted ${wordCount}-word universal wallet generated successfully! Supports ${chainCount} chains${lndStatus}. ID: ${result.wallet_id}` : 
        `New ${wordCount}-word universal wallet generated successfully! Supports ${chainCount} chains${lndStatus}. Remember to encrypt it for security.`;
      
      walletService.showNotification(message, 'success');
    } else {
      throw new Error('Resposta inválida da API');
    }
    
  } catch (error) {
    console.error('Error generating wallet:', error);
    walletService.showNotification('Erro ao gerar carteira: ' + error.message, 'error');
  } finally {
    showLoading(false);
  }
}

// Importar carteira existente
async function importExistingWallet() {
  const mnemonic = document.getElementById('importMnemonic').value.trim();
  const passphrase = document.getElementById('importPassphrase').value || '';
  const password = document.getElementById('importPassword').value.trim();
  const walletId = document.getElementById('importWalletId').value.trim();
  
  if (!mnemonic) {
    walletService.showNotification('Por favor, insira o mnemônico', 'warning');
    return;
  }
  
  try {
    showLoading(true);
    
    // Validar mnemônico usando API
    const isValid = await walletService.validateMnemonic(mnemonic);
    if (!isValid) {
      throw new Error('Mnemônico inválido');
    }
    
    // Importar carteira usando API
    const result = await walletService.importWallet(mnemonic, passphrase);
    
    if (result && result.status === 'success' && result.addresses) {
      let savedWalletId = walletId;
      
      // If password provided, save encrypted wallet
      if (password) {
        try {
          const saveResult = await walletService.saveWallet(mnemonic, password, walletId);
          if (saveResult && saveResult.wallet_id) {
            savedWalletId = saveResult.wallet_id;
          }
        } catch (saveError) {
          console.warn('Failed to save encrypted wallet:', saveError);
          walletService.showNotification('Wallet imported but encryption failed', 'warning');
        }
      }
      
      // Generate a temporary wallet ID if none provided/saved
      if (!savedWalletId) {
        savedWalletId = `imported_${Date.now()}`;
      }
      
      // Armazenar dados da carteira atual
      currentWallet = {
        mnemonic: mnemonic,
        addresses: result.addresses,
        walletId: savedWalletId
      };
      currentWalletId = savedWalletId;
      
      // Mostrar endereços
      showAddresses(result.addresses);
      
      // Limpar campos
      document.getElementById('importMnemonic').value = '';
      document.getElementById('importPassphrase').value = '';
      document.getElementById('importPassword').value = '';
      document.getElementById('importWalletId').value = '';
      
      const message = password ? 
        `Wallet imported and encrypted successfully! ID: ${savedWalletId}` : 
        'Wallet imported successfully! Remember to encrypt it for security.';
      
      walletService.showNotification(message, 'success');
      
      // Notify parent window that wallet is configured
      notifyWalletConfigured(savedWalletId);
    } else {
      throw new Error('Resposta inválida da API');
    }
    
  } catch (error) {
    console.error('Error importing wallet:', error);
    walletService.showNotification('Erro ao importar carteira: ' + error.message, 'error');
  } finally {
    showLoading(false);
  }
}

// Salvar carteira com senha
async function saveWalletWithPassword() {
  if (!currentWallet || !currentWallet.mnemonic) {
    walletService.showNotification('Nenhuma carteira para salvar', 'warning');
    return;
  }
  
  const password = document.getElementById('save-password').value;
  const confirmPassword = document.getElementById('confirm-password').value;
  
  if (!password) {
    walletService.showNotification('Por favor, insira uma senha', 'warning');
    return;
  }
  
  if (password !== confirmPassword) {
    walletService.showNotification('Senhas não coincidem', 'warning');
    return;
  }
  
  if (password.length < 8) {
    walletService.showNotification('Senha deve ter pelo menos 8 caracteres', 'warning');
    return;
  }
  
  try {
    showLoading(true);
    
    // Salvar carteira usando API
    const result = await walletService.saveWallet(
      currentWallet.mnemonic, 
      password, 
      currentWalletId
    );
    
    if (result && result.wallet_id) {
      currentWalletId = result.wallet_id;
      
      // Limpar campos de senha
      document.getElementById('save-password').value = '';
      document.getElementById('confirm-password').value = '';
      
      walletService.showNotification(`Carteira salva com ID: ${result.wallet_id}`, 'success');
      
      // Notify parent window that wallet is configured
      notifyWalletConfigured(result.wallet_id);
    } else {
      throw new Error('Resposta inválida da API');
    }
    
  } catch (error) {
    console.error('Error saving wallet:', error);
    walletService.showNotification('Erro ao salvar carteira: ' + error.message, 'error');
  } finally {
    showLoading(false);
  }
}

// Carregar carteira existente
async function loadExistingWallet() {
  const walletId = document.getElementById('load-wallet-id').value.trim();
  const password = document.getElementById('load-password').value;
  
  if (!walletId || !password) {
    walletService.showNotification('Por favor, insira o ID da carteira e a senha', 'warning');
    return;
  }
  
  try {
    showLoading(true);
    
    // Carregar carteira usando API
    const result = await walletService.loadWallet(walletId, password);
    
    if (result && result.mnemonic) {
      // Obter endereços da carteira
      const addresses = await walletService.getWalletAddresses(walletId);
      
      // Armazenar dados da carteira atual
      currentWallet = {
        mnemonic: result.mnemonic,
        addresses: addresses,
        walletId: walletId
      };
      currentWalletId = walletId;
      
      // Mostrar endereços
      showAddresses(addresses);
      
      // Limpar campos
      document.getElementById('load-wallet-id').value = '';
      document.getElementById('load-password').value = '';
      
      walletService.showNotification('Carteira carregada com sucesso!', 'success');
      
      // Notify parent window that wallet is configured
      notifyWalletConfigured(currentWalletId);
      
      // Atualizar saldos
      setTimeout(() => updateAllBalances(), 1000);
    } else {
      throw new Error('Dados da carteira inválidos');
    }
    
  } catch (error) {
    console.error('Error loading wallet:', error);
    walletService.showNotification('Erro ao carregar carteira: ' + error.message, 'error');
  } finally {
    showLoading(false);
  }
}

// Confirmar seed phrase e continuar
function confirmSeed() {
  const seedSection = document.getElementById('seedSection');
  const verificationSection = document.getElementById('verificationSection');
  
  if (seedSection) {
    seedSection.style.display = 'none';
  }
  
  if (verificationSection) {
    verificationSection.style.display = 'block';
    verificationSection.scrollIntoView({ behavior: 'smooth' });
  }
  
  // Generate verification challenges
  generateVerificationChallenges();
  
  walletService.showNotification('Please verify your seed phrase to continue', 'info');
}





// Funções de Verificação de Mnemônico

// Generate verification challenges for mnemonic confirmation
function generateVerificationChallenges() {
  if (!currentWallet || !currentWallet.mnemonic) {
    walletService.showNotification('No mnemonic available for verification', 'error');
    return;
  }
  
  const words = currentWallet.mnemonic.split(' ');
  const totalWords = words.length;
  const challengeCount = Math.ceil(totalWords / 4); // 1/4 of words as specified
  
  // Store the words for later validation
  currentMnemonicWords = words;
  
  // Generate random positions for challenges
  const challengePositions = [];
  while (challengePositions.length < challengeCount) {
    const randomIndex = Math.floor(Math.random() * totalWords);
    if (!challengePositions.includes(randomIndex)) {
      challengePositions.push(randomIndex);
    }
  }
  
  // Sort positions in ascending order
  challengePositions.sort((a, b) => a - b);
  
  // Store challenges globally
  verificationChallenges = challengePositions.map(position => ({
    position: position + 1, // 1-based indexing for display
    index: position,       // 0-based indexing for validation
    expectedWord: words[position]
  }));
  
  // Generate the verification UI
  generateVerificationUI(verificationChallenges);
}

// Generate verification UI elements
function generateVerificationUI(challenges) {
  const challengeContainer = document.getElementById('verificationContainer');
  
  if (!challengeContainer) {
    walletService.showNotification('Verification UI container not found', 'error');
    return;
  }
  
  // Clear existing challenges
  challengeContainer.innerHTML = '';
  
  challenges.forEach((challenge, index) => {
    const challengeElement = document.createElement('div');
    challengeElement.className = 'verification-challenge';
    challengeElement.innerHTML = `
      <label for="word-${challenge.position}">
        Word #${challenge.position}:
      </label>
      <input 
        type="text" 
        id="word-${challenge.position}" 
        class="verification-input" 
        placeholder="Enter word ${challenge.position}"
        data-position="${challenge.position}"
        data-index="${challenge.index}"
        autocomplete="off"
        spellcheck="false"
      />
    `;
    challengeContainer.appendChild(challengeElement);
  });
  
  // Focus on first input
  const firstInput = challengeContainer.querySelector('.verification-input');
  if (firstInput) {
    setTimeout(() => firstInput.focus(), 100);
  }
}

// Validate mnemonic words entered by user
function validateMnemonicWords() {
  if (!verificationChallenges || verificationChallenges.length === 0) {
    walletService.showNotification('No verification challenges available', 'error');
    return;
  }
  
  let allCorrect = true;
  const incorrectWords = [];
  
  // Validate each challenge
  verificationChallenges.forEach(challenge => {
    const input = document.getElementById(`word-${challenge.position}`);
    if (!input) {
      allCorrect = false;
      return;
    }
    
    const userWord = input.value.trim().toLowerCase();
    const expectedWord = challenge.expectedWord.toLowerCase();
    
    // Remove any previous error styling
    input.classList.remove('error', 'success');
    
    if (userWord !== expectedWord) {
      allCorrect = false;
      incorrectWords.push({
        position: challenge.position,
        entered: userWord,
        expected: expectedWord
      });
      input.classList.add('error');
    } else {
      input.classList.add('success');
    }
  });
  
  if (allCorrect) {
    walletService.showNotification('Mnemonic verification successful! Saving wallet securely...', 'success');
    
    // Save wallet directly using systemd credentials (no password prompt needed)
    saveWalletWithSystemdCredentials();
    
    // Clear verification data for security
    setTimeout(() => {
      const inputs = document.querySelectorAll('.verification-input');
      inputs.forEach(input => {
        input.value = '';
        input.classList.remove('error', 'success');
      });
    }, 2000);
    
  } else {
    // Show specific error messages
    const errorMsg = incorrectWords.length === 1 
      ? `Incorrect word at position ${incorrectWords[0].position}. Please try again.`
      : `Incorrect words at positions: ${incorrectWords.map(w => w.position).join(', ')}. Please try again.`;
    
    walletService.showNotification(errorMsg, 'error');
    
    // Focus on first incorrect input
    const firstErrorInput = document.querySelector('.verification-input.error');
    if (firstErrorInput) {
      firstErrorInput.focus();
      firstErrorInput.select();
    }
  }
}

// Save wallet - uses authenticated session for encryption
async function saveWalletWithSystemdCredentials() {
  if (!currentWallet || !currentWallet.mnemonic) {
    walletService.showNotification('No wallet data to save', 'error');
    return;
  }
  
  // Check if user is authenticated (has valid session)
  const isAuthenticated = await walletService.checkAuthentication();
  
  if (!isAuthenticated) {
    // User needs to authenticate first
    walletService.showNotification('Please authenticate to save wallet securely', 'info');
    await showAuthenticationModal();
    
    // Check again after authentication
    const authenticated = await walletService.checkAuthentication();
    if (!authenticated) {
      walletService.showNotification('Authentication required to save wallet', 'warning');
      return;
    }
  }
  
  try {
    showLoading(true);
    
    // Save wallet using API - backend uses session password for encryption
    const metadata = {
      wordCount: currentWallet.wordCount,
      hasBip39Passphrase: !!currentWallet.bip39Passphrase,
      createdAt: new Date().toISOString(),
      useSessionAuth: true  // ✅ Use authenticated session for encryption
    };
    
    // ✅ NO PASSWORD SENT - backend retrieves from encrypted session
    const result = await walletService.saveWallet(
      currentWallet.mnemonic, 
      null,  // ✅ Password retrieved from session server-side
      currentWalletId,
      metadata
    );
    
    if (result && result.wallet_id) {
      currentWalletId = result.wallet_id;
      
      walletService.showNotification(`Wallet saved securely using session authentication`, 'success');
      
      // Notify parent window and set as system default
      notifyWalletConfigured(currentWalletId);
      
      // Redirect to home after short delay
      setTimeout(() => {
        // If in iframe, notify parent to navigate
        if (window.parent && window.parent !== window) {
          window.parent.postMessage({
            type: 'NAVIGATE_TO_HOME',
            timestamp: new Date().toISOString()
          }, '*');
        } else {
          // Direct navigation if not in iframe
          window.location.href = '/pages/home/index.html';
        }
      }, 2000);
    } else {
      throw new Error('Invalid response from API');
    }
    
  } catch (error) {
    console.error('Error saving wallet:', error);
    
    // Check if error is due to expired session
    if (error.message.includes('session') || error.message.includes('authentication')) {
      walletService.showNotification('Session expired. Please authenticate again.', 'warning');
      await showAuthenticationModal();
      // Retry saving after re-authentication
      return saveWalletWithSystemdCredentials();
    }
    
    walletService.showNotification('Error saving wallet: ' + error.message, 'error');
  } finally {
    showLoading(false);
  }
}



// Funções de Interface do Usuário

// Mostrar indicador de carregamento
function showLoading(show) {
  const loadingElement = document.querySelector('.loading');
  if (loadingElement) {
    loadingElement.style.display = show ? 'block' : 'none';
  }
  
  // Desabilitar/habilitar botões durante carregamento
  const buttons = document.querySelectorAll('button');
  buttons.forEach(button => {
    button.disabled = show;
  });
}

// Exibir mnemônico gerado
function showMnemonic(mnemonic) {
  const seedSection = document.getElementById('seedSection');
  const seedDisplay = document.getElementById('seedDisplay');
  
  if (seedSection && seedDisplay) {
    // Create seed words display
    const words = mnemonic.split(' ');
    seedDisplay.innerHTML = '';
    
    words.forEach((word, index) => {
      const wordElement = document.createElement('span');
      wordElement.className = 'seed-word';
      wordElement.innerHTML = `<span class="word-number">${index + 1}</span>${word}`;
      seedDisplay.appendChild(wordElement);
    });
    
    seedSection.style.display = 'block';
    
    // Scroll até a seção
    seedSection.scrollIntoView({ behavior: 'smooth' });
  }
}

// Show wallet addresses and integrations (called from config page)
async function showWalletAddressesAndIntegrations() {
  if (!currentWallet || !currentWallet.addresses) {
    walletService.showNotification('No wallet loaded. Please load a wallet first.', 'warning');
    return;
  }
  
  console.log('Displaying wallet addresses and integrations:', currentWallet);
  
  // Show universal wallet info section
  const universalWalletInfo = document.getElementById('universalWalletInfo');
  if (universalWalletInfo) {
    universalWalletInfo.style.display = 'block';
    universalWalletInfo.scrollIntoView({ behavior: 'smooth' });
    
    // Display chain addresses
    displayChainAddresses(currentWallet.addresses);
    
    // Display LND configuration
    displayLNDConfiguration(currentWallet.lnd_keys);
    
    // Display Elements/Liquid configuration
    displayElementsConfiguration(currentWallet.addresses);
    
    // Display TRON configuration
    displayTronConfiguration(currentWallet.addresses);
    
    // Setup event listeners for universal wallet actions
    setupUniversalWalletEventListeners();
  }
}

// Show universal wallet information (kept for compatibility)
function showUniversalWallet(walletData) {
  console.log('Displaying universal wallet:', walletData);
  
  // First show the seed phrase
  showMnemonic(walletData.mnemonic);
  
  // Show universal wallet info section
  const universalWalletInfo = document.getElementById('universalWalletInfo');
  if (universalWalletInfo) {
    universalWalletInfo.style.display = 'block';
    
    // Display chain addresses
    displayChainAddresses(walletData.addresses);
    
    // Display LND configuration
    displayLNDConfiguration(walletData.lnd_keys);
    
    // Display Elements/Liquid configuration
    displayElementsConfiguration(walletData.addresses);
    
    // Display TRON configuration
    displayTronConfiguration(walletData.addresses);
    
    // Setup event listeners for universal wallet actions
    setupUniversalWalletEventListeners();
  }
}

// Display addresses for all supported chains
function displayChainAddresses(addresses) {
  const chainAddressesList = document.getElementById('chainAddressesList');
  if (!chainAddressesList || !addresses) return;
  
  chainAddressesList.innerHTML = '';
  
  // Chain icons mapping
  const chainIcons = {
    'bitcoin': '₿',
    'ethereum': 'Ξ',
    'liquid': '💧',
    'tron': '⚡',
    'solana': '◎'
  };
  
  Object.entries(addresses).forEach(([chainId, addressData]) => {
    if (addressData.address) {
      const addressItem = document.createElement('div');
      addressItem.className = 'address-item';
      
      addressItem.innerHTML = `
        <div class="address-info">
          <div class="chain-name">
            <span class="chain-icon">${chainIcons[chainId] || '🔗'}</span>
            ${addressData.chain || chainId}
            <span class="chain-symbol">${addressData.symbol || chainId.toUpperCase()}</span>
          </div>
          <div class="chain-address" title="${addressData.address}">${addressData.address}</div>
        </div>
        <button class="copy-address-btn" onclick="copyAddress('${addressData.address}', '${chainId}')">
          📋 Copy
        </button>
      `;
      
      chainAddressesList.appendChild(addressItem);
    }
  });
}

// Display LND configuration options
async function displayLNDConfiguration(lndKeys) {
  const lndExtendedKey = document.getElementById('lndExtendedKey');
  
  if (!lndExtendedKey || !lndKeys) return;
  
  // Store LND keys globally
  window.currentLNDKeys = lndKeys;
  
  // Get network from system configuration via API
  try {
    const response = await fetch(`${API_BASE_URL}/system/config/network`);
    const data = await response.json();
    const network = data.network || 'mainnet'; // Default to mainnet if not available
    updateLNDKeyDisplay(network);
  } catch (error) {
    console.error('Error fetching network config:', error);
    // Default to mainnet if API call fails
    updateLNDKeyDisplay('mainnet');
  }
}

// Display Elements/Liquid configuration options
function displayElementsConfiguration(addresses) {
  const elementsAddressElement = document.getElementById('elementsAddress');
  
  if (!elementsAddressElement) return;
  
  // Get liquid address from addresses object
  if (addresses && addresses.liquid && addresses.liquid.address) {
    elementsAddressElement.textContent = addresses.liquid.address;
  } else {
    elementsAddressElement.textContent = 'Generate wallet first';
  }
}

// Display TRON configuration options
function displayTronConfiguration(addresses) {
  const tronAddressElement = document.getElementById('tronAddress');
  
  if (!tronAddressElement) return;
  
  // Get TRON address from addresses object
  if (addresses && addresses.tron && addresses.tron.address) {
    tronAddressElement.textContent = addresses.tron.address;
  } else {
    tronAddressElement.textContent = 'Generate wallet first';
  }
}

// Update LND key display based on selected network
function updateLNDKeyDisplay(network) {
  const lndExtendedKey = document.getElementById('lndExtendedKey');
  const lndKeys = window.currentLNDKeys;
  
  if (!lndKeys || !lndExtendedKey) return;
  
  const networkKey = lndKeys[network];
  if (networkKey && networkKey.extended_master_key) {
    lndExtendedKey.textContent = networkKey.extended_master_key;
  } else {
    lndExtendedKey.textContent = 'Key not available for this network';
  }
}

// Setup event listeners for universal wallet functionality
function setupUniversalWalletEventListeners() {
  // Copy LND key button
  const copyLndKeyBtn = document.getElementById('copyLndKeyBtn');
  if (copyLndKeyBtn) {
    copyLndKeyBtn.addEventListener('click', copyLNDKey);
  }
  
  // Auto-configure LND button
  const autoConfigureLndBtn = document.getElementById('autoConfigureLndBtn');
  if (autoConfigureLndBtn) {
    autoConfigureLndBtn.addEventListener('click', autoConfigureLND);
  }
  
  // Copy Elements address button
  const copyElementsAddressBtn = document.getElementById('copyElementsAddressBtn');
  if (copyElementsAddressBtn) {
    copyElementsAddressBtn.addEventListener('click', copyElementsAddress);
  }
  
  // Auto-configure Elements button
  const autoConfigureElementsBtn = document.getElementById('autoConfigureElementsBtn');
  if (autoConfigureElementsBtn) {
    autoConfigureElementsBtn.addEventListener('click', autoConfigureElements);
  }
  
  // Copy TRON address button
  const copyTronAddressBtn = document.getElementById('copyTronAddressBtn');
  if (copyTronAddressBtn) {
    copyTronAddressBtn.addEventListener('click', copyTronAddress);
  }
  
  // Auto-configure TRON button
  const autoConfigureTronBtn = document.getElementById('autoConfigureTronBtn');
  if (autoConfigureTronBtn) {
    autoConfigureTronBtn.addEventListener('click', autoConfigureTron);
  }
}

// Copy address to clipboard
function copyAddress(address, chainId) {
  navigator.clipboard.writeText(address).then(() => {
    walletService.showNotification(`${chainId.toUpperCase()} address copied!`, 'success');
    
    // Visual feedback
    const buttons = document.querySelectorAll('.copy-address-btn');
    buttons.forEach(btn => {
      if (btn.onclick && btn.onclick.toString().includes(address)) {
        btn.classList.add('copied');
        btn.textContent = '✅ Copied';
        setTimeout(() => {
          btn.classList.remove('copied');
          btn.textContent = '📋 Copy';
        }, 2000);
      }
    });
  }).catch(error => {
    console.error('Error copying address:', error);
    walletService.showNotification('Error copying address', 'error');
  });
}

// Copy LND extended master key
function copyLNDKey() {
  const lndExtendedKey = document.getElementById('lndExtendedKey');
  const copyBtn = document.getElementById('copyLndKeyBtn');
  
  if (!lndExtendedKey) return;
  
  const keyText = lndExtendedKey.textContent;
  if (keyText && keyText !== 'Key not available for this network') {
    navigator.clipboard.writeText(keyText).then(() => {
      walletService.showNotification('LND extended key copied!', 'success');
      
      // Visual feedback
      copyBtn.classList.add('copied');
      copyBtn.textContent = '✅';
      setTimeout(() => {
        copyBtn.classList.remove('copied');
        copyBtn.textContent = '📋';
      }, 2000);
    }).catch(error => {
      console.error('Error copying LND key:', error);
      walletService.showNotification('Error copying LND key', 'error');
    });
  }
}

// Auto-configure LND with the generated key
async function autoConfigureLND() {
  try {
    const automationStatus = document.getElementById('lndAutomationStatus');
    const statusMessage = document.getElementById('lndStatusMessage');
    const progressBar = document.getElementById('lndProgressBar');
    const autoConfigureBtn = document.getElementById('autoConfigureLndBtn');
    const lndOutputContainer = document.getElementById('lndOutputContainer');
    const lndScriptOutput = document.getElementById('lndScriptOutput');
    
    // Get network from system configuration
    let network = 'mainnet'; // default
    try {
      const response = await fetch(`${API_BASE_URL}/system/config/network`);
      const data = await response.json();
      network = data.network || 'mainnet';
    } catch (error) {
      console.error('Error fetching network config:', error);
    }
    
    const lndKeys = window.currentLNDKeys;
    
    if (!lndKeys || !lndKeys[network]) {
      walletService.showNotification('LND key not available for selected network', 'error');
      return;
    }
    
    // Get or generate LND wallet password from secure password manager
    statusMessage.textContent = 'Retrieving LND wallet password...';
    progressBar.style.width = '10%';
    
    let walletPassword;
    try {
      // Try to get existing password from secure password manager
      const passwordResponse = await fetch(`${API_BASE_URL}/system/passwords/get/lnd_wallet`, {
        method: 'GET',
        headers: {'Content-Type': 'application/json'}
      });
      
      if (passwordResponse.ok) {
        const passwordData = await passwordResponse.json();
        if (passwordData.password) {
          walletPassword = passwordData.password;
          lndScriptOutput.value += '🔐 Retrieved existing LND wallet password from secure storage\n\n';
        }
      }
    } catch (error) {
      console.log('No existing LND password found, will generate new one');
    }
    
    // If no password exists, generate and store a new one
    if (!walletPassword) {
      lndScriptOutput.value += '🔑 Generating new secure LND wallet password...\n';
      
      // Generate a cryptographically secure 24-character password
      const array = new Uint8Array(18);
      crypto.getRandomValues(array);
      walletPassword = btoa(String.fromCharCode.apply(null, array)).substring(0, 24);
      
      // Store in secure password manager
      try {
        const storeResponse = await fetch(`${API_BASE_URL}/system/passwords/store`, {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({
            service_name: 'lnd_wallet',
            username: 'lnd',
            password: walletPassword,
            description: 'LND Wallet Password',
            port: 8080,
            url: 'https://127.0.0.1:8080'
          })
        });
        
        if (storeResponse.ok) {
          lndScriptOutput.value += '✅ New password generated and stored securely\n\n';
        } else {
          lndScriptOutput.value += '⚠️  Password generated but storage failed (will use anyway)\n\n';
        }
      } catch (error) {
        console.error('Failed to store password:', error);
        lndScriptOutput.value += '⚠️  Password generated but storage failed (will use anyway)\n\n';
      }
    }
    
    // Show automation status and output container
    automationStatus.style.display = 'block';
    lndOutputContainer.style.display = 'block';
    autoConfigureBtn.disabled = true;
    statusMessage.textContent = 'Preparing LND wallet creation...';
    progressBar.style.width = '20%';
    
    // Clear and initialize output
    lndScriptOutput.value = '';
    lndScriptOutput.value += '╔════════════════════════════════════════════════════════════╗\n';
    lndScriptOutput.value += '║     BRLN-OS LND WALLET AUTO-CONFIGURATION SYSTEM          ║\n';
    lndScriptOutput.value += '╚════════════════════════════════════════════════════════════╝\n\n';
    lndScriptOutput.value += '🚀 Starting LND wallet creation with expect script...\n';
    lndScriptOutput.value += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
    
    // Scroll output into view
    lndOutputContainer.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    
    // Add delay to show initial output
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Call API endpoint to run expect script
    statusMessage.textContent = 'Running expect script to configure LND...';
    progressBar.style.width = '40%';
    
    const extendedKey = lndKeys[network].extended_master_key;
    lndScriptOutput.value += `📋 Network: ${network}\n`;
    lndScriptOutput.value += `🔑 Extended Master Key:\n    ${extendedKey}\n\n`;
    lndScriptOutput.value += '⏳ Executing: /home/brln-api/scripts/auto-lnd-create-masterkey.exp\n';
    lndScriptOutput.value += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
    lndScriptOutput.scrollTop = lndScriptOutput.scrollHeight;
    
    // Add delay to show progress
    await new Promise(resolve => setTimeout(resolve, 300));
    
    const response = await fetch(`${API_BASE_URL}/lnd/wallet/create-expect`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        wallet_password: walletPassword,
        extended_master_key: extendedKey,
        network: network
      })
    });
    
    const result = await response.json();
    
    progressBar.style.width = '80%';
    
    if (response.ok && result.status === 'success') {
      statusMessage.textContent = 'LND wallet configured successfully!';
      progressBar.style.width = '100%';
      
      // Display script output
      lndScriptOutput.value += '\n╔════════════════════════════════════════════════════════════╗\n';
      lndScriptOutput.value += '║              EXPECT SCRIPT OUTPUT                          ║\n';
      lndScriptOutput.value += '╚════════════════════════════════════════════════════════════╝\n\n';
      lndScriptOutput.value += result.output || 'Script executed successfully';
      lndScriptOutput.value += '\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      lndScriptOutput.value += '✅ SUCCESS: LND wallet created and configured!\n';
      lndScriptOutput.value += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      
      // Auto-scroll to bottom
      lndScriptOutput.scrollTop = lndScriptOutput.scrollHeight;
      
      setTimeout(() => {
        automationStatus.style.display = 'none';
        autoConfigureBtn.disabled = false;
        walletService.showNotification('LND wallet configured successfully!', 'success');
      }, 3000);
      
    } else {
      throw new Error(result.error || 'Failed to configure LND');
    }
    
  } catch (error) {
    console.error('Error auto-configuring LND:', error);
    
    const automationStatus = document.getElementById('lndAutomationStatus');
    const statusMessage = document.getElementById('lndStatusMessage');
    const autoConfigureBtn = document.getElementById('autoConfigureLndBtn');
    const lndScriptOutput = document.getElementById('lndScriptOutput');
    
    statusMessage.textContent = 'Error configuring LND: ' + error.message;
    if (lndScriptOutput) {
      lndScriptOutput.value += '\n\n╔════════════════════════════════════════════════════════════╗\n';
      lndScriptOutput.value += '║                     ERROR OCCURRED                         ║\n';
      lndScriptOutput.value += '╚════════════════════════════════════════════════════════════╝\n\n';
      lndScriptOutput.value += '❌ ERROR: ' + error.message + '\n';
      lndScriptOutput.value += '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      lndScriptOutput.scrollTop = lndScriptOutput.scrollHeight;
    }
    
    setTimeout(() => {
      automationStatus.style.display = 'none';
      autoConfigureBtn.disabled = false;
    }, 3000);
    
    walletService.showNotification('Error configuring LND: ' + error.message, 'error');
  }
}

// Copy Elements/Liquid address
function copyElementsAddress() {
  const elementsAddress = document.getElementById('elementsAddress');
  const copyBtn = document.getElementById('copyElementsAddressBtn');
  
  if (!elementsAddress) return;
  
  const addressText = elementsAddress.textContent;
  if (addressText && addressText !== '-') {
    navigator.clipboard.writeText(addressText).then(() => {
      walletService.showNotification('Liquid address copied!', 'success');
      
      // Visual feedback
      copyBtn.classList.add('copied');
      copyBtn.textContent = '✅';
      setTimeout(() => {
        copyBtn.classList.remove('copied');
        copyBtn.textContent = '📋';
      }, 2000);
    }).catch(error => {
      console.error('Error copying Liquid address:', error);
      walletService.showNotification('Error copying Liquid address', 'error');
    });
  }
}

// Auto-configure Elements/Liquid with the wallet
async function autoConfigureElements() {
  try {
    const automationStatus = document.getElementById('elementsAutomationStatus');
    const statusMessage = document.getElementById('elementsStatusMessage');
    const progressBar = document.getElementById('elementsProgressBar');
    const autoConfigureBtn = document.getElementById('autoConfigureElementsBtn');
    const elementsOutputContainer = document.getElementById('elementsOutputContainer');
    const elementsScriptOutput = document.getElementById('elementsScriptOutput');
    const elementsAddressElement = document.getElementById('elementsAddress');
    
    if (!currentWallet || !currentWallet.mnemonic) {
      walletService.showNotification('No wallet loaded. Please generate or import a wallet first.', 'error');
      return;
    }
    
    // Show automation status and output container
    automationStatus.style.display = 'block';
    elementsOutputContainer.style.display = 'block';
    autoConfigureBtn.disabled = true;
    statusMessage.textContent = 'Preparing Elements/Liquid wallet integration...';
    progressBar.style.width = '20%';
    
    // Clear and initialize output
    elementsScriptOutput.value = '';
    elementsScriptOutput.value += '╔════════════════════════════════════════════════════════════╗\n';
    elementsScriptOutput.value += '║    BRLN-OS LIQUID/ELEMENTS WALLET AUTO-CONFIGURATION      ║\n';
    elementsScriptOutput.value += '╚════════════════════════════════════════════════════════════╝\n\n';
    elementsScriptOutput.value += '🚀 Starting Elements/Liquid wallet integration...\n';
    elementsScriptOutput.value += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
    
    // Scroll output into view
    elementsOutputContainer.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Integrate wallet with Elements
    statusMessage.textContent = 'Integrating wallet with Elements...';
    progressBar.style.width = '40%';
    
    elementsScriptOutput.value += `📋 Wallet ID: ${currentWallet.wallet_id || 'N/A'}\n`;
    elementsScriptOutput.value += '⏳ Importing wallet into Elements daemon...\n\n';
    elementsScriptOutput.scrollTop = elementsScriptOutput.scrollHeight;
    
    await new Promise(resolve => setTimeout(resolve, 300));
    
    // Call API to integrate wallet
    const response = await fetch(`${API_BASE_URL}/wallet/integrate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        wallet_id: currentWallet.wallet_id,
        password: currentWallet.encryption_password || '' // Send encryption password if available
      })
    });
    
    const result = await response.json();
    
    progressBar.style.width = '80%';
    
    if (response.ok && result.status === 'success') {
      statusMessage.textContent = 'Elements wallet integrated successfully!';
      progressBar.style.width = '100%';
      
      // Display integration output
      elementsScriptOutput.value += '\n╔════════════════════════════════════════════════════════════╗\n';
      elementsScriptOutput.value += '║              INTEGRATION OUTPUT                            ║\n';
      elementsScriptOutput.value += '╚════════════════════════════════════════════════════════════╝\n\n';
      
      if (result.elements_integrated) {
        elementsScriptOutput.value += '✅ Elements/Liquid: INTEGRATED\n';
        if (result.elements_address) {
          elementsScriptOutput.value += `💧 Liquid Address: ${result.elements_address}\n`;
          // Update the address display
          if (elementsAddressElement) {
            elementsAddressElement.textContent = result.elements_address;
          }
        }
      } else {
        elementsScriptOutput.value += '⚠️  Elements/Liquid: Not integrated (may not be running)\n';
      }
      
      elementsScriptOutput.value += '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      elementsScriptOutput.value += '✅ SUCCESS: Elements/Liquid wallet integrated!\n';
      elementsScriptOutput.value += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      
      // Auto-scroll to bottom
      elementsScriptOutput.scrollTop = elementsScriptOutput.scrollHeight;
      
      setTimeout(() => {
        automationStatus.style.display = 'none';
        autoConfigureBtn.disabled = false;
        walletService.showNotification('Elements/Liquid wallet integrated successfully!', 'success');
      }, 3000);
      
    } else {
      throw new Error(result.error || result.message || 'Failed to integrate Elements wallet');
    }
    
  } catch (error) {
    console.error('Error auto-configuring Elements:', error);
    
    const automationStatus = document.getElementById('elementsAutomationStatus');
    const statusMessage = document.getElementById('elementsStatusMessage');
    const autoConfigureBtn = document.getElementById('autoConfigureElementsBtn');
    const elementsScriptOutput = document.getElementById('elementsScriptOutput');
    
    statusMessage.textContent = 'Error configuring Elements: ' + error.message;
    if (elementsScriptOutput) {
      elementsScriptOutput.value += '\n\n╔════════════════════════════════════════════════════════════╗\n';
      elementsScriptOutput.value += '║                     ERROR OCCURRED                         ║\n';
      elementsScriptOutput.value += '╚════════════════════════════════════════════════════════════╝\n\n';
      elementsScriptOutput.value += '❌ ERROR: ' + error.message + '\n';
      elementsScriptOutput.value += '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      elementsScriptOutput.scrollTop = elementsScriptOutput.scrollHeight;
    }
    
    setTimeout(() => {
      automationStatus.style.display = 'none';
      autoConfigureBtn.disabled = false;
    }, 3000);
    
    walletService.showNotification('Error configuring Elements: ' + error.message, 'error');
  }
}

// Copy TRON address
function copyTronAddress() {
  const tronAddress = document.getElementById('tronAddress');
  const copyBtn = document.getElementById('copyTronAddressBtn');
  
  if (!tronAddress) return;
  
  const addressText = tronAddress.textContent;
  if (addressText && addressText !== '-') {
    navigator.clipboard.writeText(addressText).then(() => {
      walletService.showNotification('TRON address copied!', 'success');
      
      // Visual feedback
      copyBtn.classList.add('copied');
      copyBtn.textContent = '✅';
      setTimeout(() => {
        copyBtn.classList.remove('copied');
        copyBtn.textContent = '📋';
      }, 2000);
    }).catch(error => {
      console.error('Error copying TRON address:', error);
      walletService.showNotification('Error copying TRON address', 'error');
    });
  }
}

// Auto-configure TRON wallet
async function autoConfigureTron() {
  try {
    const automationStatus = document.getElementById('tronAutomationStatus');
    const statusMessage = document.getElementById('tronStatusMessage');
    const progressBar = document.getElementById('tronProgressBar');
    const autoConfigureBtn = document.getElementById('autoConfigureTronBtn');
    const tronOutputContainer = document.getElementById('tronOutputContainer');
    const tronScriptOutput = document.getElementById('tronScriptOutput');
    const tronAddressElement = document.getElementById('tronAddress');
    
    if (!currentWallet || !currentWallet.wallet_id) {
      walletService.showNotification('No wallet loaded. Please generate or import a wallet first.', 'error');
      return;
    }
    
    // Show automation status and output container
    automationStatus.style.display = 'block';
    tronOutputContainer.style.display = 'block';
    autoConfigureBtn.disabled = true;
    statusMessage.textContent = 'Preparing TRON wallet integration...';
    progressBar.style.width = '20%';
    
    // Clear and initialize output
    tronScriptOutput.value = '';
    tronScriptOutput.value += '╔════════════════════════════════════════════════════════════╗\n';
    tronScriptOutput.value += '║       BRLN-OS TRON WALLET AUTO-CONFIGURATION              ║\n';
    tronScriptOutput.value += '╚════════════════════════════════════════════════════════════╝\n\n';
    tronScriptOutput.value += '🚀 Starting TRON wallet integration...\n';
    tronScriptOutput.value += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
    
    // Scroll output into view
    tronOutputContainer.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Initialize TRON wallet
    statusMessage.textContent = 'Initializing TRON wallet...';
    progressBar.style.width = '40%';
    
    tronScriptOutput.value += `📋 Wallet ID: ${currentWallet.wallet_id}\n`;
    tronScriptOutput.value += `🔗 Network: TRON Mainnet\n\n`;
    
    tronScriptOutput.value += '⏳ Calling TRON wallet initialization API...\n';
    tronScriptOutput.scrollTop = tronScriptOutput.scrollHeight;
    
    const response = await fetch(`${API_BASE_URL}/tron/wallet/initialize`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        wallet_id: currentWallet.wallet_id
      })
    });
    
    progressBar.style.width = '60%';
    
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Failed to initialize TRON wallet');
    }
    
    const result = await response.json();
    
    progressBar.style.width = '80%';
    statusMessage.textContent = 'TRON wallet initialized successfully!';
    
    tronScriptOutput.value += '\n✅ TRON wallet initialized successfully!\n';
    tronScriptOutput.value += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
    
    if (result.tron_address) {
      tronScriptOutput.value += `🔑 TRON Address:\n   ${result.tron_address}\n\n`;
      
      // Update the address display
      if (tronAddressElement) {
        tronAddressElement.textContent = result.tron_address;
      }
    }
    
    if (result.balance) {
      tronScriptOutput.value += `💰 Current Balance:\n`;
      tronScriptOutput.value += `   TRX: ${result.balance.trx || '0'} TRX\n`;
      tronScriptOutput.value += `   USDT: ${result.balance.usdt || '0'} USDT\n\n`;
    }
    
    if (result.gas_free) {
      tronScriptOutput.value += `⚡ Gas-Free Features:\n`;
      tronScriptOutput.value += `   Status: ${result.gas_free.enabled ? 'Enabled ✅' : 'Disabled ❌'}\n`;
      if (result.gas_free.service_provider) {
        tronScriptOutput.value += `   Provider: ${result.gas_free.service_provider}\n`;
      }
      tronScriptOutput.value += '\n';
    }
    
    tronScriptOutput.value += '📝 Next Steps:\n';
    tronScriptOutput.value += '   1. Send TRX or USDT to this address\n';
    tronScriptOutput.value += '   2. Use TRON tools for transactions\n';
    tronScriptOutput.value += `   3. Check balance: https://tronscan.org/#/address/${result.tron_address || ''}\n\n`;
    
    tronScriptOutput.value += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
    tronScriptOutput.value += '✅ SUCCESS: TRON wallet configured!\n';
    tronScriptOutput.value += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
    
    tronScriptOutput.scrollTop = tronScriptOutput.scrollHeight;
    
    progressBar.style.width = '100%';
    
    setTimeout(() => {
      automationStatus.style.display = 'none';
      autoConfigureBtn.disabled = false;
      walletService.showNotification('TRON wallet configured successfully!', 'success');
    }, 3000);
    
  } catch (error) {
    console.error('Error auto-configuring TRON:', error);
    
    const automationStatus = document.getElementById('tronAutomationStatus');
    const statusMessage = document.getElementById('tronStatusMessage');
    const autoConfigureBtn = document.getElementById('autoConfigureTronBtn');
    const tronScriptOutput = document.getElementById('tronScriptOutput');
    
    statusMessage.textContent = 'Error configuring TRON: ' + error.message;
    if (tronScriptOutput) {
      tronScriptOutput.value += '\n\n╔════════════════════════════════════════════════════════════╗\n';
      tronScriptOutput.value += '║                     ERROR OCCURRED                         ║\n';
      tronScriptOutput.value += '╚════════════════════════════════════════════════════════════╝\n\n';
      tronScriptOutput.value += '❌ ERROR: ' + error.message + '\n';
      tronScriptOutput.value += '\nPlease check:\n';
      tronScriptOutput.value += '  • Wallet has been properly generated\n';
      tronScriptOutput.value += '  • API server is running\n';
      tronScriptOutput.value += '  • TRON configuration is set up\n';
      tronScriptOutput.value += '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      tronScriptOutput.scrollTop = tronScriptOutput.scrollHeight;
    }
    
    setTimeout(() => {
      automationStatus.style.display = 'none';
      autoConfigureBtn.disabled = false;
    }, 3000);
    
    walletService.showNotification('Error configuring TRON: ' + error.message, 'error');
  }
}

// Copiar mnemônico para clipboard
function copyMnemonic() {
  if (!currentWallet || !currentWallet.mnemonic) {
    walletService.showNotification('Nenhuma seed phrase para copiar', 'warning');
    return;
  }
  
  navigator.clipboard.writeText(currentWallet.mnemonic).then(() => {
    walletService.showNotification('Mnemônico copiado para o clipboard!', 'success');
  }).catch(error => {
    console.error('Error copying mnemonic:', error);
    walletService.showNotification('Erro ao copiar mnemônico', 'error');
  });
}

// Mostrar endereços da carteira
function showAddresses(addresses) {
  // Show current wallet section instead of balance wallets section
  showCurrentWalletInfo(addresses);
  
  // Hide wallet selection section and show current wallet
  const walletSelectionSection = document.getElementById('walletSelectionSection');
  const createImportSection = document.getElementById('createImportSection');  
  const seedSection = document.getElementById('seedSection');
  const currentWalletSection = document.getElementById('currentWalletSection');
  
  if (walletSelectionSection) walletSelectionSection.style.display = 'none';
  if (createImportSection) createImportSection.style.display = 'none';
  if (seedSection) seedSection.style.display = 'none';
  if (currentWalletSection) currentWalletSection.style.display = 'block';
}

function showCurrentWalletInfo(addresses) {
  // Update current wallet info display
  const walletNameElement = document.getElementById('currentWalletName');
  const walletIdElement = document.getElementById('currentWalletId');
  const walletCreatedElement = document.getElementById('currentWalletCreated');
  const walletMnemonicElement = document.getElementById('currentWalletMnemonic');
  const walletMnemonicRow = document.getElementById('walletMnemonicRow');
  
  if (walletNameElement && currentWalletId) {
    walletNameElement.textContent = `Wallet ${currentWalletId}`;
  }
  
  if (walletIdElement && currentWalletId) {
    walletIdElement.textContent = currentWalletId;
  }
  
  if (walletCreatedElement) {
    walletCreatedElement.textContent = new Date().toLocaleString('pt-BR');
  }
  
  // Display mnemonic if available
  if (walletMnemonicElement && currentWallet && currentWallet.mnemonic && currentWallet.mnemonic !== '[PROTEGIDO]') {
    walletMnemonicElement.textContent = currentWallet.mnemonic;
    if (walletMnemonicRow) walletMnemonicRow.style.display = 'block';
  } else {
    if (walletMnemonicRow) walletMnemonicRow.style.display = 'none';
  }
  
  // Scroll to current wallet section
  const currentWalletSection = document.getElementById('currentWalletSection');
  if (currentWalletSection) {
    currentWalletSection.scrollIntoView({ behavior: 'smooth' });
  }
}

// Copiar endereço para clipboard
function copyAddress(chain) {
  const chainElements = {
    'bitcoin': 'bitcoin-address',
    'ethereum': 'ethereum-address',
    'liquid': 'liquid-address', 
    'tron': 'tron-address',
    'solana': 'solana-address'
  };
  
  const elementId = chainElements[chain];
  if (!elementId) return;
  
  const element = document.getElementById(elementId);
  if (!element) return;
  
  const address = element.textContent.trim();
  if (address && address !== 'N/A') {
    navigator.clipboard.writeText(address).then(() => {
      walletService.showNotification(`Endereço ${chain} copiado!`, 'success');
    }).catch(error => {
      console.error('Error copying address:', error);
      walletService.showNotification('Erro ao copiar endereço', 'error');
    });
  }
}

// Atualizar todos os saldos
async function updateAllBalances() {
  if (!currentWallet || !currentWallet.addresses) {
    console.log('No wallet loaded');
    return;
  }
  
  console.log('Updating all balances...');
  
  const balanceElements = {
    'bitcoin': 'btcBalance',
    'ethereum': 'ethBalance',
    'liquid': 'liquidBalance',
    'tron': 'trxBalance',
    'solana': 'solBalance'
  };
  
  // Atualizar cada saldo usando a API
  const updatePromises = Object.entries(currentWallet.addresses).map(async ([chain, data]) => {
    try {
      if (data.address && data.address !== 'Error') {
        const balance = await walletService.getBalance(chain, data.address);
        
        const elementId = balanceElements[chain];
        if (elementId) {
          const element = document.getElementById(elementId);
          if (element) {
            element.textContent = balance;
          }
        }
      }
    } catch (error) {
      console.error(`Error updating ${chain} balance:`, error);
      const elementId = balanceElements[chain];
      if (elementId) {
        const element = document.getElementById(elementId);
        if (element) {
          element.textContent = 'Erro';
        }
      }
    }
  });
  
  try {
    await Promise.all(updatePromises);
    console.log('✓ All balances updated');
    walletService.showNotification('Saldos atualizados com sucesso', 'success');
  } catch (error) {
    console.error('Error updating balances:', error);
    walletService.showNotification('Erro ao atualizar alguns saldos', 'warning');
  }
}

// Alternar visibilidade de seções
function toggleSection(sectionId) {
  const section = document.getElementById(sectionId);
  if (section) {
    const isVisible = section.style.display !== 'none';
    section.style.display = isVisible ? 'none' : 'block';
    
    if (!isVisible) {
      section.scrollIntoView({ behavior: 'smooth' });
    }
  }
}

// Event Listeners para inicializar a aplicação
document.addEventListener('DOMContentLoaded', function() {
  console.log('Wallet interface loaded');
  
  // Adicionar event listeners para os botões
  const generateBtn = document.getElementById('generateWalletBtn');
  const importBtn = document.getElementById('importWalletBtn');
  const copySeedBtn = document.getElementById('copySeedBtn');
  const confirmSeedBtn = document.getElementById('confirmSeedBtn');
  const refreshAllBtn = document.getElementById('refreshAllBalancesBtn');
  
  if (generateBtn) {
    generateBtn.addEventListener('click', generateNewWallet);
    console.log('Generate button event listener attached');
  }
  
  if (importBtn) {
    importBtn.addEventListener('click', importExistingWallet);
    console.log('Import button event listener attached');
  }
  
  if (copySeedBtn) {
    copySeedBtn.addEventListener('click', copyMnemonic);
    console.log('Copy seed button event listener attached');
  }
  
  if (confirmSeedBtn) {
    confirmSeedBtn.addEventListener('click', confirmSeed);
    console.log('Confirm seed button event listener attached');
  }
  
  // Balance refresh removed - not needed in admin wallet view
  
  // Event listeners para navegação entre seções
  const showCreateOptionsBtn = document.getElementById('showCreateOptionsBtn');
  const backToSelectionBtn = document.getElementById('backToSelectionBtn');
  const loadAnotherWalletBtn = document.getElementById('loadAnotherWalletBtn');
  
  if (showCreateOptionsBtn) {
    showCreateOptionsBtn.addEventListener('click', () => {
      const walletSelectionSection = document.getElementById('walletSelectionSection');
      const createImportSection = document.getElementById('createImportSection');
      
      if (walletSelectionSection) walletSelectionSection.style.display = 'none';
      if (createImportSection) createImportSection.style.display = 'block';
    });
    console.log('Show create options button event listener attached');
  }
  
  if (backToSelectionBtn) {
    backToSelectionBtn.addEventListener('click', () => {
      const walletSelectionSection = document.getElementById('walletSelectionSection');
      const createImportSection = document.getElementById('createImportSection');
      
      if (walletSelectionSection) walletSelectionSection.style.display = 'block';
      if (createImportSection) createImportSection.style.display = 'none';
    });
    console.log('Back to selection button event listener attached');
  }
  
  if (loadAnotherWalletBtn) {
    loadAnotherWalletBtn.addEventListener('click', () => {
      // Clear current wallet data
      currentWallet = null;
      currentWalletId = null;
      
      // Hide current wallet section
      const currentWalletSection = document.getElementById('currentWalletSection');
      if (currentWalletSection) currentWalletSection.style.display = 'none';
      
      // Show wallet selection section and reload wallet list
      const walletSelectionSection = document.getElementById('walletSelectionSection');
      if (walletSelectionSection) walletSelectionSection.style.display = 'block';
      
      // Reload existing wallets
      checkForExistingWallets();
      
      walletService.showNotification('Ready to load another wallet', 'info');
    });
    console.log('Load another wallet button event listener attached');
  }
  
  // Copy current mnemonic button
  const copyCurrentMnemonicBtn = document.getElementById('copyCurrentMnemonicBtn');
  if (copyCurrentMnemonicBtn) {
    copyCurrentMnemonicBtn.addEventListener('click', () => {
      const mnemonicText = document.getElementById('currentWalletMnemonic').textContent;
      if (mnemonicText && mnemonicText !== '-') {
        navigator.clipboard.writeText(mnemonicText).then(() => {
          walletService.showNotification('Seed phrase copied to clipboard!', 'success');
        }).catch(error => {
          console.error('Error copying mnemonic:', error);
          walletService.showNotification('Error copying seed phrase', 'error');
        });
      }
    });
  }
  
  // Go to Home button
  const goToHomeBtn = document.getElementById('goToHomeBtn');
  if (goToHomeBtn) {
    goToHomeBtn.addEventListener('click', () => {
      // Navigate to index.html in parent window
      if (window.parent && window.parent !== window) {
        window.parent.location.href = '/index.html';
      } else {
        window.location.href = '/index.html';
      }
    });
  }

  if (loadAnotherWalletBtn) {
    loadAnotherWalletBtn.addEventListener('click', () => {
      // Hide current wallet section and show wallet selection
      const currentWalletSection = document.getElementById('currentWalletSection');
      const walletSelectionSection = document.getElementById('walletSelectionSection');
      
      if (currentWalletSection) currentWalletSection.style.display = 'none';
      if (walletSelectionSection) walletSelectionSection.style.display = 'block';
      
      // Clear current wallet data
      currentWallet = null;
      currentWalletId = null;
      
      // Check for existing wallets to reload the list
      checkForExistingWallets();
    });
    console.log('Load another wallet button event listener attached');
  }
  
  // Verificar se a API está acessível
  walletService.makeApiRequest('/wallet/status')
    .then(response => {
      console.log('API connection successful:', response);
      walletService.showNotification('Sistema inicializado com sucesso', 'success');
      
      // Verificar se há carteiras existentes
      checkForExistingWallets();
    })
    .catch(error => {
      console.error('API connection failed:', error);
      walletService.showNotification('Erro ao conectar com a API', 'error');
    });
});

// ============================================
// PARENT WINDOW COMMUNICATION
// ============================================

/**
 * Notify parent window that wallet has been configured
 */
function notifyWalletConfigured(walletId) {
  try {
    // Set this wallet as system default
    setAsSystemDefault(walletId);
    
    // Check if we're in an iframe
    if (window.parent && window.parent !== window) {
      console.log('Notifying parent window of wallet configuration:', walletId);
      
      // Send message to parent window
      window.parent.postMessage({
        type: 'WALLET_CONFIGURED',
        walletId: walletId,
        timestamp: new Date().toISOString()
      }, '*');
      
      // Also store flag in sessionStorage for main window
      sessionStorage.setItem('walletJustConfigured', 'true');
      sessionStorage.setItem('lastConfiguredWallet', walletId);
      
      console.log('Parent notification sent successfully');
    } else {
      console.log('Not in iframe, storing wallet configuration flag');
      sessionStorage.setItem('walletJustConfigured', 'true');
      sessionStorage.setItem('lastConfiguredWallet', walletId);
    }
  } catch (error) {
    console.error('Error notifying parent window:', error);
  }
}

/**
 * Set a wallet as the system default
 */
async function setAsSystemDefault(walletId) {
  try {
    console.log('Setting wallet as system default:', walletId);
    
    const response = await fetch(`${API_BASE_URL}/wallet/system-default`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        wallet_id: walletId
      })
    });
    
    const data = await response.json();
    
    if (response.ok) {
      console.log('Wallet set as system default successfully');
      walletService.showNotification(`Wallet ${walletId} definido como padrão do sistema`, 'info');
    } else {
      console.error('Failed to set as system default:', data.error);
    }
  } catch (error) {
    console.error('Error setting wallet as system default:', error);
  }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
  // ... existing initialization code ...
  
  // Verificar se a API está acessível
  walletService.makeApiRequest('/wallet/status')
    .then(response => {
      console.log('API connection successful:', response);
      walletService.showNotification('Sistema inicializado com sucesso', 'success');
      
      // Verificar se há carteiras existentes
      checkForExistingWallets();
    })
    .catch(error => {
      console.error('API connection failed:', error);
      walletService.showNotification('Erro ao conectar com a API', 'error');
    });
});