import { Inject, Injectable } from '@nestjs/common';
import { DefaultResultError, Result } from '../../../global/utils/Result';
import {
  TronWallet,
  TronWalletCreationRequest,
} from '../../domain/entities/tron-wallet.entity';
import { ITronNetworkRepository } from '../../domain/repositories/itron-network.repository';
import { ITronWalletRepository } from '../../domain/repositories/itron-wallet.repository';
import { TronValidationService } from '../../domain/services/tron-validation.service';
import { TronNetworkProvider } from '../../infrastructure/providers/tron-network.provider';
import {
  TRON_NETWORK_REPOSITORY,
  TRON_WALLET_REPOSITORY,
} from '../../tron.tokens';

export interface CreateWalletRequest {
  address: string;
  privateKey?: string;
  publicKey?: string;
  networkId: string;
  label?: string;
  isWatchOnly?: boolean;
  userId?: string;
}

export interface ImportWalletRequest {
  privateKey: string;
  networkId: string;
  label?: string;
  userId: string;
}

export interface WalletBalanceInfo {
  trxBalance: string;
  usdtBalance: string;
  totalUSDValue: string;
}

@Injectable()
export class TronWalletApplicationService {
  constructor(
    @Inject(TRON_WALLET_REPOSITORY)
    private readonly walletRepository: ITronWalletRepository,
    @Inject(TRON_NETWORK_REPOSITORY)
    private readonly networkRepository: ITronNetworkRepository,
    private readonly validationService: TronValidationService,
    private readonly tronNetworkProvider: TronNetworkProvider,
  ) {}

