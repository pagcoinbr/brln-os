import { Module } from '@nestjs/common';

// Repository Interface Tokens (for dependency injection)
import {
  TRON_NETWORK_REPOSITORY,
  TRON_TRANSACTION_REPOSITORY,
  TRON_WALLET_REPOSITORY,
  USDT_TOKEN_REPOSITORY,
} from './tron.tokens';

// Domain Services
import { TronGasFreeService } from './domain/services/tron-gasfree.service';
import { TronNetworkService } from './domain/services/tron-network.service';
import { TronValidationService } from './domain/services/tron-validation.service';
import { USDTTransferService } from './domain/services/usdt-transfer.service';

// Application Services
import { TronGasFreeApplicationService } from './application/services/tron-gasfree-application.service';
import { TronNetworkApplicationService } from './application/services/tron-network-application.service';
import { TronTransactionApplicationService } from './application/services/tron-transaction-application.service';
import { TronWalletApplicationService } from './application/services/tron-wallet-application.service';

// Infrastructure - Providers
import { GasFreeProvider } from './infrastructure/providers/gasfree.provider';
import { TronNetworkProvider } from './infrastructure/providers/tron-network.provider';

// Infrastructure - Repositories
import { TronNetworkRepository } from './infrastructure/repositories/tron-network.repository';
import { TronTransactionRepository } from './infrastructure/repositories/tron-transaction.repository';
import { TronWalletRepository } from './infrastructure/repositories/tron-wallet.repository';
import { USDTTokenRepository } from './infrastructure/repositories/usdt-token.repository';

@Module({
  providers: [
    // Domain Services
    TronNetworkService,
    USDTTransferService,
    TronValidationService,
    TronGasFreeService,

    // Application Services
    TronWalletApplicationService,
    TronTransactionApplicationService,
    TronNetworkApplicationService,
    TronGasFreeApplicationService,

    // Infrastructure Providers
    TronNetworkProvider,
    GasFreeProvider,

    // Repository Implementations (using token-based injection)
    {
      provide: TRON_NETWORK_REPOSITORY,
      useClass: TronNetworkRepository,
    },
    {
      provide: TRON_WALLET_REPOSITORY,
      useClass: TronWalletRepository,
    },
    {
      provide: TRON_TRANSACTION_REPOSITORY,
      useClass: TronTransactionRepository,
    },
    {
      provide: USDT_TOKEN_REPOSITORY,
      useClass: USDTTokenRepository,
    },
  ],
  exports: [
    // Export application services for use in other modules
    TronWalletApplicationService,
    TronTransactionApplicationService,
    TronNetworkApplicationService,
    TronGasFreeApplicationService,

    // Export domain services if needed by other modules
    TronNetworkService,
    USDTTransferService,
    TronValidationService,
    TronGasFreeService,

    // Export provider for direct blockchain access if needed
    TronNetworkProvider,
    GasFreeProvider,

    // Export repository tokens for testing/mocking
    TRON_NETWORK_REPOSITORY,
    TRON_WALLET_REPOSITORY,
    TRON_TRANSACTION_REPOSITORY,
    USDT_TOKEN_REPOSITORY,
  ],
})
export class TronModule {}

// Re-export tokens for backward compatibility
export {
  TRON_NETWORK_REPOSITORY,
  TRON_TRANSACTION_REPOSITORY,
  TRON_WALLET_REPOSITORY,
  USDT_TOKEN_REPOSITORY,
} from './tron.tokens';
