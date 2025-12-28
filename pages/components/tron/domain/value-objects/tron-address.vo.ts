import { Result, DefaultResultError } from '../../../global/utils/Result';

export class TronAddress {
  private readonly _value: string;

  private constructor(value: string) {
    this._value = value;
  }

  public static create(address: string): Result<TronAddress, DefaultResultError> {
    if (!address) {
      return Result.Error({
        code: 'SERIALIZATION',
        payload: 'Address cannot be empty'
      });
    }

    if (!this.isValid(address)) {
      return Result.Error({
        code: 'SERIALIZATION',
        payload: 'Invalid TRON address format. Address must start with "T" and be 34 characters long'
      });
    }

    return Result.Success(new TronAddress(address));
  }

  public get value(): string {
    return this._value;
  }

  public equals(other: TronAddress): boolean {
    return this._value === other._value;
  }

  public getShortFormat(): string {
    return `${this._value.slice(0, 6)}...${this._value.slice(-4)}`;
  }

  public isMainnetAddress(): boolean {
    // Mainnet addresses typically start with specific patterns
    // This is a simplified check - in practice, you might want more sophisticated validation
    return this._value.startsWith('T') && this._value.length === 34;
  }

  public toHex(): string {
    // Note: This is a placeholder implementation
    // In practice, you would use TRON SDK to convert base58 to hex
    return this._value; // Simplified for now
  }

  public toString(): string {
    return this._value;
  }

  private static isValid(address: string): boolean {
    // TRON addresses are base58check encoded and start with 'T'
    // They are exactly 34 characters long
    const tronAddressRegex = /^T[A-Za-z0-9]{33}$/;
    return tronAddressRegex.test(address);
  }
}