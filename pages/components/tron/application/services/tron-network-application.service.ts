import { Injectable, Inject } from '@nestjs/common';
import { Result, DefaultResultError } from '../../../global/utils/Result';
import { TronNetwork } from '../../domain/entities/tron-network.entity';
import { USDTToken } from '../../domain/entities/usdt-token.entity';
import { TronNetworkService } from '../../domain/services/tron-network.service';
import { ITronNetworkRepository } from '../../domain/repositories/itron-network.repository';
import { IUSDTTokenRepository } from '../../domain/repositories/iusdt-token.repository';
import { TRON_NETWORK_REPOSITORY, USDT_TOKEN_REPOSITORY } from '../../tron.tokens';

export interface CreateNetworkRequest {
  networkId: string;
  name: string;
  rpcUrl: string;
  explorerUrl: string;
  chainId: number;
  isTestnet: boolean;
  gasLimit?: number;
  confirmationsRequired?: number;
}

export interface NetworkStatus {
  networkId: string;
  name: string;
  isActive: boolean;
  isReachable: boolean;
  blockHeight: number | null;
  hasUSDTToken: boolean;
  error?: string;
}

@Injectable()
export class TronNetworkApplicationService {
  constructor(
    @Inject(TRON_NETWORK_REPOSITORY)
    private readonly networkRepository: ITronNetworkRepository,
    @Inject(USDT_TOKEN_REPOSITORY)
    private readonly usdtTokenRepository: IUSDTTokenRepository,
    private readonly networkService: TronNetworkService,
  ) {}

