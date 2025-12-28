import { Result, DefaultResultError } from '../../../global/utils/Result';
import { TronTransaction, TransactionType } from '../entities/tron-transaction.entity';
import { USDTToken } from '../entities/usdt-token.entity';
import { TronWallet } from '../entities/tron-wallet.entity';
import { TronAddress } from '../value-objects/tron-address.vo';
import { TokenAmount } from '../value-objects/token-amount.vo';
import { GasFee, GasFeeType } from '../value-objects/gas-fee.vo';

export interface USDTTransferRequest {
  fromWallet: TronWallet;
  toAddress: TronAddress;
  amount: TokenAmount;
  usdtToken: USDTToken;
  networkId: string;
  userId?: string;
  orderId?: string;
  metadata?: Record<string, any>;
}

export interface TransferValidationResult {
  isValid: boolean;
  errors: string[];
  warnings: string[];
  estimatedGasFee?: GasFee;
  minimumBalance?: TokenAmount;
}

export class USDTTransferService {

  public validateTransferRequest(request: USDTTransferRequest): Result<TransferValidationResult, DefaultResultError> {
    try {
      const errors: string[] = [];
      const warnings: string[] = [];

      // Validate wallet can sign transactions
      if (!request.fromWallet.canSign()) {
        errors.push('Source wallet cannot sign transactions (watch-only or missing private key)');
      }

      // Validate wallet is active
      if (!request.fromWallet.isActive) {
        errors.push('Source wallet is not active');
      }

      // Validate wallet network matches
      if (request.fromWallet.networkId !== request.networkId) {
        errors.push('Source wallet network does not match transaction network');
      }

      // Validate USDT token is active
      if (!request.usdtToken.isActive) {
        errors.push('USDT token is not active');
      }

      // Validate token network matches
      if (request.usdtToken.networkId !== request.networkId) {
        errors.push('USDT token network does not match transaction network');
      }

      // Validate addresses are different
      if (request.fromWallet.address === request.toAddress.value) {
        errors.push('Cannot transfer to the same address');
      }

      // Validate amount is positive
      if (!request.amount.isPositive()) {
        errors.push('Transfer amount must be greater than zero');
      }

      // Validate minimum transfer amount
      const minAmount = TokenAmount.fromSmallestUnit(request.usdtToken.getMinimumTransferAmount(), request.usdtToken.decimals);
      if (minAmount.result.type === 'SUCCESS' && request.amount.isLessThan(minAmount.result.data)) {
        errors.push(`Transfer amount is below minimum (${minAmount.result.data.toDecimalString()} USDT)`);
      }

      // Validate maximum transfer amount
      const maxAmount = TokenAmount.fromSmallestUnit(request.usdtToken.getMaximumTransferAmount(), request.usdtToken.decimals);
      if (maxAmount.result.type === 'SUCCESS' && request.amount.isGreaterThan(maxAmount.result.data)) {
        errors.push(`Transfer amount exceeds maximum (${maxAmount.result.data.toDecimalString()} USDT)`);
      }

      // Add warnings for large amounts
      const largeAmountThreshold = TokenAmount.create('10000', request.usdtToken.decimals); // 10,000 USDT
      if (largeAmountThreshold.result.type === 'SUCCESS' && request.amount.isGreaterThan(largeAmountThreshold.result.data)) {
        warnings.push('Large transfer amount detected - consider splitting into multiple transactions');
      }

      // Testnet warnings
      if (request.usdtToken.isTestnetUSDT()) {
        warnings.push('Using testnet USDT - ensure this is intended for testing only');
      }

      const gasFeeResult = GasFee.create(100000, GasFeeType.ENERGY);
      const result: TransferValidationResult = {
        isValid: errors.length === 0,
        errors,
        warnings,
        estimatedGasFee: gasFeeResult.result.type === 'SUCCESS' ? gasFeeResult.result.data : undefined,
        minimumBalance: request.amount
      };

      return Result.Success(result);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Transfer validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public createTransferTransaction(request: USDTTransferRequest): Result<TronTransaction, DefaultResultError> {
    // First validate the request
    const validationResult = this.validateTransferRequest(request);
    if (validationResult.result.type === 'ERROR') {
      return Result.Error(validationResult.result.error);
    }

    if (!validationResult.result.data.isValid) {
      return Result.Error({
        code: 'SERIALIZATION',
        payload: `Transfer validation failed: ${validationResult.result.data.errors.join(', ')}`
      });
    }

    // Create the transaction
    const transactionResult = TronTransaction.create({
      fromAddress: request.fromWallet.address,
      toAddress: request.toAddress.value,
      amount: request.amount.toDecimalString(),
      tokenAddress: request.usdtToken.contractAddress,
      transactionType: TransactionType.USDT_TRANSFER,
      networkId: request.networkId,
      gasLimit: 200000, // Higher gas limit for contract calls
      userId: request.userId,
      orderId: request.orderId,
      metadata: {
        ...request.metadata,
        tokenSymbol: request.usdtToken.symbol,
        tokenDecimals: request.usdtToken.decimals,
        walletId: request.fromWallet.walletId,
        estimatedGasFee: validationResult.result.data.estimatedGasFee?.toString()
      }
    });

    return transactionResult;
  }

  public calculateGasFeeEstimate(
    amount: TokenAmount, 
    networkCongestion: 'low' | 'medium' | 'high' = 'medium'
  ): Result<GasFee, DefaultResultError> {
    try {
      // Base gas for USDT transfers (typical range: 50,000 - 200,000)
      let baseGas = 100000;

      // Adjust for network congestion
      switch (networkCongestion) {
        case 'low':
          baseGas = 80000;
          break;
        case 'medium':
          baseGas = 120000;
          break;
        case 'high':
          baseGas = 200000;
          break;
      }

      // Large amounts might require more gas
      const largeAmountThreshold = TokenAmount.create('50000', 6); // 50,000 USDT
      if (largeAmountThreshold.result.type === 'SUCCESS' && amount.isGreaterThan(largeAmountThreshold.result.data)) {
        baseGas = Math.ceil(baseGas * 1.2); // 20% increase for large amounts
      }

      const gasFee = GasFee.create(baseGas, GasFeeType.ENERGY);
      return gasFee;
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Gas fee calculation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public validateTransferAmount(
    amount: TokenAmount,
    token: USDTToken,
    availableBalance?: TokenAmount
  ): Result<boolean, DefaultResultError> {
    try {
      // Check minimum amount
      const minAmount = TokenAmount.fromSmallestUnit(token.getMinimumTransferAmount(), token.decimals);
      if (minAmount.result.type === 'SUCCESS' && amount.isLessThan(minAmount.result.data)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: `Amount below minimum transfer limit (${minAmount.result.data.toDecimalString()} ${token.symbol})`
        });
      }

      // Check maximum amount
      const maxAmount = TokenAmount.fromSmallestUnit(token.getMaximumTransferAmount(), token.decimals);
      if (maxAmount.result.type === 'SUCCESS' && amount.isGreaterThan(maxAmount.result.data)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: `Amount exceeds maximum transfer limit (${maxAmount.result.data.toDecimalString()} ${token.symbol})`
        });
      }

      // Check available balance if provided
      if (availableBalance && amount.isGreaterThan(availableBalance)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: `Insufficient balance. Available: ${availableBalance.toDecimalString()} ${token.symbol}`
        });
      }

