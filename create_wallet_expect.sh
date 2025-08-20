#!/usr/bin/expect -f

# Timeout de 60 segundos
set timeout 60

# Iniciar lncli create
spawn podman exec -it lnd-temp lncli create

# Aguardar prompt da senha
expect "Input wallet password:"
send "password123\r"

expect "Confirm password:"
send "password123\r"

# Aguardar prompt sobre seed existente
expect "Enter 'y' to use an existing cipher seed mnemonic, 'x' to use an extended master root key"
send "n\r"

# Aguardar prompt sobre passphrase do seed
expect "Input your passphrase if you wish to encrypt it"
send "\r"

# Aguardar a geração do seed
expect "END LND CIPHER SEED"

# Aguardar um pouco mais para garantir que tudo foi processado
sleep 5

# Finalizar
expect eof
