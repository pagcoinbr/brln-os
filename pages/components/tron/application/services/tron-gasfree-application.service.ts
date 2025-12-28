import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DefaultResultError, Result } from '../../../global/utils/Result';
import { TronGasFreeService } from '../../domain/services/tron-gasfree.service';
import { TokenAmount } from '../../domain/value-objects/token-amount.vo';
import { TronAddress } from '../../domain/value-objects/tron-address.vo';
import { GasFreeProvider } from '../../infrastructure/providers/gasfree.provider';

export interface SendUSDTViaGasFreeRequest {
  toAddress: string;
  amount: string;
  orderId: string;
  userId: string;
}

export interface GasFreeTransferResult {
  txHash: string;
  traceId: string;
  amount: string;
  fee: string;
  totalCost: string;
  confirmations: number;
}

/**
 * Application Service for orchestrating GasFree transfers
 * Handles the complete flow: validate -> get account info -> sign -> submit -> wait for confirmations
 */
@Injectable()
export class TronGasFreeApplicationService {
  private readonly logger = new Logger(TronGasFreeApplicationService.name);
  private readonly systemAddress: string;
  private readonly systemPrivateKey: string;
  private readonly usdtContractAddress: string;
  private readonly serviceProviderAddress: string;
  private readonly chainId: number;
  private readonly verifyingContract: string;
  private readonly maxPollingAttempts: number = 12; // 12 attempts * 15s = 3 minutes
  private readonly pollingIntervalMs: number = 15000; // 15 seconds

  constructor(
    private readonly tronGasFreeService: TronGasFreeService,
    private readonly gasFreeProvider: GasFreeProvider,
    private readonly configService: ConfigService,
  ) {
    this.systemAddress = this.configService.get<string>(
      'TRON_GASFREE_SYSTEM_ADDRESS',
      '',
    );
    this.systemPrivateKey = this.configService.get<string>(
      'TRON_GASFREE_SYSTEM_PRIVATE_KEY',
      '',
    );
    this.usdtContractAddress = this.configService.get<string>(
      'TRON_USDT_CONTRACT_ADDRESS',
      'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
    );
    this.serviceProviderAddress = this.configService.get<string>(
      'GASFREE_SERVICE_PROVIDER_ADDRESS',
      '',
    );
    this.chainId = parseInt(
      this.configService.get<string>('TRON_MAINNET_CHAIN_ID', '728126428'),
    );
    this.verifyingContract = this.configService.get<string>(
      'GASFREE_VERIFYING_CONTRACT',
      'TFFAMLQZybALab4uxHA9RBE7pxhUAjfF3U',
    );

    if (!this.systemAddress || !this.systemPrivateKey) {
      this.logger.warn(
        'GasFree system wallet not configured - gasless transfers unavailable',
      );
    } else {
      // Validate that configured address matches the private key
      this.validateAddressPrivateKeyPair();
    }

    if (!this.serviceProviderAddress) {
      this.logger.warn('GasFree service provider address not configured');
    }
  }

  /**
   * Validate that the configured system address matches the private key
   * This prevents signature failures due to address mismatch
   */
  private async validateAddressPrivateKeyPair(): Promise<void> {
    try {
      const { TronWeb } = await import('tronweb');
      const tronWeb = new TronWeb({ fullHost: 'https://api.trongrid.io' });

      const derivedAddress = tronWeb.address.fromPrivateKey(
        this.systemPrivateKey,
      );

      if (derivedAddress !== this.systemAddress) {
        this.logger.error('CRITICAL: GasFree system address mismatch!', {
          configured: this.systemAddress,
          derivedFromPrivateKey: derivedAddress,
          fix: 'Update TRON_GASFREE_SYSTEM_ADDRESS to match the private key',
        });
      } else {
        this.logger.log('GasFree system address validation successful', {
          address: this.systemAddress,
        });
      }
    } catch (error) {
      this.logger.error('Failed to validate GasFree system address', error);
    }
  }

