FROM debian:bullseye-slim

# Argumentos de build para permitir especificar a arquitetura e a versão do Bitcoin
ARG ARCH=x86_64
ARG BTC_VERSION=28.1

# Instalar dependências necessárias
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    gosu \
    libevent-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libboost-chrono-dev \
    libboost-program-options-dev \
    libboost-thread-dev \
    libzmq3-dev \
    libdb-dev \
    libdb++-dev \
    libssl-dev \
    python3 \
    libminiupnpc-dev \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório de trabalho
WORKDIR /app

# Copiar os binários preexistentes ou baixar do site oficial
COPY ./setup.sh /app/
RUN chmod +x /app/setup.sh
RUN /app/setup.sh

# Adicionar script de inicialização
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/root/.bitcoin"]
EXPOSE 8332 8333 28332 28333

# Verificar instalação do bitcoind
RUN which bitcoind || echo "AVISO: bitcoind não está no PATH!"

ENTRYPOINT ["/entrypoint.sh"]
