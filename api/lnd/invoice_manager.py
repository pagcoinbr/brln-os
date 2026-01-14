"""
Invoice Manager for Atomic Swaps.

High-level invoice management that abstracts away gRPC details and provides
a clean interface for atomic swap operations.

Key responsibilities:
- Create invoices with custom payment hashes for atomic swaps
- Monitor invoice payment status
- Extract preimages from settled invoices
- Handle invoice expiry and cancellation
"""

import logging
import hashlib
from typing import Optional, Dict, Any, Tuple
from datetime import datetime, timedelta

from api.lnd.client import get_lnd_client, AtomicSwapLNDClient

logger = logging.getLogger(__name__)


class InvoiceManager:
    """
    High-level invoice manager for atomic swaps.

    Provides simplified interface for:
    - Creating swap invoices with specific payment hashes
    - Monitoring invoice settlement
    - Extracting preimages when invoices are paid
    """

    def __init__(self, lnd_client: Optional[AtomicSwapLNDClient] = None):
        """
        Initialize invoice manager.

        Args:
            lnd_client: Optional LND client (uses singleton if not provided)
        """
        self.lnd_client = lnd_client or get_lnd_client()
        logger.info("InvoiceManager initialized")

    def create_swap_invoice(
        self,
        preimage: bytes,
        amount_sat: int,
        memo: str = "Atomic Swap",
        expiry_seconds: int = 3600
    ) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
        """
        Create a Lightning invoice for an atomic swap.

        The preimage is provided by the swap initiator, and the invoice
        can only be settled by revealing this preimage.

        Args:
            preimage: 32-byte preimage (secret)
            amount_sat: Invoice amount in satoshis
            memo: Invoice description
            expiry_seconds: Time until invoice expires (default: 1 hour)

        Returns:
            Tuple of (invoice_info, error_message)
            invoice_info contains:
                - payment_request: bolt11 payment request string
                - payment_hash: Hex-encoded payment hash
                - amount_sat: Amount in satoshis
                - expires_at: ISO datetime when invoice expires
                - memo: Invoice description
        """
        try:
            # Validate preimage length
            if len(preimage) != 32:
                return None, f"Invalid preimage length: {len(preimage)} (expected 32 bytes)"

            # Compute payment hash
            payment_hash = hashlib.sha256(preimage).digest()

            # Create invoice with custom payment hash
            invoice_data, error = self.lnd_client.create_invoice_with_hash(
                payment_hash=payment_hash,
                amount_sat=amount_sat,
                memo=memo,
                expiry=expiry_seconds,
                private=False
            )

            if error:
                return None, error

            # Calculate expiry datetime
            expires_at = datetime.utcnow() + timedelta(seconds=expiry_seconds)

            result = {
                'payment_request': invoice_data['payment_request'],
                'payment_hash': invoice_data['payment_hash'],
                'amount_sat': amount_sat,
                'expires_at': expires_at.isoformat(),
                'expiry_seconds': expiry_seconds,
                'memo': memo,
                'created_at': datetime.utcnow().isoformat()
            }

            logger.info(
                f"Created swap invoice: amount={amount_sat} sat, "
                f"hash={payment_hash.hex()[:16]}..., expires_in={expiry_seconds}s"
            )
            return result, None

        except Exception as e:
            error_msg = f"Error creating swap invoice: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg

    def check_invoice_status(
        self,
        payment_hash: str
    ) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
        """
        Check the current status of an invoice.

        Args:
            payment_hash: Hex-encoded payment hash

        Returns:
            Tuple of (status_info, error_message)
            status_info contains:
                - state: OPEN, SETTLED, CANCELED, ACCEPTED
                - settled: Boolean
                - preimage: Hex-encoded preimage (if settled)
                - amount_paid: Amount actually paid (if settled)
                - settled_at: ISO datetime when settled
        """
        try:
            payment_hash_bytes = bytes.fromhex(payment_hash)

            invoice_data, error = self.lnd_client.lookup_invoice(payment_hash_bytes)
            if error:
                return None, error

            result = {
                'state': invoice_data['state'],
                'settled': invoice_data['settled'],
                'payment_hash': payment_hash,
                'preimage': invoice_data.get('r_preimage'),
                'amount_sat': invoice_data.get('value'),
                'amount_paid_sat': invoice_data.get('amt_paid_sat'),
                'created_at': invoice_data.get('creation_date'),
                'settled_at': invoice_data.get('settle_date'),
                'memo': invoice_data.get('memo'),
                'expiry': invoice_data.get('expiry')
            }

            logger.debug(f"Invoice status: {payment_hash[:16]}... state={result['state']}")
            return result, None

        except ValueError as e:
            return None, f"Invalid payment_hash format: {str(e)}"
        except Exception as e:
            error_msg = f"Error checking invoice status: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg

    def wait_for_payment(
        self,
        payment_hash: str,
        timeout_seconds: int = 3600,
        poll_interval: int = 2
    ) -> Tuple[Optional[str], Optional[str]]:
        """
        Wait for an invoice to be paid and extract the preimage.

        This is the critical operation for atomic swaps: once the Lightning
        invoice is paid, the preimage is revealed and can be used to claim
        the on-chain HTLC.

        Args:
            payment_hash: Hex-encoded payment hash
            timeout_seconds: Maximum time to wait (default: 1 hour)
            poll_interval: How often to check status (default: 2 seconds)

        Returns:
            Tuple of (preimage_hex, error_message)
        """
        try:
            payment_hash_bytes = bytes.fromhex(payment_hash)

            logger.info(
                f"Waiting for invoice payment: {payment_hash[:16]}... "
                f"(timeout={timeout_seconds}s)"
            )

            preimage_bytes, error = self.lnd_client.wait_for_invoice_settlement(
                payment_hash=payment_hash_bytes,
                timeout=timeout_seconds,
                poll_interval=poll_interval
            )

            if error:
                return None, error

            preimage_hex = preimage_bytes.hex()
            logger.info(f"Invoice paid! Preimage: {preimage_hex[:16]}...")
            return preimage_hex, None

        except ValueError as e:
            return None, f"Invalid payment_hash format: {str(e)}"
        except Exception as e:
            error_msg = f"Error waiting for payment: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg

    def verify_preimage(
        self,
        preimage: str,
        payment_hash: str
    ) -> bool:
        """
        Verify that a preimage matches a payment hash.

        Args:
            preimage: Hex-encoded preimage
            payment_hash: Hex-encoded payment hash

        Returns:
            True if preimage is valid for the payment hash
        """
        try:
            preimage_bytes = bytes.fromhex(preimage)
            payment_hash_bytes = bytes.fromhex(payment_hash)

            computed_hash = hashlib.sha256(preimage_bytes).digest()

            is_valid = computed_hash == payment_hash_bytes

            if is_valid:
                logger.debug(f"Preimage verified: {preimage[:16]}...")
            else:
                logger.warning(f"Invalid preimage for hash {payment_hash[:16]}...")

            return is_valid

        except ValueError as e:
            logger.error(f"Invalid hex format: {str(e)}")
            return False
        except Exception as e:
            logger.error(f"Error verifying preimage: {str(e)}", exc_info=True)
            return False

    def decode_invoice(
        self,
        payment_request: str
    ) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
        """
        Decode a bolt11 payment request.

        Useful for validating incoming payment requests before paying them.

        Args:
            payment_request: bolt11 encoded string

        Returns:
            Tuple of (decoded_info, error_message)
            decoded_info contains:
                - payment_hash: Hex-encoded payment hash
                - amount_sat: Amount in satoshis
                - description: Invoice description
                - expiry: Expiry in seconds
                - destination: Recipient pubkey
        """
        try:
            decoded_data, error = self.lnd_client.decode_payment_request(payment_request)
            if error:
                return None, error

            result = {
                'payment_hash': decoded_data['payment_hash'],
                'amount_sat': decoded_data['num_satoshis'],
                'description': decoded_data.get('description', ''),
                'expiry': decoded_data['expiry'],
                'destination': decoded_data['destination'],
                'timestamp': decoded_data['timestamp'],
                'cltv_expiry': decoded_data['cltv_expiry']
            }

            logger.debug(
                f"Decoded invoice: hash={result['payment_hash'][:16]}..., "
                f"amount={result['amount_sat']} sat"
            )
            return result, None

        except Exception as e:
            error_msg = f"Error decoding invoice: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg

    def get_invoice_expiry_time(
        self,
        payment_hash: str
    ) -> Tuple[Optional[datetime], Optional[str]]:
        """
        Get the expiry time for an invoice.

        Args:
            payment_hash: Hex-encoded payment hash

        Returns:
            Tuple of (expiry_datetime, error_message)
        """
        try:
            status_info, error = self.check_invoice_status(payment_hash)
            if error:
                return None, error

            creation_timestamp = int(status_info.get('created_at', 0))
            expiry_seconds = int(status_info.get('expiry', 0))

            if creation_timestamp == 0:
                return None, "Invoice creation timestamp not available"

            expiry_time = datetime.fromtimestamp(creation_timestamp + expiry_seconds)

            return expiry_time, None

        except Exception as e:
            error_msg = f"Error getting invoice expiry: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg

    def is_invoice_expired(
        self,
        payment_hash: str
    ) -> Tuple[Optional[bool], Optional[str]]:
        """
        Check if an invoice has expired.

        Args:
            payment_hash: Hex-encoded payment hash

        Returns:
            Tuple of (is_expired, error_message)
        """
        try:
            expiry_time, error = self.get_invoice_expiry_time(payment_hash)
            if error:
                return None, error

            is_expired = datetime.utcnow() > expiry_time

            logger.debug(
                f"Invoice {payment_hash[:16]}... "
                f"{'expired' if is_expired else 'still valid'}"
            )

            return is_expired, None

        except Exception as e:
            error_msg = f"Error checking invoice expiry: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return None, error_msg


# Convenience function to get a singleton invoice manager
_invoice_manager_instance = None

def get_invoice_manager() -> InvoiceManager:
    """
    Get or create the global invoice manager instance.

    Returns:
        InvoiceManager instance
    """
    global _invoice_manager_instance
    if _invoice_manager_instance is None:
        _invoice_manager_instance = InvoiceManager()
    return _invoice_manager_instance