  /**
   * Send USDT via GasFree with complete orchestration
   */
  async sendUSDTViaGasFree(
    request: SendUSDTViaGasFreeRequest,
  ): Promise<Result<GasFreeTransferResult, DefaultResultError>> {
    this.logger.log(
      `🚀 Starting GasFree transfer for order ${request.orderId}`,
      {
        toAddress: request.toAddress,
        amount: request.amount,
        userId: request.userId,
      },
    );

    try {
      // 1. Validate configuration
      if (!this.gasFreeProvider.isAvailable()) {
        return Result.Error({
          code: 'EXTERNAL_SERVICE_ERROR',
          payload: 'GasFree service is not configured',
        });
      }

      // 2. Create value objects
      const toAddressVO = TronAddress.create(request.toAddress);
      if (toAddressVO.result.type === 'ERROR') {
        return Result.Error(toAddressVO.result.error);
      }

      const amountVO = TokenAmount.create(request.amount, 6);
      if (amountVO.result.type === 'ERROR') {
        return Result.Error(amountVO.result.error);
      }

      // 3. Get account info (nonce, active status)
      this.logger.log('📊 Fetching account info...');
      const accountInfoResult = await this.gasFreeProvider.getAccountInfo(
        this.systemAddress,
      );

      if (accountInfoResult.result.type === 'ERROR') {
        this.logger.error(
          'Failed to get account info',
          accountInfoResult.result.error,
        );
        return Result.Error(accountInfoResult.result.error);
      }

      const accountInfo = accountInfoResult.result.data;
      this.logger.log('✓ Account info retrieved', {
        nonce: accountInfo.nonce,
        active: accountInfo.active,
        allowSubmit: accountInfo.allow_submit,
      });

      // Primeira transferência pode ativar a conta automaticamente
      if (accountInfo.allow_submit === false) {
        return Result.Error({
          code: 'EXTERNAL_SERVICE_ERROR',
          payload: 'Account is explicitly not allowed to submit transfers',
        });
      }

      // Se allow_submit é undefined, tentamos prosseguir pois pode ser ativado automaticamente
      if (accountInfo.allow_submit === undefined) {
        this.logger.warn(
          'Account not yet activated - attempting to activate with first transfer',
        );
      }

      // 4. Get token info (fees)
      this.logger.log('💰 Fetching token fees...');
      const tokensResult = await this.gasFreeProvider.getTokens();

      if (tokensResult.result.type === 'ERROR') {
        this.logger.error('Failed to get tokens', tokensResult.result.error);
        return Result.Error(tokensResult.result.error);
      }

      const usdtToken = tokensResult.result.data.tokens.find(
        (t) =>
          t.tokenAddress.toLowerCase() ===
          this.usdtContractAddress.toLowerCase(),
      );

      if (!usdtToken) {
        return Result.Error({
          code: 'NOT_FOUND',
          payload: 'USDT token not found in GasFree supported tokens',
        });
      }

      this.logger.log('✓ Token fees retrieved', {
        activateFee: usdtToken.activateFee,
        transferFee: usdtToken.transferFee,
      });

      // 5. Calculate maxFee
      const maxFee = this.tronGasFreeService.calculateRecommendedMaxFee(
        amountVO.result.data,
        accountInfo.active,
        usdtToken.activateFee,
        usdtToken.transferFee,
      );

      this.logger.log('💵 Max fee calculated', { maxFee });

      // 6. Estimate total cost
      const costEstimate = this.tronGasFreeService.estimateTotalCost(
        amountVO.result.data,
        maxFee,
      );

      this.logger.log('📊 Cost estimate', {
        amount: costEstimate.amountInUSDT,
        fee: costEstimate.feeInUSDT,
        total: costEstimate.totalInUSDT,
      });

      // 7. Sign the transfer
      this.logger.log('✍️ Signing transfer...');
      const signedTransferResult =
        await this.tronGasFreeService.signGasFreeTransfer({
          fromAddress: this.systemAddress,
          privateKey: this.systemPrivateKey,
          toAddress: toAddressVO.result.data,
          amount: amountVO.result.data,
          usdtContractAddress: this.usdtContractAddress,
          serviceProvider: this.serviceProviderAddress,
          nonce: accountInfo.nonce,
          chainId: this.chainId,
          verifyingContract: this.verifyingContract,
          maxFee,
        });

      if (signedTransferResult.result.type === 'ERROR') {
        this.logger.error(
          'Failed to sign transfer',
          signedTransferResult.result.error,
        );
        return Result.Error(signedTransferResult.result.error);
      }

      const signedTransfer = signedTransferResult.result.data;
      this.logger.log('✓ Transfer signed', {
        nonce: signedTransfer.nonce,
        deadline: signedTransfer.deadline,
        signature: signedTransfer.sig.substring(0, 20) + '...',
      });

      // 8. Submit to GasFree
      this.logger.log('📤 Submitting to GasFree...');
      const submitResult =
        await this.gasFreeProvider.submitGasFreeTransfer(signedTransfer);

      if (submitResult.result.type === 'ERROR') {
        this.logger.error(
          'Failed to submit transfer',
          submitResult.result.error,
        );
        return Result.Error(submitResult.result.error);
      }

      const submission = submitResult.result.data;
      this.logger.log('✓ Transfer submitted', {
        traceId: submission.traceId,
        status: submission.status,
      });

      // 9. Wait for confirmations
      this.logger.log(`⏳ Waiting for confirmations (up to 3 minutes)...`);
      const finalStatusResult = await this.waitForConfirmations(
        submission.traceId,
        19,
      );

      if (finalStatusResult.result.type === 'ERROR') {
        this.logger.error(
          'Failed to confirm transfer',
          finalStatusResult.result.error,
        );
        return Result.Error(finalStatusResult.result.error);
      }

      const finalStatus = finalStatusResult.result.data;

      if (!finalStatus.txHash) {
        return Result.Error({
          code: 'EXTERNAL_SERVICE_ERROR',
          payload: 'Transfer completed but no transaction hash received',
        });
      }

      this.logger.log('✅ Transfer confirmed!', {
        txHash: finalStatus.txHash,
        traceId: finalStatus.traceId,
        status: finalStatus.status,
      });

      return Result.Success({
        txHash: finalStatus.txHash,
        traceId: finalStatus.traceId,
        amount: costEstimate.amountInUSDT,
        fee: costEstimate.feeInUSDT,
        totalCost: costEstimate.totalInUSDT,
        confirmations: 19,
      });
    } catch (error: any) {
      this.logger.error(`❌ GasFree transfer failed: ${error.message}`, error);
      return Result.Error({
        code: 'EXTERNAL_SERVICE_ERROR',
        payload: `GasFree transfer failed: ${error.message}`,
      });
    }
  }

