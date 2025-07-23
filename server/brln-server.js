const express = require('express');
const cors = require('cors');
const fs = require('fs');
const { exec } = require('child_process');
const path = require('path');

// Importar projeto Lightning + Elements modificado
// Usar caminho absoluto para evitar problemas
const lightningPath = path.join(__dirname, '..', 'index.js');
const lightning = require(lightningPath);

const app = express();
const PORT = 5003; // Mesma porta que seu frontend espera

// Middleware
app.use(cors());
app.use(express.json());

// Variáveis globais para clientes
let lndClient = null;
let elementsClient = null;

// ====================================================================
// CONFIGURAÇÃO DE REDE - ALTERE AQUI PARA TROCAR ENTRE TESTNET/MAINNET
// ====================================================================
const NETWORK_MODE = process.env.NETWORK_MODE || 'testnet'; // 'testnet' ou 'mainnet'

// Configurações por rede
const NETWORK_CONFIG = {
  testnet: {
    elements: {
      port: 7040,
      chain: 'liquidtestnet'
    },
    lnd: {
      macaroonPath: '/data/lnd/data/chain/bitcoin/testnet/admin.macaroon'
    }
  },
  mainnet: {
    elements: {
      port: 7041,
      chain: 'liquidv1'
    },
    lnd: {
      macaroonPath: '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
    }
  }
};

// Configurações baseadas no brln-os
const config = {
  network: NETWORK_MODE,
  elements: {
    host: process.env.ELEMENTS_HOST || 'localhost',
    port: parseInt(process.env.ELEMENTS_PORT) || NETWORK_CONFIG[NETWORK_MODE].elements.port,
    user: process.env.ELEMENTS_RPC_USER || 'test',
    password: process.env.ELEMENTS_RPC_PASSWORD || 'test',
    chain: NETWORK_CONFIG[NETWORK_MODE].elements.chain
  },
  lnd: {
    socket: process.env.LND_HOST || 'localhost:10009',
    certPath: process.env.LND_TLS_CERT_PATH || '/data/lnd/tls.cert',
    macaroonPath: process.env.LND_MACAROON_PATH || NETWORK_CONFIG[NETWORK_MODE].lnd.macaroonPath
  }
};

// Inicializar clientes
async function initializeClients() {
  console.log('🔧 Inicializando clientes Lightning + Elements...');
  console.log(`🌐 Modo de rede: ${config.network.toUpperCase()}`);
  console.log(`🌊 Elements: ${config.elements.host}:${config.elements.port} (${config.elements.chain})`);
  console.log(`⚡ LND: ${config.lnd.socket} (${config.network})`);
  
  // Inicializar Elements Client
  try {
    const elementsRpc = lightning.elementsRpc(config.elements);
    elementsClient = elementsRpc.elements;
    
    // Testar conexão
    await lightning.getElementsInfo({ elements: elementsClient });
    console.log('✅ Elements conectado:', config.elements.host + ':' + config.elements.port);
  } catch (error) {
    const errorMsg = error?.message || error?.toString() || 'Erro desconhecido na conexão Elements';
    console.warn('⚠️ Elements não disponível:', errorMsg);
    elementsClient = null;
  }

  // Inicializar LND Client
  try {
    if (fs.existsSync(config.lnd.certPath) && fs.existsSync(config.lnd.macaroonPath)) {
      const { lnd } = lightning.authenticatedLndGrpc({
        cert: fs.readFileSync(config.lnd.certPath),
        macaroon: fs.readFileSync(config.lnd.macaroonPath),
        socket: config.lnd.socket
      });
      
      lndClient = lnd;
      
      // Testar conexão
      await lightning.getWalletInfo({ lnd: lndClient });
      console.log('✅ LND conectado:', config.lnd.socket);
    }
  } catch (error) {
    const errorMsg = error?.message || error?.toString() || 'Erro desconhecido na conexão LND';
    console.warn('⚠️ LND não disponível:', errorMsg);
    lndClient = null;
  }
}

