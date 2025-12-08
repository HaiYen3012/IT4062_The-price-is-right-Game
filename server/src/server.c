// server/src/server.c
#include "server.h"
#include "database.h"

// Global variables
Client *head_client = NULL;
Match *head_match = NULL; // Danh sách trận đấu
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
extern MYSQL *g_db_conn;  // From database.c

// ==================== MATCH MANAGEMENT (ROUND 3 LOGIC) ====================

Match *find_match(int room_id) {
    Match *tmp = head_match;
    while (tmp != NULL) {
        if (tmp->room_id == room_id) return tmp;
        tmp = tmp->next;
    }
    return NULL;
}

// Khởi tạo Match trong RAM khi Start Game
void create_match_in_memory(int room_id) {
    // Chỉ gọi hàm này KHI ĐÃ LOCK MUTEX ở bên ngoài
    
    // Check if match exists
    if (find_match(room_id) != NULL) return;

    Match *new_m = (Match *)malloc(sizeof(Match));
    new_m->room_id = room_id;
    new_m->count_players = 0;
    // LƯU Ý: Để test Round 3, ta set = 3. Khi chạy thật hãy sửa thành = 1
    new_m->current_round = 3; 
    new_m->current_turn_index = 0;
    new_m->next = head_match;
    head_match = new_m;

    // Load players from DB
    char query[1024]; // Tăng buffer size để tránh warning
    sprintf(query, "SELECT u.user_id, u.username FROM room_members rm JOIN users u ON rm.user_id = u.user_id WHERE rm.room_id = %d AND rm.left_at IS NULL ORDER BY rm.joined_at ASC", room_id);
    
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row;
        int count = 0;
        while ((row = mysql_fetch_row(res)) != NULL && count < MAX_PLAYERS) {
            new_m->player_ids[count] = atoi(row[0]);
            strcpy(new_m->player_names[count], row[1]);
            
            // Init Round 3 data
            new_m->r3_scores[count] = 0;
            new_m->r3_spins[count] = 0;
            new_m->r3_passed[count] = 0;
            
            count++;
        }
        new_m->count_players = count;
        mysql_free_result(res);
    }
    printf("[MATCH] Match created in memory for Room %d with %d players. Round %d\n", room_id, new_m->count_players, new_m->current_round);
}

void end_match(int room_id) {
    pthread_mutex_lock(&mutex);
    Match *curr = head_match;
    Match *prev = NULL;
    while (curr != NULL) {
        if (curr->room_id == room_id) {
            if (prev == NULL) head_match = curr->next;
            else prev->next = curr->next;
            free(curr);
            printf("[MATCH] Match memory cleared for Room %d\n", room_id);
            break;
        }
        prev = curr;
        curr = curr->next;
    }
    pthread_mutex_unlock(&mutex);
}

// Broadcast JSON message to all players in a match
void broadcast_match_json(Match *m, const char *json_data, int type) {
    Client *tmp = head_client;
    Message msg;
    msg.type = type;
    strncpy(msg.value, json_data, sizeof(msg.value) - 1);
    msg.value[sizeof(msg.value) - 1] = '\0';

    while (tmp != NULL) {
        if (tmp->room_id == m->room_id) {
            // Ưu tiên gửi qua Async socket, nếu không có thì gửi qua socket chính
            int target_fd = (tmp->async_conn_fd > 0) ? tmp->async_conn_fd : tmp->conn_fd;
            if (target_fd > 0) {
                send(target_fd, &msg, sizeof(Message), 0);
            }
        }
        tmp = tmp->next;
    }
}

