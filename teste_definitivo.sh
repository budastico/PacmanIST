#!/bin/bash

echo "=========================================="
echo "  TESTE DEFINITIVO - CLIENTES LONGOS"
echo "=========================================="
echo ""

# Limpar
pkill -9 -f "bin/server" 2>/dev/null
pkill -9 -f "bin/client" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
rm -f top5_clientes.txt server-debug.log

# Iniciar servidor
echo "[1] Iniciando servidor..."
./bin/server levels 3 /tmp/pacman_server 2>&1 | tee server.log &
SERVER_PID=$!
echo "    Servidor PID: $SERVER_PID"
sleep 2

# Cliente 1 - muitos comandos para ficar conectado
echo ""
echo "[2] Iniciando Cliente 1..."
(
    for i in {1..100}; do
        echo "w"
        sleep 0.2
    done
) | ./bin/client cliente1 /tmp/pacman_server > /dev/null 2>&1 &
CLIENT1_PID=$!
sleep 2

# Cliente 2
echo ""
echo "[3] Iniciando Cliente 2..."
(
    for i in {1..100}; do
        echo "d"
        sleep 0.2
    done
) | ./bin/client cliente2 /tmp/pacman_server > /dev/null 2>&1 &
CLIENT2_PID=$!
sleep 2

# Verificar conexões
echo ""
echo "[4] Verificando clientes conectados..."
if grep -q "Cliente registado com ID 1" server-debug.log 2>/dev/null; then
    echo "    ✓ Cliente 1 conectado"
fi
if grep -q "Cliente registado com ID 2" server-debug.log 2>/dev/null; then
    echo "    ✓ Cliente 2 conectado"
fi

# Aguardar um pouco
echo ""
echo "[5] Aguardando clientes jogarem (2s)..."
sleep 2

# Verificar se clientes ainda estão ativos
echo ""
echo "[6] Status dos clientes:"
if ps -p $CLIENT1_PID > /dev/null 2>&1; then
    echo "    ✓ Cliente 1 ainda ativo"
else
    echo "    ✗ Cliente 1 terminou"
fi
if ps -p $CLIENT2_PID > /dev/null 2>&1; then
    echo "    ✓ Cliente 2 ainda ativo"
else
    echo "    ✗ Cliente 2 terminou"
fi

# Enviar SIGUSR1
echo ""
echo "[7] Enviando SIGUSR1 ao servidor..."
kill -SIGUSR1 $SERVER_PID 2>&1
echo "    Sinal enviado, aguardando processamento..."
sleep 3

# Resultado
echo ""
echo "=========================================="
echo "  RESULTADO:"
echo "=========================================="
if [ -f top5_clientes.txt ]; then
    echo "✅ FICHEIRO CRIADO!"
    echo ""
    cat top5_clientes.txt
    echo ""
else
    echo "❌ Ficheiro não criado"
    echo ""
    echo "Últimas 30 linhas do log do servidor:"
    tail -30 server-debug.log 2>/dev/null
fi

# Verificar se SIGUSR1 aparece nos logs
echo ""
if grep -q "SIGUSR1 recebido" server.log 2>/dev/null; then
    echo "✓ SIGUSR1 recebido pelo servidor (visto no stderr)"
fi
if grep -q "Flag sigusr1_recebido detectada" server-debug.log 2>/dev/null; then
    echo "✓ Flag sigusr1_recebido foi detectada"
fi
if grep -q "Ficheiro.*gerado com sucesso" server-debug.log 2>/dev/null; then
    echo "✓ Função gerar_top5_clientes() foi executada"
fi

# Limpeza
echo ""
echo "=========================================="
kill $CLIENT1_PID $CLIENT2_PID $SERVER_PID 2>/dev/null
sleep 1
pkill -9 -f "bin/server" 2>/dev/null
pkill -9 -f "bin/client" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
echo "Limpeza concluída"
