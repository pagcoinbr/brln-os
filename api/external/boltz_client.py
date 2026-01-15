"""
Boltz Backend Python Client for BRLN-OS

This module provides a Python wrapper around the Boltz Backend REST API,
enabling easy integration of atomic swaps (submarine, reverse submarine,
and chain swaps) into the BRLN-OS Flask application.

Boltz Backend Documentation: https://docs.boltz.exchange
"""

import requests
import json
import asyncio
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from enum import Enum


class SwapType(Enum):
    """Types of swaps supported by Boltz Backend"""
    SUBMARINE = "submarine"  # Chain → Lightning
    REVERSE_SUBMARINE = "reverse"  # Lightning → Chain
    CHAIN = "chain"  # Chain → Chain (BTC ↔ L-BTC)


class SwapStatus(Enum):
    """Swap status constants from Boltz Backend"""
    # Submarine swap statuses
    SWAP_CREATED = "swap.created"
    TRANSACTION_MEMPOOL = "transaction.mempool"
    TRANSACTION_CONFIRMED = "transaction.confirmed"
    INVOICE_SET = "invoice.set"
    INVOICE_PAID = "invoice.paid"
    INVOICE_FAILEDTOPAY = "invoice.failedToPay"
    TRANSACTION_CLAIMED = "transaction.claimed"
    SWAP_EXPIRED = "swap.expired"

    # Reverse submarine swap statuses
    MINERFEE_PAID = "minerfee.paid"
    INVOICE_SETTLED = "invoice.settled"
    INVOICE_EXPIRED = "invoice.expired"
    TRANSACTION_FAILED = "transaction.failed"


@dataclass
class BoltzSwapResponse:
    """Response from Boltz swap creation"""
    swap_id: str
    status: str
    raw_response: Dict[str, Any]