// Logic Round 3
void handle_round_3_move(Client *cli, char *json_input) {
    pthread_mutex_lock(&mutex);
    
    Match *m = find_match(cli->room_id);
    if (!m || m->current_round != 3) {
        pthread_mutex_unlock(&mutex);
        return;
    }

    // 1. Xác định người chơi
    int p_idx = -1;
    for (int i = 0; i < m->count_players; i++) {
        if (strcmp(m->player_names[i], cli->login_account) == 0) {
            p_idx = i;
            break;
        }
    }

    // Check lượt
    if (p_idx == -1 || p_idx != m->current_turn_index) {
        pthread_mutex_unlock(&mutex);
        return;
    }

    char action[50]; 
    strncpy(action, json_input, sizeof(action) - 1);
    action[sizeof(action) - 1] = '\0';

    int turn_ended = 0;

    // --- XỬ LÝ QUAY (SPIN) ---
    if (strcmp(action, MOVE_SPIN) == 0) {
        if (m->r3_spins[p_idx] >= 2) {
             pthread_mutex_unlock(&mutex); return;
        }
        
        int spin_val = (rand() % 20 + 1) * 5; // 5, 10 ... 100
        m->r3_scores[p_idx] += spin_val;
        m->r3_spins[p_idx]++;
        
        printf("[R3] %s Spinned: %d. Total: %d.\n", cli->login_account, spin_val, m->r3_scores[p_idx]);

        // Gửi kết quả quay
        char json_resp[BUFF_SIZE];
        sprintf(json_resp, "{\"type\":\"%s\",\"user\":\"%s\",\"spin_val\":%d,\"total\":%d,\"spins_count\":%d}", 
                SPIN_RESULT, m->player_names[p_idx], spin_val, m->r3_scores[p_idx], m->r3_spins[p_idx]);
        broadcast_match_json(m, json_resp, ROUND_RESULT);

        // Hết 2 lượt quay thì xong lượt
        if (m->r3_spins[p_idx] == 2) {
            turn_ended = 1;
        }
        
    } 
    // --- XỬ LÝ BỎ LƯỢT (PASS) ---
    else if (strcmp(action, MOVE_PASS) == 0) {
        // Chỉ được pass nếu đã quay ít nhất 1 lần
        if (m->r3_spins[p_idx] >= 1) {
            m->r3_passed[p_idx] = 1;
            turn_ended = 1;
            printf("[R3] %s Passed.\n", cli->login_account);
            // Không gửi SPIN_RESULT khi Pass để tránh lỗi hiển thị FE
        }
    }

    // --- KIỂM TRA CHUYỂN LƯỢT ---
    if (turn_ended) {
        m->current_turn_index++;
        
        // Kiểm tra xem đã hết vòng (tất cả người chơi xong) chưa
        if (m->current_turn_index >= m->count_players) {
            char winner[50] = "";
            int max_score = -1;
            char scores_json[512] = "[";
            
            // Tính toán kết quả cuối cùng
            for (int i=0; i<m->count_players; i++) {
                int final_score = m->r3_scores[i];
                // Luật: > 100 thì trừ 100
                if (final_score > 100) final_score -= 100;
                
                if (final_score > max_score) {
                    max_score = final_score;
                    strcpy(winner, m->player_names[i]);
                }
                
                char entry[100];
                sprintf(entry, "{\"user\":\"%s\",\"score\":%d}", m->player_names[i], final_score);
                strcat(scores_json, entry);
                if(i < m->count_players -1) strcat(scores_json, ",");
            }
            strcat(scores_json, "]");
            
            char json_end[BUFF_SIZE];
            // Gửi chi tiết điểm số trong 'details'
            sprintf(json_end, "{\"type\":\"%s\",\"winner\":\"%s\",\"details\":%s}", ROUND3_END, winner, scores_json);
            broadcast_match_json(m, json_end, ROUND_RESULT);
            
            printf("[R3] Round End. Winner: %s\n", winner);
        } else {
             // Chuyển sang người tiếp theo
             char json_turn[BUFF_SIZE];
             sprintf(json_turn, "{\"type\":\"TURN_CHANGE\",\"next_user\":\"%s\"}", m->player_names[m->current_turn_index]);
             broadcast_match_json(m, json_turn, ROUND_INFO); 
        }
    }

    pthread_mutex_unlock(&mutex);
}
// ==================== CLIENT MANAGEMENT ====================

Client *new_client()
{
    Client *new = (Client *)malloc(sizeof(Client));
    new->login_status = UN_AUTH;
    new->async_conn_fd = -1;
    new->room_id = 0;
    new->is_ready = 0;
    new->next = NULL;
    return new;
}

void add_client(int conn_fd)
{
    pthread_mutex_lock(&mutex);
    
    Client *new = new_client();
    new->conn_fd = conn_fd;
    
    if (head_client == NULL) {
        head_client = new;
    } else {
        Client *tmp = head_client;
        while (tmp->next != NULL)
            tmp = tmp->next;
        tmp->next = new;
    }
    
    pthread_mutex_unlock(&mutex);
    printf("[%d] Client added to list\n", conn_fd);
}

void delete_client(int conn_fd)
{
    pthread_mutex_lock(&mutex);
    
    Client *tmp = head_client;
    Client *prev = NULL;
    
    while (tmp != NULL) {
        if (tmp->conn_fd == conn_fd || tmp->async_conn_fd == conn_fd) {
            if (tmp->conn_fd >= 0) close(tmp->conn_fd);
            if (tmp->async_conn_fd >= 0 && tmp->async_conn_fd != conn_fd) close(tmp->async_conn_fd);
            
            if (prev == NULL) head_client = tmp->next;
            else prev->next = tmp->next;
            free(tmp);
            printf("[%d] Client removed from list\n", conn_fd);
            break;
        }
        prev = tmp;
        tmp = tmp->next;
    }
    
    pthread_mutex_unlock(&mutex);
}

Client *find_client(int conn_fd)
{
    Client *tmp = head_client;
    while (tmp != NULL) {
        if (tmp->conn_fd == conn_fd) return tmp;
        tmp = tmp->next;
    }
    return NULL;
}

// ==================== AUTHENTICATION ====================
// Đã sửa tham số mảng để khớp với header (tránh warning)

