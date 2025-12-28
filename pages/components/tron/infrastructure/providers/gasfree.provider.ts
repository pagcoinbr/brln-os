import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import * as crypto from 'crypto';
import { DefaultResultError, Result } from '../../../global/utils/Result';

export interface GasFreeTokenInfo {
  tokenAddress: string;
  symbol: string;
  decimal: number;
  activateFee: number;
  transferFee: number;
  supported: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface GasFreeProvider {
  address: string;
  name: string;
  icon: string;
  website: string;
  config: {
    maxPendingTransfer: number;
    minDeadlineDuration: number;
    maxDeadlineDuration: number;
    defaultDeadlineDuration: number;
  };
}

export interface GasFreeAccountInfo {
  accountAddress: string;
  gasFreeAddress: string;
  active: boolean;
  nonce: number;
  allow_submit: boolean;
  assets: Array<{
    tokenAddress: string;
    tokenSymbol: string;
    activateFee: number;
    transferFee: number;
    decimal: number;
    frozen: number;
  }>;
}

export interface GasFreeTransferPayload {
  token: string;
  serviceProvider: string;
  user: string;
  receiver: string;
  value: string;
  maxFee: string;
  deadline: number;
  version: number;
  nonce: number;
  sig: string;
}

export interface GasFreeTransferResult {
  traceId: string;
  status:
    | 'WAITING'
    | 'INPROGRESS'
    | 'CONFIRMING'
    | 'SUCCEED'
    | 'FAILED'
    | 'PENDING'
    | 'SUCCESS';
  txHash?: string;
  message?: string;
  accountAddress?: string;
  gasFreeAddress?: string;
  providerAddress?: string;
  targetAddress?: string;
  tokenAddress?: string;
  amount?: string;
  estimatedActivateFee?: number;
  estimatedTransferFee?: number;
  estimatedTotalFee?: number;
  estimatedTotalCost?: number;
  txnBlockNum?: number;
  txnBlockTimestamp?: number;
  txnState?:
    | 'INIT'
    | 'NOT_ON_CHAIN'
    | 'ON_CHAIN'
    | 'SOLIDITY'
    | 'ON_CHAIN_FAILED';
  txnActivateFee?: number;
  txnTransferFee?: number;
  txnTotalFee?: number;
  txnAmount?: string;
  txnTotalCost?: number;
  createdAt?: string;
  updatedAt?: string;
  expiredAt?: string;
}

@Injectable()
export class GasFreeProvider {
  private readonly logger = new Logger(GasFreeProvider.name);
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly apiSecret: string;
  private readonly verifyingContract: string;
  private readonly chainId: number;

  constructor(private readonly configService: ConfigService) {
    const rawBaseUrl = this.configService.get<string>(
      'GASFREE_MAINNET_ENDPOINT',
      'https://open.gasfree.io/tron/',
    );
    // Ensure baseUrl ends with / but doesn't have double slashes
    this.baseUrl = rawBaseUrl.endsWith('/') ? rawBaseUrl : rawBaseUrl + '/';
    this.apiKey = this.configService.get<string>('GASFREE_API_KEY', '');
    this.apiSecret = this.configService.get<string>('GASFREE_API_SECRET', '');
    this.verifyingContract = this.configService.get<string>(
      'GASFREE_VERIFYING_CONTRACT',
      'TFFAMLQZybALab4uxHA9RBE7pxhUAjfF3U',
    );
    this.chainId = parseInt(
      this.configService.get<string>('TRON_MAINNET_CHAIN_ID', '728126428'),
    );

    if (!this.apiKey || !this.apiSecret) {
      this.logger.warn(
        'GasFree API credentials not configured - gasless transfers will not be available',
      );
    } else {
      this.logger.log('GasFree provider initialized for mainnet');
    }
  }

  /**
   * Create API signature for authentication
   * Based on GasFree API documentation: method + path + timestamp (NO BODY)
   */
  private createSignature(
    method: string,
    path: string,
    timestamp: number,
  ): string {
    // According to GasFree docs: method + path + timestamp (body is NOT included)
    const message = `${method.toUpperCase()}${path}${timestamp}`;

    return crypto
      .createHmac('sha256', this.apiSecret)
      .update(message)
      .digest('base64');
  }

