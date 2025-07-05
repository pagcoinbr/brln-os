# Makefile para setup-docker-intelligent em Rust

.PHONY: help build build-release clean test run install check format lint doc

# Variáveis
BINARY_NAME := setup-docker-intelligent
INSTALL_PATH := /usr/local/bin

# Target padrão
help:
	@echo "Comandos disponíveis:"
	@echo "  build         - Build em modo debug"
	@echo "  build-release - Build em modo release otimizado"
	@echo "  run           - Executar em modo interativo"
	@echo "  test          - Executar testes básicos"
	@echo "  check         - Verificar código sem compilar"
	@echo "  clean         - Limpar arquivos de build"
	@echo "  format        - Formatar código com rustfmt"
	@echo "  lint          - Verificar código com clippy"
	@echo "  install       - Instalar globalmente"
	@echo "  doc           - Gerar documentação"

# Build debug
build:
	@echo "Compilando em modo debug..."
	cargo build

# Build release
build-release:
	@echo "Compilando em modo release..."
	cargo build --release

# Executar
run:
	@echo "Executando setup-docker-intelligent..."
	cargo run

# Executar com argumentos específicos
run-auto:
	cargo run -- --mode auto

run-verbose:
	cargo run -- --verbose

run-help:
	cargo run -- --help

# Testes
test:
	@echo "Executando testes básicos..."
	./test.sh

check:
	@echo "Verificando código..."
	cargo check

# Limpeza
clean:
	@echo "Limpando arquivos de build..."
	cargo clean

# Formatação
format:
	@echo "Formatando código..."
	cargo fmt

# Lint
lint:
	@echo "Verificando com clippy..."
	cargo clippy -- -D warnings

# Instalação global
install: build-release
	@echo "Instalando $(BINARY_NAME) em $(INSTALL_PATH)..."
	sudo cp target/release/$(BINARY_NAME) $(INSTALL_PATH)/
	sudo chmod +x $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "Instalado com sucesso!"

# Desinstalar
uninstall:
	@echo "Removendo $(BINARY_NAME) de $(INSTALL_PATH)..."
	sudo rm -f $(INSTALL_PATH)/$(BINARY_NAME)

# Documentação
doc:
	@echo "Gerando documentação..."
	cargo doc --open

# Verificar dependências do sistema
deps-check:
	@echo "Verificando dependências do sistema..."
	@command -v docker >/dev/null 2>&1 || echo "❌ Docker não encontrado"
	@command -v docker-compose >/dev/null 2>&1 || echo "❌ Docker Compose não encontrado"
	@command -v jq >/dev/null 2>&1 || echo "⚠️  jq não encontrado (opcional)"
	@command -v yq >/dev/null 2>&1 || echo "⚠️  yq não encontrado (opcional)"
	@echo "✅ Verificação concluída"

# Atualizar dependências Rust
update:
	@echo "Atualizando dependências..."
	cargo update

# Build completo com todas as verificações
all: clean format lint check test build-release
	@echo "Build completo concluído!"

# Exemplo de uso
example:
	@echo "Exemplos de uso:"
	@echo ""
	@echo "1. Modo interativo:"
	@echo "   make run"
	@echo ""
	@echo "2. Modo automático:"
	@echo "   make run-auto"
	@echo ""
	@echo "3. Com verbose:"
	@echo "   make run-verbose"
	@echo ""
	@echo "4. Serviços específicos:"
	@echo "   cargo run -- --services 'lnd,elements'"
	@echo ""
	@echo "5. Com dependências:"
	@echo "   cargo run -- --services 'lnd' --deps"