int handle_signup(char username[BUFF_SIZE], char password[BUFF_SIZE])
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[1024]; // Tăng buffer
    int result;
    
    printf("Signup attempt: username='%s'\n", username);
    
    pthread_mutex_lock(&mutex);
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", username);
    
    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "MySQL query error: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return ACCOUNT_EXIST;
    }
    
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    
    if (row != NULL) {
        mysql_free_result(res);
        result = ACCOUNT_EXIST;
        printf("Account already exists: %s\n", username);
    } else {
        mysql_free_result(res);
        sprintf(query, "INSERT INTO users (username, password_hash, is_online) VALUES ('%s', '%s', 0)", username, password);
        
        if (mysql_query(g_db_conn, query)) {
            fprintf(stderr, "MySQL insert error: %s\n", mysql_error(g_db_conn));
            result = ACCOUNT_EXIST;
        } else {
            result = SIGNUP_SUCCESS;
            printf("Signup success: %s\n", username);
        }
    }
    pthread_mutex_unlock(&mutex);
    return result;
}

int handle_login(Client *cli, char username[BUFF_SIZE], char password[BUFF_SIZE])
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[1024]; // Tăng buffer
    int result;
    
    printf("Login attempt: username='%s'\n", username);
    
    pthread_mutex_lock(&mutex);
    sprintf(query, "SELECT user_id, password_hash, is_online FROM users WHERE username = '%s'", username);
    
    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "MySQL query error: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return ACCOUNT_NOT_EXIST;
    }
    
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    
    if (row == NULL) {
        mysql_free_result(res);
        result = ACCOUNT_NOT_EXIST;
        printf("Account does not exist: %s\n", username);
    } else {
        char *db_password = row[1];
        int is_online = atoi(row[2]);
        mysql_free_result(res);
        
        if (is_online) {
            result = LOGGED_IN;
            printf("Account already logged in: %s\n", username);
        } else if (strcmp(password, db_password) != 0) {
            result = WRONG_PASSWORD;
            printf("Wrong password for: %s\n", username);
        } else {
            sprintf(query, "UPDATE users SET is_online = 1 WHERE username = '%s'", username);
            if (mysql_query(g_db_conn, query)) {
                fprintf(stderr, "MySQL update error: %s\n", mysql_error(g_db_conn));
                result = ACCOUNT_NOT_EXIST;
            } else {
                strcpy(cli->login_account, username);
                cli->login_status = AUTH;
                result = LOGIN_SUCCESS;
                printf("Login success: %s\n", username);
            }
        }
    }
    pthread_mutex_unlock(&mutex);
    return result;
}

int handle_async_connect(int conn_fd, char username[BUFF_SIZE])
{
    pthread_mutex_lock(&mutex);
    Client *tmp = head_client;
    Client *target = NULL;
    
    while (tmp != NULL) {
        if (tmp->login_status == AUTH && strcmp(tmp->login_account, username) == 0) {
            target = tmp;
            break;
        }
        tmp = tmp->next;
    }
    
    if (target == NULL) {
        printf("[%d] ASYNC_CONNECT failed: user '%s' not found or not logged in\n", conn_fd, username);
        pthread_mutex_unlock(&mutex);
        return ACCOUNT_NOT_EXIST;
    }
    
    target->async_conn_fd = conn_fd;
    printf("[%d] Async socket registered for user '%s' (main fd=%d)\n", conn_fd, username, target->conn_fd);
    
    pthread_mutex_unlock(&mutex);
    return ASYNC_CONNECT_SUCCESS;
}

// ==================== CLIENT HANDLER ====================

