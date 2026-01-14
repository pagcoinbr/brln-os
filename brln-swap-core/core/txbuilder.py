"""
BRLN-OS Atomic Swap Module - Transaction Builder

This module constructs, signs, and broadcasts Bitcoin/Liquid transactions for HTLC atomic swaps.
Uses python-bitcoinlib for transaction construction and ElementsRPCClient for signing/broadcasting.

Transaction Types:
1. Funding Transaction - Sends funds to HTLC P2WSH address
2. Claim Transaction - Spends HTLC with preimage reveal (receiver)
3. Refund Transaction - Spends HTLC after timeout (sender)

Security Requirements:
- All inputs must be validated before transaction construction
- Preimage must be provided in witness for claim transactions
- Sequence numbers must be set correctly for OP_CHECKSEQUENCEVERIFY
- Fee estimation must prevent stuck transactions

References:
- BIP141 (Segwit): https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki
- BIP143 (Segwit signing): https://github.com/bitcoin/bips/blob/master/bip-0143.mediawiki
- BIP68 (Relative timelocks): https://github.com/bitcoin/bips/blob/master/bip-0068.mediawiki
"""

from typing import List, Tuple, Optional, Dict, Any
from dataclasses import dataclass
import logging

# Bitcoin library imports
try:
    from bitcoin.core import (
        CTransaction, CTxIn, CTxOut, COutPoint,
        CMutableTransaction, CMutableTxIn, CMutableTxOut,
        COIN, lx, b2x, x
    )
    from bitcoin.core.script import CScript, SIGHASH_ALL, SignatureHash
    from bitcoin.wallet import P2WSHBitcoinAddress
    BITCOIN_LIB_AVAILABLE = True
except ImportError:
    BITCOIN_LIB_AVAILABLE = False
    logging.warning("python-bitcoinlib not installed")

# Import from other brln-swap-core modules
from .htlc import HTLC, HTLCScript
from .scriptbuilder import HTLCScriptBuilder

# Configure logging
logger = logging.getLogger(__name__)


@dataclass
class UTXO:
    """
    Unspent Transaction Output.

    Attributes:
        txid: Transaction ID (hex string)
        vout: Output index
        amount_sats: Amount in satoshis
        script_pubkey: ScriptPubKey (hex string)
        confirmations: Number of confirmations
    """
    txid: str
    vout: int
    amount_sats: int
    script_pubkey: str
    confirmations: int = 0

    def to_outpoint(self) -> 'COutPoint':
        """Convert to COutPoint for transaction input."""
        if not BITCOIN_LIB_AVAILABLE:
            raise ImportError("python-bitcoinlib required")
        return COutPoint(lx(self.txid), self.vout)


@dataclass
class TransactionResult:
    """
    Result of transaction building/broadcasting.

    Attributes:
        success: Whether operation succeeded
        tx_hex: Transaction hex (if successful)
        txid: Transaction ID (if broadcast)
        error: Error message (if failed)
    """
    success: bool
    tx_hex: Optional[str] = None
    txid: Optional[str] = None
    error: Optional[str] = None


