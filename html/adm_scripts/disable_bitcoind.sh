#!/bin/bash

disable_bitcoind() {
    # Desabilitar o serviço bitcoind
    sudo systemctl stop bitcoind
    sudo systemctl disable bitcoind
}

disable_bitcoind >> $?
echo $?