void *handle_client(void *arg)
{
    pthread_detach(pthread_self());
    
    int conn_fd = *((int *)arg);
    free(arg);
    
    Message msg;
    int recv_bytes, result;
    
    Client *cli = find_client(conn_fd);
    printf("[%d] Client handler started\n", conn_fd);
    
    while ((recv_bytes = recv(conn_fd, &msg, sizeof(Message), 0)) > 0)
    {
        printf("[%d] Received message type: %d\n", conn_fd, msg.type);
        
        if (msg.type == DISCONNECT) {
            printf("[%d] Client requested disconnect\n", conn_fd);
            break;
        }
        
        switch (cli->login_status)
        {
        case UN_AUTH:
            switch (msg.type)
            {
            case LOGIN:
                {
                    char username[BUFF_SIZE], password[BUFF_SIZE];
                    char *token = strtok(msg.value, "|");
                    if (token != NULL) {
                        while (*token == ' ') token++;
                        strcpy(username, token);
                        char *end = username + strlen(username) - 1;
                        while (end > username && *end == ' ') { *end = '\0'; end--; }
                        
                        token = strtok(NULL, "|");
                        if (token != NULL) {
                            while (*token == ' ') token++;
                            strcpy(password, token);
                            end = password + strlen(password) - 1;
                            while (end > password && *end == ' ') { *end = '\0'; end--; }
                        }
                    }
                    result = handle_login(cli, username, password);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                }
                break;
                
            case SIGNUP:
                {
                    char username[BUFF_SIZE], password[BUFF_SIZE];
                    char *token = strtok(msg.value, "|");
                    if (token != NULL) {
                        while (*token == ' ') token++;
                        strcpy(username, token);
                        char *end = username + strlen(username) - 1;
                        while (end > username && *end == ' ') { *end = '\0'; end--; }
                        
                        token = strtok(NULL, "|");
                        if (token != NULL) {
                            while (*token == ' ') token++;
                            strcpy(password, token);
                            end = password + strlen(password) - 1;
                            while (end > password && *end == ' ') { *end = '\0'; end--; }
                        }
                    }
                    result = handle_signup(username, password);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                }
                break;
            
            case ASYNC_CONNECT:
                {
                    char username[BUFF_SIZE];
                    strcpy(username, msg.value);
                    char *end = username + strlen(username) - 1;
                    while (end > username && *end == ' ') { *end = '\0'; end--; }
                    result = handle_async_connect(conn_fd, username);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                }
                break;
                
            default:
                printf("[%d] Unauthorized access attempt, type=%d\n", conn_fd, msg.type);
                break;
            }
            break;
            
        case AUTH:
            switch (msg.type)
            {
            case LOGOUT:
                printf("[%d] Logout: %s\n", conn_fd, cli->login_account);
                pthread_mutex_lock(&mutex);
                char query[512]; // Increased buffer
                sprintf(query, "UPDATE users SET is_online = 0 WHERE username = '%s'", cli->login_account);
                mysql_query(g_db_conn, query);
                pthread_mutex_unlock(&mutex);
                cli->login_status = UN_AUTH;
                memset(cli->login_account, 0, sizeof(cli->login_account));
                break;
                
            case GET_ROOMS:
                {
                    printf("[%d] Client requested room list\n", conn_fd);
                    pthread_mutex_lock(&mutex);
                    char q[512];
                    sprintf(q, "SELECT room_id, room_code, max_players, "
                               "(SELECT COUNT(*) FROM room_members rm WHERE rm.room_id = r.room_id AND rm.left_at IS NULL) AS current_players "
                               "FROM rooms r "
                               "WHERE r.status = 'LOBBY' "
                               "HAVING current_players > 0");
                    if (mysql_query(g_db_conn, q)) {
                        msg.type = GET_ROOMS_RESULT; msg.value[0] = '\0';
                        send(conn_fd, &msg, sizeof(Message), 0);
                    } else {
                        MYSQL_RES *res = mysql_store_result(g_db_conn);
                        MYSQL_ROW row;
                        char json[BUFF_SIZE];
                        int first = 1;
                        strcpy(json, "[");
                        while ((row = mysql_fetch_row(res)) != NULL) {
                            if (!first) strcat(json, ","); else first = 0;
                            char entry[256];
                            snprintf(entry, sizeof(entry), "{\"room_id\":%s,\"room_code\":\"%s\",\"players\":\"%s/%s\"}", 
                                row[0], row[1], row[3], row[2]);
                            strcat(json, entry);
                        }
                        strcat(json, "]");
                        mysql_free_result(res);
                        msg.type = GET_ROOMS_RESULT;
                        strncpy(msg.value, json, sizeof(msg.value)-1);
                        send(conn_fd, &msg, sizeof(Message), 0);
                    }
                    pthread_mutex_unlock(&mutex);
                }
                break;

            case GET_ONLINE_USERS:
                {
                    printf("[%d] Client requested online users\n", conn_fd);
                    pthread_mutex_lock(&mutex);
                    if (mysql_query(g_db_conn, "SELECT username FROM users WHERE is_online = 1")) {
                        msg.type = GET_ONLINE_USERS_RESULT; msg.value[0] = '\0';
                        send(conn_fd, &msg, sizeof(Message), 0);
                    } else {
                        MYSQL_RES *res = mysql_store_result(g_db_conn);
                        MYSQL_ROW row;
                        char json[BUFF_SIZE];
                        strcpy(json, "[");
                        int first = 1;
                        while ((row = mysql_fetch_row(res)) != NULL) {
                            if (!first) strcat(json, ","); else first = 0;
                            char entry[128];
                            snprintf(entry, sizeof(entry), "\"%s\"", row[0]);
                            strcat(json, entry);
                        }
                        strcat(json, "]");
                        mysql_free_result(res);
                        msg.type = GET_ONLINE_USERS_RESULT;
                        strncpy(msg.value, json, sizeof(msg.value)-1);
                        send(conn_fd, &msg, sizeof(Message), 0);
                    }
                    pthread_mutex_unlock(&mutex);
                }
                break;
                
            case CREATE_ROOM:
                {
                    char room_code[BUFF_SIZE];
                    strcpy(room_code, msg.value);
                    result = handle_create_room(cli, room_code);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                }
                break;
                
            case JOIN_ROOM:
                {
                    char room_code[BUFF_SIZE];
                    strcpy(room_code, msg.value);
                    result = handle_join_room(cli, room_code);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                    if (result == JOIN_ROOM_SUCCESS) broadcast_room_state(cli->room_id);
                }
                break;
                
            case LEAVE_ROOM:
                {
                    int old_room = cli->room_id;
                    result = handle_leave_room(cli);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                    if (result == LEAVE_ROOM_SUCCESS && old_room > 0) broadcast_room_state(old_room);
                }
                break;
                
            case INVITE_USER:
                {
                    char target_username[BUFF_SIZE];
                    strcpy(target_username, msg.value);
                    result = handle_invite_user(cli, target_username);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                }
                break;
                
            case INVITE_RESPONSE:
                {
                    int invitation_id, accept;
                    sscanf(msg.value, "%d|%d", &invitation_id, &accept);
                    result = handle_invite_response(cli, invitation_id, accept);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                    if (accept && result == JOIN_ROOM_SUCCESS) broadcast_room_state(cli->room_id);
                }
                break;
                
            case READY_TOGGLE:
                {
                    result = handle_ready_toggle(cli);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                    if (result == READY_UPDATE) broadcast_room_state(cli->room_id);
                }
                break;
                
            case START_GAME:
                {
                    result = handle_start_game(cli);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                }
                break;

            case GET_ROOM_INFO:
                {
                    printf("[%d] Client requested room info\n", conn_fd);
                    pthread_mutex_lock(&mutex);
                    if (cli->room_id <= 0) {
                        msg.type = GET_ROOM_INFO_RESULT; msg.value[0] = '\0';
                        send(conn_fd, &msg, sizeof(Message), 0);
                    } else {
                        char q[1024];
                        sprintf(q, "SELECT r.room_code, r.host_user_id, r.max_players, "
                            "(SELECT GROUP_CONCAT(u.username ORDER BY rm.joined_at SEPARATOR '|') "
                            " FROM room_members rm JOIN users u ON rm.user_id = u.user_id "
                            " WHERE rm.room_id = r.room_id AND rm.left_at IS NULL) AS members, "
                            "(SELECT u.username FROM users u WHERE u.user_id = r.host_user_id) AS host_name "
                            "FROM rooms r WHERE r.room_id = %d", cli->room_id);
                        if (mysql_query(g_db_conn, q)) {
                            msg.type = GET_ROOM_INFO_RESULT; msg.value[0] = '\0';
                            send(conn_fd, &msg, sizeof(Message), 0);
                        } else {
                            MYSQL_RES *res = mysql_store_result(g_db_conn);
                            MYSQL_ROW row = mysql_fetch_row(res);
                            if (row != NULL) {
                                char json[BUFF_SIZE];
                                snprintf(json, sizeof(json), "{\"room_code\":\"%s\",\"max_players\":%s,\"members\":\"%s\",\"host_name\":\"%s\"}", 
                                    row[0], row[2], row[3] ? row[3] : "", row[4]);
                                msg.type = GET_ROOM_INFO_RESULT;
                                strncpy(msg.value, json, sizeof(msg.value)-1);
                                msg.value[sizeof(msg.value)-1] = '\0';
                                send(conn_fd, &msg, sizeof(Message), 0);
                            } else {
                                msg.type = GET_ROOM_INFO_RESULT; msg.value[0] = '\0';
                                send(conn_fd, &msg, sizeof(Message), 0);
                            }
                            mysql_free_result(res);
                        }
                    }
                    pthread_mutex_unlock(&mutex);
                }
                break;

            case ROUND_ANSWER:
                {
                    printf("[%d] Client answer: %s\n", conn_fd, msg.value);
                    handle_round_3_move(cli, msg.value);
                }
                break;
                 
            default:
                 printf("[%d] Unhandled message type: %d\n", conn_fd, msg.type);
                 break;
             }
             break;
        }
    }
    
    // Cleanup
    if (recv_bytes <= 0) {
        if (cli && cli->login_status == AUTH) {
            pthread_mutex_lock(&mutex);
            char query[512]; // Increased buffer
            sprintf(query, "UPDATE users SET is_online = 0 WHERE username = '%s'", cli->login_account);
            mysql_query(g_db_conn, query);
            
            if (cli->room_id > 0) {
                int old_room = cli->room_id;
                // Logic leave room when disconnect...
                // (Simplification: just mark user offline, room management might need explicit handling)
                // Re-using handle_leave_room logic is tricky inside mutex lock, best to do raw SQL here or implement safely
            }
            pthread_mutex_unlock(&mutex);
            printf("[%d] User '%s' cleaned up\n", conn_fd, cli->login_account);
        }
    }
    
    close(conn_fd);
    delete_client(conn_fd);
    printf("[%d] Handler exit\n", conn_fd);
    pthread_exit(NULL);
}

