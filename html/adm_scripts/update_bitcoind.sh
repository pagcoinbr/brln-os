#!/bin/bash
cd /tmp

# Obter a última versão do Bitcoin Core a partir da página oficial (estável)
VERSION=$(curl -s https://bitcoincore.org/en/download/ | grep -o 'bitcoin-core-[0-9.]*' | sed 's/bitcoin-core-//' | head -n1)

echo "Última versão do Bitcoin Core detectada: $VERSION"

{
    wget -q https://bitcoincore.org/bin/bitcoin-core-$VERSION/bitcoin-$VERSION-x86_64-linux-gnu.tar.gz
    wget -q https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS
    wget -q https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS.asc

    sha256sum --ignore-missing --check SHA256SUMS

    # Importar todas as chaves dos builders
    curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" \
      | grep download_url \
      | grep -oE "https://[a-zA-Z0-9./_-]+" \
      | while read url; do curl -s "$url" | gpg --import; done

    gpg --verify SHA256SUMS.asc

    tar -xzf bitcoin-$VERSION-x86_64-linux-gnu.tar.gz
    sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$VERSION/bin/bitcoin-cli bitcoin-$VERSION/bin/bitcoind

    bitcoind --version

    # Limpeza
    sudo rm -r bitcoin-$VERSION \
      bitcoin-$VERSION-x86_64-linux-gnu.tar.gz \
      SHA256SUMS \
      SHA256SUMS.asc

    sudo systemctl restart bitcoind
    cd
} &> /dev/null &

echo "Atualizando Bitcoin Core para a versão $VERSION... Por favor, aguarde."
wait
echo "✅ Bitcoin Core atualizado para a versão $VERSION com sucesso!"
