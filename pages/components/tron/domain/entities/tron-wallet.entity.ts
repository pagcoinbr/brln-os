import { Result, DefaultResultError } from '../../../global/utils/Result';

export interface TronWalletCreationRequest {
  readonly address: string;
  readonly privateKey?: string;
  readonly publicKey?: string;
  readonly networkId: string;
  readonly label?: string;
  readonly isWatchOnly?: boolean;
  readonly userId?: string;
}

export class TronWallet {
  public readonly walletId: string;
  public readonly address: string;
  public readonly privateKey: string | null;
  public readonly publicKey: string | null;
  public readonly networkId: string;
  public readonly label: string;
  public readonly isWatchOnly: boolean;
  public readonly userId: string | null;
  public readonly isActive: boolean;
  public readonly createdAt: Date;
  public readonly updatedAt: Date;

  private constructor(req: {
    walletId: string;
    address: string;
    privateKey: string | null;
    publicKey: string | null;
    networkId: string;
    label: string;
    isWatchOnly: boolean;
    userId: string | null;
    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
  }) {
    this.walletId = req.walletId;
    this.address = req.address;
    this.privateKey = req.privateKey;
    this.publicKey = req.publicKey;
    this.networkId = req.networkId;
    this.label = req.label;
    this.isWatchOnly = req.isWatchOnly;
    this.userId = req.userId;
    this.isActive = req.isActive;
    this.createdAt = req.createdAt;
    this.updatedAt = req.updatedAt;
  }

  public static create(req: TronWalletCreationRequest): Result<TronWallet, DefaultResultError> {
    try {
      // Validation
      if (!req.address || !this.isValidTronAddress(req.address)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid TRON address format'
        });
      }

      if (!req.networkId || req.networkId.length < 3) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Network ID is required and must be at least 3 characters'
        });
      }

      // Validate private key if provided
      if (req.privateKey && !this.isValidPrivateKey(req.privateKey)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid private key format'
        });
      }

      // Check watch-only wallet consistency
      const isWatchOnly = req.isWatchOnly || !req.privateKey;
      if (!isWatchOnly && !req.privateKey) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Private key is required for non-watch-only wallets'
        });
      }

      const now = new Date();
      const walletId = this.generateWalletId();

      const wallet = new TronWallet({
        walletId,
        address: req.address,
        privateKey: req.privateKey || null,
        publicKey: req.publicKey || null,
        networkId: req.networkId,
        label: req.label || `TRON Wallet ${req.address.slice(0, 6)}...${req.address.slice(-4)}`,
        isWatchOnly,
        userId: req.userId || null,
        isActive: true,
        createdAt: now,
        updatedAt: now
      });

      return Result.Success(wallet);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to create TronWallet: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public static reconstruct(req: {
    walletId: string;
    address: string;
    privateKey: string | null;
    publicKey: string | null;
    networkId: string;
    label: string;
    isWatchOnly: boolean;
    userId: string | null;
    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
  }): TronWallet {
    return new TronWallet(req);
  }

  public updateLabel(newLabel: string): Result<TronWallet, DefaultResultError> {
    if (!newLabel || newLabel.trim().length < 1) {
      return Result.Error({
        code: 'SERIALIZATION',
        payload: 'Label cannot be empty'
      });
    }

    const updatedWallet = new TronWallet({
      ...this,
      label: newLabel.trim(),
      updatedAt: new Date()
    });

    return Result.Success(updatedWallet);
  }

  public assignToUser(userId: string): TronWallet {
    return new TronWallet({
      ...this,
      userId,
      updatedAt: new Date()
    });
  }

  public activate(): TronWallet {
    return new TronWallet({
      ...this,
      isActive: true,
      updatedAt: new Date()
    });
  }

  public deactivate(): TronWallet {
    return new TronWallet({
      ...this,
      isActive: false,
      updatedAt: new Date()
    });
  }

  public canSign(): boolean {
    return !this.isWatchOnly && this.privateKey !== null;
  }

  public getShortAddress(): string {
    return `${this.address.slice(0, 6)}...${this.address.slice(-4)}`;
  }

  public hasPrivateKey(): boolean {
    return this.privateKey !== null && this.privateKey.length > 0;
  }

  public belongsToUser(userId: string): boolean {
    return this.userId === userId;
  }

  private static isValidTronAddress(address: string): boolean {
    // TRON addresses start with 'T' and are 34 characters long (Base58Check encoded)
    const tronAddressRegex = /^T[A-Za-z0-9]{33}$/;
    return tronAddressRegex.test(address);
  }

  private static isValidPrivateKey(privateKey: string): boolean {
    // TRON private keys are 64 character hex strings
    const privateKeyRegex = /^[a-fA-F0-9]{64}$/;
    return privateKeyRegex.test(privateKey);
  }

  private static generateWalletId(): string {
    // Generate a unique wallet ID (could be UUID, but using timestamp + random for simplicity)
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substr(2, 9);
    return `tron_${timestamp}_${random}`;
  }
}