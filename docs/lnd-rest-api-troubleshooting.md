# LND REST API Troubleshooting Guide

## Problem: 400 Bad Request when creating onchain addresses via SATSCAPITAL tunnel

### Initial Issue
We were experiencing `400 Bad Request` errors when trying to create onchain addresses through the LND REST API, both locally and through the SATSCAPITAL tunnel URL (`satscapital.pagcoin.org`).

### Environment
- **System**: Linux (Ubuntu/Debian)
- **LND Node**: Running via Docker containers
- **Tunnel**: Cloudflare tunnel configured for `satscapital.pagcoin.org`
- **Local API**: `https://localhost:8080`
- **Target Endpoint**: `/v1/newaddress`

### Research Process

#### 1. API Documentation Review
We researched the official Lightning Labs API documentation at:
- https://lightning.engineering/api-docs/api/lnd/lightning/new-address
- https://lightning.engineering/api-docs/api/lnd/rest-endpoints/

**Key Findings:**
- The `/v1/newaddress` endpoint should use `GET` method (not POST)
- Authentication requires `Grpc-Metadata-macaroon` header
- No request body needed for basic address generation

#### 2. Authentication Format Investigation
The documentation revealed that:
- Macaroon must be hex-encoded
- Header format: `Grpc-Metadata-macaroon: [hex-encoded-macaroon]`
- Line breaks in the macaroon string cause authentication failures

### Root Cause Analysis

The 400 Bad Request errors were caused by:

1. **Incorrect HTTP Method**: Initially using `POST` instead of `GET`
2. **Malformed Macaroon Header**: Line breaks in the hex-encoded macaroon string
3. **Authentication Header Format**: Inconsistent formatting of the macaroon

### Solution Implementation

#### Step 1: Extract and Format Macaroon Properly
```bash
# Convert macaroon to properly formatted hex string
MACAROON=$(xxd -ps -u -c 1000 admin.macaroon)

# Verify the macaroon is stored correctly (no line breaks)
echo $MACAROON
```

#### Step 2: Use Correct HTTP Method and Headers
```bash
# Correct format - GET method with proper headers
curl -k -X GET \
  -H "Grpc-Metadata-macaroon: $MACAROON" \
  "https://localhost:8080/v1/newaddress"
```

#### Step 3: Test Through Tunnel
```bash
# Test through SATSCAPITAL tunnel
curl -k -X GET \
  -H "Grpc-Metadata-macaroon: $MACAROON" \
  "https://satscapital.pagcoin.org/v1/newaddress"
```

### Results

#### Local Endpoint Test
**Request:**
```bash
curl -k -X GET \
  -H "Grpc-Metadata-macaroon: $MACAROON" \
  "https://localhost:8080/v1/newaddress"
```

**Response:**
```json
{"address":"bc1q75qmdelhet5rr3fppvhtqvyr6n64zatq30sfhm"}
```
✅ **SUCCESS**

#### SATSCAPITAL Tunnel Test
**Request:**
```bash
curl -k -X GET \
  -H "Grpc-Metadata-macaroon: $MACAROON" \
  "https://satscapital.pagcoin.org/v1/newaddress"
```

**Response:**
```json
{"address":"bc1q98mg44nf2fymls504wxrchyxukhrnqlspk6arn"}
```
✅ **SUCCESS**

### Key Learnings

1. **HTTP Method Matters**: LND REST API `/v1/newaddress` requires `GET`, not `POST`

2. **Macaroon Formatting is Critical**: 
   - Must be continuous hex string without line breaks
   - Use `xxd -ps -u -c 1000` to ensure proper formatting
   - Store in variable to avoid shell line-wrapping issues

3. **Header Format**: 
   - Use `Grpc-Metadata-macaroon` (not just `macaroon`)
   - Ensure no extra spaces or formatting issues

4. **Tunnel Configuration**: 
   - Cloudflare tunnel properly forwards requests when configured correctly
   - SSL/TLS termination works correctly through the tunnel

### Best Practices for LND REST API

#### Macaroon Handling
```bash
# Always extract macaroon to variable first
MACAROON=$(xxd -ps -u -c 1000 /path/to/admin.macaroon)

# Verify macaroon format before use
echo "Macaroon length: ${#MACAROON}"
```

#### Request Templates

**Get Node Info:**
```bash
curl -k -X GET \
  -H "Grpc-Metadata-macaroon: $MACAROON" \
  "https://satscapital.pagcoin.org/v1/getinfo"
```

**Create New Address:**
```bash
curl -k -X GET \
  -H "Grpc-Metadata-macaroon: $MACAROON" \
  "https://satscapital.pagcoin.org/v1/newaddress"
```

**Create Address with Specific Type:**
```bash
curl -k -X GET \
  -H "Grpc-Metadata-macaroon: $MACAROON" \
  "https://satscapital.pagcoin.org/v1/newaddress?type=0"
```

### Address Types Reference
- `0`: WITNESS_PUBKEY_HASH (bech32, starts with bc1)
- `1`: NESTED_PUBKEY_HASH (P2SH-wrapped SegWit)
- `2`: UNUSED_WITNESS_PUBKEY_HASH
- `3`: UNUSED_NESTED_PUBKEY_HASH
- `4`: TAPROOT_PUBKEY
- `5`: UNUSED_TAPROOT_PUBKEY

### Troubleshooting Checklist

When experiencing API issues:

- [ ] Verify LND service is running
- [ ] Check macaroon file exists and is readable
- [ ] Ensure macaroon is properly hex-encoded without line breaks
- [ ] Use correct HTTP method (GET for newaddress)
- [ ] Verify header format: `Grpc-Metadata-macaroon`
- [ ] Test locally first, then through tunnel
- [ ] Check tunnel configuration and status
- [ ] Verify SSL certificates are working

### Related Files
- **Tunnel Config**: `/home/pagcoin/brln-os/cloudflare-tunnel.yml`
- **LND Config**: `/home/pagcoin/brln-os/container/nodes/lnd/lnd.conf`
- **Macaroon**: `/home/pagcoin/brln-os/admin.macaroon`
- **TLS Cert**: `/home/pagcoin/brln-os/tls.cert`

---

**Date**: August 27, 2025  
**Status**: ✅ Resolved  
**Tested Endpoints**: 
- Local: `https://localhost:8080`
- Tunnel: `https://satscapital.pagcoin.org`

**Generated Addresses**:
- Local test: `bc1q75qmdelhet5rr3fppvhtqvyr6n64zatq30sfhm`
- Tunnel test: `bc1q98mg44nf2fymls504wxrchyxukhrnqlspk6arn`
