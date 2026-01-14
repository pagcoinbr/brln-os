"""
BRLN-OS Atomic Swap Module - HTLC Script Builder

This module constructs Hash Time Locked Contract (HTLC) scripts for atomic swaps
on Bitcoin and Liquid blockchains using python-bitcoinlib.

HTLC Script Structure:
    OP_IF
        OP_HASH160 <payment_hash> OP_EQUALVERIFY <receiver_pubkey> OP_CHECKSIG
    OP_ELSE
        <timeout_blocks> OP_CHECKSEQUENCEVERIFY OP_DROP <sender_pubkey> OP_CHECKSIG
    OP_ENDIF

Security Requirements:
- payment_hash must be 20 bytes (RIPEMD160(SHA256(preimage)))
- Public keys must be 33 bytes (compressed SEC format)
- Timeout must use OP_CHECKSEQUENCEVERIFY (BIP112) for relative timelocks
- Script must be deterministic and reproducible

References:
- BIP112 (CHECKSEQUENCEVERIFY): https://github.com/bitcoin/bips/blob/master/bip-0112.mediawiki
- BIP141 (Segwit): https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki
- python-bitcoinlib: https://github.com/petertodd/python-bitcoinlib
"""

import hashlib
from typing import Tuple, Optional
from dataclasses import dataclass
import logging

# Bitcoin library imports
try:
    from bitcoin.core import CScript, Hash160
    from bitcoin.core.script import (
        OP_IF, OP_ELSE, OP_ENDIF,
        OP_HASH160, OP_EQUALVERIFY, OP_CHECKSIG,
        OP_CHECKSEQUENCEVERIFY, OP_DROP
    )
    from bitcoin.core.scripteval import VerifyScript, SCRIPT_VERIFY_P2SH
    from bitcoin.wallet import P2WSHBitcoinAddress
    BITCOIN_LIB_AVAILABLE = True
except ImportError:
    BITCOIN_LIB_AVAILABLE = False
    logging.warning(
        "python-bitcoinlib not installed. Install with: "
        "pip install python-bitcoinlib"
    )

# Configure logging
logger = logging.getLogger(__name__)


# Constants
PAYMENT_HASH_SIZE = 20  # RIPEMD160 output (20 bytes)
PUBKEY_COMPRESSED_SIZE = 33  # Compressed SEC format
SHA256_SIZE = 32  # For converting SHA256 to RIPEMD160


@dataclass
class HTLCScript:
    """
    Container for HTLC script data.

    Attributes:
        script: The compiled Bitcoin Script (CScript)
        script_hex: Hexadecimal representation of the script
        script_hash: SHA256 hash of the script (for P2WSH)
        witness_script: Same as script (for clarity in P2WSH context)
    """
    script: 'CScript'
    script_hex: str
    script_hash: bytes
    witness_script: 'CScript'

    def to_p2wsh_address(self, testnet: bool = False) -> str:
        """
        Convert script to Pay-to-Witness-Script-Hash (P2WSH) address.

        Args:
            testnet: If True, generate testnet address (tb1...).
                     If False, generate mainnet address (bc1...)

        Returns:
            Bech32-encoded P2WSH address
        """
        # For Liquid, would use different address encoding (blech32)
        # This implementation focuses on Bitcoin mainnet/testnet

        if testnet:
            # Testnet P2WSH address (starts with tb1)
            from bitcoin.core import TESTNET
            from bitcoin.wallet import P2WSHBitcoinTestnetAddress
            address = P2WSHBitcoinTestnetAddress.from_scriptPubKey(
                CScript([0, self.script_hash])
            )
        else:
            # Mainnet P2WSH address (starts with bc1)
            address = P2WSHBitcoinAddress.from_scriptPubKey(
                CScript([0, self.script_hash])
            )

        return str(address)

    def __repr__(self) -> str:
        return f"HTLCScript(script_hash={self.script_hash.hex()[:16]}...)"


