#!/usr/bin/env python3
"""
Cliente Python gRPC para Lightning Network Daemon (LND) e Elements
Versão aprimorada com suporte a arquivo de configuração
Exibe saldos Lightning, on-chain Bitcoin e Liquid
"""

import lightning_pb2 as ln
import lightning_pb2_grpc as lnrpc
import grpc
import os
import json
import sys
import requests
import configparser
from typing import Dict, Any, Optional
import logging
from datetime import datetime

class ConfigManager:
    """Gerenciador de configurações"""
    
    def __init__(self, config_file: str = "lnd_client_config.ini"):
        self.config_file = config_file
        self.config = configparser.ConfigParser()
        self.load_config()
    
    def load_config(self):
        """Carrega configurações do arquivo INI"""
        if os.path.exists(self.config_file):
            self.config.read(self.config_file)
        else:
            # Criar configuração padrão se não existir
            self.create_default_config()
    
    def create_default_config(self):
        """Cria arquivo de configuração padrão"""
        self.config['LND'] = {
            'host': 'localhost',
            'port': '10009',
            'tls_cert_path': '/data/lnd/tls.cert',
            'macaroon_path': '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
        }
        
        self.config['ELEMENTS'] = {
            'host': 'localhost',
            'port': '18884',
            'rpc_user': 'elementsuser',
            'rpc_password': 'elementspassword123'
        }
        
        self.config['DISPLAY'] = {
            'show_pubkey_full': 'false',
            'show_millisats': 'false',
            'currency_format': 'BTC',
            'decimal_places': '8'
        }
        
        self.config['LOGGING'] = {
            'level': 'INFO',
            'format': '%(asctime)s - %(levelname)s - %(message)s',
            'file': 'lnd_client.log'
        }
        
        with open(self.config_file, 'w') as f:
            self.config.write(f)
    
    def get(self, section: str, key: str, fallback: Any = None):
        """Obtém valor da configuração"""
        return self.config.get(section, key, fallback=fallback)
    
    def getint(self, section: str, key: str, fallback: int = 0):
        """Obtém valor inteiro da configuração"""
        return self.config.getint(section, key, fallback=fallback)
    
    def getboolean(self, section: str, key: str, fallback: bool = False):
        """Obtém valor booleano da configuração"""
        return self.config.getboolean(section, key, fallback=fallback)