void catch_ctrl_c_and_exit(int sig)
{
    (void)sig; // Avoid unused warning
    printf("\n[SERVER] Shutting down...\n");
    Client *tmp = head_client;
    while (tmp != NULL) { close(tmp->conn_fd); tmp = tmp->next; }
    db_close();
    printf("[SERVER] Bye!\n");
    exit(0);
}

void start_server(int port)
{
    int listen_fd, conn_fd;
    struct sockaddr_in servaddr, cliaddr;
    socklen_t cli_len;
    pthread_t tid;
    signal(SIGINT, catch_ctrl_c_and_exit);
    listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    servaddr.sin_port = htons(port);
    bind(listen_fd, (struct sockaddr*)&servaddr, sizeof(servaddr));
    listen(listen_fd, BACKLOG);
    
    printf("[SERVER] Listening on port %d...\n", port);
    
    while (1) {
        cli_len = sizeof(cliaddr);
        conn_fd = accept(listen_fd, (struct sockaddr*)&cliaddr, &cli_len);
        if (conn_fd < 0) continue;
        add_client(conn_fd);
        int *pclient = malloc(sizeof(int));
        *pclient = conn_fd;
        pthread_create(&tid, NULL, handle_client, pclient);
    }
    close(listen_fd);
}

// ==================== ROOM MANAGEMENT (RE-ADDED & FIXED) ====================

