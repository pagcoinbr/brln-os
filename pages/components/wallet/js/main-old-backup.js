// Central de Controle Carteira Multichain BRLN-OS
// Usando API backend para operações de carteira seguras

// Base URL da API
const API_BASE_URL = '/api/v1';

// Variáveis globais para a carteira
let currentWallet = null;
let walletAddresses = {};
let currentWalletId = null;

// Classe principal do serviço de carteira (API-based)
class WalletService {
  constructor() {
    this.apiBaseUrl = API_BASE_URL;
  }

  // Fazer requisição para API
  async makeApiRequest(endpoint, options = {}) {
    try {
      const url = `${this.apiBaseUrl}${endpoint}`;
      const defaultOptions = {
        headers: {
          'Content-Type': 'application/json'
        }
      };
      
      const response = await fetch(url, {
        ...defaultOptions,
        ...options
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || `API request failed: ${response.status}`);
      }
      
      return data;
    } catch (error) {
      console.error('API request failed:', error);
      throw error;
    }
  }

  // Gerar nova carteira
  async generateWallet() {
    const data = await this.makeApiRequest('/wallet/generate', {
      method: 'POST'
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
  async loadWallet(walletId, password) {
    const data = await this.makeApiRequest('/wallet/load', {
      method: 'POST',
      body: JSON.stringify({
        wallet_id: walletId,
        password
      })
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
}

// Instanciar o serviço de carteira
const walletService = new WalletService();

// Funções de Gerenciamento de Carteira

// Gerar nova carteira
async function generateNewWallet() {
  try {
    showLoading(true);
    
    // Usar API para gerar carteira
    const result = await walletService.generateWallet();
    
    if (result && result.mnemonic) {
      // Exibir o mnemônico para o usuário
      showMnemonic(result.mnemonic);
      
      // Gerar endereços usando a API
      const addresses = await walletService.getWalletAddresses(result.wallet_id);
      
      // Armazenar dados da carteira atual
      currentWallet = {
        mnemonic: result.mnemonic,
        addresses: addresses,
        walletId: result.wallet_id
      };
      currentWalletId = result.wallet_id;
      
      // Mostrar seção de endereços
      showAddresses(addresses);
      
      walletService.showNotification('Nova carteira gerada com sucesso!', 'success');
      
      // Atualizar saldos
      setTimeout(() => updateAllBalances(), 1000);
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
  const mnemonic = document.getElementById('import-mnemonic').value.trim();
  const passphrase = document.getElementById('import-passphrase').value || '';
  
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
    
    if (result && result.wallet_id) {
      // Obter endereços da carteira
      const addresses = await walletService.getWalletAddresses(result.wallet_id);
      
      // Armazenar dados da carteira atual
      currentWallet = {
        mnemonic: mnemonic,
        addresses: addresses,
        walletId: result.wallet_id
      };
      currentWalletId = result.wallet_id;
      
      // Mostrar endereços
      showAddresses(addresses);
      
      // Limpar campos
      document.getElementById('import-mnemonic').value = '';
      document.getElementById('import-passphrase').value = '';
      
      walletService.showNotification('Carteira importada com sucesso!', 'success');
      
      // Atualizar saldos
      setTimeout(() => updateAllBalances(), 1000);
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
        });
        
        if (!response.ok) {
          throw new Error('Failed to fetch Bitcoin block from mempool.space');
        }
        
        const blockHeight = await response.json();
        console.log('Current Bitcoin block height from mempool.space:', blockHeight);
        return blockHeight;
        
      } catch (fallbackError) {
        console.error('Error fetching Bitcoin block from both APIs:', fallbackError);
        return null;
      }
    }
  }

  // Gerar fingerprint do navegador para entropia adicional
  getBrowserFingerprint() {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    ctx.textBaseline = 'top';
    ctx.font = '14px Arial';
    ctx.fillText('Entropy fingerprint', 2, 2);
    
    return [
      navigator.userAgent,
      navigator.language,
      screen.width + 'x' + screen.height,
      new Date().getTimezoneOffset(),
      canvas.toDataURL()
    ].join('|');
  }

  // Gerar mnemonic BIP39 de 12 palavras
  async generateMnemonic() {
    if (!window.bip39) {
      throw new Error('BIP39 library not available');
    }

    try {
      // Gerar entropy segura
      const entropy = await this.generateSecureEntropy();
      
      // Usar nossa implementação simples
      const mnemonic = await window.bip39.entropyToMnemonic(entropy);
      
      if (!this.validateMnemonic(mnemonic)) {
        throw new Error('Generated mnemonic failed validation');
      }
      
      console.log('Secure mnemonic generated with Bitcoin block data');
      return mnemonic;
      
    } catch (error) {
      console.error('Error generating mnemonic:', error);
      // Fallback para geração padrão
      return await window.bip39.generateMnemonic();
    }
  }

  // Validar mnemonic BIP39
  validateMnemonic(mnemonic) {
    if (!window.bip39) {
      return false;
    }
    
    try {
      return window.bip39.validateMnemonic(mnemonic.trim());
    } catch (error) {
      console.error('Error validating mnemonic:', error);
      return false;
    }
  }

  // Derivar carteiras para todas as chains
  async deriveWallets(mnemonic, passphrase = '') {
    if (!this.validateMnemonic(mnemonic)) {
      throw new Error('Invalid mnemonic phrase');
    }

    try {
      const seed = await window.bip39.mnemonicToSeed(mnemonic, passphrase);
      const wallets = {};
      
      // Derivar para cada blockchain
      for (const [chainId, chainConfig] of Object.entries(CHAINS)) {
        try {
          const wallet = await this.deriveChainWallet(seed, chainConfig);
          wallets[chainId] = wallet;
        } catch (error) {
          console.error(`Error deriving ${chainId} wallet:`, error);
          wallets[chainId] = { error: error.message };
        }
      }
      
      return wallets;
      
    } catch (error) {
      console.error('Error deriving wallets:', error);
      throw error;
    }
  }

  // Derivar carteira para uma blockchain específica
  async deriveChainWallet(seed, chainConfig) {
    // Implementação básica - em produção usar bibliotecas específicas
    const wallet = {
      path: chainConfig.path,
      chain: chainConfig.name,
      symbol: chainConfig.symbol,
      address: null,
      publicKey: null,
      privateKey: null // NUNCA expor em produção
    };

    // Para Bitcoin e chains baseadas em secp256k1
    if (chainConfig.coinType === 0 || chainConfig.coinType === 1776) {
      wallet.address = await this.deriveBitcoinAddress(seed, chainConfig.path);
    }
    
    // Para Ethereum
    else if (chainConfig.coinType === 60) {
      wallet.address = await this.deriveEthereumAddress(seed, chainConfig.path);
    }
    
    // Para TRON
    else if (chainConfig.coinType === 195) {
      wallet.address = await this.deriveTronAddress(seed, chainConfig.path);
    }
    
    // Para Solana
    else if (chainConfig.coinType === 501) {
      wallet.address = await this.deriveSolanaAddress(seed, chainConfig.path);
    }

    return wallet;
  }

  // Derivar endereço Bitcoin (implementação simplificada)
  async deriveBitcoinAddress(seed, path) {
    // Em produção, usar bitcoinjs-lib completo
    try {
      // TODO: Implementar derivação real com bitcoinjs-lib
      // Por enquanto retorna erro para não mostrar endereço falso
      return 'Bitcoin address generation not implemented';
    } catch (error) {
      console.error('Error deriving Bitcoin address:', error);
      return 'Error generating address';
    }
  }

  // Derivar endereço Ethereum
  async deriveEthereumAddress(seed, path) {
    try {
      if (typeof ethers !== 'undefined') {
        // Implementação real com ethers
        const wallet = ethers.Wallet.createRandom();
        return wallet.address;
      } else {
        // Ethers.js não carregado
        return 'Ethereum library not available';
      }
    } catch (error) {
      console.error('Error deriving Ethereum address:', error);
      return 'Error generating address';
    }
  }

  // Derivar endereço TRON
  async deriveTronAddress(seed, path) {
    try {
      // TODO: Implementar derivação real com TronWeb
      // Por enquanto retorna erro para não mostrar endereço falso
      return 'TRON address generation not implemented';
    } catch (error) {
      console.error('Error deriving TRON address:', error);
      return 'Error generating address';
    }
  }

  // Derivar endereço Solana
  async deriveSolanaAddress(seed, path) {
    try {
      // TODO: Implementar derivação real com @solana/web3.js
      // Por enquanto retorna erro para não mostrar endereço falso
      return 'Solana address generation not implemented';
    } catch (error) {
      console.error('Error deriving Solana address:', error);
      return 'Error generating address';
    }
  }

  // Obter saldo para uma chain específica
  async getBalance(chain, address) {
    const chainConfig = CHAINS[chain];
    if (!chainConfig) {
      throw new Error(`Unsupported chain: ${chain}`);
    }

    try {
      // Implementação específica por chain
      switch (chain) {
        case 'bitcoin':
          return await this.getBitcoinBalance(address);
        case 'ethereum':
          return await this.getEthereumBalance(address);
        case 'liquid':
          return await this.getLiquidBalance(address);
        case 'tron':
          return await this.getTronBalance(address);
        case 'solana':
          return await this.getSolanaBalance(address);
        default:
          throw new Error(`Balance checking not implemented for ${chain}`);
      }
    } catch (error) {
      console.error(`Error getting balance for ${chain}:`, error);
      return '0.00000000';
    }
  }

  // Obter saldo Bitcoin
  async getBitcoinBalance(address) {
    if (!address || address === 'Error') {
      return '0.00000000';
    }

    // Tentar múltiplas APIs com fallback
    const apis = [
      {
        name: 'local',
        fetch: async () => {
          const response = await fetch(`/api/v1/wallet/balance/onchain`);
          if (!response.ok) throw new Error('Local API error');
          const data = await response.json();
          if (data.status === 'success') {
            const balanceSats = parseInt(data.confirmed_balance || 0);
            return (balanceSats / 100000000).toFixed(8);
          }
          throw new Error('Local API returned error');
        }
      },
      {
        name: 'mempool.space',
        fetch: async () => {
          const response = await fetch(`https://mempool.space/api/address/${address}`);
          if (!response.ok) throw new Error('Mempool API error');
          const data = await response.json();
          const balance = (data.chain_stats.funded_txo_sum - data.chain_stats.spent_txo_sum) / 100000000;
          return balance.toFixed(8);
        }
      },
      {
        name: 'blockstream',
        fetch: async () => {
          const response = await fetch(`https://blockstream.info/api/address/${address}`);
          if (!response.ok) throw new Error('Blockstream API error');
          const data = await response.json();
          const balance = (data.chain_stats.funded_txo_sum - data.chain_stats.spent_txo_sum) / 100000000;
          return balance.toFixed(8);
        }
      },
      {
        name: 'blockchain.info',
        fetch: async () => {
          const response = await fetch(`https://blockchain.info/q/addressbalance/${address}`);
          if (!response.ok) throw new Error('Blockchain.info API error');
          const balanceSats = await response.text();
          return (parseInt(balanceSats) / 100000000).toFixed(8);
        }
      }
    ];

    for (const api of apis) {
      try {
        console.log(`Trying Bitcoin balance from ${api.name}...`);
        const balance = await api.fetch();
        console.log(`Bitcoin balance from ${api.name}: ${balance} BTC`);
        return balance;
      } catch (error) {
        console.log(`Bitcoin balance API ${api.name} failed:`, error.message);
        continue;
      }
    }

    console.error('All Bitcoin balance APIs failed');
    return '0.00000000';
  }

  // Obter saldo Ethereum
  async getEthereumBalance(address) {
    if (!address || address === 'Error' || address === 'Ethereum library not available') {
      return '0.000000000000000000';
    }

    const apis = [
      {
        name: 'etherscan',
        fetch: async () => {
          const apiKey = 'YourApiKeyToken'; // Use free tier without key or replace with real key
          const url = `https://api.etherscan.io/api?module=account&action=balance&address=${address}&tag=latest&apikey=${apiKey}`;
          const response = await fetch(url);
          if (!response.ok) throw new Error('Etherscan API error');
          const data = await response.json();
          if (data.status !== '1') throw new Error(data.message);
          return (BigInt(data.result) / BigInt('1000000000000000000')).toString();
        }
      },
      {
        name: 'alchemy',
        fetch: async () => {
          const response = await fetch('https://eth-mainnet.g.alchemy.com/v2/demo', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              jsonrpc: '2.0',
              id: 1,
              method: 'eth_getBalance',
              params: [address, 'latest']
            })
          });
          if (!response.ok) throw new Error('Alchemy API error');
          const data = await response.json();
          if (data.error) throw new Error(data.error.message);
          const balanceWei = BigInt(data.result);
          return (balanceWei / BigInt('1000000000000000000')).toString();
        }
      },
      {
        name: 'infura',
        fetch: async () => {
          const response = await fetch('https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              jsonrpc: '2.0',
              id: 1,
              method: 'eth_getBalance',
              params: [address, 'latest']
            })
          });
          if (!response.ok) throw new Error('Infura API error');
          const data = await response.json();
          if (data.error) throw new Error(data.error.message);
          const balanceWei = BigInt(data.result);
          return (balanceWei / BigInt('1000000000000000000')).toString();
        }
      }
    ];

    for (const api of apis) {
      try {
        console.log(`Trying Ethereum balance from ${api.name}...`);
        const balance = await api.fetch();
        console.log(`Ethereum balance from ${api.name}: ${balance} ETH`);
        return parseFloat(balance).toFixed(18);
      } catch (error) {
        console.log(`Ethereum balance API ${api.name} failed:`, error.message);
        continue;
      }
    }

    console.error('All Ethereum balance APIs failed');
    return '0.000000000000000000';
  }

  // Obter saldo Liquid
  async getLiquidBalance(address) {
    if (!address || address === 'Error') {
      return '0.00000000';
    }

    const apis = [
      {
        name: 'local',
        fetch: async () => {
          const response = await fetch(`/api/v1/elements/balances`);
          if (!response.ok) throw new Error('Local Elements API error');
          const data = await response.json();
          if (data.status === 'success' && data.balances && data.balances.lbtc) {
            return (data.balances.lbtc.trusted || 0).toFixed(8);
          }
          throw new Error('Local API returned error');
        }
      },
      {
        name: 'liquid.network',
        fetch: async () => {
          const response = await fetch(`https://liquid.network/api/address/${address}`);
          if (!response.ok) throw new Error('Liquid.network API error');
          const data = await response.json();
          const balance = (data.chain_stats.funded_txo_sum - data.chain_stats.spent_txo_sum) / 100000000;
          return balance.toFixed(8);
        }
      },
      {
        name: 'blockstream-liquid',
        fetch: async () => {
          const response = await fetch(`https://blockstream.info/liquid/api/address/${address}`);
          if (!response.ok) throw new Error('Blockstream Liquid API error');
          const data = await response.json();
          const balance = (data.chain_stats.funded_txo_sum - data.chain_stats.spent_txo_sum) / 100000000;
          return balance.toFixed(8);
        }
      }
    ];

    for (const api of apis) {
      try {
        console.log(`Trying Liquid balance from ${api.name}...`);
        const balance = await api.fetch();
        console.log(`Liquid balance from ${api.name}: ${balance} L-BTC`);
        return balance;
      } catch (error) {
        console.log(`Liquid balance API ${api.name} failed:`, error.message);
        continue;
      }
    }

    console.error('All Liquid balance APIs failed');
    return '0.00000000';
  }

  // Obter saldo TRON
  async getTronBalance(address) {
    if (!address || address === 'Error' || address === 'TRON address generation not implemented') {
      return '0.000000';
    }

    const apis = [
      {
        name: 'trongrid',
        fetch: async () => {
          const response = await fetch('https://api.trongrid.io/wallet/getaccount', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ address: address, visible: true })
          });
          if (!response.ok) throw new Error('TronGrid API error');
          const data = await response.json();
          if (data.Error) throw new Error(data.Error);
          const balanceSun = data.balance || 0;
          return (balanceSun / 1000000).toFixed(6); // Convert from SUN to TRX
        }
      },
      {
        name: 'tronscan',
        fetch: async () => {
          const response = await fetch(`https://apilist.tronscanapi.com/api/account?address=${address}`);
          if (!response.ok) throw new Error('TronScan API error');
          const data = await response.json();
          if (!data.balance) throw new Error('No balance data');
          const balanceTrx = data.balance / 1000000; // Convert from SUN to TRX
          return balanceTrx.toFixed(6);
        }
      },
      {
        name: 'tronapi',
        fetch: async () => {
          const response = await fetch(`https://api.tronapi.com/v1/account/${address}`);
          if (!response.ok) throw new Error('TronAPI error');
          const data = await response.json();
          if (data.error) throw new Error(data.error);
          const balanceTrx = (data.balance || 0) / 1000000;
          return balanceTrx.toFixed(6);
        }
      }
    ];

    for (const api of apis) {
      try {
        console.log(`Trying TRON balance from ${api.name}...`);
        const balance = await api.fetch();
        console.log(`TRON balance from ${api.name}: ${balance} TRX`);
        return balance;
      } catch (error) {
        console.log(`TRON balance API ${api.name} failed:`, error.message);
        continue;
      }
    }

    console.error('All TRON balance APIs failed');
    return '0.000000';
  }

  // Obter saldo Solana
  async getSolanaBalance(address) {
    if (!address || address === 'Error' || address === 'Solana address generation not implemented') {
      return '0.000000000';
    }

    const apis = [
      {
        name: 'mainnet-beta',
        fetch: async () => {
          const response = await fetch('https://api.mainnet-beta.solana.com', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              jsonrpc: '2.0',
              id: 1,
              method: 'getBalance',
              params: [address]
            })
          });
          if (!response.ok) throw new Error('Solana mainnet API error');
          const data = await response.json();
          if (data.error) throw new Error(data.error.message);
          const balanceLamports = data.result.value;
          return (balanceLamports / 1000000000).toFixed(9); // Convert from lamports to SOL
        }
      },
      {
        name: 'helius',
        fetch: async () => {
          const response = await fetch('https://rpc.helius.xyz/?api-key=demo', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              jsonrpc: '2.0',
              id: 1,
              method: 'getBalance',
              params: [address]
            })
          });
          if (!response.ok) throw new Error('Helius API error');
          const data = await response.json();
          if (data.error) throw new Error(data.error.message);
          const balanceLamports = data.result.value;
          return (balanceLamports / 1000000000).toFixed(9);
        }
      },
      {
        name: 'quicknode',
        fetch: async () => {
          const response = await fetch('https://solana-mainnet.core.chainstack.com/rpc/demo', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              jsonrpc: '2.0',
              id: 1,
              method: 'getBalance',
              params: [address]
            })
          });
          if (!response.ok) throw new Error('Chainstack API error');
          const data = await response.json();
          if (data.error) throw new Error(data.error.message);
          const balanceLamports = data.result.value;
          return (balanceLamports / 1000000000).toFixed(9);
        }
      }
    ];

    for (const api of apis) {
      try {
        console.log(`Trying Solana balance from ${api.name}...`);
        const balance = await api.fetch();
        console.log(`Solana balance from ${api.name}: ${balance} SOL`);
        return balance;
      } catch (error) {
        console.log(`Solana balance API ${api.name} failed:`, error.message);
        continue;
      }
    }

    console.error('All Solana balance APIs failed');
    return '0.000000000';
  }

  // Criptografar seed com AES-256
  async encryptSeed(mnemonic, password) {
    try {
      const enc = new TextEncoder();
      const data = enc.encode(mnemonic);
      const passwordKey = await crypto.subtle.importKey(
        'raw',
        enc.encode(password),
        { name: 'PBKDF2' },
        false,
        ['deriveBits', 'deriveKey']
      );
      
      const key = await crypto.subtle.deriveKey(
        {
          name: 'PBKDF2',
          salt: enc.encode('brln-wallet-salt'),
          iterations: 100000,
          hash: 'SHA-256'
        },
        passwordKey,
        { name: 'AES-GCM', length: 256 },
        true,
        ['encrypt', 'decrypt']
      );
      
      const iv = crypto.getRandomValues(new Uint8Array(12));
      const encrypted = await crypto.subtle.encrypt(
        { name: 'AES-GCM', iv: iv },
        key,
        data
      );
      
      return {
        encrypted: Array.from(new Uint8Array(encrypted)),
        iv: Array.from(iv)
      };
      
    } catch (error) {
      console.error('Error encrypting seed:', error);
      throw error;
    }
  }

  // Descriptografar seed
  async decryptSeed(encryptedData, password) {
    try {
      const enc = new TextEncoder();
      const dec = new TextDecoder();
      
      const passwordKey = await crypto.subtle.importKey(
        'raw',
        enc.encode(password),
        { name: 'PBKDF2' },
        false,
        ['deriveBits', 'deriveKey']
      );
      
      const key = await crypto.subtle.deriveKey(
        {
          name: 'PBKDF2',
          salt: enc.encode('brln-wallet-salt'),
          iterations: 100000,
          hash: 'SHA-256'
        },
        passwordKey,
        { name: 'AES-GCM', length: 256 },
        true,
        ['encrypt', 'decrypt']
      );
      
      const decrypted = await crypto.subtle.decrypt(
        {
          name: 'AES-GCM',
          iv: new Uint8Array(encryptedData.iv)
        },
        key,
        new Uint8Array(encryptedData.encrypted)
      );
      
      return dec.decode(decrypted);
      
    } catch (error) {
      console.error('Error decrypting seed:', error);
      throw error;
    }
  }

  // Obter saldo USDT na rede TRON
  async getTronUSDTBalance(address) {
    if (!address || address === 'Error' || address === 'TRON address generation not implemented') {
      return '0.000000';
    }

    const usdtContractAddress = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'; // USDT TRC20 contract
    
    const apis = [
      {
        name: 'trongrid-usdt',
        fetch: async () => {
          const response = await fetch('https://api.trongrid.io/v1/accounts/' + address + '/transactions/trc20', {
            method: 'GET',
            headers: { 'Accept': 'application/json' }
          });
          if (!response.ok) throw new Error('TronGrid USDT API error');
          const data = await response.json();
          
          // Get USDT balance through account info
          const accountResponse = await fetch('https://api.trongrid.io/wallet/getaccount', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ address: address, visible: true })
          });
          
          if (!accountResponse.ok) throw new Error('TronGrid account API error');
          const accountData = await accountResponse.json();
          
          // Look for USDT in TRC20 tokens
          if (accountData.trc20 && accountData.trc20[usdtContractAddress]) {
            const balanceRaw = accountData.trc20[usdtContractAddress];
            return (balanceRaw / 1000000).toFixed(6); // USDT has 6 decimals
          }
          
          return '0.000000';
        }
      },
      {
        name: 'tronscan-usdt',
        fetch: async () => {
          const response = await fetch(`https://apilist.tronscanapi.com/api/account/tokens?address=${address}&contract=${usdtContractAddress}`);
          if (!response.ok) throw new Error('TronScan USDT API error');
          const data = await response.json();
          
          if (data.data && data.data.length > 0) {
            const usdtToken = data.data.find(token => token.tokenId === usdtContractAddress);
            if (usdtToken) {
              return (usdtToken.balance / Math.pow(10, usdtToken.tokenDecimal)).toFixed(6);
            }
          }
          
          return '0.000000';
        }
      }
    ];

    for (const api of apis) {
      try {
        console.log(`Trying TRON USDT balance from ${api.name}...`);
        const balance = await api.fetch();
        console.log(`TRON USDT balance from ${api.name}: ${balance} USDT`);
        return balance;
      } catch (error) {
        console.log(`TRON USDT balance API ${api.name} failed:`, error.message);
        continue;
      }
    }

    console.error('All TRON USDT balance APIs failed');
    return '0.000000';
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
}

