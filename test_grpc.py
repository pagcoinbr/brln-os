#!/usr/bin/env python3
"""
Script de teste para debuggar chamadas gRPC do LND
"""

import sys
import os
import grpc
import codecs

# Adicionar o diretório da API ao path para importar os protos
sys.path.append('/root/brln-os/api/v1')

try:
    import lightning_pb2 as lnrpc
    import lightning_pb2_grpc as lnrpcstub
    print("✓ Proto files carregados com sucesso")
except ImportError as e:
    print(f"✗ Erro ao importar proto files: {e}")
    exit(1)

# Configurações LND
LND_HOST = "localhost"
LND_GRPC_PORT = "10009"
MACAROON_PATH = "/data/lnd/data/chain/bitcoin/testnet/admin.macaroon"
TLS_CERT_PATH = "/data/lnd/tls.cert"

def get_credentials():
    """Obter credenciais SSL e macaroon para gRPC"""
    try:
        # Ler certificado TLS
        if not os.path.exists(TLS_CERT_PATH):
            raise FileNotFoundError(f"TLS cert não encontrado: {TLS_CERT_PATH}")
        
        with open(TLS_CERT_PATH, 'rb') as f:
            cert_data = f.read()
        
        # Ler macaroon
        if not os.path.exists(MACAROON_PATH):
            raise FileNotFoundError(f"Macaroon não encontrado: {MACAROON_PATH}")
        
        with open(MACAROON_PATH, 'rb') as f:
            macaroon_data = f.read()
        
        # Criar credenciais SSL
        ssl_creds = grpc.ssl_channel_credentials(cert_data)
        
        # Criar metadata callback para macaroon
        def metadata_callback(context, callback):
            macaroon_hex = codecs.encode(macaroon_data, 'hex')
            callback([('macaroon', macaroon_hex)], None)
        
        # Combinar credenciais
        auth_creds = grpc.metadata_call_credentials(metadata_callback)
        combined_creds = grpc.composite_channel_credentials(ssl_creds, auth_creds)
        
        return combined_creds, None
        
    except Exception as e:
        return None, str(e)

def test_getinfo():
    """Testar chamada GetInfo"""
    print("\n=== TESTE GetInfo ===")
    try:
        credentials, error = get_credentials()
        if error:
            print(f"✗ Erro ao obter credenciais: {error}")
            return False
        
        with grpc.secure_channel(f'{LND_HOST}:{LND_GRPC_PORT}', credentials) as channel:
            stub = lnrpcstub.LightningStub(channel)
            
            request = lnrpc.GetInfoRequest()
            response = stub.GetInfo(request, timeout=10)
            
            print(f"✓ Conectado ao LND")
            print(f"  - Alias: {response.alias}")
            print(f"  - Identity Pubkey: {response.identity_pubkey}")
            print(f"  - Testnet: {response.testnet}")
            print(f"  - Synced to chain: {response.synced_to_chain}")
            print(f"  - Block Height: {response.block_height}")
            
            return True
            
    except Exception as e:
        print(f"✗ Erro no GetInfo: {e}")
        return False

def test_wallet_balance():
    """Testar chamada WalletBalance"""
    print("\n=== TESTE WalletBalance ===")
    try:
        credentials, error = get_credentials()
        if error:
            print(f"✗ Erro ao obter credenciais: {error}")
            return False
        
        with grpc.secure_channel(f'{LND_HOST}:{LND_GRPC_PORT}', credentials) as channel:
            stub = lnrpcstub.LightningStub(channel)
            
            request = lnrpc.WalletBalanceRequest()
            response = stub.WalletBalance(request, timeout=10)
            
            print(f"✓ Saldo da carteira obtido")
            print(f"  - Total Balance: {response.total_balance}")
            print(f"  - Confirmed Balance: {response.confirmed_balance}")
            print(f"  - Unconfirmed Balance: {response.unconfirmed_balance}")
            print(f"  - Locked Balance: {response.locked_balance}")
            
            return True
            
    except Exception as e:
        print(f"✗ Erro no WalletBalance: {e}")
        return False

