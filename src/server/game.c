#include "board.h"
#include "display.h"
#include "protocol.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/types.h>
#include <dirent.h>
#include <unistd.h>
#include <pthread.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <semaphore.h>
#include <signal.h>
#include <errno.h>
#include <sys/select.h>

#define CONTINUE_PLAY 0
#define NEXT_LEVEL 1
#define QUIT_GAME 2
#define MAX_BUFFER_SIZE 64

// Buffer circular para pedidos de conexão
static msg_connect_t pedidos_buffer[MAX_BUFFER_SIZE];
static int buffer_read_idx = 0;   // Índice de leitura (consumidores)
static int buffer_write_idx = 0;  // Índice de escrita (produtor)

// Semáforos para sincronização
static sem_t slots_vazios;        // Conta slots livres no buffer
static sem_t pedidos_disponiveis; // Conta pedidos no buffer
static pthread_mutex_t buffer_mutex = PTHREAD_MUTEX_INITIALIZER;

// Configuração do servidor
static int max_games = 1;
static char *levels_dir_global = NULL;

// Estrutura para guardar informação de clientes ativos
typedef struct {
    int client_id;           // ID único do cliente
    int points;              // Pontuação atual
    int active;              // Se está ativo (1) ou não (0)
    board_t *board;          // Ponteiro para o tabuleiro do cliente
    pthread_mutex_t lock;    // Para acesso concorrente
} client_info_t;

// Array global de clientes (tamanho max_games)
static client_info_t *clientes_ativos = NULL;
static int next_client_id = 1;  // Contador de IDs
static pthread_mutex_t clientes_mutex = PTHREAD_MUTEX_INITIALIZER;

// Variável volátil para o handler do sinal
static volatile sig_atomic_t sigusr1_recebido = 0;

// Estrutura para passar argumentos para as threads da sessão
typedef struct {
    board_t *board;
    int fd_req;
    int fd_notif;
    int *thread_shutdown;  // Flag por sessão
    int *player_victory;   // Flag por sessão
    int client_id;         // ID único do cliente
    int *client_index;     // Índice no array de clientes
} session_args_t;

typedef struct {
    board_t *board;
    int ghost_index;
    int *thread_shutdown;  // Flag por sessão
} ghost_thread_arg_t;

void handler_sigusr1(int sig) {
    (void)sig;
    sigusr1_recebido = 1;  // Memorizar que recebeu SIGUSR1
    write(STDERR_FILENO, "SIGUSR1 recebido!\n", 18);
}

void gerar_top5_clientes(const char *filename) {
    FILE *f = fopen(filename, "w");
    if (!f) {
        debug("Erro ao criar ficheiro %s: %s\n", filename, strerror(errno));
        return;
    }
    
    debug("Ficheiro %s aberto com sucesso\n", filename);
    
    time_t now = time(NULL);
    fprintf(f, "=== TOP 5 CLIENTES ===\n");
    
    pthread_mutex_lock(&clientes_mutex);
    
    // Contar clientes ativos
    int n_ativos = 0;
    for (int i = 0; i < max_games; i++) {
        if (clientes_ativos[i].active) {
            n_ativos++;
        }
    }
    
    debug("Número de clientes ativos: %d\n", n_ativos);
    fprintf(f, "Clientes conectados: %d\n\n", n_ativos);
    
    // Se não há clientes, terminar
    if (n_ativos == 0) {
        pthread_mutex_unlock(&clientes_mutex);
        fprintf(f, "Nenhum cliente ativo no momento.\n");
        fclose(f);
        debug("Ficheiro %s gerado (sem clientes ativos)\n", filename);
        return;
    }
    
    // Copiar clientes ativos para array temporário
    typedef struct {
        int client_id;
        int points;
    } cliente_rank_t;
    
    cliente_rank_t *ranking = malloc(n_ativos * sizeof(cliente_rank_t));
    if (!ranking) {
        pthread_mutex_unlock(&clientes_mutex);
        fprintf(f, "Erro: Não foi possível alocar memória.\n");
        fclose(f);
        debug("Erro ao alocar memória para ranking\n");
        return;
    }
    int idx = 0;
    for (int i = 0; i < max_games; i++) {
        if (clientes_ativos[i].active) {
            ranking[idx].client_id = clientes_ativos[i].client_id;
            ranking[idx].points = clientes_ativos[i].points;
            idx++;
        }
    }
    
    pthread_mutex_unlock(&clientes_mutex);
    
    // Ordenar por pontuação (bubble sort simples)
    for (int i = 0; i < n_ativos - 1; i++) {
        for (int j = 0; j < n_ativos - i - 1; j++) {
            if (ranking[j].points < ranking[j+1].points) {
                cliente_rank_t temp = ranking[j];
                ranking[j] = ranking[j+1];
                ranking[j+1] = temp;
            }
        }
    }
    
    // Escrever top 5 (ou menos se houver menos clientes)
    int top = (n_ativos < 5) ? n_ativos : 5;
    fprintf(f, "Rank | Cliente ID | Pontuação\n");
    fprintf(f, "--------------------------------\n");
    for (int i = 0; i < top; i++) {
        fprintf(f, " %d   | %10d | %9d\n", 
                i+1, ranking[i].client_id, ranking[i].points);
    }
    
    fprintf(f, "\n=== FIM DO LOG ===\n");
    
    free(ranking);
    fclose(f);
    debug("Ficheiro %s gerado com sucesso!\n", filename);
}

