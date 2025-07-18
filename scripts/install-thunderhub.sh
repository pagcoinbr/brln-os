      echo
      echo -e "${YELLOW}🕒 Iniciando a instalação do Thunderhub...${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    log "🔐 Configuração da Senha do Thunderhub"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    info "Configure uma senha personalizada para o Thunderhub Lightning Dashboard:"
    echo ""
    echo "• A senha será usada para acessar o Thunderhub na interface web"
    echo "• Por padrão, a senha é 'changeme123'"
    echo "• Recomendamos usar uma senha forte e única"
    echo ""
    while true; do
        read -p "Deseja definir uma senha personalizada para o Thunderhub? (y/N): " -n 1 -r
        echo
        case $REPLY in
            [Yy]* )
                echo ""
                while true; do
                    read -p "🔐 Digite a nova senha para o Thunderhub: " thunderhub_password
                    if [[ -n "$thunderhub_password" && ${#thunderhub_password} -ge 8 ]]; then
                        echo ""
                        read -p "🔐 Confirme a senha: " thunderhub_password_confirm
                        if [[ "$thunderhub_password" == "$thunderhub_password_confirm" ]]; then
                            log "✅ Senha do Thunderhub definida com sucesso!"
                            configure_thunderhub_yaml "$thunderhub_password"
                            break 2
                        else
                            error "❌ As senhas não coincidem! Tente novamente."
                            echo ""
                        fi
                    else
                        error "❌ A senha deve ter pelo menos 8 caracteres!"
                        echo ""
                    fi
                done
                ;;
            [Nn]* | "" )
                log "🔐 Usando senha padrão do Thunderhub (changeme123)"
                warning "⚠️  Recomendamos alterar a senha padrão antes de usar em produção!"
                # Ainda assim, criar o arquivo de configuração padrão se não existir
                if [[ ! -f "container/thunderhub/thubConfig.yaml" ]]; then
                    if [[ -f "container/thunderhub/thubConfig.yaml.example" ]]; then
                        cp "container/thunderhub/thubConfig.yaml.example" "container/thunderhub/thubConfig.yaml"
                        log "📝 Arquivo thubConfig.yaml criado com configuração padrão"
                    fi
                fi
                break
                ;;
            * )
                echo "Por favor, responda y (sim) ou n (não)."
                ;;
        esac
    done
    echo ""
      echo -e "${CYAN}🚀 Instalando ThunderHub...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      app="thunderhub"
      if [[ "$verbose_mode" == "y" ]]; then
        docker-compose build $app
        docker-compose up -d $app
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso poderá demorar 10min ou mais. Seja paciente...${NC}"
        docker-compose build $app >> /dev/null 2>&1 & spinner
        docker-compose up -d $app >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu
      fi   
   
    local password="$1"
    local thunderhub_config="container/thunderhub/thubConfig.yaml"
    
    log "📝 Configurando thubConfig.yaml..."
    
    # Verificar se o arquivo existe
    if [[ ! -f "$thunderhub_config" ]]; then
        # Copiar do exemplo se não existir
        if [[ -f "container/thunderhub/thubConfig.yaml.example" ]]; then
            cp "container/thunderhub/thubConfig.yaml.example" "$thunderhub_config"
            log "Arquivo thubConfig.yaml criado a partir do exemplo"
        else
            error "Arquivo thubConfig.yaml.example não encontrado!"
            return 1
        fi
    fi
    
    # Atualizar senha no thubConfig.yaml
    sed -i "s/masterPassword: 'changeme123'/masterPassword: '$password'/g" "$thunderhub_config"
    sed -i "s/password: 'changeme123'/password: '$password'/g" "$thunderhub_config"
    
    # Também atualizar a variável de ambiente no service.json
    local service_json="container/thunderhub/service.json"
    if [[ -f "$service_json" ]]; then
        sed -i "s/\"THUB_PASSWORD\": \"changeme123\"/\"THUB_PASSWORD\": \"$password\"/g" "$service_json"
        log "✅ service.json atualizado com nova senha"
    fi
    
    log "✅ thubConfig.yaml configurado com sucesso!"