"""
BRLN-OS Atomic Swap Module - Preimage Generation and Management

This module handles the cryptographic preimage generation and hashing
that is fundamental to Hash Time Locked Contracts (HTLC) in atomic swaps.

Security Requirements:
- Preimage must be exactly 32 bytes (256 bits) of cryptographic randomness
- Hash must be SHA256 for Bitcoin/Lightning compatibility
- Constant-time comparison to prevent timing attacks
- No preimage should ever be stored in plaintext after swap completion

References:
- BOLT #0: https://github.com/lightning/bolts/blob/master/00-introduction.md
- BIP141: https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki
"""

import os
import hashlib
import hmac
from typing import Tuple, Optional
from dataclasses import dataclass
import logging

# Configure logging
logger = logging.getLogger(__name__)


# Constants
PREIMAGE_SIZE_BYTES = 32  # 256 bits
HASH_SIZE_BYTES = 32      # SHA256 output


@dataclass
class PreimageData:
    """
    Container for preimage and its hash.

    Attributes:
        preimage: The secret preimage (32 bytes)
        payment_hash: SHA256 hash of the preimage (32 bytes)
    """
    preimage: bytes
    payment_hash: bytes

    def __post_init__(self):
        """Validate preimage and hash after initialization."""
        if len(self.preimage) != PREIMAGE_SIZE_BYTES:
            raise ValueError(
                f"Preimage must be exactly {PREIMAGE_SIZE_BYTES} bytes, "
                f"got {len(self.preimage)}"
            )
        if len(self.payment_hash) != HASH_SIZE_BYTES:
            raise ValueError(
                f"Payment hash must be exactly {HASH_SIZE_BYTES} bytes, "
                f"got {len(self.payment_hash)}"
            )

    def to_hex(self) -> Tuple[str, str]:
        """
        Convert preimage and hash to hexadecimal strings.

        Returns:
            Tuple of (preimage_hex, payment_hash_hex)
        """
        return self.preimage.hex(), self.payment_hash.hex()

    def __repr__(self) -> str:
        """
        String representation (payment_hash only for security).
        Never print preimage in logs.
        """
        return f"PreimageData(payment_hash={self.payment_hash.hex()})"