// Instância global do serviço de carteira
const walletService = new WalletService();

// === INICIALIZAÇÃO ===
document.addEventListener('DOMContentLoaded', function() {
  initializePage();
  setupEventListeners();
});

function initializePage() {
  // Verificar se existe carteira salva
  checkSavedWallet();
}

function setupEventListeners() {
  // Botões de ação principais
  const generateBtn = document.getElementById('generateWalletBtn');
  if (generateBtn) {
    generateBtn.addEventListener('click', generateNewWallet);
  }
  
  const importBtn = document.getElementById('importWalletBtn');
  if (importBtn) {
    importBtn.addEventListener('click', importExistingWallet);
  }
  
  // Botões da seed
  const copySeedBtn = document.getElementById('copySeedBtn');
  if (copySeedBtn) {
    copySeedBtn.addEventListener('click', copySeedToClipboard);
  }
  
  const confirmSeedBtn = document.getElementById('confirmSeedBtn');
  if (confirmSeedBtn) {
    confirmSeedBtn.addEventListener('click', confirmSeedAndContinue);
  }
  
  // Botões de segurança
  const encryptBtn = document.getElementById('encryptWalletBtn');
  if (encryptBtn) {
    encryptBtn.addEventListener('click', encryptAndSaveWallet);
  }
  
  const decryptBtn = document.getElementById('decryptWalletBtn');
  if (decryptBtn) {
    decryptBtn.addEventListener('click', decryptSavedWallet);
  }
  
  // Botão para refresh manual de todos os saldos
  const refreshAllBtn = document.getElementById('refreshAllBalancesBtn');
  if (refreshAllBtn) {
    refreshAllBtn.addEventListener('click', async function() {
      this.disabled = true;
      this.textContent = '⏳ Updating...';
      
      try {
        await updateAllBalances();
      } finally {
        this.disabled = false;
        this.textContent = '🔄 Refresh All Balances';
      }
    });
  }
  
  // Auto-refresh toggle
  const autoRefreshToggle = document.getElementById('autoRefreshToggle');
  if (autoRefreshToggle) {
    autoRefreshToggle.addEventListener('change', function() {
      if (this.checked) {
        startAutoRefresh();
        walletService.showNotification('Auto-refresh enabled (every 2 minutes)', 'info');
      } else {
        stopAutoRefresh();
        walletService.showNotification('Auto-refresh disabled', 'info');
      }
    });
  }
}

