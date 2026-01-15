"""
Tor Integration for BRLN-OS P2P Network

Provides Tor hidden service management for peer-to-peer atomic swap coordination.
Enables anonymous peer discovery and communication over the Tor network.

Features:
- Create ephemeral hidden services
- Connect to peer hidden services via SOCKS5 proxy
- Manage Tor controller connection
- Handle Tor authentication
"""

import socket
import socks
import logging
from typing import Optional, Tuple
from dataclasses import dataclass

try:
    from stem import Signal
    from stem.control import Controller
    from stem.socket import ControlPort
except ImportError:
    raise ImportError(
        "stem library required for Tor integration. "
        "Install with: pip install stem"
    )

logger = logging.getLogger(__name__)


@dataclass
class TorHiddenService:
    """Represents a Tor hidden service"""
    onion_address: str
    service_id: str
    local_port: int
    onion_port: int = 80


class TorIntegration:
    """
    Tor integration for BRLN-OS P2P network
    
    Manages Tor hidden services for exposing swap API endpoints
    and connects to other peers via Tor SOCKS5 proxy.
    
    Example:
        >>> tor = TorIntegration()
        >>> onion_addr = tor.create_hidden_service(local_port=2121)
        >>> print(f"Hidden service: {onion_addr}")
        >>> 
        >>> # Connect to peer
        >>> sock = tor.connect_to_peer("abc123.onion", 80)
        >>> sock.send(b"Hello peer!")
    """
    
    def __init__(
        self,
        control_port: int = 9051,
        socks_port: int = 9050,
        tor_password: Optional[str] = None
    ):
        """
        Initialize Tor integration
        
        Args:
            control_port: Tor control port (default: 9051)
            socks_port: Tor SOCKS5 proxy port (default: 9050)
            tor_password: Tor control password (optional, uses cookie auth if None)
        """
        self.control_port = control_port
        self.socks_port = socks_port
        self.tor_password = tor_password
        self.controller: Optional[Controller] = None
        self.hidden_services = {}
        
    def connect_controller(self) -> Controller:
        """
        Connect to Tor controller
        
        Returns:
            Controller instance
            
        Raises:
            ConnectionError: If unable to connect to Tor
        """
        try:
            self.controller = Controller.from_port(port=self.control_port)
            
            # Authenticate
            if self.tor_password:
                self.controller.authenticate(password=self.tor_password)
            else:
                # Try cookie authentication (default for Tor)
                self.controller.authenticate()
            
            logger.info("✅ Connected to Tor controller")
            return self.controller
            
        except Exception as e:
            logger.error(f"❌ Failed to connect to Tor controller: {e}")
            raise ConnectionError(
                f"Unable to connect to Tor control port {self.control_port}. "
                "Ensure Tor is running and ControlPort is enabled."
            ) from e
    
    def create_hidden_service(
        self,
        local_port: int,
        onion_port: int = 80
    ) -> str:
        """
        Create an ephemeral Tor hidden service
        
        The hidden service maps .onion:onion_port -> localhost:local_port
        
        Args:
            local_port: Local port to expose (e.g., 2121 for BRLN API)
            onion_port: Port on .onion address (default: 80)
            
        Returns:
            .onion address (e.g., "abc123xyz.onion")
            
        Example:
            >>> onion_addr = tor.create_hidden_service(local_port=2121, onion_port=80)
            >>> # Now accessible at: http://<onion_addr>:80
        """
        if not self.controller:
            self.connect_controller()
        
        try:
            # Create ephemeral hidden service (v3 onion)
            response = self.controller.create_ephemeral_hidden_service(
                ports={onion_port: local_port},
                await_publication=True,  # Wait for descriptor to be published
                detached=False  # Service removed when controller disconnects
            )
            
            service_id = response.service_id
            onion_address = f"{service_id}.onion"
            
            # Store hidden service info
            hidden_service = TorHiddenService(
                onion_address=onion_address,
                service_id=service_id,
                local_port=local_port,
                onion_port=onion_port
            )
            self.hidden_services[service_id] = hidden_service
            
            logger.info(f"✅ Hidden service created: {onion_address}")
            logger.info(f"   Mapping: {onion_address}:{onion_port} -> localhost:{local_port}")
            
            return onion_address
            
        except Exception as e:
            logger.error(f"❌ Failed to create hidden service: {e}")
            raise
    
    def remove_hidden_service(self, service_id: str):
        """
        Remove an ephemeral hidden service
        
        Args:
            service_id: Service ID (without .onion)
        """
        if not self.controller:
            logger.warning("No controller connection")
            return
        
        try:
            self.controller.remove_ephemeral_hidden_service(service_id)
            
            if service_id in self.hidden_services:
                del self.hidden_services[service_id]
            
            logger.info(f"✅ Hidden service removed: {service_id}.onion")
            
        except Exception as e:
            logger.error(f"❌ Failed to remove hidden service: {e}")
    
    def connect_to_peer(
        self,
        onion_address: str,
        port: int = 80,
        timeout: int = 30
    ) -> socket.socket:
        """
        Connect to a peer's Tor hidden service via SOCKS5 proxy
        
        Args:
            onion_address: Peer's .onion address (with or without .onion suffix)
            port: Port on peer's hidden service (default: 80)
            timeout: Connection timeout in seconds (default: 30)
            
        Returns:
            Connected socket
            
        Example:
            >>> sock = tor.connect_to_peer("abc123.onion", 80)
            >>> sock.send(b"GET /api/v1/peers HTTP/1.1\r\n\r\n")
            >>> response = sock.recv(4096)
        """
        # Ensure .onion suffix
        if not onion_address.endswith('.onion'):
            onion_address = f"{onion_address}.onion"
        
        try:
            # Create SOCKS5 socket
            sock = socks.socksocket()
            sock.set_proxy(
                socks.SOCKS5,
                "127.0.0.1",
                self.socks_port
            )
            sock.settimeout(timeout)
            
            # Connect via Tor
            logger.info(f"🔗 Connecting to {onion_address}:{port} via Tor...")
            sock.connect((onion_address, port))
            logger.info(f"✅ Connected to {onion_address}:{port}")
            
            return sock
            
        except socket.timeout:
            logger.error(f"⏱️  Timeout connecting to {onion_address}:{port}")
            raise
        except Exception as e:
            logger.error(f"❌ Failed to connect to {onion_address}:{port}: {e}")
            raise
    
    def get_tor_info(self) -> dict:
        """
        Get Tor daemon information
        
        Returns:
            Dictionary with Tor version, status, and configuration
        """
        if not self.controller:
            self.connect_controller()
        
        try:
            info = {
                'version': self.controller.get_version().version_str,
                'is_alive': self.controller.is_alive(),
                'socks_port': self.socks_port,
                'control_port': self.control_port,
                'hidden_services': len(self.hidden_services)
            }
            
            return info
            
        except Exception as e:
            logger.error(f"Failed to get Tor info: {e}")
            return {}
    
    def new_identity(self):
        """
        Request a new Tor identity (new circuits)
        
        Useful for changing exit node or resetting circuits
        """
        if not self.controller:
            self.connect_controller()
        
        try:
            self.controller.signal(Signal.NEWNYM)
            logger.info("✅ Requested new Tor identity")
        except Exception as e:
            logger.error(f"❌ Failed to request new identity: {e}")
    
    def close(self):
        """Close Tor controller connection and remove hidden services"""
        if self.controller:
            # Remove all ephemeral hidden services
            for service_id in list(self.hidden_services.keys()):
                self.remove_hidden_service(service_id)
            
            # Close controller
            self.controller.close()
            self.controller = None
            logger.info("✅ Tor controller connection closed")
    
    def __enter__(self):
        """Context manager entry"""
        self.connect_controller()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()