class PreimageGenerator:
    """
    Cryptographically secure preimage generator for atomic swaps.

    This class generates random 32-byte preimages and computes their
    SHA256 hashes for use in Hash Time Locked Contracts (HTLC).
    """

    @staticmethod
    def generate() -> PreimageData:
        """
        Generate a new random preimage and compute its SHA256 hash.

        Uses os.urandom() which is cryptographically secure and suitable
        for generating secrets.

        Returns:
            PreimageData containing the preimage and its hash

        Raises:
            OSError: If the system cannot generate random bytes

        Example:
            >>> preimage_data = PreimageGenerator.generate()
            >>> print(f"Payment hash: {preimage_data.payment_hash.hex()}")
        """
        try:
            # Generate 32 bytes of cryptographic randomness
            preimage = os.urandom(PREIMAGE_SIZE_BYTES)

            # Compute SHA256 hash
            payment_hash = hashlib.sha256(preimage).digest()

            logger.debug(
                f"Generated new preimage with hash: {payment_hash.hex()}"
            )

            return PreimageData(preimage=preimage, payment_hash=payment_hash)

        except OSError as e:
            logger.error(f"Failed to generate random preimage: {e}")
            raise

    @staticmethod
    def compute_hash(preimage: bytes) -> bytes:
        """
        Compute SHA256 hash of a given preimage.

        Args:
            preimage: The preimage bytes (must be 32 bytes)

        Returns:
            SHA256 hash of the preimage (32 bytes)

        Raises:
            ValueError: If preimage is not 32 bytes

        Example:
            >>> preimage = bytes.fromhex("a" * 64)
            >>> hash_value = PreimageGenerator.compute_hash(preimage)
        """
        if len(preimage) != PREIMAGE_SIZE_BYTES:
            raise ValueError(
                f"Preimage must be exactly {PREIMAGE_SIZE_BYTES} bytes, "
                f"got {len(preimage)}"
            )

        return hashlib.sha256(preimage).digest()

    @staticmethod
    def verify_preimage(preimage: bytes, expected_hash: bytes) -> bool:
        """
        Verify that a preimage matches the expected payment hash.

        Uses constant-time comparison to prevent timing attacks.

        Args:
            preimage: The preimage to verify (32 bytes)
            expected_hash: The expected SHA256 hash (32 bytes)

        Returns:
            True if preimage hashes to expected_hash, False otherwise

        Security:
            Uses hmac.compare_digest() for constant-time comparison to
            prevent timing side-channel attacks.

        Example:
            >>> data = PreimageGenerator.generate()
            >>> assert PreimageGenerator.verify_preimage(
            ...     data.preimage,
            ...     data.payment_hash
            ... )
        """
        if len(preimage) != PREIMAGE_SIZE_BYTES:
            logger.warning(
                f"Invalid preimage size: {len(preimage)} bytes "
                f"(expected {PREIMAGE_SIZE_BYTES})"
            )
            return False

        if len(expected_hash) != HASH_SIZE_BYTES:
            logger.warning(
                f"Invalid hash size: {len(expected_hash)} bytes "
                f"(expected {HASH_SIZE_BYTES})"
            )
            return False

        # Compute hash of provided preimage
        computed_hash = hashlib.sha256(preimage).digest()

        # Constant-time comparison to prevent timing attacks
        is_valid = hmac.compare_digest(computed_hash, expected_hash)

        if is_valid:
            logger.debug(f"Preimage verified for hash: {expected_hash.hex()}")
        else:
            logger.warning(
                f"Preimage verification failed for hash: {expected_hash.hex()}"
            )

        return is_valid

    @staticmethod
    def from_hex(preimage_hex: str) -> PreimageData:
        """
        Create PreimageData from hexadecimal string.

        Args:
            preimage_hex: Hexadecimal string representation of preimage

        Returns:
            PreimageData with preimage and computed hash

        Raises:
            ValueError: If hex string is invalid or wrong length

        Example:
            >>> hex_str = "a" * 64  # 32 bytes in hex
            >>> data = PreimageGenerator.from_hex(hex_str)
        """
        try:
            preimage = bytes.fromhex(preimage_hex)
        except ValueError as e:
            raise ValueError(f"Invalid hexadecimal string: {e}")

        if len(preimage) != PREIMAGE_SIZE_BYTES:
            raise ValueError(
                f"Preimage must be exactly {PREIMAGE_SIZE_BYTES} bytes "
                f"({PREIMAGE_SIZE_BYTES * 2} hex characters), "
                f"got {len(preimage)} bytes"
            )

        payment_hash = PreimageGenerator.compute_hash(preimage)

        return PreimageData(preimage=preimage, payment_hash=payment_hash)


