# Guia de Teste - SIGUSR1 e Top 5 Clientes

## O que foi implementado

✅ **Handler SIGUSR1**: Quando o servidor recebe o sinal SIGUSR1, memoriza essa recepção  
✅ **Gestão de clientes**: Cada cliente recebe um ID único e tem a pontuação rastreada  
✅ **Bloqueio em workers**: Apenas a tarefa anfitriã recebe SIGUSR1 (workers bloqueiam o sinal)  
✅ **Geração de ficheiro**: Cria `top5_clientes.txt` com os 5 clientes com maior pontuação  

---

## Como Testar

### **Passo 1: Iniciar o Servidor**

```bash
cd /home/oo_grazina/ProjetoSO2/PacmanIST
./bin/server levels 3 /tmp/pacman_server
```

- `levels` = diretório com os níveis .lvl
- `3` = máximo de jogos simultâneos (max_games)
- `/tmp/pacman_server` = nome do FIFO de registo

O servidor ficará à espera de conexões.

---

### **Passo 2: Conectar Vários Clientes (em terminais separados)**

**Terminal 2:**
```bash
cd /home/oo_grazina/ProjetoSO2/PacmanIST
./bin/client /tmp/pacman_server
```

**Terminal 3:**
```bash
cd /home/oo_grazina/ProjetoSO2/PacmanIST
./bin/client /tmp/pacman_server
```

**Terminal 4:**
```bash
cd /home/oo_grazina/ProjetoSO2/PacmanIST
./bin/client /tmp/pacman_server
```

Cada cliente deve começar a jogar. Usa as teclas **w, a, s, d** para mover o Pacman.

---

### **Passo 3: Jogar e Acumular Pontos**

- Cada cliente joga e acumula pontos ao comer bolinhas (`.`)
- Os pontos são atualizados continuamente no servidor
- Tenta ter clientes com pontuações diferentes

---

### **Passo 4: Obter o PID do Servidor**

**Num novo terminal:**
```bash
ps aux | grep bin/server
```

Vai aparecer algo como:
```
usuario  12345  0.1  0.2  ... ./bin/server levels 3 /tmp/pacman_server
```

O número **12345** é o PID do servidor.

---

### **Passo 5: Enviar o Sinal SIGUSR1**

```bash
kill -SIGUSR1 12345
```

(Substitui `12345` pelo PID real do servidor)

---

### **Passo 6: Verificar o Ficheiro Gerado**

```bash
cat top5_clientes.txt
```

**Exemplo de output:**
```
TOP 3 CLIENTES:
1. Cliente ID 1 - 150 pontos
2. Cliente ID 3 - 80 pontos
3. Cliente ID 2 - 45 pontos
```

---

### **Passo 7: Verificar o Debug Log**

```bash
tail -f server-debug.log
```

Deves ver mensagens como:
```
Cliente registado com ID 1 no slot 0
Cliente registado com ID 2 no slot 1
Cliente registado com ID 3 no slot 2
Ficheiro top5_clientes.txt gerado com sucesso
Ficheiro top5 gerado após SIGUSR1
```

---

## Testar com Múltiplos SIGUSR1

Podes enviar o sinal várias vezes:

```bash
# Enviar primeira vez
kill -SIGUSR1 12345
cat top5_clientes.txt

# Esperar que os clientes acumulem mais pontos...
sleep 10

# Enviar segunda vez
kill -SIGUSR1 12345
cat top5_clientes.txt
```

O ficheiro é atualizado com as pontuações mais recentes.

---

## Testar com Clientes Desconectando

1. Conecta 5 clientes
2. Envia SIGUSR1 → verás 5 clientes no top5
3. Fecha 2 clientes (Ctrl+C nos terminais)
4. Envia SIGUSR1 novamente → verás apenas 3 clientes

**Isto confirma que apenas clientes ATIVOS aparecem no top 5.**

---

## Testar que Workers NÃO Recebem SIGUSR1

Para verificar que apenas a tarefa anfitriã recebe o sinal:

1. Adiciona um `printf` no `session_worker` (se quiseres confirmar)
2. Envia SIGUSR1
3. Verifica que o ficheiro é gerado, mas as threads worker continuam normalmente

**Nota:** Já está implementado com `pthread_sigmask(SIG_BLOCK, ...)` nas workers.

---

## Script Automático de Teste

Podes usar este script bash:

```bash
#!/bin/bash

echo "=== Teste SIGUSR1 ==="

# 1. Iniciar servidor em background
./bin/server levels 3 /tmp/pacman_server &
SERVER_PID=$!
echo "Servidor iniciado com PID: $SERVER_PID"
sleep 2

# 2. Iniciar 3 clientes em background
for i in 1 2 3; do
    ./bin/client /tmp/pacman_server &
    echo "Cliente $i iniciado"
    sleep 1
done

# 3. Esperar clientes jogarem
echo "Aguardando clientes acumularem pontos..."
sleep 10

# 4. Enviar SIGUSR1
echo "Enviando SIGUSR1 para $SERVER_PID..."
kill -SIGUSR1 $SERVER_PID
sleep 1

# 5. Mostrar resultado
echo "=== Conteúdo de top5_clientes.txt ==="
cat top5_clientes.txt

# 6. Limpeza
echo "Limpando processos..."
pkill -P $SERVER_PID
kill $SERVER_PID 2>/dev/null
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification

echo "=== Teste concluído ==="
```

Guarda como `test_sigusr1.sh` e executa:
```bash
chmod +x test_sigusr1.sh
./test_sigusr1.sh
```

---

## Verificação de Correção

### ✅ Critérios de Sucesso:

1. **Handler instalado**: Servidor não crasha ao receber SIGUSR1
2. **Ficheiro gerado**: `top5_clientes.txt` é criado após o sinal
3. **Top 5 correto**: Mostra os 5 clientes com maior pontuação (ou menos se houver < 5)
4. **Ordenação**: Clientes estão ordenados por pontuação decrescente
5. **Apenas ativos**: Clientes desconectados NÃO aparecem
6. **Workers não afetados**: Jogos continuam normalmente após SIGUSR1
7. **IDs únicos**: Cada cliente tem um ID diferente

---

## Debugging

Se algo não funciona:

```bash
# Ver logs detalhados
tail -f server-debug.log

# Ver se FIFO existe
ls -l /tmp/pacman_server

# Ver processos ativos
ps aux | grep bin/server
ps aux | grep bin/client

# Limpar tudo e recomeçar
pkill -f bin/server
pkill -f bin/client
rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
```

---

## Resumo Técnico

**Estrutura de dados:**
- Array `clientes_ativos[max_games]` com info de cada cliente
- Cada entrada tem: `client_id`, `points`, `active`, `lock`

**Sincronização:**
- `clientes_mutex` protege o array global
- `sig_atomic_t sigusr1_recebido` é thread-safe

**Fluxo:**
1. Cliente conecta → recebe ID único
2. Pontuação atualizada em `session_manager_thread`
3. SIGUSR1 chega → flag ativa
4. Tarefa anfitriã verifica flag no ciclo
5. Gera ficheiro com top 5 ordenado
6. Cliente desconecta → marca `active = 0`

---

Boa sorte com os testes! 🎮
