# TRON Gas-Free Wallet

This directory contains the TRON gas-free wallet implementation for BRLN-OS, allowing users to send and receive USDT on the TRON network without needing TRX for gas fees.

## Features

- **Gas-Free Transactions**: Send USDT without needing TRX for gas fees
- **Fixed Fee**: 1 USDT per transaction via gas-free protocol
- **Wallet Display**: View your TRON address with QR code
- **Balance Tracking**: Real-time USDT and TRX balance display
- **Transaction History**: View last 30 transactions
- **API Configuration**: Configure TRON and Gas-Free API endpoints

## Files

- `tron.html` - Main wallet interface
- `tron.css` - Styling (follows BRLN-OS design system)
- `tron.js` - Frontend JavaScript logic
- `tron.module.ts` - NestJS module (TypeScript implementation)
- `tron.tokens.ts` - Dependency injection tokens

## Architecture

The implementation follows a clean architecture pattern:

```
application/
  services/       - Application layer services
domain/
  entities/       - Domain entities (wallet, transaction, network)
  repositories/   - Repository interfaces
  services/       - Domain business logic
  value-objects/  - Value objects (address, amount, etc)
infrastructure/
  providers/      - External API providers
  repositories/   - Repository implementations
  services/       - Infrastructure services
```

## Configuration

### Required Environment Variables

```bash
# TRON Network Configuration
TRON_DEPOSIT_ADDRESS="TFKqshj7e79RC84czeK46RQ3TwxbyDfiTn"
TRON_API_URL="https://api.trongrid.io"
TRON_API_KEY="your-trongrid-api-key"
TRON_MAINNET_CHAIN_ID="728126428"

# Gas-Free Protocol Configuration
GASFREE_API_KEY="your-gasfree-api-key"
GASFREE_API_SECRET="your-gasfree-api-secret"
GASFREE_MAINNET_ENDPOINT="https://open.gasfree.io/tron/"
GASFREE_VERIFYING_CONTRACT="TFFAMLQZybALab4uxHA9RBE7pxhUAjfF3U"
GASFREE_SERVICE_PROVIDER_ADDRESS="TLntW9Z59LYY5KEi9cmwk3PKjQga828ird"

# TRON System Wallet (for gas-free operations)
TRON_GASFREE_SYSTEM_ADDRESS="TFKqshj7e79RC84czeK46RQ3TwxbyDfiTn"
TRON_GASFREE_SYSTEM_PRIVATE_KEY="your-private-key"

# USDT Contract
TRON_USDT_CONTRACT_ADDRESS="TR7NHqjeKQxGTCi8z8ZY4pL8otSzgjLj6t"
```

### Database Schema

The wallet uses a secure SQLite database with encrypted storage:

```sql
CREATE TABLE tron_config (
    id INTEGER PRIMARY KEY DEFAULT 1,
    tron_address TEXT,
    encrypted_private_key BLOB,
    salt BLOB,
    tron_api_url TEXT DEFAULT 'https://api.trongrid.io',
    tron_api_key TEXT,
    gasfree_api_key TEXT,
    gasfree_api_secret TEXT,
    gasfree_endpoint TEXT DEFAULT 'https://open.gasfree.io/tron/',
    gasfree_verifying_contract TEXT DEFAULT 'TFFAMLQZybALab4uxHA9RBE7pxhUAjfF3U',
    gasfree_service_provider TEXT DEFAULT 'TLntW9Z59LYY5KEi9cmwk3PKjQga828ird',
    usdt_contract_address TEXT DEFAULT 'TR7NHqjeKQxGTCi8z8ZY4pL8otSzgjLj6t',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CHECK (id = 1)
);
```

## API Endpoints

All endpoints are prefixed with `/api/v1/tron/`:

### Wallet Management

- `GET /wallet/address` - Get wallet address
- `GET /wallet/balance` - Get USDT and TRX balance
- `POST /wallet/send` - Send USDT (gas-free)
- `GET /wallet/transactions` - Get transaction history

### Configuration

- `POST /config/save` - Save encrypted configuration
- `GET /config/load` - Load configuration (non-sensitive data)

## Security

All sensitive data is encrypted using:

- **PBKDF2** key derivation function
- **Fernet** symmetric encryption (AES-128-CBC)
- **Random salt** for each encrypted value
- **Password-based encryption** using the same password as LND wallet unlock

## Usage

### Initial Setup

1. Navigate to TRON page in BRLN-OS interface
2. Go to "API Configuration" section
3. Enter your TronGrid API key (get free key at https://www.trongrid.io)
4. Enter your Gas-Free API credentials
5. Enter your wallet password
6. Click "Save Configuration"

### Sending USDT

1. Enter recipient TRON address (starts with 'T')
2. Enter amount (minimum 1.01 USDT)
   - 1 USDT goes to gas-free fee
   - Remaining amount goes to recipient
3. Enter wallet password
4. Click "Send USDT"
5. Confirm transaction

### Viewing Transactions

- Transaction history automatically loads on page load
- Shows last 30 transactions
- Click "🔄 Refresh History" to update

## Gas-Free Protocol

The gas-free protocol allows USDT transfers without TRX:

1. User creates unsigned USDT transfer transaction
2. Transaction is signed with gas-free protocol signature
3. Gas-free provider covers the TRX network fees
4. User pays 1 USDT to gas-free service provider
5. Transaction is broadcast to TRON network

### Benefits

- No need to hold TRX for gas
- Predictable fixed fees (1 USDT)
- Simpler user experience
- Automatic fee handling

## Development

### TypeScript Services

The `application/services/` directory contains:

- `tron-wallet-application.service.ts` - Wallet operations
- `tron-transaction-application.service.ts` - Transaction management
- `tron-network-application.service.ts` - Network interactions
- `tron-gasfree-application.service.ts` - Gas-free protocol integration

### Domain Services

The `domain/services/` directory contains:

- `tron-network.service.ts` - Network business logic
- `tron-validation.service.ts` - Address and transaction validation
- `usdt-transfer.service.ts` - USDT transfer logic
- `tron-gasfree.service.ts` - Gas-free protocol logic

### Testing

Run tests with:

```bash
npm test -- tron
```

Test files include:

- `tron-network.service.spec.ts`
- `tron-validation.service.spec.ts`
- `usdt-transfer.service.spec.ts`
- `tron-gasfree-real-integration.spec.ts`

## Troubleshooting

### "TRON wallet not configured"

- Ensure you've saved configuration in the settings
- Check that wallet address is derived from system seed phrase

### "Invalid password or decryption failed"

- Password must match the password used for LND wallet unlock
- Password is used to decrypt private keys

### "Failed to load balance"

- Check TronGrid API key is valid
- Verify network connectivity
- Ensure API URL is correct

### "Transaction failed"

- Ensure sufficient USDT balance (amount + 1 USDT fee)
- Verify recipient address is valid TRON address
- Check gas-free API credentials are correct

## References

- [TRON Documentation](https://developers.tron.network/)
- [TronGrid API](https://www.trongrid.io)
- [Gas-Free Protocol](https://www.gasfree.io)
- [USDT TRC20 Contract](https://tronscan.org/#/token20/TR7NHqjeKQxGTCi8z8ZY4pL8otSzgjLj6t)

## License

Same as BRLN-OS main project license.
