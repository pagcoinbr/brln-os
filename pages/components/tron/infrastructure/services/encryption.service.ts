import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

/**
 * Service for encrypting and decrypting sensitive data like private keys
 * Uses AES-256-GCM for encryption
 */
@Injectable()
export class EncryptionService {
  private readonly logger = new Logger(EncryptionService.name);
  private readonly algorithm = 'aes-256-gcm';
  private readonly key: Buffer;
  private readonly iv: Buffer;

  constructor(private readonly configService: ConfigService) {
    // Get encryption key from environment
    const encryptionKey = this.configService.get<string>('ENCRYPTION_KEY');
    const encryptionIv = this.configService.get<string>('ENCRYPTION_IV');

    if (!encryptionKey || !encryptionIv) {
      throw new Error('ENCRYPTION_KEY and ENCRYPTION_IV must be set in environment variables');
    }

    // Convert key to proper format (32 bytes for AES-256)
    this.key = crypto.scryptSync(encryptionKey, 'salt', 32);
    
    // Convert IV to proper format (16 bytes)
    this.iv = crypto.scryptSync(encryptionIv, 'salt', 16);

    this.logger.log('Encryption service initialized');
  }

  /**
   * Encrypt a private key or sensitive data
   * Returns base64 encoded encrypted data with auth tag
   */
  encrypt(plaintext: string): string {
    try {
      const cipher = crypto.createCipheriv(this.algorithm, this.key, this.iv);
      
      let encrypted = cipher.update(plaintext, 'utf8', 'base64');
      encrypted += cipher.final('base64');
      
      // Get authentication tag for GCM mode
      const authTag = cipher.getAuthTag();
      
      // Combine encrypted data and auth tag
      const result = {
        encrypted,
        authTag: authTag.toString('base64'),
      };
      
      return Buffer.from(JSON.stringify(result)).toString('base64');
    } catch (error) {
      this.logger.error(`Encryption failed: ${error.message}`);
      throw new Error('Failed to encrypt data');
    }
  }

  /**
   * Decrypt a private key or sensitive data
   * Expects base64 encoded data with auth tag
   */
  decrypt(ciphertext: string): string {
    try {
      // Decode the combined data
      const combined = JSON.parse(Buffer.from(ciphertext, 'base64').toString('utf8'));
      
      const decipher = crypto.createDecipheriv(this.algorithm, this.key, this.iv);
      
      // Set authentication tag
      decipher.setAuthTag(Buffer.from(combined.authTag, 'base64'));
      
      let decrypted = decipher.update(combined.encrypted, 'base64', 'utf8');
      decrypted += decipher.final('utf8');
      
      return decrypted;
    } catch (error) {
      this.logger.error(`Decryption failed: ${error.message}`);
      throw new Error('Failed to decrypt data');
    }
  }

  /**
   * Encrypt private key specifically
   */
  encryptPrivateKey(privateKey: string): string {
    if (!privateKey) {
      throw new Error('Private key cannot be empty');
    }
    
    return this.encrypt(privateKey);
  }

  /**
   * Decrypt private key specifically
   */
  decryptPrivateKey(encryptedPrivateKey: string): string {
    if (!encryptedPrivateKey) {
      throw new Error('Encrypted private key cannot be empty');
    }
    
    return this.decrypt(encryptedPrivateKey);
  }

  /**
   * Hash a string (one-way, for comparison purposes)
   * Useful for storing wallet addresses that shouldn't be decrypted
   */
  hash(data: string): string {
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  /**
   * Generate a secure random string (for keys, tokens, etc.)
   */
  generateSecureRandom(length: number = 32): string {
    return crypto.randomBytes(length).toString('hex');
  }
}
