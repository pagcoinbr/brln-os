const express = require('express');
const cors = require('cors');
const path = require('path');
const lightning = require('../index');
const config = require('../config/brln-elements-config');

const app = express();
const PORT = process.env.API_PORT || 5010;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../../html'))); // Servir arquivos estáticos do frontend

// Configurações globais
let elementsClient = null;
let lndClient = null;

// Inicializar conexões
async function initializeConnections() {
  try {
    console.log('🔧 Inicializando conexões...');
    
    // Conectar Elements
    const {elements: elementsConfig} = config.loadConfig();
    const {elements} = lightning.elementsRpc(elementsConfig);
    elementsClient = elements;
    console.log('✅ Elements conectado');
    
    // Conectar LND (se disponível)
    try {
      const fs = require('fs');
      const {lnd: lndConfig} = config.loadConfig();
      
      if (fs.existsSync(lndConfig.cert) && fs.existsSync(lndConfig.macaroon)) {
        const {lnd} = lightning.authenticatedLndGrpc({
          cert: fs.readFileSync(lndConfig.cert),
          macaroon: fs.readFileSync(lndConfig.macaroon),
          socket: lndConfig.socket
        });
        lndClient = lnd;
        console.log('✅ LND conectado');
      }
    } catch (lndError) {
      console.log('⚠️ LND não disponível:', lndError.message);
    }
    
  } catch (error) {
    console.error('❌ Erro ao inicializar conexões:', error.message);
  }
}

// === ENDPOINTS PARA O FRONTEND ===