// Função auxiliar para converter o tabuleiro em dados para enviar ao cliente
char* board_to_data(board_t *board) {
    int size = board->width * board->height;
    char *data = malloc(size);
    if (!data) return NULL;
    
    for (int y = 0; y < board->height; y++) {
        for (int x = 0; x < board->width; x++) {
            int idx = y * board->width + x;
            board_pos_t *pos = &board->board[idx];
            
            if (pos->content != ' ' && pos->content != '\0') {
                // Converter caracteres internos para o formato do cliente
                switch (pos->content) {
                    case 'W': data[idx] = '#'; break;  // Parede
                    case 'P': data[idx] = 'C'; break;  // Pacman
                    case 'M': data[idx] = 'M'; break;  // Monstro
                    default:  data[idx] = pos->content; break;
                }
            } else if (pos->has_dot) {
                data[idx] = '.';
            } else if (pos->has_portal) {
                data[idx] = '@';  // Portal (era 'T')
            } else {
                data[idx] = ' ';
            }
        }
    }
    return data;
}

// Envia o estado do tabuleiro periodicamente para o cliente
void* session_manager_thread(void *arg) {
    session_args_t *args = (session_args_t*) arg;
    board_t *board = args->board;
    int *thread_shutdown = args->thread_shutdown;
    int *player_victory = args->player_victory;

    while (true) {
        sleep_ms(board->tempo);
        
        pthread_rwlock_rdlock(&board->state_lock);
        
        // Atualizar pontuação do cliente no array global
        if (args->client_index && *args->client_index >= 0) {
            pthread_mutex_lock(&clientes_mutex);
            clientes_ativos[*args->client_index].points = board->pacmans[0].points;
            pthread_mutex_unlock(&clientes_mutex);
        }
        
        // Preparar o cabeçalho da mensagem (OP_CODE 4)
        msg_board_header_t header = {
            .op_code = OP_CODE_BOARD,
            .width = board->width,
            .height = board->height,
            .tempo = board->tempo,
            .victory = *player_victory,
            .game_over = !board->pacmans[0].alive || *player_victory,
            .accumulated_points = board->pacmans[0].points
        };

        // Converter tabuleiro para dados
        char *board_data = board_to_data(board);
        
        pthread_rwlock_unlock(&board->state_lock);
        
        if (!board_data) break;

        // Enviar cabeçalho e depois os dados do tabuleiro
        if (write(args->fd_notif, &header, sizeof(header)) <= 0) {
            free(board_data);
            break; 
        }
        if (write(args->fd_notif, board_data, board->width * board->height) <= 0) {
            free(board_data);
            break;
        }
        
        free(board_data);

        if (*thread_shutdown || header.game_over) break;
    }
    return NULL;
}

// Lê comandos do FIFO de pedidos em vez do teclado
void* pacman_thread(void *arg) {
    session_args_t *args = (session_args_t*) arg;
    board_t *board = args->board;
    int *player_victory = args->player_victory;
    msg_play_t jogada;

    while (read(args->fd_req, &jogada, sizeof(msg_play_t)) > 0) {
        if (jogada.op_code == OP_CODE_PLAY) {
            command_t c = { .command = jogada.command, .turns = 1 };
            
            pthread_rwlock_wrlock(&board->state_lock);
            int result = move_pacman(board, 0, &c);
            if (result == REACHED_PORTAL) {
                *player_victory = 1;
            }
            pthread_rwlock_unlock(&board->state_lock);
        }
        
        if (jogada.op_code == OP_CODE_DISCONNECT) break;
        if (*player_victory) {
            // Esperar para que o session_manager envie a última atualização
            sleep_ms(board->tempo * 2);
            break;
        }
    }
    return NULL;
}

