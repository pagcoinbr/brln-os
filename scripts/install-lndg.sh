#!/bin/bash

# Source das funções básicas
source "$(dirname "$0")/basic.sh"
basics

      info "🚀 Instalando LNDG..."
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        cd "$REPO_DIR/container"
        docker-compose build $app
        docker-compose up -d $app
      elif [[ "$verbose_mode" == "n" ]]; then
        warning " 🕒 Aguarde, isso pode demorar um pouco..."
        cd "$REPO_DIR/container"
        docker-compose build $app >> /dev/null 2>&1 & spinner
        docker-compose up -d $app >> /dev/null 2>&1 & spinner
        clear
      else
        warning "Opção inválida. Usando o modo padrão."
        menu
      fi
      warning "📝 Para acessar o LNDG, use a seguinte senha:"
      echo
      cat /data/lndg/data/lndg-admin.txt
      echo
      echo
      warning "📝 Você deve mudar essa senha ao final da instalação."