void broadcast_room_state(int room_id)
{
    pthread_mutex_lock(&mutex);
    Message msg;
    msg.type = UPDATE_ROOM_STATE;
    
    char query[1024];
    sprintf(query, "SELECT u.username FROM room_members rm JOIN users u ON rm.user_id = u.user_id WHERE rm.room_id = %d AND rm.left_at IS NULL ORDER BY rm.joined_at", room_id);
    
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row;
        char json[BUFF_SIZE] = "[";
        int first = 1;
        while ((row = mysql_fetch_row(res)) != NULL) {
            char *username = row[0];
            int is_ready = 0;
            Client *tmp = head_client;
            while (tmp != NULL) {
                if (tmp->room_id == room_id && strcmp(tmp->login_account, username) == 0) {
                    is_ready = tmp->is_ready; break;
                }
                tmp = tmp->next;
            }
            if (!first) strcat(json, ","); else first = 0;
            char obj[256];
            sprintf(obj, "{\"username\":\"%s\",\"is_ready\":%s}", username, is_ready ? "true" : "false");
            strcat(json, obj);
        }
        strcat(json, "]");
        mysql_free_result(res);
        strcpy(msg.value, json);
        
        Client *tmp = head_client;
        while (tmp != NULL) {
            if (tmp->room_id == room_id) {
                int target = (tmp->async_conn_fd > 0) ? tmp->async_conn_fd : tmp->conn_fd;
                send(target, &msg, sizeof(Message), 0);
            }
            tmp = tmp->next;
        }
    }
    pthread_mutex_unlock(&mutex);
}

int handle_create_room(Client *cli, char room_code[BUFF_SIZE])
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[1024];
    int result = CREATE_ROOM_FAIL;
    
    pthread_mutex_lock(&mutex);
    if (cli->room_id > 0) { pthread_mutex_unlock(&mutex); return CREATE_ROOM_FAIL; }
    
    sprintf(query, "SELECT room_id FROM rooms WHERE room_code = '%s' AND status != 'CLOSED'", room_code);
    if (!mysql_query(g_db_conn, query)) {
        res = mysql_store_result(g_db_conn);
        if (mysql_fetch_row(res) != NULL) { mysql_free_result(res); pthread_mutex_unlock(&mutex); return CREATE_ROOM_FAIL; }
        mysql_free_result(res);
    }
    
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    if (!mysql_query(g_db_conn, query)) {
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        if (row) {
            int user_id = atoi(row[0]);
            mysql_free_result(res);
            sprintf(query, "INSERT INTO rooms (room_code, host_user_id, status, max_players) VALUES ('%s', %d, 'LOBBY', 4)", room_code, user_id);
            if (!mysql_query(g_db_conn, query)) {
                int room_id = (int)mysql_insert_id(g_db_conn);
                sprintf(query, "INSERT INTO room_members (room_id, user_id, role) VALUES (%d, %d, 'PLAYER')", room_id, user_id);
                mysql_query(g_db_conn, query);
                cli->room_id = room_id;
                cli->is_ready = 1;
                result = CREATE_ROOM_SUCCESS;
                printf("Room created: %s (%d)\n", room_code, room_id);
            }
        } else { mysql_free_result(res); }
    }
    pthread_mutex_unlock(&mutex);
    return result;
}

