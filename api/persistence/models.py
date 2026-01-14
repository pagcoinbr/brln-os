"""
SQLAlchemy ORM models for atomic swap persistence.

This module defines the database schema for:
- Swaps (atomic swap lifecycle tracking)
- Peers (P2P network participants)
- SwapTransactions (on-chain transaction tracking)
- SwapEvents (audit trail for swap state changes)
- Assets (supported assets for swaps)
"""

import enum
from datetime import datetime
from typing import Optional
import uuid

from sqlalchemy import (
    Column, String, Integer, BigInteger, Boolean, DateTime,
    ForeignKey, Enum, JSON, Text, Index
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

Base = declarative_base()


class SwapState(enum.Enum):
    """Swap lifecycle states"""
    INITIATED = "initiated"      # Swap created, not yet funded
    FUNDED = "funded"            # HTLC funded on-chain
    CLAIMED = "claimed"          # Successfully completed (preimage revealed, funds claimed)
    REFUNDED = "refunded"        # Timeout expired, funds refunded to initiator
    EXPIRED = "expired"          # Past timeout but not yet refunded
    FAILED = "failed"            # Swap failed for some reason


class SwapDirection(enum.Enum):
    """Swap direction/type"""
    # L-BTC ↔ Lightning (PRIMARY)
    LBTC_TO_LIGHTNING = "lbtc_to_lightning"
    LIGHTNING_TO_LBTC = "lightning_to_lbtc"

    # Bitcoin on-chain ↔ Lightning (submarine swaps)
    ONCHAIN_TO_LIGHTNING = "onchain_to_lightning"
    LIGHTNING_TO_ONCHAIN = "lightning_to_onchain"

    # Cross-chain atomic swaps
    BTC_TO_LBTC = "btc_to_lbtc"
    LBTC_TO_BTC = "lbtc_to_btc"

    # Liquid asset swaps
    LIQUID_ASSET_TO_ASSET = "liquid_asset_to_asset"
    LIQUID_ASSET_TO_LIGHTNING = "liquid_asset_to_lightning"


class NetworkType(enum.Enum):
    """Blockchain network types"""
    BITCOIN_MAINNET = "bitcoin_mainnet"
    BITCOIN_TESTNET = "bitcoin_testnet"
    LIQUID_MAINNET = "liquid_mainnet"
    LIQUID_TESTNET = "liquid_testnet"


class ConnectionType(enum.Enum):
    """Peer connection types"""
    LIGHTNING = "lightning"      # Via Lightning Network channels
    TOR = "tor"                  # Via Tor hidden service
    DIRECT = "direct"            # Direct IP connection


class Swap(Base):
    """
    Atomic swap record.

    Tracks the complete lifecycle of a swap from initiation through
    completion (claimed) or failure (refunded/expired).
    """
    __tablename__ = 'swaps'

    # Primary key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Swap type and state
    swap_type = Column(Enum(SwapDirection), nullable=False, index=True)
    state = Column(Enum(SwapState), nullable=False, default=SwapState.INITIATED, index=True)

    # HTLC details
    payment_hash = Column(String(64), nullable=False, unique=True, index=True)  # 32 bytes hex
    preimage = Column(String(64), nullable=True)  # Encrypted, deleted after completion
    timeout_block_height = Column(Integer, nullable=False)
    network_type = Column(Enum(NetworkType), nullable=False)

    # Parties
    initiator_peer_id = Column(UUID(as_uuid=True), ForeignKey('peers.id'), nullable=False)
    receiver_peer_id = Column(UUID(as_uuid=True), ForeignKey('peers.id'), nullable=False)

    # Amounts
    amount_satoshis = Column(BigInteger, nullable=False)
    fee_satoshis = Column(BigInteger, nullable=False, default=0)

    # Transaction tracking
    funding_txid = Column(String(64), nullable=True, index=True)
    funding_vout = Column(Integer, nullable=True)
    claim_txid = Column(String(64), nullable=True)
    refund_txid = Column(String(64), nullable=True)

    # Script and address
    htlc_script_hex = Column(Text, nullable=False)
    htlc_address = Column(String(128), nullable=False, index=True)

    # Timestamps
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)
    funded_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    expires_at = Column(DateTime, nullable=False, index=True)

    # Recovery
    recovery_file_path = Column(String(512), nullable=True)

    # Lightning invoice (if applicable)
    lightning_invoice = Column(Text, nullable=True)
    lightning_payment_request = Column(Text, nullable=True)

    # Relations
    initiator = relationship("Peer", foreign_keys=[initiator_peer_id], backref="initiated_swaps")
    receiver = relationship("Peer", foreign_keys=[receiver_peer_id], backref="received_swaps")
    transactions = relationship("SwapTransaction", back_populates="swap", cascade="all, delete-orphan")
    events = relationship("SwapEvent", back_populates="swap", cascade="all, delete-orphan", order_by="SwapEvent.created_at")

    # Indexes for common queries
    __table_args__ = (
        Index('idx_swap_state_expires', 'state', 'expires_at'),
        Index('idx_swap_network_state', 'network_type', 'state'),
        Index('idx_swap_created', 'created_at'),
    )

    def __repr__(self):
        return f"<Swap(id={self.id}, type={self.swap_type.value}, state={self.state.value}, amount={self.amount_satoshis})>"


