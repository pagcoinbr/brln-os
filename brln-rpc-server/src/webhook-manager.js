const axios = require('axios');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const config = require('../config/config.json');

class WebhookManager {
  constructor(logger) {
    this.logger = logger;
    this.config = config.webhooks;
    this.failedWebhooksDir = path.join(__dirname, '../webhook_failures');
    
    // Criar diretório para webhooks falhados se não existir
    if (this.config.saveFailedWebhooks && !fs.existsSync(this.failedWebhooksDir)) {
      fs.mkdirSync(this.failedWebhooksDir, { recursive: true });
    }
  }

  /**
   * Gera assinatura HMAC para verificação de autenticidade
   * @param {string} payload - Payload JSON do webhook
   * @param {string} secret - Chave secreta para assinatura
   * @returns {string} Assinatura HMAC
   */
  generateSignature(payload, secret) {
    return crypto
      .createHmac('sha256', secret)
      .update(payload, 'utf8')
      .digest('hex');
  }

  /**
   * Envia webhook para o endpoint especificado
   * @param {string} webhookUrl - URL do webhook
   * @param {object} paymentData - Dados do pagamento
   * @param {string} event - Tipo de evento (payment.pending, payment.completed, payment.failed)
   * @param {string} webhookSecret - Chave secreta para assinatura (opcional)
   * @returns {Promise<boolean>} Sucesso do envio
   */
  async sendWebhook(webhookUrl, paymentData, event, webhookSecret = null) {
    if (!this.config.enabled) {
      this.logger.info('Webhooks desabilitados na configuração');
      return true;
    }

    const payload = {
      event: event,
      timestamp: new Date().toISOString(),
      data: paymentData,
      server: {
        name: 'LND-RPC-Server',
        version: '2.0.0'
      }
    };

    const payloadString = JSON.stringify(payload);
    const headers = { ...this.config.defaultHeaders };

    // Adicionar assinatura se secret foi fornecido
    if (webhookSecret) {
      const signature = this.generateSignature(payloadString, webhookSecret);
      headers['X-Webhook-Signature'] = `sha256=${signature}`;
      headers['X-Webhook-Signature-256'] = `sha256=${signature}`;
    }

    // Adicionar timestamp para prevenir replay attacks
    headers['X-Webhook-Timestamp'] = Math.floor(Date.now() / 1000).toString();

    let attempt = 0;
    const maxAttempts = this.config.retryAttempts + 1;

    while (attempt < maxAttempts) {
      try {
        this.logger.info(`Enviando webhook (tentativa ${attempt + 1}/${maxAttempts}): ${event} para ${webhookUrl}`);

        const response = await axios.post(webhookUrl, payload, {
          headers: headers,
          timeout: this.config.timeout,
          validateStatus: (status) => status >= 200 && status < 300
        });

        this.logger.info(`Webhook enviado com sucesso: ${event} - Status: ${response.status}`);
        return true;

      } catch (error) {
        attempt++;
        const isLastAttempt = attempt >= maxAttempts;

        this.logger.warn(`Falha no webhook (tentativa ${attempt}/${maxAttempts}): ${error.message}`);

        if (isLastAttempt) {
          // Última tentativa falhou
          this.logger.error(`Webhook falhou definitivamente após ${maxAttempts} tentativas: ${webhookUrl}`);
          
          if (this.config.logFailures) {
            this.logFailedWebhook(webhookUrl, payload, error.message);
          }

          if (this.config.saveFailedWebhooks) {
            this.saveFailedWebhook(webhookUrl, payload, error.message);
          }

          return false;
        } else {
          // Aguardar antes da próxima tentativa
          await this.sleep(this.config.retryDelay);
        }
      }
    }

    return false;
  }

  /**
   * Envia webhook de pagamento pendente
   */
  async sendPaymentPendingWebhook(webhookUrl, paymentData, webhookSecret = null) {
    return await this.sendWebhook(webhookUrl, paymentData, 'payment.pending', webhookSecret);
  }

  /**
   * Envia webhook de pagamento concluído
   */
  async sendPaymentCompletedWebhook(webhookUrl, paymentData, webhookSecret = null) {
    return await this.sendWebhook(webhookUrl, paymentData, 'payment.completed', webhookSecret);
  }

