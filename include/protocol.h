#define MAX_PIPE_PATH_LENGTH 40

#ifndef PROTOCOL_H
#define PROTOCOL_H

enum {
  OP_CODE_CONNECT = 1,
  OP_CODE_DISCONNECT = 2,
  OP_CODE_PLAY = 3,
  OP_CODE_BOARD = 4,
};

// Mensagem enviada pelo Cliente para pedir conexão (OP_CODE 1)
typedef struct {
    char op_code;
    char req_pipe_path[MAX_PIPE_PATH_LENGTH];
    char notif_pipe_path[MAX_PIPE_PATH_LENGTH];
} msg_connect_t;

// Mensagem de resposta do Servidor (OP_CODE 1)
typedef struct {
    char op_code;
    char result; // 0 para sucesso, outro valor para erro
} msg_connect_res_t;

// Mensagem de jogada (OP_CODE 3)
typedef struct {
    char op_code;
    char command; // 'w', 'a', 's', 'd'
} msg_play_t;

// Mensagem de atualização do tabuleiro (OP_CODE 4)
typedef struct {
    char op_code;
    int width;
    int height;
    int tempo;
    int victory;
    int game_over;
    int accumulated_points;
} msg_board_header_t;

#endif