int handle_join_room(Client *cli, char room_code[BUFF_SIZE])
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[1024];
    int result = JOIN_ROOM_FAIL;
    
    pthread_mutex_lock(&mutex);
    if (cli->room_id > 0) { pthread_mutex_unlock(&mutex); return JOIN_ROOM_FAIL; }
    
    sprintf(query, "SELECT room_id, max_players FROM rooms WHERE room_code = '%s' AND status = 'LOBBY'", room_code);
    if (!mysql_query(g_db_conn, query)) {
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        if (row) {
            int room_id = atoi(row[0]);
            int max_players = atoi(row[1]);
            mysql_free_result(res);
            
            sprintf(query, "SELECT COUNT(*) FROM room_members WHERE room_id = %d AND left_at IS NULL", room_id);
            if (!mysql_query(g_db_conn, query)) {
                res = mysql_store_result(g_db_conn);
                row = mysql_fetch_row(res);
                int curr = atoi(row[0]);
                mysql_free_result(res);
                
                if (curr >= max_players) { pthread_mutex_unlock(&mutex); return ROOM_FULL; }
                
                sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
                mysql_query(g_db_conn, query);
                res = mysql_store_result(g_db_conn);
                row = mysql_fetch_row(res);
                int user_id = atoi(row[0]);
                mysql_free_result(res);
                
                sprintf(query, "SELECT left_at FROM room_members WHERE room_id = %d AND user_id = %d", room_id, user_id);
                mysql_query(g_db_conn, query);
                res = mysql_store_result(g_db_conn);
                if (mysql_fetch_row(res)) {
                    mysql_free_result(res);
                    sprintf(query, "UPDATE room_members SET left_at = NULL, joined_at = NOW() WHERE room_id = %d AND user_id = %d", room_id, user_id);
                } else {
                    mysql_free_result(res);
                    sprintf(query, "INSERT INTO room_members (room_id, user_id, role) VALUES (%d, %d, 'PLAYER')", room_id, user_id);
                }
                mysql_query(g_db_conn, query);
                cli->room_id = room_id;
                cli->is_ready = 0;
                result = JOIN_ROOM_SUCCESS;
            }
        } else { mysql_free_result(res); }
    }
    pthread_mutex_unlock(&mutex);
    return result;
}

int handle_leave_room(Client *cli)
{
    char query[1024];
    pthread_mutex_lock(&mutex);
    if (cli->room_id <= 0) { pthread_mutex_unlock(&mutex); return LEAVE_ROOM_SUCCESS; }
    
    int room_id = cli->room_id;
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    if (!mysql_query(g_db_conn, query)) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row = mysql_fetch_row(res);
        int user_id = atoi(row[0]);
        mysql_free_result(res);
        
        sprintf(query, "UPDATE room_members SET left_at = NOW() WHERE room_id = %d AND user_id = %d", room_id, user_id);
        mysql_query(g_db_conn, query);
        
        // Host check
        sprintf(query, "SELECT host_user_id FROM rooms WHERE room_id = %d", room_id);
        mysql_query(g_db_conn, query);
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        if (row && atoi(row[0]) == user_id) {
            mysql_free_result(res);
            sprintf(query, "SELECT user_id FROM room_members WHERE room_id = %d AND user_id != %d AND left_at IS NULL ORDER BY joined_at LIMIT 1", room_id, user_id);
            if (!mysql_query(g_db_conn, query)) {
                res = mysql_store_result(g_db_conn);
                row = mysql_fetch_row(res);
                if (row) {
                    int new_host = atoi(row[0]);
                    mysql_free_result(res);
                    sprintf(query, "UPDATE rooms SET host_user_id = %d WHERE room_id = %d", new_host, room_id);
                    mysql_query(g_db_conn, query);
                } else {
                    mysql_free_result(res);
                    sprintf(query, "UPDATE rooms SET status = 'CLOSED' WHERE room_id = %d", room_id);
                    mysql_query(g_db_conn, query);
                }
            }
        } else { mysql_free_result(res); }
    }
    cli->room_id = 0;
    cli->is_ready = 0;
    pthread_mutex_unlock(&mutex);
    return LEAVE_ROOM_SUCCESS;
}

int handle_invite_user(Client *cli, char target_username[BUFF_SIZE])
{
    char query[1024];
    pthread_mutex_lock(&mutex);
    if (cli->room_id <= 0) { pthread_mutex_unlock(&mutex); return INVITE_FAIL; }
    
    int from_id, to_id;
    // Get IDs
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    mysql_query(g_db_conn, query);
    MYSQL_RES *res = mysql_store_result(g_db_conn);
    MYSQL_ROW row = mysql_fetch_row(res);
    from_id = atoi(row[0]);
    mysql_free_result(res);
    
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s' AND is_online = 1", target_username);
    if (mysql_query(g_db_conn, query)) { pthread_mutex_unlock(&mutex); return INVITE_FAIL; }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (!row) { mysql_free_result(res); pthread_mutex_unlock(&mutex); return INVITE_FAIL; }
    to_id = atoi(row[0]);
    mysql_free_result(res);
    
    sprintf(query, "INSERT INTO invitations (room_id, from_user_id, to_user_id, status) VALUES (%d, %d, %d, 'PENDING')", cli->room_id, from_id, to_id);
    if (mysql_query(g_db_conn, query)) { pthread_mutex_unlock(&mutex); return INVITE_FAIL; }
    int inv_id = (int)mysql_insert_id(g_db_conn);
    pthread_mutex_unlock(&mutex);
    
    send_invite_notification(to_id, from_id, cli->room_id, inv_id);
    return INVITE_SUCCESS;
}