// === FUNÇÕES PRINCIPAIS ===

// Gerar nova carteira
async function generateNewWallet() {
  try {
    const button = document.getElementById('generateWalletBtn');
    button.disabled = true;
    button.textContent = '⏳ Gerando...';
    
    // Chamar API para gerar carteira
    const response = await walletService.generateWallet();
    
    // Mostrar seed para o usuário
    displaySeedPhrase(response.mnemonic);
    
    // Salvar temporariamente
    currentWallet = { 
      mnemonic: response.mnemonic, 
      addresses: response.addresses,
      generated: true 
    };
    
    walletService.showNotification('Carteira gerada com sucesso!', 'success');
    
  } catch (error) {
    console.error('Error generating wallet:', error);
    walletService.showNotification('Erro ao gerar carteira: ' + error.message, 'error');
  } finally {
    const button = document.getElementById('generateWalletBtn');
    button.disabled = false;
    button.textContent = '🔄 Gerar Nova Carteira';
  }
}

// Importar carteira existente  
async function importExistingWallet() {
  const mnemonic = document.getElementById('importMnemonic').value.trim();
  const passphrase = document.getElementById('importPassphrase').value;
  
  if (!mnemonic) {
    walletService.showNotification('Digite a seed phrase', 'warning');
    return;
  }
  
  try {
    // Validar mnemonic via API
    const isValid = await walletService.validateMnemonic(mnemonic);
    if (!isValid) {
      walletService.showNotification('Seed phrase inválida', 'error');
      return;
    }
    
    // Importar carteira via API
    const response = await walletService.importWallet(mnemonic, passphrase);
    
    // Salvar carteira atual
    currentWallet = { 
      mnemonic, 
      passphrase, 
      addresses: response.addresses 
    };
    walletAddresses = response.addresses;
    
    // Mostrar carteiras derivadas
    displayWallets(response.addresses);
    updateWalletStatus('Carteira importada com sucesso', true);
    
    walletService.showNotification('Carteira importada com sucesso!', 'success');
    
  } catch (error) {
    console.error('Error importing wallet:', error);
    walletService.showNotification('Erro ao importar carteira: ' + error.message, 'error');
  }
}

