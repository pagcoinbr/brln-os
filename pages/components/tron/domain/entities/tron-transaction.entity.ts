import { Result, DefaultResultError } from '../../../global/utils/Result';

export enum TransactionStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  FAILED = 'FAILED',
  CANCELLED = 'CANCELLED'
}

export enum TransactionType {
  TRANSFER = 'TRANSFER',
  CONTRACT_EXECUTION = 'CONTRACT_EXECUTION',
  USDT_TRANSFER = 'USDT_TRANSFER',
  TRX_TRANSFER = 'TRX_TRANSFER'
}

export interface TronTransactionCreationRequest {
  readonly fromAddress: string;
  readonly toAddress: string;
  readonly amount: string;
  readonly tokenAddress?: string;
  readonly transactionType: TransactionType;
  readonly networkId: string;
  readonly gasLimit?: number;
  readonly gasPrice?: string;
  readonly userId?: string;
  readonly orderId?: string;
  readonly metadata?: Record<string, any>;
}

export class TronTransaction {
  public readonly transactionId: string;
  public readonly hash: string | null;
  public readonly fromAddress: string;
  public readonly toAddress: string;
  public readonly amount: string;
  public readonly tokenAddress: string | null;
  public readonly transactionType: TransactionType;
  public readonly networkId: string;
  public readonly gasLimit: number;
  public readonly gasPrice: string;
  public readonly gasUsed: number | null;
  public readonly status: TransactionStatus;
  public readonly blockNumber: number | null;
  public readonly blockHash: string | null;
  public readonly confirmations: number;
  public readonly userId: string | null;
  public readonly orderId: string | null;
  public readonly metadata: Record<string, any>;
  public readonly rawTransaction: string | null;
  public readonly errorMessage: string | null;
  public readonly createdAt: Date;
  public readonly updatedAt: Date;
  public readonly confirmedAt: Date | null;

  private constructor(req: {
    transactionId: string;
    hash: string | null;
    fromAddress: string;
    toAddress: string;
    amount: string;
    tokenAddress: string | null;
    transactionType: TransactionType;
    networkId: string;
    gasLimit: number;
    gasPrice: string;
    gasUsed: number | null;
    status: TransactionStatus;
    blockNumber: number | null;
    blockHash: string | null;
    confirmations: number;
    userId: string | null;
    orderId: string | null;
    metadata: Record<string, any>;
    rawTransaction: string | null;
    errorMessage: string | null;
    createdAt: Date;
    updatedAt: Date;
    confirmedAt: Date | null;
  }) {
    this.transactionId = req.transactionId;
    this.hash = req.hash;
    this.fromAddress = req.fromAddress;
    this.toAddress = req.toAddress;
    this.amount = req.amount;
    this.tokenAddress = req.tokenAddress;
    this.transactionType = req.transactionType;
    this.networkId = req.networkId;
    this.gasLimit = req.gasLimit;
    this.gasPrice = req.gasPrice;
    this.gasUsed = req.gasUsed;
    this.status = req.status;
    this.blockNumber = req.blockNumber;
    this.blockHash = req.blockHash;
    this.confirmations = req.confirmations;
    this.userId = req.userId;
    this.orderId = req.orderId;
    this.metadata = req.metadata;
    this.rawTransaction = req.rawTransaction;
    this.errorMessage = req.errorMessage;
    this.createdAt = req.createdAt;
    this.updatedAt = req.updatedAt;
    this.confirmedAt = req.confirmedAt;
  }

  public static create(req: TronTransactionCreationRequest): Result<TronTransaction, DefaultResultError> {
    try {
      // Validation
      if (!req.fromAddress || !this.isValidTronAddress(req.fromAddress)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid from address format'
        });
      }

