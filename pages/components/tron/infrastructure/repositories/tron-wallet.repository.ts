import { Injectable } from '@nestjs/common';
import { Result, DefaultResultError } from '../../../global/utils/Result';
import { TronWallet } from '../../domain/entities/tron-wallet.entity';
import { ITronWalletRepository, FindTronWalletFilters } from '../../domain/repositories/itron-wallet.repository';

// TODO: Add TRON tables to Prisma schema and implement proper database operations
// For now, this is a mock implementation demonstrating the repository pattern

@Injectable()
export class TronWalletRepository implements ITronWalletRepository {
  private wallets: Map<string, TronWallet> = new Map();
  private addressIndex: Map<string, string> = new Map(); // address -> walletId

  async create(wallet: TronWallet): Promise<Result<TronWallet, DefaultResultError>> {
    try {
      // Check if wallet with this address already exists
      if (this.addressIndex.has(wallet.address)) {
        return Result.Error({
          code: 'ALREADY_EXIST',
          payload: `Wallet with address ${wallet.address} already exists`
        });
      }

      // Store the wallet
      this.wallets.set(wallet.walletId, wallet);
      this.addressIndex.set(wallet.address, wallet.walletId);
      
      return Result.Success(wallet);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to create TRON wallet: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  async findById(walletId: string): Promise<Result<TronWallet, DefaultResultError>> {
    try {
      const wallet = this.wallets.get(walletId);

      if (!wallet) {
        return Result.Error({
          code: 'NOT_FOUND',
          payload: `TRON wallet not found: ${walletId}`
        });
      }

      return Result.Success(wallet);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to find TRON wallet: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  async findByAddress(address: string): Promise<Result<TronWallet, DefaultResultError>> {
    try {
      const walletId = this.addressIndex.get(address);
      
      if (!walletId) {
        return Result.Error({
          code: 'NOT_FOUND',
          payload: `TRON wallet not found for address: ${address}`
        });
      }

      return this.findById(walletId);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to find TRON wallet by address: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  async findByUserId(userId: string): Promise<Result<TronWallet[], DefaultResultError>> {
    try {
      const userWallets = Array.from(this.wallets.values())
        .filter(wallet => wallet.userId === userId && wallet.isActive)
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

      return Result.Success(userWallets);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to find user wallets: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  async findMany(filters: FindTronWalletFilters): Promise<Result<TronWallet[], DefaultResultError>> {
    try {
      let wallets = Array.from(this.wallets.values());

      if (filters.address) {
        wallets = wallets.filter(w => w.address === filters.address);
      }
      if (filters.networkId) {
        wallets = wallets.filter(w => w.networkId === filters.networkId);
      }
      if (filters.userId) {
        wallets = wallets.filter(w => w.userId === filters.userId);
      }
      if (filters.isActive !== undefined) {
        wallets = wallets.filter(w => w.isActive === filters.isActive);
      }
      if (filters.isWatchOnly !== undefined) {
        wallets = wallets.filter(w => w.isWatchOnly === filters.isWatchOnly);
      }

      // Sort by creation date (newest first)
      wallets.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

      return Result.Success(wallets);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to find TRON wallets: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  async findActiveByNetwork(networkId: string): Promise<Result<TronWallet[], DefaultResultError>> {
    return this.findMany({ networkId, isActive: true });
  }

  async update(walletId: string, wallet: TronWallet): Promise<Result<TronWallet, DefaultResultError>> {
    try {
      if (!this.wallets.has(walletId)) {
        return Result.Error({
          code: 'NOT_FOUND',
          payload: `TRON wallet not found: ${walletId}`
        });
      }

      // Update the wallet in memory
      this.wallets.set(walletId, wallet);
      
      return Result.Success(wallet);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to update TRON wallet: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  async delete(walletId: string): Promise<Result<boolean, DefaultResultError>> {
    try {
      const wallet = this.wallets.get(walletId);
      
      if (!wallet) {
        return Result.Error({
          code: 'NOT_FOUND',
          payload: `TRON wallet not found: ${walletId}`
        });
      }

      // Soft delete by deactivating
      const deactivatedWallet = wallet.deactivate();
      this.wallets.set(walletId, deactivatedWallet);

      return Result.Success(true);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to delete TRON wallet: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  async existsByAddress(address: string): Promise<Result<boolean, DefaultResultError>> {
    try {
      const exists = this.addressIndex.has(address);
      return Result.Success(exists);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to check wallet existence: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  async getUserDefaultWallet(userId: string, networkId: string): Promise<Result<TronWallet, DefaultResultError>> {
    try {
      const userWallets = Array.from(this.wallets.values())
        .filter(w => w.userId === userId && w.networkId === networkId && w.isActive && !w.isWatchOnly)
        .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime()); // Oldest first

      if (userWallets.length === 0) {
        return Result.Error({
          code: 'NOT_FOUND',
          payload: `No default wallet found for user ${userId} on network ${networkId}`
        });
      }

      return Result.Success(userWallets[0]);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to get user default wallet: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  async countByUser(userId: string): Promise<Result<number, DefaultResultError>> {
    try {
      const count = Array.from(this.wallets.values())
        .filter(w => w.userId === userId && w.isActive).length;

      return Result.Success(count);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to count user wallets: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  async findSigningWallets(userId: string, networkId?: string): Promise<Result<TronWallet[], DefaultResultError>> {
    try {
      let wallets = Array.from(this.wallets.values())
        .filter(w => w.userId === userId && w.isActive && w.canSign());

      if (networkId) {
        wallets = wallets.filter(w => w.networkId === networkId);
      }

      // Sort by creation date (newest first)
      wallets.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

      return Result.Success(wallets);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to find signing wallets: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }
}