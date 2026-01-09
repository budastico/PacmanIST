#!/bin/bash

# Script para simular clientes jogando automaticamente
# Envia comandos aleatórios para fazer o pacman se mover e acumular pontos

FIFO_REGISTO=$1
CLIENT_NUM=$2
DURATION=${3:-20}  # Tempo de jogo em segundos

if [ -z "$FIFO_REGISTO" ] || [ -z "$CLIENT_NUM" ]; then
    echo "Uso: $0 <fifo_registo> <client_num> [duration]"
    exit 1
fi

# Criar pipes únicos para este cliente
REQ_PIPE="/tmp/client${CLIENT_NUM}_request"
NOTIF_PIPE="/tmp/client${CLIENT_NUM}_notification"

# Limpar pipes antigos
rm -f $REQ_PIPE $NOTIF_PIPE

# Criar pipes
mkfifo $REQ_PIPE 2>/dev/null
mkfifo $NOTIF_PIPE 2>/dev/null

echo "[Cliente $CLIENT_NUM] Pipes criados: $REQ_PIPE, $NOTIF_PIPE"

# Enviar pedido de conexão ao servidor
{
    # op_code = 1 (CONNECT)
    printf "\x01"
    # req_pipe_path (40 bytes)
    printf "%-40s" "$REQ_PIPE"
    # notif_pipe_path (40 bytes)
    printf "%-40s" "$NOTIF_PIPE"
} > $FIFO_REGISTO

echo "[Cliente $CLIENT_NUM] Pedido de conexão enviado"

# Abrir pipe de notificações em background para consumir dados
cat $NOTIF_PIPE > /dev/null &
NOTIF_PID=$!

# Aguardar confirmação (simplificado)
sleep 1

# Enviar comandos de movimento aleatórios
echo "[Cliente $CLIENT_NUM] Iniciando jogo por ${DURATION}s..."

END_TIME=$(($(date +%s) + DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    # Escolher comando aleatório: w, a, s, d
    COMMANDS=("w" "a" "s" "d")
    CMD=${COMMANDS[$((RANDOM % 4))]}
    
    # Enviar comando (op_code=3, command=w/a/s/d)
    printf "\x03%c" "$CMD" > $REQ_PIPE
    
    sleep 0.5  # Aguardar meio segundo entre comandos
done

echo "[Cliente $CLIENT_NUM] Enviando desconexão..."

# Enviar desconexão (op_code=2)
printf "\x02\x00" > $REQ_PIPE

sleep 1

# Limpar
kill $NOTIF_PID 2>/dev/null
rm -f $REQ_PIPE $NOTIF_PIPE

echo "[Cliente $CLIENT_NUM] Terminado"
