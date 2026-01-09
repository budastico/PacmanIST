# ============================================================================
# PacmanIST - Makefile Unificado
# Projeto de Sistemas Operativos
# ============================================================================

CC = gcc
CFLAGS = -Wall -Wextra -g -I$(INCLUDE_DIR)
LDFLAGS = -lncurses -lpthread

# Diretórios
INCLUDE_DIR = include
SRC_SERVER = src/server
SRC_CLIENT = src/client
OBJ_SERVER = obj/server
OBJ_CLIENT = obj/client
BIN_DIR = bin
LEVELS_DIR = levels

# Ficheiros fonte do servidor
SERVER_SRCS = $(SRC_SERVER)/game.c \
              $(SRC_SERVER)/board.c \
              $(SRC_SERVER)/parser.c \
              $(SRC_SERVER)/display.c

# Ficheiros fonte do cliente
CLIENT_SRCS = $(SRC_CLIENT)/client_main.c \
              $(SRC_CLIENT)/api.c \
              $(SRC_CLIENT)/display.c \
              $(SRC_CLIENT)/debug.c

# Ficheiros objeto
SERVER_OBJS = $(patsubst $(SRC_SERVER)/%.c,$(OBJ_SERVER)/%.o,$(SERVER_SRCS))
CLIENT_OBJS = $(patsubst $(SRC_CLIENT)/%.c,$(OBJ_CLIENT)/%.o,$(CLIENT_SRCS))

# Executáveis
SERVER = $(BIN_DIR)/server
CLIENT = $(BIN_DIR)/client

# ============================================================================
# Targets principais
# ============================================================================

.PHONY: all clean server client run-server run-client run test help

all: server client
	@echo "✅ Compilação completa!"

server: $(SERVER)
	@echo "✅ Servidor compilado: $(SERVER)"

client: $(CLIENT)
	@echo "✅ Cliente compilado: $(CLIENT)"

# ============================================================================
# Compilação do servidor
# ============================================================================

$(SERVER): $(SERVER_OBJS) | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(OBJ_SERVER)/%.o: $(SRC_SERVER)/%.c | $(OBJ_SERVER)
	$(CC) $(CFLAGS) -c $< -o $@

# ============================================================================
# Compilação do cliente
# ============================================================================

$(CLIENT): $(CLIENT_OBJS) | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(OBJ_CLIENT)/%.o: $(SRC_CLIENT)/%.c | $(OBJ_CLIENT)
	$(CC) $(CFLAGS) -c $< -o $@

# ============================================================================
# Criação de diretórios
# ============================================================================

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(OBJ_SERVER):
	mkdir -p $(OBJ_SERVER)

$(OBJ_CLIENT):
	mkdir -p $(OBJ_CLIENT)

# ============================================================================
# Limpeza
# ============================================================================

clean:
	rm -rf $(OBJ_SERVER)/*.o $(OBJ_CLIENT)/*.o
	rm -f $(SERVER) $(CLIENT)
	rm -f /tmp/pacman_server /tmp/*_request /tmp/*_notification
	@echo "🧹 Limpeza completa!"

# ============================================================================
# Execução
# ============================================================================

FIFO_SERVER = /tmp/pacman_server

run-server: server
	@pkill -f "$(SERVER)" 2>/dev/null || true
	@rm -f $(FIFO_SERVER) /tmp/*_request /tmp/*_notification
	./$(SERVER) $(LEVELS_DIR) 1 $(FIFO_SERVER)

run-client: client
	./$(CLIENT) 1 $(FIFO_SERVER)

run: all
	@echo "🎮 A iniciar o jogo..."
	@pkill -f "$(SERVER)" 2>/dev/null || true
	@pkill -f "$(CLIENT)" 2>/dev/null || true
	@rm -f $(FIFO_SERVER) /tmp/*_request /tmp/*_notification
	@sleep 0.2
	./$(SERVER) $(LEVELS_DIR) 1 $(FIFO_SERVER) &
	@sleep 0.5
	./$(CLIENT) 1 $(FIFO_SERVER)

test: all
	@echo "🧪 A correr testes..."
	@pkill -f "$(SERVER)" 2>/dev/null || true
	@rm -f $(FIFO_SERVER) /tmp/*_request /tmp/*_notification
	./$(SERVER) $(LEVELS_DIR) 1 $(FIFO_SERVER) &
	@sleep 0.5
	./$(CLIENT) 1 $(FIFO_SERVER)

# ============================================================================
# Ajuda
# ============================================================================

help:
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║              PacmanIST - Comandos Disponíveis              ║"
	@echo "╠════════════════════════════════════════════════════════════╣"
	@echo "║  make              - Compila servidor e cliente            ║"
	@echo "║  make server       - Compila apenas o servidor             ║"
	@echo "║  make client       - Compila apenas o cliente              ║"
	@echo "║  make run          - Compila e executa o jogo              ║"
	@echo "║  make run-server   - Executa apenas o servidor             ║"
	@echo "║  make run-client   - Executa apenas o cliente              ║"
	@echo "║  make clean        - Remove ficheiros compilados           ║"
	@echo "║  make help         - Mostra esta ajuda                     ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
