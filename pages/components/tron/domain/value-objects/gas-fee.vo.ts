import { Result, DefaultResultError } from '../../../global/utils/Result';

export enum GasFeeType {
  ENERGY = 'ENERGY',
  BANDWIDTH = 'BANDWIDTH',
  TOTAL = 'TOTAL'
}

export class GasFee {
  private readonly _amount: bigint;
  private readonly _type: GasFeeType;
  private readonly _pricePerUnit: bigint;

  private constructor(amount: bigint, type: GasFeeType, pricePerUnit: bigint) {
    this._amount = amount;
    this._type = type;
    this._pricePerUnit = pricePerUnit;
  }

  public static create(
    amount: string | number | bigint,
    type: GasFeeType,
    pricePerUnit: string | number | bigint = BigInt(0)
  ): Result<GasFee, DefaultResultError> {
    try {
      let amountBigInt: bigint;
      let pricePerUnitBigInt: bigint;

      // Convert amount to BigInt
      if (typeof amount === 'string') {
        if (!amount || amount.trim() === '') {
          return Result.Error({
            code: 'SERIALIZATION',
            payload: 'Gas fee amount cannot be empty'
          });
        }
        amountBigInt = BigInt(amount);
      } else if (typeof amount === 'number') {
        if (!isFinite(amount)) {
          return Result.Error({
            code: 'SERIALIZATION',
            payload: 'Gas fee amount must be a finite number'
          });
        }
        amountBigInt = BigInt(Math.floor(amount));
      } else {
        amountBigInt = amount;
      }

      // Convert pricePerUnit to BigInt
      if (typeof pricePerUnit === 'string') {
        pricePerUnitBigInt = BigInt(pricePerUnit);
      } else if (typeof pricePerUnit === 'number') {
        pricePerUnitBigInt = BigInt(Math.floor(pricePerUnit));
      } else {
        pricePerUnitBigInt = pricePerUnit;
      }

      if (amountBigInt < 0) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Gas fee amount cannot be negative'
        });
      }

      if (pricePerUnitBigInt < 0) {
        return Result.Error({
          code: 'SERIALIZATION',
          payload: 'Gas fee price per unit cannot be negative'
        });
      }

      return Result.Success(new GasFee(amountBigInt, type, pricePerUnitBigInt));
    } catch (error) {
      return Result.Error({
        code: 'SERIALIZATION',
        payload: `Failed to create GasFee: ${error instanceof Error ? error.message : 'Unknown error'}`
      });
    }
  }

  public static zero(type: GasFeeType): GasFee {
    return new GasFee(BigInt(0), type, BigInt(0));
  }

  public static fromSun(sunAmount: bigint, type: GasFeeType): GasFee {
    return new GasFee(sunAmount, type, BigInt(0));
  }

  public get amount(): bigint {
    return this._amount;
  }

  public get type(): GasFeeType {
    return this._type;
  }

  public get pricePerUnit(): bigint {
    return this._pricePerUnit;
  }

  public toSun(): bigint {
    return this._amount;
  }

  public toTRX(): string {
    // Convert SUN to TRX (1 TRX = 1,000,000 SUN)
    const trxAmount = this._amount / BigInt(1_000_000);
    const sunRemainder = this._amount % BigInt(1_000_000);

    if (sunRemainder === BigInt(0)) {
      return trxAmount.toString();
    }

    const fractionalPart = sunRemainder.toString().padStart(6, '0');
    const trimmedFractional = fractionalPart.replace(/0+$/, '');
    
    return `${trxAmount}.${trimmedFractional}`;
  }

  public equals(other: GasFee): boolean {
    return this._amount === other._amount && 
           this._type === other._type && 
           this._pricePerUnit === other._pricePerUnit;
  }

  public isZero(): boolean {
    return this._amount === BigInt(0);
  }

  public isEnergy(): boolean {
    return this._type === GasFeeType.ENERGY;
  }

  public isBandwidth(): boolean {
    return this._type === GasFeeType.BANDWIDTH;
  }

  public isTotal(): boolean {
    return this._type === GasFeeType.TOTAL;
  }

  public add(other: GasFee): Result<GasFee, DefaultResultError> {
    if (this._type !== other._type) {
      return Result.Error({
        code: 'SERIALIZATION',
        payload: 'Cannot add gas fees of different types'
      });
    }

    return Result.Success(new GasFee(
      this._amount + other._amount,
      this._type,
      this._pricePerUnit
    ));
  }

  public multiply(factor: number): Result<GasFee, DefaultResultError> {
    if (!isFinite(factor) || factor < 0) {
      return Result.Error({
        code: 'SERIALIZATION',
        payload: 'Factor must be a positive finite number'
      });
    }

    const result = this._amount * BigInt(Math.floor(factor * 1000)) / BigInt(1000);
    
    return Result.Success(new GasFee(result, this._type, this._pricePerUnit));
  }

  public calculateTotalCost(): bigint {
    if (this._pricePerUnit === BigInt(0)) {
      return this._amount;
    }
    return this._amount * this._pricePerUnit;
  }

  public isGreaterThan(other: GasFee): boolean {
    if (this._type !== other._type) {
      throw new Error('Cannot compare gas fees of different types');
    }
    return this._amount > other._amount;
  }

  public isLessThan(other: GasFee): boolean {
    if (this._type !== other._type) {
      throw new Error('Cannot compare gas fees of different types');
    }
    return this._amount < other._amount;
  }

  public toString(): string {
    return `${this._amount.toString()} ${this._type}`;
  }

  public toDetailedString(): string {
    if (this._pricePerUnit === BigInt(0)) {
      return `${this._amount.toString()} ${this._type}`;
    }
    return `${this._amount.toString()} ${this._type} (${this._pricePerUnit.toString()} SUN per unit)`;
  }
}