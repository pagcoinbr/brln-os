#!/bin/bash

disable_bitcoind() {
    # Desabilitar o serviço bitcoind
    sudo systemctl start bitcoind
    sudo systemctl enable bitcoind
}

disable_bitcoind >> $?
echo $?
