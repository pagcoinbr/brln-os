# Prompt Estruturado para Desenvolvimento de Sistema de Swaps Descentralizados em BRLN-OS

## 1. Contexto e Visão Geral do Projeto

O BRLN-OS é uma distribuição Linux que transforma qualquer servidor em um nó completo de Bitcoin, Lightning Network e Liquid, com foco em soberania e auto custódia. O objetivo desta expansão é transformar o BRLN-OS em uma super plataforma de carteira auto custodial que integra Bitcoin on-chain, Lightning Network e ativos Liquid em um único ecossistema descentralizado e permissionless.

A visão é criar um aplicativo Linux que funcione como uma carteira universal capaz de gerenciar múltiplos ativos, camadas e protocolos através de uma interface unificada. Este sistema permitirá que cada nó na rede (peer) mantenha custódia total sobre seus fundos enquanto realizando trocas atômicas (atomic swaps) com qualquer outro peer na rede, sem intermediários, sem permissão e com segurança criptográfica garantida pelo protocolo HTLC (Hash Time Locked Contract).

A rede de peers será descentralizada, com comunicação via protocolo gossip através da rede Tor ou diretamente via Lightning Network quando disponível. Cada peer manterá sua própria database de estado de swaps, peers conectados e ativos gerenciados. O sistema será totalmente permissionless, permitindo adicionar novos peers através de informações públicas disponibilizadas em Tor, similar ao modelo de descoberta de nós LND.

## 2. Arquitetura de Alto Nível do Sistema

O sistema será construído em uma arquitetura em camadas que integra múltiplas linguagens de programação, aproveitando os pontos fortes de cada uma para diferentes responsabilidades:

A camada de infraestrutura base compreende o LND (Lightning Network Daemon) operando em conjunto com o elementsd (servidor Liquid). Estes daemons fornecem as capacidades fundamentais de pagamento Lightning e gerenciamento de ativos Liquid através de interfaces de RPC e gRPC. O LND expõe funcionalidades de gerenciamento de canais, pagamento de invoices, e manipulação de transações Lightning. O elementsd fornece acesso à blockchain Liquid, permitindo operações com L-BTC (Bitcoin na Liquid) e ativos customizados (Taproot Assets ou Issued Assets).

A camada de orquestração de swaps é implementada em Python e ser responsável pela lógica de coordenação de atomic swaps. Esta camada implementará o protocolo HTLC, gerenciará os fluxos de swap (iniciação, execução, falha e recuperação), mantendo estado persistente de todos os swaps em andamento. Será responsável por detectar eventos na blockchain e Lightning Network, sincronizar estado com peers, e orquestrar transações criptográficas.

A camada de rede peer-to-peer implementa comunicação descentralizada entre nós usando protocolo gossip. A comunicação ocorre preferencialmente via Lightning Network (usando canais existentes) e cai para comunicação via Tor como alternativa. Esta camada também implementa o modelo de descoberta de nós, permitindo que peers encontrem uns aos outros através de informações públicas publicadas em Tor.

A camada de carteira e gerenciamento de chaves implementa as funcionalidades de auto custódia, derivação de chaves, assinatura de transações e gerenciamento seguro de materiais criptográficos. Esta camada será implementada primariamente em Rust para máxima segurança criptográfica, integrando com bibliotecas como bitcoin, lightning e elements.

A camada de persistência gerencia databases de estado, transações, peers, swaps e configurações. Será utilizado um banco de dados relacional (PostgreSQL ou SQLite) para estrutura de dados complexa e um sistema de fila para operações assincronistas.

## 3. Stack Tecnológico Proposto

A camada de infraestrutura continuará utilizando o LND versão recente com Taproot support habilitado e o elementsd com suporte total a Liquid Assets. O LND será configurado para expor APIs via gRPC com TLS habilitado para comunicação segura.

A camada de Python (orchestração de swaps) utilizará FastAPI para APIs internas que expõem endpoints para gerenciar swaps e consultar estado. O Pydantic será utilizado para validação de dados e serialização. A biblioteca python-bitcoinlib será utilizada para manipulação de scripts Bitcoin e transações. A biblioteca py-liquidlib será utilizada para construir e assinar transações Liquid. A biblioteca grpcio será utilizada para comunicar com LND via gRPC.

A camada de comunicação P2P utilizará aiozmq ou FastAPI WebSockets para comunicação de baixa latência entre peers. O Tor será integrado via biblioteca stem para roteamento anônimo. O gossip protocol será implementado customizado, garantindo que atualizações de estado são propagadas através da rede.

A camada de carteira e criptografia será implementada em Rust utilizando as bibliotecas rust-bitcoin para manipulação de Bitcoin, lightning para operações Lightning, elements para Liquid, secp256k1 para operações ECDSA, e sha256 para hashing criptográfico. A biblioteca bdk (Bitcoin Development Kit) será utilizada para gerenciamento de descriptors e derivação de chaves.