class HTLCScriptBuilder:
    """
    Builder for Hash Time Locked Contract (HTLC) scripts.

    Creates scripts compatible with Bitcoin and Liquid blockchains that enable
    trustless atomic swaps using hash locks and timelocks.
    """

    def __init__(self):
        """Initialize the HTLC script builder."""
        if not BITCOIN_LIB_AVAILABLE:
            raise ImportError(
                "python-bitcoinlib is required for HTLCScriptBuilder. "
                "Install with: pip install python-bitcoinlib"
            )
        logger.debug("HTLCScriptBuilder initialized")

    @staticmethod
    def hash160(data: bytes) -> bytes:
        """
        Compute RIPEMD160(SHA256(data)) - Bitcoin's Hash160.

        Args:
            data: Input data to hash

        Returns:
            20-byte hash160 result
        """
        return Hash160(data)

    @staticmethod
    def sha256_to_hash160(sha256_hash: bytes) -> bytes:
        """
        Convert SHA256 hash (32 bytes) to Hash160 (20 bytes).

        This is used to convert preimage hashes from SHA256 to the format
        expected by OP_HASH160 in the HTLC script.

        Args:
            sha256_hash: 32-byte SHA256 hash

        Returns:
            20-byte RIPEMD160(SHA256) hash

        Raises:
            ValueError: If input is not 32 bytes
        """
        if len(sha256_hash) != SHA256_SIZE:
            raise ValueError(
                f"SHA256 hash must be {SHA256_SIZE} bytes, "
                f"got {len(sha256_hash)}"
            )

        # Apply RIPEMD160 to the SHA256 hash
        h = hashlib.new('ripemd160')
        h.update(sha256_hash)
        return h.digest()

    def build_htlc_script(
        self,
        payment_hash: bytes,
        receiver_pubkey: bytes,
        sender_pubkey: bytes,
        timeout_blocks: int
    ) -> HTLCScript:
        """
        Build HTLC script for atomic swap.

        The script allows:
        1. Receiver to claim funds with preimage + signature
        2. Sender to refund after timeout with signature only

        Script structure:
            OP_IF
                OP_HASH160 <payment_hash> OP_EQUALVERIFY <receiver_pubkey> OP_CHECKSIG
            OP_ELSE
                <timeout_blocks> OP_CHECKSEQUENCEVERIFY OP_DROP <sender_pubkey> OP_CHECKSIG
            OP_ENDIF

        Args:
            payment_hash: 20-byte RIPEMD160(SHA256(preimage)) or 32-byte SHA256(preimage)
            receiver_pubkey: 33-byte compressed public key of receiver
            sender_pubkey: 33-byte compressed public key of sender (refund)
            timeout_blocks: Number of blocks for relative timelock (BIP68/112)

        Returns:
            HTLCScript object containing script and metadata

        Raises:
            ValueError: If input parameters are invalid

        Example:
            >>> builder = HTLCScriptBuilder()
            >>> payment_hash = bytes.fromhex("a" * 40)  # 20 bytes
            >>> receiver_pub = bytes.fromhex("03" + "b" * 64)  # 33 bytes
            >>> sender_pub = bytes.fromhex("02" + "c" * 64)  # 33 bytes
            >>> htlc = builder.build_htlc_script(payment_hash, receiver_pub, sender_pub, 144)
            >>> print(htlc.script_hex)
        """
        # Validate inputs
        self._validate_inputs(
            payment_hash, receiver_pubkey, sender_pubkey, timeout_blocks
        )

        # Convert SHA256 to Hash160 if necessary
        if len(payment_hash) == SHA256_SIZE:
            logger.debug("Converting SHA256 payment hash to Hash160")
            payment_hash_160 = self.sha256_to_hash160(payment_hash)
        elif len(payment_hash) == PAYMENT_HASH_SIZE:
            payment_hash_160 = payment_hash
        else:
            raise ValueError(
                f"Payment hash must be either {SHA256_SIZE} bytes (SHA256) "
                f"or {PAYMENT_HASH_SIZE} bytes (Hash160)"
            )

        # Build the HTLC script
        script = CScript([
            OP_IF,
                # Claim path: receiver provides preimage + signature
                OP_HASH160,
                payment_hash_160,
                OP_EQUALVERIFY,
                receiver_pubkey,
                OP_CHECKSIG,
            OP_ELSE,
                # Refund path: sender waits for timeout + provides signature
                timeout_blocks,
                OP_CHECKSEQUENCEVERIFY,
                OP_DROP,
                sender_pubkey,
                OP_CHECKSIG,
            OP_ENDIF
        ])

        # Compute script hash for P2WSH
        script_hash = hashlib.sha256(script).digest()

        logger.info(
            f"Built HTLC script: "
            f"hash160={payment_hash_160.hex()}, "
            f"timeout={timeout_blocks} blocks, "
            f"script_hash={script_hash.hex()[:16]}..."
        )

        return HTLCScript(
            script=script,
            script_hex=script.hex(),
            script_hash=script_hash,
            witness_script=script
        )

    def _validate_inputs(
        self,
        payment_hash: bytes,
        receiver_pubkey: bytes,
        sender_pubkey: bytes,
        timeout_blocks: int
    ) -> None:
        """
        Validate HTLC script inputs.

        Args:
            payment_hash: Payment hash (20 or 32 bytes)
            receiver_pubkey: Receiver's public key (33 bytes)
            sender_pubkey: Sender's public key (33 bytes)
            timeout_blocks: Timeout in blocks (positive integer)

        Raises:
            ValueError: If any input is invalid
        """
        # Validate payment hash
        if not isinstance(payment_hash, bytes):
            raise ValueError("payment_hash must be bytes")

        if len(payment_hash) not in (PAYMENT_HASH_SIZE, SHA256_SIZE):
            raise ValueError(
                f"payment_hash must be {PAYMENT_HASH_SIZE} or {SHA256_SIZE} bytes, "
                f"got {len(payment_hash)}"
            )

        # Validate receiver pubkey
        if not isinstance(receiver_pubkey, bytes):
            raise ValueError("receiver_pubkey must be bytes")

        if len(receiver_pubkey) != PUBKEY_COMPRESSED_SIZE:
            raise ValueError(
                f"receiver_pubkey must be {PUBKEY_COMPRESSED_SIZE} bytes (compressed), "
                f"got {len(receiver_pubkey)}"
            )

        # Validate first byte of receiver pubkey (must be 02 or 03)
        if receiver_pubkey[0] not in (0x02, 0x03):
            raise ValueError(
                f"receiver_pubkey must start with 0x02 or 0x03 (compressed format), "
                f"got 0x{receiver_pubkey[0]:02x}"
            )

        # Validate sender pubkey
        if not isinstance(sender_pubkey, bytes):
            raise ValueError("sender_pubkey must be bytes")

        if len(sender_pubkey) != PUBKEY_COMPRESSED_SIZE:
            raise ValueError(
                f"sender_pubkey must be {PUBKEY_COMPRESSED_SIZE} bytes (compressed), "
                f"got {len(sender_pubkey)}"
            )

        # Validate first byte of sender pubkey
        if sender_pubkey[0] not in (0x02, 0x03):
            raise ValueError(
                f"sender_pubkey must start with 0x02 or 0x03 (compressed format), "
                f"got 0x{sender_pubkey[0]:02x}"
            )

        # Validate timeout
        if not isinstance(timeout_blocks, int):
            raise ValueError("timeout_blocks must be an integer")

        if timeout_blocks <= 0:
            raise ValueError(
                f"timeout_blocks must be positive, got {timeout_blocks}"
            )

        if timeout_blocks > 0xFFFF:  # 16-bit limit for BIP68
            raise ValueError(
                f"timeout_blocks exceeds BIP68 limit (65535), got {timeout_blocks}"
            )

        logger.debug("Input validation passed")

    def parse_htlc_script(self, script: bytes) -> dict:
        """
        Parse an HTLC script to extract parameters.

        Args:
            script: Raw HTLC script bytes

        Returns:
            Dictionary with 'payment_hash', 'receiver_pubkey',
            'sender_pubkey', 'timeout_blocks'

        Raises:
            ValueError: If script doesn't match expected HTLC format
        """
        try:
            cs = CScript(script)
            ops = list(cs)

            # Expected structure has at least 12 elements
            if len(ops) < 12:
                raise ValueError("Script too short to be valid HTLC")

            # Extract components
            if ops[0] != OP_IF:
                raise ValueError("Script doesn't start with OP_IF")

            payment_hash = ops[2] if isinstance(ops[2], bytes) else None
            receiver_pubkey = ops[4] if isinstance(ops[4], bytes) else None
            timeout_blocks = ops[7] if isinstance(ops[7], int) else None
            sender_pubkey = ops[10] if isinstance(ops[10], bytes) else None

            if not all([payment_hash, receiver_pubkey, sender_pubkey, timeout_blocks is not None]):
                raise ValueError("Failed to extract all HTLC parameters")

            return {
                'payment_hash': payment_hash,
                'receiver_pubkey': receiver_pubkey,
                'sender_pubkey': sender_pubkey,
                'timeout_blocks': timeout_blocks
            }

        except Exception as e:
            raise ValueError(f"Failed to parse HTLC script: {e}")


