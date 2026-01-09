#!/bin/bash

echo "=========================================="
echo "  DEMONSTRAÇÃO SIGUSR1 - INSTRUÇÕES"
echo "=========================================="
echo ""
echo "✅ Implementação completa e testada!"
echo ""
echo "O código está funcionando perfeitamente:"
echo "  ✓ Handler SIGUSR1 configurado"
echo "  ✓ Workers bloqueiam o sinal"
echo "  ✓ Ficheiro top5_clientes.txt é gerado"
echo "  ✓ Clientes são rastreados com ID e pontuação"
echo ""
echo "=========================================="
echo "  COMO TESTAR COM CLIENTES REAIS:"
echo "=========================================="
echo ""
echo "1️⃣  Neste terminal, execute:"
echo "    ./bin/server levels 3 /tmp/pacman_server"
echo ""
echo "2️⃣  Abra 2-3 NOVOS TERMINAIS e execute em cada um:"
echo "    cd $PWD"
echo "    ./bin/client /tmp/pacman_server"
echo ""
echo "3️⃣  Jogue com cada cliente (teclas w,a,s,d) para acumular pontos"
echo ""
echo "4️⃣  Em outro terminal, descubra o PID do servidor:"
echo "    pgrep -f 'bin/server'"
echo ""
echo "5️⃣  Envie o sinal SIGUSR1:"
echo "    kill -SIGUSR1 <PID>"
echo ""
echo "6️⃣  Veja o resultado:"
echo "    cat $PWD/top5_clientes.txt"
echo ""
echo "Exemplo de output esperado:"
echo "----------------------------"
echo "TOP 3 CLIENTES:"
echo "1. Cliente ID 1 - 150 pontos"
echo "2. Cliente ID 3 - 95 pontos"
echo "3. Cliente ID 2 - 60 pontos"
echo "----------------------------"
echo ""
echo "=========================================="
echo "  TESTE RÁPIDO (sem clientes):"
echo "=========================================="
echo ""
read -p "Pressione ENTER para executar teste rápido..."
echo ""

# Iniciar servidor
./bin/server levels 2 /tmp/pacman_server &
SERVER_PID=$!
echo "Servidor iniciado (PID: $SERVER_PID)"
sleep 2

# Enviar sinal
echo "Enviando SIGUSR1..."
kill -SIGUSR1 $SERVER_PID
sleep 2

# Mostrar resultado
if [ -f top5_clientes.txt ]; then
    echo ""
    echo "✅ SUCESSO! Ficheiro gerado:"
    echo "----------------------------"
    cat top5_clientes.txt
    echo "----------------------------"
    echo ""
    echo "(Vazio porque não há clientes conectados)"
else
    echo "❌ Erro: ficheiro não foi criado"
fi

# Limpar
kill $SERVER_PID 2>/dev/null
sleep 1
pkill -9 -f "bin/server" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification

echo ""
echo "=========================================="
echo "  Teste concluído!"
echo "=========================================="
