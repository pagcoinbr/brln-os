import { DefaultResultError, Result } from '../../../global/utils/Result';

export interface TronNetworkConfig {
  readonly networkId: string;
  readonly name: string;
  readonly rpcUrl: string;
  readonly explorerUrl: string;
  readonly chainId: number;
  readonly isTestnet: boolean;
  readonly gasLimit: number;
  readonly confirmationsRequired: number;
}

export class TronNetwork {
  public readonly networkId: string;
  public readonly name: string;
  public readonly rpcUrl: string;
  public readonly explorerUrl: string;
  public readonly chainId: number;
  public readonly isTestnet: boolean;
  public readonly gasLimit: number;
  public readonly confirmationsRequired: number;
  public readonly isActive: boolean;
  public readonly createdAt: Date;
  public readonly updatedAt: Date;

  private constructor(req: {
    networkId: string;
    name: string;
    rpcUrl: string;
    explorerUrl: string;
    chainId: number;
    isTestnet: boolean;
    gasLimit: number;
    confirmationsRequired: number;
    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
  }) {
    this.networkId = req.networkId;
    this.name = req.name;
    this.rpcUrl = req.rpcUrl;
    this.explorerUrl = req.explorerUrl;
    this.chainId = req.chainId;
    this.isTestnet = req.isTestnet;
    this.gasLimit = req.gasLimit;
    this.confirmationsRequired = req.confirmationsRequired;
    this.isActive = req.isActive;
    this.createdAt = req.createdAt;
    this.updatedAt = req.updatedAt;
  }

  public static create(req: {
    networkId: string;
    name: string;
    rpcUrl: string;
    explorerUrl: string;
    chainId: number;
    isTestnet: boolean;
    gasLimit?: number;
    confirmationsRequired?: number;
    isActive?: boolean;
  }): Result<TronNetwork, DefaultResultError> {
    try {
      // Validation
      if (!req.networkId || req.networkId.length < 3) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Network ID must be at least 3 characters',
        });
      }

      if (!req.name || req.name.length < 2) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Network name must be at least 2 characters',
        });
      }

      if (!req.rpcUrl || !this.isValidUrl(req.rpcUrl)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid RPC URL',
        });
      }

      if (!req.explorerUrl || !this.isValidUrl(req.explorerUrl)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid Explorer URL',
        });
      }

      if (req.chainId <= 0) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Chain ID must be greater than 0',
        });
      }

      // Validate gasLimit - must be greater than 0
      // Tron requires minimum gas for transactions to avoid mempool issues
      const gasLimit = req.gasLimit !== undefined ? req.gasLimit : 100000;
      if (gasLimit <= 0) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Gas limit must be greater than 0 to avoid mempool issues',
        });
      }

      // Validate confirmationsRequired - must be at least 1
      // Tron network typically requires 19 blocks for full confirmation, minimum is 1
      const confirmationsRequired =
        req.confirmationsRequired !== undefined ? req.confirmationsRequired : 1;
      if (confirmationsRequired <= 0) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload:
            'Confirmations required must be at least 1 for transaction validity',
        });
      }

      const now = new Date();
      const network = new TronNetwork({
        networkId: req.networkId,
        name: req.name,
        rpcUrl: req.rpcUrl,
        explorerUrl: req.explorerUrl,
        chainId: req.chainId,
        isTestnet: req.isTestnet,
        gasLimit: gasLimit,
        confirmationsRequired: confirmationsRequired,
        isActive: req.isActive !== undefined ? req.isActive : true,
        createdAt: now,
        updatedAt: now,
      });

      return Result.Success(network);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to create TronNetwork: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    }
  }

  public static reconstruct(req: {
    networkId: string;
    name: string;
    rpcUrl: string;
    explorerUrl: string;
    chainId: number;
    isTestnet: boolean;
    gasLimit: number;
    confirmationsRequired: number;
    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
  }): TronNetwork {
    return new TronNetwork(req);
  }

  public updateConfiguration(
    config: Partial<TronNetworkConfig>,
  ): Result<TronNetwork, DefaultResultError> {
    try {
      const updatedNetwork = new TronNetwork({
        networkId: this.networkId,
        name: config.name || this.name,
        rpcUrl: config.rpcUrl || this.rpcUrl,
        explorerUrl: config.explorerUrl || this.explorerUrl,
        chainId: config.chainId || this.chainId,
        isTestnet:
          config.isTestnet !== undefined ? config.isTestnet : this.isTestnet,
        gasLimit: config.gasLimit || this.gasLimit,
        confirmationsRequired:
          config.confirmationsRequired || this.confirmationsRequired,
        isActive: this.isActive,
        createdAt: this.createdAt,
        updatedAt: new Date(),
      });

      return Result.Success(updatedNetwork);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to update TronNetwork: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    }
  }

  public activate(): TronNetwork {
    return new TronNetwork({
      ...this,
      isActive: true,
      updatedAt: new Date(),
    });
  }

  public deactivate(): TronNetwork {
    return new TronNetwork({
      ...this,
      isActive: false,
      updatedAt: new Date(),
    });
  }

  public isMainnet(): boolean {
    return !this.isTestnet;
  }

  public getExplorerTxUrl(txHash: string): string {
    return `${this.explorerUrl}/transaction/${txHash}`;
  }

  public getExplorerAddressUrl(address: string): string {
    return `${this.explorerUrl}/address/${address}`;
  }

  private static isValidUrl(url: string): boolean {
    try {
      new URL(url);
      return true;
    } catch {
      return false;
    }
  }
}
