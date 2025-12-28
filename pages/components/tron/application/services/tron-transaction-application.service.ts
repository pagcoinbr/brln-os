import { Injectable, Inject } from '@nestjs/common';
import { Result, DefaultResultError } from '../../../global/utils/Result';
import { TronTransaction, TransactionStatus, TransactionType } from '../../domain/entities/tron-transaction.entity';
import { USDTTransferService, USDTTransferRequest } from '../../domain/services/usdt-transfer.service';
import { TronValidationService } from '../../domain/services/tron-validation.service';
import { TronAddress } from '../../domain/value-objects/tron-address.vo';
import { TokenAmount } from '../../domain/value-objects/token-amount.vo';
import { TransactionHash } from '../../domain/value-objects/transaction-hash.vo';
import { ITronTransactionRepository, TransactionStatistics } from '../../domain/repositories/itron-transaction.repository';
import { ITronWalletRepository } from '../../domain/repositories/itron-wallet.repository';
import { IUSDTTokenRepository } from '../../domain/repositories/iusdt-token.repository';
import { 
  TRON_TRANSACTION_REPOSITORY, 
  TRON_WALLET_REPOSITORY, 
  USDT_TOKEN_REPOSITORY 
} from '../../tron.tokens';

export interface CreateUSDTTransferRequest {
  fromWalletId: string;
  toAddress: string;
  amount: string;
  networkId: string;
  userId: string;
  orderId?: string;
  metadata?: Record<string, any>;
}

export interface TransactionSearchFilters {
  userId?: string;
  orderId?: string;
  status?: TransactionStatus;
  transactionType?: TransactionType;
  fromAddress?: string;
  toAddress?: string;
  networkId?: string;
  createdAfter?: Date;
  createdBefore?: Date;
  limit?: number;
  offset?: number;
}

export interface TransactionSummary {
  transactionId: string;
  hash: string | null;
  amount: string;
  status: TransactionStatus;
  fromAddress: string;
  toAddress: string;
  createdAt: Date;
  confirmedAt: Date | null;
}

@Injectable()
export class TronTransactionApplicationService {
  constructor(
    @Inject(TRON_TRANSACTION_REPOSITORY)
    private readonly transactionRepository: ITronTransactionRepository,
    @Inject(TRON_WALLET_REPOSITORY)
    private readonly walletRepository: ITronWalletRepository,
    @Inject(USDT_TOKEN_REPOSITORY)
    private readonly usdtTokenRepository: IUSDTTokenRepository,
    private readonly usdtTransferService: USDTTransferService,
    private readonly validationService: TronValidationService,
  ) {}