class BitcoinTransactionBuilder:
    """
    Builder for Bitcoin/Liquid transactions related to HTLC atomic swaps.

    Handles construction of funding, claim, and refund transactions.
    """

    def __init__(self, elements_rpc_client=None):
        """
        Initialize transaction builder.

        Args:
            elements_rpc_client: ElementsRPCClient instance for signing/broadcasting
        """
        if not BITCOIN_LIB_AVAILABLE:
            raise ImportError(
                "python-bitcoinlib required for BitcoinTransactionBuilder. "
                "Install with: pip install python-bitcoinlib"
            )

        self.elements_client = elements_rpc_client
        logger.debug("BitcoinTransactionBuilder initialized")

    def build_htlc_funding_tx(
        self,
        htlc: HTLC,
        utxos: List[UTXO],
        change_address: str,
        fee_rate_sat_per_vbyte: int = 10
    ) -> TransactionResult:
        """
        Build transaction to fund an HTLC.

        Creates a transaction that sends funds to the HTLC P2WSH address.

        Args:
            htlc: HTLC instance to fund
            utxos: List of UTXOs to use as inputs
            change_address: Address for change output
            fee_rate_sat_per_vbyte: Fee rate in sat/vByte

        Returns:
            TransactionResult with transaction hex

        Example:
            >>> builder = BitcoinTransactionBuilder()
            >>> result = builder.build_htlc_funding_tx(htlc, utxos, change_addr)
            >>> print(result.tx_hex)
        """
        try:
            # Validate inputs
            if not utxos:
                return TransactionResult(
                    success=False,
                    error="No UTXOs provided"
                )

            # Calculate total input amount
            total_input = sum(utxo.amount_sats for utxo in utxos)
            htlc_amount = htlc.parameters.amount_sats

            # Estimate transaction size (rough estimate)
            # Input: ~148 vBytes per P2WPKH input
            # Output: ~31 vBytes per P2WSH output, ~31 for P2WPKH change
            estimated_size = len(utxos) * 148 + 31 + 31 + 10  # +10 for overhead
            estimated_fee = estimated_size * fee_rate_sat_per_vbyte

            # Check if we have enough funds
            if total_input < htlc_amount + estimated_fee:
                return TransactionResult(
                    success=False,
                    error=f"Insufficient funds: need {htlc_amount + estimated_fee} sats, "
                           f"have {total_input} sats"
                )

            # Build transaction inputs
            tx_inputs = []
            for utxo in utxos:
                tx_in = CMutableTxIn(utxo.to_outpoint())
                tx_inputs.append(tx_in)

            # Get HTLC address
            htlc_address = htlc.get_address()

            # Build transaction outputs
            tx_outputs = []

            # HTLC output
            htlc_script_pubkey = P2WSHBitcoinAddress(htlc_address).to_scriptPubKey()
            htlc_output = CMutableTxOut(htlc_amount, htlc_script_pubkey)
            tx_outputs.append(htlc_output)

            # Change output
            change_amount = total_input - htlc_amount - estimated_fee
            if change_amount > 546:  # Dust limit
                # Note: Would need to parse change_address properly
                # For now, assume it's already a script
                change_output = CMutableTxOut(change_amount, CScript())
                tx_outputs.append(change_output)
                logger.debug(f"Adding change output: {change_amount} sats")
            else:
                logger.debug(f"Change amount {change_amount} below dust, adding to fee")

            # Create transaction
            tx = CMutableTransaction(tx_inputs, tx_outputs)

            # Convert to hex
            tx_hex = b2x(tx.serialize())

            logger.info(
                f"Built HTLC funding transaction: "
                f"{len(utxos)} inputs, {len(tx_outputs)} outputs, "
                f"amount={htlc_amount} sats, fee={estimated_fee} sats"
            )

            return TransactionResult(
                success=True,
                tx_hex=tx_hex
            )

        except Exception as e:
            logger.error(f"Error building HTLC funding transaction: {e}")
            return TransactionResult(
                success=False,
                error=str(e)
            )

    def build_claim_tx(
        self,
        htlc: HTLC,
        htlc_utxo: UTXO,
        preimage: bytes,
        destination_address: str,
        fee_sats: int = 1000
    ) -> TransactionResult:
        """
        Build transaction to claim HTLC with preimage.

        Creates a transaction that spends the HTLC by providing the preimage
        and receiver's signature.

        Args:
            htlc: HTLC instance
            htlc_utxo: UTXO of the funded HTLC
            preimage: 32-byte preimage that hashes to payment_hash
            destination_address: Address to send claimed funds
            fee_sats: Transaction fee in satoshis

        Returns:
            TransactionResult with transaction hex

        Note:
            This transaction requires witness data:
            - Receiver's signature
            - Preimage
            - Witness script (HTLC script)
        """
        try:
            # Validate preimage
            can_claim, msg = htlc.can_claim(preimage)
            if not can_claim:
                return TransactionResult(
                    success=False,
                    error=f"Cannot claim HTLC: {msg}"
                )

            # Build transaction input
            # Set sequence to 0xfffffffe (enables relative timelock but doesn't trigger it)
            tx_in = CMutableTxIn(
                htlc_utxo.to_outpoint(),
                nSequence=0xfffffffe
            )

            # Build transaction output
            output_amount = htlc_utxo.amount_sats - fee_sats
            if output_amount <= 546:  # Dust limit
                return TransactionResult(
                    success=False,
                    error=f"Output amount {output_amount} below dust limit"
                )

            # Note: Would need to parse destination_address properly
            # For now, assume it's already a script
            tx_out = CMutableTxOut(output_amount, CScript())

            # Create transaction
            tx = CMutableTransaction([tx_in], [tx_out])

            # For witness transactions, we need to build the witness stack:
            # [receiver_sig] [preimage] [1] [witness_script]
            # The actual signing would be done via RPC

            tx_hex = b2x(tx.serialize())

            logger.info(
                f"Built HTLC claim transaction: "
                f"amount={output_amount} sats, fee={fee_sats} sats"
            )

            return TransactionResult(
                success=True,
                tx_hex=tx_hex,
                error="Note: Transaction needs witness data (signature + preimage) before broadcasting"
            )

        except Exception as e:
            logger.error(f"Error building HTLC claim transaction: {e}")
            return TransactionResult(
                success=False,
                error=str(e)
            )

    def build_refund_tx(
        self,
        htlc: HTLC,
        htlc_utxo: UTXO,
        refund_address: str,
        fee_sats: int = 1000,
        current_block: int = 0
    ) -> TransactionResult:
        """
        Build transaction to refund HTLC after timeout.

        Creates a transaction that spends the HTLC by providing the sender's
        signature after the timeout period.

        Args:
            htlc: HTLC instance
            htlc_utxo: UTXO of the funded HTLC
            refund_address: Address to send refunded funds
            fee_sats: Transaction fee in satoshis
            current_block: Current block height

        Returns:
            TransactionResult with transaction hex

        Note:
            This transaction requires:
            - Sequence number set to timeout_blocks (for OP_CHECKSEQUENCEVERIFY)
            - Witness data: [sender_sig] [0] [witness_script]
        """
        try:
            # Validate refund conditions
            can_refund, msg = htlc.can_refund(current_block)
            if not can_refund:
                return TransactionResult(
                    success=False,
                    error=f"Cannot refund HTLC: {msg}"
                )

            # Build transaction input
            # CRITICAL: Set nSequence to timeout_blocks for OP_CHECKSEQUENCEVERIFY
            timeout_sequence = htlc.parameters.timeout_blocks

            tx_in = CMutableTxIn(
                htlc_utxo.to_outpoint(),
                nSequence=timeout_sequence
            )

            # Build transaction output
            output_amount = htlc_utxo.amount_sats - fee_sats
            if output_amount <= 546:  # Dust limit
                return TransactionResult(
                    success=False,
                    error=f"Output amount {output_amount} below dust limit"
                )

            # Note: Would need to parse refund_address properly
            tx_out = CMutableTxOut(output_amount, CScript())

            # Create transaction
            tx = CMutableTransaction([tx_in], [tx_out])

            # For refund, witness stack is:
            # [sender_sig] [0] [witness_script]
            # The actual signing would be done via RPC

            tx_hex = b2x(tx.serialize())

            logger.info(
                f"Built HTLC refund transaction: "
                f"amount={output_amount} sats, fee={fee_sats} sats, "
                f"timeout_sequence={timeout_sequence}"
            )

            return TransactionResult(
                success=True,
                tx_hex=tx_hex,
                error="Note: Transaction needs witness data (signature) before broadcasting"
            )

        except Exception as e:
            logger.error(f"Error building HTLC refund transaction: {e}")
            return TransactionResult(
                success=False,
                error=str(e)
            )

    def sign_transaction(
        self,
        tx_hex: str,
        utxos: List[Dict[str, Any]]
    ) -> TransactionResult:
        """
        Sign transaction using ElementsRPCClient.

        Args:
            tx_hex: Unsigned transaction hex
            utxos: List of UTXO dictionaries with txid, vout, amount, scriptPubKey

        Returns:
            TransactionResult with signed transaction hex
        """
        if not self.elements_client:
            return TransactionResult(
                success=False,
                error="ElementsRPCClient not configured"
            )

        try:
            # Call RPC to sign transaction
            result, error = self.elements_client.sign_raw_transaction_with_wallet(
                tx_hex,
                utxos
            )

            if error:
                return TransactionResult(
                    success=False,
                    error=f"Signing failed: {error}"
                )

            signed_hex = result.get('hex')
            is_complete = result.get('complete', False)

            if not is_complete:
                errors = result.get('errors', [])
                return TransactionResult(
                    success=False,
                    error=f"Transaction incomplete: {errors}"
                )

            logger.info("Transaction signed successfully")

            return TransactionResult(
                success=True,
                tx_hex=signed_hex
            )

        except Exception as e:
            logger.error(f"Error signing transaction: {e}")
            return TransactionResult(
                success=False,
                error=str(e)
            )

    def broadcast_transaction(self, signed_tx_hex: str) -> TransactionResult:
        """
        Broadcast signed transaction to network.

        Args:
            signed_tx_hex: Signed transaction hex

        Returns:
            TransactionResult with txid if successful
        """
        if not self.elements_client:
            return TransactionResult(
                success=False,
                error="ElementsRPCClient not configured"
            )

        try:
            # Call RPC to broadcast transaction
            txid, error = self.elements_client.send_raw_transaction(signed_tx_hex)

            if error:
                return TransactionResult(
                    success=False,
                    error=f"Broadcast failed: {error}"
                )

            logger.info(f"Transaction broadcast successfully: {txid}")

            return TransactionResult(
                success=True,
                txid=txid,
                tx_hex=signed_tx_hex
            )

        except Exception as e:
            logger.error(f"Error broadcasting transaction: {e}")
            return TransactionResult(
                success=False,
                error=str(e)
            )

    def build_sign_and_broadcast(
        self,
        build_result: TransactionResult,
        utxos: List[Dict[str, Any]]
    ) -> TransactionResult:
        """
        Convenience method to sign and broadcast a built transaction.

        Args:
            build_result: Result from build_*_tx() method
            utxos: List of UTXO dictionaries for signing

        Returns:
            TransactionResult with final txid
        """
        if not build_result.success:
            return build_result

        # Sign transaction
        sign_result = self.sign_transaction(build_result.tx_hex, utxos)
        if not sign_result.success:
            return sign_result

        # Broadcast transaction
        broadcast_result = self.broadcast_transaction(sign_result.tx_hex)
        return broadcast_result


