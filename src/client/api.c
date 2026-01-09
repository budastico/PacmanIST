#include "api.h"
#include "protocol.h"
#include "debug.h"

#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <sys/stat.h>
#include <stdlib.h>


struct Session {
  int id;
  int req_pipe;
  int notif_pipe;
  char req_pipe_path[MAX_PIPE_PATH_LENGTH + 1];
  char notif_pipe_path[MAX_PIPE_PATH_LENGTH + 1];
};

static struct Session session = {.id = -1};

int pacman_connect(char const *req_pipe_path, char const *notif_pipe_path, char const *server_pipe_path) {
    // 1. Criar os FIFOs do cliente [cite: 39]
    if (mkfifo(req_pipe_path, 0666) == -1 || mkfifo(notif_pipe_path, 0666) == -1) {
        return 1;
    }

    // 2. Abrir o FIFO do servidor para enviar o pedido [cite: 40]
    int server_fd = open(server_pipe_path, O_WRONLY);
    if (server_fd == -1) return 1;

    // 3. Preparar a mensagem de conexão (OP_CODE 1) [cite: 80]
    msg_connect_t msg;
    memset(&msg, 0, sizeof(msg));
    msg.op_code = OP_CODE_CONNECT;
    strncpy(msg.req_pipe_path, req_pipe_path, MAX_PIPE_PATH_LENGTH);
    strncpy(msg.notif_pipe_path, notif_pipe_path, MAX_PIPE_PATH_LENGTH);

    // Enviar o pedido [cite: 22]
    if (write(server_fd, &msg, sizeof(msg)) == -1) {
        close(server_fd);
        return 1;
    }
    close(server_fd);

    // 4. Abrir os nossos pipes e esperar confirmação do servidor [cite: 78, 81]
    session.notif_pipe = open(notif_pipe_path, O_RDONLY);
    session.req_pipe = open(req_pipe_path, O_WRONLY);

    msg_connect_res_t res;
    if (read(session.notif_pipe, &res, sizeof(res)) > 0) {
        if (res.op_code == OP_CODE_CONNECT && res.result == 0) {
            // Guardar caminhos para o disconnect mais tarde [cite: 43]
            strncpy(session.req_pipe_path, req_pipe_path, MAX_PIPE_PATH_LENGTH);
            strncpy(session.notif_pipe_path, notif_pipe_path, MAX_PIPE_PATH_LENGTH);
            return 0; // Sucesso! [cite: 41, 102]
        }
    }

    return 1; // Erro [cite: 41]
}

void pacman_play(char command) {
    if (session.req_pipe == -1) return;

    msg_play_t msg;
    msg.op_code = OP_CODE_PLAY; 
    msg.command = command; 

    write(session.req_pipe, &msg, sizeof(msg)); 
}

int pacman_disconnect() {
    if (session.req_pipe == -1) return 1;

    // Enviar código de desconexão (OP_CODE 2)
    char op_code = OP_CODE_DISCONNECT;
    write(session.req_pipe, &op_code, sizeof(op_code));

    // Fechar os descritores de ficheiro
    close(session.req_pipe);
    close(session.notif_pipe);

    // Apagar os FIFOs do sistema de ficheiros
    unlink(session.req_pipe_path);
    unlink(session.notif_pipe_path);

    session.id = -1; // Reset ao estado da sessão
    return 0;
}

Board receive_board_update(void) {
    Board b = {0};
    msg_board_header_t header;

    // 1. Ler cabeçalho
    if (read(session.notif_pipe, &header, sizeof(header)) <= 0) {
        return b; // Retorna Board vazio em caso de erro
    }

    if (header.op_code != OP_CODE_BOARD) {
        return b;
    }

    // 2. Alocar e ler os dados do tabuleiro
    int board_size = header.width * header.height;
    char *board_data = malloc(board_size * sizeof(char));
    if (board_data == NULL) {
        return b;
    }
    read(session.notif_pipe, board_data, board_size);

    // 3. Preencher a estrutura Board
    b.width = header.width;
    b.height = header.height;
    b.tempo = header.tempo;
    b.victory = header.victory;
    b.game_over = header.game_over;
    b.accumulated_points = header.accumulated_points;
    b.data = board_data;

    return b;
}