  /**
   * Create a new TRON network configuration
   */
  async createNetwork(request: CreateNetworkRequest): Promise<Result<TronNetwork, DefaultResultError>> {
    try {
      // Check if network already exists
      const existingNetwork = await this.networkRepository.findById(request.networkId);
      if (existingNetwork.result.type === 'SUCCESS') {
        return Result.Error({
          code: 'ALREADY_EXIST',
          payload: 'Network with this ID already exists'
        });
      }

      // Check if chain ID already exists
      const existingChainId = await this.networkRepository.existsByChainId(request.chainId);
      if (existingChainId.result.type === 'SUCCESS' && existingChainId.result.data) {
        return Result.Error({
          code: 'ALREADY_EXIST',
          payload: 'Network with this chain ID already exists'
        });
      }

      // Create network entity
      const networkResult = TronNetwork.create({
        networkId: request.networkId,
        name: request.name,
        rpcUrl: request.rpcUrl,
        explorerUrl: request.explorerUrl,
        chainId: request.chainId,
        isTestnet: request.isTestnet,
        gasLimit: request.gasLimit,
        confirmationsRequired: request.confirmationsRequired
      });

      if (networkResult.result.type === 'ERROR') {
        return Result.Error(networkResult.result.error);
      }

      const network = networkResult.result.data;

      // Validate network configuration
      const validationResult = this.networkService.validateNetworkConfiguration(network);
      if (validationResult.result.type === 'ERROR') {
        return Result.Error(validationResult.result.error);
      }

      // Save network
      return await this.networkRepository.create(network);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to create network: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Get all networks
   */
  async getAllNetworks(): Promise<Result<TronNetwork[], DefaultResultError>> {
    return await this.networkRepository.findMany({});
  }

  /**
   * Get active networks
   */
  async getActiveNetworks(): Promise<Result<TronNetwork[], DefaultResultError>> {
    return await this.networkRepository.findAllActive();
  }

  /**
   * Get network by ID
   */
  async getNetworkById(networkId: string): Promise<Result<TronNetwork, DefaultResultError>> {
    return await this.networkRepository.findById(networkId);
  }

  /**
   * Get network by chain ID
   */
  async getNetworkByChainId(chainId: number): Promise<Result<TronNetwork, DefaultResultError>> {
    return await this.networkRepository.findByChainId(chainId);
  }

  /**
   * Get default network for environment
   */
  async getDefaultNetwork(isTestnet: boolean): Promise<Result<TronNetwork, DefaultResultError>> {
    return await this.networkRepository.getDefaultNetwork(isTestnet);
  }

  /**
   * Update network configuration
   */
  async updateNetwork(
    networkId: string, 
    updates: Partial<CreateNetworkRequest>
  ): Promise<Result<TronNetwork, DefaultResultError>> {
    try {
      // Get existing network
      const networkResult = await this.networkRepository.findById(networkId);
      if (networkResult.result.type === 'ERROR') {
        return Result.Error(networkResult.result.error);
      }

      const network = networkResult.result.data;

      // Update configuration
      const updateResult = network.updateConfiguration({
        name: updates.name,
        rpcUrl: updates.rpcUrl,
        explorerUrl: updates.explorerUrl,
        chainId: updates.chainId,
        isTestnet: updates.isTestnet,
        gasLimit: updates.gasLimit,
        confirmationsRequired: updates.confirmationsRequired
      });

      if (updateResult.result.type === 'ERROR') {
        return Result.Error(updateResult.result.error);
      }

      // Validate updated configuration
      const validationResult = this.networkService.validateNetworkConfiguration(updateResult.result.data);
      if (validationResult.result.type === 'ERROR') {
        return Result.Error(validationResult.result.error);
      }

      // Save updated network
      return await this.networkRepository.update(networkId, updateResult.result.data);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to update network: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Activate network
   */
  async activateNetwork(networkId: string): Promise<Result<TronNetwork, DefaultResultError>> {
    try {
      const networkResult = await this.networkRepository.findById(networkId);
      if (networkResult.result.type === 'ERROR') {
        return Result.Error(networkResult.result.error);
      }

      const network = networkResult.result.data;
      const activatedNetwork = network.activate();
      
      return await this.networkRepository.update(networkId, activatedNetwork);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to activate network: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Deactivate network
   */
  async deactivateNetwork(networkId: string): Promise<Result<TronNetwork, DefaultResultError>> {
    try {
      const networkResult = await this.networkRepository.findById(networkId);
      if (networkResult.result.type === 'ERROR') {
        return Result.Error(networkResult.result.error);
      }

      const network = networkResult.result.data;
      const deactivatedNetwork = network.deactivate();
      
      return await this.networkRepository.update(networkId, deactivatedNetwork);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to deactivate network: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Get optimal network for preferences
   */
  async getOptimalNetwork(preferences: {
    preferTestnet?: boolean;
    minConfirmations?: number;
    maxGasLimit?: number;
  }): Promise<Result<TronNetwork, DefaultResultError>> {
    try {
      const networksResult = await this.getActiveNetworks();
      if (networksResult.result.type === 'ERROR') {
        return Result.Error(networksResult.result.error);
      }

      return this.networkService.selectOptimalNetwork(networksResult.result.data, preferences);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to get optimal network: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Get network status
   */
  async getNetworkStatus(networkId: string): Promise<Result<NetworkStatus, DefaultResultError>> {
    try {
      const networkResult = await this.networkRepository.findById(networkId);
      if (networkResult.result.type === 'ERROR') {
        return Result.Error(networkResult.result.error);
      }

      const network = networkResult.result.data;

      // Check if USDT token is configured
      const usdtTokenResult = await this.usdtTokenRepository.getDefaultForNetwork(networkId);
      const hasUSDTToken = usdtTokenResult.result.type === 'SUCCESS';

      // TODO: In real implementation, check network reachability and block height
      const status: NetworkStatus = {
        networkId: network.networkId,
        name: network.name,
        isActive: network.isActive,
        isReachable: true, // Would be checked via RPC call
        blockHeight: null, // Would be fetched from network
        hasUSDTToken,
        error: undefined
      };

      return Result.Success(status);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to get network status: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Validate network compatibility
   */
  async validateNetworkCompatibility(
    networkId: string, 
    isProduction: boolean
  ): Promise<Result<boolean, DefaultResultError>> {
    try {
      const networkResult = await this.networkRepository.findById(networkId);
      if (networkResult.result.type === 'ERROR') {
        return Result.Error(networkResult.result.error);
      }

      const network = networkResult.result.data;
      return this.networkService.validateNetworkForEnvironment(network, isProduction);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to validate network compatibility: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Get recommended gas limit for transaction type
   */
  getRecommendedGasLimit(network: TronNetwork, transactionType: 'transfer' | 'contract'): number {
    return this.networkService.getRecommendedGasLimit(network, transactionType);
  }

  /**
   * Calculate required confirmations for amount
   */
  calculateRequiredConfirmations(network: TronNetwork, amountInTRX: number): number {
    return this.networkService.calculateRequiredConfirmations(network, amountInTRX);
  }
}