void* ghost_thread(void *arg) {
    ghost_thread_arg_t *ghost_arg = (ghost_thread_arg_t*) arg;
    board_t *board = ghost_arg->board;
    int ghost_ind = ghost_arg->ghost_index;
    int *thread_shutdown = ghost_arg->thread_shutdown;
    free(ghost_arg);

    ghost_t* ghost = &board->ghosts[ghost_ind];

    while (true) {
        sleep_ms(board->tempo * (1 + ghost->passo));

        pthread_rwlock_rdlock(&board->state_lock);
        if (*thread_shutdown) {
            pthread_rwlock_unlock(&board->state_lock);
            pthread_exit(NULL);
        }
        move_ghost(board, ghost_ind, &ghost->moves[ghost->current_move % ghost->n_moves]);
        pthread_rwlock_unlock(&board->state_lock);
    }
}

// Função auxiliar para encontrar o primeiro ficheiro .lvl no diretório
char* find_first_level(const char *levels_dir) {
    DIR *dir = opendir(levels_dir);
    if (!dir) return NULL;
    
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;
        
        char *dot = strrchr(entry->d_name, '.');
        if (dot && strcmp(dot, ".lvl") == 0) {
            char *name = strdup(entry->d_name);
            closedir(dir);
            return name;
        }
    }
    closedir(dir);
    return NULL;
}

static void processar_sessao(msg_connect_t *pedido) {
    debug("Worker: A processar pedido de conexão\n");
    debug("  Pipe pedidos: %s\n", pedido->req_pipe_path);
    debug("  Pipe notificações: %s\n", pedido->notif_pipe_path);
    
    // Abrir os pipes criados pelo cliente
    int fd_notif = open(pedido->notif_pipe_path, O_WRONLY);
    if (fd_notif < 0) {
        debug("Erro ao abrir pipe de notificações\n");
        return;
    }
    
    int fd_req = open(pedido->req_pipe_path, O_RDONLY);
    if (fd_req < 0) {
        debug("Erro ao abrir pipe de pedidos\n");
        close(fd_notif);
        return;
    }

    // Confirmar conexão com o cliente
    msg_connect_res_t res = { .op_code = OP_CODE_CONNECT, .result = 0 };
    if (write(fd_notif, &res, sizeof(res)) <= 0) {
        debug("Erro ao enviar confirmação\n");
        close(fd_req);
        close(fd_notif);
        return;
    }
    
    debug("Cliente conectado com sucesso!\n");

    // Atribuir ID único ao cliente
    pthread_mutex_lock(&clientes_mutex);
    int client_id = next_client_id++;
    int client_index = -1;

    // Encontrar slot livre no array de clientes
    for (int i = 0; i < max_games; i++) {
        if (!clientes_ativos[i].active) {
            client_index = i;
            clientes_ativos[i].client_id = client_id;
            clientes_ativos[i].points = 0;
            clientes_ativos[i].board = NULL;  // Será preenchido após carregar o nível
            clientes_ativos[i].active = 1;
            break;
        }
    }
    pthread_mutex_unlock(&clientes_mutex);
    
    debug("Cliente registado com ID %d no slot %d\n", client_id, client_index);

    // Encontrar e carregar o primeiro nível
    char *level_name = find_first_level(levels_dir_global);
    if (!level_name) {
        debug("Nenhum nível encontrado em %s\n", levels_dir_global);
        close(fd_req);
        close(fd_notif);
        return;
    }
    
    board_t *game_board = malloc(sizeof(board_t));
    if (!game_board) {
        debug("Erro ao alocar board\n");
        free(level_name);
        close(fd_req);
        close(fd_notif);
        return;
    }
    
    if (load_level(game_board, level_name, levels_dir_global, 0) < 0) {
        debug("Erro ao carregar nível: %s\n", level_name);
        free(level_name);
        free(game_board);
        close(fd_req);
        close(fd_notif);
        return;
    }
    free(level_name);
    
    debug("Nível carregado: %dx%d\n", game_board->width, game_board->height);

    // Associar o tabuleiro ao cliente para o log SIGUSR1
    if (client_index >= 0) {
        pthread_mutex_lock(&clientes_mutex);
        clientes_ativos[client_index].board = game_board;
        pthread_mutex_unlock(&clientes_mutex);
    }

    // Flags de controlo por sessão (alocadas dinamicamente)
    int *thread_shutdown = malloc(sizeof(int));
    int *player_victory = malloc(sizeof(int));
    *thread_shutdown = 0;
    *player_victory = 0;

    // Criar argumentos para a sessão
    session_args_t *s_args = malloc(sizeof(session_args_t));
    s_args->board = game_board;
    s_args->fd_req = fd_req;
    s_args->fd_notif = fd_notif;
    s_args->thread_shutdown = thread_shutdown;
    s_args->player_victory = player_victory;
    s_args->client_id = client_id;
    int *client_index_ptr = malloc(sizeof(int));
    *client_index_ptr = client_index;
    s_args->client_index = client_index_ptr;

    pthread_t tid_pac, tid_sess;
    pthread_t *ghost_tids = malloc(game_board->n_ghosts * sizeof(pthread_t));

    // Lançar as tarefas da sessão
    pthread_create(&tid_pac, NULL, pacman_thread, s_args);
    pthread_create(&tid_sess, NULL, session_manager_thread, s_args);

    for (int i = 0; i < game_board->n_ghosts; i++) {
        ghost_thread_arg_t *g_arg = malloc(sizeof(ghost_thread_arg_t));
        g_arg->board = game_board;
        g_arg->ghost_index = i;
        g_arg->thread_shutdown = thread_shutdown;
        pthread_create(&ghost_tids[i], NULL, ghost_thread, (void*) g_arg);
    }

    // Esperar pelo fim da sessão
    pthread_join(tid_pac, NULL);
    *thread_shutdown = 1;
    pthread_join(tid_sess, NULL);
    for (int i = 0; i < game_board->n_ghosts; i++) {
        pthread_join(ghost_tids[i], NULL);
    }

    // Marcar cliente como inativo e limpar referência ao board
    if (client_index >= 0) {
        pthread_mutex_lock(&clientes_mutex);
        clientes_ativos[client_index].board = NULL;  // Limpar antes de desalocar
        clientes_ativos[client_index].active = 0;
        pthread_mutex_unlock(&clientes_mutex);
        debug("Cliente ID %d desconectado\n", client_id);
    }

    // Limpeza da sessão
    close(fd_req);
    close(fd_notif);
    free(ghost_tids);
    free(thread_shutdown);
    free(player_victory);
    if (s_args->client_index) free(s_args->client_index);
    unload_level(game_board);
    free(game_board);
    free(s_args);
    
    debug("Sessão terminada.\n");
}