void send_invite_notification(int to_user_id, int from_user_id, int room_id, int invitation_id)
{
    pthread_mutex_lock(&mutex);
    Message msg;
    msg.type = INVITE_NOTIFY;
    char query[1024];
    sprintf(query, "SELECT u.username, r.room_code FROM users u, rooms r WHERE u.user_id = %d AND r.room_id = %d", from_user_id, room_id);
    if (!mysql_query(g_db_conn, query)) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row = mysql_fetch_row(res);
        if (row) {
            sprintf(msg.value, "%d|%s|%s", invitation_id, row[0], row[1]);
            mysql_free_result(res);
            
            sprintf(query, "SELECT username FROM users WHERE user_id = %d", to_user_id);
            mysql_query(g_db_conn, query);
            res = mysql_store_result(g_db_conn);
            row = mysql_fetch_row(res);
            char *target_user = row[0];
            
            Client *tmp = head_client;
            while (tmp != NULL) {
                if (strcmp(tmp->login_account, target_user) == 0) {
                    int fd = (tmp->async_conn_fd > 0) ? tmp->async_conn_fd : tmp->conn_fd;
                    send(fd, &msg, sizeof(Message), 0);
                    break;
                }
                tmp = tmp->next;
            }
            mysql_free_result(res);
        } else mysql_free_result(res);
    }
    pthread_mutex_unlock(&mutex);
}

int handle_invite_response(Client *cli, int invitation_id, int accept)
{
    char query[1024];
    pthread_mutex_lock(&mutex);
    sprintf(query, "SELECT room_id FROM invitations WHERE invitation_id = %d AND status = 'PENDING'", invitation_id);
    if (mysql_query(g_db_conn, query)) { pthread_mutex_unlock(&mutex); return INVITE_FAIL; }
    MYSQL_RES *res = mysql_store_result(g_db_conn);
    MYSQL_ROW row = mysql_fetch_row(res);
    if (!row) { mysql_free_result(res); pthread_mutex_unlock(&mutex); return INVITE_FAIL; }
    int room_id = atoi(row[0]);
    mysql_free_result(res);
    
    sprintf(query, "UPDATE invitations SET status = '%s' WHERE invitation_id = %d", accept ? "ACCEPTED" : "DECLINED", invitation_id);
    mysql_query(g_db_conn, query);
    pthread_mutex_unlock(&mutex);
    
    if (accept) {
        pthread_mutex_lock(&mutex);
        sprintf(query, "SELECT room_code FROM rooms WHERE room_id = %d", room_id);
        mysql_query(g_db_conn, query);
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        char room_code[BUFF_SIZE];
        strcpy(room_code, row[0]);
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return handle_join_room(cli, room_code);
    }
    return INVITE_FAIL;
}

int handle_ready_toggle(Client *cli)
{
    char query[1024];
    pthread_mutex_lock(&mutex);
    if (cli->room_id <= 0) { pthread_mutex_unlock(&mutex); return READY_UPDATE; }
    
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    mysql_query(g_db_conn, query);
    MYSQL_RES *res = mysql_store_result(g_db_conn);
    MYSQL_ROW row = mysql_fetch_row(res);
    int user_id = atoi(row[0]);
    mysql_free_result(res);
    
    sprintf(query, "SELECT host_user_id FROM rooms WHERE room_id = %d", cli->room_id);
    mysql_query(g_db_conn, query);
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row && atoi(row[0]) != user_id) {
        cli->is_ready = !cli->is_ready;
    }
    mysql_free_result(res);
    pthread_mutex_unlock(&mutex);
    return READY_UPDATE;
}

int handle_start_game(Client *cli)
{
    char query[1024];
    pthread_mutex_lock(&mutex);
    if (cli->room_id <= 0) { pthread_mutex_unlock(&mutex); return START_GAME_FAIL; }
    
    // Validate host and player count (simplified)
    sprintf(query, "UPDATE rooms SET status = 'PLAYING' WHERE room_id = %d", cli->room_id);
    if (mysql_query(g_db_conn, query)) { pthread_mutex_unlock(&mutex); return START_GAME_FAIL; }
    
    create_match_in_memory(cli->room_id);
    pthread_mutex_unlock(&mutex);
    
    Match *m = find_match(cli->room_id);
    if (m) {
        char json[100];
        sprintf(json, "{\"type\":\"ROUND_START\",\"round\":3,\"turn_user\":\"%s\"}", m->player_names[0]);
        broadcast_match_json(m, json, GAME_START_NOTIFY); 
    }
    
    return START_GAME_SUCCESS;
}