O banco de dados será PostgreSQL em produção (com SQLite como fallback para desenvolvimento). A fila de tarefas assincronistas será Redis com Celery (ou alternativa em Python). O logging estruturado será implementado com Python logging com JSON output para análise.

## 4. Fluxo de Atomic Swap Detalhado

O fluxo de uma transação de swap atômico envolve múltiplas fases, cada uma crítica para garantir a não-confiança (trustlessness) entre peers.

Na fase de iniciação, o peer A (iniciador do swap) gera um preimage aleatório de 32 bytes e calcula seu hash SHA256. O peer A então cria um script HTLC (Hash Time Locked Contract) que especifica as condições sob as quais fundos podem ser gastos. O script permite que o peer B reclame os fundos fornecendo (1) sua assinatura e (2) o preimage secreto, OU permite que o peer A recupere os fundos após um período de timeout (tipicamente 24 blocos em Bitcoin ou 72 blocos em Liquid). O peer A comunica ao peer B a solicitação de swap contendo o hash do preimage, o valor, a moeda de origem e a moeda de destino.

Na fase de bloqueio de fundos, o peer A cria uma transação que envia seus fundos para o script HTLC. Esta transação é assinada com a chave privada do peer A e broadcast para a blockchain relevante (Bitcoin on-chain, Liquid, ou como pagamento Lightning). Simultaneamente, o peer B cria um contrato espelho no seu lado, com o mesmo hash do preimage, bloqueando seus fundos no script HTLC correspondente.

Na fase de execução, assim que o peer A vê que seus fundos estão bloqueados no HTLC, ele cria uma invoice Lightning (ou transação on-chain, dependendo do tipo de swap) para o peer B pelo valor acordado. A invoice contém o payment_hash que é igual ao hash do preimage. Quando o peer B paga a invoice Lightning, a rede Lightning obriga a revelação do preimage como prova de pagamento. Alternativamente, se for um swap on-chain, o peer B assina e submete uma transação que gasta o UTXO HTLC do peer A, fornecendo o preimage no witness script. O preimage fica visível na blockchain.

Na fase de conclusão, o peer A observa a blockchain (ou recebe notificação do evento Lightning) e detecta que o preimage foi revelado. Agora que conhece o preimage, o peer A cria uma transação que gasta o HTLC do peer B, fornecendo sua assinatura e o preimage recém-descoberto. Esta transação é assinada e broadcast para a blockchain. O swap agora está atomicamente completo: ambos os peers obtiveram seus fundos ou nenhum dos dois obteve nada.

Na fase de recuperação, se algo der errado em qualquer ponto, há mecanismos de segurança. Se o peer B nunca reclama seus fundos (a invoice não é paga, a transação não é broadcast), o timeout do HTLC do peer A expira e ele pode recuperar seus fundos usando apenas sua chave privada. Se o peer A não conseguir reivindicar os fundos do peer B após o preimage ser revelado, ele pode fazer uma reivindicação cooperativa onde ambos assinam uma transação de refund, ou aguardar seu próprio timeout. Arquivos de recuperação contendo preimage, chaves de refund e scripts HTLC são armazenados localmente para cada swap.

## 5. Estrutura de Diretórios e Módulos Propostos

O projeto será estruturado em diretórios logicamente separados por responsabilidade técnica:

A pasta raiz do projeto conterá configurações gerais: docker-compose.yml para orquestração de containers (LND, elementsd, banco de dados), requisitos do sistema em requirements.txt, variáveis de ambiente em .env.example, e documentação em README.md.

O diretório brln-swap-core conterá a lógica core de orchestração de swaps em Python. Dentro dele, o módulo atomicswap.py implementará a lógica fundamental de criação de scripts HTLC, cálculo de hashes, e manipulação de transações atômicas. O módulo submarineswap.py implementará swaps que conectam Bitcoin on-chain com Lightning Network. O módulo liquidswap.py implementará swaps envolvendo ativos Liquid. O módulo scriptbuilder.py conterá utilitários para construir scripts HTLC em Bitcoin e Liquid. O módulo txbuilder.py conterá lógica para construir, assinar e broadcast transações.

O diretório brln-wallet conterá código Rust para gerenciamento seguro de chaves e carteira. O módulo keymanager.rs implementará derivação BIP32 de chaves e armazenamento seguro. O módulo signer.rs implementará assinatura de transações. O módulo descriptor.rs gerenciará descriptors de carteira. O módulo liquid.rs fornecerá bindings seguros para operações Liquid.

