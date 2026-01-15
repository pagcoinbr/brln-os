"""
P2P Network Layer for BRLN-OS Decentralized Atomic Swap Exchange

This module provides peer-to-peer networking capabilities for discovering
and coordinating with other BRLN-OS nodes for atomic swaps.

Components:
- tor_integration: Tor hidden service management
- discovery: Peer discovery via Tor and Lightning gossip
- gossip: Gossip protocol for liquidity advertisement
- p2p_swap_coordinator: P2P swap negotiation and coordination
"""

from .tor_integration import TorIntegration, get_tor_client
from .discovery import PeerDiscovery, PeerInfo
from .gossip import GossipProtocol, GossipMessage, MessageType
from .p2p_swap_coordinator import P2PSwapCoordinator, SwapProposal

__all__ = [
    'TorIntegration',
    'get_tor_client',
    'PeerDiscovery',
    'PeerInfo',
    'GossipProtocol',
    'GossipMessage',
    'MessageType',
    'P2PSwapCoordinator',
    'SwapProposal'
]
