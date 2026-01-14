"""
Payment Monitor for Atomic Swaps.

Provides asynchronous monitoring of Lightning invoice payments.
Uses gRPC streaming to detect invoice settlements in real-time.

This is critical for atomic swaps: we need to detect when the Lightning
invoice is paid (revealing the preimage) so we can claim the on-chain HTLC.
"""

import asyncio
import logging
from typing import Callable, Dict, Any, Optional, Set
from datetime import datetime
import threading

from api.lnd.client import get_lnd_client, AtomicSwapLNDClient

logger = logging.getLogger(__name__)


class InvoiceUpdate:
    """
    Represents an invoice update event.

    Simplified wrapper around the gRPC invoice update message.
    """

    def __init__(self, invoice_data: Dict[str, Any]):
        """
        Initialize from invoice data.

        Args:
            invoice_data: Dictionary with invoice fields from gRPC
        """
        self.payment_hash = invoice_data.get('r_hash', '').hex() if isinstance(invoice_data.get('r_hash'), bytes) else invoice_data.get('r_hash', '')
        self.preimage = invoice_data.get('r_preimage', '').hex() if isinstance(invoice_data.get('r_preimage'), bytes) else invoice_data.get('r_preimage')
        self.settled = invoice_data.get('settled', False)
        self.state = invoice_data.get('state', 'UNKNOWN')
        self.amount_sat = int(invoice_data.get('value', 0))
        self.amount_paid_sat = int(invoice_data.get('amt_paid_sat', 0))
        self.memo = invoice_data.get('memo', '')
        self.settled_at = invoice_data.get('settle_date')
        self.created_at = invoice_data.get('creation_date')

    def __repr__(self):
        return (
            f"InvoiceUpdate(hash={self.payment_hash[:16]}..., "
            f"settled={self.settled}, state={self.state})"
        )


class PaymentMonitor:
    """
    Async payment monitor for atomic swaps.

    Monitors Lightning invoices and triggers callbacks when they are settled.
    Uses gRPC streaming for real-time updates.

    Usage:
        monitor = PaymentMonitor()

        def on_payment(update: InvoiceUpdate):
            print(f"Invoice paid! Preimage: {update.preimage}")

        monitor.watch_invoice(payment_hash, on_payment)
        monitor.start()
    """

    def __init__(self, lnd_client: Optional[AtomicSwapLNDClient] = None):
        """
        Initialize payment monitor.

        Args:
            lnd_client: Optional LND client (uses singleton if not provided)
        """
        self.lnd_client = lnd_client or get_lnd_client()
        self.watchers: Dict[str, Callable] = {}  # payment_hash -> callback
        self.running = False
        self.monitor_thread: Optional[threading.Thread] = None
        self._lock = threading.Lock()
        logger.info("PaymentMonitor initialized")

    def watch_invoice(
        self,
        payment_hash: str,
        callback: Callable[[InvoiceUpdate], None]
    ) -> None:
        """
        Watch an invoice for payment.

        When the invoice is settled, the callback will be invoked with
        the invoice update containing the preimage.

        Args:
            payment_hash: Hex-encoded payment hash to watch
            callback: Function to call when invoice is settled
                     Signature: callback(update: InvoiceUpdate) -> None
        """
        with self._lock:
            self.watchers[payment_hash] = callback
            logger.info(f"Now watching invoice: {payment_hash[:16]}...")

    def unwatch_invoice(self, payment_hash: str) -> None:
        """
        Stop watching an invoice.

        Args:
            payment_hash: Hex-encoded payment hash
        """
        with self._lock:
            if payment_hash in self.watchers:
                del self.watchers[payment_hash]
                logger.info(f"Stopped watching invoice: {payment_hash[:16]}...")

    def start(self) -> bool:
        """
        Start the payment monitor in a background thread.

        Returns:
            True if started successfully
        """
        if self.running:
            logger.warning("Payment monitor already running")
            return False

        self.running = True
        self.monitor_thread = threading.Thread(
            target=self._monitor_loop,
            daemon=True,
            name="PaymentMonitor"
        )
        self.monitor_thread.start()
        logger.info("Payment monitor started")
        return True

    def stop(self) -> None:
        """Stop the payment monitor."""
        self.running = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=5)
        logger.info("Payment monitor stopped")

    def _monitor_loop(self) -> None:
        """
        Main monitoring loop (runs in background thread).

        Subscribes to invoice updates and dispatches callbacks.
        """
        logger.info("Payment monitor loop starting...")

        while self.running:
            try:
                # Subscribe to invoice updates
                stream, error = self.lnd_client.subscribe_invoice(
                    payment_hash=bytes(32),  # Dummy hash (we subscribe to all)
                    timeout=3600
                )

                if error:
                    logger.error(f"Error subscribing to invoices: {error}")
                    if self.running:
                        # Wait before retry
                        import time
                        time.sleep(5)
                    continue

                # Process invoice updates
                for invoice in stream:
                    if not self.running:
                        break

                    try:
                        # Convert gRPC invoice to dict
                        invoice_dict = self._grpc_invoice_to_dict(invoice)
                        update = InvoiceUpdate(invoice_dict)

                        # Check if we're watching this invoice
                        with self._lock:
                            callback = self.watchers.get(update.payment_hash)

                        if callback and update.settled:
                            logger.info(
                                f"Invoice settled! {update.payment_hash[:16]}... "
                                f"Preimage: {update.preimage[:16] if update.preimage else 'N/A'}..."
                            )

                            try:
                                callback(update)
                            except Exception as e:
                                logger.error(
                                    f"Error in invoice callback: {str(e)}",
                                    exc_info=True
                                )

                            # Remove watcher after callback
                            with self._lock:
                                self.watchers.pop(update.payment_hash, None)

                    except Exception as e:
                        logger.error(
                            f"Error processing invoice update: {str(e)}",
                            exc_info=True
                        )

            except Exception as e:
                logger.error(f"Error in monitor loop: {str(e)}", exc_info=True)
                if self.running:
                    # Wait before retry
                    import time
                    time.sleep(5)

        logger.info("Payment monitor loop stopped")

    def _grpc_invoice_to_dict(self, invoice) -> Dict[str, Any]:
        """
        Convert gRPC invoice message to dictionary.

        Args:
            invoice: gRPC Invoice message

        Returns:
            Dictionary with invoice fields
        """
        return {
            'r_hash': invoice.r_hash,
            'r_preimage': invoice.r_preimage if invoice.r_preimage else None,
            'settled': invoice.settled,
            'state': invoice.state,
            'value': invoice.value,
            'amt_paid_sat': invoice.amt_paid_sat,
            'amt_paid_msat': invoice.amt_paid_msat,
            'memo': invoice.memo,
            'creation_date': invoice.creation_date,
            'settle_date': invoice.settle_date if invoice.settle_date else None
        }

    def get_active_watches(self) -> Set[str]:
        """
        Get the set of payment hashes currently being watched.

        Returns:
            Set of hex-encoded payment hashes
        """
        with self._lock:
            return set(self.watchers.keys())

    def is_watching(self, payment_hash: str) -> bool:
        """
        Check if a payment hash is being watched.

        Args:
            payment_hash: Hex-encoded payment hash

        Returns:
            True if being watched
        """
        with self._lock:
            return payment_hash in self.watchers