  /**
   * Create USDT transfer transaction
   */
  async createUSDTTransfer(request: CreateUSDTTransferRequest): Promise<Result<TronTransaction, DefaultResultError>> {
    try {
      // Get and validate wallet
      const walletResult = await this.walletRepository.findById(request.fromWalletId);
      if (walletResult.result.type === 'ERROR') {
        return Result.Error({
          code: 'NOT_FOUND',
          payload: 'Source wallet not found'
        });
      }

      const wallet = walletResult.result.data;

      // Check wallet ownership
      if (!wallet.belongsToUser(request.userId)) {
        return Result.Error({
          code: 'FORBIDDEN',
          payload: 'You can only create transactions from your own wallets'
        });
      }

      // Validate wallet can sign
      if (!wallet.canSign()) {
        return Result.Error({
          code: 'FORBIDDEN',
          payload: 'Wallet cannot sign transactions'
        });
      }

      // Validate to address
      const toAddressResult = TronAddress.create(request.toAddress);
      if (toAddressResult.result.type === 'ERROR') {
        return Result.Error(toAddressResult.result.error);
      }

      // Validate amount
      const amountResult = TokenAmount.create(request.amount, 6); // USDT has 6 decimals
      if (amountResult.result.type === 'ERROR') {
        return Result.Error(amountResult.result.error);
      }

      // Get USDT token configuration
      const usdtTokenResult = await this.usdtTokenRepository.getDefaultForNetwork(request.networkId);
      if (usdtTokenResult.result.type === 'ERROR') {
        return Result.Error({
          code: 'NOT_FOUND',
          payload: 'USDT token not configured for this network'
        });
      }

      // Create transfer request
      const transferRequest: USDTTransferRequest = {
        fromWallet: wallet,
        toAddress: toAddressResult.result.data,
        amount: amountResult.result.data,
        usdtToken: usdtTokenResult.result.data,
        networkId: request.networkId,
        userId: request.userId,
        orderId: request.orderId,
        metadata: request.metadata
      };

      // Create transaction using domain service
      const transactionResult = this.usdtTransferService.createTransferTransaction(transferRequest);
      if (transactionResult.result.type === 'ERROR') {
        return Result.Error(transactionResult.result.error);
      }

      // Save transaction
      const savedTransaction = await this.transactionRepository.create(transactionResult.result.data);
      return savedTransaction;
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to create USDT transfer: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Get transaction by ID
   */
  async getTransactionById(transactionId: string, userId?: string): Promise<Result<TronTransaction, DefaultResultError>> {
    try {
      const transactionResult = await this.transactionRepository.findById(transactionId);
      if (transactionResult.result.type === 'ERROR') {
        return Result.Error(transactionResult.result.error);
      }

      const transaction = transactionResult.result.data;

      // Check ownership if userId provided
      if (userId && !transaction.belongsToUser(userId)) {
        return Result.Error({
          code: 'FORBIDDEN',
          payload: 'You can only access your own transactions'
        });
      }

      return Result.Success(transaction);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to get transaction: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Get transaction by hash
   */
  async getTransactionByHash(hash: string): Promise<Result<TronTransaction, DefaultResultError>> {
    return await this.transactionRepository.findByHash(hash);
  }

  /**
   * Search transactions with filters
   */
  async searchTransactions(filters: TransactionSearchFilters): Promise<Result<TronTransaction[], DefaultResultError>> {
    return await this.transactionRepository.findMany({
      userId: filters.userId,
      orderId: filters.orderId,
      status: filters.status,
      transactionType: filters.transactionType,
      fromAddress: filters.fromAddress,
      toAddress: filters.toAddress,
      networkId: filters.networkId,
      createdAfter: filters.createdAfter,
      createdBefore: filters.createdBefore,
      limit: filters.limit,
      offset: filters.offset
    });
  }

  /**
   * Get user's transactions
   */
  async getUserTransactions(
    userId: string, 
    filters?: Partial<TransactionSearchFilters>
  ): Promise<Result<TronTransaction[], DefaultResultError>> {
    return await this.transactionRepository.findByUserId(userId, filters);
  }

  /**
   * Get transactions by order ID
   */
  async getTransactionsByOrderId(orderId: string, userId?: string): Promise<Result<TronTransaction[], DefaultResultError>> {
    try {
      const transactionsResult = await this.transactionRepository.findByOrderId(orderId);
      if (transactionsResult.result.type === 'ERROR') {
        return Result.Error(transactionsResult.result.error);
      }

      const transactions = transactionsResult.result.data;

      // Filter by user if specified
      if (userId) {
        const userTransactions = transactions.filter(tx => tx.belongsToUser(userId));
        return Result.Success(userTransactions);
      }

      return Result.Success(transactions);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to get transactions by order: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Update transaction hash (after broadcast)
   */
  async updateTransactionHash(
    transactionId: string, 
    hash: string, 
    userId?: string
  ): Promise<Result<TronTransaction, DefaultResultError>> {
    try {
      // Validate hash format
      const hashResult = TransactionHash.create(hash);
      if (hashResult.result.type === 'ERROR') {
        return Result.Error(hashResult.result.error);
      }

      // Get transaction
      const transactionResult = await this.transactionRepository.findById(transactionId);
      if (transactionResult.result.type === 'ERROR') {
        return Result.Error(transactionResult.result.error);
      }

      const transaction = transactionResult.result.data;

      // Check ownership
      if (userId && !transaction.belongsToUser(userId)) {
        return Result.Error({
          code: 'FORBIDDEN',
          payload: 'You can only update your own transactions'
        });
      }

      // Update hash
      return await this.transactionRepository.updateHash(transactionId, hash);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to update transaction hash: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Confirm transaction (after block confirmation)
   */
  async confirmTransaction(
    transactionId: string,
    blockNumber: number,
    blockHash: string,
    gasUsed?: number
  ): Promise<Result<TronTransaction, DefaultResultError>> {
    try {
      const transactionResult = await this.transactionRepository.findById(transactionId);
      if (transactionResult.result.type === 'ERROR') {
        return Result.Error(transactionResult.result.error);
      }

      const transaction = transactionResult.result.data;

      // Only confirm pending transactions
      if (!transaction.isPending()) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Transaction is not in pending status'
        });
      }

      // Update status to confirmed
      return await this.transactionRepository.updateStatus(
        transactionId, 
        TransactionStatus.CONFIRMED, 
        blockNumber, 
        blockHash
      );
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to confirm transaction: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Mark transaction as failed
   */
  async failTransaction(transactionId: string, errorMessage: string): Promise<Result<TronTransaction, DefaultResultError>> {
    try {
      const transactionResult = await this.transactionRepository.findById(transactionId);
      if (transactionResult.result.type === 'ERROR') {
        return Result.Error(transactionResult.result.error);
      }

      const transaction = transactionResult.result.data;
      const failedTransaction = transaction.fail(errorMessage);
      
      return await this.transactionRepository.update(transactionId, failedTransaction);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to mark transaction as failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Get pending transactions for monitoring
   */
  async getPendingTransactions(networkId?: string): Promise<Result<TronTransaction[], DefaultResultError>> {
    return await this.transactionRepository.findPendingTransactions(networkId);
  }

  /**
   * Get user transaction statistics
   */
  async getUserStatistics(userId: string, networkId?: string): Promise<Result<TransactionStatistics, DefaultResultError>> {
    return await this.transactionRepository.getUserStatistics(userId, networkId);
  }

  /**
   * Get transaction statistics for period
   */
  async getPeriodStatistics(
    startDate: Date, 
    endDate: Date, 
    networkId?: string
  ): Promise<Result<TransactionStatistics, DefaultResultError>> {
    return await this.transactionRepository.getPeriodStatistics(startDate, endDate, networkId);
  }

  /**
   * Get recent transactions for monitoring
   */
  async getRecentTransactions(limit: number = 50, networkId?: string): Promise<Result<TronTransaction[], DefaultResultError>> {
    return await this.transactionRepository.findRecentTransactions(limit, networkId);
  }

  /**
   * Get transactions requiring confirmation updates
   */
  async getTransactionsForConfirmationUpdate(networkId: string): Promise<Result<TronTransaction[], DefaultResultError>> {
    return await this.transactionRepository.findTransactionsForConfirmationUpdate(networkId);
  }

  /**
   * Estimate transaction risk
   */
  async estimateTransactionRisk(
    fromAddress: string,
    toAddress: string,
    amount: string
  ): Promise<Result<'low' | 'medium' | 'high', DefaultResultError>> {
    try {
      const amountResult = TokenAmount.create(amount, 6);
      if (amountResult.result.type === 'ERROR') {
        return Result.Error(amountResult.result.error);
      }

      const risk = this.validationService.estimateTransactionRisk(
        amountResult.result.data,
        fromAddress,
        toAddress
      );

      return Result.Success(risk);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to estimate transaction risk: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  /**
   * Create transaction summary
   */
  createTransactionSummary(transaction: TronTransaction): TransactionSummary {
    return {
      transactionId: transaction.transactionId,
      hash: transaction.hash,
      amount: transaction.amount,
      status: transaction.status,
      fromAddress: transaction.fromAddress,
      toAddress: transaction.toAddress,
      createdAt: transaction.createdAt,
      confirmedAt: transaction.confirmedAt
    };
  }
}