#!/bin/bash
echo "Content-type: application/json"
echo ""

read_input() {
  input=""
  while IFS= read -r line; do
    input="$input$line"
  done
}
read_input

if echo "$input" | grep -q '"acao":"ligar-lnd"'; then
    if sudo systemctl start lnd && sudo systemctl enable lnd; then
        echo '{"status":"ok", "mensagem":"LND foi LIGADO com sucesso"}'
    else
        echo '{"status":"erro", "mensagem":"Erro ao ligar o LND"}'
    fi

elif echo "$input" | grep -q '"acao":"desligar-lnd"'; then
    if sudo systemctl stop lnd && sudo systemctl disable lnd; then
        echo '{"status":"ok", "mensagem":"LND foi DESLIGADO com sucesso"}'
    else
        echo '{"status":"erro", "mensagem":"Erro ao desligar o LND"}'
    fi

else
    echo '{"status":"erro", "mensagem":"Ação inválida"}'
fi