  /**
   * Wait for transfer to be confirmed on-chain
   */
  private async waitForConfirmations(
    traceId: string,
    minConfirmations: number,
  ): Promise<
    Result<
      { txHash: string; traceId: string; status: string },
      DefaultResultError
    >
  > {
    for (let attempt = 1; attempt <= this.maxPollingAttempts; attempt++) {
      this.logger.log(
        `🔍 Polling status (attempt ${attempt}/${this.maxPollingAttempts})...`,
      );

      const statusResult =
        await this.gasFreeProvider.getTransferStatus(traceId);

      if (statusResult.result.type === 'ERROR') {
        this.logger.warn(
          `Failed to get status on attempt ${attempt}`,
          statusResult.result.error,
        );

        // Continue polling on transient errors
        if (attempt < this.maxPollingAttempts) {
          await this.sleep(this.pollingIntervalMs);
          continue;
        }

        return Result.Error(statusResult.result.error);
      }

      const status = statusResult.result.data;

      this.logger.log(`📊 Status: ${status.status}`, {
        txHash: status.txHash,
        txnState: status.txnState,
        blockNum: status.txnBlockNum,
      });

      // Check for terminal states
      if (status.status === 'SUCCEED' || status.status === 'SUCCESS') {
        if (status.txHash) {
          return Result.Success({
            txHash: status.txHash,
            traceId,
            status: status.status,
          });
        }
      }

      if (status.status === 'FAILED') {
        return Result.Error({
          code: 'EXTERNAL_SERVICE_ERROR',
          payload: status.message || 'Transfer failed on GasFree network',
        });
      }

      // Continue polling for non-terminal states
      if (attempt < this.maxPollingAttempts) {
        await this.sleep(this.pollingIntervalMs);
      }
    }

    // Timeout reached
    return Result.Error({
      code: 'NETWORK_ERROR',
      payload: `Transfer not confirmed after ${(this.maxPollingAttempts * this.pollingIntervalMs) / 1000} seconds`,
    });
  }

  /**
   * Sleep utility
   */
  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Check if service is available
   */
  isAvailable(): boolean {
    return (
      !!this.systemAddress &&
      !!this.systemPrivateKey &&
      !!this.serviceProviderAddress &&
      this.gasFreeProvider.isAvailable()
    );
  }
}