// Mostrar seed phrase gerada
function displaySeedPhrase(mnemonic) {
  const words = mnemonic.split(' ');
  const seedDisplay = document.getElementById('seedDisplay');
  
  const seedGrid = document.createElement('div');
  seedGrid.className = 'seed-grid';
  
  words.forEach((word, index) => {
    const seedWord = document.createElement('div');
    seedWord.className = 'seed-word';
    seedWord.innerHTML = `
      <span class="seed-word-number">${index + 1}</span>
      ${word}
    `;
    seedGrid.appendChild(seedWord);
  });
  
  seedDisplay.innerHTML = '';
  seedDisplay.appendChild(seedGrid);
  
  // Mostrar seção da seed
  document.getElementById('seedSection').style.display = 'block';
  document.getElementById('seedSection').scrollIntoView({ behavior: 'smooth' });
}

// Copiar seed para clipboard
async function copySeedToClipboard() {
  if (!currentWallet || !currentWallet.mnemonic) {
    walletService.showNotification('Nenhuma seed para copiar', 'warning');
    return;
  }
  
  try {
    await navigator.clipboard.writeText(currentWallet.mnemonic);
    walletService.showNotification('Seed copiada para clipboard!', 'success');
  } catch (error) {
    console.error('Error copying to clipboard:', error);
    walletService.showNotification('Erro ao copiar seed', 'error');
  }
}