class BoltzClient:
    """
    Python client for Boltz Backend REST API

    Provides methods to:
    - Create submarine swaps (BTC/L-BTC → Lightning)
    - Create reverse submarine swaps (Lightning → BTC/L-BTC)
    - Create chain swaps (BTC ↔ L-BTC)
    - Query swap status
    - Subscribe to swap updates via WebSocket

    Example:
        >>> client = BoltzClient()
        >>> pairs = client.get_pairs()
        >>> swap = client.create_submarine_swap(
        ...     invoice="lnbc...",
        ...     from_chain="BTC",
        ...     to_chain="LN",
        ...     refund_pubkey="03abc..."
        ... )
        >>> status = client.get_swap_status(swap['id'])
    """

    def __init__(self, base_url: str = "http://localhost:9001"):
        """
        Initialize Boltz client

        Args:
            base_url: Base URL of Boltz Backend API (default: http://localhost:9001)
        """
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })

    def health_check(self) -> bool:
        """
        Check if Boltz Backend is responding

        Returns:
            True if API is healthy, False otherwise
        """
        try:
            response = self.session.get(f"{self.base_url}/version", timeout=5)
            return response.status_code == 200
        except:
            return False

    def get_version(self) -> Dict[str, str]:
        """
        Get Boltz Backend version information

        Returns:
            Dictionary with version info
        """
        response = self.session.get(f"{self.base_url}/version")
        response.raise_for_status()
        return response.json()

    def get_pairs(self) -> Dict[str, Any]:
        """
        Get supported trading pairs and their configurations

        Returns:
            Dictionary of trading pairs with rates, fees, and limits

        Example response:
            {
                "BTC/BTC": {
                    "rate": 1,
                    "fee": {
                        "percentage": 0.1,
                        "minerFees": {...}
                    },
                    "limits": {
                        "maximal": 100000000,
                        "minimal": 10000
                    }
                }
            }
        """
        response = self.session.get(f"{self.base_url}/v2/swap/pairs")
        response.raise_for_status()
        return response.json()

    def create_submarine_swap(
        self,
        invoice: str,
        from_chain: str = "BTC",
        to_chain: str = "LN",
        refund_pubkey: Optional[str] = None
    ) -> BoltzSwapResponse:
        """
        Create a submarine swap (on-chain → Lightning)

        User sends funds on-chain, receives Lightning payment

        Args:
            invoice: Lightning invoice (user receives payment here)
            from_chain: Source chain ('BTC' or 'L-BTC')
            to_chain: Destination (must be 'LN' for Lightning)
            refund_pubkey: Public key for refund if swap fails (hex format)

        Returns:
            BoltzSwapResponse with swap ID and details

        Example:
            >>> swap = client.create_submarine_swap(
            ...     invoice="lnbc10u1...",
            ...     from_chain="BTC",
            ...     refund_pubkey="03abc..."
            ... )
            >>> print(f"Send BTC to: {swap.raw_response['address']}")
            >>> print(f"Swap ID: {swap.swap_id}")
        """
        payload = {
            "invoice": invoice,
            "from": from_chain,
            "to": to_chain
        }

        if refund_pubkey:
            payload["refundPublicKey"] = refund_pubkey

        response = self.session.post(
            f"{self.base_url}/v2/swap/submarine",
            json=payload
        )
        response.raise_for_status()
        data = response.json()

        return BoltzSwapResponse(
            swap_id=data.get('id'),
            status=data.get('status', 'swap.created'),
            raw_response=data
        )

    def create_reverse_swap(
        self,
        invoice_amount: int,
        from_chain: str = "LN",
        to_chain: str = "BTC",
        claim_pubkey: Optional[str] = None,
        preimage_hash: Optional[str] = None
    ) -> BoltzSwapResponse:
        """
        Create a reverse submarine swap (Lightning → on-chain)

        User pays Lightning invoice, receives on-chain funds

        Args:
            invoice_amount: Amount in satoshis to receive on-chain
            from_chain: Source (must be 'LN' for Lightning)
            to_chain: Destination chain ('BTC' or 'L-BTC')
            claim_pubkey: Public key for claiming on-chain funds (hex format)
            preimage_hash: Optional preimage hash (generated if not provided)

        Returns:
            BoltzSwapResponse with swap ID and invoice to pay

        Example:
            >>> swap = client.create_reverse_swap(
            ...     invoice_amount=100000,  # 100k sats
            ...     to_chain="BTC",
            ...     claim_pubkey="03xyz..."
            ... )
            >>> print(f"Pay invoice: {swap.raw_response['invoice']}")
            >>> print(f"Claim from: {swap.raw_response['claimAddress']}")
        """
        payload = {
            "invoiceAmount": invoice_amount,
            "from": from_chain,
            "to": to_chain
        }

        if claim_pubkey:
            payload["claimPublicKey"] = claim_pubkey

        if preimage_hash:
            payload["preimageHash"] = preimage_hash

        response = self.session.post(
            f"{self.base_url}/v2/swap/reverse",
            json=payload
        )
        response.raise_for_status()
        data = response.json()

        return BoltzSwapResponse(
            swap_id=data.get('id'),
            status=data.get('status', 'swap.created'),
            raw_response=data
        )

    def create_chain_swap(
        self,
        lock_amount: int,
        from_chain: str = "BTC",
        to_chain: str = "L-BTC",
        claim_pubkey: Optional[str] = None,
        refund_pubkey: Optional[str] = None
    ) -> BoltzSwapResponse:
        """
        Create a chain swap (BTC ↔ L-BTC)

        Atomic swap between Bitcoin and Liquid chains

        Args:
            lock_amount: Amount in satoshis to lock on source chain
            from_chain: Source chain ('BTC' or 'L-BTC')
            to_chain: Destination chain ('L-BTC' or 'BTC')
            claim_pubkey: Public key for claiming destination funds
            refund_pubkey: Public key for refunding source funds if needed

        Returns:
            BoltzSwapResponse with swap ID and lockup details

        Example:
            >>> swap = client.create_chain_swap(
            ...     lock_amount=1000000,  # 0.01 BTC
            ...     from_chain="BTC",
            ...     to_chain="L-BTC",
            ...     claim_pubkey="03xyz..."
            ... )
            >>> print(f"BTC lockup: {swap.raw_response['lockupDetails']}")
            >>> print(f"L-BTC claim: {swap.raw_response['claimDetails']}")
        """
        payload = {
            "lockAmount": lock_amount,
            "from": from_chain,
            "to": to_chain
        }

        if claim_pubkey:
            payload["claimPublicKey"] = claim_pubkey

        if refund_pubkey:
            payload["refundPublicKey"] = refund_pubkey

        response = self.session.post(
            f"{self.base_url}/v2/swap/chain",
            json=payload
        )
        response.raise_for_status()
        data = response.json()

        return BoltzSwapResponse(
            swap_id=data.get('id'),
            status=data.get('status', 'swap.created'),
            raw_response=data
        )

    def get_swap_status(self, swap_id: str) -> Dict[str, Any]:
        """
        Query status of an existing swap

        Args:
            swap_id: Swap identifier

        Returns:
            Dictionary with swap status and details

        Example response:
            {
                'status': 'transaction.confirmed',
                'transaction': {
                    'id': 'abc123...',
                    'hex': '...'
                },
                'invoice': {...}
            }
        """
        response = self.session.get(f"{self.base_url}/swap/{swap_id}")
        response.raise_for_status()
        return response.json()

    def get_swap_claim_details(
        self,
        swap_id: str,
        swap_type: SwapType
    ) -> Dict[str, Any]:
        """
        Get claim transaction details for cooperative signature

        Args:
            swap_id: Swap identifier
            swap_type: Type of swap (submarine, reverse, or chain)

        Returns:
            Dictionary with claim transaction details
        """
        response = self.session.get(
            f"{self.base_url}/v2/swap/{swap_type.value}/{swap_id}/claim"
        )
        response.raise_for_status()
        return response.json()

    async def subscribe_swap_updates(
        self,
        swap_id: str,
        callback: callable
    ):
        """
        Subscribe to real-time swap updates via WebSocket

        Args:
            swap_id: Swap identifier to monitor
            callback: Async function called on status updates
                     Signature: async def callback(update: dict)

        Example:
            >>> async def on_update(update):
            ...     print(f"New status: {update['status']}")
            ...
            >>> await client.subscribe_swap_updates(
            ...     swap_id="abc123",
            ...     callback=on_update
            ... )
        """
        try:
            import websockets

            ws_url = self.base_url.replace('http://', 'ws://').replace('https://', 'wss://')

            async with websockets.connect(f"{ws_url}/v2/ws") as ws:
                # Subscribe to swap updates
                subscribe_msg = {
                    "op": "subscribe",
                    "channel": "swap.update",
                    "args": [swap_id]
                }
                await ws.send(json.dumps(subscribe_msg))

                # Listen for updates
                async for message in ws:
                    data = json.loads(message)
                    await callback(data)

        except ImportError:
            raise ImportError(
                "websockets library required for WebSocket support. "
                "Install with: pip install websockets"
            )


