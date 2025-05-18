#!/bin/bash
# Script para iniciar o container do Bitcoin Core
# Uso: ./bitcoin-docker.sh [start|stop|restart|logs|status]

set -e

# Carrega variáveis de ambiente
if [ -f "/home/admin/brlnfullauto/shell/.env" ]; then
  source /home/admin/brlnfullauto/shell/.env
fi

DOCKER_DIR="/home/admin/brlnfullauto/docker/bitcoin"
cd "$DOCKER_DIR"

case "$1" in
  start)
    echo "Construindo e iniciando o container do Bitcoin Core..."
    docker-compose up -d --build
    ;;
  stop)
    echo "Parando o container do Bitcoin Core..."
    docker-compose down
    ;;
  restart)
    echo "Reiniciando o container do Bitcoin Core..."
    docker-compose down
    docker-compose up -d --build
    ;;
  clean)
    echo "Limpando e reconstruindo o container do Bitcoin Core..."
    docker-compose down
    docker system prune -f --filter "label=com.docker.compose.project=bitcoin"
    docker-compose build --no-cache
    docker-compose up -d
    ;;
  logs)
    echo "Mostrando logs do Bitcoin Core..."
    docker-compose logs -f bitcoind
    ;;
  status)
    if docker-compose ps | grep -q "bitcoind.*Up"; then
      echo "Status: O Bitcoin Core está em execução."
    else
      echo "Status: O Bitcoin Core não está em execução."
    fi
    ;;
  *)
    echo "Uso: $0 [start|stop|restart|clean|logs|status]"
    echo "  start   - Constrói e inicia o container"
    echo "  stop    - Para o container"
    echo "  restart - Reinicia o container"
    echo "  clean   - Limpa completamente e reconstrói o container (use em caso de problemas)"
    echo "  logs    - Mostra os logs do container"
    echo "  status  - Mostra o status do container"
    exit 1
    ;;
esac

exit 0