O diretório brln-network conterá código de rede peer-to-peer. O módulo p2pprotocol.py implementará o protocolo gossip customizado. O módulo discovery.py implementará descoberta de peers via Tor. O módulo messaging.py implementará serialização e transmissão de mensagens entre peers.

O diretório brln-lnd contém wrappers para comunicação com LND. O módulo lndclient.py fornecerá uma abstração high-level sobre gRPC do LND. O módulo invoicemanager.py gerenciará criação e rastreamento de invoices Lightning. O módulo channelmanager.py gerenciará estado de canais Lightning.

O diretório brln-liquid contém wrappers para comunicação com elementsd. O módulo liquidclient.py fornecerá uma abstração sobre RPC de elementsd. O módulo assetmanager.py gerenciará ativos Liquid customizados. O módulo transactionmanager.py gerenciará ciclo de vida de transações Liquid.

O diretório brln-persistence contém código de banco de dados. O módulo models.py conterá definições de modelos SQLAlchemy. O módulo database.py conterá pool de conexões e operações de banco de dados. O módulo migrations.py conterá migrações Alembic.

O diretório brln-api contém a API REST/gRPC exposta. O módulo fastapi_app.py definirá endpoints para iniciar swaps, consultar status, recuperar fundos, e gerenciar peers. O módulo schemas.py conterá definições Pydantic de requisição/resposta.

O diretório brln-cli contém interface de linha de comando. O módulo cli.py conterá comandos Click para operações de usuário.

## 6. Integração com Componentes Externos

O projeto integrará com o LND existente através de gRPC. A integração permitirá: criar invoices com payment hashes específicos, escutar eventos de pagamento, consultar estado de canais, enviar pagamentos HTLCs customizados.

O projeto integrará com o elementsd existente através de RPC JSON. A integração permitirá: criar e assinar transações Liquid, submeter transações para broadcast, monitorar confirmação de transações, gerenciar ativos Liquid.

O projeto integrará com Peerswap onde possível. Se o Peerswap estiver rodando, swaps internos de rebalanceamento de canais podem usar o Peerswap. O código será agnóstico a qual swap implementação está disponível.

O projeto integrará com Boltz se a API pública for utilizada para swaps com terceiros. Mas a implementação de swap nativa será independente de qualquer serviço externo.

## 7. Requisitos Técnicos para Geração de Código via IA

Ao utilizar Claude (ou outro LLM generativo) para auxiliar no desenvolvimento do código, os seguintes requisitos devem ser explicitamente comunicados:

A implementação de scripts HTLC deve seguir as especificações BIP119 (OP_CHECKSEQUENCEVERIFY) para timelock e ser compatível com ambas blockchains Bitcoin e Liquid. O preimage secreto deve ter exatamente 32 bytes de entropia criptográfica gerada via os.urandom().

Toda a manipulação de chaves privadas deve ocorrer exclusivamente no módulo Rust (brln-wallet). Python nunca manipula chaves privadas diretamente. As operações de assinatura são sempre delegadas ao módulo Rust via FFI (Foreign Function Interface) ou gRPC.

O banco de dados não deve armazenar preimages revelados em plaintext após o swap ser completado. Uma vez que o swap é completado, apenas um hash do preimage deve ser armazenado para auditoria.

Toda comunicação entre peers deve ser criptografada. Se usando Tor, a criptografia end-to-end é redundante mas pode ser adicionada como defense-in-depth. A comunicação via Lightning Payment Secrets oferece privacidade inerente.

A implementação de timelock deve considerar reorganizações de blockchain. Um swap com timeout em bloco X não deve ser considerado seguro até bloco X+6 em Bitcoin ou X+2 em Liquid para contabilizar possíveis reorgs.

Todos os endpoints da API devem validar inputs usando Pydantic. Serialização JSON deve ser explícita e segura. Nenhuma execução dinâmica de código Python (eval, exec) em dados de usuário.

Operações com chaves privadas devem usar constant-time comparisons quando possível para evitar timing attacks. Bibliotecas como hmac devem ser utilizadas para comparações de secrets.

## 8. Fluxo de Desenvolvimento Esperado

O desenvolvimento será dividido em fases iterativas, cada uma adicionando funcionalidade e refinando a anterior.

Fase 1 focará em fundação: setup do projeto Python com estrutura modular, integração gRPC com LND, integração RPC com elementsd, setup de banco de dados PostgreSQL com modelos SQLAlchemy, implementação de API REST básica em FastAPI com autenticação, e testes unitários para componentes principais.

Fase 2 focará em lógica de swap: implementação de builders para scripts HTLC em Python, implementação de atomic swap on-chain (Bitcoin on-chain para Bitcoin on-chain), implementação de submarine swaps (on-chain para Lightning), implementação de liquid swaps (L-BTC para L-BTC), e testes em signet/testnet.