class LNDClient:
    """Cliente para conectar com LND via gRPC"""
    
    def __init__(self, config_manager: ConfigManager):
        self.config = config_manager
        self.host = self.config.get('LND', 'host', 'localhost')
        self.port = self.config.getint('LND', 'port', 10009)
        self.tls_cert_path = self.config.get('LND', 'tls_cert_path')
        self.macaroon_path = self.config.get('LND', 'macaroon_path')
        self.channel = None
        self.stub = None
        
        # Configurar cipher suites para ECDSA
        os.environ["GRPC_SSL_CIPHER_SUITES"] = 'HIGH+ECDSA'
        
        # Setup logging
        log_level = getattr(logging, self.config.get('LOGGING', 'level', 'INFO'))
        log_format = self.config.get('LOGGING', 'format')
        log_file = self.config.get('LOGGING', 'file')
        
        logging.basicConfig(
            level=log_level, 
            format=log_format,
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def connect(self) -> bool:
        """Estabelece conexão com o LND"""
        try:
            # Ler certificado TLS
            if os.path.exists(self.tls_cert_path):
                with open(self.tls_cert_path, 'rb') as f:
                    cert = f.read()
            else:
                self.logger.error(f"Certificado TLS não encontrado em: {self.tls_cert_path}")
                return False
                
            # Ler macaroon para autenticação
            if os.path.exists(self.macaroon_path):
                with open(self.macaroon_path, 'rb') as f:
                    macaroon_bytes = f.read()
                    self.macaroon = macaroon_bytes.hex()
            else:
                self.logger.warning(f"Macaroon não encontrado em: {self.macaroon_path}")
                self.macaroon = None
            
            # Criar canal seguro
            creds = grpc.ssl_channel_credentials(cert)
            self.channel = grpc.secure_channel(f'{self.host}:{self.port}', creds)
            self.stub = lnrpc.LightningStub(self.channel)
            
            # Testar conexão
            request = ln.GetInfoRequest()
            metadata = self.get_macaroon_metadata()
            response = self.stub.GetInfo(request, metadata=metadata)
                
            self.logger.info(f"Conectado ao LND: {response.alias} - Versão: {response.version}")
            return True
            
        except Exception as e:
            self.logger.error(f"Erro ao conectar com LND: {e}")
            return False
    
    def get_macaroon_metadata(self) -> list:
        """Retorna metadados do macaroon se disponível"""
        if hasattr(self, 'macaroon') and self.macaroon:
            return [('macaroon', self.macaroon)]
        return []
    
    def get_wallet_balance(self) -> Dict[str, Any]:
        """Obtém saldo on-chain da carteira"""
        try:
            request = ln.WalletBalanceRequest()
            metadata = self.get_macaroon_metadata()
            response = self.stub.WalletBalance(request, metadata=metadata)
            
            return {
                "total_balance": int(response.total_balance),
                "confirmed_balance": int(response.confirmed_balance),
                "unconfirmed_balance": int(response.unconfirmed_balance)
            }
        except Exception as e:
            self.logger.error(f"Erro ao obter saldo da carteira: {e}")
            return {}
    
    def get_channel_balance(self) -> Dict[str, Any]:
        """Obtém saldo dos canais Lightning"""
        try:
            request = ln.ChannelBalanceRequest()
            metadata = self.get_macaroon_metadata()
            response = self.stub.ChannelBalance(request, metadata=metadata)
            
            return {
                "balance": int(response.balance),
                "pending_open_balance": int(response.pending_open_balance),
                "local_balance": {
                    "sat": int(response.local_balance.sat),
                    "msat": int(response.local_balance.msat)
                },
                "remote_balance": {
                    "sat": int(response.remote_balance.sat),
                    "msat": int(response.remote_balance.msat)
                },
                "unsettled_local_balance": {
                    "sat": int(response.unsettled_local_balance.sat),
                    "msat": int(response.unsettled_local_balance.msat)
                },
                "unsettled_remote_balance": {
                    "sat": int(response.unsettled_remote_balance.sat),
                    "msat": int(response.unsettled_remote_balance.msat)
                }
            }
        except Exception as e:
            self.logger.error(f"Erro ao obter saldo dos canais: {e}")
            return {}
    
    def get_node_info(self) -> Dict[str, Any]:
        """Obtém informações do nó"""
        try:
            request = ln.GetInfoRequest()
            metadata = self.get_macaroon_metadata()
            response = self.stub.GetInfo(request, metadata=metadata)
            
            return {
                "alias": response.alias,
                "identity_pubkey": response.identity_pubkey,
                "version": response.version,
                "num_active_channels": response.num_active_channels,
                "num_pending_channels": response.num_pending_channels,
                "num_peers": response.num_peers,
                "synced_to_chain": response.synced_to_chain,
                "synced_to_graph": response.synced_to_graph,
                "block_height": response.block_height,
                "block_hash": response.block_hash,
                "testnet": response.testnet,
                "chains": [{"chain": chain.chain, "network": chain.network} for chain in response.chains]
            }
        except Exception as e:
            self.logger.error(f"Erro ao obter informações do nó: {e}")
            return {}
    
    def get_channels(self) -> Dict[str, Any]:
        """Obtém lista de canais"""
        try:
            request = ln.ListChannelsRequest()
            metadata = self.get_macaroon_metadata()
            response = self.stub.ListChannels(request, metadata=metadata)
            
            channels = []
            for channel in response.channels:
                channels.append({
                    "active": channel.active,
                    "remote_pubkey": channel.remote_pubkey,
                    "channel_point": channel.channel_point,
                    "capacity": int(channel.capacity),
                    "local_balance": int(channel.local_balance),
                    "remote_balance": int(channel.remote_balance),
                    "commit_fee": int(channel.commit_fee),
                    "fee_per_kw": int(channel.fee_per_kw),
                    "unsettled_balance": int(channel.unsettled_balance),
                    "total_satoshis_sent": int(channel.total_satoshis_sent),
                    "total_satoshis_received": int(channel.total_satoshis_received),
                    "num_updates": int(channel.num_updates),
                    "private": channel.private
                })
            
            return {"channels": channels, "total_channels": len(channels)}
        except Exception as e:
            self.logger.error(f"Erro ao obter lista de canais: {e}")
            return {}
    
    def close(self):
        """Fecha a conexão"""
        if self.channel:
            self.channel.close()

class ElementsClient:
    """Cliente para conectar com Elements via RPC"""
    
    def __init__(self, config_manager: ConfigManager):
        self.config = config_manager
        self.host = self.config.get('ELEMENTS', 'host', 'localhost')
        self.port = self.config.getint('ELEMENTS', 'port', 18884)
        self.rpc_user = self.config.get('ELEMENTS', 'rpc_user', 'elementsuser')
        self.rpc_password = self.config.get('ELEMENTS', 'rpc_password', 'elementspassword123')
        self.rpc_url = f"http://{self.host}:{self.port}"
        
        self.logger = logging.getLogger(__name__)
    
    def rpc_call(self, method: str, params: list = None) -> Optional[Dict]:
        """Faz uma chamada RPC para o Elements"""
        if params is None:
            params = []
            
        payload = {
            "jsonrpc": "2.0",
            "id": "python-client",
            "method": method,
            "params": params
        }
        
        try:
            response = requests.post(
                self.rpc_url,
                json=payload,
                auth=(self.rpc_user, self.rpc_password),
                timeout=30
            )
            response.raise_for_status()
            result = response.json()
            
            if "error" in result and result["error"]:
                self.logger.error(f"RPC Error: {result['error']}")
                return None
                
            return result.get("result")
            
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Erro na chamada RPC para Elements: {e}")
            return None
    
    def test_connection(self) -> bool:
        """Testa conexão com Elements"""
        result = self.rpc_call("getblockchaininfo")
        return result is not None
    
    def get_wallet_info(self) -> Dict[str, Any]:
        """Obtém informações da carteira Elements"""
        try:
            result = self.rpc_call("getwalletinfo")
            if result:
                return {
                    "balance": result.get("balance", {}),
                    "unconfirmed_balance": result.get("unconfirmed_balance", {}),
                    "immature_balance": result.get("immature_balance", {}),
                    "txcount": result.get("txcount", 0),
                    "keypoolsize": result.get("keypoolsize", 0),
                    "walletname": result.get("walletname", ""),
                    "walletversion": result.get("walletversion", 0)
                }
        except Exception as e:
            self.logger.error(f"Erro ao obter informações da carteira Elements: {e}")
        return {}
    
    def get_blockchain_info(self) -> Dict[str, Any]:
        """Obtém informações da blockchain Elements"""
        try:
            result = self.rpc_call("getblockchaininfo")
            if result:
                return {
                    "chain": result.get("chain"),
                    "blocks": result.get("blocks"),
                    "bestblockhash": result.get("bestblockhash"),
                    "verificationprogress": result.get("verificationprogress"),
                    "mediantime": result.get("mediantime"),
                    "initialblockdownload": result.get("initialblockdownload", False)
                }
        except Exception as e:
            self.logger.error(f"Erro ao obter informações da blockchain Elements: {e}")
        return {}

class BalanceDisplay:
    """Classe para exibir os saldos de forma organizada"""
    
    def __init__(self, config_file: str = "lnd_client_config.ini"):
        self.config = ConfigManager(config_file)
        self.lnd_client = LNDClient(self.config)
        self.elements_client = ElementsClient(self.config)
    
    def connect_clients(self) -> Dict[str, bool]:
        """Conecta aos clientes LND e Elements"""
        lnd_connected = self.lnd_client.connect()
        elements_connected = self.elements_client.test_connection()
        
        return {
            "lnd": lnd_connected,
            "elements": elements_connected
        }
    
    def format_satoshis(self, satoshis: int, show_msat: bool = False) -> str:
        """Formata satoshis para BTC"""
        if satoshis == 0:
            return "0.00000000 BTC"
        
        decimal_places = self.config.getint('DISPLAY', 'decimal_places', 8)
        btc = satoshis / 100000000
        
        if show_msat and self.config.getboolean('DISPLAY', 'show_millisats', False):
            return f"{btc:.{decimal_places}f} BTC ({satoshis:,} sats)"
        else:
            return f"{btc:.{decimal_places}f} BTC ({satoshis:,} sats)"
    
    def format_balance_dict(self, balance_dict: Dict) -> str:
        """Formata um dicionário de saldos por asset"""
        if not balance_dict:
            return "0.00000000"
        
        formatted = []
        for asset, amount in balance_dict.items():
            if asset == "bitcoin":
                formatted.append(f"{amount:.8f} L-BTC")
            elif asset.upper() == "USDT" or len(asset) == 64:  # Asset ID ou nome conhecido
                asset_name = "USDT" if asset.upper() == "USDT" or "usdt" in asset.lower() else asset[:8]
                formatted.append(f"{amount:.8f} {asset_name}")
            else:
                formatted.append(f"{amount:.8f} {asset}")
        
        return ", ".join(formatted) if formatted else "0.00000000"
    
    def display_all_balances(self):
        """Exibe todos os saldos"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        show_full_pubkey = self.config.getboolean('DISPLAY', 'show_pubkey_full', False)
        
        print("=" * 80)
        print("🏦 BRLN-OS - Saldos das Carteiras")
        print(f"📅 {timestamp}")
        print("=" * 80)
        
        # Conectar aos serviços
        connections = self.connect_clients()
        
        # Informações do nó LND
        if connections["lnd"]:
            node_info = self.lnd_client.get_node_info()
            if node_info:
                pubkey = node_info.get('identity_pubkey', 'N/A')
                if not show_full_pubkey and len(pubkey) > 20:
                    pubkey = pubkey[:20] + "..."
                
                print(f"\n⚡ Nó Lightning: {node_info.get('alias', 'N/A')}")
                print(f"   Pubkey: {pubkey}")
                print(f"   Versão: {node_info.get('version', 'N/A')}")
                print(f"   Peers: {node_info.get('num_peers', 0)}")
                print(f"   Canais Ativos: {node_info.get('num_active_channels', 0)}")
                print(f"   Canais Pendentes: {node_info.get('num_pending_channels', 0)}")
                print(f"   Sincronizado Chain: {'✅' if node_info.get('synced_to_chain') else '❌'}")
                print(f"   Sincronizado Graph: {'✅' if node_info.get('synced_to_graph') else '❌'}")
                print(f"   Altura do Bloco: {node_info.get('block_height', 0):,}")
                
                chains = node_info.get('chains', [])
                if chains:
                    chain_info = ", ".join([f"{c['chain']}-{c['network']}" for c in chains])
                    print(f"   Rede: {chain_info}")
            
            # Saldo Lightning Network
            print(f"\n⚡ LIGHTNING NETWORK")
            print("-" * 40)
            channel_balance = self.lnd_client.get_channel_balance()
            if channel_balance:
                local_sats = channel_balance.get("local_balance", {}).get("sat", 0)
                remote_sats = channel_balance.get("remote_balance", {}).get("sat", 0)
                unsettled_local = channel_balance.get("unsettled_local_balance", {}).get("sat", 0)
                unsettled_remote = channel_balance.get("unsettled_remote_balance", {}).get("sat", 0)
                
                print(f"   Saldo Local:     {self.format_satoshis(local_sats)}")
                print(f"   Saldo Remoto:    {self.format_satoshis(remote_sats)}")
                if unsettled_local > 0:
                    print(f"   Não Liquidado (Local):  {self.format_satoshis(unsettled_local)}")
                if unsettled_remote > 0:
                    print(f"   Não Liquidado (Remoto): {self.format_satoshis(unsettled_remote)}")
                print(f"   Total no Canal:  {self.format_satoshis(local_sats + remote_sats)}")
            else:
                print("   ❌ Não foi possível obter saldo Lightning")
            
            # Saldo On-Chain Bitcoin
            print(f"\n₿ BITCOIN ON-CHAIN")
            print("-" * 40)
            wallet_balance = self.lnd_client.get_wallet_balance()
            if wallet_balance:
                confirmed = wallet_balance.get("confirmed_balance", 0)
                unconfirmed = wallet_balance.get("unconfirmed_balance", 0)
                total = wallet_balance.get("total_balance", 0)
                print(f"   Confirmado:      {self.format_satoshis(confirmed)}")
                print(f"   Não Confirmado:  {self.format_satoshis(unconfirmed)}")
                print(f"   Total:           {self.format_satoshis(total)}")
            else:
                print("   ❌ Não foi possível obter saldo on-chain")
        else:
            print("\n❌ Não foi possível conectar ao LND")
        
        # Saldo Liquid/Elements
        if connections["elements"]:
            print(f"\n🌊 LIQUID (ELEMENTS)")
            print("-" * 40)
            elements_wallet = self.elements_client.get_wallet_info()
            if elements_wallet:
                balance = elements_wallet.get("balance", {})
                unconfirmed = elements_wallet.get("unconfirmed_balance", {})
                immature = elements_wallet.get("immature_balance", {})
                
                print(f"   Confirmado:      {self.format_balance_dict(balance)}")
                if unconfirmed:
                    print(f"   Não Confirmado:  {self.format_balance_dict(unconfirmed)}")
                if immature:
                    print(f"   Imaturo:         {self.format_balance_dict(immature)}")
                print(f"   Transações:      {elements_wallet.get('txcount', 0):,}")
                
                # Informações da blockchain Elements
                blockchain_info = self.elements_client.get_blockchain_info()
                if blockchain_info:
                    print(f"   Chain: {blockchain_info.get('chain', 'N/A')}")
                    print(f"   Blocos: {blockchain_info.get('blocks', 0):,}")
                    progress = blockchain_info.get('verificationprogress', 0)
                    print(f"   Progresso Sync: {progress:.2%}")
            else:
                print("   ❌ Não foi possível obter informações da carteira")
        else:
            print(f"\n🌊 LIQUID (ELEMENTS)")
            print("-" * 40)
            print("   ❌ Não foi possível conectar ao Elements")
        
        print("\n" + "=" * 80)
        
        # Resumo das conexões
        print("📊 Status das Conexões:")
        print(f"   LND: {'✅ Conectado' if connections['lnd'] else '❌ Falha'}")
        print(f"   Elements: {'✅ Conectado' if connections['elements'] else '❌ Falha'}")
        print("=" * 80)
    
    def display_detailed_channels(self):
        """Exibe informações detalhadas dos canais"""
        if not self.lnd_client.connect():
            print("❌ Não foi possível conectar ao LND")
            return
        
        print("\n📋 DETALHES DOS CANAIS LIGHTNING")
        print("=" * 80)
        
        channels_info = self.lnd_client.get_channels()
        if channels_info and channels_info.get("channels"):
            channels = channels_info["channels"]
            print(f"Total de canais: {len(channels)}\n")
            
            for i, channel in enumerate(channels, 1):
                status = "🟢 Ativo" if channel["active"] else "🔴 Inativo"
                private = "🔒 Privado" if channel["private"] else "🌐 Público"
                
                print(f"Canal #{i} - {status} - {private}")
                print(f"   Remote Pubkey: {channel['remote_pubkey'][:20]}...")
                print(f"   Capacidade: {self.format_satoshis(channel['capacity'])}")
                print(f"   Saldo Local: {self.format_satoshis(channel['local_balance'])}")
                print(f"   Saldo Remoto: {self.format_satoshis(channel['remote_balance'])}")
                print(f"   Taxa de Commit: {channel['commit_fee']} sats")
                print(f"   Enviado: {self.format_satoshis(channel['total_satoshis_sent'])}")
                print(f"   Recebido: {self.format_satoshis(channel['total_satoshis_received'])}")
                print(f"   Updates: {channel['num_updates']:,}")
                print("-" * 60)
        else:
            print("Nenhum canal encontrado ou erro ao obter informações")
    
    def close_connections(self):
        """Fecha todas as conexões"""
        self.lnd_client.close()

def main():
    """Função principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Cliente gRPC para LND e Elements")
    parser.add_argument('--config', '-c', default='lnd_client_config.ini',
                       help='Arquivo de configuração (padrão: lnd_client_config.ini)')
    parser.add_argument('--channels', '-ch', action='store_true',
                       help='Exibir detalhes dos canais Lightning')
    parser.add_argument('--json', '-j', action='store_true',
                       help='Saída em formato JSON')
    
    args = parser.parse_args()
    
    balance_display = BalanceDisplay(args.config)
    
    try:
        if args.channels:
            balance_display.display_detailed_channels()
        else:
            balance_display.display_all_balances()
            
    except KeyboardInterrupt:
        print("\n\n⏹️  Interrompido pelo usuário")
    except Exception as e:
        logger = logging.getLogger(__name__)
        logger.error(f"Erro inesperado: {e}")
        sys.exit(1)
    finally:
        balance_display.close_connections()

if __name__ == "__main__":
    main()