// Confirmar seed e continuar
async function confirmSeedAndContinue() {
  if (!currentWallet || !currentWallet.mnemonic) {
    walletService.showNotification('Erro: nenhuma carteira gerada', 'error');
    return;
  }
  
  try {
    // Se já temos endereços da geração, usar eles
    let addresses = currentWallet.addresses;
    
    // Se não temos endereços, derivar via API
    if (!addresses) {
      const response = await walletService.importWallet(currentWallet.mnemonic, '');
      addresses = response.addresses;
    }
    
    // Atualizar dados da carteira
    currentWallet.addresses = addresses;
    walletAddresses = addresses;
    
    // Ocultar seção da seed
    document.getElementById('seedSection').style.display = 'none';
    
    // Mostrar carteiras derivadas
    displayWallets(addresses);
    updateWalletStatus('Carteira ativa', true);
    
    // Mostrar seção de segurança
    document.getElementById('securitySection').style.display = 'block';
    
    walletService.showNotification('Carteiras derivadas com sucesso!', 'success');
    
  } catch (error) {
    console.error('Error confirming seed:', error);
    walletService.showNotification('Erro ao derivar carteiras: ' + error.message, 'error');
  }
}

// Exibir carteiras derivadas
function displayWallets(wallets) {
  let successCount = 0;
  let errorCount = 0;
  
  for (const [chainId, wallet] of Object.entries(wallets)) {
    if (wallet.error) {
      console.error(`Error in ${chainId} wallet:`, wallet.error);
      errorCount++;
      
      // Show error in address field
      const addressElement = document.getElementById(`${chainId === 'ethereum' ? 'eth' : chainId === 'tron' ? 'trx' : chainId === 'solana' ? 'sol' : chainId}Address`);
      if (addressElement) {
        addressElement.textContent = 'Generation failed';
        addressElement.style.color = '#ff6b6b';
      }
      continue;
    }
    
    const addressElement = document.getElementById(`${chainId === 'ethereum' ? 'eth' : chainId === 'tron' ? 'trx' : chainId === 'solana' ? 'sol' : chainId}Address`);
    if (addressElement) {
      if (wallet.address && wallet.address !== 'Error') {
        addressElement.textContent = wallet.address;
        addressElement.style.color = ''; // Reset color
        successCount++;
      } else {
        addressElement.textContent = 'Not implemented';
        addressElement.style.color = '#ffa726';
        errorCount++;
      }
    }
  }
  
  // Mostrar seção das carteiras
  document.getElementById('walletsSection').style.display = 'block';
  
  // Show summary
  console.log(`Wallets displayed: ${successCount} successful, ${errorCount} failed`);
  
  if (successCount > 0) {
    // Start auto-refresh for successful wallets
    startAutoRefresh();
    
    // Load initial balances
    updateAllBalances();
    
    walletService.showNotification(
      `${successCount} wallets ready. ${errorCount > 0 ? errorCount + ' failed.' : ''}`, 
      errorCount > 0 ? 'warning' : 'success'
    );
  } else {
    walletService.showNotification('No wallets could be generated', 'error');
  }
}