# Convenience functions

def build_htlc_script(
    payment_hash: bytes,
    receiver_pubkey: bytes,
    sender_pubkey: bytes,
    timeout_blocks: int
) -> HTLCScript:
    """
    Convenience function to build HTLC script.

    Args:
        payment_hash: 20 or 32 byte hash
        receiver_pubkey: 33-byte compressed pubkey
        sender_pubkey: 33-byte compressed pubkey
        timeout_blocks: Timeout in blocks

    Returns:
        HTLCScript object
    """
    builder = HTLCScriptBuilder()
    return builder.build_htlc_script(
        payment_hash, receiver_pubkey, sender_pubkey, timeout_blocks
    )


if __name__ == "__main__":
    # Example usage and testing
    logging.basicConfig(level=logging.DEBUG)

    print("=== BRLN-OS HTLC Script Builder Demo ===\n")

    if not BITCOIN_LIB_AVAILABLE:
        print("ERROR: python-bitcoinlib not installed")
        print("Install with: pip install python-bitcoinlib")
        exit(1)

    # Example parameters
    # Payment hash (20 bytes - Hash160)
    payment_hash_hex = "a" * 40  # 20 bytes
    payment_hash = bytes.fromhex(payment_hash_hex)

    # Compressed public keys (33 bytes each)
    receiver_pubkey_hex = "03" + "b" * 64  # Starts with 03 (compressed)
    receiver_pubkey = bytes.fromhex(receiver_pubkey_hex)

    sender_pubkey_hex = "02" + "c" * 64  # Starts with 02 (compressed)
    sender_pubkey = bytes.fromhex(sender_pubkey_hex)

    # Timeout (144 blocks ≈ 24 hours on Bitcoin)
    timeout_blocks = 144

    print(f"Payment Hash: {payment_hash.hex()}")
    print(f"Receiver Pubkey: {receiver_pubkey.hex()}")
    print(f"Sender Pubkey: {sender_pubkey.hex()}")
    print(f"Timeout: {timeout_blocks} blocks\n")

    # Build HTLC script
    builder = HTLCScriptBuilder()
    htlc = builder.build_htlc_script(
        payment_hash, receiver_pubkey, sender_pubkey, timeout_blocks
    )

    print(f"HTLC Script (hex): {htlc.script_hex}")
    print(f"Script Hash (SHA256): {htlc.script_hash.hex()}")
    print(f"P2WSH Address (testnet): {htlc.to_p2wsh_address(testnet=True)}")
    print(f"P2WSH Address (mainnet): {htlc.to_p2wsh_address(testnet=False)}\n")

    # Test with SHA256 hash input (32 bytes)
    print("=== Testing with SHA256 hash (32 bytes) ===")
    sha256_hash = hashlib.sha256(b"test preimage").digest()
    print(f"SHA256 Hash: {sha256_hash.hex()}")

    htlc2 = builder.build_htlc_script(
        sha256_hash, receiver_pubkey, sender_pubkey, timeout_blocks
    )
    print(f"HTLC Script Hash: {htlc2.script_hash.hex()}\n")

    # Parse script back
    print("=== Parsing HTLC script ===")
    try:
        parsed = builder.parse_htlc_script(htlc.script)
        print(f"Parsed payment_hash: {parsed['payment_hash'].hex()}")
        print(f"Parsed receiver_pubkey: {parsed['receiver_pubkey'].hex()}")
        print(f"Parsed sender_pubkey: {parsed['sender_pubkey'].hex()}")
        print(f"Parsed timeout_blocks: {parsed['timeout_blocks']}")
    except Exception as e:
        print(f"Parse error: {e}")

    print("\n=== Demo Complete ===")