      if (!req.toAddress || !this.isValidTronAddress(req.toAddress)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid to address format'
        });
      }

      if (!req.amount || !this.isValidAmount(req.amount)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid amount format'
        });
      }

      if (!req.networkId || req.networkId.length < 3) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Network ID is required'
        });
      }

      // Validate token address for token transfers
      if (req.tokenAddress && !this.isValidTronAddress(req.tokenAddress)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid token contract address format'
        });
      }

      const now = new Date();
      const transactionId = this.generateTransactionId();

      const transaction = new TronTransaction({
        transactionId,
        hash: null,
        fromAddress: req.fromAddress,
        toAddress: req.toAddress,
        amount: req.amount,
        tokenAddress: req.tokenAddress || null,
        transactionType: req.transactionType,
        networkId: req.networkId,
        gasLimit: req.gasLimit || 100000,
        gasPrice: req.gasPrice || '0',
        gasUsed: null,
        status: TransactionStatus.PENDING,
        blockNumber: null,
        blockHash: null,
        confirmations: 0,
        userId: req.userId || null,
        orderId: req.orderId || null,
        metadata: req.metadata || {},
        rawTransaction: null,
        errorMessage: null,
        createdAt: now,
        updatedAt: now,
        confirmedAt: null
      });

      return Result.Success(transaction);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to create TronTransaction: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public static reconstruct(req: {
    transactionId: string;
    hash: string | null;
    fromAddress: string;
    toAddress: string;
    amount: string;
    tokenAddress: string | null;
    transactionType: TransactionType;
    networkId: string;
    gasLimit: number;
    gasPrice: string;
    gasUsed: number | null;
    status: TransactionStatus;
    blockNumber: number | null;
    blockHash: string | null;
    confirmations: number;
    userId: string | null;
    orderId: string | null;
    metadata: Record<string, any>;
    rawTransaction: string | null;
    errorMessage: string | null;
    createdAt: Date;
    updatedAt: Date;
    confirmedAt: Date | null;
  }): TronTransaction {
    return new TronTransaction(req);
  }

  public updateHash(hash: string): TronTransaction {
    return new TronTransaction({
      ...this,
      hash,
      updatedAt: new Date()
    });
  }

  public updateRawTransaction(rawTransaction: string): TronTransaction {
    return new TronTransaction({
      ...this,
      rawTransaction,
      updatedAt: new Date()
    });
  }

  public confirm(blockNumber: number, blockHash: string, gasUsed: number): TronTransaction {
    return new TronTransaction({
      ...this,
      status: TransactionStatus.CONFIRMED,
      blockNumber,
      blockHash,
      gasUsed,
      confirmations: 1,
      confirmedAt: new Date(),
      updatedAt: new Date()
    });
  }

  public fail(errorMessage: string): TronTransaction {
    return new TronTransaction({
      ...this,
      status: TransactionStatus.FAILED,
      errorMessage,
      updatedAt: new Date()
    });
  }

  public cancel(reason: string): TronTransaction {
    return new TronTransaction({
      ...this,
      status: TransactionStatus.CANCELLED,
      errorMessage: reason,
      updatedAt: new Date()
    });
  }

  public addConfirmation(): TronTransaction {
    return new TronTransaction({
      ...this,
      confirmations: this.confirmations + 1,
      updatedAt: new Date()
    });
  }

  public updateMetadata(newMetadata: Record<string, any>): TronTransaction {
    return new TronTransaction({
      ...this,
      metadata: { ...this.metadata, ...newMetadata },
      updatedAt: new Date()
    });
  }

  public isPending(): boolean {
    return this.status === TransactionStatus.PENDING;
  }

  public isConfirmed(): boolean {
    return this.status === TransactionStatus.CONFIRMED;
  }

  public isFailed(): boolean {
    return this.status === TransactionStatus.FAILED;
  }

  public isCancelled(): boolean {
    return this.status === TransactionStatus.CANCELLED;
  }

  public isTokenTransfer(): boolean {
    return this.tokenAddress !== null;
  }

  public isUSDTTransfer(): boolean {
    return this.transactionType === TransactionType.USDT_TRANSFER;
  }

  public belongsToUser(userId: string): boolean {
    return this.userId === userId;
  }

  public belongsToOrder(orderId: string): boolean {
    return this.orderId === orderId;
  }

  public getAmountInSun(): bigint {
    // Convert amount to SUN (1 TRX = 1,000,000 SUN)
    return BigInt(Math.floor(parseFloat(this.amount) * 1_000_000));
  }

  private static isValidTronAddress(address: string): boolean {
    const tronAddressRegex = /^T[A-Za-z0-9]{33}$/;
    return tronAddressRegex.test(address);
  }

  private static isValidAmount(amount: string): boolean {
    try {
      const num = parseFloat(amount);
      return num > 0 && isFinite(num);
    } catch {
      return false;
    }
  }

  private static generateTransactionId(): string {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substr(2, 9);
    return `tron_tx_${timestamp}_${random}`;
  }
}