      return Result.Success(true);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Amount validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public isHighValueTransfer(amount: TokenAmount, thresholdUSD: number = 10000): boolean {
    try {
      // Assuming 1 USDT = 1 USD for simplicity
      const amountInUSD = parseFloat(amount.toDecimalString());
      return amountInUSD >= thresholdUSD;
    } catch {
      return false;
    }
  }

  public suggestOptimalGasLimit(
    transferType: 'standard' | 'high_priority',
    networkCongestion: 'low' | 'medium' | 'high'
  ): number {
    const baseGasLimits = {
      standard: {
        low: 80000,
        medium: 120000,
        high: 180000
      },
      high_priority: {
        low: 120000,
        medium: 180000,
        high: 250000
      }
    };

    return baseGasLimits[transferType][networkCongestion];
  }

  public formatTransferSummary(request: USDTTransferRequest): string {
    const fromAddress = TronAddress.create(request.fromWallet.address);
    const fromShort = fromAddress.result.type === 'SUCCESS' 
      ? fromAddress.result.data.getShortFormat() 
      : request.fromWallet.address;
    const toShort = request.toAddress.getShortFormat();
    
    return `Transfer ${request.amount.toDecimalString()} ${request.usdtToken.symbol} from ${fromShort} to ${toShort}`;
  }
}