"""
BRLN-OS Atomic Swap Module - HTLC Lifecycle Management

This module manages the lifecycle of Hash Time Locked Contracts (HTLC) for atomic swaps,
including creation, validation, claiming, and refunding.

HTLC States:
1. Created - HTLC script generated, not yet funded
2. Funded - Transaction sending funds to HTLC address confirmed
3. Claimed - Receiver revealed preimage and claimed funds
4. Refunded - Timeout expired, sender reclaimed funds
5. Expired - Timeout passed but not yet refunded

Security Considerations:
- Timeout margins account for blockchain reorganizations
- Bitcoin: 6 block confirmation requirement
- Liquid: 2 block confirmation requirement
- Preimage verification uses constant-time comparison

References:
- BIP68 (Relative Timelocks): https://github.com/bitcoin/bips/blob/master/bip-0068.mediawiki
- BIP112 (CHECKSEQUENCEVERIFY): https://github.com/bitcoin/bips/blob/master/bip-0112.mediawiki
"""

import time
from typing import Optional, Tuple
from dataclasses import dataclass
from enum import Enum
from datetime import datetime, timedelta
import logging

# Import from other brln-swap-core modules
from . import preimage
from .scriptbuilder import HTLCScriptBuilder, HTLCScript

# Configure logging
logger = logging.getLogger(__name__)


class HTLCState(Enum):
    """HTLC lifecycle states."""
    CREATED = "created"
    FUNDED = "funded"
    CLAIMED = "claimed"
    REFUNDED = "refunded"
    EXPIRED = "expired"


class NetworkType(Enum):
    """Blockchain network types."""
    BITCOIN_MAINNET = "bitcoin_mainnet"
    BITCOIN_TESTNET = "bitcoin_testnet"
    LIQUID_MAINNET = "liquid_mainnet"
    LIQUID_TESTNET = "liquid_testnet"


# Network-specific constants
NETWORK_CONSTANTS = {
    NetworkType.BITCOIN_MAINNET: {
        'block_time_seconds': 600,  # 10 minutes
        'reorg_safety_blocks': 6,   # Standard 6 confirmations
        'min_timeout_blocks': 144,  # 24 hours
        'max_timeout_blocks': 2016,  # 2 weeks
    },
    NetworkType.BITCOIN_TESTNET: {
        'block_time_seconds': 600,
        'reorg_safety_blocks': 6,
        'min_timeout_blocks': 12,   # Shorter for testing
        'max_timeout_blocks': 288,
    },
    NetworkType.LIQUID_MAINNET: {
        'block_time_seconds': 60,   # 1 minute
        'reorg_safety_blocks': 2,   # Liquid is more centralized
        'min_timeout_blocks': 288,  # 4.8 hours
        'max_timeout_blocks': 4320,  # 3 days
    },
    NetworkType.LIQUID_TESTNET: {
        'block_time_seconds': 60,
        'reorg_safety_blocks': 2,
        'min_timeout_blocks': 24,   # Shorter for testing
        'max_timeout_blocks': 288,
    },
}


@dataclass
class HTLCParameters:
    """
    Parameters for creating an HTLC.

    Attributes:
        amount_sats: Amount in satoshis
        payment_hash: 20 or 32 byte hash
        receiver_pubkey: 33-byte compressed pubkey of receiver
        sender_pubkey: 33-byte compressed pubkey of sender (for refund)
        timeout_blocks: Number of blocks for relative timelock
        network: Network type (Bitcoin/Liquid, mainnet/testnet)
    """
    amount_sats: int
    payment_hash: bytes
    receiver_pubkey: bytes
    sender_pubkey: bytes
    timeout_blocks: int
    network: NetworkType

    def __post_init__(self):
        """Validate parameters after initialization."""
        if self.amount_sats <= 0:
            raise ValueError(f"Amount must be positive, got {self.amount_sats}")

        if len(self.payment_hash) not in (20, 32):
            raise ValueError(
                f"Payment hash must be 20 or 32 bytes, got {len(self.payment_hash)}"
            )

        if len(self.receiver_pubkey) != 33:
            raise ValueError(
                f"Receiver pubkey must be 33 bytes, got {len(self.receiver_pubkey)}"
            )

        if len(self.sender_pubkey) != 33:
            raise ValueError(
                f"Sender pubkey must be 33 bytes, got {len(self.sender_pubkey)}"
            )

        if self.timeout_blocks <= 0:
            raise ValueError(
                f"Timeout must be positive, got {self.timeout_blocks}"
            )


