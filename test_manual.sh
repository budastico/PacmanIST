#!/bin/bash

echo "========== TESTE MANUAL SIGUSR1 =========="
echo ""

# Limpar tudo
pkill -9 -f "bin/server" 2>/dev/null
pkill -9 -f "bin/client" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
rm -f top5_clientes.txt server-debug.log

echo "[1] Iniciando servidor em background..."
./bin/server levels 2 /tmp/pacman_server &
SERVER_PID=$!
echo "    Servidor PID: $SERVER_PID"
sleep 2

# Verificar se servidor está rodando
if ! ps -p $SERVER_PID > /dev/null; then
    echo "    ❌ Servidor não iniciou!"
    exit 1
fi
echo "    ✓ Servidor rodando"

echo ""
echo "[2] Agora VOCÊ deve:"
echo "    - Abrir NOVOS TERMINAIS"
echo "    - Executar: cd /home/oo_grazina/ProjetoSO2/PacmanIST && ./bin/client /tmp/pacman_server"
echo "    - Jogar com w,a,s,d para acumular pontos"
echo "    - Abrir 2-3 clientes"
echo ""
echo "[3] Quando quiser testar SIGUSR1:"
echo "    - Execute neste terminal: kill -SIGUSR1 $SERVER_PID"
echo "    - Depois: cat top5_clientes.txt"
echo ""
echo "[4] Para terminar:"
echo "    - Ctrl+C nos clientes"
echo "    - Execute: kill $SERVER_PID"
echo ""
echo "=========================================="
echo "Servidor rodando... (Ctrl+C para parar)"
echo "=========================================="

# Aguardar
wait $SERVER_PID
