const axios = require('axios');

class LiquidRPC {
  constructor(config, logger) {
    this.config = config;
    this.logger = logger;
    this.rpcUrl = `http://${config.rpcUser}:${config.rpcPassword}@${config.rpcHost}:${config.rpcPort}`;
    
    // Asset ID do L-BTC (Liquid Bitcoin)
    this.LBTC_ASSET_ID = '6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
    this.TEST_ASSET_ID = '38fca2d939696061a8f76d4e6b5eecd54e3b4221c846f24a6b279e79952850a5'; // Exemplo de asset ID para testes
    
    // Mapeamento de asset IDs para nomes amigáveis
    this.assetNames = {
      'bitcoin': 'L-BTC',
      [this.LBTC_ASSET_ID]: 'L-BTC',
      [this.TEST_ASSET_ID]: 'TEST'
    };
  }

  async rpcCall(method, params = []) {
    try {
      const response = await axios.post(this.rpcUrl, {
        jsonrpc: '1.0',
        id: 'liquid-rpc',
        method: method,
        params: params
      }, {
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 30000
      });

      if (response.data.error) {
        throw new Error(`Liquid RPC Error: ${response.data.error.message}`);
      }

      return response.data.result;
    } catch (error) {
      this.logger.error(`Liquid RPC call failed: ${method}`, error);
      throw new Error(`Liquid RPC call failed: ${error.message}`);
    }
  }

  getAssetName(assetId) {
    return this.assetNames[assetId] || assetId;
  }

  async getBalance() {
    try {
      // Obter saldo de todos os assets
      const balances = await this.rpcCall('getbalance');
      
      // Obter saldo não confirmado
      const unconfirmedBalances = await this.rpcCall('getunconfirmedbalance');
      
      // Buscar especificamente L-BTC - Elements/Liquid pode retornar como "bitcoin" ou pelo asset ID
      const lbtcBalance = balances['bitcoin'] || balances[this.LBTC_ASSET_ID] || 0;
      const lbtcUnconfirmed = unconfirmedBalances['bitcoin'] || unconfirmedBalances[this.LBTC_ASSET_ID] || 0;
      
      // Criar objeto de assets com nomes amigáveis
      const namedAssets = {};
      for (const [assetId, balance] of Object.entries(balances)) {
        const assetName = this.getAssetName(assetId);
        namedAssets[assetName] = balance;
      }
      
      return {
        confirmed: Math.round(lbtcBalance * 100000000), // Convert to satoshis
        unconfirmed: Math.round(lbtcUnconfirmed * 100000000),
        total: Math.round((lbtcBalance + lbtcUnconfirmed) * 100000000),
        assets: namedAssets // Assets com nomes amigáveis
      };
    } catch (error) {
      this.logger.error('Erro ao consultar saldo Liquid:', error);
      throw error;
    }
  }

  async sendPayment(destinationAddress, amountSats, assetId = null) {
    try {
      // Usar L-BTC como padrão se não especificado
      const asset = assetId || this.LBTC_ASSET_ID;
      
      // Converter satoshis para BTC
      const amountBTC = amountSats / 100000000;
      
      this.logger.info(`Enviando ${amountSats} sats (${amountBTC} L-BTC) para ${destinationAddress}`);
      
      // Verificar se o endereço é válido
      const isValid = await this.rpcCall('validateaddress', [destinationAddress]);
      if (!isValid.isvalid) {
        throw new Error(`Endereço Liquid inválido: ${destinationAddress}`);
      }
      
      // Estimar taxa
      const feeRate = await this.estimateFee();
      
      // Preparar outputs
      const outputs = {};
      outputs[destinationAddress] = amountBTC;
      
      // Criar transação raw
      const rawTx = await this.rpcCall('createrawtransaction', [
        [], // inputs (será selecionado automaticamente)
        outputs,
        0, // locktime
        false, // replaceable
        asset // asset para o output
      ]);
      
      // Financiar transação
      const fundedTx = await this.rpcCall('fundrawtransaction', [rawTx, {
        feeRate: feeRate,
        includeWatching: false,
        lockUnspents: false,
        reserveChangeKey: true,
        changeAddress: await this.getNewAddress(),
        changePosition: -1,
        includeUnsafe: false
      }]);
      
      // Assinar transação
      const signedTx = await this.rpcCall('signrawtransactionwithwallet', [fundedTx.hex]);
      
      if (!signedTx.complete) {
        throw new Error('Não foi possível assinar a transação completamente');
      }
      
      // Enviar transação
      const txid = await this.rpcCall('sendrawtransaction', [signedTx.hex]);
      
      // Obter detalhes da transação
      const txDetails = await this.rpcCall('gettransaction', [txid]);
      
      return {
        transactionHash: txid,
        fee: Math.abs(Math.round(fundedTx.fee * 100000000)), // Convert fee to satoshis
        confirmations: txDetails.confirmations || 0,
        blockHash: txDetails.blockhash || null,
        assetId: asset
      };
      
    } catch (error) {
      this.logger.error(`Erro ao enviar pagamento Liquid: ${error.message}`, error);
      throw error;
    }
  }