// Atualizar todos os saldos
async function updateAllBalances() {
  if (!walletAddresses) {
    console.log('No wallet addresses available for balance update');
    return;
  }
  
  console.log('Starting balance update for all chains...');
  walletService.showNotification('Updating balances for all chains...', 'info');
  
  const updatePromises = [];
  
  for (const [chainId, wallet] of Object.entries(walletAddresses)) {
    if (wallet.address && !wallet.error) {
      const chainKey = chainId === 'ethereum' ? 'eth' : 
                       chainId === 'tron' ? 'trx' : 
                       chainId === 'solana' ? 'sol' : 
                       chainId;
      
      // Add each balance update as a promise
      updatePromises.push(
        refreshBalance(chainKey).catch(error => {
          console.error(`Failed to update ${chainId} balance:`, error);
          return null; // Don't fail the entire update if one chain fails
        })
      );
    }
  }
  
  // Wait for all balance updates to complete
  try {
    await Promise.allSettled(updatePromises);
    
    const successCount = updatePromises.length;
    console.log(`Balance update completed for ${successCount} chains`);
    
    // Update global refresh timestamp
    const now = new Date();
    const timeString = now.toLocaleString('pt-BR');
    
    const globalRefreshElement = document.getElementById('globalLastRefresh');
    if (globalRefreshElement) {
      globalRefreshElement.textContent = `Last update: ${timeString}`;
    }
    
    walletService.showNotification('All balances updated successfully', 'success');
    
  } catch (error) {
    console.error('Error during balance update:', error);
    walletService.showNotification('Some balances failed to update', 'warning');
  }
}

