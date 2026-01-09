#!/bin/bash

echo "=========================================="
echo "  TESTE COM CLIENTES SIMULADOS"
echo "=========================================="
echo ""

# Limpar
pkill -9 -f "bin/server" 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
rm -f top5_clientes.txt server-debug.log

echo "[1] Criando programa de teste com clientes simulados..."

# Criar um programa simples em C que adiciona clientes fake
cat > test_with_clients.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>

int main() {
    printf("Iniciando servidor...\n");
    
    // Executar servidor em background
    pid_t server_pid = fork();
    if (server_pid == 0) {
        execl("./bin/server", "./bin/server", "levels", "3", "/tmp/pacman_server", NULL);
        exit(1);
    }
    
    sleep(2);
    printf("Servidor PID: %d\n", server_pid);
    
    // Simular que temos clientes conectados
    // (Na prática, os clientes reais devem conectar via FIFO)
    printf("\nNOTA: Para clientes reais, execute em terminais separados:\n");
    printf("  Terminal 2: ./bin/client /tmp/pacman_server\n");
    printf("  Terminal 3: ./bin/client /tmp/pacman_server\n\n");
    
    printf("Aguardando 5 segundos para você conectar clientes...\n");
    sleep(5);
    
    printf("\nEnviando SIGUSR1...\n");
    kill(server_pid, SIGUSR1);
    sleep(2);
    
    printf("\n=== Conteúdo de top5_clientes.txt ===\n");
    system("cat top5_clientes.txt 2>/dev/null || echo 'Ficheiro não encontrado'");
    printf("=====================================\n\n");
    
    // Limpar
    kill(server_pid, SIGTERM);
    sleep(1);
    system("pkill -9 -f bin/server");
    system("rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification");
    
    return 0;
}
EOF

gcc test_with_clients.c -o test_with_clients
./test_with_clients

rm -f test_with_clients test_with_clients.c