class Peer(Base):
    """
    P2P network peer.

    Represents another node in the atomic swap network.
    Can be connected via Lightning Network, Tor, or direct IP.
    """
    __tablename__ = 'peers'

    # Primary key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Identity
    peer_pubkey = Column(String(66), unique=True, nullable=False, index=True)  # Lightning node pubkey or unique ID
    peer_alias = Column(String(128), nullable=True)

    # Connection details
    connection_type = Column(Enum(ConnectionType), nullable=False)
    tor_onion_address = Column(String(128), nullable=True)  # e.g., abc123xyz.onion:9999
    lnd_node_uri = Column(String(256), nullable=True)       # e.g., pubkey@host:port

    # Status
    last_seen_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)
    is_active = Column(Boolean, nullable=False, default=True, index=True)

    # Reputation tracking
    reputation_score = Column(Integer, nullable=False, default=100)
    successful_swaps = Column(Integer, nullable=False, default=0)
    failed_swaps = Column(Integer, nullable=False, default=0)

    # Capabilities
    supported_swap_types = Column(JSON, nullable=True)  # List of SwapDirection values
    supported_assets = Column(JSON, nullable=True)       # List of asset IDs

    # Timestamps
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Indexes
    __table_args__ = (
        Index('idx_peer_active_lastseen', 'is_active', 'last_seen_at'),
        Index('idx_peer_reputation', 'reputation_score'),
    )

    def __repr__(self):
        return f"<Peer(id={self.id}, pubkey={self.peer_pubkey[:16]}..., alias={self.peer_alias})>"


class SwapTransaction(Base):
    """
    On-chain transaction associated with a swap.

    Tracks funding, claim, and refund transactions.
    """
    __tablename__ = 'swap_transactions'

    # Primary key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Foreign key
    swap_id = Column(UUID(as_uuid=True), ForeignKey('swaps.id', ondelete='CASCADE'), nullable=False, index=True)

    # Transaction details
    tx_type = Column(String(16), nullable=False)  # 'funding', 'claim', 'refund'
    txid = Column(String(64), unique=True, nullable=False, index=True)
    tx_hex = Column(Text, nullable=False)

    # Confirmation tracking
    confirmations = Column(Integer, nullable=False, default=0)
    block_height = Column(Integer, nullable=True)
    block_hash = Column(String(64), nullable=True)

    # Timestamps
    broadcast_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    confirmed_at = Column(DateTime, nullable=True)

    # Relations
    swap = relationship("Swap", back_populates="transactions")

    # Indexes
    __table_args__ = (
        Index('idx_tx_swap_type', 'swap_id', 'tx_type'),
        Index('idx_tx_confirmations', 'confirmations'),
    )

    def __repr__(self):
        return f"<SwapTransaction(id={self.id}, type={self.tx_type}, txid={self.txid[:16]}..., confirmations={self.confirmations})>"


class SwapEvent(Base):
    """
    Audit trail for swap state changes.

    Records every state transition, error, and recovery attempt.
    """
    __tablename__ = 'swap_events'

    # Primary key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Foreign key
    swap_id = Column(UUID(as_uuid=True), ForeignKey('swaps.id', ondelete='CASCADE'), nullable=False, index=True)

    # Event details
    event_type = Column(String(32), nullable=False)  # 'state_transition', 'error', 'recovery_attempt', etc.
    old_state = Column(Enum(SwapState), nullable=True)
    new_state = Column(Enum(SwapState), nullable=True)

    # Additional data
    details = Column(JSON, nullable=True)  # Free-form event details
    error_message = Column(Text, nullable=True)

    # Timestamp
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)

    # Relations
    swap = relationship("Swap", back_populates="events")

    # Indexes
    __table_args__ = (
        Index('idx_event_swap_created', 'swap_id', 'created_at'),
        Index('idx_event_type', 'event_type'),
    )

    def __repr__(self):
        return f"<SwapEvent(id={self.id}, type={self.event_type}, swap_id={self.swap_id})>"


class Asset(Base):
    """
    Supported asset for swaps.

    Tracks Bitcoin, L-BTC, and Liquid assets (Taproot Assets, Issued Assets).
    """
    __tablename__ = 'assets'

    # Primary key
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Asset identity
    asset_id = Column(String(64), unique=True, nullable=False, index=True)  # "bitcoin", "lbtc", or Liquid asset ID
    asset_name = Column(String(128), nullable=False)
    asset_ticker = Column(String(16), nullable=True)
    asset_type = Column(String(32), nullable=False)  # "BTC", "L-BTC", "TAPROOT_ASSET", "ISSUED_ASSET"

    # Asset metadata
    decimals = Column(Integer, nullable=False, default=8)
    is_enabled = Column(Boolean, nullable=False, default=True)

    # Statistics
    total_swapped_amount = Column(BigInteger, nullable=False, default=0)
    total_swap_count = Column(Integer, nullable=False, default=0)

    # Timestamps
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"<Asset(id={self.asset_id}, name={self.asset_name}, type={self.asset_type})>"


# Utility functions for model operations

def create_swap_event(
    swap_id: uuid.UUID,
    event_type: str,
    old_state: Optional[SwapState] = None,
    new_state: Optional[SwapState] = None,
    details: Optional[dict] = None,
    error_message: Optional[str] = None
) -> SwapEvent:
    """Helper function to create a swap event."""
    return SwapEvent(
        swap_id=swap_id,
        event_type=event_type,
        old_state=old_state,
        new_state=new_state,
        details=details,
        error_message=error_message
    )


def update_peer_reputation(
    peer: Peer,
    swap_successful: bool,
    adjustment: int = 5
) -> None:
    """
    Update peer reputation based on swap outcome.

    Args:
        peer: Peer to update
        swap_successful: Whether the swap completed successfully
        adjustment: Points to add/subtract (default: 5)
    """
    if swap_successful:
        peer.successful_swaps += 1
        peer.reputation_score = min(100, peer.reputation_score + adjustment)
    else:
        peer.failed_swaps += 1
        peer.reputation_score = max(0, peer.reputation_score - adjustment)

    peer.last_seen_at = datetime.utcnow()