class HTLC:
    """
    Hash Time Locked Contract manager.

    Manages the full lifecycle of an HTLC from creation through claiming or refunding.
    """

    def __init__(self, parameters: HTLCParameters):
        """
        Initialize HTLC with parameters.

        Args:
            parameters: HTLCParameters object
        """
        self.parameters = parameters
        self.state = HTLCState.CREATED
        self.created_at = datetime.utcnow()
        self.funded_at: Optional[datetime] = None
        self.claimed_at: Optional[datetime] = None
        self.refunded_at: Optional[datetime] = None

        # Build script
        self.script_builder = HTLCScriptBuilder()
        self.htlc_script: HTLCScript = self.script_builder.build_htlc_script(
            payment_hash=parameters.payment_hash,
            receiver_pubkey=parameters.receiver_pubkey,
            sender_pubkey=parameters.sender_pubkey,
            timeout_blocks=parameters.timeout_blocks
        )

        # Transaction IDs
        self.funding_txid: Optional[str] = None
        self.claim_txid: Optional[str] = None
        self.refund_txid: Optional[str] = None

        # Block heights
        self.funding_block_height: Optional[int] = None
        self.expiry_block_height: Optional[int] = None

        logger.info(
            f"HTLC created: amount={parameters.amount_sats} sats, "
            f"timeout={parameters.timeout_blocks} blocks, "
            f"network={parameters.network.value}"
        )

    def get_script(self) -> HTLCScript:
        """
        Get the compiled HTLC script.

        Returns:
            HTLCScript object containing script and metadata
        """
        return self.htlc_script

    def get_address(self, testnet: Optional[bool] = None) -> str:
        """
        Get the P2WSH address for funding the HTLC.

        Args:
            testnet: If None, auto-detect from network type.
                     If True, generate testnet address.
                     If False, generate mainnet address.

        Returns:
            Bech32-encoded P2WSH address (bc1... or tb1...)
        """
        if testnet is None:
            # Auto-detect from network type
            testnet = self.parameters.network in (
                NetworkType.BITCOIN_TESTNET,
                NetworkType.LIQUID_TESTNET
            )

        address = self.htlc_script.to_p2wsh_address(testnet=testnet)
        logger.debug(f"Generated HTLC address: {address}")
        return address

    def validate_timeout(
        self,
        current_block: int,
        include_safety_margin: bool = True
    ) -> Tuple[bool, str]:
        """
        Validate that timeout is safe for the current block height.

        Args:
            current_block: Current blockchain tip height
            include_safety_margin: If True, add reorg safety margin

        Returns:
            Tuple of (is_valid, message)

        Example:
            >>> htlc = HTLC(params)
            >>> is_valid, msg = htlc.validate_timeout(current_block=700000)
        """
        constants = NETWORK_CONSTANTS[self.parameters.network]

        # Calculate expiry block
        if self.funding_block_height:
            expiry_block = (
                self.funding_block_height + self.parameters.timeout_blocks
            )
        else:
            # Not yet funded, estimate from current block
            expiry_block = current_block + self.parameters.timeout_blocks

        # Add safety margin for reorgs
        if include_safety_margin:
            safety_blocks = constants['reorg_safety_blocks']
            safe_expiry_block = expiry_block + safety_blocks
        else:
            safe_expiry_block = expiry_block

        # Check if timeout is in valid range
        min_timeout = constants['min_timeout_blocks']
        max_timeout = constants['max_timeout_blocks']

        if self.parameters.timeout_blocks < min_timeout:
            return False, (
                f"Timeout too short: {self.parameters.timeout_blocks} blocks "
                f"< minimum {min_timeout} blocks"
            )

        if self.parameters.timeout_blocks > max_timeout:
            return False, (
                f"Timeout too long: {self.parameters.timeout_blocks} blocks "
                f"> maximum {max_timeout} blocks"
            )

        # Check if HTLC will expire soon
        blocks_until_expiry = expiry_block - current_block
        if blocks_until_expiry <= 0:
            return False, f"HTLC already expired at block {expiry_block}"

        if blocks_until_expiry < constants['reorg_safety_blocks']:
            return False, (
                f"HTLC expires too soon: {blocks_until_expiry} blocks remaining "
                f"(minimum safety margin: {constants['reorg_safety_blocks']} blocks)"
            )

        # Calculate estimated time until expiry
        estimated_seconds = blocks_until_expiry * constants['block_time_seconds']
        estimated_time = timedelta(seconds=estimated_seconds)

        return True, (
            f"Timeout valid: {blocks_until_expiry} blocks "
            f"(≈ {estimated_time}) until expiry at block {expiry_block}"
        )

    def can_claim(self, preimage_bytes: bytes) -> Tuple[bool, str]:
        """
        Check if HTLC can be claimed with the given preimage.

        Args:
            preimage_bytes: 32-byte preimage to verify

        Returns:
            Tuple of (can_claim, message)

        Security:
            Uses constant-time comparison via preimage.verify_preimage()
        """
        # Check state
        if self.state == HTLCState.CLAIMED:
            return False, "HTLC already claimed"

        if self.state == HTLCState.REFUNDED:
            return False, "HTLC already refunded"

        if self.state != HTLCState.FUNDED:
            return False, f"HTLC not funded yet (state: {self.state.value})"

        # Verify preimage matches payment hash
        # If payment_hash is 20 bytes (Hash160), we need to convert preimage
        if len(self.parameters.payment_hash) == 20:
            # Payment hash is Hash160, compute Hash160 of preimage
            preimage_hash160 = self.script_builder.hash160(preimage_bytes)
            is_valid = preimage.verify_preimage(
                preimage_bytes,
                preimage_hash160  # Compare against Hash160
            )
        else:
            # Payment hash is SHA256 (32 bytes)
            is_valid = preimage.verify_preimage(
                preimage_bytes,
                self.parameters.payment_hash
            )

        if not is_valid:
            return False, "Preimage does not match payment hash"

        return True, "HTLC can be claimed with this preimage"

    def can_refund(
        self,
        current_block: int,
        require_safety_margin: bool = True
    ) -> Tuple[bool, str]:
        """
        Check if HTLC can be refunded at the current block height.

        Args:
            current_block: Current blockchain tip height
            require_safety_margin: If True, require reorg safety margin

        Returns:
            Tuple of (can_refund, message)
        """
        # Check state
        if self.state == HTLCState.CLAIMED:
            return False, "HTLC already claimed"

        if self.state == HTLCState.REFUNDED:
            return False, "HTLC already refunded"

        if self.state != HTLCState.FUNDED and self.state != HTLCState.EXPIRED:
            return False, f"HTLC not funded yet (state: {self.state.value})"

        # Check if funding block is known
        if not self.funding_block_height:
            return False, "HTLC funding block height unknown"

        # Calculate expiry block
        expiry_block = self.funding_block_height + self.parameters.timeout_blocks

        # Add safety margin
        constants = NETWORK_CONSTANTS[self.parameters.network]
        if require_safety_margin:
            safe_expiry_block = expiry_block + constants['reorg_safety_blocks']
        else:
            safe_expiry_block = expiry_block

        # Check if current block is past expiry
        if current_block < expiry_block:
            blocks_remaining = expiry_block - current_block
            return False, (
                f"Timeout not yet reached: {blocks_remaining} blocks remaining "
                f"until block {expiry_block}"
            )

        if require_safety_margin and current_block < safe_expiry_block:
            blocks_remaining = safe_expiry_block - current_block
            return False, (
                f"Safety margin not yet reached: {blocks_remaining} blocks remaining "
                f"until safe refund at block {safe_expiry_block}"
            )

        blocks_past_expiry = current_block - expiry_block
        return True, (
            f"HTLC can be refunded: {blocks_past_expiry} blocks past expiry "
            f"(expired at block {expiry_block})"
        )

    def mark_funded(
        self,
        txid: str,
        block_height: int,
        confirmed: bool = True
    ) -> None:
        """
        Mark HTLC as funded.

        Args:
            txid: Transaction ID of funding transaction
            block_height: Block height where funding was confirmed
            confirmed: If False, funding is in mempool
        """
        if self.state != HTLCState.CREATED:
            raise ValueError(f"Cannot fund HTLC in state {self.state.value}")

        self.funding_txid = txid
        self.funding_block_height = block_height
        self.expiry_block_height = block_height + self.parameters.timeout_blocks
        self.state = HTLCState.FUNDED
        self.funded_at = datetime.utcnow()

        logger.info(
            f"HTLC funded: txid={txid}, block={block_height}, "
            f"expires_at_block={self.expiry_block_height}"
        )

    def mark_claimed(self, txid: str, preimage_bytes: bytes) -> None:
        """
        Mark HTLC as claimed.

        Args:
            txid: Transaction ID of claim transaction
            preimage_bytes: Preimage used to claim

        Raises:
            ValueError: If HTLC cannot be claimed
        """
        can_claim, msg = self.can_claim(preimage_bytes)
        if not can_claim:
            raise ValueError(f"Cannot claim HTLC: {msg}")

        self.claim_txid = txid
        self.state = HTLCState.CLAIMED
        self.claimed_at = datetime.utcnow()

        logger.info(f"HTLC claimed: txid={txid}")

    def mark_refunded(self, txid: str, current_block: int) -> None:
        """
        Mark HTLC as refunded.

        Args:
            txid: Transaction ID of refund transaction
            current_block: Current block height

        Raises:
            ValueError: If HTLC cannot be refunded
        """
        can_refund, msg = self.can_refund(current_block)
        if not can_refund:
            raise ValueError(f"Cannot refund HTLC: {msg}")

        self.refund_txid = txid
        self.state = HTLCState.REFUNDED
        self.refunded_at = datetime.utcnow()

        logger.info(f"HTLC refunded: txid={txid}, block={current_block}")

    def mark_expired(self, current_block: int) -> None:
        """
        Mark HTLC as expired (timeout reached but not yet refunded).

        Args:
            current_block: Current block height
        """
        if self.state != HTLCState.FUNDED:
            raise ValueError(f"Cannot mark expired from state {self.state.value}")

        if not self.funding_block_height:
            raise ValueError("Funding block height not set")

        expiry_block = self.funding_block_height + self.parameters.timeout_blocks
        if current_block < expiry_block:
            raise ValueError(
                f"HTLC not yet expired: {expiry_block - current_block} blocks remaining"
            )

        self.state = HTLCState.EXPIRED
        logger.info(f"HTLC expired at block {current_block}")

    def to_dict(self) -> dict:
        """
        Convert HTLC to dictionary for serialization.

        Returns:
            Dictionary with all HTLC data
        """
        return {
            'state': self.state.value,
            'parameters': {
                'amount_sats': self.parameters.amount_sats,
                'payment_hash': self.parameters.payment_hash.hex(),
                'receiver_pubkey': self.parameters.receiver_pubkey.hex(),
                'sender_pubkey': self.parameters.sender_pubkey.hex(),
                'timeout_blocks': self.parameters.timeout_blocks,
                'network': self.parameters.network.value,
            },
            'script': {
                'script_hex': self.htlc_script.script_hex,
                'script_hash': self.htlc_script.script_hash.hex(),
            },
            'transactions': {
                'funding_txid': self.funding_txid,
                'claim_txid': self.claim_txid,
                'refund_txid': self.refund_txid,
            },
            'blocks': {
                'funding_block_height': self.funding_block_height,
                'expiry_block_height': self.expiry_block_height,
            },
            'timestamps': {
                'created_at': self.created_at.isoformat() if self.created_at else None,
                'funded_at': self.funded_at.isoformat() if self.funded_at else None,
                'claimed_at': self.claimed_at.isoformat() if self.claimed_at else None,
                'refunded_at': self.refunded_at.isoformat() if self.refunded_at else None,
            }
        }

    def __repr__(self) -> str:
        return (
            f"HTLC(state={self.state.value}, "
            f"amount={self.parameters.amount_sats} sats, "
            f"timeout={self.parameters.timeout_blocks} blocks)"
        )


