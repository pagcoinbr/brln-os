#!/bin/bash
# Script para remover credenciais do histórico Git

echo "🚨 LIMPEZA DE CREDENCIAIS DO HISTÓRICO GIT 🚨"
echo "==============================================="
echo "⚠️  ATENÇÃO: Esta operação é IRREVERSÍVEL!"
echo "⚠️  O histórico público será completamente reescrito!"
echo ""

# Verificar se estamos em um repositório Git
if [ ! -d ".git" ]; then
    echo "❌ Erro: Não estamos em um repositório Git!"
    exit 1
fi

# Verificar se há mudanças não commitadas
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Erro: Há mudanças não commitadas. Faça commit ou stash primeiro."
    echo "Execute: git add . && git commit -m 'Backup antes da limpeza'"
    exit 1
fi

# Confirmação do usuário
echo "🔍 Verificando credenciais expostas no histórico..."
EXPOSED_CREDS=$(git log --all -p | grep -E "(REDACTED_USER|REDACTED_PASS|bitcoin\.br-ln\.com)" | wc -l)
echo "📊 Encontradas $EXPOSED_CREDS ocorrências de credenciais no histórico"

if [ $EXPOSED_CREDS -eq 0 ]; then
    echo "✅ Nenhuma credencial encontrada no histórico público!"
    exit 0
fi

echo ""
echo "💀 ÚLTIMA CHANCE DE CANCELAR!"
echo "Esta operação irá:"
echo "   • Reescrever TODO o histórico Git"
echo "   • Invalidar todos os clones existentes"
echo "   • Mudar todos os hashes de commit"
echo "   • Quebrar pull requests abertos"
echo ""
read -p "Tem CERTEZA que quer continuar? (digite 'CONFIRMO'): " confirm

if [ "$confirm" != "CONFIRMO" ]; then
    echo "❌ Operação cancelada pelo usuário"
    exit 1
fi

# Backup do repositório atual
echo "📦 Fazendo backup..."
BACKUP_DIR="/home/admin/brlnfullauto-backup-$(date +%Y%m%d-%H%M%S)"
cp -r /home/admin/brlnfullauto "$BACKUP_DIR"
echo "✅ Backup criado em: $BACKUP_DIR"

echo "🧹 Iniciando limpeza do histórico..."

# Método 1: BFG Repo-Cleaner (mais rápido e seguro)
echo "🔧 Verificando se BFG está disponível..."
if command -v bfg &> /dev/null; then
    echo "✅ BFG encontrado! Usando método mais seguro..."
    
    # Criar arquivo com credenciais a serem substituídas
    cat > /tmp/credentials-to-replace.txt << EOF
REDACTED_USER==>REDACTED_USER
REDACTED_PASS==>REDACTED_PASS
REDACTED_HOST==>REDACTED_HOST
EOF
    
    # Executar BFG
    bfg --replace-text /tmp/credentials-to-replace.txt --no-blob-protection .
    rm /tmp/credentials-to-replace.txt
    
else
    echo "⚠️  BFG não encontrado. Usando git filter-branch (mais lento)..."
    
    # Método 2: git filter-branch (fallback)
    git filter-branch --tree-filter '
      # Substituir em todos os arquivos .conf
      find . -name "*.conf" -type f 2>/dev/null | while read file; do
        if [ -f "$file" ]; then
          sed -i.bak "s/REDACTED_USER/REDACTED_USER/g" "$file" 2>/dev/null || true
          sed -i.bak "s/REDACTED_PASS/REDACTED_PASS/g" "$file" 2>/dev/null || true
          sed -i.bak "s/bitcoin\.br-ln\.com/REDACTED_HOST/g" "$file" 2>/dev/null || true
          rm -f "$file.bak" 2>/dev/null || true
        fi
      done
      
      # Substituir em outros arquivos que possam conter credenciais
      find . -name "*.md" -o -name "*.txt" -o -name "*.sh" -o -name "*.py" | while read file; do
        if [ -f "$file" ]; then
          sed -i.bak "s/REDACTED_USER/REDACTED_USER/g" "$file" 2>/dev/null || true
          sed -i.bak "s/REDACTED_PASS/REDACTED_PASS/g" "$file" 2>/dev/null || true
          sed -i.bak "s/bitcoin\.br-ln\.com/REDACTED_HOST/g" "$file" 2>/dev/null || true
          rm -f "$file.bak" 2>/dev/null || true
        fi
      done
    ' --prune-empty --all
fi

echo "🔄 Limpando referências antigas..."
# Limpar refs antigas e garbage collection
git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin
git reflog expire --expire=now --all
git gc --aggressive --prune=now

echo "🔍 Verificando resultado..."
REMAINING_CREDS=$(git log --all -p | grep -E "(REDACTED_USER|REDACTED_PASS|bitcoin\.br-ln\.com)" | wc -l)
if [ $REMAINING_CREDS -eq 0 ]; then
    echo "✅ Sucesso! Todas as credenciais foram removidas do histórico!"
else
    echo "⚠️  Atenção: Ainda restam $REMAINING_CREDS ocorrências. Pode ser necessário executar novamente."
fi

echo ""
echo "📝 PRÓXIMOS PASSOS OBRIGATÓRIOS:"
echo "================================"
echo "1. 🔑 TROCAR CREDENCIAIS NO SERVIDOR IMEDIATAMENTE!"
echo "2. 🚀 Forçar push para reescrever histórico remoto:"
echo "   git push --force --all origin"
echo "   git push --force --tags origin"
echo ""
echo "3. 📢 AVISAR TODOS OS COLABORADORES:"
echo "   • Fazer novo clone do repositório"
echo "   • Não tentar fazer merge/pull do repo antigo"
echo "   • Usar: git clone [url] [novo-diretorio]"
echo ""
echo "4. 🗑️  Deletar clones antigos em todas as máquinas"
echo ""
echo "⚠️  ATENÇÃO: Isso irá reescrever o histórico público!"
echo "⚠️  Todos que clonaram o repo precisarão fazer novo clone!"

echo ""
echo "Para aplicar as mudanças, execute:"
echo "git push --force --all origin"
echo "git push --force --tags origin"

echo ""
echo "✅ Limpeza concluída!"
echo "🔑 IMPORTANTE: Troque as credenciais no servidor IMEDIATAMENTE!"
