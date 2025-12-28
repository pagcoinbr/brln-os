import { Result, DefaultResultError } from '../../../global/utils/Result';

export class TransactionHash {
  private readonly _value: string;

  private constructor(value: string) {
    this._value = value;
  }

  public static create(hash: string): Result<TransactionHash, DefaultResultError> {
    if (!hash) {
      return Result.Error({
        code: 'SERIALIZATION',
        payload: 'Transaction hash cannot be empty'
      });
    }

    if (!this.isValid(hash)) {
      return Result.Error({
        code: 'SERIALIZATION',
        payload: 'Invalid transaction hash format. Must be a 64-character hexadecimal string'
      });
    }

    return Result.Success(new TransactionHash(hash));
  }

  public get value(): string {
    return this._value;
  }

  public equals(other: TransactionHash): boolean {
    return this._value.toLowerCase() === other._value.toLowerCase();
  }

  public getShortFormat(): string {
    return `${this._value.slice(0, 8)}...${this._value.slice(-8)}`;
  }

  public toString(): string {
    return this._value;
  }

  public toUpperCase(): string {
    return this._value.toUpperCase();
  }

  public toLowerCase(): string {
    return this._value.toLowerCase();
  }

  private static isValid(hash: string): boolean {
    // TRON transaction hashes are 64-character hexadecimal strings
    const hashRegex = /^[a-fA-F0-9]{64}$/;
    return hashRegex.test(hash);
  }
}