# Convenience functions

def create_htlc(
    amount_sats: int,
    payment_hash: bytes,
    receiver_pubkey: bytes,
    sender_pubkey: bytes,
    timeout_blocks: int,
    network: NetworkType = NetworkType.BITCOIN_TESTNET
) -> HTLC:
    """
    Convenience function to create an HTLC.

    Args:
        amount_sats: Amount in satoshis
        payment_hash: 20 or 32 byte hash
        receiver_pubkey: 33-byte compressed pubkey
        sender_pubkey: 33-byte compressed pubkey
        timeout_blocks: Timeout in blocks
        network: Network type

    Returns:
        HTLC instance
    """
    params = HTLCParameters(
        amount_sats=amount_sats,
        payment_hash=payment_hash,
        receiver_pubkey=receiver_pubkey,
        sender_pubkey=sender_pubkey,
        timeout_blocks=timeout_blocks,
        network=network
    )
    return HTLC(params)


if __name__ == "__main__":
    # Example usage
    logging.basicConfig(level=logging.DEBUG)

    print("=== BRLN-OS HTLC Manager Demo ===\n")

    # Generate preimage and hash
    preimage_data = preimage.generate_preimage()
    print(f"Generated preimage: {preimage_data.preimage.hex()}")
    print(f"Payment hash: {preimage_data.payment_hash.hex()}\n")

    # Example public keys (33 bytes compressed)
    receiver_pubkey = bytes.fromhex("03" + "a" * 64)
    sender_pubkey = bytes.fromhex("02" + "b" * 64)

    # Create HTLC
    htlc = create_htlc(
        amount_sats=100000,  # 0.001 BTC
        payment_hash=preimage_data.payment_hash,
        receiver_pubkey=receiver_pubkey,
        sender_pubkey=sender_pubkey,
        timeout_blocks=144,  # 24 hours
        network=NetworkType.BITCOIN_TESTNET
    )

    print(f"HTLC created: {htlc}")
    print(f"HTLC address: {htlc.get_address()}\n")

    # Validate timeout
    current_block = 700000
    is_valid, msg = htlc.validate_timeout(current_block)
    print(f"Timeout validation: {is_valid}")
    print(f"Message: {msg}\n")

    # Mark as funded
    htlc.mark_funded(txid="abc123", block_height=current_block)
    print(f"HTLC state after funding: {htlc.state.value}\n")

    # Check if can claim
    can_claim, msg = htlc.can_claim(preimage_data.preimage)
    print(f"Can claim: {can_claim}")
    print(f"Message: {msg}\n")

    # Check if can refund (should fail, not expired yet)
    can_refund, msg = htlc.can_refund(current_block + 100)
    print(f"Can refund (at block {current_block + 100}): {can_refund}")
    print(f"Message: {msg}\n")

    # Check if can refund after expiry
    expiry_block = current_block + 144 + 6  # Timeout + safety margin
    can_refund, msg = htlc.can_refund(expiry_block)
    print(f"Can refund (at block {expiry_block}): {can_refund}")
    print(f"Message: {msg}\n")

    # Serialize to dict
    print("=== HTLC Serialization ===")
    htlc_dict = htlc.to_dict()
    print(f"State: {htlc_dict['state']}")
    print(f"Amount: {htlc_dict['parameters']['amount_sats']} sats")
    print(f"Expiry block: {htlc_dict['blocks']['expiry_block_height']}")

    print("\n=== Demo Complete ===")
