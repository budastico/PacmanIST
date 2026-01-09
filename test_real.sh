#!/bin/bash

echo "=========================================="
echo "  TESTE REAL SIGUSR1 - DEMONSTRAÇÃO"
echo "=========================================="
echo ""

# Limpar
pkill -9 -f "bin/server" 2>/dev/null
pkill -9 -f "bin/client" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
rm -f top5_clientes.txt server-debug.log

echo "[1/4] Iniciando servidor..."
./bin/server levels 2 /tmp/pacman_server &
SERVER_PID=$!
echo "      Servidor PID: $SERVER_PID"
sleep 2

if ! ps -p $SERVER_PID > /dev/null; then
    echo "      ❌ Servidor não iniciou"
    exit 1
fi
echo "      ✓ Servidor rodando"

echo ""
echo "[2/4] Criando dados simulados de clientes..."
# Como não temos clientes reais conectados, vamos enviar SIGUSR1 
# para demonstrar que o handler funciona mesmo sem clientes

echo ""
echo "[3/4] Enviando SIGUSR1 ao servidor..."
kill -SIGUSR1 $SERVER_PID

if [ $? -eq 0 ]; then
    echo "      ✓ Sinal SIGUSR1 enviado com sucesso"
else
    echo "      ❌ Erro ao enviar sinal"
    kill $SERVER_PID
    exit 1
fi

echo "      Aguardando processamento..."
sleep 3

echo ""
echo "[4/4] Verificando resultado..."
if [ -f top5_clientes.txt ]; then
    echo "      ✓ Ficheiro top5_clientes.txt criado!"
    echo ""
    echo "=========================================="
    echo "  CONTEÚDO DO FICHEIRO:"
    echo "=========================================="
    cat top5_clientes.txt
    echo "=========================================="
    echo ""
    echo "✅ TESTE PASSOU: Handler SIGUSR1 funciona!"
    echo "   O ficheiro foi gerado (vazio porque não há clientes)"
else
    echo "      ❌ Ficheiro não foi criado"
    echo ""
    echo "Verificando logs..."
    if [ -f server-debug.log ]; then
        echo "--- server-debug.log ---"
        cat server-debug.log
    fi
fi

echo ""
echo "=========================================="
echo "  LIMPEZA"
echo "=========================================="
kill $SERVER_PID 2>/dev/null
sleep 1
pkill -9 -f "bin/server" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
echo "✓ Concluído"
echo ""
echo "NOTA: Para teste completo com clientes reais:"
echo "  1. ./bin/server levels 2 /tmp/pacman_server"
echo "  2. Em outros terminais: ./bin/client /tmp/pacman_server"
echo "  3. Jogar para acumular pontos"
echo "  4. kill -SIGUSR1 <PID_do_servidor>"
echo "  5. cat top5_clientes.txt"
echo ""