# Utility functions

def select_utxos(
    available_utxos: List[UTXO],
    target_amount: int,
    fee_estimate: int = 1000
) -> Tuple[List[UTXO], int]:
    """
    Simple UTXO selection (largest first).

    Args:
        available_utxos: List of available UTXOs
        target_amount: Target amount to spend (excluding fee)
        fee_estimate: Estimated transaction fee

    Returns:
        Tuple of (selected_utxos, change_amount)

    Raises:
        ValueError: If insufficient funds
    """
    # Sort UTXOs by amount (largest first)
    sorted_utxos = sorted(
        available_utxos,
        key=lambda u: u.amount_sats,
        reverse=True
    )

    selected = []
    total = 0
    needed = target_amount + fee_estimate

    for utxo in sorted_utxos:
        selected.append(utxo)
        total += utxo.amount_sats

        if total >= needed:
            change = total - needed
            return selected, change

    raise ValueError(
        f"Insufficient funds: need {needed} sats, "
        f"have {total} sats from {len(available_utxos)} UTXOs"
    )


if __name__ == "__main__":
    # Example usage
    logging.basicConfig(level=logging.DEBUG)

    print("=== BRLN-OS Transaction Builder Demo ===\n")

    if not BITCOIN_LIB_AVAILABLE:
        print("ERROR: python-bitcoinlib not installed")
        exit(1)

    # Create mock HTLC
    from . import preimage, htlc

    preimage_data = preimage.generate_preimage()
    receiver_pubkey = bytes.fromhex("03" + "a" * 64)
    sender_pubkey = bytes.fromhex("02" + "b" * 64)

    test_htlc = htlc.create_htlc(
        amount_sats=100000,
        payment_hash=preimage_data.payment_hash,
        receiver_pubkey=receiver_pubkey,
        sender_pubkey=sender_pubkey,
        timeout_blocks=144,
        network=htlc.NetworkType.BITCOIN_TESTNET
    )

    print(f"HTLC created: {test_htlc}")
    print(f"HTLC address: {test_htlc.get_address()}\n")

    # Create mock UTXOs
    mock_utxos = [
        UTXO(
            txid="a" * 64,
            vout=0,
            amount_sats=150000,
            script_pubkey="76a914" + "b" * 40 + "88ac",
            confirmations=6
        )
    ]

    print(f"Using {len(mock_utxos)} UTXO(s) with total {sum(u.amount_sats for u in mock_utxos)} sats\n")

    # Build funding transaction
    builder = BitcoinTransactionBuilder()
    result = builder.build_htlc_funding_tx(
        htlc=test_htlc,
        utxos=mock_utxos,
        change_address="tb1q" + "c" * 39,  # Mock address
        fee_rate_sat_per_vbyte=10
    )

    if result.success:
        print(f"✅ Funding transaction built successfully")
        print(f"TX hex (truncated): {result.tx_hex[:80]}...")
    else:
        print(f"❌ Failed to build funding transaction: {result.error}")

    print("\n=== Demo Complete ===")