  async sendAsset(destinationAddress, amountSats, assetId) {
    return this.sendPayment(destinationAddress, amountSats, assetId);
  }

  async estimateFee() {
    try {
      // Estimar taxa para confirmação em 6 blocos
      const feeEstimate = await this.rpcCall('estimatesmartfee', [6]);
      
      if (feeEstimate.feerate) {
        return feeEstimate.feerate;
      }
      
      // Fallback para taxa mínima
      return 0.00001;
      
    } catch (error) {
      this.logger.warn('Não foi possível estimar taxa, usando taxa mínima');
      return 0.00001;
    }
  }

  async getTransactionStatus(txid) {
    try {
      const tx = await this.rpcCall('gettransaction', [txid]);
      return {
        confirmations: tx.confirmations || 0,
        confirmed: (tx.confirmations || 0) >= 2, // Liquid requer 2 confirmações
        blockHash: tx.blockhash || null,
        blockTime: tx.blocktime || null
      };
    } catch (error) {
      this.logger.error(`Erro ao consultar status da transação ${txid}:`, error);
      throw error;
    }
  }

  async getNewAddress() {
    try {
      return await this.rpcCall('getnewaddress');
    } catch (error) {
      this.logger.error('Erro ao gerar novo endereço:', error);
      throw error;
    }
  }

  async getNewAddressConfidential() {
    try {
      const address = await this.rpcCall('getnewaddress');
      const confidentialAddress = await this.rpcCall('getaddressinfo', [address]);
      return confidentialAddress.confidential || address;
    } catch (error) {
      this.logger.error('Erro ao gerar novo endereço confidencial:', error);
      throw error;
    }
  }

  async blindRawTransaction(rawTx) {
    try {
      return await this.rpcCall('blindrawtransaction', [rawTx]);
    } catch (error) {
      this.logger.error('Erro ao cegar transação:', error);
      throw error;
    }
  }

  async unblindRawTransaction(rawTx) {
    try {
      return await this.rpcCall('unblindrawtransaction', [rawTx]);
    } catch (error) {
      this.logger.error('Erro ao descegar transação:', error);
      throw error;
    }
  }

  async listAssets() {
    try {
      const balances = await this.rpcCall('getbalance');
      const assets = [];
      
      for (const [assetId, balance] of Object.entries(balances)) {
        if (balance > 0) {
          assets.push({
            assetId: assetId,
            assetName: this.getAssetName(assetId),
            balance: Math.round(balance * 100000000),
            isLBTC: assetId === this.LBTC_ASSET_ID || assetId === 'bitcoin'
          });
        }
      }
      
      return assets;
    } catch (error) {
      this.logger.error('Erro ao listar assets:', error);
      throw error;
    }
  }

  async issueAsset(assetAmount, tokenAmount = 0, blind = true) {
    try {
      const result = await this.rpcCall('issueasset', [assetAmount, tokenAmount, blind]);
      
      return {
        asset: result.asset,
        token: result.token,
        txid: result.txid,
        vin: result.vin,
        entropy: result.entropy
      };
    } catch (error) {
      this.logger.error('Erro ao emitir asset:', error);
      throw error;
    }
  }

  async reissueAsset(assetId, amount) {
    try {
      return await this.rpcCall('reissueasset', [assetId, amount]);
    } catch (error) {
      this.logger.error('Erro ao reemitir asset:', error);
      throw error;
    }
  }
}

module.exports = LiquidRPC;
