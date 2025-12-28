import { Result, DefaultResultError } from '../../../global/utils/Result';
import { TronAddress } from '../value-objects/tron-address.vo';
import { TransactionHash } from '../value-objects/transaction-hash.vo';
import { TokenAmount } from '../value-objects/token-amount.vo';

export interface AddressValidationResult {
  isValid: boolean;
  isMainnet: boolean;
  isTestnet: boolean;
  error?: string;
}

export interface TransactionValidationResult {
  isValid: boolean;
  hasValidFormat: boolean;
  estimatedConfirmations: number;
  error?: string;
}

export class TronValidationService {

  public validateAddress(address: string): Result<AddressValidationResult, DefaultResultError> {
    try {
      const addressResult = TronAddress.create(address);
      
      if (addressResult.result.type === 'ERROR') {
        return Result.Success({
          isValid: false,
          isMainnet: false,
          isTestnet: false,
          error: addressResult.result.error.payload
        });
      }

      const tronAddress = addressResult.result.data;
      
      return Result.Success({
        isValid: true,
        isMainnet: tronAddress.isMainnetAddress(),
        isTestnet: !tronAddress.isMainnetAddress(),
        error: undefined
      });
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Address validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public validateTransactionHash(hash: string): Result<TransactionValidationResult, DefaultResultError> {
    try {
      const hashResult = TransactionHash.create(hash);
      
      if (hashResult.result.type === 'ERROR') {
        return Result.Success({
          isValid: false,
          hasValidFormat: false,
          estimatedConfirmations: 0,
          error: hashResult.result.error.payload
        });
      }

      return Result.Success({
        isValid: true,
        hasValidFormat: true,
        estimatedConfirmations: 1, // Default estimation
        error: undefined
      });
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Transaction hash validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public validateTokenAmount(
    amount: string, 
    decimals: number = 6
  ): Result<TokenAmount, DefaultResultError> {
    return TokenAmount.create(amount, decimals);
  }

  public isValidUSDTContractAddress(address: string): boolean {
    // Known USDT contract addresses
    const knownUSDTAddresses = [
      'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t', // Mainnet USDT
      'TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf', // Nile testnet USDT
      'TG3XXyExBkPp9nzdajDZsozEu4BkaSJozs'  // Shasta testnet USDT
    ];

    return knownUSDTAddresses.includes(address);
  }

  public validatePrivateKey(privateKey: string): Result<boolean, DefaultResultError> {
    try {
      // TRON private keys are 64-character hex strings
      const privateKeyRegex = /^[a-fA-F0-9]{64}$/;
      
      if (!privateKey) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Private key cannot be empty'
        });
      }

      if (!privateKeyRegex.test(privateKey)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid private key format. Must be a 64-character hexadecimal string'
        });
      }

      return Result.Success(true);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Private key validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public validateNetworkCompatibility(
    address: string, 
    isTestnet: boolean
  ): Result<boolean, DefaultResultError> {
    try {
      const addressResult = this.validateAddress(address);
      
      if (addressResult.result.type === 'ERROR') {
        return Result.Error(addressResult.result.error);
      }

      if (!addressResult.result.data.isValid) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Invalid address format'
        });
      }

      const addressIsTestnet = addressResult.result.data.isTestnet;
      
      if (isTestnet !== addressIsTestnet) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: `Address network mismatch. Expected ${isTestnet ? 'testnet' : 'mainnet'} address`
        });
      }

      return Result.Success(true);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Network compatibility validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public validateTransferBounds(
    amount: TokenAmount,
    minAmount?: TokenAmount,
    maxAmount?: TokenAmount
  ): Result<boolean, DefaultResultError> {
    try {
      if (!amount.isPositive()) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Amount must be greater than zero'
        });
      }

      if (minAmount && amount.isLessThan(minAmount)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: `Amount is below minimum limit (${minAmount.toDecimalString()})`
        });
      }

      if (maxAmount && amount.isGreaterThan(maxAmount)) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: `Amount exceeds maximum limit (${maxAmount.toDecimalString()})`
        });
      }

      return Result.Success(true);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Transfer bounds validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public estimateTransactionRisk(
    amount: TokenAmount,
    fromAddress: string,
    toAddress: string
  ): 'low' | 'medium' | 'high' {
    try {
      let riskScore = 0;

      // Amount-based risk
      const amountValue = parseFloat(amount.toDecimalString());
      if (amountValue >= 100000) { // $100k+
        riskScore += 3;
      } else if (amountValue >= 10000) { // $10k+
        riskScore += 2;
      } else if (amountValue >= 1000) { // $1k+
        riskScore += 1;
      }

      // Address validation risk
      const fromValidation = this.validateAddress(fromAddress);
      const toValidation = this.validateAddress(toAddress);
      
      if (fromValidation.result.type === 'ERROR' || toValidation.result.type === 'ERROR') {
        riskScore += 2;
      }

      // Same address transfer (should be caught earlier but double-check)
      if (fromAddress === toAddress) {
        riskScore += 3;
      }

      // Risk levels
      if (riskScore >= 5) return 'high';
      if (riskScore >= 3) return 'medium';
      return 'low';
    } catch {
      return 'high'; // Default to high risk if estimation fails
    }
  }

  public validateGasParameters(
    gasLimit: number,
    gasPrice?: string
  ): Result<boolean, DefaultResultError> {
    try {
      if (gasLimit <= 0) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Gas limit must be greater than zero'
        });
      }

      if (gasLimit > 10_000_000) { // Reasonable upper bound
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Gas limit too high (maximum: 10,000,000)'
        });
      }

      if (gasPrice !== undefined) {
        const price = parseFloat(gasPrice);
        if (isNaN(price) || price < 0) {
          return Result.Error({
            code: 'SERIALIZATION',
            payload: 'Gas price must be a non-negative number'
          });
        }
      }

      return Result.Success(true);
    } catch (error) {
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Gas parameters validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public sanitizeAddress(address: string): string {
    // Remove any whitespace and ensure proper casing
    return address.trim();
  }

  public sanitizeAmount(amount: string): string {
    // Remove any non-numeric characters except decimal point
    return amount.replace(/[^0-9.]/g, '');
  }

  public formatValidationError(error: string): string {
    // Standardize error message formatting
    return error.charAt(0).toUpperCase() + error.slice(1).toLowerCase();
  }
}