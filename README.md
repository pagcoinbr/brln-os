# ⚡ BRLN-OS

<div align="center">

![BRLN-OS Logo](https://img.shields.io/badge/BRLN--OS-Lightning%20Node-orange?style=for-the-badge&logo=bitcoin&logoColor=white)

**Sistema operacional containerizado completo para Bitcoin, Lightning Network e Liquid Network**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://docker.com)
[![Lightning](https://img.shields.io/badge/lightning-network-yellow.svg)](https://lightning.network)
[![Bitcoin](https://img.shields.io/badge/bitcoin-core-orange.svg)](https://bitcoincore.org)
[![JavaScript](https://img.shields.io/badge/javascript-gRPC%20server-yellow.svg)](https://nodejs.org)
[![Elements](https://img.shields.io/badge/elements-liquid%20network-green.svg)](https://elementsproject.org)

*Uma plataforma completa de nó Bitcoin, Lightning e Liquid Network com interface web integrada, servidor JavaScript gRPC e suporte a PeerSwap*

</div>

---

## 🚀 Instalação Rápida

**⚠️ IMPORTANTE: Sempre inicie como root**

Execute o comando:

```bash
sudo su
```

Para instalar a versão 2.0-alfa: (EM DESENVOLVIMENTO)
```bash
passwd root && cd && git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && bash run.sh
```

Para instalar a vesão 1.0-alfa: (FUNCIONAL)
```bash
passwd root && cd && git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && git switch brlnfullauto && bash run.sh
```
```
# Após a instalação inicial, você verá um qr code para acessar sua rede tailscale (VPN), caso não queira utilizar, acesse a interface web (http://SEU_IP ou http://localhost) e finalize a configuração do node:
# - Clique no botão "⚡ BRLN Node Manager" 
# - Siga o passo a passo na interface gráfica para:
#   • Configurar rede (mainnet/testnet) 
#   • Instalar os aplicativos de administração.
#
# Digite a nova senha do Super usuário (root), para continuar:
```

**É isso!** O BRLN-OS será instalado com todos os componentes necessários e você poderá configurar tudo através da interface web moderna.

---