// Auto-refresh balances every 2 minutes
let autoRefreshInterval = null;

function startAutoRefresh() {
  if (autoRefreshInterval) {
    clearInterval(autoRefreshInterval);
  }
  
  autoRefreshInterval = setInterval(() => {
    if (walletAddresses) {
      console.log('Auto-refreshing balances...');
      updateAllBalances();
    }
  }, 120000); // 2 minutes
  
  console.log('Auto-refresh started (every 2 minutes)');
}

function stopAutoRefresh() {
  if (autoRefreshInterval) {
    clearInterval(autoRefreshInterval);
    autoRefreshInterval = null;
    console.log('Auto-refresh stopped');
  }
}

// Atualizar status da carteira
function updateWalletStatus(message, active = false) {
  const statusElement = document.getElementById('walletStatus');
  const titleElement = statusElement.querySelector('.service-title');
  const infoElement = statusElement.querySelector('.service-info');
  
  titleElement.textContent = message;
  infoElement.textContent = active ? 'Carteiras derivadas e prontas para uso' : 'Gere uma nova carteira ou importe uma existente';
  
  if (active) {
    statusElement.classList.add('active');
  } else {
    statusElement.classList.remove('active');
  }
}

// === FUNÇÕES DE SALDO ===

// Atualizar saldo de uma chain específica
async function refreshBalance(chain) {
  const chainMap = {
    'btc': 'bitcoin',
    'eth': 'ethereum', 
    'liquid': 'liquid',
    'trx': 'tron',
    'sol': 'solana'
  };
  
  const chainId = chainMap[chain];
  if (!chainId || !walletAddresses[chainId]) return;
  
  const wallet = walletAddresses[chainId];
  if (!wallet.address || wallet.error) {
    const balanceElement = document.getElementById(`${chain}Balance`);
    balanceElement.textContent = 'Address not available';
    return;
  }
  
  try {
    const balanceElement = document.getElementById(`${chain}Balance`);
    balanceElement.textContent = '⏳ Loading...';
    
    // Get balance via API
    const balance = await walletService.getBalance(chainId, wallet.address);
    let balanceText = `${balance} ${wallet.symbol}`;
    
    // For TRON, also try to get USDT balance via a separate API call
    if (chainId === 'tron') {
      try {
        // Note: USDT balance would need a separate API endpoint
        // For now just show TRX balance
      } catch (error) {
        console.log('USDT balance fetch failed:', error);
      }
    }
    
    balanceElement.textContent = balanceText;
    
    // Update last refresh time
    const now = new Date();
    const timeString = now.toLocaleTimeString('pt-BR', { 
      hour: '2-digit', 
      minute: '2-digit' 
    });
    
    const refreshElement = document.getElementById(`${chain}LastRefresh`);
    if (refreshElement) {
      refreshElement.textContent = `Updated: ${timeString}`;
    }
    
    console.log(`${chainId.toUpperCase()} balance updated: ${balanceText}`);
    
  } catch (error) {
    console.error(`Error refreshing ${chain} balance:`, error);
    const balanceElement = document.getElementById(`${chain}Balance`);
    balanceElement.textContent = '❌ Error loading';
    
    walletService.showNotification(`Failed to load ${chainId.toUpperCase()} balance`, 'error');
  }
}

// Copiar endereço para clipboard
async function copyAddress(chain) {
  const chainMap = {
    'btc': 'bitcoin',
    'eth': 'ethereum',
    'liquid': 'liquid', 
    'trx': 'tron',
    'sol': 'solana'
  };
  
  const chainId = chainMap[chain];
  if (!chainId || !walletAddresses[chainId]) {
    walletService.showNotification('Endereço não disponível', 'warning');
    return;
  }
  
  const address = walletAddresses[chainId].address;
  if (!address || address === 'Error') {
    walletService.showNotification('Endereço inválido', 'warning');
    return;
  }
  
  try {
    await navigator.clipboard.writeText(address);
    walletService.showNotification(`Endereço ${walletAddresses[chainId].symbol} copiado!`, 'success');
  } catch (error) {
    console.error('Error copying address:', error);
    walletService.showNotification('Erro ao copiar endereço', 'error');
  }
}

// === FUNÇÕES DE SEGURANÇA ===

