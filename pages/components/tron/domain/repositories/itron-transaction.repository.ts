import { Result, DefaultResultError } from '../../../global/utils/Result';
import { TronTransaction, TransactionStatus, TransactionType } from '../entities/tron-transaction.entity';

export interface FindTronTransactionFilters {
  hash?: string;
  fromAddress?: string;
  toAddress?: string;
  userId?: string;
  orderId?: string;
  status?: TransactionStatus;
  transactionType?: TransactionType;
  networkId?: string;
  tokenAddress?: string;
  createdAfter?: Date;
  createdBefore?: Date;
  limit?: number;
  offset?: number;
}

export interface TransactionStatistics {
  totalTransactions: number;
  pendingTransactions: number;
  confirmedTransactions: number;
  failedTransactions: number;
  totalVolume: string;
}

export interface ITronTransactionRepository {
  /**
   * Create a new TRON transaction
   */
  create(transaction: TronTransaction): Promise<Result<TronTransaction, DefaultResultError>>;

  /**
   * Find a transaction by its ID
   */
  findById(transactionId: string): Promise<Result<TronTransaction, DefaultResultError>>;

  /**
   * Find a transaction by hash
   */
  findByHash(hash: string): Promise<Result<TronTransaction, DefaultResultError>>;

  /**
   * Find transactions with filters
   */
  findMany(filters: FindTronTransactionFilters): Promise<Result<TronTransaction[], DefaultResultError>>;

  /**
   * Find pending transactions
   */
  findPendingTransactions(networkId?: string): Promise<Result<TronTransaction[], DefaultResultError>>;

  /**
   * Find transactions by user
   */
  findByUserId(userId: string, filters?: Partial<FindTronTransactionFilters>): Promise<Result<TronTransaction[], DefaultResultError>>;

  /**
   * Find transactions by order ID
   */
  findByOrderId(orderId: string): Promise<Result<TronTransaction[], DefaultResultError>>;

  /**
   * Update an existing transaction
   */
  update(transactionId: string, transaction: TronTransaction): Promise<Result<TronTransaction, DefaultResultError>>;

  /**
   * Update transaction status
   */
  updateStatus(transactionId: string, status: TransactionStatus, blockNumber?: number, blockHash?: string): Promise<Result<TronTransaction, DefaultResultError>>;

  /**
   * Update transaction hash
   */
  updateHash(transactionId: string, hash: string): Promise<Result<TronTransaction, DefaultResultError>>;

  /**
   * Delete a transaction
   */
  delete(transactionId: string): Promise<Result<boolean, DefaultResultError>>;

  /**
   * Check if a transaction exists by hash
   */
  existsByHash(hash: string): Promise<Result<boolean, DefaultResultError>>;

  /**
   * Get transaction statistics for a user
   */
  getUserStatistics(userId: string, networkId?: string): Promise<Result<TransactionStatistics, DefaultResultError>>;

  /**
   * Get transaction statistics for a period
   */
  getPeriodStatistics(startDate: Date, endDate: Date, networkId?: string): Promise<Result<TransactionStatistics, DefaultResultError>>;

  /**
   * Find transactions requiring confirmation updates
   */
  findTransactionsForConfirmationUpdate(networkId: string): Promise<Result<TronTransaction[], DefaultResultError>>;

  /**
   * Find failed transactions for retry
   */
  findFailedTransactionsForRetry(maxRetries: number): Promise<Result<TronTransaction[], DefaultResultError>>;

  /**
   * Count transactions by status
   */
  countByStatus(status: TransactionStatus, networkId?: string): Promise<Result<number, DefaultResultError>>;

  /**
   * Find recent transactions for monitoring
   */
  findRecentTransactions(limit: number, networkId?: string): Promise<Result<TronTransaction[], DefaultResultError>>;
}