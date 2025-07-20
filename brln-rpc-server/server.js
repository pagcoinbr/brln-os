#!/usr/bin/env node

/**
 * BRLN-RPC-Server
 * Servidor HTTP Multi-Chain para Bitcoin, Lightning e Liquid
 * Estendido para funcionalidades específicas do BRLN-OS
 */

const express = require('express');
const cors = require('cors');
const { exec, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');

// Configuração
const CONFIG_FILE = process.env.CONFIG_FILE || path.join(__dirname, 'config', 'config.json');
let config;

try {
  config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
} catch (error) {
  console.error('❌ Erro ao carregar configuração:', error.message);
  process.exit(1);
}

const app = express();
const PORT = config.server.port || 5001;

// Middleware
app.use(express.json());
app.use(cors({
  origin: config.server.cors?.origins || ['*'],
  credentials: true
}));

// Logging
const logDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

function log(message, level = 'info') {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [${level.toUpperCase()}] ${message}\n`;
  
  console.log(logMessage.trim());
  fs.appendFileSync(path.join(logDir, 'brln-rpc-server.log'), logMessage);
}

// Verificação de autenticação
function authenticateRequest(req, res, next) {
  const providedKey = req.headers['x-secret-key'] || req.query.key;
  const clientIP = req.ip || req.connection.remoteAddress;
  
  // Verificar chave secreta
  if (providedKey !== config.server.secretKey) {
    log(`❌ Acesso negado - chave inválida de IP: ${clientIP}`, 'warn');
    return res.status(401).json({ error: 'Chave secreta inválida' });
  }
  
  next();
}

// Configuração gRPC para LND
let lndClient = null;

async function initLNDConnection() {
  try {
    // Carregar proto
    const packageDefinition = protoLoader.loadSync(path.join(__dirname, 'lightning.proto'), {
      keepCase: true,
      longs: String,
      enums: String,
      defaults: true,
      oneofs: true,
    });
    
    const lightning = grpc.loadPackageDefinition(packageDefinition).lnrpc;
    
    // Ler certificados
    const tlsCert = fs.readFileSync(config.lnd.tlsCertPath);
    const sslCredentials = grpc.credentials.createSsl(tlsCert);
    
    const macaroon = fs.readFileSync(config.lnd.macaroonPath);
    const metadata = new grpc.Metadata();
    metadata.add('macaroon', macaroon.toString('hex'));
    
    const macaroonCredentials = grpc.credentials.createFromMetadataGenerator((_, callback) => {
      callback(null, metadata);
    });
    
    const combinedCredentials = grpc.credentials.combineChannelCredentials(
      sslCredentials,
      macaroonCredentials
    );
    
    lndClient = new lightning.Lightning(config.lnd.host, combinedCredentials);
    
    // Testar conexão
    await new Promise((resolve, reject) => {
      lndClient.getInfo({}, (err, response) => {
        if (err) reject(err);
        else resolve(response);
      });
    });
    
    log('✅ Conexão LND estabelecida com sucesso');
    return true;
  } catch (error) {
    log(`❌ Erro ao conectar com LND: ${error.message}`, 'error');
    return false;
  }
}

// Função para executar comandos Elements/Liquid
function executeElementsCommand(command, args = []) {
  return new Promise((resolve, reject) => {
    const fullCommand = `docker exec elements elements-cli ${command} ${args.join(' ')}`;
    
    exec(fullCommand, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(`Elements command failed: ${error.message}`));
        return;
      }
      
      if (stderr && !stderr.includes('warning')) {
        reject(new Error(`Elements stderr: ${stderr}`));
        return;
      }
      
      try {
        // Tentar parsear como JSON, senão retornar como string
        const result = JSON.parse(stdout.trim());
        resolve(result);
      } catch {
        resolve(stdout.trim());
      }
    });
  });
}

// Função para executar comandos Docker
function executeDockerCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, { cwd: '/root/brln-os/container' }, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(`Docker command failed: ${error.message}`));
        return;
      }
      resolve(stdout.trim());
    });
  });
}

// === ROTAS DA API ===

// Status de saúde
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    service: 'BRLN-RPC-Server'
  });
});

// Endpoint para status de novidades (compatibilidade com radio.js)
app.get('/status_novidade', (req, res) => {
  res.json({
    novidade: false,
    timestamp: new Date().toISOString(),
    message: 'Nenhuma novidade no momento'
  });
});

// === FUNCIONALIDADES ESPECÍFICAS DO BRLN-OS ===

// Mapeamento de apps para serviços Docker
const APP_TO_SERVICE = {
  "brln-rpc-server": "brln-rpc-server", // Serviço systemd especial
  "lnd": "lnd",
  "bitcoin": "bitcoin",
  "bitcoind": "bitcoin", // alias
  "elements": "elements",
  "lnbits": "lnbits",
  "thunderhub": "thunderhub",
  "lndg": "lndg",
  "peerswap": "peerswap",
  "psweb": "psweb",
  "tor": "tor",
  "grafana": "grafana",
  "electrum": "electrum" // Futuro suporte
};

// Verificar status de serviço Docker
async function getServiceStatus(serviceName) {
  try {
    const containerName = APP_TO_SERVICE[serviceName] || serviceName;
    const command = `docker ps --filter "name=${containerName}" --format "{{.Names}}" | grep -q "${containerName}" && echo "running" || echo "stopped"`;
    
    const result = await executeDockerCommand(command);
    return result.trim() === 'running';
  } catch (error) {
    log(`❌ Erro ao verificar status do serviço ${serviceName}: ${error.message}`, 'error');
    return false;
  }
}

// Status de serviço
app.get('/service-status', async (req, res) => {
  try {
    const appName = req.query.app;
    
    if (!appName || !APP_TO_SERVICE[appName]) {
      return res.status(400).json({ 
        error: "App inválido ou não informado",
        availableApps: Object.keys(APP_TO_SERVICE)
      });
    }

    const isActive = await getServiceStatus(appName);
    
    res.json({ 
      active: isActive,
      service: APP_TO_SERVICE[appName],
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    log(`❌ Erro no service-status: ${error.message}`, 'error');
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// Toggle de serviço (start/stop)
app.post('/toggle-service', async (req, res) => {
  try {
    const appName = req.query.app;
    
    if (!appName || !APP_TO_SERVICE[appName]) {
      return res.status(400).json({ 
        error: "App inválido ou não informado",
        availableApps: Object.keys(APP_TO_SERVICE)
      });
    }

    const serviceName = APP_TO_SERVICE[appName];
    const isRunning = await getServiceStatus(appName);
    
    const action = isRunning ? 'stop' : 'start';
    const command = `docker-compose ${action} ${serviceName}`;
    
    log(`🔄 Executando: ${command} para serviço ${serviceName}`);
    
    await executeDockerCommand(command);
    
    // Aguardar um momento para o serviço inicializar/parar
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const newStatus = await getServiceStatus(appName);
    
    res.json({ 
      success: true,
      action: action,
      service: serviceName,
      active: newStatus,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    log(`❌ Erro no toggle-service: ${error.message}`, 'error');
    res.status(500).json({ 
      success: false,
      error: error.message 
    });
  }
});

// === FUNCIONALIDADES DE SALDOS ===

// Saldos das carteiras (substituindo o endpoint Python)
app.get('/wallet-balances', async (req, res) => {
  try {
    const balances = {
      success: true,
      lnd_status: 'disconnected',
      elements_status: 'disconnected',
      lightning: 'Não disponível',
      bitcoin: 'Não disponível', 
      elements: 'Não disponível',
      timestamp: new Date().toISOString()
    };

    // Obter saldos LND (Lightning + Bitcoin on-chain)
    if (lndClient) {
      try {
        // Saldo Lightning (canais)
        const channelBalance = await new Promise((resolve, reject) => {
          lndClient.channelBalance({}, (err, response) => {
            if (err) reject(err);
            else resolve(response);
          });
        });

        // Saldo Bitcoin on-chain
        const walletBalance = await new Promise((resolve, reject) => {
          lndClient.walletBalance({}, (err, response) => {
            if (err) reject(err);
            else resolve(response);
          });
        });

        balances.lnd_status = 'connected';
        balances.lightning = `${parseInt(channelBalance.balance || 0).toLocaleString()} sats`;
        balances.bitcoin = `${parseInt(walletBalance.total_balance || 0).toLocaleString()} sats`;
        
        log('✅ Saldos LND obtidos com sucesso');
      } catch (error) {
        log(`❌ Erro ao obter saldos LND: ${error.message}`, 'error');
      }
    }

    // Obter saldo Elements/Liquid
    try {
      const elementsBalance = await executeElementsCommand('getbalance');
      balances.elements_status = 'connected';
      
      // Elements retorna um objeto com diferentes assets
      if (typeof elementsBalance === 'object') {
        // Criar uma string com todos os assets
        const assetBalances = [];
        
        for (const [asset, balance] of Object.entries(elementsBalance)) {
          if (parseFloat(balance) > 0) {
            let assetName = asset;
            // Identificar assets conhecidos
            if (asset === 'bitcoin') {
              assetName = 'L-BTC';
            } else if (asset.length === 64) {
              // Asset ID longo - mostrar apenas primeiros/últimos caracteres
              assetName = asset.substring(0, 8) + '...' + asset.substring(56);
            }
            assetBalances.push(`${parseFloat(balance).toFixed(8)} ${assetName}`);
          }
        }
        
        balances.elements = assetBalances.length > 0 ? assetBalances.join(' | ') : '0.00000000 L-BTC';
      } else {
        balances.elements = '0.00000000 L-BTC';
      }
      
      log('✅ Saldo Elements obtido com sucesso');
    } catch (error) {
      log(`❌ Erro ao obter saldo Elements: ${error.message}`, 'error');
    }

    res.json(balances);
    
  } catch (error) {
    log(`❌ Erro geral ao obter saldos: ${error.message}`, 'error');
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Toggle de serviços Docker (substituindo o endpoint Python)
app.post('/toggle-service', async (req, res) => {
  try {
    const { app } = req.query;
    
    if (!app) {
      return res.status(400).json({ error: 'Parâmetro app é obrigatório' });
    }

    const containerMap = {
      'lnd': 'lnd',
      'bitcoind': 'bitcoin',
      'bitcoin': 'bitcoin',
      'lnbits': 'lnbits', 
      'thunderhub': 'thunderhub',
      'lndg': 'lndg',
      'peerswap': 'peerswap',
      'tor': 'tor',
      'elements': 'elements',
      'grafana': 'grafana'
    };

    const containerName = containerMap[app] || app;
    
    // Verificar status atual
    const statusCommand = `docker ps --filter name=${containerName} --filter status=running --format "{{.Names}}"`;
    const currentStatus = await executeDockerCommand(statusCommand);
    const isRunning = currentStatus.includes(containerName);
    
    // Executar ação apropriada
    let action, command;
    if (isRunning) {
      action = 'stop';
      command = `docker-compose stop ${containerName}`;
    } else {
      action = 'start';
      command = `docker-compose up -d ${containerName}`;
    }
    
    log(`🔄 ${action.charAt(0).toUpperCase() + action.slice(1)}ando serviço: ${containerName}`);
    
    await executeDockerCommand(command);
    
    // Aguardar um momento para a mudança tomar efeito
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    res.json({
      success: true,
      action: action,
      app: app,
      container: containerName,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    log(`❌ Erro ao fazer toggle do serviço: ${error.message}`, 'error');
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// === ROTAS DO SERVIDOR LND-RPC-JS ORIGINAL ===
// (Aqui você pode importar as rotas existentes do servidor original)

// Middleware de erro
app.use((err, req, res, next) => {
  log(`❌ Erro interno: ${err.message}`, 'error');
  res.status(500).json({ error: 'Erro interno do servidor' });
});

// Inicialização do servidor
async function startServer() {
  log('🚀 Iniciando BRLN-RPC-Server...');
  
  // Inicializar conexão LND
  await initLNDConnection();
  
  // Iniciar servidor HTTP
  app.listen(PORT, config.server.host, () => {
    log(`✅ BRLN-RPC-Server rodando em http://${config.server.host}:${PORT}`);
    log(`📁 Logs em: ${path.join(__dirname, 'logs')}`);
    log(`⚙️ Configuração: ${CONFIG_FILE}`);
  });
}

// Tratamento de sinais
process.on('SIGTERM', () => {
  log('📝 Recebido SIGTERM, encerrando servidor...');
  process.exit(0);
});

process.on('SIGINT', () => {
  log('📝 Recebido SIGINT, encerrando servidor...');
  process.exit(0);
});

// Iniciar servidor
startServer().catch(error => {
  log(`❌ Erro fatal ao iniciar servidor: ${error.message}`, 'error');
  process.exit(1);
});
