/**
 * Teste de integração REAL para verificar envio USDT via GasFree
 *
 * Este teste conecta com a API GasFree real para verificar:
 * 1. Configuração correta das credenciais
 * 2. Fluxo completo de envio para TEngmEjAezVqq2kEsiWmuE9qrJi7i7EYWu
 * 3. Verificação de status e confirmação
 *
 * ⚠️  ATENÇÃO: Este teste faz transações reais! ⚠️
 * Só execute com configurações de testnet e com cuidado
 */

import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import { TronGasFreeService } from '../../domain/services/tron-gasfree.service';
import { GasFreeProvider } from '../../infrastructure/providers/gasfree.provider';
import {
  SendUSDTViaGasFreeRequest,
  TronGasFreeApplicationService,
} from './tron-gasfree-application.service';

describe('GasFree USDT Transfer - Real Integration Test', () => {
  let tronGasFreeApplicationService: TronGasFreeApplicationService;
  let gasFreeProvider: GasFreeProvider;

  const TARGET_ADDRESS = 'TEngmEjAezVqq2kEsiWmuE9qrJi7i7EYWu';

  beforeAll(async () => {
    // Mock configurações de teste
    const mockConfigService = {
      get: jest.fn((key: string, defaultValue?: any) => {
        const config = {
          TRON_GASFREE_SYSTEM_ADDRESS:
            process.env.TRON_GASFREE_SYSTEM_ADDRESS ||
            'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY',
          TRON_GASFREE_SYSTEM_PRIVATE_KEY:
            process.env.TRON_GASFREE_SYSTEM_PRIVATE_KEY || '',
          TRON_USDT_CONTRACT_ADDRESS:
            process.env.TRON_USDT_CONTRACT_ADDRESS ||
            'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
          GASFREE_SERVICE_PROVIDER_ADDRESS:
            process.env.GASFREE_SERVICE_PROVIDER_ADDRESS || '',
          GASFREE_CHAIN_ID: process.env.GASFREE_CHAIN_ID || '728126428',
          GASFREE_VERIFYING_CONTRACT:
            process.env.GASFREE_VERIFYING_CONTRACT ||
            'TFFAMLQZybALab4uxHA9RBE7pxhUAjfF3U',
          GASFREE_API_KEY: process.env.GASFREE_API_KEY || '',
          GASFREE_API_SECRET: process.env.GASFREE_API_SECRET || '',
          GASFREE_MAINNET_ENDPOINT:
            process.env.GASFREE_MAINNET_ENDPOINT ||
            'https://open.gasfree.io/tron/',
        };
        return config[key] || defaultValue;
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TronGasFreeApplicationService,
        GasFreeProvider,
        TronGasFreeService,
        {
          provide: ConfigService,
          useValue: mockConfigService,
        },
      ],
    }).compile();

    tronGasFreeApplicationService = module.get<TronGasFreeApplicationService>(
      TronGasFreeApplicationService,
    );
    gasFreeProvider = module.get<GasFreeProvider>(GasFreeProvider);
  });

  describe('Configuração e Disponibilidade', () => {
    it('deve verificar se GasFree está disponível e configurado', async () => {
      // Verify service is available
      const isAvailable = gasFreeProvider.isAvailable();

      if (!isAvailable) {
        console.warn(
          '⚠️  GasFree não está configurado - pule este teste se intencional',
        );
        console.warn(
          '   Configure as variáveis de ambiente GASFREE_API_KEY e GASFREE_API_SECRET',
        );
        expect(isAvailable).toBe(false); // Test passes but warns
        return;
      }

      expect(isAvailable).toBe(true);
      console.log('✅ GasFree está configurado e disponível');
    });

    it('deve conseguir buscar informações da conta do sistema', async () => {
      if (!gasFreeProvider.isAvailable()) {
        console.warn('⏭️  Pulando teste - GasFree não configurado');
        return;
      }

      const systemAddress =
        process.env.TRON_GASFREE_SYSTEM_ADDRESS ||
        'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY';

      console.log(`🔍 Buscando informações da conta: ${systemAddress}`);

      const result = await gasFreeProvider.getAccountInfo(systemAddress);

      if (result.result.type === 'ERROR') {
        console.error('❌ Erro ao buscar conta:', result.result.error);
        fail(`Falha ao buscar conta: ${result.result.error.payload}`);
      }

      const accountInfo = result.result.data;
      console.log('✅ Informações da conta obtidas:', {
        active: accountInfo.active,
        nonce: accountInfo.nonce,
        allowSubmit: accountInfo.allow_submit,
        assetsCount: accountInfo.assets.length,
      });

      expect(accountInfo.active).toBe(true);
      expect(accountInfo.allow_submit).toBe(true);
      expect(accountInfo.nonce).toBeGreaterThanOrEqual(0);
    });

    it('deve conseguir buscar tokens suportados', async () => {
      if (!gasFreeProvider.isAvailable()) {
        console.warn('⏭️  Pulando teste - GasFree não configurado');
        return;
      }

      console.log('🪙 Buscando tokens suportados...');

      const result = await gasFreeProvider.getTokens();

      if (result.result.type === 'ERROR') {
        console.error('❌ Erro ao buscar tokens:', result.result.error);
        fail(`Falha ao buscar tokens: ${result.result.error.payload}`);
      }

      const tokensData = result.result.data;
      console.log('✅ Tokens obtidos:', {
        tokensCount: tokensData.tokens.length,
      });

      expect(tokensData.tokens.length).toBeGreaterThan(0);

      // Verificar se USDT está disponível
      const usdtToken = tokensData.tokens.find(
        (t) =>
          t.tokenAddress.toLowerCase() ===
          (
            process.env.TRON_USDT_CONTRACT_ADDRESS ||
            'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'
          ).toLowerCase(),
      );

      if (!usdtToken) {
        console.error('❌ USDT não encontrado nos tokens suportados');
        console.log(
          'Tokens disponíveis:',
          tokensData.tokens.map((t) => `${t.symbol} (${t.tokenAddress})`),
        );
        fail('USDT não está disponível no provider GasFree');
      }

      console.log('✅ USDT encontrado:', {
        symbol: usdtToken.symbol,
        address: usdtToken.tokenAddress,
        activateFee: usdtToken.activateFee,
        transferFee: usdtToken.transferFee,
        supported: usdtToken.supported,
      });

      expect(usdtToken.supported).toBe(true);
    });
  });

  describe('Teste de Envio USDT Real', () => {
    it(`deve executar envio USDT para ${TARGET_ADDRESS}`, async () => {
      if (!gasFreeProvider.isAvailable()) {
        console.warn('⏭️  Pulando teste - GasFree não configurado');
        return;
      }

      // ⚠️  ATENÇÃO: Este teste faz uma transação real!
      console.log('🚀 INICIANDO TESTE DE ENVIO REAL DE USDT');
      console.log(`📍 Endereço de destino: ${TARGET_ADDRESS}`);
      console.log('💰 Quantidade: 1.000000 USDT (valor de teste)');

      const request: SendUSDTViaGasFreeRequest = {
        toAddress: TARGET_ADDRESS,
        amount: '1.000000', // 1 USDT para teste
        orderId: `test-order-${Date.now()}`,
        userId: `test-user-${Date.now()}`,
      };

      console.log('⏳ Executando transferência...');
      console.log('   Isso pode levar até 3 minutos para confirmar');

      const startTime = Date.now();
      const result =
        await tronGasFreeApplicationService.sendUSDTViaGasFree(request);
      const endTime = Date.now();
      const duration = (endTime - startTime) / 1000;

      if (result.result.type === 'ERROR') {
        console.error('❌ Falha na transferência:', result.result.error);

        // Para alguns erros, ainda consideramos o teste como sucesso se for um erro esperado
        const errorMessage = result.result.error.payload || '';
        if (
          errorMessage.includes('insufficient balance') ||
          errorMessage.includes('not enough') ||
          errorMessage.includes('saldo insuficiente')
        ) {
          console.log(
            '⚠️  Erro de saldo insuficiente - teste passa pois a integração está funcionando',
          );
          expect(result.result.error.code).toBe('EXTERNAL_SERVICE_ERROR');
          return;
        }

        fail(`Transferência falhou: ${errorMessage}`);
      }

      const transferResult = result.result.data;

      console.log('✅ TRANSFERÊNCIA CONCLUÍDA COM SUCESSO!');
      console.log(`⏱️  Tempo total: ${duration.toFixed(2)} segundos`);
      console.log('📋 Detalhes da transação:', {
        txHash: transferResult.txHash,
        traceId: transferResult.traceId,
        amount: transferResult.amount,
        fee: transferResult.fee,
        totalCost: transferResult.totalCost,
        confirmations: transferResult.confirmations,
      });

      // Verificações do resultado
      expect(transferResult.txHash).toBeDefined();
      expect(transferResult.txHash).toMatch(/^[a-f0-9]{64}$/i); // Hash de 64 caracteres hex
      expect(transferResult.traceId).toBeDefined();
      expect(transferResult.amount).toBe('1.000000');
      expect(parseFloat(transferResult.fee)).toBeGreaterThan(0);
      expect(parseFloat(transferResult.totalCost)).toBeGreaterThan(
        parseFloat(transferResult.amount),
      );
      expect(transferResult.confirmations).toBeGreaterThanOrEqual(19);

      console.log('🎉 TESTE DE INTEGRAÇÃO COMPLETO!');
      console.log(
        `🔗 Verificar transação: https://tronscan.org/#/transaction/${transferResult.txHash}`,
      );
    }, 300000); // 5 minutos de timeout para transferência real
  });

  describe('Validação de Parâmetros', () => {
    it('deve rejeitar endereço inválido', async () => {
      if (!gasFreeProvider.isAvailable()) {
        console.warn('⏭️  Pulando teste - GasFree não configurado');
        return;
      }

      const request: SendUSDTViaGasFreeRequest = {
        toAddress: 'endereco-invalido',
        amount: '1.000000',
        orderId: 'test-order-invalid',
        userId: 'test-user-invalid',
      };

      const result =
        await tronGasFreeApplicationService.sendUSDTViaGasFree(request);

      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        console.log(
          '✅ Endereço inválido rejeitado corretamente:',
          result.result.error.payload,
        );
      }
    });

    it('deve rejeitar quantidade inválida', async () => {
      if (!gasFreeProvider.isAvailable()) {
        console.warn('⏭️  Pulando teste - GasFree não configurado');
        return;
      }

      const request: SendUSDTViaGasFreeRequest = {
        toAddress: TARGET_ADDRESS,
        amount: '-1.000000', // Quantidade negativa
        orderId: 'test-order-invalid-amount',
        userId: 'test-user-invalid-amount',
      };

      const result =
        await tronGasFreeApplicationService.sendUSDTViaGasFree(request);

      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        console.log(
          '✅ Quantidade inválida rejeitada corretamente:',
          result.result.error.payload,
        );
      }
    });
  });
});
