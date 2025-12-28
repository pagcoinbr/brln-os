import { Injectable, Logger } from '@nestjs/common';
import { TronWeb } from 'tronweb';
import { DefaultResultError, Result } from '../../../global/utils/Result';
import { TokenAmount } from '../value-objects/token-amount.vo';
import { TronAddress } from '../value-objects/tron-address.vo';

// Remove unused TronWeb constructor

export interface GasFreeTransferRequest {
  fromAddress: string; // EOA address (TYgHbEBuWL4LNPt959CgkzR1TCSxMeH3oY)
  privateKey: string; // Private key for EIP-712 signing
  toAddress: TronAddress;
  amount: TokenAmount;
  usdtContractAddress: string; // TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t
  serviceProvider: string;
  nonce: number;
  chainId: number;
  verifyingContract: string;
  maxFee: string; // In smallest unit (e.g., 20 USDT = 20000000)
  deadline?: number; // Optional, will use default if not provided
}

export interface GasFreeSignedTransfer {
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

export interface GasFreeTransferValidation {
  isValid: boolean;
  errors: string[];
  warnings: string[];
}

/**
 * Domain Service for GasFree transfer logic
 * Handles EIP-712 signing and validation following GasFree specification
 */
@Injectable()
export class TronGasFreeService {
  private readonly logger = new Logger(TronGasFreeService.name);

  /**
   * Validate transfer request before signing
   */
  validateTransferRequest(
    request: GasFreeTransferRequest,
  ): Result<GasFreeTransferValidation, DefaultResultError> {
    const errors: string[] = [];
    const warnings: string[] = [];

    try {
      // Validate from address format
      if (!this.isValidTronAddress(request.fromAddress)) {
        errors.push('Invalid from address format');
      }

      // Validate to address
      if (!request.toAddress || !request.toAddress.value) {
        errors.push('Invalid to address');
      }

      // Validate amount
      if (!request.amount || request.amount.value <= BigInt(0)) {
        errors.push('Amount must be greater than zero');
      }

      // Validate USDT contract address
      if (!this.isValidTronAddress(request.usdtContractAddress)) {
        errors.push('Invalid USDT contract address');
      }

      // Validate service provider address
      if (!this.isValidTronAddress(request.serviceProvider)) {
        errors.push('Invalid service provider address');
      }

      // Validate nonce
      if (request.nonce < 0) {
        errors.push('Nonce must be non-negative');
      }

      // Validate maxFee
      const maxFeeValue = BigInt(request.maxFee);
      if (maxFeeValue <= BigInt(0)) {
        errors.push('Max fee must be greater than zero');
      }

      // Validate amount + maxFee doesn't overflow
      const totalCost = request.amount.value + maxFeeValue;
      if (totalCost <= request.amount.value) {
        errors.push('Amount + maxFee overflow detected');
      }

      // Warning for high fees
      const feePercentage = Number(
        (maxFeeValue * BigInt(100)) / request.amount.value,
      );
      if (feePercentage > 10) {
        warnings.push(
          `High fee detected: ${feePercentage}% of transfer amount`,
        );
      }

      const validation: GasFreeTransferValidation = {
        isValid: errors.length === 0,
        errors,
        warnings,
      };

      return Result.Success(validation);
    } catch (error) {
      this.logger.error(`Transfer validation failed: ${error.message}`);
      return Result.Error({
        code: 'UNKNOWN',
        payload: `Failed to validate transfer: ${error.message}`,
      });
    }
  }

  /**
   * Create and sign GasFree transfer using EIP-712
   * Following GasFree specification: https://test.gasfree.io/docs/GasFree_specification.html
   */
  async signGasFreeTransfer(
    request: GasFreeTransferRequest,
  ): Promise<Result<GasFreeSignedTransfer, DefaultResultError>> {
    try {
      // Validate request first
      const validationResult = this.validateTransferRequest(request);
      if (validationResult.result.type === 'ERROR') {
        return Result.Error(validationResult.result.error);
      }

      const validation = validationResult.result.data;
      if (!validation.isValid) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: `Transfer validation failed: ${validation.errors.join(', ')}`,
        });
      }

      // Calculate deadline (default 180 seconds from now)
      const deadline = request.deadline || Math.floor(Date.now() / 1000) + 180;

      // EIP-712 Domain as per GasFree specification
      const domain = {
        name: 'GasFreeController',
        version: 'V1.0.0',
        chainId: request.chainId, // 728126428 for mainnet, 3448148188 for testnet
        verifyingContract: request.verifyingContract, // TFFAMLQZybALab4uxHA9RBE7pxhUAjfF3U for mainnet
      };

