const lightning = require('./index');

// Exemplo de uso do cliente Elements/Liquid integrado ao lightning

async function demonstrateElementsIntegration() {
  try {
    // 1. Conectar ao Elements Core (usando configurações do brln-os)
    const {elements} = lightning.elementsRpc({
      host: 'localhost',      // ou 'elements' se rodando em Docker
      port: 7041,             // porta mainnet Elements
      user: 'test',           // usuário RPC configurado no brln-os
      password: 'test'        // senha RPC configurada no brln-os
    });

    console.log('✅ Conectado ao Elements Core!');

    // 2. Obter informações da blockchain Liquid
    const chainInfo = await lightning.getElementsInfo({elements});
    console.log('📊 Informações da Liquid Network:', chainInfo);

    // 3. Verificar saldo L-BTC
    const balance = await lightning.getElementsBalance({elements});
    console.log('💰 Saldo L-BTC:', balance);

    // 4. Listar todos os assets da Liquid
    const assets = await lightning.getLiquidAssets({elements});
    console.log('🏦 Assets disponíveis:', assets);

    // 5. Criar novo endereço L-BTC
    const newAddress = await lightning.createElementsAddress({
      elements,
      format: 'bech32',
      label: 'brln-os-integration'
    });
    console.log('🏠 Novo endereço:', newAddress);

    // 6. Exemplo de uso com LND (funcionalidade original)
    // const {lnd} = lightning.authenticatedLndGrpc({
    //   cert: fs.readFileSync('/data/lnd/tls.cert'),
    //   macaroon: fs.readFileSync('/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'),
    //   socket: 'lnd:10009'
    // });
    
    // const lndInfo = await lightning.getWalletInfo({lnd});
    // console.log('⚡ LND Info:', lndInfo);

    console.log('\n🎉 Integração Elements + Lightning completa!');
    
    return {
      elements_info: chainInfo,
      balance,
      assets,
      new_address: newAddress
    };

  } catch (error) {
    console.error('❌ Erro na demonstração:', error.message);
    throw error;
  }
}

// Exemplo de transação L-BTC
async function sendLiquidTransaction() {
  try {
    const {elements} = lightning.elementsRpc({
      host: 'localhost',
      port: 7041,
      user: 'test',
      password: 'test'
    });

    // Criar endereço de destino
    const destinationAddress = await lightning.createElementsAddress({
      elements,
      label: 'destination-example'
    });

    // Enviar 0.001 L-BTC (100000 satoshis)
    const transaction = await lightning.sendToElementsAddress({
      elements,
      address: destinationAddress.address,
      tokens: 100000, // satoshis
      description: 'Teste de transação L-BTC via brln-os'
    });

    console.log('✅ Transação enviada:', transaction);
    return transaction;

  } catch (error) {
    console.error('❌ Erro na transação:', error.message);
    throw error;
  }
}

// Função para monitorar múltiplos assets
async function monitorLiquidAssets() {
  try {
    const {elements} = lightning.elementsRpc({
      host: 'localhost',
      port: 7041,
      user: 'test',
      password: 'test'
    });

    const assets = await lightning.getLiquidAssets({elements});
    
    console.log('\n💎 Monitoramento de Assets:');
    
    for (const asset of assets.assets) {
      try {
        const balance = await lightning.getElementsBalance({
          elements,
          asset: asset.asset_id
        });
        
        console.log(`${asset.name || asset.asset_id.substring(0,8)}: ${balance.balance} unidades`);
      } catch (err) {
        console.log(`${asset.name || asset.asset_id.substring(0,8)}: 0 unidades (não possuído)`);
      }
    }

  } catch (error) {
    console.error('❌ Erro no monitoramento:', error.message);
  }
}

module.exports = {
  demonstrateElementsIntegration,
  sendLiquidTransaction,
  monitorLiquidAssets
};

// Executar demonstração se executado diretamente
if (require.main === module) {
  demonstrateElementsIntegration()
    .then(() => console.log('\n🎯 Demonstração concluída com sucesso!'))
    .catch(err => {
      console.error('\n💥 Erro na demonstração:', err);
      process.exit(1);
    });
}
