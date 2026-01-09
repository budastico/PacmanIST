#!/bin/bash

echo "=========================================="
echo "  TESTE CORRIGIDO - 2 CLIENTES REAIS"
echo "=========================================="
echo ""

# Limpar
pkill -9 -f "bin/server" 2>/dev/null
pkill -9 -f "bin/client" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
rm -f top5_clientes.txt server-debug.log client-debug.log

echo "CORREÇÃO: O cliente precisa de 2 argumentos:"
echo "  ./bin/client <client_id> <server_pipe>"
echo ""
echo "Vamos testar com client_id=1 e client_id=2"
echo ""
read -p "Pressione ENTER para iniciar..."

# Iniciar servidor
echo ""
echo "[1/5] Iniciando servidor..."
./bin/server levels 3 /tmp/pacman_server > server.log 2>&1 &
SERVER_PID=$!
echo "      Servidor PID: $SERVER_PID"
sleep 2

if ! ps -p $SERVER_PID > /dev/null; then
    echo "      ❌ Servidor falhou"
    cat server.log
    exit 1
fi
echo "      ✓ Servidor rodando"

# Cliente 1
echo ""
echo "[2/5] Iniciando Cliente 1 (ID=cliente1)..."
(
    sleep 1
    for i in {1..20}; do
        echo "w"
        sleep 0.3
    done
    sleep 15  # Manter conectado por mais tempo
    echo "Q"
) | ./bin/client cliente1 /tmp/pacman_server > /dev/null 2>&1 &
CLIENT1_PID=$!
echo "      Cliente 1 PID: $CLIENT1_PID"
sleep 2

# Verificar se cliente 1 conectou
echo "      Verificando conexão..."
if [ -f server-debug.log ]; then
    if grep -q "Cliente registado com ID 1" server-debug.log; then
        echo "      ✓ Cliente 1 conectado (ID único: 1)"
    else
        echo "      ⚠ Cliente 1 pode não ter conectado ainda"
    fi
fi

# Cliente 2
echo ""
echo "[3/5] Iniciando Cliente 2 (ID=cliente2)..."
(
    sleep 1
    for i in {1..15}; do
        echo "d"
        sleep 0.3
    done
    sleep 15  # Manter conectado por mais tempo
    echo "Q"
) | ./bin/client cliente2 /tmp/pacman_server > /dev/null 2>&1 &
CLIENT2_PID=$!
echo "      Cliente 2 PID: $CLIENT2_PID"
sleep 2

# Verificar conexões
echo ""
echo "Verificando clientes no servidor..."
if [ -f server-debug.log ]; then
    NUM_CLIENTS=$(grep -c "Cliente registado com ID" server-debug.log)
    echo "      Total de clientes registados: $NUM_CLIENTS"
    echo ""
    grep "Cliente registado" server-debug.log
fi

# Aguardar clientes jogarem um pouco
echo ""
echo "Aguardando clientes acumularem pontos (3s)..."
sleep 3

# Enviar SIGUSR1 ENQUANTO clientes estão conectados
echo ""
echo "[4/5] Enviando SIGUSR1 (clientes ainda conectados)..."
kill -SIGUSR1 $SERVER_PID

if [ $? -eq 0 ]; then
    echo "      ✓ SIGUSR1 enviado"
else
    echo "      ❌ Erro ao enviar SIGUSR1"
fi

sleep 3

# Verificar resultado
echo ""
echo "[5/5] RESULTADO:"
echo "=========================================="
if [ -f top5_clientes.txt ]; then
    echo "✅ Ficheiro top5_clientes.txt criado!"
    echo ""
    cat top5_clientes.txt
    echo ""
    
    NUM_LISTED=$(grep -c "Cliente ID" top5_clientes.txt)
    if [ $NUM_LISTED -gt 0 ]; then
        echo "✅ SUCESSO! $NUM_LISTED cliente(s) no top 5"
    else
        echo "⚠️  Ficheiro vazio (clientes podem ter desconectado)"
    fi
else
    echo "❌ Ficheiro não foi criado"
fi
echo "=========================================="

# Mostrar logs
echo ""
echo "LOGS DO SERVIDOR:"
echo "----------------------------------------"
if [ -f server-debug.log ]; then
    tail -25 server-debug.log
else
    echo "(sem logs)"
fi

# Limpeza
echo ""
echo "=========================================="
echo "LIMPEZA..."
kill $CLIENT1_PID $CLIENT2_PID $SERVER_PID 2>/dev/null
sleep 1
pkill -9 -f "bin/server" 2>/dev/null
pkill -9 -f "bin/client" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification

echo "✓ Teste concluído"
echo ""
echo "Para testar manualmente:"
echo "  Terminal 1: ./bin/server levels 3 /tmp/pacman_server"
echo "  Terminal 2: ./bin/client cliente1 /tmp/pacman_server"
echo "  Terminal 3: ./bin/client cliente2 /tmp/pacman_server"
echo "  Terminal 4: kill -SIGUSR1 \$(pgrep -f 'bin/server')"
echo "              cat top5_clientes.txt"
echo ""
