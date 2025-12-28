import { Result, DefaultResultError } from '../../../global/utils/Result';
import { TronNetwork } from '../entities/tron-network.entity';

export interface FindTronNetworkFilters {
  networkId?: string;
  chainId?: number;
  isTestnet?: boolean;
  isActive?: boolean;
}

export interface ITronNetworkRepository {
  /**
   * Create a new TRON network
   */
  create(network: TronNetwork): Promise<Result<TronNetwork, DefaultResultError>>;

  /**
   * Find a network by its ID
   */
  findById(networkId: string): Promise<Result<TronNetwork, DefaultResultError>>;

  /**
   * Find a network by chain ID
   */
  findByChainId(chainId: number): Promise<Result<TronNetwork, DefaultResultError>>;

  /**
   * Find networks with filters
   */
  findMany(filters: FindTronNetworkFilters): Promise<Result<TronNetwork[], DefaultResultError>>;

  /**
   * Find all active networks
   */
  findAllActive(): Promise<Result<TronNetwork[], DefaultResultError>>;

  /**
   * Update an existing network
   */
  update(networkId: string, network: TronNetwork): Promise<Result<TronNetwork, DefaultResultError>>;

  /**
   * Delete a network (soft delete - deactivate)
   */
  delete(networkId: string): Promise<Result<boolean, DefaultResultError>>;

  /**
   * Check if a network exists by chain ID
   */
  existsByChainId(chainId: number): Promise<Result<boolean, DefaultResultError>>;

  /**
   * Get default network for environment
   */
  getDefaultNetwork(isTestnet: boolean): Promise<Result<TronNetwork, DefaultResultError>>;
}