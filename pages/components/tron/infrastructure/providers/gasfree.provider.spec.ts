import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import axios from 'axios';

// Mock axios globalmente antes de importar o provider
jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

import {
  GasFreeAccountInfo,
  GasFreeProvider,
  GasFreeTransferPayload,
  GasFreeTransferResult,
} from './gasfree.provider';

/**
 * Teste unitário para GasFreeProvider
 *
 * Este teste verifica:
 * 1. Autenticação HMAC-SHA256 com API GasFree
 * 2. Métodos individuais da API (getAccountInfo, getTokens, submitGasFreeTransfer, getTransferStatus)
 * 3. Tratamento de erros e timeouts
 * 4. Normalização de respostas da API
 */
describe('GasFreeProvider - Unit Test', () => {
  let provider: GasFreeProvider;
  let configService: ConfigService;

  // Mock de configurações
  const mockConfig = {
    GASFREE_API_KEY: 'test-api-key',
    GASFREE_API_SECRET: 'test-api-secret',
    GASFREE_MAINNET_ENDPOINT: 'https://open.gasfree.io/tron/',
    GASFREE_VERIFYING_CONTRACT: 'TFFAMLQZybALab4uxHA9RBE7pxhUAjfF3U',
  };

  beforeEach(async () => {
    const mockConfigService = {
      get: jest.fn((key: string, defaultValue?: any) => {
        return mockConfig[key] || defaultValue;
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        GasFreeProvider,
        {
          provide: ConfigService,
          useValue: mockConfigService,
        },
      ],
    }).compile();

    provider = module.get<GasFreeProvider>(GasFreeProvider);
    configService = module.get<ConfigService>(ConfigService);

    // Clear all previous mocks
    jest.clearAllMocks();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Configuração e Disponibilidade', () => {
    it('deve estar disponível quando todas as configurações estão presentes', () => {
      expect(provider.isAvailable()).toBe(true);
    });

    it('deve não estar disponível quando configurações estão faltando', async () => {
      // Arrange - Mock config sem API key
      (configService.get as jest.Mock).mockImplementation((key: string) => {
        if (key === 'GASFREE_API_KEY') return undefined;
        return mockConfig[key];
      });

      // Recreate provider with missing config
      const module = await Test.createTestingModule({
        providers: [
          GasFreeProvider,
          {
            provide: ConfigService,
            useValue: configService,
          },
        ],
      }).compile();

      const providerWithMissingConfig =
        module.get<GasFreeProvider>(GasFreeProvider);

      // Assert
      expect(providerWithMissingConfig.isAvailable()).toBe(false);
    });
  });

  describe('getAccountInfo', () => {
    it('deve retornar informações da conta com sucesso', async () => {
      // Arrange
      const accountAddress = 'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY';
      const mockResponse = {
        accountAddress: accountAddress,
        gasFreeAddress: 'TGasFreeAddress123456789012345678901',
        active: true,
        nonce: 5,
        allow_submit: true,
        assets: [
          {
            tokenAddress: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
            tokenSymbol: 'USDT',
            activateFee: 10000000,
            transferFee: 5000000,
            decimal: 6,
            frozen: 0,
          },
        ],
      };

      mockAxios
        .onGet(`/api/v1/gasfree/account/${accountAddress}`)
        .reply(200, mockResponse);

      // Act
      const result = await provider.getAccountInfo(accountAddress);

      // Assert
      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        const accountInfo: GasFreeAccountInfo = result.result.data;
        expect(accountInfo.accountAddress).toBe(accountAddress);
        expect(accountInfo.active).toBe(true);
        expect(accountInfo.nonce).toBe(5);
        expect(accountInfo.allow_submit).toBe(true);
        expect(accountInfo.assets).toHaveLength(1);
        expect(accountInfo.assets[0].tokenSymbol).toBe('USDT');
      }

      // Verify request was made with proper authentication
      expect(mockAxios.history.get).toHaveLength(1);
      expect(mockAxios.history.get[0].headers).toHaveProperty('Authorization');
    });

    it('deve tratar erro 404 quando conta não existe', async () => {
      // Arrange
      const accountAddress = 'TInvalidAddress123456789012345678901';

      mockAxios
        .onGet(`/api/v1/gasfree/account/${accountAddress}`)
        .reply(404, { message: 'Account not found' });

      // Act
      const result = await provider.getAccountInfo(accountAddress);

      // Assert
      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.code).toBe('EXTERNAL_SERVICE_ERROR');
      }
    });

    it('deve tratar timeout da API', async () => {
      // Arrange
      const accountAddress = 'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY';

      mockAxios.onGet(`/api/v1/gasfree/account/${accountAddress}`).timeout();

      // Act
      const result = await provider.getAccountInfo(accountAddress);

      // Assert
      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.code).toBe('EXTERNAL_SERVICE_ERROR');
        expect(result.result.error.payload).toContain('timeout');
      }
    });
  });

  describe('getTokens', () => {
    it('deve retornar lista de tokens suportados', async () => {
      // Arrange
      const mockResponse = {
        provider: {
          address: 'TProviderAddress123456789012345678901',
          name: 'Test Provider',
          icon: 'https://example.com/icon.png',
          website: 'https://example.com',
          config: {
            maxPendingTransfer: 10,
            minDeadlineDuration: 60,
            maxDeadlineDuration: 3600,
            defaultDeadlineDuration: 300,
          },
        },
        tokens: [
          {
            tokenAddress: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
            symbol: 'USDT',
            decimal: 6,
            activateFee: 10000000,
            transferFee: 5000000,
            supported: true,
          },
          {
            tokenAddress: 'TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR',
            symbol: 'WTRX',
            decimal: 6,
            activateFee: 15000000,
            transferFee: 8000000,
            supported: true,
          },
        ],
      };

      mockAxios.onGet('/api/v1/config/provider/all').reply(200, mockResponse);

      // Act
      const result = await provider.getTokens();

      // Assert
      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.tokens).toHaveLength(2);

        const usdtToken = result.result.data.tokens.find(
          (t) => t.symbol === 'USDT',
        );
        expect(usdtToken).toBeDefined();
        expect(usdtToken?.tokenAddress).toBe(
          'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        );
        expect(usdtToken?.decimal).toBe(6);
        expect(usdtToken?.activateFee).toBe(10000000);
        expect(usdtToken?.transferFee).toBe(5000000);
        expect(usdtToken?.supported).toBe(true);
      }
    });

    it('deve tratar resposta vazia da API', async () => {
      // Arrange
      mockAxios.onGet('/api/v1/config/provider/all').reply(200, { tokens: [] });

      // Act
      const result = await provider.getTokens();

      // Assert
      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.tokens).toHaveLength(0);
      }
    });
  });

  describe('submitGasFreeTransfer', () => {
    it('deve submeter transferência com sucesso', async () => {
      // Arrange
      const payload: GasFreeTransferPayload = {
        token: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        serviceProvider: 'TProviderAddress123456789012345678901',
        user: 'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY',
        receiver: 'TEngmEjAezVqq2kEsiWmuE9qrJi7i7EYWu',
        value: '10000000',
        maxFee: '20000000',
        deadline: Math.floor(Date.now() / 1000) + 300,
        version: 1,
        nonce: 1,
        sig: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1b',
      };

      const mockResponse = {
        id: 'test-trace-id-12345',
        state: 'PENDING',
        accountAddress: 'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY',
        gasFreeAddress: 'TGasFreeAddress123456789012345678901',
        providerAddress: 'TProviderAddress123456789012345678901',
        targetAddress: 'TEngmEjAezVqq2kEsiWmuE9qrJi7i7EYWu',
        tokenAddress: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        amount: '10000000',
        estimatedActivateFee: '10000000',
        estimatedTransferFee: '5000000',
        estimatedTotalFee: '15000000',
        estimatedTotalCost: '25000000',
        message: 'Transfer submitted successfully',
      };

      mockAxios.onPost('/api/v1/gasfree/submit').reply(200, mockResponse);

      // Act
      const result = await provider.submitGasFreeTransfer(payload);

      // Assert
      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        const transferResult: GasFreeTransferResult = result.result.data;
        expect(transferResult.traceId).toBe('test-trace-id-12345');
        expect(transferResult.status).toBe('PENDING');
        expect(transferResult.accountAddress).toBe(
          'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY',
        );
        expect(transferResult.targetAddress).toBe(
          'TEngmEjAezVqq2kEsiWmuE9qrJi7i7EYWu',
        );
        expect(transferResult.amount).toBe('10000000');
        expect(transferResult.estimatedTotalCost).toBe('25000000');
      }

      // Verify request payload
      expect(mockAxios.history.post).toHaveLength(1);
      const requestData = JSON.parse(mockAxios.history.post[0].data);
      expect(requestData.user).toBe(payload.user);
      expect(requestData.receiver).toBe(payload.receiver);
      expect(requestData.value).toBe(payload.value);
    });

    it('deve tratar erro de validação da API', async () => {
      // Arrange
      const payload: GasFreeTransferPayload = {
        token: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        serviceProvider: 'TProviderAddress123456789012345678901',
        user: 'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY',
        receiver: 'TEngmEjAezVqq2kEsiWmuE9qrJi7i7EYWu',
        value: '0', // Valor inválido
        maxFee: '20000000',
        deadline: Math.floor(Date.now() / 1000) + 300,
        version: 1,
        nonce: 1,
        sig: '0x1234567890abcdef',
      };

      mockAxios.onPost('/api/v1/gasfree/submit').reply(400, {
        message: 'Invalid transfer amount',
        error: 'INVALID_AMOUNT',
      });

      // Act
      const result = await provider.submitGasFreeTransfer(payload);

      // Assert
      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.code).toBe('EXTERNAL_SERVICE_ERROR');
      }
    });

    it('deve tratar erro de autenticação', async () => {
      // Arrange
      const payload: GasFreeTransferPayload = {
        token: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        serviceProvider: 'TProviderAddress123456789012345678901',
        user: 'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY',
        receiver: 'TEngmEjAezVqq2kEsiWmuE9qrJi7i7EYWu',
        value: '10000000',
        maxFee: '20000000',
        deadline: Math.floor(Date.now() / 1000) + 300,
        version: 1,
        nonce: 1,
        sig: '0x1234567890abcdef',
      };

      mockAxios.onPost('/api/v1/gasfree/submit').reply(401, {
        message: 'Unauthorized: Invalid API key or signature',
        error: 'UNAUTHORIZED',
      });

      // Act
      const result = await provider.submitGasFreeTransfer(payload);

      // Assert
      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.code).toBe('EXTERNAL_SERVICE_ERROR');
      }
    });
  });

  describe('getTransferStatus', () => {
    it('deve retornar status da transferência CONFIRMED', async () => {
      // Arrange
      const traceId = 'test-trace-id-12345';
      const mockResponse = {
        id: traceId,
        state: 'CONFIRMED',
        tx_hash:
          'a1b2c3d4e5f6789012345678901234567890abcdefabcdef1234567890abcdef',
        accountAddress: 'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY',
        gasFreeAddress: 'TGasFreeAddress123456789012345678901',
        providerAddress: 'TProviderAddress123456789012345678901',
        targetAddress: 'TEngmEjAezVqq2kEsiWmuE9qrJi7i7EYWu',
        tokenAddress: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        amount: '10000000',
        estimatedActivateFee: '10000000',
        estimatedTransferFee: '5000000',
        estimatedTotalFee: '15000000',
        estimatedTotalCost: '25000000',
        message: 'Transfer confirmed on blockchain',
      };

      mockAxios.onGet(`/api/v1/gasfree/${traceId}`).reply(200, mockResponse);

      // Act
      const result = await provider.getTransferStatus(traceId);

      // Assert
      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        const status = result.result.data;
        expect(status.traceId).toBe(traceId);
        expect(status.status).toBe('CONFIRMED');
        expect(status.txHash).toBe(
          'a1b2c3d4e5f6789012345678901234567890abcdefabcdef1234567890abcdef',
        );
        expect(status.message).toBe('Transfer confirmed on blockchain');
      }
    });

    it('deve retornar status PENDING para transferência em processamento', async () => {
      // Arrange
      const traceId = 'test-trace-id-pending';
      const mockResponse = {
        id: traceId,
        state: 'PENDING',
        tx_hash: null,
        message: 'Transfer is being processed',
      };

      mockAxios.onGet(`/api/v1/gasfree/${traceId}`).reply(200, mockResponse);

      // Act
      const result = await provider.getTransferStatus(traceId);

      // Assert
      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        const status = result.result.data;
        expect(status.traceId).toBe(traceId);
        expect(status.status).toBe('PENDING');
        expect(status.txHash).toBeNull();
      }
    });

    it('deve tratar transferência não encontrada', async () => {
      // Arrange
      const traceId = 'non-existent-trace-id';

      mockAxios.onGet(`/api/v1/gasfree/${traceId}`).reply(404, {
        message: 'Transfer not found',
        error: 'NOT_FOUND',
      });

      // Act
      const result = await provider.getTransferStatus(traceId);

      // Assert
      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.code).toBe('EXTERNAL_SERVICE_ERROR');
      }
    });
  });

  describe('Autenticação HMAC-SHA256', () => {
    it('deve gerar headers de autenticação corretos', async () => {
      // Arrange
      const accountAddress = 'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY';

      mockAxios
        .onGet(`/api/v1/gasfree/account/${accountAddress}`)
        .reply(200, {});

      // Act
      await provider.getAccountInfo(accountAddress);

      // Assert
      const request = mockAxios.history.get[0];
      expect(request.headers).toHaveProperty('Authorization');
      expect(request.headers).toHaveProperty('X-Timestamp');

      // Verify format: "ApiKey API_KEY:SIGNATURE"
      const authHeader = request.headers?.['Authorization'];
      expect(authHeader).toMatch(/^ApiKey test-api-key:.+$/);
    });

    it('deve incluir timestamp correto nos headers', async () => {
      // Arrange
      const accountAddress = 'TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY';
      const beforeTimestamp = Math.floor(Date.now() / 1000);

      mockAxios
        .onGet(`/api/v1/gasfree/account/${accountAddress}`)
        .reply(200, {});

      // Act
      await provider.getAccountInfo(accountAddress);

      // Assert
      const request = mockAxios.history.get[0];
      const timestamp = parseInt(request.headers?.['X-Timestamp'] || '0');
      const afterTimestamp = Math.floor(Date.now() / 1000);

      expect(timestamp).toBeGreaterThanOrEqual(beforeTimestamp);
      expect(timestamp).toBeLessThanOrEqual(afterTimestamp);
    });
  });

  describe('Normalização de Status', () => {
    const statusMappings = [
      { input: 'PENDING', expected: 'PENDING' },
      { input: 'pending', expected: 'PENDING' },
      { input: 'PROCESSING', expected: 'PROCESSING' },
      { input: 'processing', expected: 'PROCESSING' },
      { input: 'CONFIRMED', expected: 'CONFIRMED' },
      { input: 'confirmed', expected: 'CONFIRMED' },
      { input: 'SUCCESS', expected: 'CONFIRMED' },
      { input: 'success', expected: 'CONFIRMED' },
      { input: 'FAILED', expected: 'FAILED' },
      { input: 'failed', expected: 'FAILED' },
      { input: 'ERROR', expected: 'FAILED' },
      { input: 'error', expected: 'FAILED' },
      { input: 'UNKNOWN_STATUS', expected: 'UNKNOWN' },
    ];

    statusMappings.forEach(({ input, expected }) => {
      it(`deve normalizar status '${input}' para '${expected}'`, async () => {
        // Arrange
        const traceId = 'test-trace-id';
        const mockResponse = {
          id: traceId,
          state: input,
        };

        mockAxios.onGet(`/api/v1/gasfree/${traceId}`).reply(200, mockResponse);

        // Act
        const result = await provider.getTransferStatus(traceId);

        // Assert
        expect(result.result.type).toBe('SUCCESS');
        if (result.result.type === 'SUCCESS') {
          expect(result.result.data.status).toBe(expected);
        }
      });
    });
  });
});