// ====================================================================
// ENDPOINTS COMPATÍVEIS COM SEU FRONTEND EXISTENTE
// ====================================================================

// Health check (usado pelo seu checkBRLNRPCServerStatus)
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '2.0.0-lightning-elements',
    service: 'BRLN-Lightning-Elements-Server',
    clients: {
      lnd: lndClient ? 'connected' : 'disconnected',
      elements: elementsClient ? 'connected' : 'disconnected'
    }
  });
});

// Status de serviços (usado pelo seu toggleService)
app.get('/service-status', (req, res) => {
  const { app: appName } = req.query;
  
  exec(`docker ps --filter "name=${appName}" --format "{{.Status}}"`, (error, stdout) => {
    if (error) {
      return res.json({ active: false, error: error.message });
    }
    
    const isRunning = stdout.trim().includes('Up');
    res.json({ active: isRunning });
  });
});

// Toggle serviços (usado pelo seu toggleService)
app.post('/toggle-service', (req, res) => {
  const { app: appName } = req.query;
  
  // Primeiro verificar status atual
  exec(`docker ps --filter "name=${appName}" --format "{{.Status}}"`, (error, stdout) => {
    if (error) {
      return res.json({ success: false, error: error.message });
    }
    
    const isRunning = stdout.trim().includes('Up');
    const action = isRunning ? 'stop' : 'start';
    
    exec(`docker ${action} ${appName}`, (error, stdout) => {
      if (error) {
        return res.json({ success: false, error: error.message });
      }
      
      res.json({ 
        success: true, 
        action: action,
        message: `Container ${appName} ${action}ed successfully`
      });
    });
  });
});

