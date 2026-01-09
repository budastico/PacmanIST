#!/bin/bash
echo "=== TESTE FINAL SIGUSR1 ==="
pkill -9 -f "bin/server" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification top5_clientes.txt server-debug.log

./bin/server levels 3 /tmp/pacman_server &
SERVER_PID=$!
sleep 2

echo "Servidor PID: $SERVER_PID"
echo "Abrindo 2 clientes em 10 segundos... conecte clientes agora!"
echo ""
echo "Execute em OUTROS TERMINAIS:"
echo "  cd $(pwd) && ./bin/client /tmp/pacman_server"
echo ""

for i in {10..1}; do
    echo -ne "Tempo restante: $i segundos...\r"
    sleep 1
done
echo ""

echo "Enviando SIGUSR1..."
kill -SIGUSR1 $SERVER_PID
sleep 2

echo ""
echo "=== RESULTADO ==="
cat top5_clientes.txt 2>/dev/null || echo "Nenhum ficheiro criado"
echo ""
echo "=== LOGS ==="
grep "Cliente registado\|Ficheiro.*gerado" server-debug.log 2>/dev/null

kill $SERVER_PID 2>/dev/null
pkill -9 -f "bin/" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