  /**
   * Get authentication headers
   */
  private getAuthHeaders(
    method: string,
    path: string,
    body?: any,
  ): Record<string, string> {
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = this.createSignature(method, path, timestamp);

    // Debug logging for authentication
    this.logger.debug('Authentication details', {
      method: method.toUpperCase(),
      path,
      timestamp,
      message: `${method.toUpperCase()}${path}${timestamp}`,
      signature: signature,
      hasBody: !!body,
    });

    return {
      'Content-Type': 'application/json',
      Timestamp: timestamp.toString(),
      Authorization: `ApiKey ${this.apiKey}:${signature}`,
    };
  }

  /**
   * Make authenticated API call
   */
  private async makeApiCall<T>(
    method: string,
    path: string,
    data?: any,
  ): Promise<Result<T, DefaultResultError>> {
    try {
      // Para assinatura, usar path completo /tron + path
      const fullPath = `/tron${path}`;
      const headers = this.getAuthHeaders(method, fullPath, data);

      // Debug logging
      this.logger.debug('GasFree API request details', {
        method: method.toUpperCase(),
        fullPath,
        url: `${this.baseUrl}${path.startsWith('/') ? path.substring(1) : path}`,
        headers: {
          ...headers,
          Authorization: headers.Authorization
            ? `${headers.Authorization.substring(0, 20)}...`
            : undefined,
        },
        bodyExists: !!data,
        bodySize: data ? JSON.stringify(data).length : 0,
      });

      // Remove leading slash from path to avoid double slash
      const cleanPath = path.startsWith('/') ? path.substring(1) : path;
      const response = await axios({
        method: method as any,
        url: `${this.baseUrl}${cleanPath}`,
        headers,
        data,
      });

      if (response.data.code !== 0 && response.data.code !== 200) {
        throw new Error(response.data.message || 'API request failed');
      }

      return Result.Success(response.data.data);
    } catch (error: any) {
      this.logger.error(
        `GasFree API call failed: ${error.message}`,
        error.response?.data,
      );
      return Result.Error({
        code: 'EXTERNAL_SERVICE_ERROR',
        payload: `GasFree API error: ${error.response?.data?.message || error.message}`,
      });
    }
  }

  /**
   * Get supported tokens
   */
  async getTokens(): Promise<
    Result<{ tokens: GasFreeTokenInfo[] }, DefaultResultError>
  > {
    return this.makeApiCall<{ tokens: GasFreeTokenInfo[] }>(
      'GET',
      '/api/v1/config/token/all',
    );
  }

  /**
   * Get available service providers
   */
  async getProviders(): Promise<
    Result<{ providers: GasFreeProvider[] }, DefaultResultError>
  > {
    return this.makeApiCall<{ providers: GasFreeProvider[] }>(
      'GET',
      '/api/v1/config/provider/all',
    );
  }

  /**
   * Get account information including nonce
   */
  async getAccountInfo(
    address: string,
  ): Promise<Result<GasFreeAccountInfo, DefaultResultError>> {
    return this.makeApiCall<GasFreeAccountInfo>(
      'GET',
      `/api/v1/address/${address}`,
    );
  }

  /**
   * Submit gasless USDT transfer
   */
  async submitGasFreeTransfer(
    payload: GasFreeTransferPayload,
  ): Promise<Result<GasFreeTransferResult, DefaultResultError>> {
    try {
      this.logger.log('Submitting GasFree transfer', {
        user: payload.user,
        receiver: payload.receiver,
        value: payload.value,
        maxFee: payload.maxFee,
        nonce: payload.nonce,
      });

      const result = await this.makeApiCall<any>(
        'POST',
        '/api/v1/gasfree/submit',
        payload,
      );

      if (result.result.type === 'ERROR') {
        return Result.Error(result.result.error);
      }

      const data = result.result.data;

      // Map response to standardized format
      const transferResult: GasFreeTransferResult = {
        traceId: data.id || data.traceId || data.trace_id || '',
        status: this.normalizeStatus(data.state || data.status),
        txHash: data.txnHash || data.txHash || data.tx_hash,
        message: data.message,
        accountAddress: data.accountAddress,
        gasFreeAddress: data.gasFreeAddress,
        providerAddress: data.providerAddress,
        targetAddress: data.targetAddress,
        tokenAddress: data.tokenAddress,
        amount: data.amount,
        estimatedActivateFee: data.estimatedActivateFee,
        estimatedTransferFee: data.estimatedTransferFee,
        estimatedTotalFee: data.estimatedTotalFee,
        estimatedTotalCost: data.estimatedTotalCost,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
        expiredAt: data.expiredAt,
      };

      this.logger.log('GasFree transfer submitted successfully', {
        traceId: transferResult.traceId,
        status: transferResult.status,
      });

      return Result.Success(transferResult);
    } catch (error: any) {
      this.logger.error(
        `Failed to submit GasFree transfer: ${error.message}`,
        error,
      );
      return Result.Error({
        code: 'EXTERNAL_SERVICE_ERROR',
        payload: `Failed to submit GasFree transfer: ${error.message}`,
      });
    }
  }

