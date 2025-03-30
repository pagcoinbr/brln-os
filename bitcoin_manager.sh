#! /bin/bash

    # Caminho do arquivo de configuração e arquivos para apagar
    local LND_CONF="/home/admin/.lnd/lnd.conf"
    local FILES_TO_DELETE=(
        "/home/admin/.lnd/tls.cert"
        "/home/admin/.lnd/tls.key"
        "/home/admin/.lnd/v3_onion_private_key"
    )

    # Função interna para comentar linhas 73 a 78
    comment_lines() {
        sed -i '73,78 s/^/#/' "$LND_CONF"
    }

    # Função interna para descomentar linhas 73 a 78
    decomment_lines() {
        sed -i '73,78 s/^#//' "$LND_CONF"
    }

    # Função interna para apagar os arquivos
    delete_files() {
        for file in "${FILES_TO_DELETE[@]}"; do
            if [ -f "$file" ]; then
                rm -f "$file"
                echo "Deleted: $file"
            else
                echo "File not found: $file"
            fi
        done
    }

    # Função interna para reiniciar o serviço LND
    restart_lnd() {
        sudo systemctl restart lnd
        if [ $? -eq 0 ]; then
            echo "LND service restarted successfully."
        else
            echo "Failed to restart LND service."
        fi
    }

    # Exibir o menu para o usuário
    while true; do
        echo "Escolha uma opção:"
        echo "1) Trocar para o Bitcoin Core local"
        echo "2) Trocar para o node Bitcoin remoto"
        echo "3) Sair"
        read -p "Digite sua escolha: " choice

        case $choice in
            1)
                echo "Trocando para o Bitcoin Core local..."
                comment_lines
                delete_files
                restart_lnd
                echo "Trocado para o Bitcoin Core local."
                ;;
            2)
                echo "Trocando para o node Bitcoin remoto..."
                decomment_lines
                delete_files
                restart_lnd
                echo "Trocado para o node Bitcoin remoto."
                ;;
            3)
                echo "Saindo."
                break
                ;;
            *)
                echo "Escolha inválida. Por favor, tente novamente."
                ;;
        esac
        echo ""
    done