  /**
   * Create a new TRON wallet
   */
  async createWallet(
    request: CreateWalletRequest,
  ): Promise<Result<TronWallet, DefaultResultError>> {
    try {
      // Validate network exists
      const networkResult = await this.networkRepository.findById(
        request.networkId,
      );
      if (networkResult.result.type === 'ERROR') {
        return Result.Error({
          code: 'NOT_FOUND',
          payload: `Network not found: ${request.networkId}`,
        });
      }

      // Validate address
      const addressValidation = this.validationService.validateAddress(
        request.address,
      );
      if (addressValidation.result.type === 'ERROR') {
        return Result.Error(addressValidation.result.error);
      }

      if (!addressValidation.result.data.isValid) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: `Invalid address: ${addressValidation.result.data.error}`,
        });
      }

      // Check if wallet already exists
      const existingWallet = await this.walletRepository.findByAddress(
        request.address,
      );
      if (existingWallet.result.type === 'SUCCESS') {
        return Result.Error({
          code: 'ALREADY_EXIST',
          payload: 'Wallet with this address already exists',
        });
      }

      // Validate private key if provided
      if (request.privateKey) {
        const privateKeyValidation = this.validationService.validatePrivateKey(
          request.privateKey,
        );
        if (privateKeyValidation.result.type === 'ERROR') {
          return Result.Error(privateKeyValidation.result.error);
        }
      }

      // Validate network compatibility
      const network = networkResult.result.data;
      const networkCompatibility =
        this.validationService.validateNetworkCompatibility(
          request.address,
          network.isTestnet,
        );
      if (networkCompatibility.result.type === 'ERROR') {
        return Result.Error(networkCompatibility.result.error);
      }

      // Create wallet entity
      const walletCreationRequest: TronWalletCreationRequest = {
        address: request.address,
        privateKey: request.privateKey,
        publicKey: request.publicKey,
        networkId: request.networkId,
        label: request.label,
        isWatchOnly: request.isWatchOnly,
        userId: request.userId,
      };

      const walletResult = TronWallet.create(walletCreationRequest);
      if (walletResult.result.type === 'ERROR') {
        return Result.Error(walletResult.result.error);
      }

      // Save to repository
      const savedWallet = await this.walletRepository.create(
        walletResult.result.data,
      );
      return savedWallet;
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to create wallet: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    }
  }

  /**
   * Import wallet from private key
   */
  async importWallet(
    request: ImportWalletRequest,
  ): Promise<Result<TronWallet, DefaultResultError>> {
    try {
      // Validate private key
      const privateKeyValidation = this.validationService.validatePrivateKey(
        request.privateKey,
      );
      if (privateKeyValidation.result.type === 'ERROR') {
        return Result.Error(privateKeyValidation.result.error);
      }

      // Derive address from private key using TRON provider
      const addressResult =
        await this.tronNetworkProvider.getAddressFromPrivateKey(
          request.privateKey,
        );
      if (addressResult.result.type === 'ERROR') {
        return Result.Error(addressResult.result.error);
      }

      const address = addressResult.result.data.address;

      // Validate network exists
      const networkResult = await this.networkRepository.findById(
        request.networkId,
      );
      if (networkResult.result.type === 'ERROR') {
        return Result.Error({
          code: 'NOT_FOUND',
          payload: `Network not found: ${request.networkId}`,
        });
      }

      // Check if wallet already exists
      const existingWallet = await this.walletRepository.findByAddress(address);
      if (existingWallet.result.type === 'SUCCESS') {
        return Result.Error({
          code: 'ALREADY_EXIST',
          payload: 'Wallet with this address already exists',
        });
      }

      // Validate network compatibility
      const network = networkResult.result.data;
      const networkCompatibility =
        this.validationService.validateNetworkCompatibility(
          address,
          network.isTestnet,
        );
      if (networkCompatibility.result.type === 'ERROR') {
        return Result.Error(networkCompatibility.result.error);
      }

      // Create wallet
      return this.createWallet({
        address,
        privateKey: request.privateKey,
        networkId: request.networkId,
        label:
          request.label ||
          `Imported Wallet ${address.slice(0, 6)}...${address.slice(-4)}`,
        userId: request.userId,
        isWatchOnly: false,
      });
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to import wallet: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    }
  }

  /**
   * Get wallet by ID
   */
  async getWalletById(
    walletId: string,
  ): Promise<Result<TronWallet, DefaultResultError>> {
    return await this.walletRepository.findById(walletId);
  }

  /**
   * Get wallet by address
   */
  async getWalletByAddress(
    address: string,
  ): Promise<Result<TronWallet, DefaultResultError>> {
    return await this.walletRepository.findByAddress(address);
  }

  /**
   * Get user's wallets
   */
  async getUserWallets(
    userId: string,
    networkId?: string,
  ): Promise<Result<TronWallet[], DefaultResultError>> {
    if (networkId) {
      return await this.walletRepository.findMany({
        userId,
        networkId,
        isActive: true,
      });
    }
    return await this.walletRepository.findByUserId(userId);
  }

  /**
   * Get user's default wallet for network
   */
  async getUserDefaultWallet(
    userId: string,
    networkId: string,
  ): Promise<Result<TronWallet, DefaultResultError>> {
    return await this.walletRepository.getUserDefaultWallet(userId, networkId);
  }

  /**
   * Update wallet label
   */
  async updateWalletLabel(
    walletId: string,
    newLabel: string,
    userId?: string,
  ): Promise<Result<TronWallet, DefaultResultError>> {
    try {
      // Get existing wallet
      const walletResult = await this.walletRepository.findById(walletId);
      if (walletResult.result.type === 'ERROR') {
        return Result.Error(walletResult.result.error);
      }

      const wallet = walletResult.result.data;

      // Check ownership if userId provided
      if (userId && !wallet.belongsToUser(userId)) {
        return Result.Error({
          code: 'FORBIDDEN',
          payload: 'You can only update your own wallets',
        });
      }

      // Update label
      const updatedWalletResult = wallet.updateLabel(newLabel);
      if (updatedWalletResult.result.type === 'ERROR') {
        return Result.Error(updatedWalletResult.result.error);
      }

      // Save updated wallet
      return await this.walletRepository.update(
        walletId,
        updatedWalletResult.result.data,
      );
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to update wallet label: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    }
  }

  /**
   * Deactivate wallet
   */
  async deactivateWallet(
    walletId: string,
    userId?: string,
  ): Promise<Result<boolean, DefaultResultError>> {
    try {
      // Get existing wallet
      const walletResult = await this.walletRepository.findById(walletId);
      if (walletResult.result.type === 'ERROR') {
        return Result.Error(walletResult.result.error);
      }

      const wallet = walletResult.result.data;

      // Check ownership if userId provided
      if (userId && !wallet.belongsToUser(userId)) {
        return Result.Error({
          code: 'FORBIDDEN',
          payload: 'You can only deactivate your own wallets',
        });
      }

      // Deactivate wallet
      const deactivatedWallet = wallet.deactivate();
      const updateResult = await this.walletRepository.update(
        walletId,
        deactivatedWallet,
      );

      if (updateResult.result.type === 'ERROR') {
        return Result.Error(updateResult.result.error);
      }

      return Result.Success(true);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to deactivate wallet: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    }
  }

  /**
   * Get wallets that can sign transactions
   */
  async getSigningWallets(
    userId: string,
    networkId?: string,
  ): Promise<Result<TronWallet[], DefaultResultError>> {
    return await this.walletRepository.findSigningWallets(userId, networkId);
  }

  /**
   * Validate wallet for transaction
   */
  async validateWalletForTransaction(
    walletId: string,
    userId?: string,
  ): Promise<Result<TronWallet, DefaultResultError>> {
    try {
      const walletResult = await this.walletRepository.findById(walletId);
      if (walletResult.result.type === 'ERROR') {
        return Result.Error(walletResult.result.error);
      }

      const wallet = walletResult.result.data;

      // Check ownership
      if (userId && !wallet.belongsToUser(userId)) {
        return Result.Error({
          code: 'FORBIDDEN',
          payload: 'You can only use your own wallets for transactions',
        });
      }

      // Check if wallet is active
      if (!wallet.isActive) {
        return Result.Error({
          code: 'FORBIDDEN',
          payload: 'Wallet is not active',
        });
      }

      // Check if wallet can sign
      if (!wallet.canSign()) {
        return Result.Error({
          code: 'FORBIDDEN',
          payload:
            'Wallet cannot sign transactions (watch-only or missing private key)',
        });
      }

      return Result.Success(wallet);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to validate wallet: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    }
  }

  /**
   * Count user's wallets
   */
  async countUserWallets(
    userId: string,
  ): Promise<Result<number, DefaultResultError>> {
    return await this.walletRepository.countByUser(userId);
  }

  /**
   * Check if address is available for new wallet
   */
  async isAddressAvailable(
    address: string,
  ): Promise<Result<boolean, DefaultResultError>> {
    const existsResult = await this.walletRepository.existsByAddress(address);
    if (existsResult.result.type === 'ERROR') {
      return Result.Error(existsResult.result.error);
    }

    return Result.Success(!existsResult.result.data);
  }
}