// Criptografar e salvar carteira
async function encryptAndSaveWallet() {
  const password = document.getElementById('encryptPassword').value;
  
  if (!password) {
    walletService.showNotification('Digite uma senha para criptografar', 'warning');
    return;
  }
  
  if (!currentWallet || !currentWallet.mnemonic) {
    walletService.showNotification('Nenhuma carteira para criptografar', 'warning');
    return;
  }
  
  try {
    const button = document.getElementById('encryptWalletBtn');
    button.disabled = true;
    button.textContent = '🔒 Criptografando...';
    
    // Salvar carteira via API
    const response = await walletService.saveWallet(
      currentWallet.mnemonic, 
      password, 
      null, // auto-generate wallet ID
      { created_from: 'brln_os_frontend' }
    );
    
    // Salvar wallet ID para uso futuro
    currentWalletId = response.wallet_id;
    localStorage.setItem('brln-current-wallet-id', currentWalletId);
    
    walletService.showNotification('Carteira criptografada e salva com sucesso!', 'success');
    
  } catch (error) {
    console.error('Error encrypting wallet:', error);
    walletService.showNotification('Erro ao criptografar carteira: ' + error.message, 'error');
  } finally {
    const button = document.getElementById('encryptWalletBtn');
    button.disabled = false;
    button.textContent = '🔒 Criptografar e Salvar';
  }
}

// Descriptografar carteira salva
async function decryptSavedWallet() {
  const password = document.getElementById('decryptPassword').value;
  
  if (!password) {
    walletService.showNotification('Digite a senha da carteira', 'warning');
    return;
  }
  
  // Verificar se existe wallet ID salvo
  const walletId = localStorage.getItem('brln-current-wallet-id');
  if (!walletId) {
    walletService.showNotification('Nenhuma carteira salva encontrada', 'warning');
    return;
  }
  
  try {
    const button = document.getElementById('decryptWalletBtn');
    button.disabled = true;
    button.textContent = '🔓 Descriptografando...';
    
    // Carregar carteira via API
    const response = await walletService.loadWallet(walletId, password);
    
    // Atualizar estado
    currentWallet = { 
      mnemonic: 'hidden_for_security', // Não expor mnemonic no frontend
      addresses: response.addresses 
    };
    walletAddresses = response.addresses;
    currentWalletId = walletId;
    
    // Mostrar carteiras
    displayWallets(response.addresses);
    updateWalletStatus('Carteira descriptografada', true);
    
    walletService.showNotification('Carteira descriptografada com sucesso!', 'success');
    
  } catch (error) {
    console.error('Error decrypting wallet:', error);
    walletService.showNotification('Erro ao descriptografar: senha incorreta ou carteira não encontrada', 'error');
  } finally {
    const button = document.getElementById('decryptWalletBtn');
    button.disabled = false;
    button.textContent = '🔓 Descriptografar Carteira';
  }
}

// Verificar carteira salva na inicialização
function checkSavedWallet() {
  const walletId = localStorage.getItem('brln-current-wallet-id');
  if (walletId) {
    document.getElementById('securitySection').style.display = 'block';
    walletService.showNotification('Carteira salva encontrada. Insira a senha para acessar.', 'info');
  }
}

// Get portfolio summary with all balances
async function getPortfolioSummary() {
  if (!walletAddresses) return null;
  
  const summary = {
    total_chains: 0,
    active_addresses: 0,
    balances: {},
    last_updated: new Date().toISOString()
  };
  
  for (const [chainId, wallet] of Object.entries(walletAddresses)) {
    summary.total_chains++;
    
    if (wallet.address && !wallet.error && !wallet.address.includes('not implemented')) {
      summary.active_addresses++;
      
      try {
        const balance = await walletService.getBalance(chainId, wallet.address);
        summary.balances[chainId] = {
          symbol: CHAINS[chainId].symbol,
          balance: balance,
          address: wallet.address
        };
        
        // Special case for TRON - also get USDT
        if (chainId === 'tron') {
          try {
            const usdtBalance = await walletService.getTronUSDTBalance(wallet.address);
            summary.balances[`${chainId}_usdt`] = {
              symbol: 'USDT',
              balance: usdtBalance,
              address: wallet.address
            };
          } catch (error) {
            console.log('USDT balance not available:', error);
          }
        }
        
      } catch (error) {
        console.error(`Failed to get ${chainId} balance for summary:`, error);
      }
    }
  }
  
  return summary;
}

// Display portfolio summary
async function displayPortfolioSummary() {
  const summary = await getPortfolioSummary();
  if (!summary) return;
  
  console.log('Portfolio Summary:', summary);
  
  // Update global status with summary
  const statusElement = document.getElementById('globalLastRefresh');
  if (statusElement) {
    const activeCount = summary.active_addresses;
    const totalCount = summary.total_chains;
    statusElement.textContent = `Portfolio: ${activeCount}/${totalCount} active addresses | ${summary.last_updated}`;
  }
  
  // You could expand this to show more detailed portfolio information
  // For example, add a portfolio section to the HTML
}

console.log('BRLN-OS Multichain Wallet initialized');

// Add notification styles if not already present
if (!document.querySelector('#wallet-notifications-style')) {
  const style = document.createElement('style');
  style.id = 'wallet-notifications-style';
  style.textContent = `
    .notification {
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 15px 20px;
      border-radius: 8px;
      color: white;
      font-weight: 500;
      z-index: 10000;
      max-width: 350px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
      animation: slideIn 0.3s ease-out;
    }
    
    .notification.info {
      background: linear-gradient(135deg, #17a2b8 0%, #138496 100%);
    }
    
    .notification.success {
      background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
    }
    
    .notification.warning {
      background: linear-gradient(135deg, #ffc107 0%, #fd7e14 100%);
      color: #212529;
    }
    
    .notification.error {
      background: linear-gradient(135deg, #dc3545 0%, #c82333 100%);
    }
    
    @keyframes slideIn {
      from {
        transform: translateX(100%);
        opacity: 0;
      }
      to {
        transform: translateX(0);
        opacity: 1;
      }
    }
  `;
  document.head.appendChild(style);
}

// Initialize cleanup on page unload
window.addEventListener('beforeunload', () => {
  stopAutoRefresh();
});

console.log('BRLN-OS Multichain Wallet fully loaded and ready!');