# ============================================================================
# SINGLETON INSTANCE
# ============================================================================

_boltz_client_instance = None


def get_boltz_client(base_url: str = "http://localhost:9001") -> BoltzClient:
    """
    Get singleton instance of Boltz client

    Args:
        base_url: Base URL of Boltz Backend API

    Returns:
        BoltzClient instance (singleton)

    Example:
        >>> client = get_boltz_client()
        >>> pairs = client.get_pairs()
    """
    global _boltz_client_instance

    if _boltz_client_instance is None:
        _boltz_client_instance = BoltzClient(base_url)

    return _boltz_client_instance


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_swap_complete(status: str) -> bool:
    """
    Check if swap has reached a terminal state

    Args:
        status: Swap status string

    Returns:
        True if swap is complete (success or failure), False otherwise
    """
    terminal_statuses = {
        SwapStatus.TRANSACTION_CLAIMED.value,
        SwapStatus.INVOICE_SETTLED.value,
        SwapStatus.SWAP_EXPIRED.value,
        SwapStatus.INVOICE_EXPIRED.value,
        SwapStatus.INVOICE_FAILEDTOPAY.value,
        SwapStatus.TRANSACTION_FAILED.value
    }
    return status in terminal_statuses


def is_swap_successful(status: str) -> bool:
    """
    Check if swap completed successfully

    Args:
        status: Swap status string

    Returns:
        True if swap completed successfully, False otherwise
    """
    success_statuses = {
        SwapStatus.TRANSACTION_CLAIMED.value,
        SwapStatus.INVOICE_SETTLED.value
    }
    return status in success_statuses