class AsyncPaymentMonitor:
    """
    Async version of PaymentMonitor using asyncio.

    Provides async/await interface for monitoring invoice payments.

    Usage:
        monitor = AsyncPaymentMonitor()
        await monitor.start()

        async def on_payment(update: InvoiceUpdate):
            print(f"Invoice paid! Preimage: {update.preimage}")

        await monitor.watch_invoice(payment_hash, on_payment)
    """

    def __init__(self, lnd_client: Optional[AtomicSwapLNDClient] = None):
        """
        Initialize async payment monitor.

        Args:
            lnd_client: Optional LND client
        """
        self.lnd_client = lnd_client or get_lnd_client()
        self.watchers: Dict[str, Callable] = {}
        self.running = False
        self.monitor_task: Optional[asyncio.Task] = None
        logger.info("AsyncPaymentMonitor initialized")

    async def watch_invoice(
        self,
        payment_hash: str,
        callback: Callable[[InvoiceUpdate], Any]
    ) -> None:
        """
        Watch an invoice for payment (async).

        Args:
            payment_hash: Hex-encoded payment hash
            callback: Async or sync callback function
        """
        self.watchers[payment_hash] = callback
        logger.info(f"Now watching invoice (async): {payment_hash[:16]}...")

    async def start(self) -> None:
        """Start the async payment monitor."""
        if self.running:
            logger.warning("Async payment monitor already running")
            return

        self.running = True
        self.monitor_task = asyncio.create_task(self._monitor_loop())
        logger.info("Async payment monitor started")

    async def stop(self) -> None:
        """Stop the async payment monitor."""
        self.running = False
        if self.monitor_task:
            self.monitor_task.cancel()
            try:
                await self.monitor_task
            except asyncio.CancelledError:
                pass
        logger.info("Async payment monitor stopped")

    async def _monitor_loop(self) -> None:
        """
        Main async monitoring loop.

        This uses threading + asyncio hybrid since gRPC streaming
        is synchronous.
        """
        logger.info("Async payment monitor loop starting...")

        # Run sync monitoring in executor
        loop = asyncio.get_event_loop()

        def sync_monitor():
            """Sync monitor that can be run in executor."""
            monitor = PaymentMonitor(self.lnd_client)

            # Copy watchers
            for payment_hash, callback in self.watchers.items():
                # Wrap async callback if needed
                def make_wrapper(cb):
                    def wrapper(update):
                        if asyncio.iscoroutinefunction(cb):
                            asyncio.run_coroutine_threadsafe(cb(update), loop)
                        else:
                            cb(update)
                    return wrapper

                monitor.watch_invoice(payment_hash, make_wrapper(callback))

            monitor.start()

            # Keep running while monitor is active
            while self.running and monitor.running:
                import time
                time.sleep(1)

            monitor.stop()

        # Run in executor
        await loop.run_in_executor(None, sync_monitor)

        logger.info("Async payment monitor loop stopped")


# Singleton instances
_payment_monitor_instance = None
_async_payment_monitor_instance = None


def get_payment_monitor() -> PaymentMonitor:
    """
    Get or create the global payment monitor instance.

    Returns:
        PaymentMonitor instance
    """
    global _payment_monitor_instance
    if _payment_monitor_instance is None:
        _payment_monitor_instance = PaymentMonitor()
    return _payment_monitor_instance


def get_async_payment_monitor() -> AsyncPaymentMonitor:
    """
    Get or create the global async payment monitor instance.

    Returns:
        AsyncPaymentMonitor instance
    """
    global _async_payment_monitor_instance
    if _async_payment_monitor_instance is None:
        _async_payment_monitor_instance = AsyncPaymentMonitor()
    return _async_payment_monitor_instance
