#!/bin/bash

echo "=========================================="
echo "  TESTE COMPLETO SIGUSR1 COM CLIENTES"
echo "=========================================="
echo ""

# Limpar
pkill -9 -f "bin/server" 2>/dev/null
pkill -9 -f "bin/client" 2>/dev/null  
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
rm -f top5_clientes.txt server-debug.log

echo "[1] Iniciando servidor..."
./bin/server levels 3 /tmp/pacman_server &
SERVER_PID=$!
echo "    Servidor PID: $SERVER_PID"
sleep 2

if ! ps -p $SERVER_PID > /dev/null; then
    echo "    ❌ Servidor não iniciou"
    exit 1
fi
echo "    ✓ Servidor rodando"

echo ""
echo "[2] Os clientes precisam ser iniciados MANUALMENTE!"
echo "    Abre 2-3 NOVOS TERMINAIS e executa em cada um:"
echo ""
echo "    cd /home/oo_grazina/ProjetoSO2/PacmanIST"
echo "    ./bin/client /tmp/pacman_server"
echo ""
echo "    Joga com w,a,s,d para acumular pontos"
echo ""
echo "[3] Quando os clientes estiverem jogando, pressiona ENTER aqui..."
read

echo ""
echo "[4] Enviando SIGUSR1..."
kill -SIGUSR1 $SERVER_PID
echo "    ✓ Sinal enviado"
sleep 2

echo ""
echo "[5] Resultado:"
if [ -f top5_clientes.txt ]; then
    echo "=========================================="
    cat top5_clientes.txt
    echo "=========================================="
    echo "✅ SUCESSO!"
else
    echo "❌ Ficheiro não criado"
fi

echo ""
echo "Pressiona ENTER para terminar e limpar..."
read

kill $SERVER_PID 2>/dev/null
pkill -9 -f "bin/client" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
echo "✓ Limpo"
