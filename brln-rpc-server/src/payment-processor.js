const fs = require('fs');
const path = require('path');
const config = require('../config/config.json');
const LightningRPC = require('./rpc/lightning-rpc');
const LiquidRPC = require('./rpc/liquid-rpc');
const WebhookManager = require('./webhook-manager');

class PaymentProcessor {
  constructor(logger) {
    this.logger = logger;
    this.lightningRPC = new LightningRPC(config.lightning, logger);
    this.liquidRPC = new LiquidRPC(config.liquid, logger);
    this.webhookManager = new WebhookManager(logger);
  }

  async processPayment(paymentRequest) {
    try {
      this.logger.info(`Processando pagamento: ${paymentRequest.id}`);
      
      // Enviar webhook de pagamento pendente se configurado
      if (paymentRequest.webhookUrl) {
        await this.webhookManager.sendPaymentPendingWebhook(
          paymentRequest.webhookUrl, 
          paymentRequest,
          paymentRequest.webhookSecret
        );
      }
      
      let result;
      const network = paymentRequest.network.toLowerCase();
      
      // Determinar qual RPC usar baseado na rede
      switch (network) {
        case 'bitcoin':
        case 'lightning':
          // Usar Lightning RPC para ambos Bitcoin on-chain e Lightning Network
          // O Lightning RPC irá detectar automaticamente o tipo baseado no destino
          result = await this.lightningRPC.sendPayment(
            paymentRequest.destinationWallet,
            paymentRequest.amount
          );
          break;
          
        case 'liquid':
          result = await this.liquidRPC.sendPayment(
            paymentRequest.destinationWallet,
            paymentRequest.amount
          );
          break;
          
        default:
          throw new Error(`Rede não suportada: ${network}`);
      }
      
      // Atualizar dados da requisição com o resultado
      paymentRequest.status = 'sent';
      paymentRequest.transactionHash = result.transactionHash;
      paymentRequest.completedAt = new Date().toISOString();
      paymentRequest.networkFee = result.fee || 0;
      
      // Enviar webhook de pagamento concluído se configurado
      if (paymentRequest.webhookUrl) {
        await this.webhookManager.sendPaymentCompletedWebhook(
          paymentRequest.webhookUrl, 
          paymentRequest,
          paymentRequest.webhookSecret
        );
      }
      
      // Mover arquivo de payment_req para payment_sent
      await this.movePaymentFile(paymentRequest);
      
      this.logger.info(`Pagamento concluído: ${paymentRequest.id}, Hash: ${result.transactionHash}`);
      
      return result;
      
    } catch (error) {
      this.logger.error(`Erro ao processar pagamento ${paymentRequest.id}: ${error.message}`, error);
      
      // Atualizar status para erro
      paymentRequest.status = 'error';
      paymentRequest.error = error.message;
      paymentRequest.errorAt = new Date().toISOString();
      
      // Enviar webhook de pagamento falhado se configurado
      if (paymentRequest.webhookUrl) {
        await this.webhookManager.sendPaymentFailedWebhook(
          paymentRequest.webhookUrl, 
          paymentRequest,
          paymentRequest.webhookSecret
        );
      }
      
      // Salvar arquivo com erro
      await this.savePaymentWithError(paymentRequest);
      
      throw error;
    }
  }

  async movePaymentFile(paymentRequest) {
    const sourceFile = path.join(__dirname, '../payment_req', `${paymentRequest.id}_${paymentRequest.transactionId}.json`);
    const destFile = path.join(__dirname, '../payment_sent', `${paymentRequest.id}_${paymentRequest.transactionId}.json`);
    
    // Salvar arquivo atualizado no diretório payment_sent
    fs.writeFileSync(destFile, JSON.stringify(paymentRequest, null, 2));
    
    // Remover arquivo original do diretório payment_req
    if (fs.existsSync(sourceFile)) {
      fs.unlinkSync(sourceFile);
    }
    
    this.logger.info(`Arquivo movido: ${sourceFile} -> ${destFile}`);
  }

  async savePaymentWithError(paymentRequest) {
    const errorFile = path.join(__dirname, '../payment_req', `ERROR_${paymentRequest.id}_${paymentRequest.transactionId}.json`);
    fs.writeFileSync(errorFile, JSON.stringify(paymentRequest, null, 2));
    this.logger.info(`Arquivo de erro salvo: ${errorFile}`);
  }

  async getBalance(network) {
    switch (network) {
      case 'bitcoin':
        // Usar Lightning RPC para saldo on-chain do Bitcoin
        return await this.lightningRPC.getOnChainBalance();
        
      case 'lightning':
        // Usar Lightning RPC para saldo dos canais Lightning
        return await this.lightningRPC.getChannelBalance();
        
      case 'liquid':
        return await this.liquidRPC.getBalance();
        
      default:
        throw new Error(`Rede não suportada: ${network}`);
    }
  }

  // Método para detectar tipo de endereço/invoice
  detectAddressType(address) {
    // Lightning invoice (bolt11)
    if (address.toLowerCase().startsWith('ln')) {
      return 'lightning';
    }
    
    // Lightning address (usuario@dominio.com)
    if (address.includes('@') && address.split('@').length === 2) {
      const [username, domain] = address.split('@');
      if (username && domain && domain.includes('.')) {
        return 'lightning';
      }
    }
    
    // Bitcoin address patterns
    if (address.match(/^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$/) || // Legacy
        address.match(/^bc1[a-zA-HJ-NP-Z0-9]{39,59}$/) ||     // Bech32
        address.match(/^3[a-km-zA-HJ-NP-Z1-9]{25,34}$/)) {    // P2SH
      return 'bitcoin';
    }
    
    // Liquid address patterns
    if (address.match(/^[2-9A-HJ-NP-Z][1-9A-HJ-NP-Za-km-z]{25,39}$/) ||
        address.match(/^lq1[a-zA-HJ-NP-Z0-9]{39,59}$/)) {
      return 'liquid';
    }
    
    return 'unknown';
  }

  // Método adicional para obter informações detalhadas de saldos
  async getAllBalances() {
    try {
      const [bitcoinBalance, lightningBalance, liquidBalance] = await Promise.all([
        this.lightningRPC.getOnChainBalance(),
        this.lightningRPC.getChannelBalance(),
        this.liquidRPC.getBalance()
      ]);

      return {
        bitcoin: bitcoinBalance,
        lightning: lightningBalance,
        liquid: liquidBalance,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      this.logger.error('Erro ao obter todos os saldos:', error);
      throw error;
    }
  }
}

module.exports = PaymentProcessor;