# ============================================================================
# SINGLETON INSTANCE
# ============================================================================

_tor_client_instance = None


def get_tor_client(
    control_port: int = 9051,
    socks_port: int = 9050
) -> TorIntegration:
    """
    Get singleton instance of Tor integration
    
    Args:
        control_port: Tor control port (default: 9051)
        socks_port: Tor SOCKS5 proxy port (default: 9050)
        
    Returns:
        TorIntegration instance (singleton)
        
    Example:
        >>> tor = get_tor_client()
        >>> onion_addr = tor.create_hidden_service(local_port=2121)
    """
    global _tor_client_instance
    
    if _tor_client_instance is None:
        _tor_client_instance = TorIntegration(
            control_port=control_port,
            socks_port=socks_port
        )
    
    return _tor_client_instance


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def is_tor_running() -> bool:
    """
    Check if Tor daemon is running
    
    Returns:
        True if Tor is accessible, False otherwise
    """
    try:
        controller = Controller.from_port(port=9051)
        controller.authenticate()
        controller.close()
        return True
    except:
        return False


def get_lnd_onion_address() -> Optional[str]:
    """
    Get LND's onion address from LND config or runtime
    
    Returns:
        LND's .onion address if available, None otherwise
    """
    # Try to read from LND config
    try:
        import configparser
        config = configparser.ConfigParser()
        config.read('/home/lnd/.lnd/lnd.conf')
        
        if 'tor' in config:
            # LND advertises onion address
            # This is typically auto-generated by LND
            pass
        
        # Alternative: query LND via gRPC for its onion URI
        # This would require LND gRPC client
        
    except:
        pass
    
    return None