Fase 3 focará em rede P2P: implementação de protocolo gossip customizado, implementação de descoberta de peers via Tor, implementação de messaging entre peers, testes de latência e confiabilidade da rede.

Fase 4 focará em segurança e recuperação: implementação de mecanismo de recuperação (recovery files), testes de falha de rede e timeout, testes de reorganização de blockchain, implementação de refund cooperativo, auditoria de código criptográfico.

Fase 5 focará em UI/UX: implementação de CLI em Python, implementação opcional de web frontend, documentação de usuário, testes de aceitação com usuários reais.

## 9. Considerações de Segurança Críticas

A segurança é fundamental em qualquer sistema que manipula criptoativos. As seguintes considerações devem guiar todas as decisões de implementação:

Chaves privadas nunca devem deixar o módulo Rust. Python comunicará com Rust apenas para operações de assinatura já completamente especificadas. Nenhuma chave privada deve ser logada, serializada em JSON, ou transmitida pela rede.

Timeouts HTLC devem ter margem de segurança. Se um timeout é calculado para o bloco 1000, a interface de usuário deve advertir que o swap é seguro a partir do bloco 1006 (Bitcoin) ou 1002 (Liquid) para contabilizar reorgs.

Toda entrada do usuário deve ser validada. Endereços devem ser verificados com checksum (Bech32 para Bitcoin, elementos addressing para Liquid). Valores devem ser verificados quanto a overflow/underflow. Hashes devem ter tamanho exato.

O banco de dados deve ser encrypted at rest. Se usando PostgreSQL, pode-se usar pgcrypto ou full-disk encryption. Backups devem ser encriptados.

Recovery files contêm informações sensíveis. Devem ser armazenados com permissões de arquivo 0600 (readable only by owner). Devem ser oferecidos ao usuário para backup imediatamente após criação de swap.

A rede Tor oferece anonimato mas não autenticidade. Cada peer na rede P2P deve ser verificado criptograficamente. A chave pública de cada peer deve ser conhecida fora de banda ou verificada através de canais Lightning existentes.

## 10. Métricas de Sucesso e Validação

Um swap será considerado bem-sucedido apenas quando ambos os peers confirmarem atomicamente o recebimento de seus ativos respectivos. Um swap será considerado recuperável se o peer que iniciou puder recuperar fundos após timeout sem ação do outro peer.

O tempo médio de conclusão de um swap deve ser menor que 10 minutos em Bitcoin mainnet e 2 minutos em Liquid mainnet (após confirmação inicial).

Taxa de falha de rede que resulta em swap bem-sucedido deve ser menor que 0.1% quando comunicando via Lightning e menor que 1% quando comunicando via Tor.

Auditoria de segurança deve ser realizada por especialista terceiro antes de deployar em mainnet com mais que 1 BTC de liquidez total.

## 11. Recursos e Documentação Referencial

As seguintes fontes técnicas devem ser utilizadas para garantir conformidade com padrões:

Para HTLC e atomic swaps, a documentação oficial do Lightning Labs sobre Submarine Swaps fornece arquitetura e especificação de protocolo.

Para scripts Bitcoin, BIP119 (OP_CHECKSEQUENCEVERIFY) especifica timelock contracts. BIP141 (Segregated Witness) especifica script format.

Para Liquid, a documentação oficial do Blockstream sobre Liquid Network especifica elementos protocol e assets.

Para Python, FastAPI documentation fornece padrões para API segura e performática. Pydantic documentation fornece padrões para validação de dados.

Para Rust, rust-bitcoin documentation fornece tipos seguros para manipulação de Bitcoin. secp256k1 documentation fornece padrões para criptografia.

Para banco de dados, SQLAlchemy documentation e Alembic documentation fornecem padrões para ORM e migrations.

Para testes, pytest é recomendado para Python com fixtures reutilizáveis. Para Rust, cargo test com proptest para property-based testing.

## 12. Próximos Passos para Utilização com Claude

Este prompt estruturado deve ser dividido em seções específicas ao solicitar geração de código ao Claude:

Para implementação de HTLC: solicite com a seção 4 (Fluxo de Atomic Swap) e seção 7 (requisitos técnicos específicos para HTLC).

Para integração com LND: solicite com a seção 6 (integração com componentes externos, parte LND).

Para integração com elementsd: solicite com a seção 6 (integração com componentes externos, parte Liquid).

Para rede P2P: solicite com a seção 5 (estrutura de módulos, brln-network) e seção 8 (fase 3).

Para segurança: solicite com a seção 9 (considerações de segurança).

Para banco de dados e persistência: solicite com a seção 5 (brln-persistence) e estrutura de modelos.

Cada solicitação deve incluir contexto claro do objetivo específico, constraints técnicas, e formato de output esperado.
