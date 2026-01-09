#!/bin/bash

echo "======================================"
echo "  Teste Automático SIGUSR1"
echo "======================================"

# Limpar processos antigos
pkill -f bin/server 2>/dev/null
pkill -f bin/client 2>/dev/null
sleep 1

# Limpar FIFOs antigos
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification 2>/dev/null

# 1. Iniciar servidor em background
echo ""
echo "[1/6] Iniciando servidor..."
./bin/server levels 3 /tmp/pacman_server > /dev/null 2>&1 &
SERVER_PID=$!
echo "      Servidor iniciado com PID: $SERVER_PID"
sleep 2

# Verificar se servidor está rodando
if ! ps -p $SERVER_PID > /dev/null; then
    echo "❌ ERRO: Servidor não iniciou!"
    exit 1
fi
echo "      ✓ Servidor rodando"

# 2. Iniciar 3 clientes em background (sem interface)
echo ""
echo "[2/6] Iniciando 3 clientes..."
for i in 1 2 3; do
    timeout 30 ./bin/client /tmp/pacman_server < /dev/null > /dev/null 2>&1 &
    CLIENT_PIDS[$i]=$!
    echo "      Cliente $i iniciado (PID: ${CLIENT_PIDS[$i]})"
    sleep 2
done

# 3. Aguardar clientes jogarem e acumularem pontos
echo ""
echo "[3/6] Aguardando clientes acumularem pontos (15 segundos)..."
sleep 15

# 4. Enviar SIGUSR1
echo ""
echo "[4/6] Enviando SIGUSR1 para o servidor..."
kill -SIGUSR1 $SERVER_PID

if [ $? -eq 0 ]; then
    echo "      ✓ Sinal enviado com sucesso"
else
    echo "      ❌ Erro ao enviar sinal"
fi

# Dar tempo para processar
sleep 2

# 5. Verificar se ficheiro foi criado
echo ""
echo "[5/6] Verificando ficheiro top5_clientes.txt..."
if [ -f top5_clientes.txt ]; then
    echo "      ✓ Ficheiro criado com sucesso!"
    echo ""
    echo "======================================"
    echo "  CONTEÚDO DO FICHEIRO:"
    echo "======================================"
    cat top5_clientes.txt
    echo "======================================"
else
    echo "      ❌ Ficheiro não foi criado!"
fi

# 6. Verificar logs
echo ""
echo "[6/6] Verificando server-debug.log..."
if grep -q "Ficheiro.*gerado com sucesso" server-debug.log 2>/dev/null; then
    echo "      ✓ Log confirma geração do ficheiro"
else
    echo "      ⚠ Log não encontrado ou sem confirmação"
fi

# 7. Mostrar estatísticas
echo ""
echo "======================================"
echo "  ESTATÍSTICAS:"
echo "======================================"
echo "  Servidor PID: $SERVER_PID"
echo "  Clientes conectados: 3"

# Contar clientes ativos
ACTIVE_CLIENTS=$(ps aux | grep -c "bin/client")
echo "  Clientes ainda ativos: $((ACTIVE_CLIENTS - 1))"

# 8. Limpeza
echo ""
echo "======================================"
echo "  LIMPEZA"
echo "======================================"
echo "Encerrando processos..."

# Matar clientes
for pid in "${CLIENT_PIDS[@]}"; do
    kill $pid 2>/dev/null
done

# Matar servidor
kill $SERVER_PID 2>/dev/null
sleep 1

# Forçar se necessário
pkill -9 -f bin/server 2>/dev/null
pkill -9 -f bin/client 2>/dev/null

# Limpar FIFOs
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification 2>/dev/null

echo "✓ Limpeza concluída"

echo ""
echo "======================================"
echo "  TESTE CONCLUÍDO"
echo "======================================"
echo ""
echo "Para testar manualmente:"
echo "  1. ./bin/server levels 3 /tmp/pacman_server"
echo "  2. Em outros terminais: ./bin/client /tmp/pacman_server"
echo "  3. kill -SIGUSR1 <PID_do_servidor>"
echo "  4. cat top5_clientes.txt"
echo ""