  /**
   * Envia webhook de pagamento falhado
   */
  async sendPaymentFailedWebhook(webhookUrl, paymentData, webhookSecret = null) {
    return await this.sendWebhook(webhookUrl, paymentData, 'payment.failed', webhookSecret);
  }

  /**
   * Envia webhook de teste
   */
  async sendTestWebhook(webhookUrl, webhookSecret = null) {
    const testPayload = {
      id: 'test-webhook-' + Date.now(),
      transactionId: 'test-transaction',
      username: 'test-user',
      amount: 1000,
      network: 'lightning',
      destinationWallet: 'test@example.com',
      status: 'test',
      timestamp: new Date().toISOString()
    };

    return await this.sendWebhook(webhookUrl, testPayload, 'webhook.test', webhookSecret);
  }

  /**
   * Registra webhook falhado no log
   */
  logFailedWebhook(webhookUrl, payload, errorMessage) {
    this.logger.error('WEBHOOK_FAILURE', {
      url: webhookUrl,
      event: payload.event,
      transactionId: payload.data?.transactionId,
      error: errorMessage,
      timestamp: new Date().toISOString()
    });
  }

  /**
   * Salva webhook falhado em arquivo para reprocessamento
   */
  saveFailedWebhook(webhookUrl, payload, errorMessage) {
    const failureData = {
      webhookUrl: webhookUrl,
      payload: payload,
      error: errorMessage,
      failedAt: new Date().toISOString(),
      attempts: this.config.retryAttempts + 1
    };

    const filename = `failed_webhook_${Date.now()}_${payload.data?.transactionId || 'unknown'}.json`;
    const filepath = path.join(this.failedWebhooksDir, filename);

    try {
      fs.writeFileSync(filepath, JSON.stringify(failureData, null, 2));
      this.logger.info(`Webhook falhado salvo para reprocessamento: ${filepath}`);
    } catch (error) {
      this.logger.error(`Erro ao salvar webhook falhado: ${error.message}`);
    }
  }

  /**
   * Reprocessa webhooks falhados
   */
  async reprocessFailedWebhooks() {
    if (!fs.existsSync(this.failedWebhooksDir)) {
      return;
    }

    const files = fs.readdirSync(this.failedWebhooksDir)
      .filter(file => file.startsWith('failed_webhook_') && file.endsWith('.json'));

    this.logger.info(`Reprocessando ${files.length} webhooks falhados...`);

    for (const file of files) {
      const filepath = path.join(this.failedWebhooksDir, file);
      
      try {
        const failureData = JSON.parse(fs.readFileSync(filepath, 'utf8'));
        
        this.logger.info(`Reprocessando webhook: ${failureData.webhookUrl}`);
        
        const success = await this.sendWebhook(
          failureData.webhookUrl,
          failureData.payload.data,
          failureData.payload.event
        );

        if (success) {
          // Webhook reenviado com sucesso, remover arquivo
          fs.unlinkSync(filepath);
          this.logger.info(`Webhook reprocessado com sucesso: ${file}`);
        } else {
          this.logger.warn(`Falha ao reprocessar webhook: ${file}`);
        }

      } catch (error) {
        this.logger.error(`Erro ao reprocessar webhook ${file}: ${error.message}`);
      }
    }
  }

  /**
   * Valida URL de webhook
   */
  validateWebhookUrl(url) {
    try {
      const parsedUrl = new URL(url);
      return ['http:', 'https:'].includes(parsedUrl.protocol);
    } catch (error) {
      return false;
    }
  }

  /**
   * Sleep helper function
   */
  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Obtém estatísticas de webhooks
   */
  getWebhookStats() {
    const stats = {
      enabled: this.config.enabled,
      timeout: this.config.timeout,
      retryAttempts: this.config.retryAttempts,
      retryDelay: this.config.retryDelay,
      failedWebhooks: 0
    };

    if (fs.existsSync(this.failedWebhooksDir)) {
      const failedFiles = fs.readdirSync(this.failedWebhooksDir)
        .filter(file => file.startsWith('failed_webhook_') && file.endsWith('.json'));
      stats.failedWebhooks = failedFiles.length;
    }

    return stats;
  }
}

module.exports = WebhookManager;