  /**
   * Get transfer status by trace ID
   */
  async getTransferStatus(
    traceId: string,
  ): Promise<Result<GasFreeTransferResult, DefaultResultError>> {
    try {
      const result = await this.makeApiCall<any>(
        'GET',
        `/api/v1/gasfree/${traceId}`,
      );

      if (result.result.type === 'ERROR') {
        return Result.Error(result.result.error);
      }

      const data = result.result.data;

      const transferResult: GasFreeTransferResult = {
        traceId: data.id || traceId,
        status: this.normalizeStatus(data.state || data.status),
        txHash: data.txnHash || data.txHash || data.tx_hash,
        message: data.message,
        accountAddress: data.accountAddress,
        gasFreeAddress: data.gasFreeAddress,
        providerAddress: data.providerAddress,
        targetAddress: data.targetAddress,
        tokenAddress: data.tokenAddress,
        amount: data.amount,
        estimatedActivateFee: data.estimatedActivateFee,
        estimatedTransferFee: data.estimatedTransferFee,
        estimatedTotalFee: data.estimatedTotalFee,
        estimatedTotalCost: data.estimatedTotalCost,
        txnBlockNum: data.txnBlockNum,
        txnBlockTimestamp: data.txnBlockTimestamp,
        txnState: data.txnState,
        txnActivateFee: data.txnActivateFee,
        txnTransferFee: data.txnTransferFee,
        txnTotalFee: data.txnTotalFee,
        txnAmount: data.txnAmount,
        txnTotalCost: data.txnTotalCost,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
        expiredAt: data.expiredAt,
      };

      return Result.Success(transferResult);
    } catch (error: any) {
      this.logger.error(
        `Failed to get transfer status for ${traceId}: ${error.message}`,
      );
      return Result.Error({
        code: 'EXTERNAL_SERVICE_ERROR',
        payload: `Failed to get transfer status: ${error.message}`,
      });
    }
  }

  /**
   * Normalize status from API response
   */
  private normalizeStatus(status: string): GasFreeTransferResult['status'] {
    const statusMap: Record<string, GasFreeTransferResult['status']> = {
      WAITING: 'WAITING',
      INPROGRESS: 'INPROGRESS',
      CONFIRMING: 'CONFIRMING',
      SUCCEED: 'SUCCEED',
      SUCCESS: 'SUCCESS',
      FAILED: 'FAILED',
      PENDING: 'PENDING',
    };

    return statusMap[status] || 'PENDING';
  }

  /**
   * Get GasFree domain for EIP-712 signing
   */
  getGasFreeDomain() {
    return {
      name: 'GasFreeController',
      version: 'V1.0.0',
      chainId: this.chainId,
      verifyingContract: this.verifyingContract,
    };
  }

  /**
   * Get GasFree types for EIP-712 signing
   */
  getGasFreeTypes() {
    return {
      PermitTransfer: [
        { name: 'token', type: 'address' },
        { name: 'serviceProvider', type: 'address' },
        { name: 'user', type: 'address' },
        { name: 'receiver', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'maxFee', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
        { name: 'version', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
      ],
    };
  }

  /**
   * Check if GasFree is available
   */
  isAvailable(): boolean {
    return !!(this.apiKey && this.apiSecret);
  }
}