def test_list_utxos():
    """Testar chamada ListUnspent (UTXOs)"""
    print("\n=== TESTE ListUnspent (UTXOs) ===")
    try:
        credentials, error = get_credentials()
        if error:
            print(f"✗ Erro ao obter credenciais: {error}")
            return False
        
        with grpc.secure_channel(f'{LND_HOST}:{LND_GRPC_PORT}', credentials) as channel:
            stub = lnrpcstub.LightningStub(channel)
            
            request = lnrpc.ListUnspentRequest()
            request.min_confs = 0
            request.max_confs = 9999999
            
            response = stub.ListUnspent(request, timeout=10)
            
            print(f"✓ UTXOs obtidos: {len(response.utxos)} UTXOs")
            
            for i, utxo in enumerate(response.utxos):
                print(f"\n--- UTXO {i+1} ---")
                print(f"Address: {utxo.address}")
                print(f"Amount sat: {utxo.amount_sat}")
                print(f"Confirmations: {utxo.confirmations}")
                
                # Analisar pk_script
                print(f"pk_script type: {type(utxo.pk_script)}")
                try:
                    if hasattr(utxo.pk_script, 'hex'):
                        print(f"pk_script (hex()): {utxo.pk_script.hex()}")
                    else:
                        print(f"pk_script (str): {str(utxo.pk_script)}")
                except Exception as pk_error:
                    print(f"Erro ao processar pk_script: {pk_error}")
                
                # Analisar outpoint
                print(f"txid_str: {utxo.outpoint.txid_str}")
                print(f"output_index: {utxo.outpoint.output_index}")
                
                print(f"txid_bytes type: {type(utxo.outpoint.txid_bytes)}")
                try:
                    if hasattr(utxo.outpoint.txid_bytes, 'hex'):
                        print(f"txid_bytes (hex()): {utxo.outpoint.txid_bytes.hex()}")
                    else:
                        print(f"txid_bytes (str): {str(utxo.outpoint.txid_bytes)}")
                except Exception as txid_error:
                    print(f"Erro ao processar txid_bytes: {txid_error}")
                
                # Parar após 3 UTXOs para não poluir muito a saída
                if i >= 2:
                    if len(response.utxos) > 3:
                        print(f"\n... e mais {len(response.utxos) - 3} UTXOs")
                    break
            
            return True
            
    except Exception as e:
        print(f"✗ Erro no ListUnspent: {e}")
        return False

def main():
    print("=== TESTE gRPC LND ===")
    print(f"Host: {LND_HOST}:{LND_GRPC_PORT}")
    print(f"Macaroon: {MACAROON_PATH}")
    print(f"TLS Cert: {TLS_CERT_PATH}")
    
    # Verificar se arquivos existem
    if not os.path.exists(MACAROON_PATH):
        print(f"✗ Macaroon não encontrado: {MACAROON_PATH}")
        return
    
    if not os.path.exists(TLS_CERT_PATH):
        print(f"✗ TLS cert não encontrado: {TLS_CERT_PATH}")
        return
    
    print("✓ Arquivos de credenciais encontrados")
    
    # Executar testes
    tests = [
        test_getinfo,
        test_wallet_balance,
        test_list_utxos
    ]
    
    results = []
    for test in tests:
        try:
            result = test()
            results.append(result)
        except Exception as e:
            print(f"✗ Erro inesperado no teste: {e}")
            results.append(False)
    
    # Resumo
    print(f"\n=== RESUMO ===")
    print(f"GetInfo: {'✓' if results[0] else '✗'}")
    print(f"WalletBalance: {'✓' if results[1] else '✗'}")
    print(f"ListUnspent: {'✓' if results[2] else '✗'}")

if __name__ == '__main__':
    main()