import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import TronWeb from 'tronweb';
import { DefaultResultError, Result } from '../../../global/utils/Result';

const TronWebConstructor = TronWeb.TronWeb || TronWeb;

export interface TronNetworkInfo {
  chainId: number;
  blockHeight: number;
  isReachable: boolean;
  latency: number;
  version?: string;
}

export interface TronAccountInfo {
  address: string;
  balance: string;
  bandwidth: number;
  energy: number;
}

export interface TronTransactionInfo {
  hash: string;
  blockNumber: number;
  confirmations: number;
  gasUsed: number;
  timestamp: number;
}

@Injectable()
export class TronNetworkProvider {
  private readonly logger = new Logger(TronNetworkProvider.name);
  private tronWeb: any;

  constructor(private readonly configService: ConfigService) {
    const fullHost = this.configService.get<string>(
      'TRON_API_URL',
      'https://api.trongrid.io',
    );
    const apiKey = this.configService.get<string>('TRON_API_KEY');

    this.tronWeb = new TronWebConstructor({
      fullHost,
      headers: apiKey ? { 'TRON-PRO-API-KEY': apiKey } : {},
    });

    this.logger.log('TronWeb initialized');
  }

  async getNetworkInfo(
    rpcUrl: string,
  ): Promise<Result<TronNetworkInfo, DefaultResultError>> {
    try {
      const startTime = Date.now();
      const block = await this.tronWeb.trx.getCurrentBlock();
      const latency = Date.now() - startTime;

      return Result.Success({
        chainId: 728126428,
        blockHeight: block.block_header?.raw_data?.number || 0,
        isReachable: true,
        latency,
      });
    } catch (error: any) {
      return Result.Error({ code: 'NETWORK_ERROR', payload: error.message });
    }
  }

  async getAccountInfo(
    address: string,
  ): Promise<Result<TronAccountInfo, DefaultResultError>> {
    try {
      const account = await this.tronWeb.trx.getAccount(address);
      return Result.Success({
        address,
        balance: (account.balance || 0).toString(),
        bandwidth: 0,
        energy: 0,
      });
    } catch (error: any) {
      return Result.Error({ code: 'NETWORK_ERROR', payload: error.message });
    }
  }

  async getAddressFromPrivateKey(
    privateKey: string,
  ): Promise<Result<{ address: string }, DefaultResultError>> {
    try {
      const address = this.tronWeb.address.fromPrivateKey(privateKey);
      return Result.Success({ address });
    } catch (error: any) {
      return Result.Error({ code: 'SERIALIZATION', payload: error.message });
    }
  }

  async generateAddress(): Promise<
    Result<{ address: string; privateKey: string }, DefaultResultError>
  > {
    try {
      const account = await this.tronWeb.createAccount();
      return Result.Success({
        address: account.address.base58,
        privateKey: account.privateKey,
      });
    } catch (error: any) {
      return Result.Error({
        code: 'EXTERNAL_SERVICE_ERROR',
        payload: error.message,
      });
    }
  }

  isValidAddress(address: string): boolean {
    return this.tronWeb.isAddress(address);
  }

  getTronWeb(): any {
    return this.tronWeb;
  }
}
