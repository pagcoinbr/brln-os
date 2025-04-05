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

if echo "$input" | grep -q '"acao":"ligar-bitcoind"'; then
    if sudo systemctl start bitcoind && sudo systemctl enable bitcoind; then
        echo '{"status":"ok", "mensagem":"Bitcoind foi LIGADO com sucesso"}'
    else
        echo '{"status":"erro", "mensagem":"Erro ao ligar o Bitcoind"}'
    fi

elif echo "$input" | grep -q '"acao":"desligar-bitcoind"'; then
    if sudo systemctl stop bitcoind && sudo systemctl disable bitcoind; then
        echo '{"status":"ok", "mensagem":"Bitcoind foi DESLIGADO com sucesso"}'
    else
        echo '{"status":"erro", "mensagem":"Erro ao desligar o Bitcoind"}'
    fi

else
    echo '{"status":"erro", "mensagem":"Ação inválida"}'
fi