static void* session_worker(void *arg) {
    (void)arg;
    
    // Bloquear SIGUSR1 nesta thread (só a tarefa anfitriã deve receber)
    sigset_t set;
    sigemptyset(&set);
    sigaddset(&set, SIGUSR1);
    pthread_sigmask(SIG_BLOCK, &set, NULL);
    
    while (1) {
        // Esperar por um pedido no buffer
        sem_wait(&pedidos_disponiveis);
        
        // Retirar o pedido do buffer (secção crítica)
        pthread_mutex_lock(&buffer_mutex);
        msg_connect_t pedido = pedidos_buffer[buffer_read_idx];
        buffer_read_idx = (buffer_read_idx + 1) % MAX_BUFFER_SIZE;
        pthread_mutex_unlock(&buffer_mutex);
        
        // Processar a sessão
        processar_sessao(&pedido);
        
        // Sinalizar que há um slot livre
        sem_post(&slots_vazios);
    }
    
    return NULL;
}

int main(int argc, char** argv) {
    if (argc != 4) {
        printf("Usage: %s <level_dir> <max_games> <fifo_registo>\n", argv[0]);
        return -1;
    }

    levels_dir_global = argv[1];
    max_games = atoi(argv[2]);
    char *fifo_registo_nome = argv[3];

    // Validar max_games
    if (max_games < 1 || max_games > MAX_BUFFER_SIZE) {
        printf("max_games deve estar entre 1 e %d\n", MAX_BUFFER_SIZE);
        return -1;
    }

    srand((unsigned int)time(NULL));
    open_debug_file("server-debug.log");

    clientes_ativos = calloc(max_games, sizeof(client_info_t));
    for (int i = 0; i < max_games; i++) {
        pthread_mutex_init(&clientes_ativos[i].lock, NULL);
    }
    
    // Configurar handler SIGUSR1 (só para a tarefa anfitriã)
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handler_sigusr1;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;  // NÃO usar SA_RESTART - queremos interromper syscalls
    if (sigaction(SIGUSR1, &sa, NULL) == -1) {
        perror("Erro ao configurar handler SIGUSR1");
        return -1;
    }
    debug("Handler SIGUSR1 configurado\n");

    
    sem_init(&slots_vazios, 0, max_games);      // max_games slots livres
    sem_init(&pedidos_disponiveis, 0, 0);       // 0 pedidos inicialmente

    pthread_t *worker_threads = malloc(max_games * sizeof(pthread_t));
    for (int i = 0; i < max_games; i++) {
        pthread_create(&worker_threads[i], NULL, session_worker, NULL);
    }
    debug("Criadas %d tarefas worker\n", max_games);

    unlink(fifo_registo_nome); // Remover se já existir
    if (mkfifo(fifo_registo_nome, 0666) == -1) {
        perror("Erro ao criar FIFO de registo");
        return -1;
    }
    
    debug("Servidor iniciado. FIFO: %s, max_games: %d\n", fifo_registo_nome, max_games);
    
    // Abrir FIFO em modo não-bloqueante para não ficar preso se não houver escritores
    // Depois mudamos para bloqueante quando necessário
    int fd_registo = open(fifo_registo_nome, O_RDWR);
    if (fd_registo < 0) {
        perror("Erro ao abrir FIFO de registo");
        unlink(fifo_registo_nome);
        return -1;
    }

    //Colocar em modo não-bloqueante para garantir que o read() não pare a execução
    fcntl(fd_registo, F_SETFL, O_NONBLOCK);
    
    msg_connect_t pedido;
    fd_set read_fds;
    
    while (1) {
        
        if (sigusr1_recebido) {
            debug("Flag sigusr1_recebido detectada, gerando ficheiro...\n");
            sigusr1_recebido = 0;  // Reset
            gerar_top5_clientes("top5_clientes.txt");
            debug("Ficheiro top5_clientes.txt gerado após SIGUSR1\n");
        }
        
        // Configurar select com timeout (DEVE ser reinicializado em cada iteração!)
        struct timeval timeout;
        timeout.tv_sec = 1;
        timeout.tv_usec = 0;  // 1 segundo
        
        FD_ZERO(&read_fds);
        FD_SET(fd_registo, &read_fds);
        
        int ready = select(fd_registo + 1, &read_fds, NULL, NULL, &timeout);
        
        if (ready < 0) {
            if (errno == EINTR) {
                // Interrompido por sinal, continuar para verificar SIGUSR1
                debug("Select interrompido por sinal\n");
                continue;
            }
            // Outro erro
            debug("Erro em select: %d\n", errno);
            break;
        }
        
        if (ready == 0) {
            // Timeout - volta ao início do loop para verificar flag
            continue;
        }
        
        // Dados disponíveis para leitura
        ssize_t bytes_read = read(fd_registo, &pedido, sizeof(msg_connect_t));
        
        if (bytes_read <= 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                // Não há dados disponíveis (não deveria acontecer após select)
                debug("EAGAIN após select, continuando...\n");
                continue;
            }
            // FIFO fechado, reabrir com retry em caso de EINTR
            close(fd_registo);
            do {
                fd_registo = open(fifo_registo_nome, O_RDONLY);
            } while (fd_registo < 0 && errno == EINTR);
            
            if (fd_registo < 0) {
                debug("Erro ao reabrir FIFO de registo\n");
                break;
            }
            continue;
        }
        
        if (pedido.op_code == OP_CODE_CONNECT) {
            debug("Anfitriã: Pedido de conexão recebido\n");
            debug("  Pipe pedidos: %s\n", pedido.req_pipe_path);
            debug("  Pipe notificações: %s\n", pedido.notif_pipe_path);
            
            // Esperar por um slot livre (bloqueia se max_games atingido)
            sem_wait(&slots_vazios);
            
            // Inserir no buffer (secção crítica)
            pthread_mutex_lock(&buffer_mutex);
            pedidos_buffer[buffer_write_idx] = pedido;
            buffer_write_idx = (buffer_write_idx + 1) % MAX_BUFFER_SIZE;
            pthread_mutex_unlock(&buffer_mutex);
            
            // Sinalizar que há um pedido disponível
            sem_post(&pedidos_disponiveis);
            
            debug("Anfitriã: Pedido inserido no buffer\n");
        }
    }

    close(fd_registo);
    unlink(fifo_registo_nome);
    sem_destroy(&slots_vazios);
    sem_destroy(&pedidos_disponiveis);
    
    // Limpar array de clientes
    for (int i = 0; i < max_games; i++) {
        pthread_mutex_destroy(&clientes_ativos[i].lock);
    }
    free(clientes_ativos);
    
    free(worker_threads);
    close_debug_file();
    return 0;
}