// Status geral do sistema
app.get('/api/status', async (req, res) => {
  try {
    const status = {
      timestamp: new Date().toISOString(),
      elements: {
        connected: !!elementsClient,
        info: null
      },
      lnd: {
        connected: !!lndClient,
        info: null
      }
    };

    // Tentar obter informações Elements
    if (elementsClient) {
      try {
        status.elements.info = await lightning.getElementsInfo({elements: elementsClient});
      } catch (err) {
        status.elements.connected = false;
        status.elements.error = err.message;
      }
    }

    // Tentar obter informações LND
    if (lndClient) {
      try {
        status.lnd.info = await lightning.getWalletInfo({lnd: lndClient});
      } catch (err) {
        status.lnd.connected = false;
        status.lnd.error = err.message;
      }
    }

    res.json(status);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Saldos de todas as redes
app.get('/api/balances', async (req, res) => {
  try {
    const balances = {
      liquid: null,
      bitcoin: null,
      lightning: null
    };

    // Saldo Liquid (L-BTC)
    if (elementsClient) {
      try {
        const liquidBalance = await lightning.getElementsBalance({elements: elementsClient});
        balances.liquid = {
          lbtc: liquidBalance.balance,
          asset: 'bitcoin'
        };
      } catch (err) {
        balances.liquid = {error: err.message};
      }
    }

    // Saldos Bitcoin e Lightning via LND
    if (lndClient) {
      try {
        const chainBalance = await lightning.getChainBalance({lnd: lndClient});
        balances.bitcoin = {
          confirmed: chainBalance.chain_balance,
          unconfirmed: chainBalance.unconfirmed_balance
        };
      } catch (err) {
        balances.bitcoin = {error: err.message};
      }

      try {
        const channelBalance = await lightning.getChannelBalance({lnd: lndClient});
        balances.lightning = {
          local: channelBalance.channel_balance,
          remote: channelBalance.channel_balance_mtokens
        };
      } catch (err) {
        balances.lightning = {error: err.message};
      }
    }

    res.json(balances);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Listar Liquid Assets
app.get('/api/liquid/assets', async (req, res) => {
  try {
    if (!elementsClient) {
      return res.status(503).json({error: 'Elements não conectado'});
    }

    const assets = await lightning.getLiquidAssets({elements: elementsClient});
    res.json(assets);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Criar endereço Liquid
app.post('/api/liquid/address', async (req, res) => {
  try {
    if (!elementsClient) {
      return res.status(503).json({error: 'Elements não conectado'});
    }

    const {label, format} = req.body;
    const address = await lightning.createElementsAddress({
      elements: elementsClient,
      label: label || 'Frontend Generated',
      format: format || 'bech32'
    });

    res.json(address);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Criar endereço Bitcoin (via LND)
app.post('/api/bitcoin/address', async (req, res) => {
  try {
    if (!lndClient) {
      return res.status(503).json({error: 'LND não conectado'});
    }

    const {format} = req.body;
    const address = await lightning.createChainAddress({
      lnd: lndClient,
      format: format || 'p2wpkh'
    });

    res.json(address);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Enviar L-BTC
app.post('/api/liquid/send', async (req, res) => {
  try {
    if (!elementsClient) {
      return res.status(503).json({error: 'Elements não conectado'});
    }

    const {address, amount, description} = req.body;
    
    if (!address || !amount) {
      return res.status(400).json({error: 'Endereço e valor são obrigatórios'});
    }

    const transaction = await lightning.sendToElementsAddress({
      elements: elementsClient,
      address,
      tokens: parseInt(amount), // em satoshis
      description: description || 'Enviado via BRLN-OS Frontend'
    });

    res.json(transaction);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Enviar Bitcoin (via LND)
app.post('/api/bitcoin/send', async (req, res) => {
  try {
    if (!lndClient) {
      return res.status(503).json({error: 'LND não conectado'});
    }

    const {address, amount, fee_rate} = req.body;
    
    if (!address || !amount) {
      return res.status(400).json({error: 'Endereço e valor são obrigatórios'});
    }

    const transaction = await lightning.sendToChainAddress({
      lnd: lndClient,
      address,
      tokens: parseInt(amount),
      fee_tokens_per_vbyte: fee_rate || 1
    });

    res.json(transaction);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Criar invoice Lightning
app.post('/api/lightning/invoice', async (req, res) => {
  try {
    if (!lndClient) {
      return res.status(503).json({error: 'LND não conectado'});
    }

    const {amount, description, expiry} = req.body;
    
    if (!amount) {
      return res.status(400).json({error: 'Valor é obrigatório'});
    }

    const invoice = await lightning.createInvoice({
      lnd: lndClient,
      tokens: parseInt(amount),
      description: description || 'Invoice gerado via BRLN-OS',
      expires_at: expiry ? new Date(Date.now() + expiry * 1000).toISOString() : undefined
    });

    res.json(invoice);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Pagar invoice Lightning
app.post('/api/lightning/pay', async (req, res) => {
  try {
    if (!lndClient) {
      return res.status(503).json({error: 'LND não conectado'});
    }

    const {payment_request, max_fee} = req.body;
    
    if (!payment_request) {
      return res.status(400).json({error: 'Payment request é obrigatório'});
    }

    const payment = await lightning.pay({
      lnd: lndClient,
      request: payment_request,
      max_fee: max_fee || 100
    });

    res.json(payment);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Histórico de transações Elements
app.get('/api/liquid/transactions', async (req, res) => {
  try {
    if (!elementsClient) {
      return res.status(503).json({error: 'Elements não conectado'});
    }

    // Por simplicidade, retornamos info básica
    // Em produção, seria implementado um sistema de histórico
    const info = await lightning.getElementsInfo({elements: elementsClient});
    res.json({
      message: 'Funcionalidade em desenvolvimento',
      latest_block: info.blocks,
      chain: info.chain
    });
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Informações detalhadas do nó
app.get('/api/node/info', async (req, res) => {
  try {
    const nodeInfo = {};

    if (lndClient) {
      try {
        const lndInfo = await lightning.getWalletInfo({lnd: lndClient});
        const networkInfo = await lightning.getNetworkInfo({lnd: lndClient});
        nodeInfo.lnd = {
          ...lndInfo,
          network: networkInfo
        };
      } catch (err) {
        nodeInfo.lnd = {error: err.message};
      }
    }

    if (elementsClient) {
      try {
        const elementsInfo = await lightning.getElementsInfo({elements: elementsClient});
        nodeInfo.elements = elementsInfo;
      } catch (err) {
        nodeInfo.elements = {error: err.message};
      }
    }

    res.json(nodeInfo);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    services: {
      elements: !!elementsClient,
      lnd: !!lndClient
    }
  });
});

// Servir frontend na raiz
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../../html/index.html'));
});

// Inicializar servidor
async function startServer() {
  await initializeConnections();
  
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 BRLN-OS Lightning+Elements API rodando em http://localhost:${PORT}`);
    console.log(`🌐 Frontend disponível em http://localhost:${PORT}`);
    console.log(`📊 API base: http://localhost:${PORT}/api`);
  });
}

// Tratamento de erros
process.on('uncaughtException', (err) => {
  console.error('❌ Erro não capturado:', err);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Promise rejeitada:', reason);
});

// Iniciar servidor se executado diretamente
if (require.main === module) {
  startServer().catch(console.error);
}

module.exports = {app, startServer};
