import { Result, DefaultResultError } from '../../../global/utils/Result';
import { TronNetwork } from '../entities/tron-network.entity';
import { TronAddress } from '../value-objects/tron-address.vo';

export interface NetworkValidationResult {
  isValid: boolean;
  isReachable: boolean;
  chainId: number | null;
  blockHeight: number | null;
  error?: string;
}

export class TronNetworkService {
  
  public validateNetworkConfiguration(network: TronNetwork): Result<boolean, DefaultResultError> {
    try {
      // Validate basic network properties
      if (!network.isActive) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Network is not active'
        });
      }

      if (network.gasLimit <= 0) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Gas limit must be greater than 0'
        });
      }

      if (network.confirmationsRequired <= 0) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Confirmations required must be greater than 0'
        });
      }

      // Validate RPC URL format
      try {
        new URL(network.rpcUrl);
      } catch {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid RPC URL format'
        });
      }

      return Result.Success(true);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Network validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public isCompatibleNetwork(network: TronNetwork, targetChainId: number): boolean {
    return network.chainId === targetChainId && network.isActive;
  }

  public getRecommendedGasLimit(network: TronNetwork, transactionType: 'transfer' | 'contract'): number {
    const baseGasLimit = network.gasLimit;
    
    switch (transactionType) {
      case 'transfer':
        return Math.max(baseGasLimit, 50000); // Minimum for simple transfers
      case 'contract':
        return Math.max(baseGasLimit, 200000); // Higher limit for contract interactions
      default:
        return baseGasLimit;
    }
  }

  public calculateRequiredConfirmations(network: TronNetwork, amountInTRX: number): number {
    const baseConfirmations = network.confirmationsRequired;
    
    // Increase confirmations for larger amounts
    if (amountInTRX >= 10000) {
      return Math.max(baseConfirmations, 20);
    } else if (amountInTRX >= 1000) {
      return Math.max(baseConfirmations, 10);
    } else if (amountInTRX >= 100) {
      return Math.max(baseConfirmations, 5);
    }
    
    return baseConfirmations;
  }

  public isTestnetNetwork(network: TronNetwork): boolean {
    return network.isTestnet;
  }

  public isMainnetNetwork(network: TronNetwork): boolean {
    return !network.isTestnet;
  }

  public getExplorerUrlForTransaction(network: TronNetwork, txHash: string): string {
    return network.getExplorerTxUrl(txHash);
  }

  public getExplorerUrlForAddress(network: TronNetwork, address: TronAddress): string {
    return network.getExplorerAddressUrl(address.value);
  }

  public validateNetworkForEnvironment(network: TronNetwork, isProduction: boolean): Result<boolean, DefaultResultError> {
    if (isProduction && network.isTestnet) {
      return Result.Error({
        code: 'FORBIDDEN',
        payload: 'Cannot use testnet in production environment'
      });
    }

    if (!isProduction && !network.isTestnet) {
      // Warning but not error for development using mainnet
      console.warn('Using mainnet in development environment');
    }

    return Result.Success(true);
  }

  public selectOptimalNetwork(networks: TronNetwork[], preferences: {
    preferTestnet?: boolean;
    minConfirmations?: number;
    maxGasLimit?: number;
  }): Result<TronNetwork, DefaultResultError> {
    const activeNetworks = networks.filter(n => n.isActive);
    
    if (activeNetworks.length === 0) {
      return Result.Error({
        code: 'NOT_FOUND',
        payload: 'No active networks available'
      });
    }

    let candidates = activeNetworks;

    // Filter by testnet preference
    if (preferences.preferTestnet !== undefined) {
      candidates = candidates.filter(n => n.isTestnet === preferences.preferTestnet);
    }

    // Filter by minimum confirmations
    if (preferences.minConfirmations !== undefined) {
      candidates = candidates.filter(n => n.confirmationsRequired >= preferences.minConfirmations!);
    }

    // Filter by maximum gas limit
    if (preferences.maxGasLimit !== undefined) {
      candidates = candidates.filter(n => n.gasLimit <= preferences.maxGasLimit!);
    }

    if (candidates.length === 0) {
      return Result.Error({
        code: 'NOT_FOUND',
        payload: 'No networks match the specified preferences'
      });
    }

    // Select the first suitable network (could implement more sophisticated selection logic)
    return Result.Success(candidates[0]);
  }

  public compareNetworkReliability(networkA: TronNetwork, networkB: TronNetwork): number {
    // Simple comparison based on configuration
    // In practice, this might include historical uptime, response times, etc.
    
    let scoreA = 0;
    let scoreB = 0;

    // Prefer mainnet over testnet for reliability
    if (!networkA.isTestnet) scoreA += 10;
    if (!networkB.isTestnet) scoreB += 10;

    // Lower confirmations required = faster (but less secure)
    scoreA += Math.max(0, 10 - networkA.confirmationsRequired);
    scoreB += Math.max(0, 10 - networkB.confirmationsRequired);

    // Higher gas limit = more flexible
    scoreA += Math.min(5, networkA.gasLimit / 20000);
    scoreB += Math.min(5, networkB.gasLimit / 20000);

    return scoreA - scoreB; // Positive if A is better, negative if B is better
  }
}