// Saldos das carteiras (usado pelo seu updateWalletBalances)
app.get('/wallet-balances', async (req, res) => {
  try {
    const balances = {
      success: true,
      timestamp: new Date().toISOString(),
      lnd_status: lndClient ? 'connected' : 'disconnected',
      elements_status: elementsClient ? 'connected' : 'disconnected'
    };

    // Saldo Lightning
    if (lndClient) {
      try {
        const channelBalance = await lightning.getChannelBalance({ lnd: lndClient });
        balances.lightning = parseInt(channelBalance.channel_balance);
      } catch (error) {
        balances.lightning = null;
        console.warn('Erro ao obter saldo Lightning:', error.message);
      }

      // Saldo Bitcoin On-chain via LND
      try {
        const chainBalance = await lightning.getChainBalance({ lnd: lndClient });
        balances.bitcoin = parseInt(chainBalance.chain_balance);
      } catch (error) {
        balances.bitcoin = null;
        console.warn('Erro ao obter saldo Bitcoin:', error.message);
      }
    } else {
      balances.lightning = null;
      balances.bitcoin = null;
    }

    // Saldo Elements/Liquid
    if (elementsClient) {
      try {
        const elementsBalance = await lightning.getElementsBalance({ elements: elementsClient });
        balances.elements = parseFloat(elementsBalance.balance);

        // Assets Liquid
        const assets = await lightning.getLiquidAssets({ elements: elementsClient });
        balances.liquid_assets = assets.assets;
      } catch (error) {
        balances.elements = null;
        balances.liquid_assets = [];
        // Melhor tratamento de erro para evitar "undefined"
        const errorMsg = error?.message || error?.toString() || 'Erro desconhecido na conexão Elements';
        console.warn('Erro ao obter saldo Elements:', errorMsg);
      }
    } else {
      balances.elements = null;
      balances.liquid_assets = [];
    }

    res.json(balances);
  } catch (error) {
    res.json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// ====================================================================
// NOVOS ENDPOINTS PARA LIGHTNING + ELEMENTS
// ====================================================================

// Criar endereços
app.post('/create-address', async (req, res) => {
  try {
    const { network, type = 'bech32' } = req.body;

    if (network === 'lightning' && lndClient) {
      const address = await lightning.createChainAddress({
        lnd: lndClient,
        format: type
      });
      res.json({ success: true, address: address.address, network });
      
    } else if (network === 'liquid' && elementsClient) {
      const address = await lightning.createElementsAddress({
        elements: elementsClient,
        format: type
      });
      res.json({ success: true, address: address.address, network });
      
    } else {
      res.status(400).json({ 
        success: false, 
        error: `Rede ${network} não disponível ou não suportada` 
      });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Enviar transações
app.post('/send-transaction', async (req, res) => {
  try {
    const { network, address, amount, asset = 'bitcoin' } = req.body;

    if (!address || !amount) {
      return res.status(400).json({ 
        success: false, 
        error: 'Endereço e valor são obrigatórios' 
      });
    }

    const tokens = Math.round(amount * 100000000); // Converter para satoshis

    if (network === 'lightning' && lndClient) {
      const result = await lightning.sendToChainAddress({
        lnd: lndClient,
        address,
        tokens
      });
      res.json({ success: true, txid: result.id, network });
      
    } else if (network === 'liquid' && elementsClient) {
      const result = await lightning.sendToElementsAddress({
        elements: elementsClient,
        address,
        tokens,
        asset
      });
      res.json({ success: true, txid: result.id, network });
      
    } else {
      res.status(400).json({ 
        success: false, 
        error: `Rede ${network} não disponível` 
      });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Listar assets Liquid
app.get('/liquid-assets', async (req, res) => {
  try {
    if (!elementsClient) {
      return res.status(503).json({ 
        success: false, 
        error: 'Elements não disponível' 
      });
    }

    const assets = await lightning.getLiquidAssets({ elements: elementsClient });
    res.json({ success: true, assets: assets.assets });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Informações da rede
app.get('/network-info', async (req, res) => {
  try {
    const info = {
      timestamp: new Date().toISOString()
    };

    // Info LND
    if (lndClient) {
      try {
        const [walletInfo, peers] = await Promise.all([
          lightning.getWalletInfo({ lnd: lndClient }),
          lightning.getPeers({ lnd: lndClient })
        ]);
        
        info.lnd = {
          connected: true,
          alias: walletInfo.alias,
          peers: peers.peers.length,
          block_height: walletInfo.current_block_height
        };
      } catch (error) {
        info.lnd = { connected: false, error: error.message };
      }
    } else {
      info.lnd = { connected: false, error: 'Cliente não inicializado' };
    }

    // Info Elements
    if (elementsClient) {
      try {
        const elementsInfo = await lightning.getElementsInfo({ elements: elementsClient });
        info.elements = {
          connected: true,
          chain: elementsInfo.chain,
          blocks: elementsInfo.blocks,
          difficulty: elementsInfo.difficulty
        };
      } catch (error) {
        info.elements = { connected: false, error: error.message };
      }
    } else {
      info.elements = { connected: false, error: 'Cliente não inicializado' };
    }

    res.json(info);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Inicializar servidor
async function startServer() {
  await initializeClients();
  
  app.listen(PORT, '0.0.0.0', () => {
    console.log('====================================================================');
    console.log('🚀 BRLN-OS Lightning + Elements Server');
    console.log('====================================================================');
    console.log(`📡 Server: http://localhost:${PORT}`);
    console.log(`🌐 Rede: ${config.network.toUpperCase()}`);
    console.log(`⚡ LND: ${lndClient ? '✅ Conectado' : '❌ Desconectado'} (${config.lnd.socket})`);
    console.log(`🌊 Elements: ${elementsClient ? '✅ Conectado' : '❌ Desconectado'} (${config.elements.chain})`);
    console.log('📱 Frontend pode acessar todos os endpoints em:', `http://localhost:${PORT}`);
    console.log('====================================================================');
    console.log('💡 Para alterar rede: export NETWORK_MODE=mainnet ou testnet');
    console.log('====================================================================');
  });
}

// Tratamento de erros
process.on('uncaughtException', (error) => {
  console.error('❌ Erro não capturado:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Rejeição não tratada:', reason);
});

// Iniciar servidor
startServer().catch(console.error);