class PreimageStorage:
    """
    Secure storage manager for preimages.

    WARNING: Preimages should NEVER be stored in plaintext after a swap
    completes. This class is for temporary storage during active swaps only.
    """

    def __init__(self):
        """Initialize in-memory preimage storage (for active swaps only)."""
        self._active_preimages: dict[str, bytes] = {}
        logger.debug("Initialized PreimageStorage")

    def store_preimage(self, payment_hash: bytes, preimage: bytes) -> None:
        """
        Temporarily store preimage for an active swap.

        Args:
            payment_hash: The SHA256 hash (32 bytes)
            preimage: The preimage (32 bytes)

        Raises:
            ValueError: If preimage doesn't match payment_hash
        """
        if not PreimageGenerator.verify_preimage(preimage, payment_hash):
            raise ValueError(
                "Preimage does not match payment_hash - refusing to store"
            )

        hash_hex = payment_hash.hex()
        self._active_preimages[hash_hex] = preimage

        logger.info(f"Stored preimage for payment_hash: {hash_hex}")

    def retrieve_preimage(self, payment_hash: bytes) -> Optional[bytes]:
        """
        Retrieve stored preimage for a payment hash.

        Args:
            payment_hash: The SHA256 hash (32 bytes)

        Returns:
            The preimage if found, None otherwise
        """
        hash_hex = payment_hash.hex()
        preimage = self._active_preimages.get(hash_hex)

        if preimage:
            logger.debug(f"Retrieved preimage for payment_hash: {hash_hex}")
        else:
            logger.debug(f"No preimage found for payment_hash: {hash_hex}")

        return preimage

    def delete_preimage(self, payment_hash: bytes) -> bool:
        """
        Delete preimage from storage (after swap completes).

        Args:
            payment_hash: The SHA256 hash (32 bytes)

        Returns:
            True if preimage was deleted, False if not found
        """
        hash_hex = payment_hash.hex()

        if hash_hex in self._active_preimages:
            del self._active_preimages[hash_hex]
            logger.info(
                f"Deleted preimage for payment_hash: {hash_hex} "
                "(swap completed or failed)"
            )
            return True

        return False

    def clear_all(self) -> int:
        """
        Clear all stored preimages.

        WARNING: Only use for cleanup or testing!

        Returns:
            Number of preimages cleared
        """
        count = len(self._active_preimages)
        self._active_preimages.clear()
        logger.warning(f"Cleared all {count} stored preimages")
        return count


# Utility functions for convenience

def generate_preimage() -> PreimageData:
    """
    Convenience function to generate a new preimage.

    Returns:
        PreimageData containing preimage and payment hash
    """
    return PreimageGenerator.generate()


def verify_preimage(preimage: bytes, payment_hash: bytes) -> bool:
    """
    Convenience function to verify a preimage.

    Args:
        preimage: The preimage to verify (32 bytes)
        payment_hash: The expected SHA256 hash (32 bytes)

    Returns:
        True if valid, False otherwise
    """
    return PreimageGenerator.verify_preimage(preimage, payment_hash)


def compute_payment_hash(preimage: bytes) -> bytes:
    """
    Convenience function to compute payment hash.

    Args:
        preimage: The preimage (32 bytes)

    Returns:
        SHA256 hash of the preimage
    """
    return PreimageGenerator.compute_hash(preimage)


# Module-level instance for convenience
_preimage_storage = PreimageStorage()


def store_preimage(payment_hash: bytes, preimage: bytes) -> None:
    """Module-level convenience function for storing preimages."""
    _preimage_storage.store_preimage(payment_hash, preimage)


def retrieve_preimage(payment_hash: bytes) -> Optional[bytes]:
    """Module-level convenience function for retrieving preimages."""
    return _preimage_storage.retrieve_preimage(payment_hash)


def delete_preimage(payment_hash: bytes) -> bool:
    """Module-level convenience function for deleting preimages."""
    return _preimage_storage.delete_preimage(payment_hash)


if __name__ == "__main__":
    # Example usage
    logging.basicConfig(level=logging.DEBUG)

    print("=== BRLN-OS Preimage Generator Demo ===\n")

    # Generate new preimage
    data = generate_preimage()
    print(f"Generated preimage:")
    print(f"  Preimage: {data.preimage.hex()}")
    print(f"  Payment hash: {data.payment_hash.hex()}\n")

    # Verify preimage
    is_valid = verify_preimage(data.preimage, data.payment_hash)
    print(f"Verification result: {is_valid}\n")

    # Test with wrong preimage
    wrong_preimage = os.urandom(32)
    is_valid = verify_preimage(wrong_preimage, data.payment_hash)
    print(f"Wrong preimage verification: {is_valid}\n")

    # Store and retrieve
    store_preimage(data.payment_hash, data.preimage)
    retrieved = retrieve_preimage(data.payment_hash)
    print(f"Retrieved preimage matches: {retrieved == data.preimage}\n")

    # Delete
    deleted = delete_preimage(data.payment_hash)
    print(f"Preimage deleted: {deleted}")

    print("\n=== Demo Complete ===")
