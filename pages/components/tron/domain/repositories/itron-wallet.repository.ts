import { Result, DefaultResultError } from '../../../global/utils/Result';
import { TronWallet } from '../entities/tron-wallet.entity';

export interface FindTronWalletFilters {
  address?: string;
  networkId?: string;
  userId?: string;
  isActive?: boolean;
  isWatchOnly?: boolean;
}

export interface ITronWalletRepository {
  /**
   * Create a new TRON wallet
   */
  create(wallet: TronWallet): Promise<Result<TronWallet, DefaultResultError>>;

  /**
   * Find a wallet by its ID
   */
  findById(walletId: string): Promise<Result<TronWallet, DefaultResultError>>;

  /**
   * Find a wallet by address
   */
  findByAddress(address: string): Promise<Result<TronWallet, DefaultResultError>>;

  /**
   * Find wallets by user ID
   */
  findByUserId(userId: string): Promise<Result<TronWallet[], DefaultResultError>>;

  /**
   * Find wallets with filters
   */
  findMany(filters: FindTronWalletFilters): Promise<Result<TronWallet[], DefaultResultError>>;

  /**
   * Find all active wallets for a network
   */
  findActiveByNetwork(networkId: string): Promise<Result<TronWallet[], DefaultResultError>>;

  /**
   * Update an existing wallet
   */
  update(walletId: string, wallet: TronWallet): Promise<Result<TronWallet, DefaultResultError>>;

  /**
   * Delete a wallet (soft delete - deactivate)
   */
  delete(walletId: string): Promise<Result<boolean, DefaultResultError>>;

  /**
   * Check if a wallet exists by address
   */
  existsByAddress(address: string): Promise<Result<boolean, DefaultResultError>>;

  /**
   * Get user's default wallet for a network
   */
  getUserDefaultWallet(userId: string, networkId: string): Promise<Result<TronWallet, DefaultResultError>>;

  /**
   * Count wallets by user
   */
  countByUser(userId: string): Promise<Result<number, DefaultResultError>>;

  /**
   * Find wallets that can sign transactions
   */
  findSigningWallets(userId: string, networkId?: string): Promise<Result<TronWallet[], DefaultResultError>>;
}