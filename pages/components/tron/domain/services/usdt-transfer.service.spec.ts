import { TronNetwork } from '../entities/tron-network.entity';
import { TransactionType } from '../entities/tron-transaction.entity';
import { TronWallet } from '../entities/tron-wallet.entity';
import { USDTToken } from '../entities/usdt-token.entity';
import { TokenAmount } from '../value-objects/token-amount.vo';
import { TronAddress } from '../value-objects/tron-address.vo';
import { USDTTransferService } from './usdt-transfer.service';

describe('USDTTransferService', () => {
  let service: USDTTransferService;
  let mainnetNetwork: TronNetwork;
  let testnetNetwork: TronNetwork;
  let mainnetUSDT: USDTToken;
  let testnetUSDT: USDTToken;
  let senderWallet: TronWallet;
  let watchOnlyWallet: TronWallet;
  let recipientAddress: TronAddress;

  beforeEach(() => {
    service = new USDTTransferService();

    // Create REAL mainnet network
    const mainnetResult = TronNetwork.create({
      networkId: 'mainnet-1',
      name: 'Tron Mainnet',
      chainId: 728126428,
      rpcUrl: 'https://api.trongrid.io',
      explorerUrl: 'https://tronscan.org',
      isTestnet: false,
      isActive: true,
      gasLimit: 100000,
      confirmationsRequired: 19,
    });
    if (mainnetResult.result.type !== 'SUCCESS')
      throw new Error('Failed to create mainnet');
    mainnetNetwork = mainnetResult.result.data;

    // Create REAL testnet network
    const testnetResult = TronNetwork.create({
      networkId: 'nile-testnet',
      name: 'Nile Testnet',
      chainId: 3448148188,
      rpcUrl: 'https://nile.trongrid.io',
      explorerUrl: 'https://nile.tronscan.org',
      isTestnet: true,
      isActive: true,
      gasLimit: 100000,
      confirmationsRequired: 1,
    });
    if (testnetResult.result.type !== 'SUCCESS')
      throw new Error('Failed to create testnet');
    testnetNetwork = testnetResult.result.data;

    // Create REAL USDT tokens
    const mainnetUSDTResult = USDTToken.create({
      contractAddress: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t', // Mainnet USDT
      networkId: 'mainnet-1',
      decimals: 6,
      symbol: 'USDT',
      name: 'Tether USD',
      isActive: true,
    });
    if (mainnetUSDTResult.result.type !== 'SUCCESS')
      throw new Error('Failed to create mainnet USDT');
    mainnetUSDT = mainnetUSDTResult.result.data;

    const testnetUSDTResult = USDTToken.create({
      contractAddress: 'TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf', // Nile testnet USDT
      networkId: 'nile-testnet',
      decimals: 6,
      symbol: 'USDT',
      name: 'Tether USD (Testnet)',
      isActive: true,
    });
    if (testnetUSDTResult.result.type !== 'SUCCESS')
      throw new Error('Failed to create testnet USDT');
    testnetUSDT = testnetUSDTResult.result.data;

    // Create REAL wallets
    const senderWalletResult = TronWallet.create({
      address: 'TYZy8CZ2eF1xNJQqM5pZgCKzDxzq8rJWCX',
      privateKey: 'a'.repeat(64), // Valid private key format
      networkId: 'mainnet-1',
      label: 'Sender Wallet',
      isWatchOnly: false,
      userId: 'user-123',
    });
    if (senderWalletResult.result.type !== 'SUCCESS')
      throw new Error('Failed to create sender wallet');
    senderWallet = senderWalletResult.result.data;

    const watchOnlyWalletResult = TronWallet.create({
      address: 'TABcdEfGhIjKlMnOpQrStUvWxYz123456A',
      networkId: 'mainnet-1',
      label: 'Watch Only Wallet',
      isWatchOnly: true,
    });
    if (watchOnlyWalletResult.result.type !== 'SUCCESS')
      throw new Error('Failed to create watch-only wallet');
    watchOnlyWallet = watchOnlyWalletResult.result.data;

    // Create REAL recipient address
    const recipientResult = TronAddress.create(
      'TJRabPrwbZy45sbavfcjinPJC18kjpRTv8',
    );
    if (recipientResult.result.type !== 'SUCCESS')
      throw new Error('Failed to create recipient address');
    recipientAddress = recipientResult.result.data;
  });

  describe('validateTransferRequest', () => {
    it('should validate a correct USDT transfer request', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
        userId: 'user-123',
        orderId: 'order-456',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(true);
        expect(result.result.data.errors).toHaveLength(0);
      }
    });

    it('should reject transfer from watch-only wallet', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: watchOnlyWallet,
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(false);
        expect(result.result.data.errors).toContain(
          'Source wallet cannot sign transactions (watch-only or missing private key)',
        );
      }
    });

    it('should reject transfer from inactive wallet', () => {
      const inactiveWallet = senderWallet.deactivate();
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: inactiveWallet,
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(false);
        expect(result.result.data.errors).toContain(
          'Source wallet is not active',
        );
      }
    });

    it('should reject transfer with network mismatch (wallet vs transaction)', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: senderWallet, // mainnet-1
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'nile-testnet', // different network
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(false);
        expect(result.result.data.errors).toContain(
          'Source wallet network does not match transaction network',
        );
      }
    });

    it('should reject transfer with inactive USDT token', () => {
      const inactiveToken = mainnetUSDT.deactivate();
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: inactiveToken,
        networkId: 'mainnet-1',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(false);
        expect(result.result.data.errors).toContain('USDT token is not active');
      }
    });

    it('should reject transfer with network mismatch (token vs transaction)', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: testnetUSDT, // nile-testnet
        networkId: 'mainnet-1', // different network
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(false);
        expect(result.result.data.errors).toContain(
          'USDT token network does not match transaction network',
        );
      }
    });

    it('should reject transfer to same address', () => {
      const sameAddressResult = TronAddress.create(
        'TYZy8CZ2eF1xNJQqM5pZgCKzDxzq8rJWCX',
      ); // Same as sender
      if (sameAddressResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create same address');

      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: sameAddressResult.result.data,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(false);
        expect(result.result.data.errors).toContain(
          'Cannot transfer to the same address',
        );
      }
    });

    it('should reject transfer with zero amount', () => {
      const zeroAmountResult = TokenAmount.create('0', 6);

      // TokenAmount should reject zero, but if it doesn't, service should
      if (zeroAmountResult.result.type === 'SUCCESS') {
        const request = {
          fromWallet: senderWallet,
          toAddress: recipientAddress,
          amount: zeroAmountResult.result.data,
          usdtToken: mainnetUSDT,
          networkId: 'mainnet-1',
        };

        const result = service.validateTransferRequest(request);

        expect(result.result.type).toBe('SUCCESS');
        if (result.result.type === 'SUCCESS') {
          expect(result.result.data.isValid).toBe(false);
          expect(
            result.result.data.errors.some((e) =>
              e.includes('greater than zero'),
            ),
          ).toBe(true);
        }
      }
    });

    it('should reject transfer below minimum amount', () => {
      // Minimum is 0.000001 USDT (1 in smallest unit)
      const tinyAmountResult = TokenAmount.fromSmallestUnit('0', 6); // Less than minimum

      if (tinyAmountResult.result.type === 'SUCCESS') {
        const request = {
          fromWallet: senderWallet,
          toAddress: recipientAddress,
          amount: tinyAmountResult.result.data,
          usdtToken: mainnetUSDT,
          networkId: 'mainnet-1',
        };

        const result = service.validateTransferRequest(request);

        expect(result.result.type).toBe('SUCCESS');
        if (result.result.type === 'SUCCESS') {
          expect(result.result.data.isValid).toBe(false);
        }
      }
    });

    it('should reject transfer above maximum amount', () => {
      // Maximum is 1,000,000 USDT
      const hugeAmountResult = TokenAmount.create('2000000', 6); // Above maximum
      if (hugeAmountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create huge amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: hugeAmountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(false);
        expect(
          result.result.data.errors.some((e) => e.includes('maximum')),
        ).toBe(true);
      }
    });

    it('should add warning for large transfer amounts (>= 10,000 USDT)', () => {
      const largeAmountResult = TokenAmount.create('15000', 6);
      if (largeAmountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create large amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: largeAmountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(true);
        expect(result.result.data.warnings).toContain(
          'Large transfer amount detected - consider splitting into multiple transactions',
        );
      }
    });

    it('should add warning for testnet USDT transfers', () => {
      const testWalletResult = TronWallet.create({
        address: 'TTestWallet1234567890123456789012A',
        privateKey: 'b'.repeat(64),
        networkId: 'nile-testnet',
        label: 'Test Wallet',
      });
      if (testWalletResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create test wallet');

      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: testWalletResult.result.data,
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: testnetUSDT,
        networkId: 'nile-testnet',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.warnings).toContain(
          'Using testnet USDT - ensure this is intended for testing only',
        );
      }
    });

    it('should include estimated gas fee in validation result', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.estimatedGasFee).toBeDefined();
      }
    });
  });

  describe('createTransferTransaction', () => {
    it('should create a valid USDT transfer transaction', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
        userId: 'user-123',
        orderId: 'order-456',
        metadata: { memo: 'Test transfer' },
      };

      const result = service.createTransferTransaction(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        const tx = result.result.data;
        expect(tx.fromAddress).toBe(senderWallet.address);
        expect(tx.toAddress).toBe(recipientAddress.value);
        expect(tx.amount).toBe('100');
        expect(tx.tokenAddress).toBe(mainnetUSDT.contractAddress);
        expect(tx.transactionType).toBe(TransactionType.USDT_TRANSFER);
        expect(tx.networkId).toBe('mainnet-1');
        expect(tx.gasLimit).toBe(200000); // Higher gas for contract calls
        expect(tx.userId).toBe('user-123');
        expect(tx.orderId).toBe('order-456');
        expect(tx.metadata).toMatchObject({
          memo: 'Test transfer',
          tokenSymbol: 'USDT',
          tokenDecimals: 6,
          walletId: senderWallet.walletId,
        });
      }
    });

    it('should reject transaction creation if validation fails', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: watchOnlyWallet, // Cannot sign
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const result = service.createTransferTransaction(request);

      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.payload).toContain(
          'cannot sign transactions',
        );
      }
    });
  });

  describe('calculateGasFeeEstimate', () => {
    it('should calculate gas fee for low network congestion', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const result = service.calculateGasFeeEstimate(
        amountResult.result.data,
        'low',
      );

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.amount).toBe(BigInt(80000));
      }
    });

    it('should calculate gas fee for medium network congestion', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const result = service.calculateGasFeeEstimate(
        amountResult.result.data,
        'medium',
      );

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.amount).toBe(BigInt(120000));
      }
    });

    it('should calculate gas fee for high network congestion', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const result = service.calculateGasFeeEstimate(
        amountResult.result.data,
        'high',
      );

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.amount).toBe(BigInt(200000));
      }
    });

    it('should increase gas fee for large amounts (>= 50,000 USDT)', () => {
      const largeAmountResult = TokenAmount.create('60000', 6);
      if (largeAmountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create large amount');

      const result = service.calculateGasFeeEstimate(
        largeAmountResult.result.data,
        'medium',
      );

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        // Should be 120000 * 1.2 = 144000
        expect(result.result.data.amount).toBeGreaterThan(BigInt(120000));
      }
    });
  });

  describe('validateTransferAmount', () => {
    it('should validate amount within limits', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const result = service.validateTransferAmount(
        amountResult.result.data,
        mainnetUSDT,
      );

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data).toBe(true);
      }
    });

    it('should reject amount below minimum', () => {
      const tinyAmountResult = TokenAmount.fromSmallestUnit('0', 6);
      if (tinyAmountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create tiny amount');

      const result = service.validateTransferAmount(
        tinyAmountResult.result.data,
        mainnetUSDT,
      );

      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.payload).toContain('below minimum');
      }
    });

    it('should reject amount above maximum', () => {
      const hugeAmountResult = TokenAmount.create('2000000', 6);
      if (hugeAmountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create huge amount');

      const result = service.validateTransferAmount(
        hugeAmountResult.result.data,
        mainnetUSDT,
      );

      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.payload).toContain('exceeds maximum');
      }
    });

    it('should reject amount exceeding available balance', () => {
      const amountResult = TokenAmount.create('100', 6);
      const balanceResult = TokenAmount.create('50', 6);

      if (
        amountResult.result.type !== 'SUCCESS' ||
        balanceResult.result.type !== 'SUCCESS'
      ) {
        throw new Error('Failed to create amounts');
      }

      const result = service.validateTransferAmount(
        amountResult.result.data,
        mainnetUSDT,
        balanceResult.result.data,
      );

      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.payload).toContain('Insufficient balance');
      }
    });
  });

  describe('isHighValueTransfer', () => {
    it('should identify high value transfers (>= $10,000)', () => {
      const highValueResult = TokenAmount.create('15000', 6);
      if (highValueResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create high value');

      const isHighValue = service.isHighValueTransfer(
        highValueResult.result.data,
      );

      expect(isHighValue).toBe(true);
    });

    it('should not identify low value transfers as high value', () => {
      const lowValueResult = TokenAmount.create('5000', 6);
      if (lowValueResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create low value');

      const isHighValue = service.isHighValueTransfer(
        lowValueResult.result.data,
      );

      expect(isHighValue).toBe(false);
    });

    it('should use custom threshold', () => {
      const amountResult = TokenAmount.create('30000', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const isHighValue = service.isHighValueTransfer(
        amountResult.result.data,
        50000,
      );

      expect(isHighValue).toBe(false); // Below custom threshold
    });
  });

  describe('suggestOptimalGasLimit', () => {
    it('should suggest correct gas limit for standard transfer with low congestion', () => {
      const gasLimit = service.suggestOptimalGasLimit('standard', 'low');
      expect(gasLimit).toBe(80000);
    });

    it('should suggest correct gas limit for standard transfer with medium congestion', () => {
      const gasLimit = service.suggestOptimalGasLimit('standard', 'medium');
      expect(gasLimit).toBe(120000);
    });

    it('should suggest correct gas limit for standard transfer with high congestion', () => {
      const gasLimit = service.suggestOptimalGasLimit('standard', 'high');
      expect(gasLimit).toBe(180000);
    });

    it('should suggest higher gas limit for high priority transfers', () => {
      const standardGas = service.suggestOptimalGasLimit('standard', 'medium');
      const priorityGas = service.suggestOptimalGasLimit(
        'high_priority',
        'medium',
      );

      expect(priorityGas).toBeGreaterThan(standardGas);
      expect(priorityGas).toBe(180000);
    });
  });

  describe('formatTransferSummary', () => {
    it('should format transfer summary correctly', () => {
      const amountResult = TokenAmount.create('100.5', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const summary = service.formatTransferSummary(request);

      expect(summary).toContain('Transfer');
      expect(summary).toContain('100.5');
      expect(summary).toContain('USDT');
      expect(summary).toContain('TYZy8C...JWCX'); // Shortened sender address
      expect(summary).toContain('TJRabP...RTv8'); // Shortened recipient address
    });
  });

  describe('Security and Edge Cases', () => {
    it('should handle multiple validation errors', () => {
      const inactiveWallet = watchOnlyWallet.deactivate();
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const request = {
        fromWallet: inactiveWallet, // Watch-only AND inactive
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(false);
        expect(result.result.data.errors.length).toBeGreaterThanOrEqual(2);
      }
    });

    it('should handle edge case of exactly minimum amount', () => {
      const minAmountResult = TokenAmount.fromSmallestUnit('1', 6); // Exactly 0.000001 USDT
      if (minAmountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create min amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: minAmountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(true);
      }
    });

    it('should handle edge case of exactly maximum amount', () => {
      const maxAmountResult = TokenAmount.create('1000000', 6); // Exactly 1,000,000 USDT
      if (maxAmountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create max amount');

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: maxAmountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
      };

      const result = service.validateTransferRequest(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isValid).toBe(true);
      }
    });

    it('should preserve metadata in transaction creation', () => {
      const amountResult = TokenAmount.create('100', 6);
      if (amountResult.result.type !== 'SUCCESS')
        throw new Error('Failed to create amount');

      const customMetadata = {
        customField1: 'value1',
        customField2: 123,
        nestedData: { key: 'value' },
      };

      const request = {
        fromWallet: senderWallet,
        toAddress: recipientAddress,
        amount: amountResult.result.data,
        usdtToken: mainnetUSDT,
        networkId: 'mainnet-1',
        userId: 'user-123',
        metadata: customMetadata,
      };

      const result = service.createTransferTransaction(request);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.metadata).toMatchObject(customMetadata);
      }
    });
  });
});
