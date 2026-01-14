"""
Extended LND gRPC client for atomic swap operations.

This module extends the existing LNDgRPCClient from api/v1/app.py with
additional methods required for atomic swaps:
- Creating invoices with custom payment hashes
- Looking up invoices by payment hash
- Subscribing to invoice updates (streaming)
- Decoding payment requests

Reuses all existing connection management, authentication, and basic operations.
"""

import sys
import os
import logging
from typing import Optional, Dict, Any, AsyncIterator

# Add parent directory to path to import from api.v1
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

# Import the existing LND client from app.py
from api.v1.app import LNDgRPCClient

# Import gRPC proto modules (same as app.py)
try:
    import lightning_pb2 as lnrpc
    import lightning_pb2_grpc as lnrpcstub
except ImportError:
    lnrpc = None
    lnrpcstub = None

try:
    import grpc
except ImportError:
    grpc = None

logger = logging.getLogger(__name__)


class AtomicSwapLNDClient(LNDgRPCClient):
    """
    Extended LND client with atomic swap functionality.

    Inherits all methods from LNDgRPCClient and adds:
    - create_invoice_with_hash() - Create invoice with custom payment hash
    - lookup_invoice() - Look up invoice by payment hash
    - subscribe_invoice() - Subscribe to single invoice updates
    - decode_payment_request() - Decode bolt11 payment request
    - get_payment_preimage() - Extract preimage from paid invoice
    """

    def __init__(self):
        """Initialize by calling parent constructor."""
        super().__init__()
        logger.info("AtomicSwapLNDClient initialized")

    def create_invoice_with_hash(
        self,
        payment_hash: bytes,
        amount_sat: int,
        memo: str = "Atomic Swap",
        expiry: int = 3600,
        private: bool = False
    ) -> tuple[Optional[Dict[str, Any]], Optional[str]]:
        """
        Create a Lightning invoice with a specific payment hash.

        This is critical for atomic swaps: we generate the preimage,
        compute the payment_hash, and create an invoice that can only
        be claimed by revealing the preimage.

        Args:
            payment_hash: 32-byte payment hash (SHA256 of preimage)
            amount_sat: Invoice amount in satoshis
            memo: Invoice description
            expiry: Expiry time in seconds (default 1 hour)
            private: Whether to make invoice private (no route hints)

        Returns:
            Tuple of (invoice_data, error_message)
            invoice_data contains:
                - payment_request: bolt11 payment request string
                - payment_hash: hex-encoded payment hash
                - add_index: invoice index
                - expiry: expiry timestamp
        """
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error

            if not lnrpc:
                return None, "gRPC modules not available"

            # Create invoice with specific payment hash
            request = lnrpc.Invoice()
            request.r_hash = payment_hash
            request.value = int(amount_sat)
            request.memo = memo
            request.expiry = int(expiry)
            request.private = private

            response = self.stub.AddInvoice(request, timeout=10)

            result = {
                'payment_request': response.payment_request,
                'payment_hash': payment_hash.hex(),
                'add_index': str(response.add_index),
                'expiry': expiry
            }

            logger.info(f"Created invoice with custom hash: {payment_hash.hex()[:16]}...")
            return result, None

        except grpc.RpcError as e:
            self._connected = False
            error_msg = f"gRPC Error creating invoice: {e.details()}"
            logger.error(error_msg)
            return None, error_msg
        except Exception as e:
            error_msg = f"Error creating invoice with hash: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg

    def lookup_invoice(
        self,
        payment_hash: bytes
    ) -> tuple[Optional[Dict[str, Any]], Optional[str]]:
        """
        Look up an invoice by its payment hash.

        Args:
            payment_hash: 32-byte payment hash

        Returns:
            Tuple of (invoice_data, error_message)
            invoice_data contains:
                - state: Invoice state (OPEN, SETTLED, CANCELED, ACCEPTED)
                - settled: Whether invoice is settled
                - payment_request: bolt11 string
                - r_preimage: Preimage (if settled)
                - value: Amount in satoshis
                - creation_date: Unix timestamp
                - settle_date: Unix timestamp (if settled)
                - amt_paid: Amount actually paid
        """
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error

            if not lnrpc:
                return None, "gRPC modules not available"

            request = lnrpc.PaymentHash()
            request.r_hash = payment_hash

            response = self.stub.LookupInvoice(request, timeout=10)

            # Map invoice state enum to string
            state_map = {
                0: 'OPEN',
                1: 'SETTLED',
                2: 'CANCELED',
                3: 'ACCEPTED'
            }

            result = {
                'state': state_map.get(response.state, 'UNKNOWN'),
                'settled': response.settled,
                'payment_request': response.payment_request,
                'r_preimage': response.r_preimage.hex() if response.r_preimage else None,
                'r_hash': payment_hash.hex(),
                'value': str(response.value),
                'value_msat': str(response.value_msat),
                'creation_date': str(response.creation_date),
                'settle_date': str(response.settle_date) if response.settle_date else None,
                'amt_paid': str(response.amt_paid),
                'amt_paid_sat': str(response.amt_paid_sat),
                'amt_paid_msat': str(response.amt_paid_msat),
                'memo': response.memo,
                'is_keysend': response.is_keysend,
                'expiry': str(response.expiry)
            }

            logger.debug(f"Looked up invoice: {payment_hash.hex()[:16]}... state={result['state']}")
            return result, None

        except grpc.RpcError as e:
            self._connected = False
            error_msg = f"gRPC Error looking up invoice: {e.details()}"
            logger.error(error_msg)
            return None, error_msg
        except Exception as e:
            error_msg = f"Error looking up invoice: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg

    def subscribe_invoice(
        self,
        payment_hash: bytes,
        timeout: int = 3600
    ) -> tuple[Optional[Any], Optional[str]]:
        """
        Subscribe to updates for a specific invoice (streaming).

        Returns a gRPC streaming response that yields invoice updates
        as they occur (e.g., when invoice is paid).

        Args:
            payment_hash: 32-byte payment hash to monitor
            timeout: Maximum time to wait for updates (seconds)

        Returns:
            Tuple of (stream_iterator, error_message)

        Usage:
            stream, error = client.subscribe_invoice(payment_hash)
            if not error:
                for invoice_update in stream:
                    if invoice_update.settled:
                        preimage = invoice_update.r_preimage
                        break
        """
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error

            if not lnrpc:
                return None, "gRPC modules not available"

            # Subscribe to all invoices, then filter (LND doesn't support single invoice subscription)
            request = lnrpc.InvoiceSubscription()
            request.add_index = 0  # Start from beginning
            request.settle_index = 0

            # Start streaming
            stream = self.stub.SubscribeInvoices(request, timeout=timeout)

            logger.info(f"Subscribed to invoice updates for {payment_hash.hex()[:16]}...")
            return stream, None

        except grpc.RpcError as e:
            self._connected = False
            error_msg = f"gRPC Error subscribing to invoice: {e.details()}"
            logger.error(error_msg)
            return None, error_msg
        except Exception as e:
            error_msg = f"Error subscribing to invoice: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg

    def decode_payment_request(
        self,
        payment_request: str
    ) -> tuple[Optional[Dict[str, Any]], Optional[str]]:
        """
        Decode a bolt11 payment request.

        Extracts information from the encoded payment request including
        payment hash, amount, description, expiry, etc.

        Args:
            payment_request: bolt11 encoded payment request string

        Returns:
            Tuple of (decoded_data, error_message)
            decoded_data contains:
                - payment_hash: Hex-encoded payment hash
                - destination: Destination pubkey
                - num_satoshis: Amount in satoshis
                - timestamp: Creation timestamp
                - expiry: Expiry in seconds
                - description: Invoice description
                - cltv_expiry: CLTV expiry delta
        """
        try:
            success, error = self.ensure_connected()
            if not success:
                return None, error

            if not lnrpc:
                return None, "gRPC modules not available"

            request = lnrpc.PayReqString()
            request.pay_req = payment_request

            response = self.stub.DecodePayReq(request, timeout=10)

            result = {
                'payment_hash': response.payment_hash,
                'destination': response.destination,
                'num_satoshis': str(response.num_satoshis),
                'timestamp': str(response.timestamp),
                'expiry': str(response.expiry),
                'description': response.description,
                'description_hash': response.description_hash,
                'fallback_addr': response.fallback_addr,
                'cltv_expiry': str(response.cltv_expiry),
                'num_msat': str(response.num_msat)
            }

            logger.debug(f"Decoded payment request: hash={result['payment_hash'][:16]}...")
            return result, None

        except grpc.RpcError as e:
            self._connected = False
            error_msg = f"gRPC Error decoding payment request: {e.details()}"
            logger.error(error_msg)
            return None, error_msg
        except Exception as e:
            error_msg = f"Error decoding payment request: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg

    def get_payment_preimage(
        self,
        payment_hash: bytes
    ) -> tuple[Optional[bytes], Optional[str]]:
        """
        Get the preimage for a settled invoice.

        This is the critical piece for atomic swaps: once the invoice is paid,
        the preimage is revealed and can be used to claim the on-chain HTLC.

        Args:
            payment_hash: 32-byte payment hash

        Returns:
            Tuple of (preimage_bytes, error_message)
        """
        try:
            invoice_data, error = self.lookup_invoice(payment_hash)
            if error:
                return None, error

            if not invoice_data.get('settled'):
                return None, "Invoice not yet settled"

            preimage_hex = invoice_data.get('r_preimage')
            if not preimage_hex:
                return None, "Preimage not available in invoice data"

            preimage_bytes = bytes.fromhex(preimage_hex)

            logger.info(f"Retrieved preimage for payment_hash {payment_hash.hex()[:16]}...")
            return preimage_bytes, None

        except Exception as e:
            error_msg = f"Error getting payment preimage: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg

    def wait_for_invoice_settlement(
        self,
        payment_hash: bytes,
        timeout: int = 3600,
        poll_interval: int = 2
    ) -> tuple[Optional[bytes], Optional[str]]:
        """
        Wait for an invoice to be settled and return the preimage.

        This is a blocking call that polls the invoice until it's settled
        or the timeout expires.

        Args:
            payment_hash: 32-byte payment hash to monitor
            timeout: Maximum time to wait (seconds)
            poll_interval: How often to poll (seconds)

        Returns:
            Tuple of (preimage_bytes, error_message)
        """
        import time

        start_time = time.time()

        while time.time() - start_time < timeout:
            invoice_data, error = self.lookup_invoice(payment_hash)

            if error:
                logger.warning(f"Error looking up invoice: {error}")
                time.sleep(poll_interval)
                continue

            if invoice_data.get('settled'):
                preimage_hex = invoice_data.get('r_preimage')
                if preimage_hex:
                    preimage_bytes = bytes.fromhex(preimage_hex)
                    logger.info(f"Invoice settled! Preimage retrieved: {payment_hash.hex()[:16]}...")
                    return preimage_bytes, None

            # Check if invoice was canceled
            if invoice_data.get('state') == 'CANCELED':
                return None, "Invoice was canceled"

            time.sleep(poll_interval)

        return None, f"Timeout waiting for invoice settlement ({timeout}s)"

    def close(self):
        """Close the gRPC channel."""
        if self.channel:
            self.channel.close()
            self._connected = False
            logger.info("LND gRPC channel closed")


# Convenience function to get a singleton client
_client_instance = None

def get_lnd_client() -> AtomicSwapLNDClient:
    """
    Get or create the global LND client instance.

    Returns:
        AtomicSwapLNDClient instance
    """
    global _client_instance
    if _client_instance is None:
        _client_instance = AtomicSwapLNDClient()
    return _client_instance
