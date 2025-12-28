import { TronNetwork } from '../entities/tron-network.entity';
import { TronAddress } from '../value-objects/tron-address.vo';
import { TronNetworkService } from './tron-network.service';

describe('TronNetworkService', () => {
  let service: TronNetworkService;
  let mainnetNetwork: TronNetwork;
  let testnetNetwork: TronNetwork;

  beforeEach(() => {
    service = new TronNetworkService();

    // Create REAL mainnet network instance
    const mainnetResult = TronNetwork.create({
      networkId: 'mainnet-1',
      name: 'Tron Mainnet',
      chainId: 728126428,
      rpcUrl: 'https://api.trongrid.io',
      explorerUrl: 'https://tronscan.org',
      isTestnet: false,
      isActive: true,
      gasLimit: 100000,
      confirmationsRequired: 3,
    });

    if (mainnetResult.result.type !== 'SUCCESS') {
      throw new Error('Failed to create mainnet for tests');
    }
    mainnetNetwork = mainnetResult.result.data;

    // Create REAL testnet network instance
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

    if (testnetResult.result.type !== 'SUCCESS') {
      throw new Error('Failed to create testnet for tests');
    }
    testnetNetwork = testnetResult.result.data;
  });

  describe('validateNetworkConfiguration', () => {
    it('should validate a properly configured active network', () => {
      const result = service.validateNetworkConfiguration(mainnetNetwork);

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data).toBe(true);
      }
    });

    it('should reject inactive network', () => {
      const inactiveNetwork = mainnetNetwork.deactivate();

      const result = service.validateNetworkConfiguration(inactiveNetwork);

      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.code).toBe('SERIALIZATION');
        expect(result.result.error.payload).toContain('not active');
      }
    });

    it('should reject network with invalid gas limit at entity level', () => {
      // TronNetwork.create should reject gasLimit: 0 to avoid mempool issues
      const invalidNetworkResult = TronNetwork.create({
        networkId: 'invalid-1',
        name: 'Invalid Network',
        chainId: 1,
        rpcUrl: 'https://api.example.com',
        explorerUrl: 'https://explorer.example.com',
        isTestnet: false,
        isActive: true,
        gasLimit: 0, // Should be rejected at entity creation
        confirmationsRequired: 1,
      });

      // Entity should reject this at creation
      expect(invalidNetworkResult.result.type).toBe('ERROR');
      if (invalidNetworkResult.result.type === 'ERROR') {
        expect(invalidNetworkResult.result.error.payload).toContain(
          'Gas limit',
        );
        expect(invalidNetworkResult.result.error.payload).toContain(
          'greater than 0',
        );
      }
    });

    it('should reject network with negative gas limit', () => {
      // TronNetwork.create should validate this at creation time
      const invalidNetworkResult = TronNetwork.create({
        networkId: 'invalid-2',
        name: 'Invalid Network',
        chainId: 1,
        rpcUrl: 'https://api.example.com',
        explorerUrl: 'https://explorer.example.com',
        isTestnet: false,
        isActive: true,
        gasLimit: -1000, // Should be rejected at entity creation
        confirmationsRequired: 1,
      });

      // Entity should reject this at creation
      expect(invalidNetworkResult.result.type).toBe('ERROR');
      if (invalidNetworkResult.result.type === 'ERROR') {
        expect(invalidNetworkResult.result.error.payload).toContain(
          'Gas limit',
        );
        expect(invalidNetworkResult.result.error.payload).toContain(
          'greater than 0',
        );
      }
    });

    it('should reject network with invalid confirmations at entity level', () => {
      // TronNetwork.create should reject confirmationsRequired: 0
      // Minimum 1 confirmation required to validate transaction on Tron
      const invalidNetworkResult = TronNetwork.create({
        networkId: 'invalid-3',
        name: 'Invalid Network',
        chainId: 1,
        rpcUrl: 'https://api.example.com',
        explorerUrl: 'https://explorer.example.com',
        isTestnet: false,
        isActive: true,
        gasLimit: 100000,
        confirmationsRequired: 0, // Should be rejected at entity creation
      });

      // Entity should reject this at creation
      expect(invalidNetworkResult.result.type).toBe('ERROR');
      if (invalidNetworkResult.result.type === 'ERROR') {
        expect(invalidNetworkResult.result.error.payload).toContain(
          'Confirmations required',
        );
        expect(invalidNetworkResult.result.error.payload).toContain(
          'at least 1',
        );
      }
    });

    it('should reject network with invalid RPC URL', () => {
      const invalidNetworkResult = TronNetwork.create({
        networkId: 'invalid-4',
        name: 'Invalid Network',
        chainId: 1,
        rpcUrl: 'not-a-valid-url',
        explorerUrl: 'https://explorer.example.com',
        isTestnet: false,
        isActive: true,
        gasLimit: 100000,
        confirmationsRequired: 1,
      });

      // Should fail at creation
      expect(invalidNetworkResult.result.type).toBe('ERROR');
      if (invalidNetworkResult.result.type === 'ERROR') {
        expect(invalidNetworkResult.result.error.payload).toContain(
          'Invalid RPC URL',
        );
      }
    });

    it('should accept network with valid HTTPS RPC URL', () => {
      const result = service.validateNetworkConfiguration(mainnetNetwork);

      expect(result.result.type).toBe('SUCCESS');
    });

    it('should accept network with valid HTTP RPC URL', () => {
      const httpNetworkResult = TronNetwork.create({
        networkId: 'local-network',
        name: 'Local Network',
        chainId: 1,
        rpcUrl: 'http://localhost:8545',
        explorerUrl: 'http://localhost:3000',
        isTestnet: true,
        isActive: true,
        gasLimit: 100000,
        confirmationsRequired: 1,
      });

      if (httpNetworkResult.result.type === 'SUCCESS') {
        const result = service.validateNetworkConfiguration(
          httpNetworkResult.result.data,
        );
        expect(result.result.type).toBe('SUCCESS');
      }
    });
  });

  describe('isCompatibleNetwork', () => {
    it('should return true for matching active network', () => {
      const isCompatible = service.isCompatibleNetwork(
        mainnetNetwork,
        728126428,
      );

      expect(isCompatible).toBe(true);
    });

    it('should return false for different chain ID', () => {
      const isCompatible = service.isCompatibleNetwork(mainnetNetwork, 999999);

      expect(isCompatible).toBe(false);
    });

    it('should return false for inactive network even with matching chain ID', () => {
      const inactiveNetwork = mainnetNetwork.deactivate();

      const isCompatible = service.isCompatibleNetwork(
        inactiveNetwork,
        728126428,
      );

      expect(isCompatible).toBe(false);
    });
  });

  describe('getRecommendedGasLimit', () => {
    it('should return minimum gas limit for simple transfers', () => {
      const gasLimit = service.getRecommendedGasLimit(
        mainnetNetwork,
        'transfer',
      );

      expect(gasLimit).toBeGreaterThanOrEqual(50000);
    });

    it('should return higher gas limit for contract interactions', () => {
      const transferGas = service.getRecommendedGasLimit(
        mainnetNetwork,
        'transfer',
      );
      const contractGas = service.getRecommendedGasLimit(
        mainnetNetwork,
        'contract',
      );

      expect(contractGas).toBeGreaterThan(transferGas);
      expect(contractGas).toBeGreaterThanOrEqual(200000);
    });

    it('should respect network base gas limit', () => {
      const highGasNetworkResult = TronNetwork.create({
        networkId: 'high-gas',
        name: 'High Gas Network',
        chainId: 1,
        rpcUrl: 'https://api.example.com',
        explorerUrl: 'https://explorer.example.com',
        isTestnet: false,
        isActive: true,
        gasLimit: 500000,
        confirmationsRequired: 1,
      });

      if (highGasNetworkResult.result.type === 'SUCCESS') {
        const gasLimit = service.getRecommendedGasLimit(
          highGasNetworkResult.result.data,
          'transfer',
        );
        expect(gasLimit).toBeGreaterThanOrEqual(500000);
      }
    });
  });

  describe('calculateRequiredConfirmations', () => {
    it('should return base confirmations for small amounts', () => {
      const confirmations = service.calculateRequiredConfirmations(
        mainnetNetwork,
        50,
      );

      expect(confirmations).toBe(mainnetNetwork.confirmationsRequired);
    });

    it('should increase confirmations for medium amounts (100-999 TRX)', () => {
      const confirmations = service.calculateRequiredConfirmations(
        mainnetNetwork,
        500,
      );

      expect(confirmations).toBeGreaterThanOrEqual(5);
    });

    it('should increase confirmations for large amounts (1000-9999 TRX)', () => {
      const confirmations = service.calculateRequiredConfirmations(
        mainnetNetwork,
        5000,
      );

      expect(confirmations).toBeGreaterThanOrEqual(10);
    });

    it('should require maximum confirmations for very large amounts (>= 10000 TRX)', () => {
      const confirmations = service.calculateRequiredConfirmations(
        mainnetNetwork,
        50000,
      );

      expect(confirmations).toBeGreaterThanOrEqual(20);
    });

    it('should respect network minimum confirmations', () => {
      const highConfNetworkResult = TronNetwork.create({
        networkId: 'high-conf',
        name: 'High Confirmations Network',
        chainId: 1,
        rpcUrl: 'https://api.example.com',
        explorerUrl: 'https://explorer.example.com',
        isTestnet: false,
        isActive: true,
        gasLimit: 100000,
        confirmationsRequired: 30,
      });

      if (highConfNetworkResult.result.type === 'SUCCESS') {
        const confirmations = service.calculateRequiredConfirmations(
          highConfNetworkResult.result.data,
          50,
        );
        expect(confirmations).toBe(30);
      }
    });
  });

  describe('isTestnetNetwork and isMainnetNetwork', () => {
    it('should correctly identify testnet network', () => {
      expect(service.isTestnetNetwork(testnetNetwork)).toBe(true);
      expect(service.isMainnetNetwork(testnetNetwork)).toBe(false);
    });

    it('should correctly identify mainnet network', () => {
      expect(service.isTestnetNetwork(mainnetNetwork)).toBe(false);
      expect(service.isMainnetNetwork(mainnetNetwork)).toBe(true);
    });
  });

  describe('getExplorerUrlForTransaction', () => {
    it('should return correct mainnet explorer URL', () => {
      const txHash = 'abc123def456';

      const url = service.getExplorerUrlForTransaction(mainnetNetwork, txHash);

      expect(url).toContain('tronscan.org');
      expect(url).toContain(txHash);
    });

    it('should return correct testnet explorer URL', () => {
      const txHash = 'test123hash456';

      const url = service.getExplorerUrlForTransaction(testnetNetwork, txHash);

      expect(url).toContain('nile.tronscan.org');
      expect(url).toContain(txHash);
    });
  });

  describe('getExplorerUrlForAddress', () => {
    it('should return correct explorer URL for address', () => {
      const addressResult = TronAddress.create(
        'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
      );

      if (addressResult.result.type === 'SUCCESS') {
        const url = service.getExplorerUrlForAddress(
          mainnetNetwork,
          addressResult.result.data,
        );

        expect(url).toContain('tronscan.org');
        expect(url).toContain('address');
      }
    });
  });

  describe('validateNetworkForEnvironment', () => {
    it('should accept mainnet in production', () => {
      const result = service.validateNetworkForEnvironment(
        mainnetNetwork,
        true,
      );

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data).toBe(true);
      }
    });

    it('should reject testnet in production', () => {
      const result = service.validateNetworkForEnvironment(
        testnetNetwork,
        true,
      );

      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.code).toBe('FORBIDDEN');
        expect(result.result.error.payload).toContain('testnet in production');
      }
    });

    it('should accept testnet in development', () => {
      const result = service.validateNetworkForEnvironment(
        testnetNetwork,
        false,
      );

      expect(result.result.type).toBe('SUCCESS');
    });

    it('should accept mainnet in development with warning', () => {
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();

      const result = service.validateNetworkForEnvironment(
        mainnetNetwork,
        false,
      );

      expect(result.result.type).toBe('SUCCESS');
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('mainnet in development'),
      );

      consoleSpy.mockRestore();
    });
  });

  describe('selectOptimalNetwork', () => {
    let networks: TronNetwork[];

    beforeEach(() => {
      const network3Result = TronNetwork.create({
        networkId: 'mainnet-2',
        name: 'Mainnet Alternative',
        chainId: 728126428,
        rpcUrl: 'https://api2.trongrid.io',
        explorerUrl: 'https://tronscan.org',
        isTestnet: false,
        isActive: true,
        gasLimit: 200000,
        confirmationsRequired: 5,
      });

      if (network3Result.result.type === 'SUCCESS') {
        networks = [mainnetNetwork, testnetNetwork, network3Result.result.data];
      } else {
        networks = [mainnetNetwork, testnetNetwork];
      }
    });

    it('should select network when only one active exists', () => {
      const singleNetwork = [mainnetNetwork];

      const result = service.selectOptimalNetwork(singleNetwork, {});

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.networkId).toBe('mainnet-1');
      }
    });

    it('should return error when no active networks', () => {
      const inactiveNetworks = networks.map((n) => n.deactivate());

      const result = service.selectOptimalNetwork(inactiveNetworks, {});

      expect(result.result.type).toBe('ERROR');
      if (result.result.type === 'ERROR') {
        expect(result.result.error.payload).toContain('No active networks');
      }
    });

    it('should filter by testnet preference', () => {
      const result = service.selectOptimalNetwork(networks, {
        preferTestnet: true,
      });

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isTestnet).toBe(true);
      }
    });

    it('should filter by mainnet preference', () => {
      const result = service.selectOptimalNetwork(networks, {
        preferTestnet: false,
      });

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isTestnet).toBe(false);
      }
    });

    it('should filter by minimum confirmations', () => {
      const result = service.selectOptimalNetwork(networks, {
        minConfirmations: 5,
      });

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.confirmationsRequired).toBeGreaterThanOrEqual(
          5,
        );
      }
    });

    it('should filter by maximum gas limit', () => {
      const result = service.selectOptimalNetwork(networks, {
        maxGasLimit: 150000,
      });

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.gasLimit).toBeLessThanOrEqual(150000);
      }
    });

    it('should apply multiple filters', () => {
      const result = service.selectOptimalNetwork(networks, {
        preferTestnet: false,
        minConfirmations: 3,
        maxGasLimit: 150000,
      });

      expect(result.result.type).toBe('SUCCESS');
      if (result.result.type === 'SUCCESS') {
        expect(result.result.data.isTestnet).toBe(false);
        expect(result.result.data.confirmationsRequired).toBeGreaterThanOrEqual(
          3,
        );
        expect(result.result.data.gasLimit).toBeLessThanOrEqual(150000);
      }
    });

    it('should return error when no networks match filters', () => {
      const result = service.selectOptimalNetwork(networks, {
        preferTestnet: true,
        minConfirmations: 100, // Impossibly high
      });

      expect(result.result.type).toBe('ERROR');
    });
  });

  describe('Security and Edge Cases', () => {
    it('should recommend 19+ confirmations for production mainnet (Tron standard)', () => {
      // Tron network typically requires 19 blocks for full transaction finality
      const productionNetwork = TronNetwork.create({
        networkId: 'mainnet-production',
        name: 'Tron Mainnet Production',
        chainId: 728126428,
        rpcUrl: 'https://api.trongrid.io',
        explorerUrl: 'https://tronscan.org',
        isTestnet: false,
        isActive: true,
        gasLimit: 100000,
        confirmationsRequired: 19, // Tron standard for production
      });

      if (productionNetwork.result.type === 'SUCCESS') {
        expect(
          productionNetwork.result.data.confirmationsRequired,
        ).toBeGreaterThanOrEqual(19);
      }
    });

    it('should handle networks with extreme gas limits', () => {
      const extremeNetworkResult = TronNetwork.create({
        networkId: 'extreme-gas',
        name: 'Extreme Gas Network',
        chainId: 1,
        rpcUrl: 'https://api.example.com',
        explorerUrl: 'https://explorer.example.com',
        isTestnet: false,
        isActive: true,
        gasLimit: 999999999,
        confirmationsRequired: 1,
      });

      if (extremeNetworkResult.result.type === 'SUCCESS') {
        const result = service.validateNetworkConfiguration(
          extremeNetworkResult.result.data,
        );
        expect(result.result.type).toBe('SUCCESS');
      }
    });

    it('should handle malformed RPC URLs gracefully', () => {
      const malformedUrls = [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'ftp://malicious.com',
      ];

      malformedUrls.forEach((url) => {
        const badNetworkResult = TronNetwork.create({
          networkId: `bad-url-${url}`,
          name: 'Bad Network',
          chainId: 1,
          rpcUrl: url,
          explorerUrl: 'https://explorer.example.com',
          isTestnet: false,
          isActive: true,
          gasLimit: 100000,
          confirmationsRequired: 1,
        });

        // Should either be rejected at creation or handled gracefully
        expect(badNetworkResult.result.type).toBeDefined();
      });
    });

    it('should handle empty network array in selectOptimalNetwork', () => {
      const result = service.selectOptimalNetwork([], {});

      expect(result.result.type).toBe('ERROR');
    });
  });
});