      // EIP-712 Types as per GasFree specification
      const types = {
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

      // Create TronWeb instance for validation and signing
      const tronWeb = new TronWeb({
        fullHost: 'https://api.trongrid.io',
      });

      // Validate addresses before converting
      const addresses = {
        token: request.usdtContractAddress,
        serviceProvider: request.serviceProvider,
        user: request.fromAddress,
        receiver: request.toAddress.value,
      };

      // Validate each address
      for (const [key, addr] of Object.entries(addresses)) {
        if (!tronWeb.isAddress(addr)) {
          throw new Error(`Invalid ${key} address: ${addr}`);
        }
      }

      const tokenHex = tronWeb.address.toHex(request.usdtContractAddress);
      const serviceProviderHex = tronWeb.address.toHex(request.serviceProvider);
      const userHex = tronWeb.address.toHex(request.fromAddress);
      const receiverHex = tronWeb.address.toHex(request.toAddress.value);

      // Message body for EIP-712
      const message = {
        token: tokenHex,
        serviceProvider: serviceProviderHex,
        user: userHex,
        receiver: receiverHex,
        value: request.amount.value.toString(),
        maxFee: request.maxFee,
        deadline: deadline.toString(),
        version: '1',
        nonce: request.nonce.toString(),
      };

      this.logger.debug('Signing EIP-712 message with TronWeb', {
        domain,
        message,
        fromAddress: request.fromAddress,
      });

      // Use official GasFree SDK for proper EIP-712 signing
      const { TronGasFree } = await import('@gasfree/gasfree-sdk');

      // Initialize GasFree SDK with mainnet configuration
      const tronGasFree = new TronGasFree({
        chainId: Number('0x2b6653dc'), // TRON mainnet
      });

      // Assemble transaction JSON for EIP-712 signing
      const transactionJson = tronGasFree.assembleGasFreeTransactionJson({
        token: request.usdtContractAddress,
        serviceProvider: request.serviceProvider,
        user: request.fromAddress,
        receiver: request.toAddress.value,
        value: request.amount.value.toString(),
        maxFee: request.maxFee,
        deadline: deadline.toString(),
        version: '1',
        nonce: request.nonce.toString(),
      });

      this.logger.debug('GasFree SDK transaction JSON assembled', {
        domain: transactionJson.domain,
        types: transactionJson.types,
        message: transactionJson.message,
      });

      // Sign with TronWeb's EIP-712 implementation
      const signature = await tronWeb.trx._signTypedData(
        transactionJson.domain,
        transactionJson.types,
        transactionJson.message,
        request.privateKey,
      );

      // Remove '0x' prefix from signature if present
      const cleanSignature = signature.startsWith('0x')
        ? signature.slice(2)
        : signature;

      const signedTransfer: GasFreeSignedTransfer = {
        token: request.usdtContractAddress,
        serviceProvider: request.serviceProvider,
        user: request.fromAddress,
        receiver: request.toAddress.value,
        value: request.amount.value.toString(),
        maxFee: request.maxFee,
        deadline,
        version: 1,
        nonce: request.nonce,
        sig: cleanSignature,
      };

      this.logger.log('GasFree transfer signed successfully', {
        from: request.fromAddress,
        to: request.toAddress.value,
        amount: request.amount.toDecimalString(),
        nonce: request.nonce,
      });

      return Result.Success(signedTransfer);
    } catch (error) {
      this.logger.error(
        `Failed to sign GasFree transfer: ${error.message}`,
        error.stack,
      );
      return Result.Error({
        code: 'EXTERNAL_SERVICE_ERROR',
        payload: `Failed to sign transfer: ${error.message}`,
      });
    }
  }

  /**
   * Calculate recommended maxFee based on transfer amount and activation status
   * Following GasFree fee structure: activateFee (first transfer) or transferFee
   */
  calculateRecommendedMaxFee(
    amount: TokenAmount,
    isAccountActive: boolean,
    activateFee: number = 10000000, // 10 USDT default
    transferFee: number = 10000000, // 10 USDT default
  ): string {
    // If account not active, include activation fee
    const totalFee = isAccountActive ? transferFee : activateFee + transferFee;

    // Add 20% buffer for safety
    const feeWithBuffer = Math.ceil(totalFee * 1.2);

    this.logger.debug('Calculated recommended maxFee', {
      isAccountActive,
      activateFee,
      transferFee,
      totalFee,
      feeWithBuffer,
      amountInSmallestUnit: amount.value.toString(),
    });

    return feeWithBuffer.toString();
  }

  /**
   * Validate TRON address format
   */
  private isValidTronAddress(address: string): boolean {
    const tronAddressRegex = /^T[A-Za-z0-9]{33}$/;
    return tronAddressRegex.test(address);
  }

  /**
   * Estimate total cost (amount + fees)
   */
  estimateTotalCost(
    amount: TokenAmount,
    maxFee: string,
  ): {
    totalCost: bigint;
    amountInUSDT: string;
    feeInUSDT: string;
    totalInUSDT: string;
  } {
    const amountSmallest = amount.value;
    const feeSmallest = BigInt(maxFee);
    const totalCost = amountSmallest + feeSmallest;

    return {
      totalCost,
      amountInUSDT: amount.toDecimalString(),
      feeInUSDT: (Number(feeSmallest) / 1_000_000).toFixed(6),
      totalInUSDT: (Number(totalCost) / 1_000_000).toFixed(6),
    };
  }
}
