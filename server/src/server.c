// server/src/server.c
#include "server.h"
#include "database.h"
#include <math.h>

// Global variables
Client *head_client = NULL;
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
extern MYSQL *g_db_conn;  // From database.c
Match *head_match = NULL;

// ==================== CLIENT MANAGEMENT ====================

Client *new_client()
{
    Client *new = (Client *)malloc(sizeof(Client));
    new->login_status = UN_AUTH;
    new->async_conn_fd = -1;
    new->room_id = 0;
    new->is_ready = 0;
    new->is_viewer = 0;
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
            // Close both sockets if they exist
            if (tmp->conn_fd >= 0) {
                close(tmp->conn_fd);
            }
            if (tmp->async_conn_fd >= 0 && tmp->async_conn_fd != conn_fd) {
                close(tmp->async_conn_fd);
            }
            
            if (prev == NULL)
                head_client = tmp->next;
            else
                prev->next = tmp->next;
            free(tmp);
            printf("[%d] Client removed from list (both sockets closed)\n", conn_fd);
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
        if (tmp->conn_fd == conn_fd)
            return tmp;
        tmp = tmp->next;
    }
    return NULL;
}

// ==================== AUTHENTICATION ====================

int handle_signup(char username[BUFF_SIZE], char password[BUFF_SIZE])
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[256];
    int result;
    
    printf("Signup attempt: username='%s'\n", username);
    
    pthread_mutex_lock(&mutex);
    
    // Kiểm tra username đã tồn tại chưa
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", username);
    
    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "MySQL query error: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return ACCOUNT_EXIST;
    }
    
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    
    if (row != NULL) {
        // Account đã tồn tại
        mysql_free_result(res);
        result = ACCOUNT_EXIST;
        printf("Account already exists: %s\n", username);
    } else {
        // Tạo account mới
        mysql_free_result(res);
        sprintf(query, "INSERT INTO users (username, password_hash, is_online) VALUES ('%s', '%s', 0)", 
                username, password);
        
        if (mysql_query(g_db_conn, query)) {
            fprintf(stderr, "MySQL insert error: %s\n", mysql_error(g_db_conn));
            result = ACCOUNT_EXIST;
        } else {
            result = SIGNUP_SUCCESS;
            printf("Signup success: %s\n", username);
        }
        // INSERT không trả về result set, không gọi mysql_store_result()
    }
    pthread_mutex_unlock(&mutex);
    
    return result;
}

int handle_login(Client *cli, char username[BUFF_SIZE], char password[BUFF_SIZE])
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[256];
    int result;
    
    printf("Login attempt: username='%s'\n", username);
    
    pthread_mutex_lock(&mutex);
    
    // Kiểm tra username có tồn tại không (bỏ is_blocked vì không có trong schema)
    sprintf(query, "SELECT user_id, password_hash, is_online FROM users WHERE username = '%s'", username);
    
    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "MySQL query error: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return ACCOUNT_NOT_EXIST;
    }
    
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    
    if (row == NULL) {
        // Account không tồn tại
        mysql_free_result(res);
        result = ACCOUNT_NOT_EXIST;
        printf("Account does not exist: %s\n", username);
    } else {
        // Lấy thông tin user
        // int user_id = atoi(row[0]);
        char *db_password = row[1];
        int is_online = atoi(row[2]);
        
        mysql_free_result(res);
        
        // Kiểm tra account có đang online không
        if (is_online) {
            result = LOGGED_IN;
            printf("Account already logged in: %s\n", username);
        }
        // Kiểm tra password
        else if (strcmp(password, db_password) != 0) {
            result = WRONG_PASSWORD;
            printf("Wrong password for: %s\n", username);
        }
        // Login thành công
        else {
            // Cập nhật is_online = 1
            sprintf(query, "UPDATE users SET is_online = 1 WHERE username = '%s'", username);
            if (mysql_query(g_db_conn, query)) {
                fprintf(stderr, "MySQL update error: %s\n", mysql_error(g_db_conn));
                result = ACCOUNT_NOT_EXIST;
            } else {
                // Cập nhật client info
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
    
    // Find the client by username
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
    
    // Set async socket
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
                    // Parse format: username | password
                    char *token = strtok(msg.value, "|");
                    if (token != NULL) {
                        // Trim leading/trailing spaces
                        while (*token == ' ') token++;
                        strcpy(username, token);
                        // Remove trailing spaces
                        char *end = username + strlen(username) - 1;
                        while (end > username && *end == ' ') {
                            *end = '\0';
                            end--;
                        }
                        
                        token = strtok(NULL, "|");
                        if (token != NULL) {
                            while (*token == ' ') token++;
                            strcpy(password, token);
                            end = password + strlen(password) - 1;
                            while (end > password && *end == ' ') {
                                *end = '\0';
                                end--;
                            }
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
                    // Parse format: username | password
                    char *token = strtok(msg.value, "|");
                    if (token != NULL) {
                        // Trim leading/trailing spaces
                        while (*token == ' ') token++;
                        strcpy(username, token);
                        // Remove trailing spaces
                        char *end = username + strlen(username) - 1;
                        while (end > username && *end == ' ') {
                            *end = '\0';
                            end--;
                        }
                        
                        token = strtok(NULL, "|");
                        if (token != NULL) {
                            while (*token == ' ') token++;
                            strcpy(password, token);
                            end = password + strlen(password) - 1;
                            while (end > password && *end == ' ') {
                                *end = '\0';
                                end--;
                            }
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
                    // Trim whitespace
                    char *end = username + strlen(username) - 1;
                    while (end > username && *end == ' ') {
                        *end = '\0';
                        end--;
                    }
                    
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
                
                // Update database
                pthread_mutex_lock(&mutex);
                char query[256];
                sprintf(query, "UPDATE users SET is_online = 0 WHERE username = '%s'", cli->login_account);
                mysql_query(g_db_conn, query);
                pthread_mutex_unlock(&mutex);
                
                cli->login_status = UN_AUTH;
                memset(cli->login_account, 0, sizeof(cli->login_account));
                
                // Send logout success response
                Message response;
                response.type = LOGOUT_SUCCESS;
                send(conn_fd, &response, sizeof(Message), 0);
                break;
                
            case GET_ROOMS:
                {
                    printf("[%d] Client requested room list\n", conn_fd);
                    pthread_mutex_lock(&mutex);
                    char q[512];
                    // Hiển thị cả phòng LOBBY (có thể join) và PLAYING (có thể xem)
                    sprintf(q, "SELECT room_id, room_code, max_players, status, "
                               "(SELECT COUNT(*) FROM room_members rm WHERE rm.room_id = r.room_id AND rm.left_at IS NULL AND rm.role = 'PLAYER') AS current_players "
                               "FROM rooms r "
                               "WHERE r.status IN ('LOBBY', 'PLAYING') "
                               "HAVING current_players > 0");
                    if (mysql_query(g_db_conn, q)) {
                        fprintf(stderr, "MySQL query error: %s\n", mysql_error(g_db_conn));
                        msg.type = GET_ROOMS_RESULT;
                        msg.value[0] = '\0';
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
                            const char *room_id = row[0] ? row[0] : "0";
                            const char *room_code = row[1] ? row[1] : "";
                            const char *max_p = row[2] ? row[2] : "0";
                            const char *status = row[3] ? row[3] : "LOBBY";
                            const char *cur_p = row[4] ? row[4] : "0";
                            snprintf(entry, sizeof(entry), "{\"room_id\":%s,\"room_code\":\"%s\",\"players\":\"%s/%s\",\"status\":\"%s\"}", 
                                    room_id, room_code, cur_p, max_p, status);
                            strcat(json, entry);
                        }
                        strcat(json, "]");
                        mysql_free_result(res);
                        msg.type = GET_ROOMS_RESULT;
                        strncpy(msg.value, json, sizeof(msg.value)-1);
                        msg.value[sizeof(msg.value)-1] = '\0';
                        send(conn_fd, &msg, sizeof(Message), 0);
                    }
                    pthread_mutex_unlock(&mutex);
                }
                break;
                
            case GET_ONLINE_USERS:
                {
                    printf("[%d] Client requested online users\n", conn_fd);
                    pthread_mutex_lock(&mutex);
                    char q2[256];
                    sprintf(q2, "SELECT username FROM users WHERE is_online = 1");
                    if (mysql_query(g_db_conn, q2)) {
                        fprintf(stderr, "MySQL query error: %s\n", mysql_error(g_db_conn));
                        msg.type = GET_ONLINE_USERS_RESULT;
                        msg.value[0] = '\0';
                        send(conn_fd, &msg, sizeof(Message), 0);
                    } else {
                        MYSQL_RES *res2 = mysql_store_result(g_db_conn);
                        MYSQL_ROW row2;
                        char json2[BUFF_SIZE];
                        int first2 = 1;
                        strcpy(json2, "[");
                        while ((row2 = mysql_fetch_row(res2)) != NULL) {
                            if (!first2) strcat(json2, ","); else first2 = 0;
                            char entry2[128];
                            const char *uname = row2[0] ? row2[0] : "";
                            snprintf(entry2, sizeof(entry2), "\"%s\"", uname);
                            strcat(json2, entry2);
                        }
                        strcat(json2, "]");
                        mysql_free_result(res2);
                        msg.type = GET_ONLINE_USERS_RESULT;
                        strncpy(msg.value, json2, sizeof(msg.value)-1);
                        msg.value[sizeof(msg.value)-1] = '\0';
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
                    if (result == JOIN_ROOM_SUCCESS) {
                        broadcast_room_state(cli->room_id);
                    }
                }
                break;
                
            case LEAVE_ROOM:
                {
                    int old_room = cli->room_id;
                    result = handle_leave_room(cli);
                    
                    // Gửi response qua async socket nếu có, nếu không thì qua socket chính
                    msg.type = result;
                    int target_fd = (cli->async_conn_fd >= 0) ? cli->async_conn_fd : conn_fd;
                    int sent = send(target_fd, &msg, sizeof(Message), 0);
                    printf("[%d] Sent LEAVE_ROOM_SUCCESS response via fd=%d, bytes=%d\n", 
                           conn_fd, target_fd, sent);
                    
                    // Broadcast cho các client còn lại SAU KHI đã gửi response
                    if (result == LEAVE_ROOM_SUCCESS && old_room > 0) {
                        broadcast_room_state(old_room);
                    }
                }
                break;
                
            case JOIN_AS_VIEWER:
                {
                    char room_code[BUFF_SIZE];
                    strcpy(room_code, msg.value);
                    result = handle_join_as_viewer(cli, room_code);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                    if (result == JOIN_AS_VIEWER_SUCCESS) {
                        send_viewer_state(cli);
                    }
                }
                break;
                
            case LEAVE_VIEWER:
                {
                    result = handle_leave_viewer(cli);
                    msg.type = LEAVE_ROOM_SUCCESS;
                    send(conn_fd, &msg, sizeof(Message), 0);
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
                    if (accept && result == JOIN_ROOM_SUCCESS) {
                        broadcast_room_state(cli->room_id);
                    }
                }
                break;
                
            case READY_TOGGLE:
                {
                    result = handle_ready_toggle(cli);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                    if (result == READY_UPDATE) {
                        broadcast_room_state(cli->room_id);
                    }
                }
                break;
                
            case KICK_USER:
                {
                    char target_username[BUFF_SIZE];
                    strcpy(target_username, msg.value);
                    int old_room = cli->room_id;
                    result = handle_kick_user(cli, target_username);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                    if (result == KICK_SUCCESS && old_room > 0) {
                        broadcast_room_state(old_room);
                    }
                }
                break;
                
            case START_GAME:
                {
                    result = handle_start_game(cli);
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                    // Game thread is created inside handle_start_game()
                }
                break;
                
            case ANSWER_SUBMIT:
                {
                    result = handle_answer_submit(cli, msg.value);
                    // Result is broadcasted to all players after all answers or timeout
                }
                break;
                
            case PRICE_SUBMIT:
                {
                    result = handle_price_submit(cli, msg.value);
                    // Result is broadcasted to all players after all answers or timeout
                }
                break;
                
            case GET_ROOM_INFO:
                {
                    printf("[%d] Client requested room info\n", conn_fd);
                    pthread_mutex_lock(&mutex);
                    
                    if (cli->room_id <= 0) {
                        msg.type = GET_ROOM_INFO_RESULT;
                        msg.value[0] = '\0';
                        send(conn_fd, &msg, sizeof(Message), 0);
                    } else {
                        char q[1024];
                        // Get room info with members
                        sprintf(q, 
                            "SELECT r.room_code, r.host_user_id, r.max_players, "
                            "(SELECT GROUP_CONCAT(u.username ORDER BY rm.joined_at SEPARATOR '|') "
                            " FROM room_members rm JOIN users u ON rm.user_id = u.user_id "
                            " WHERE rm.room_id = r.room_id AND rm.left_at IS NULL AND rm.role = 'PLAYER') AS members, "
                            "(SELECT u.username FROM users u WHERE u.user_id = r.host_user_id) AS host_name "
                            "FROM rooms r WHERE r.room_id = %d", cli->room_id);
                        
                        if (mysql_query(g_db_conn, q)) {
                            fprintf(stderr, "MySQL query error: %s\n", mysql_error(g_db_conn));
                            msg.type = GET_ROOM_INFO_RESULT;
                            msg.value[0] = '\0';
                            send(conn_fd, &msg, sizeof(Message), 0);
                        } else {
                            MYSQL_RES *res = mysql_store_result(g_db_conn);
                            MYSQL_ROW row = mysql_fetch_row(res);
                            
                            if (row != NULL) {
                                char json[BUFF_SIZE];
                                const char *room_code = row[0] ? row[0] : "";
                                const char *max_p = row[2] ? row[2] : "4";
                                const char *members = row[3] ? row[3] : "";
                                const char *host_name = row[4] ? row[4] : "";
                                
                                snprintf(json, sizeof(json), 
                                    "{\"room_code\":\"%s\",\"max_players\":%s,\"members\":\"%s\",\"host_name\":\"%s\"}", 
                                    room_code, max_p, members, host_name);
                                
                                msg.type = GET_ROOM_INFO_RESULT;
                                strncpy(msg.value, json, sizeof(msg.value)-1);
                                msg.value[sizeof(msg.value)-1] = '\0';
                                send(conn_fd, &msg, sizeof(Message), 0);
                            } else {
                                msg.type = GET_ROOM_INFO_RESULT;
                                msg.value[0] = '\0';
                                send(conn_fd, &msg, sizeof(Message), 0);
                            }
                            mysql_free_result(res);
                        }
                    }
                    pthread_mutex_unlock(&mutex);
                }
                break;
            case ROUND_ANSWER:
                handle_round_3_move(cli, msg.value);
                break;
                 
            default:
                 printf("[%d] Unhandled message type: %d\n", conn_fd, msg.type);
                 break;
             }
             break;
        }
    }
    
    if (recv_bytes <= 0) {
        if (recv_bytes == 0)
            printf("[%d] Client closed connection\n", conn_fd);
        else
            perror("recv error");
    }
    
    // Cleanup - set user offline and leave room
    if (cli && cli->login_status == AUTH) {
        pthread_mutex_lock(&mutex);
        char query[512];
        
        // Set user offline
        sprintf(query, "UPDATE users SET is_online = 0 WHERE username = '%s'", cli->login_account);
        mysql_query(g_db_conn, query);
        
        // If user is in a room, handle leaving
        if (cli->room_id > 0) {
            int old_room = cli->room_id;
            
            // Get user_id
            sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
            if (mysql_query(g_db_conn, query) == 0) {
                MYSQL_RES *res = mysql_store_result(g_db_conn);
                MYSQL_ROW row = mysql_fetch_row(res);
                if (row != NULL) {
                    int user_id = atoi(row[0]);
                    mysql_free_result(res);
                    
                    // Update left_at in room_members
                    sprintf(query, "UPDATE room_members SET left_at = NOW() WHERE room_id = %d AND user_id = %d", 
                            old_room, user_id);
                    mysql_query(g_db_conn, query);
                    
                    // Check if user was host
                    sprintf(query, "SELECT host_user_id FROM rooms WHERE room_id = %d", old_room);
                    if (mysql_query(g_db_conn, query) == 0) {
                        res = mysql_store_result(g_db_conn);
                        row = mysql_fetch_row(res);
                        if (row != NULL && atoi(row[0]) == user_id) {
                            // Host left - close room
                            mysql_free_result(res);
                            sprintf(query, "UPDATE rooms SET status = 'CLOSED' WHERE room_id = %d", old_room);
                            mysql_query(g_db_conn, query);
                            printf("[%d] Host left, room %d closed\n", conn_fd, old_room);
                        } else {
                            mysql_free_result(res);
                        }
                    }
                    
                    printf("[%d] User left room %d on disconnect\n", conn_fd, old_room);
                } else {
                    mysql_free_result(res);
                }
            }
        }
        
        pthread_mutex_unlock(&mutex);
        printf("[%d] User '%s' set offline and cleaned up\n", conn_fd, cli->login_account);
    }
    
    close(conn_fd);
    delete_client(conn_fd);
    
    printf("[%d] Client handler terminated\n", conn_fd);
    pthread_exit(NULL);
}

// ==================== SIGNAL HANDLER ====================

void catch_ctrl_c_and_exit(int sig)
{
    (void)sig;
    printf("\n[SERVER] Shutting down...\n");
    
    // Close all client connections
    Client *tmp = head_client;
    while (tmp != NULL) {
        close(tmp->conn_fd);
        tmp = tmp->next;
    }
    
    // Close database
    db_close();
    
    printf("[SERVER] Bye!\n");
    exit(0);
}

// ==================== MAIN SERVER ====================

void start_server(int port)
{
    int listen_fd, conn_fd;
    struct sockaddr_in servaddr, cliaddr;
    socklen_t cli_len;
    pthread_t tid;
    
    // Setup signal handler
    signal(SIGINT, catch_ctrl_c_and_exit);
    
    // Tạo socket
    listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        perror("socket() failed");
        exit(EXIT_FAILURE);
    }
    
    // Reuse address
    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    // Bind
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    servaddr.sin_port = htons(port);
    
    if (bind(listen_fd, (struct sockaddr*)&servaddr, sizeof(servaddr)) < 0) {
        perror("bind() failed");
        close(listen_fd);
        exit(EXIT_FAILURE);
    }
    
    // Listen
    if (listen(listen_fd, BACKLOG) < 0) {
        perror("listen() failed");
        close(listen_fd);
        exit(EXIT_FAILURE);
    }
    
    printf("[SERVER] Listening on port %d...\n", port);
    printf("[SERVER] Press Ctrl+C to stop\n");
    
    // Accept loop
    while (1) {
        cli_len = sizeof(cliaddr);
        conn_fd = accept(listen_fd, (struct sockaddr*)&cliaddr, &cli_len);
        
        if (conn_fd < 0) {
            perror("accept() failed");
            continue;
        }
        
        printf("[SERVER] New client [%d] from %s:%d\n",
               conn_fd,
               inet_ntoa(cliaddr.sin_addr),
               ntohs(cliaddr.sin_port));
        
        // Add client to list
        add_client(conn_fd);
        
        // Create thread to handle client
        int *pclient = malloc(sizeof(int));
        *pclient = conn_fd;
        
        if (pthread_create(&tid, NULL, handle_client, pclient) != 0) {
            perror("pthread_create() failed");
            free(pclient);
            close(conn_fd);
            delete_client(conn_fd);
        }
    }
    
    close(listen_fd);
}

// ==================== ROOM MANAGEMENT ====================

int handle_create_room(Client *cli, char room_code[BUFF_SIZE])
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[512];
    int result;
    
    printf("[%d] Create room: %s by %s\n", cli->conn_fd, room_code, cli->login_account);
    
    pthread_mutex_lock(&mutex);
    
    // Kiểm tra xem user đã ở trong phòng nào chưa
    if (cli->room_id > 0) {
        pthread_mutex_unlock(&mutex);
        return CREATE_ROOM_FAIL;
    }
    
    // Kiểm tra room_code đã tồn tại chưa
    sprintf(query, "SELECT room_id FROM rooms WHERE room_code = '%s' AND status != 'CLOSED'", room_code);
    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "MySQL query error: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return CREATE_ROOM_FAIL;
    }
    
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    
    if (row != NULL) {
        // Room code đã tồn tại
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return CREATE_ROOM_FAIL;
    }
    mysql_free_result(res);
    
    // Lấy user_id
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return CREATE_ROOM_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return CREATE_ROOM_FAIL;
    }
    int user_id = atoi(row[0]);
    mysql_free_result(res);
    
    // Tạo room mới (max_players = 4)
    sprintf(query, "INSERT INTO rooms (room_code, host_user_id, status, max_players) VALUES ('%s', %d, 'LOBBY', 4)", 
            room_code, user_id);
    
    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "MySQL insert error: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return CREATE_ROOM_FAIL;
    }
    
    int room_id = (int)mysql_insert_id(g_db_conn);
    
    // Thêm host vào room_members
    sprintf(query, "INSERT INTO room_members (room_id, user_id, role) VALUES (%d, %d, 'PLAYER')", 
            room_id, user_id);
    
    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "MySQL insert error: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return CREATE_ROOM_FAIL;
    }
    
    cli->room_id = room_id;
    cli->is_ready = 1; // Host luôn ready
    result = CREATE_ROOM_SUCCESS;
    
    pthread_mutex_unlock(&mutex);
    
    printf("[%d] Room created: %s (id=%d)\n", cli->conn_fd, room_code, room_id);
    return result;
}

int handle_join_room(Client *cli, char room_code[BUFF_SIZE])
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[512];
    int result;
    
    printf("[%d] Join room: %s by %s\n", cli->conn_fd, room_code, cli->login_account);
    
    pthread_mutex_lock(&mutex);
    
    // Kiểm tra xem user đã ở trong phòng nào chưa
    if (cli->room_id > 0) {
        pthread_mutex_unlock(&mutex);
        return JOIN_ROOM_FAIL;
    }
    
    // Tìm room
    sprintf(query, "SELECT room_id, max_players FROM rooms WHERE room_code = '%s' AND status = 'LOBBY'", room_code);
    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "MySQL query error: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return JOIN_ROOM_FAIL;
    }
    
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    
    if (row == NULL) {
        // Room không tồn tại hoặc không ở trạng thái LOBBY
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return JOIN_ROOM_FAIL;
    }
    
    int room_id = atoi(row[0]);
    int max_players = atoi(row[1]);
    mysql_free_result(res);
    
    // Kiểm tra số người trong phòng
    sprintf(query, "SELECT COUNT(*) FROM room_members WHERE room_id = %d AND left_at IS NULL AND role = 'PLAYER'", room_id);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return JOIN_ROOM_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    int current_players = atoi(row[0]);
    mysql_free_result(res);
    
    if (current_players >= max_players) {
        pthread_mutex_unlock(&mutex);
        return ROOM_FULL;
    }
    
    // Lấy user_id
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return JOIN_ROOM_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return JOIN_ROOM_FAIL;
    }
    int user_id = atoi(row[0]);
    mysql_free_result(res);
    
    // Kiểm tra xem user đã có record trong room_members chưa
    sprintf(query, "SELECT left_at FROM room_members WHERE room_id = %d AND user_id = %d", 
            room_id, user_id);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return JOIN_ROOM_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    
    if (row != NULL) {
        // User đã có record, UPDATE để rejoin
        mysql_free_result(res);
        sprintf(query, "UPDATE room_members SET left_at = NULL, joined_at = NOW() WHERE room_id = %d AND user_id = %d", 
                room_id, user_id);
        if (mysql_query(g_db_conn, query)) {
            fprintf(stderr, "MySQL update error: %s\n", mysql_error(g_db_conn));
            pthread_mutex_unlock(&mutex);
            return JOIN_ROOM_FAIL;
        }
    } else {
        // User chưa có record, INSERT mới
        mysql_free_result(res);
        sprintf(query, "INSERT INTO room_members (room_id, user_id, role) VALUES (%d, %d, 'PLAYER')", 
                room_id, user_id);
        if (mysql_query(g_db_conn, query)) {
            fprintf(stderr, "MySQL insert error: %s\n", mysql_error(g_db_conn));
            pthread_mutex_unlock(&mutex);
            return JOIN_ROOM_FAIL;
        }
    }
    
    cli->room_id = room_id;
    cli->is_ready = 0;
    result = JOIN_ROOM_SUCCESS;
    
    pthread_mutex_unlock(&mutex);
    
    printf("[%d] Joined room: %s (id=%d)\n", cli->conn_fd, room_code, room_id);
    
    return result;
}

int handle_leave_room(Client *cli)
{
    char query[512];
    
    printf("[%d] Leave room by %s\n", cli->conn_fd, cli->login_account);
    
    pthread_mutex_lock(&mutex);
    
    if (cli->room_id <= 0) {
        pthread_mutex_unlock(&mutex);
        return LEAVE_ROOM_SUCCESS;
    }
    
    int room_id = cli->room_id;
    
    // Lấy user_id
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return LEAVE_ROOM_SUCCESS;
    }
    MYSQL_RES *res = mysql_store_result(g_db_conn);
    MYSQL_ROW row = mysql_fetch_row(res);
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return LEAVE_ROOM_SUCCESS;
    }
    int user_id = atoi(row[0]);
    mysql_free_result(res);
    
    // Kiểm tra xem có game đang chơi không
    Match *m = find_match(room_id);
    int game_in_progress = (m != NULL);
    
    // Lưu điểm số hiện tại nếu đang trong game
    if (game_in_progress) {
        printf("[%d] Player leaving during game, saving current score\n", cli->conn_fd);
        
        // Tìm index của player trong match
        int player_idx = -1;
        for (int i = 0; i < m->count_players; i++) {
            if (m->player_ids[i] == user_id) {
                player_idx = i;
                m->has_left[i] = 1;  // Đánh dấu đã rời
                printf("[%d] Marked player %s (idx=%d) as LEFT\n", cli->conn_fd, m->player_names[i], i);
                break;
            }
        }
        
        // Tìm current match_id
        sprintf(query, "SELECT match_id FROM matches WHERE room_id = %d AND ended_at IS NULL LIMIT 1", room_id);
        int current_match_id = 0;
        if (mysql_query(g_db_conn, query) == 0) {
            res = mysql_store_result(g_db_conn);
            row = mysql_fetch_row(res);
            if (row) current_match_id = atoi(row[0]);
            mysql_free_result(res);
        }
        
        if (current_match_id > 0) {
            // Lưu điểm số hiện tại vào round_answers cho tất cả các vòng đã chơi
            // Điểm được tự động lưu khi người chơi trả lời, nên không cần làm gì thêm
            printf("[%d] Current score saved for user_id=%d in match_id=%d\n", cli->conn_fd, user_id, current_match_id);
        }
        
        // Broadcast thông báo người chơi rời cho TẤT CẢ người còn lại trong phòng
        char leave_message[BUFF_SIZE];
        sprintf(leave_message, "%s đã rời khỏi phòng", cli->login_account);
        
        Message notice_msg;
        notice_msg.type = SYSTEM_NOTICE;
        strcpy(notice_msg.value, leave_message);
        
        Client *tmp_cli = head_client;
        while (tmp_cli != NULL) {
            if (tmp_cli->room_id == room_id && tmp_cli->conn_fd != cli->conn_fd && tmp_cli->login_status == AUTH) {
                int target_fd = (tmp_cli->async_conn_fd >= 0) ? tmp_cli->async_conn_fd : tmp_cli->conn_fd;
                send(target_fd, &notice_msg, sizeof(Message), 0);
                printf("[%d] Sent SYSTEM_NOTICE to %s: '%s'\n", cli->conn_fd, tmp_cli->login_account, leave_message);
            }
            tmp_cli = tmp_cli->next;
        }
        
        // Nếu đang trong game, broadcast thêm thông tin chi tiết cho Match
        if (game_in_progress && player_idx >= 0) {
            char notify_json[BUFF_SIZE];
            sprintf(notify_json, "{\"type\":\"PLAYER_LEFT\",\"username\":\"%s\"}", cli->login_account);
            broadcast_match_json(m, notify_json, ROUND_INFO);
            printf("[%d] Broadcasted PLAYER_LEFT notification for %s\n", cli->conn_fd, cli->login_account);
            
            // Nếu người rời đang trong lượt chơi Round 3, chuyển sang người tiếp theo
            if (m->current_round == 3 && m->current_turn_index == player_idx) {
                printf("[%d] Player left during their turn in Round 3, skipping to next\n", cli->conn_fd);
                // Tìm người chơi tiếp theo còn lại
                int next_idx = m->current_turn_index + 1;
                while (next_idx < m->count_players && m->has_left[next_idx]) {
                    next_idx++;
                }
                
                if (next_idx < m->count_players) {
                    m->current_turn_index = next_idx;
                    char json_turn[BUFF_SIZE];
                    sprintf(json_turn, "{\"type\":\"TURN_CHANGE\",\"next_user\":\"%s\"}", m->player_names[next_idx]);
                    broadcast_match_json(m, json_turn, ROUND_INFO);
                    printf("[%d] Changed turn to %s (idx=%d)\n", cli->conn_fd, m->player_names[next_idx], next_idx);
                } else {
                    // Tất cả người còn lại đã chơi xong, kết thúc vòng 3
                    printf("[%d] All remaining players finished, ending Round 3\n", cli->conn_fd);
                }
            }
        }
    }
    
    // Cập nhật left_at TRƯỚC KHI đếm remaining_players
    sprintf(query, "UPDATE room_members SET left_at = NOW() WHERE room_id = %d AND user_id = %d", 
            room_id, user_id);
    mysql_query(g_db_conn, query);
    printf("[%d] Updated left_at for user_id=%d in room %d\n", cli->conn_fd, user_id, room_id);
    
    // Đếm số người còn lại trong phòng (chưa leave)
    sprintf(query, "SELECT COUNT(*) FROM room_members WHERE room_id = %d AND left_at IS NULL AND role = 'PLAYER'", room_id);
    int remaining_players = 0;
    if (mysql_query(g_db_conn, query) == 0) {
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        if (row) remaining_players = atoi(row[0]);
        mysql_free_result(res);
    }
    
    printf("[%d] Remaining players in room %d: %d (after counting)\n", cli->conn_fd, room_id, remaining_players);
    
    // Nếu không còn ai, kết thúc game và đóng phòng
    if (remaining_players == 0) {
        printf("[%d] *** ALL PLAYERS LEFT - CLOSING ROOM %d ***\n", cli->conn_fd, room_id);
        
        if (game_in_progress) {
            printf("[%d] Game in progress - ending match\n", cli->conn_fd);
            // Kết thúc match hiện tại
            sprintf(query, "UPDATE matches SET ended_at = NOW() WHERE room_id = %d AND ended_at IS NULL", room_id);
            int update_result = mysql_query(g_db_conn, query);
            printf("[%d] Match update result: %d\n", cli->conn_fd, update_result);
            
            // Xóa Match khỏi RAM
            Match *prev_m = NULL, *curr_m = head_match;
            while (curr_m) {
                if (curr_m->room_id == room_id) {
                    if (prev_m) prev_m->next = curr_m->next;
                    else head_match = curr_m->next;
                    free(curr_m);
                    printf("[%d] Match removed from memory\n", cli->conn_fd);
                    break;
                }
                prev_m = curr_m;
                curr_m = curr_m->next;
            }
        }
        
        // Đóng phòng
        sprintf(query, "UPDATE rooms SET status = 'CLOSED' WHERE room_id = %d", room_id);
        int close_result = mysql_query(g_db_conn, query);
        printf("[%d] *** ROOM %d CLOSED - SQL result: %d ***\n", cli->conn_fd, room_id, close_result);
        
        cli->room_id = 0;
        cli->is_ready = 0;
        pthread_mutex_unlock(&mutex);
        return LEAVE_ROOM_SUCCESS;
    }
    
    // Nếu chỉ còn 1 người và đang trong game, vẫn để họ chơi tiếp
    if (remaining_players == 1 && game_in_progress) {
        printf("[%d] Only 1 player remaining, game continues\n", cli->conn_fd);
    }
    
    // Kiểm tra xem user có phải host không
    sprintf(query, "SELECT host_user_id FROM rooms WHERE room_id = %d", room_id);
    if (mysql_query(g_db_conn, query) == 0) {
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        if (row != NULL && atoi(row[0]) == user_id) {
            // Host rời phòng
            mysql_free_result(res);
            
            // Kiểm tra còn members nào trong phòng không (không tính host đang rời)
            sprintf(query, "SELECT user_id FROM room_members WHERE room_id = %d AND user_id != %d AND left_at IS NULL AND role = 'PLAYER' ORDER BY joined_at LIMIT 1", 
                    room_id, user_id);
            if (mysql_query(g_db_conn, query) == 0) {
                res = mysql_store_result(g_db_conn);
                row = mysql_fetch_row(res);
                
                if (row != NULL) {
                    // Còn members -> chuyển host cho người đầu tiên
                    int new_host_id = atoi(row[0]);
                    mysql_free_result(res);
                    sprintf(query, "UPDATE rooms SET host_user_id = %d WHERE room_id = %d", new_host_id, room_id);
                    mysql_query(g_db_conn, query);
                    
                    // Cập nhật is_ready cho host mới
                    Client *tmp = head_client;
                    while (tmp != NULL) {
                        if (tmp->room_id == room_id) {
                            sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", tmp->login_account);
                            if (mysql_query(g_db_conn, query) == 0) {
                                MYSQL_RES *tmp_res = mysql_store_result(g_db_conn);
                                MYSQL_ROW tmp_row = mysql_fetch_row(tmp_res);
                                if (tmp_row != NULL && atoi(tmp_row[0]) == new_host_id) {
                                    tmp->is_ready = 1; // Host mới luôn ready
                                }
                                mysql_free_result(tmp_res);
                            }
                        }
                        tmp = tmp->next;
                    }
                    
                    printf("[%d] Host left, transferred to user_id=%d\n", cli->conn_fd, new_host_id);
                } else {
                    mysql_free_result(res);
                }
            }
        } else {
            mysql_free_result(res);
        }
    }
    
    // Set room_id = 0 TRƯỚC KHI return để client không nhận UPDATE_ROOM_STATE
    cli->room_id = 0;
    cli->is_ready = 0;
    
    pthread_mutex_unlock(&mutex);
    
    printf("[%d] Left room (id=%d)\n", cli->conn_fd, room_id);
    return LEAVE_ROOM_SUCCESS;
}

int handle_invite_user(Client *cli, char target_username[BUFF_SIZE])
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[512];
    
    printf("[%d] Invite user: %s to room %d\n", cli->conn_fd, target_username, cli->room_id);
    
    pthread_mutex_lock(&mutex);
    
    if (cli->room_id <= 0) {
        pthread_mutex_unlock(&mutex);
        return INVITE_FAIL;
    }
    
    // Lấy from_user_id
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return INVITE_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return INVITE_FAIL;
    }
    int from_user_id = atoi(row[0]);
    mysql_free_result(res);
    
    // Lấy to_user_id
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s' AND is_online = 1", target_username);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return INVITE_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return INVITE_FAIL;
    }
    int to_user_id = atoi(row[0]);
    mysql_free_result(res);
    
    // Hủy các invitation cũ còn PENDING từ cùng người gửi đến cùng người nhận trong cùng room
    sprintf(query, "UPDATE invitations SET status = 'EXPIRED' WHERE room_id = %d AND from_user_id = %d AND to_user_id = %d AND status = 'PENDING'", 
            cli->room_id, from_user_id, to_user_id);
    mysql_query(g_db_conn, query);
    
    // Tạo invitation
    sprintf(query, "INSERT INTO invitations (room_id, from_user_id, to_user_id, status) VALUES (%d, %d, %d, 'PENDING')", 
            cli->room_id, from_user_id, to_user_id);
    
    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "MySQL insert error: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return INVITE_FAIL;
    }
    
    int invitation_id = (int)mysql_insert_id(g_db_conn);
    
    pthread_mutex_unlock(&mutex);
    
    // Gửi thông báo đến user được mời
    send_invite_notification(to_user_id, from_user_id, cli->room_id, invitation_id);
    
    printf("[%d] Invitation sent (id=%d)\n", cli->conn_fd, invitation_id);
    return INVITE_SUCCESS;
}

int handle_invite_response(Client *cli, int invitation_id, int accept)
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[512];
    
    printf("[%d] Invite response: invitation_id=%d, accept=%d\n", cli->conn_fd, invitation_id, accept);
    
    pthread_mutex_lock(&mutex);
    
    // Lấy thông tin invitation
    sprintf(query, "SELECT room_id, to_user_id FROM invitations WHERE invitation_id = %d AND status = 'PENDING'", 
            invitation_id);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return INVITE_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return INVITE_FAIL;
    }
    int room_id = atoi(row[0]);
    mysql_free_result(res);
    
    if (accept) {
        // Cập nhật invitation status
        sprintf(query, "UPDATE invitations SET status = 'ACCEPTED', responded_at = NOW() WHERE invitation_id = %d", 
                invitation_id);
        mysql_query(g_db_conn, query);
        
        pthread_mutex_unlock(&mutex);
        
        // Join room
        sprintf(query, "%d", room_id);
        // Tìm room_code
        pthread_mutex_lock(&mutex);
        sprintf(query, "SELECT room_code FROM rooms WHERE room_id = %d", room_id);
        if (mysql_query(g_db_conn, query)) {
            pthread_mutex_unlock(&mutex);
            return INVITE_FAIL;
        }
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        if (row == NULL) {
            mysql_free_result(res);
            pthread_mutex_unlock(&mutex);
            return INVITE_FAIL;
        }
        char room_code[BUFF_SIZE];
        strcpy(room_code, row[0]);
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        
        return handle_join_room(cli, room_code);
    } else {
        // Cập nhật invitation status
        sprintf(query, "UPDATE invitations SET status = 'DECLINED', responded_at = NOW() WHERE invitation_id = %d", 
                invitation_id);
        mysql_query(g_db_conn, query);
        pthread_mutex_unlock(&mutex);
        return INVITE_FAIL;
    }
}

int handle_ready_toggle(Client *cli)
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[512];
    
    printf("[%d] Ready toggle in room %d\n", cli->conn_fd, cli->room_id);
    
    pthread_mutex_lock(&mutex);
    
    if (cli->room_id <= 0) {
        pthread_mutex_unlock(&mutex);
        return READY_UPDATE;
    }
    
    // Kiểm tra xem user có phải host không (host luôn ready)
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return READY_UPDATE;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return READY_UPDATE;
    }
    int user_id = atoi(row[0]);
    mysql_free_result(res);
    
    sprintf(query, "SELECT host_user_id FROM rooms WHERE room_id = %d", cli->room_id);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return READY_UPDATE;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row != NULL && atoi(row[0]) == user_id) {
        // Host không cần toggle ready
        mysql_free_result(res);
        cli->is_ready = 1;
        pthread_mutex_unlock(&mutex);
        return READY_UPDATE;
    }
    mysql_free_result(res);
    
    // Toggle ready status
    cli->is_ready = !cli->is_ready;
    
    pthread_mutex_unlock(&mutex);
    
    printf("[%d] Ready status: %d\n", cli->conn_fd, cli->is_ready);
    return READY_UPDATE;
}

int handle_kick_user(Client *cli, char target_username[BUFF_SIZE])
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[512];
    
    printf("[%d] Kick user: %s from room %d\n", cli->conn_fd, target_username, cli->room_id);
    
    pthread_mutex_lock(&mutex);
    
    if (cli->room_id <= 0) {
        pthread_mutex_unlock(&mutex);
        return KICK_FAIL;
    }
    
    // Kiểm tra xem user có phải host không
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return KICK_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return KICK_FAIL;
    }
    int user_id = atoi(row[0]);
    mysql_free_result(res);
    
    sprintf(query, "SELECT host_user_id FROM rooms WHERE room_id = %d", cli->room_id);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return KICK_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL || atoi(row[0]) != user_id) {
        // Chỉ host mới được kick
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return KICK_FAIL;
    }
    mysql_free_result(res);
    
    // Lấy target user_id
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", target_username);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return KICK_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return KICK_FAIL;
    }
    int target_user_id = atoi(row[0]);
    mysql_free_result(res);
    
    // Không cho kick bản thân
    if (target_user_id == user_id) {
        pthread_mutex_unlock(&mutex);
        return KICK_FAIL;
    }
    
    // Kick target user khỏi room (set left_at)
    sprintf(query, "UPDATE room_members SET left_at = NOW() WHERE room_id = %d AND user_id = %d", 
            cli->room_id, target_user_id);
    mysql_query(g_db_conn, query);
    
    // Tìm target client và update room_id, is_ready
    Client *target_cli = head_client;
    while (target_cli != NULL) {
        if (strcmp(target_cli->login_account, target_username) == 0) {
            target_cli->room_id = 0;
            target_cli->is_ready = 0;
            
            // Gửi thông báo kick đến target qua async socket
            if (target_cli->async_conn_fd >= 0) {
                Message notify;
                notify.type = KICK_NOTIFY;
                strcpy(notify.data_type, "string");
                strcpy(notify.value, cli->login_account); // Tên host kick
                notify.length = strlen(notify.value);
                send(target_cli->async_conn_fd, &notify, sizeof(Message), 0);
                printf("Sent KICK_NOTIFY to %s\n", target_username);
            }
            break;
        }
        target_cli = target_cli->next;
    }
    
    pthread_mutex_unlock(&mutex);
    
    printf("[%d] User %s kicked from room %d by host %s\n", cli->conn_fd, target_username, cli->room_id, cli->login_account);
    return KICK_SUCCESS;
}

int handle_start_game(Client *cli)
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char query[512];
    
    printf("[%d] Start game request in room %d\n", cli->conn_fd, cli->room_id);
    
    pthread_mutex_lock(&mutex);
    
    if (cli->room_id <= 0) {
        pthread_mutex_unlock(&mutex);
        return START_GAME_FAIL;
    }
    
    // Kiểm tra xem user có phải host không
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return START_GAME_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return START_GAME_FAIL;
    }
    int user_id = atoi(row[0]);
    mysql_free_result(res);
    
    sprintf(query, "SELECT host_user_id FROM rooms WHERE room_id = %d", cli->room_id);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return START_GAME_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    if (row == NULL || atoi(row[0]) != user_id) {
        // Không phải host
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return START_GAME_FAIL;
    }
    mysql_free_result(res);
    
    // Kiểm tra số người chơi (2-4)
    sprintf(query, "SELECT COUNT(*) FROM room_members WHERE room_id = %d AND left_at IS NULL AND role = 'PLAYER'", cli->room_id);
    if (mysql_query(g_db_conn, query)) {
        pthread_mutex_unlock(&mutex);
        return START_GAME_FAIL;
    }
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    int player_count = atoi(row[0]);
    mysql_free_result(res);
    
    if (player_count < 2 || player_count > 4) {
        pthread_mutex_unlock(&mutex);
        return START_GAME_FAIL;
    }
    
    // Kiểm tra tất cả mọi người đã ready chưa (trong thực tế cần check từng client)
    // Ở đây giả định là đã ready
    
    // Cập nhật room status
    sprintf(query, "UPDATE rooms SET status = 'PLAYING' WHERE room_id = %d", cli->room_id);
    mysql_query(g_db_conn, query);
    
    // Broadcast GAME_START_NOTIFY to all players in room
    Message notify_msg;
    notify_msg.type = GAME_START_NOTIFY;
    strcpy(notify_msg.value, "Game is starting!");
    
    Client *tmp = head_client;
    while (tmp != NULL) {
        if (tmp->room_id == cli->room_id && tmp->login_status == AUTH) {
            int target_fd = (tmp->async_conn_fd >= 0) ? tmp->async_conn_fd : tmp->conn_fd;
            send(target_fd, &notify_msg, sizeof(Message), 0);
            printf("Sent GAME_START_NOTIFY to %s (fd=%d)\n", tmp->login_account, target_fd);
        }
        tmp = tmp->next;
    }
    
    int room_id = cli->room_id;
    pthread_mutex_unlock(&mutex);
    
    printf("[%d] Game started in room %d\n", cli->conn_fd, room_id);
    
    // Check if a game thread is already running for this room
    pthread_mutex_lock(&mutex);
    sprintf(query, "SELECT match_id FROM matches WHERE room_id = %d AND ended_at IS NULL", room_id);
    int has_active_match = 0;
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        if (mysql_num_rows(res) > 0) {
            has_active_match = 1;
        }
        mysql_free_result(res);
    }
    pthread_mutex_unlock(&mutex);
    
    // Only create game thread if no active match exists
    if (!has_active_match) {
        // Create a thread to handle the game round (so it doesn't block the client thread)
        pthread_t game_thread;
        int *room_id_ptr = malloc(sizeof(int));
        *room_id_ptr = room_id;
        
        if (pthread_create(&game_thread, NULL, game_round_handler, room_id_ptr) != 0) {
            fprintf(stderr, "Failed to create game thread\n");
            free(room_id_ptr);
            return START_GAME_FAIL;
        }
        
        pthread_detach(game_thread);
    } else {
        printf("[%d] Game already running in room %d, skipping thread creation\n", cli->conn_fd, room_id);
    }
    
    return START_GAME_SUCCESS;
}

void broadcast_room_state(int room_id)
{
    // Broadcast trạng thái phòng đến tất cả client trong phòng
    pthread_mutex_lock(&mutex);
    
    Message msg;
    msg.type = UPDATE_ROOM_STATE;
    
    // Lấy danh sách members trong phòng với ready state
    char query[512];
    sprintf(query, "SELECT u.username FROM room_members rm JOIN users u ON rm.user_id = u.user_id WHERE rm.room_id = %d AND rm.left_at IS NULL AND rm.role = 'PLAYER' ORDER BY rm.joined_at", room_id);
    
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row;
        char json[BUFF_SIZE] = "[";
        int first = 1;
        
        while ((row = mysql_fetch_row(res)) != NULL) {
            char *username = row[0];
            
            // Tìm client tương ứng để lấy ready state
            int is_ready = 0;
            Client *tmp_cli = head_client;
            while (tmp_cli != NULL) {
                if (tmp_cli->room_id == room_id && strcmp(tmp_cli->login_account, username) == 0) {
                    is_ready = tmp_cli->is_ready;
                    break;
                }
                tmp_cli = tmp_cli->next;
            }
            
            if (!first) strcat(json, ",");
            else first = 0;
            
            // Format: {"username":"duyen","is_ready":true}
            char obj[256];
            sprintf(obj, "{\"username\":\"%s\",\"is_ready\":%s}", username, is_ready ? "true" : "false");
            strcat(json, obj);
        }
        strcat(json, "]");
        mysql_free_result(res);
        
        strcpy(msg.value, json);
        
        // Gửi đến tất cả client trong phòng qua async socket
        Client *tmp = head_client;
        while (tmp != NULL) {
            if (tmp->room_id == room_id && tmp->async_conn_fd > 0) {
                send(tmp->async_conn_fd, &msg, sizeof(Message), 0);
                printf("[%d] Sent UPDATE_ROOM_STATE to user '%s' (async_fd=%d)\n", 
                       tmp->conn_fd, tmp->login_account, tmp->async_conn_fd);
            }
            tmp = tmp->next;
        }
    }
    
    pthread_mutex_unlock(&mutex);
}

void send_invite_notification(int to_user_id, int from_user_id, int room_id, int invitation_id)
{
    printf("[INVITE_NOTIFY] Called for invitation_id=%d from user_id=%d to user_id=%d room=%d\n", 
           invitation_id, from_user_id, to_user_id, room_id);
    
    pthread_mutex_lock(&mutex);
    
    Message msg;
    msg.type = INVITE_NOTIFY;
    
    // Lấy thông tin người gửi và room
    char query[512];
    sprintf(query, "SELECT u.username, r.room_code FROM users u, rooms r WHERE u.user_id = %d AND r.room_id = %d", 
            from_user_id, room_id);
    
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row = mysql_fetch_row(res);
        
        if (row != NULL) {
            sprintf(msg.value, "%d|%s|%s", invitation_id, row[0], row[1]);
            
            // Tìm client của user được mời
            sprintf(query, "SELECT username FROM users WHERE user_id = %d", to_user_id);
            mysql_free_result(res);
            
            if (mysql_query(g_db_conn, query) == 0) {
                res = mysql_store_result(g_db_conn);
                row = mysql_fetch_row(res);
                
                if (row != NULL) {
                    char *target_username = row[0];
                    Client *tmp = head_client;
                    int send_count = 0;
                    while (tmp != NULL) {
                        if (strcmp(tmp->login_account, target_username) == 0) {
                            // Send on async socket if available, otherwise use main socket
                            int target_fd = (tmp->async_conn_fd >= 0) ? tmp->async_conn_fd : tmp->conn_fd;
                            send(target_fd, &msg, sizeof(Message), 0);
                            send_count++;
                            printf("Sent INVITE_NOTIFY to %s on fd %d (async=%d) [send #%d]\n", 
                                   target_username, target_fd, tmp->async_conn_fd, send_count);
                            break;
                        }
                        tmp = tmp->next;
                    }
                    if (send_count > 1) {
                        printf("WARNING: Sent invitation notification %d times to %s!\n", send_count, target_username);
                    }
                }
                mysql_free_result(res);
            }
        } else {
            mysql_free_result(res);
        }
    }
    
    pthread_mutex_unlock(&mutex);
}

// ==================== ROUND 1 GAME LOGIC ====================

// Game round handler thread - waits for clients to be ready then starts Round 1
void *game_round_handler(void *arg)
{
    int room_id = *((int *)arg);
    free(arg);
    
    // Tạo Match struct trong RAM ngay từ khi bắt đầu game
    pthread_mutex_lock(&mutex);
    create_match_in_memory(room_id);
    pthread_mutex_unlock(&mutex);
    
    // Wait 1 second for clients to navigate to Round1Room and connect signals
    printf("Waiting 1 second for clients in room %d to be ready...\n", room_id);
    sleep(1);
    
    // Start Round 1
    printf("Starting Round 1 for room %d\n", room_id);
    start_round1(room_id);
    
    return NULL;
}

// Thread wrapper for start_round1
void *start_round1_thread(void *arg)
{
    pthread_detach(pthread_self());
    int room_id = *((int *)arg);
    free(arg);
    
    start_round1(room_id);
    return NULL;
}

void start_round1(int room_id)
{
    pthread_mutex_lock(&mutex);
    
    printf("Starting Round 1 (3 questions) for room %d\n", room_id);
    
    // Get match_id for this room
    char query[1024];
    sprintf(query, "SELECT match_id FROM matches WHERE room_id = %d AND ended_at IS NULL ORDER BY match_id DESC LIMIT 1", room_id);
    
    int match_id = 0;
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row = mysql_fetch_row(res);
        if (row != NULL) {
            match_id = atoi(row[0]);
            
            // Check if this match already has rounds (game already started)
            mysql_free_result(res);
            sprintf(query, "SELECT COUNT(*) FROM rounds WHERE match_id = %d", match_id);
            if (mysql_query(g_db_conn, query) == 0) {
                res = mysql_store_result(g_db_conn);
                row = mysql_fetch_row(res);
                int round_count = atoi(row[0]);
                mysql_free_result(res);
                
                if (round_count > 0) {
                    printf("Match %d already has %d rounds, game already running. Aborting.\n", match_id, round_count);
                    pthread_mutex_unlock(&mutex);
                    return;
                }
            }
        } else {
            mysql_free_result(res);
        }
    }
    
    // If no active match, create one
    if (match_id == 0) {
        sprintf(query, "INSERT INTO matches (room_id, current_round) VALUES (%d, 1)", room_id);
        if (mysql_query(g_db_conn, query) == 0) {
            match_id = mysql_insert_id(g_db_conn);
            printf("Created new match: %d for room %d\n", match_id, room_id);
        } else {
            fprintf(stderr, "Failed to create match: %s\n", mysql_error(g_db_conn));
            pthread_mutex_unlock(&mutex);
            return;
        }
    }
    
    if (match_id == 0) {
        pthread_mutex_unlock(&mutex);
        return;
    }
    
    pthread_mutex_unlock(&mutex);
    
    // Loop through 3 questions
    for (int question_num = 1; question_num <= 3; question_num++) {
        pthread_mutex_lock(&mutex);
        
        printf("\n=== Question %d/3 ===\n", question_num);
        
        // Get random question from database (exclude already asked questions in this match)
        sprintf(query, 
            "SELECT question_id, question_text, option_a, option_b, option_c, option_d, correct_answer "
            "FROM questions "
            "WHERE question_id NOT IN (SELECT question_id FROM rounds WHERE match_id = %d) "
            "ORDER BY RAND() LIMIT 1", match_id);
        
        if (mysql_query(g_db_conn, query) != 0) {
            fprintf(stderr, "Failed to get question: %s\n", mysql_error(g_db_conn));
            pthread_mutex_unlock(&mutex);
            continue;
        }
        
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row = mysql_fetch_row(res);
        
        if (row == NULL) {
            mysql_free_result(res);
            pthread_mutex_unlock(&mutex);
            continue;
        }
        
        int question_id = atoi(row[0]);
        char *question_text = row[1];
        char *option_a = row[2];
        char *option_b = row[3];
        char *option_c = row[4];
        char *option_d = row[5];
        //char *correct_answer = row[6];
        
        // Create round in database
        sprintf(query, "INSERT INTO rounds (match_id, round_number, round_type, question_id, time_limit_sec, started_at) VALUES (%d, %d, 'ROUND1', %d, 15, NOW())", 
                match_id, question_num, question_id);
        
        if (mysql_query(g_db_conn, query) != 0) {
            fprintf(stderr, "Failed to create round: %s\n", mysql_error(g_db_conn));
            mysql_free_result(res);
            pthread_mutex_unlock(&mutex);
            continue;
        }
        
        int round_id = mysql_insert_id(g_db_conn);
        printf("Created Round 1 Question %d (round_id=%d) for match %d\n", question_num, round_id, match_id);
        
        // Prepare message to broadcast
        Message msg;
        msg.type = QUESTION_START;
        
        // Format: round_id|question_text|option_a|option_b|option_c|option_d
        sprintf(msg.value, "%d|%s|%s|%s|%s|%s", round_id, question_text, option_a, option_b, option_c, option_d);
        
        mysql_free_result(res);
        
        // Broadcast to all players in room
        Client *tmp = head_client;
        while (tmp != NULL) {
            if (tmp->room_id == room_id && tmp->login_status == AUTH) {
                int target_fd = (tmp->async_conn_fd >= 0) ? tmp->async_conn_fd : tmp->conn_fd;
                send(target_fd, &msg, sizeof(Message), 0);
                printf("Sent QUESTION_START (Q%d) to %s (fd=%d)\n", question_num, tmp->login_account, target_fd);
            }
            tmp = tmp->next;
        }
        
        pthread_mutex_unlock(&mutex);
        
        // Wait for answers with periodic checking (max 15 seconds)
        printf("Waiting for answers (max 15 seconds)...\n");
        
        for (int i = 0; i < 15; i++) {
            sleep(1);
            
            // Check if all players have answered (for logging only)
            pthread_mutex_lock(&mutex);
            
            char check_query[1024];
            sprintf(check_query, 
                "SELECT COUNT(DISTINCT rm.user_id) AS total_players, "
                "COUNT(DISTINCT ra.user_id) AS answered_players "
                "FROM rounds r "
                "JOIN matches m ON r.match_id = m.match_id "
                "JOIN room_members rm ON m.room_id = rm.room_id AND rm.left_at IS NULL AND rm.role = 'PLAYER' "
                "LEFT JOIN round_answers ra ON r.round_id = ra.round_id "
                "WHERE r.round_id = %d", round_id);
            
            if (mysql_query(g_db_conn, check_query) == 0) {
                MYSQL_RES *check_res = mysql_store_result(g_db_conn);
                MYSQL_ROW check_row = mysql_fetch_row(check_res);
                
                if (check_row != NULL) {
                    int total_players = atoi(check_row[0]);
                    int answered_players = atoi(check_row[1]);
                    
                    printf("Progress Q%d: %d/%d players answered (after %d seconds)\n", 
                           question_num, answered_players, total_players, i + 1);
                }
                mysql_free_result(check_res);
            }
            
            pthread_mutex_unlock(&mutex);
        }
        
        printf("Time's up for Question %d! Broadcasting results.\n", question_num);
        
        // Broadcast results
        broadcast_question_result(room_id, round_id);
        
        // Wait 8 seconds before next question (except after last question)
        if (question_num < 3) {
            printf("Waiting 8 seconds before next question...\n");
            sleep(8);
        }
    }
    
    printf("\n=== Round 1 Complete! All 3 questions finished ===\n");
    
    // Wait 5 seconds then show Round 1 ranking
    sleep(5);
    broadcast_final_ranking(room_id, match_id);
    
    // Wait 8 seconds then start Round 2
    printf("Waiting 8 seconds before starting Round 2...\n");
    sleep(8);
    
    // Start Round 2
    start_round2(room_id, match_id);
}

int handle_answer_submit(Client *cli, char answer[])
{
    pthread_mutex_lock(&mutex);
    
    // Parse: round_id|answer_choice (A/B/C/D)
    int round_id;
    char answer_choice[10];
    
    if (sscanf(answer, "%d|%s", &round_id, answer_choice) != 2) {
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    printf("[%d] Answer submitted for round %d: %s\n", cli->conn_fd, round_id, answer_choice);
    
    // Get user_id
    char query[1024];
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    
    if (mysql_query(g_db_conn, query) != 0) {
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    MYSQL_RES *res = mysql_store_result(g_db_conn);
    MYSQL_ROW row = mysql_fetch_row(res);
    
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    int user_id = atoi(row[0]);
    mysql_free_result(res);
    
    // Check if already answered
    sprintf(query, "SELECT answer_id FROM round_answers WHERE round_id = %d AND user_id = %d", round_id, user_id);
    
    if (mysql_query(g_db_conn, query) == 0) {
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        
        if (row != NULL) {
            // Already answered
            mysql_free_result(res);
            pthread_mutex_unlock(&mutex);
            return SYSTEM_ERROR;
        }
        mysql_free_result(res);
    }
    
    // Get round start time and correct answer
    sprintf(query, "SELECT r.started_at, q.correct_answer FROM rounds r JOIN questions q ON r.question_id = q.question_id WHERE r.round_id = %d", round_id);
    
    if (mysql_query(g_db_conn, query) != 0) {
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    char *started_at = row[0];
    char *correct_answer = row[1];
    mysql_free_result(res);
    
    // Calculate elapsed time in milliseconds
    sprintf(query, "SELECT TIMESTAMPDIFF(MICROSECOND, '%s', NOW()) / 1000", started_at);
    
    int time_ms = 0;
    if (mysql_query(g_db_conn, query) == 0) {
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        if (row != NULL) {
            time_ms = atoi(row[0]);
        }
        mysql_free_result(res);
    }
    
    // Check if answer is correct
    int is_correct = (strcmp(answer_choice, correct_answer) == 0) ? 1 : 0;
    
    // Calculate score
    int score_awarded = 0;
    if (is_correct) {
        int base_score = 100;
        int max_time = 15000; // 15 seconds in ms
        int elapsed_time = time_ms;
        
        // Clamp elapsed time to max_time
        if (elapsed_time > max_time) elapsed_time = max_time;
        
        // Speed bonus: (max_time - elapsed_time) / max_time * 100
        int speed_bonus = ((max_time - elapsed_time) * 100) / max_time;
        
        score_awarded = base_score + speed_bonus;
    }
    
    printf("Answer: %s, Correct: %s, Time: %dms, Score: %d\n", 
           answer_choice, correct_answer, time_ms, score_awarded);
    
    // Save answer to database
    sprintf(query, "INSERT INTO round_answers (round_id, user_id, answer_choice, is_correct, score_awarded, time_ms, answer_timestamp) VALUES (%d, %d, '%s', %d, %d, %d, NOW())",
            round_id, user_id, answer_choice, is_correct, score_awarded, time_ms);
    
    if (mysql_query(g_db_conn, query) != 0) {
        fprintf(stderr, "Failed to save answer: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    // Cập nhật điểm vào Match struct (RAM)
    Match *m = find_match(cli->room_id);
    if (m != NULL) {
        for (int i = 0; i < m->count_players; i++) {
            if (m->player_ids[i] == user_id) {
                m->r1_scores[i] += score_awarded;
                printf("[Round1] Updated player %s score in Match: r1_scores[%d] = %d\n", 
                       m->player_names[i], i, m->r1_scores[i]);
                break;
            }
        }
    }
    
    pthread_mutex_unlock(&mutex);
    
    printf("[%d] Answer saved successfully\n", cli->conn_fd);
    
    return ANSWER_SUBMIT;
}

void broadcast_question_result(int room_id, int round_id)
{
    pthread_mutex_lock(&mutex);
    
    printf("Broadcasting question result for round %d in room %d\n", round_id, room_id);
    
    // Mark round as ended
    char query[2048];
    sprintf(query, "UPDATE rounds SET ended_at = NOW() WHERE round_id = %d AND ended_at IS NULL", round_id);
    mysql_query(g_db_conn, query);
    
    // Get correct answer
    sprintf(query, "SELECT q.correct_answer FROM rounds r JOIN questions q ON r.question_id = q.question_id WHERE r.round_id = %d", round_id);
    
    char correct_answer[10] = "";
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row = mysql_fetch_row(res);
        if (row != NULL) {
            strcpy(correct_answer, row[0]);
        }
        mysql_free_result(res);
    }
    
    // Get all players' TOTAL cumulative scores (including those who left)
    sprintf(query, 
        "SELECT u.username, "
        "COALESCE((SELECT SUM(ra.score_awarded) "
        "          FROM rounds r2 "
        "          JOIN round_answers ra ON ra.round_id = r2.round_id "
        "          WHERE r2.match_id = m.match_id AND ra.user_id = u.user_id), 0) AS total_score, "
        "COALESCE(ra_current.is_correct, 0) AS is_correct, "
        "CASE WHEN rm.left_at IS NOT NULL THEN 1 ELSE 0 END AS has_left "
        "FROM room_members rm "
        "JOIN users u ON rm.user_id = u.user_id "
        "JOIN rounds r ON r.round_id = %d "
        "JOIN matches m ON r.match_id = m.match_id AND m.room_id = rm.room_id "
        "LEFT JOIN round_answers ra_current ON ra_current.round_id = r.round_id AND ra_current.user_id = u.user_id "
        "WHERE rm.role = 'PLAYER' "
        "ORDER BY total_score DESC", round_id);
    
    char result_json[BUFF_SIZE] = "{\"correct\":\"";
    strcat(result_json, correct_answer);
    strcat(result_json, "\",\"players\":[");
    
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row;
        int first = 1;
        
        while ((row = mysql_fetch_row(res)) != NULL) {
            if (!first) strcat(result_json, ",");
            first = 0;
            
            int has_left = atoi(row[3]);
            char player_json[256];
            sprintf(player_json, "{\"username\":\"%s\",\"score\":%s,\"is_correct\":%s,\"left\":%s}", 
                    row[0], row[1], row[2], has_left ? "true" : "false");
            strcat(result_json, player_json);
        }
        
        mysql_free_result(res);
    }
    
    strcat(result_json, "]}");
    
    printf("Result JSON: %s\n", result_json);
    printf("Correct Answer: %s\n", correct_answer);
    
    // Broadcast result to all players in room
    Message msg;
    msg.type = QUESTION_RESULT;
    strcpy(msg.value, result_json);
    
    Client *tmp = head_client;
    while (tmp != NULL) {
        if (tmp->room_id == room_id && tmp->login_status == AUTH) {
            int target_fd = (tmp->async_conn_fd >= 0) ? tmp->async_conn_fd : tmp->conn_fd;
            send(target_fd, &msg, sizeof(Message), 0);
            printf("Sent QUESTION_RESULT to %s (fd=%d, async_fd=%d, is_viewer=%d)\n", 
                   tmp->login_account, target_fd, tmp->async_conn_fd, tmp->is_viewer);
        } else {
            printf("Skipped %s (room_id=%d, need=%d, login=%d, need=%d)\n",
                   tmp->login_account, tmp->room_id, room_id, tmp->login_status, AUTH);
        }
        tmp = tmp->next;
    }
    
    pthread_mutex_unlock(&mutex);
}

void broadcast_final_ranking(int room_id, int match_id)
{
    // Do not lock here to avoid deadlock when caller already holds the mutex
    printf("[FINAL_RANKING] Broadcasting final ranking for match %d in room %d\n", match_id, room_id);
    
    // Get total scores for ALL players in this match (including those who left)
    char query[2048];
    sprintf(query, 
        "SELECT u.username, SUM(COALESCE(ra.score_awarded, 0)) AS total_score, rm.left_at "
        "FROM room_members rm "
        "JOIN users u ON rm.user_id = u.user_id "
        "JOIN matches m ON m.match_id = %d AND m.room_id = rm.room_id "
        "LEFT JOIN rounds r ON r.match_id = m.match_id "
        "LEFT JOIN round_answers ra ON ra.round_id = r.round_id AND ra.user_id = u.user_id "
        "WHERE rm.role = 'PLAYER' "
        "GROUP BY u.username, rm.left_at "
        "ORDER BY total_score DESC", match_id);
    
    printf("[FINAL_RANKING] SQL Query: %s\n", query);
    
    char result_json[BUFF_SIZE] = "{\"players\":[";
    
    if (mysql_query(g_db_conn, query) == 0) {
        printf("[FINAL_RANKING] Query executed successfully\n");
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row;
        int first = 1;
        int rank = 1;
        int player_count = 0;
        
        while ((row = mysql_fetch_row(res)) != NULL) {
            player_count++;
            int has_left = (row[2] != NULL) ? 1 : 0;
            printf("[FINAL_RANKING] Player %d: %s, Total Score: %s, Left: %d\n", rank, row[0], row[1], has_left);
            if (!first) strcat(result_json, ",");
            first = 0;
            
            char player_json[300];
            sprintf(player_json, "{\"rank\":%d,\"username\":\"%s\",\"total_score\":%s,\"left\":%s}", 
                    rank++, row[0], row[1], has_left ? "true" : "false");
            strcat(result_json, player_json);
        }
        
        printf("[FINAL_RANKING] Total players found: %d\n", player_count);
        mysql_free_result(res);
    } else {
        printf("[FINAL_RANKING] Query failed: %s\n", mysql_error(g_db_conn));
    }
    
    strcat(result_json, "]}");
    
    printf("[FINAL_RANKING] Final JSON: %s\n", result_json);
    
    // Mark match as ended
    //sprintf(query, "UPDATE matches SET ended_at = NOW() WHERE match_id = %d", match_id);
    //mysql_query(g_db_conn, query);
    
    // Broadcast ranking to all players in room
    Message msg;
    msg.type = GAME_END;
    strcpy(msg.value, result_json);
    
    Client *tmp = head_client;
    while (tmp != NULL) {
        if (tmp->room_id == room_id && tmp->login_status == AUTH) {
            int target_fd = (tmp->async_conn_fd >= 0) ? tmp->async_conn_fd : tmp->conn_fd;
            send(target_fd, &msg, sizeof(Message), 0);
            printf("Sent GAME_END (Final Ranking) to %s (fd=%d, async_fd=%d, is_viewer=%d)\n", 
                   tmp->login_account, target_fd, tmp->async_conn_fd, tmp->is_viewer);
        } else {
            printf("Skipped %s for GAME_END (room_id=%d vs %d, login=%d)\n",
                   tmp->login_account, tmp->room_id, room_id, tmp->login_status);
        }
        tmp = tmp->next;
    }
    
}

// ==================== ROUND 2 GAME LOGIC ====================

void start_round2(int room_id, int match_id)
{
    pthread_mutex_lock(&mutex);
    
    printf("\n=== Starting Round 2 (Price Guessing with %% Threshold) ===\n");
    
    char query[2048];
    
    // Get a random product from the products table
    sprintf(query, 
        "SELECT product_id, name, description, base_price, image_url "
        "FROM products "
        "ORDER BY RAND() LIMIT 1");
    
    if (mysql_query(g_db_conn, query) != 0) {
        fprintf(stderr, "Failed to get product: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return;
    }
    
    MYSQL_RES *res = mysql_store_result(g_db_conn);
    MYSQL_ROW row = mysql_fetch_row(res);
    
    if (row == NULL) {
        fprintf(stderr, "No products found in database!\n");
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return;
    }
    
    int product_id = atoi(row[0]);
    char *product_name = row[1];
    char *product_desc = row[2];
    int base_price = atoi(row[3]);
    char *image_url = row[4] ? row[4] : "";
    
    printf("Product: %s - %s (Price: %d VND, Image: %s)\n", product_name, product_desc, base_price, image_url);
    
    // Create round in database with 10% threshold
    sprintf(query, 
        "INSERT INTO rounds (match_id, round_number, round_type, time_limit_sec, threshold_pct, started_at) "
        "VALUES (%d, 2, 'V2', 20, 10.00, NOW())", 
        match_id);
    
    if (mysql_query(g_db_conn, query) != 0) {
        fprintf(stderr, "Failed to create round: %s\n", mysql_error(g_db_conn));
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return;
    }
    
    int round_id = mysql_insert_id(g_db_conn);
    printf("Created Round 2 (round_id=%d) for match %d\n", round_id, match_id);
    
    // Link product to round
    sprintf(query, 
        "INSERT INTO round_products (round_id, product_id, display_order) "
        "VALUES (%d, %d, 1)", 
        round_id, product_id);
    mysql_query(g_db_conn, query);
    
    mysql_free_result(res);
    
    // Prepare message to broadcast
    Message msg;
    msg.type = ROUND_START;
    
    // Format: round_id|round_type|product_name|product_desc|threshold_pct|time_limit|image_url
    sprintf(msg.value, "%d|V2|%s|%s|10|20|%s", 
            round_id, product_name, product_desc, image_url);
    
    // Broadcast to all players in room
    Client *tmp = head_client;
    while (tmp != NULL) {
        if (tmp->room_id == room_id && tmp->login_status == AUTH) {
            int target_fd = (tmp->async_conn_fd >= 0) ? tmp->async_conn_fd : tmp->conn_fd;
            send(target_fd, &msg, sizeof(Message), 0);
            printf("Sent ROUND_START (V2) to %s (fd=%d, async_fd=%d, is_viewer=%d)\n", 
                   tmp->login_account, target_fd, tmp->async_conn_fd, tmp->is_viewer);
        } else {
            printf("Skipped %s for ROUND_START V2 (room_id=%d vs %d, login=%d)\n",
                   tmp->login_account, tmp->room_id, room_id, tmp->login_status);
        }
        tmp = tmp->next;
    }
    
    pthread_mutex_unlock(&mutex);
    
    // Wait for answers (20 seconds)
    printf("Waiting for price guesses (max 20 seconds)...\n");
    
    for (int i = 0; i < 20; i++) {
        sleep(1);
        
        // Check progress
        pthread_mutex_lock(&mutex);
        
        sprintf(query, 
            "SELECT COUNT(DISTINCT rm.user_id) AS total_players, "
            "COUNT(DISTINCT ra.user_id) AS answered_players "
            "FROM rounds r "
            "JOIN matches m ON r.match_id = m.match_id "
            "JOIN room_members rm ON m.room_id = rm.room_id AND rm.left_at IS NULL AND rm.role = 'PLAYER' "
            "LEFT JOIN round_answers ra ON r.round_id = ra.round_id "
            "WHERE r.round_id = %d", round_id);
        
        if (mysql_query(g_db_conn, query) == 0) {
            MYSQL_RES *check_res = mysql_store_result(g_db_conn);
            MYSQL_ROW check_row = mysql_fetch_row(check_res);
            
            if (check_row != NULL) {
                int total_players = atoi(check_row[0]);
                int answered_players = atoi(check_row[1]);
                
                printf("Progress Round 2: %d/%d players answered (after %d seconds)\n", 
                       answered_players, total_players, i + 1);
            }
            mysql_free_result(check_res);
        }
        
        pthread_mutex_unlock(&mutex);
    }
    
    printf("Time's up for Round 2! Broadcasting results.\n");
    
    // Broadcast results
    broadcast_round2_result(room_id, round_id);
    
    // Wait 8 seconds before showing final ranking
    printf("Waiting 8 seconds before final ranking...\n");
    sleep(8); // Chờ người chơi xem bảng điểm Round 2
    create_match_in_memory(room_id); 
    start_round3(room_id);
}

int handle_price_submit(Client *cli, char price_data[])
{
    pthread_mutex_lock(&mutex);
    
    // Parse: round_id|guessed_price
    int round_id;
    int guessed_price;
    
    if (sscanf(price_data, "%d|%d", &round_id, &guessed_price) != 2) {
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    printf("[%d] Price submitted for round %d: %d VND\n", cli->conn_fd, round_id, guessed_price);
    
    // Get user_id
    char query[2048];
    sprintf(query, "SELECT user_id FROM users WHERE username = '%s'", cli->login_account);
    
    if (mysql_query(g_db_conn, query) != 0) {
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    MYSQL_RES *res = mysql_store_result(g_db_conn);
    MYSQL_ROW row = mysql_fetch_row(res);
    
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    int user_id = atoi(row[0]);
    mysql_free_result(res);
    
    // Check if already answered
    sprintf(query, "SELECT answer_id FROM round_answers WHERE round_id = %d AND user_id = %d", 
            round_id, user_id);
    
    if (mysql_query(g_db_conn, query) == 0) {
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        
        if (row != NULL) {
            // Already answered
            mysql_free_result(res);
            pthread_mutex_unlock(&mutex);
            return SYSTEM_ERROR;
        }
        mysql_free_result(res);
    }
    
    // Get round info and actual price
    sprintf(query, 
        "SELECT r.started_at, r.threshold_pct, p.base_price "
        "FROM rounds r "
        "JOIN round_products rp ON r.round_id = rp.round_id "
        "JOIN products p ON rp.product_id = p.product_id "
        "WHERE r.round_id = %d", round_id);
    
    if (mysql_query(g_db_conn, query) != 0) {
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    res = mysql_store_result(g_db_conn);
    row = mysql_fetch_row(res);
    
    if (row == NULL) {
        mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    char *started_at = row[0];
    float threshold_pct = atof(row[1]);
    int actual_price = atoi(row[2]);
    mysql_free_result(res);
    
    // Calculate elapsed time in milliseconds
    sprintf(query, "SELECT TIMESTAMPDIFF(MICROSECOND, '%s', NOW()) / 1000", started_at);
    
    int time_ms = 0;
    if (mysql_query(g_db_conn, query) == 0) {
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        if (row != NULL) {
            time_ms = atoi(row[0]);
        }
        mysql_free_result(res);
    }
    
    // Calculate percentage difference
    float diff_pct = fabs((float)(guessed_price - actual_price) / actual_price) * 100.0;
    
    // Check if within threshold
    int is_correct = (diff_pct <= threshold_pct) ? 1 : 0;
    
    // Calculate score
    int score_awarded = 0;
    if (is_correct) {
        // Base score for being within threshold
        int base_score = 100;
        
        // Accuracy bonus: the closer to actual price, the higher the bonus
        // Max 100 bonus points for exact match, scaling down based on % difference
        int accuracy_bonus = (int)(100.0 * (1.0 - (diff_pct / threshold_pct)));
        
        // Speed bonus
        int max_time = 20000; // 20 seconds in ms
        int elapsed_time = time_ms;
        if (elapsed_time > max_time) elapsed_time = max_time;
        int speed_bonus = ((max_time - elapsed_time) * 50) / max_time;
        
        score_awarded = base_score + accuracy_bonus + speed_bonus;
    }
    
    printf("Guessed: %d, Actual: %d, Diff: %.2f%%, Within %.2f%%? %s, Score: %d\n", 
           guessed_price, actual_price, diff_pct, threshold_pct, 
           is_correct ? "YES" : "NO", score_awarded);
    
    // Save answer to database
    sprintf(query, 
        "INSERT INTO round_answers "
        "(round_id, user_id, answer_price, is_correct, score_awarded, time_ms, answer_timestamp) "
        "VALUES (%d, %d, %d, %d, %d, %d, NOW())",
        round_id, user_id, guessed_price, is_correct, score_awarded, time_ms);
    
    if (mysql_query(g_db_conn, query) != 0) {
        fprintf(stderr, "Failed to save price answer: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return SYSTEM_ERROR;
    }
    
    // Cập nhật điểm vào Match struct (RAM)
    Match *m = find_match(cli->room_id);
    if (m != NULL) {
        for (int i = 0; i < m->count_players; i++) {
            if (m->player_ids[i] == user_id) {
                m->r2_scores[i] += score_awarded;
                printf("[Round2] Updated player %s score in Match: r2_scores[%d] = %d\n", 
                       m->player_names[i], i, m->r2_scores[i]);
                break;
            }
        }
    }
    
    pthread_mutex_unlock(&mutex);
    
    printf("[%d] Price answer saved successfully\n", cli->conn_fd);
    
    return PRICE_SUBMIT;
}

void broadcast_round2_result(int room_id, int round_id)
{
    pthread_mutex_lock(&mutex);
    
    printf("Broadcasting Round 2 result for round %d in room %d\n", round_id, room_id);
    
    // Mark round as ended
    char query[2048];
    sprintf(query, "UPDATE rounds SET ended_at = NOW() WHERE round_id = %d AND ended_at IS NULL", 
            round_id);
    mysql_query(g_db_conn, query);
    
    // Get actual price and threshold
    sprintf(query, 
        "SELECT p.base_price, r.threshold_pct "
        "FROM rounds r "
        "JOIN round_products rp ON r.round_id = rp.round_id "
        "JOIN products p ON rp.product_id = p.product_id "
        "WHERE r.round_id = %d", round_id);
    
    int actual_price = 0;
    float threshold_pct = 10.0;
    
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row = mysql_fetch_row(res);
        if (row != NULL) {
            actual_price = atoi(row[0]);
            threshold_pct = atof(row[1]);
        }
        mysql_free_result(res);
    }
    
    // Get all players' cumulative scores (including those who left)
    sprintf(query, 
        "SELECT u.username, "
        "COALESCE((SELECT SUM(ra.score_awarded) "
        "          FROM rounds r2 "
        "          JOIN round_answers ra ON ra.round_id = r2.round_id "
        "          WHERE r2.match_id = m.match_id AND ra.user_id = u.user_id), 0) AS total_score, "
        "COALESCE(ra_current.answer_price, 0) AS guessed_price, "
        "COALESCE(ra_current.is_correct, 0) AS is_correct, "
        "CASE WHEN rm.left_at IS NOT NULL THEN 1 ELSE 0 END AS has_left "
        "FROM room_members rm "
        "JOIN users u ON rm.user_id = u.user_id "
        "JOIN rounds r ON r.round_id = %d "
        "JOIN matches m ON r.match_id = m.match_id AND m.room_id = rm.room_id "
        "LEFT JOIN round_answers ra_current ON ra_current.round_id = r.round_id AND ra_current.user_id = u.user_id "
        "WHERE rm.role = 'PLAYER' "
        "ORDER BY total_score DESC", round_id);
    
    char result_json[BUFF_SIZE];
    sprintf(result_json, "{\"actual_price\":%d,\"threshold\":%.1f,\"players\":[", 
            actual_price, threshold_pct);
    
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row;
        int first = 1;
        
        while ((row = mysql_fetch_row(res)) != NULL) {
            if (!first) strcat(result_json, ",");
            first = 0;
            
            int has_left = atoi(row[4]);
            char player_json[512];
            sprintf(player_json, 
                "{\"username\":\"%s\",\"score\":%s,\"guessed_price\":%s,\"is_correct\":%s,\"left\":%s}", 
                row[0], row[1], row[2], row[3], has_left ? "true" : "false");
            strcat(result_json, player_json);
        }
        
        mysql_free_result(res);
    }
    
    strcat(result_json, "]}");
    
    printf("Round 2 Result JSON: %s\n", result_json);
    
    // Broadcast result to all players in room
    Message msg;
    msg.type = ROUND_RESULT;
    strcpy(msg.value, result_json);
    
    Client *tmp = head_client;
    while (tmp != NULL) {
        if (tmp->room_id == room_id && tmp->login_status == AUTH) {
            int target_fd = (tmp->async_conn_fd >= 0) ? tmp->async_conn_fd : tmp->conn_fd;
            send(target_fd, &msg, sizeof(Message), 0);
            printf("Sent ROUND_RESULT (V2) to %s (fd=%d, async_fd=%d, is_viewer=%d)\n", 
                   tmp->login_account, target_fd, tmp->async_conn_fd, tmp->is_viewer);
        } else {
            printf("Skipped %s for ROUND_RESULT V2 (room_id=%d vs %d, login=%d)\n",
                   tmp->login_account, tmp->room_id, room_id, tmp->login_status);
        }
        tmp = tmp->next;
    }
    
    pthread_mutex_unlock(&mutex);
}

// ==================== MATCH MANAGEMENT (ROUND 3 LOGIC) ====================
void start_round3(int room_id) {
    Match *m = find_match(room_id);
    if (m) {
        pthread_mutex_lock(&mutex);
        char query[1024];
        
        // Cập nhật current_round trong Match
        m->current_round = 3;
        m->current_turn_index = 0;
        
        // Tìm người chơi đầu tiên chưa rời để bắt đầu lượt
        while (m->current_turn_index < m->count_players && m->has_left[m->current_turn_index]) {
            m->current_turn_index++;
        }
        
        // Step 1: Insert Round 3 record
        sprintf(query, "INSERT INTO rounds (match_id, round_number, round_type, started_at) "
                       "SELECT match_id, 3, 'V3', NOW() FROM matches WHERE room_id = %d AND ended_at IS NULL LIMIT 1", room_id);
        mysql_query(g_db_conn, query);
        
        // Step 2: Initialize round_answers for each player with score = 0
        // Get match_id and round_id
        int match_id = 0, round_id = 0;
        sprintf(query, "SELECT match_id FROM matches WHERE room_id = %d AND ended_at IS NULL", room_id);
        if (mysql_query(g_db_conn, query) == 0) {
            MYSQL_RES *res = mysql_store_result(g_db_conn);
            MYSQL_ROW row = mysql_fetch_row(res);
            if (row) match_id = atoi(row[0]);
            mysql_free_result(res);
        }
        
        sprintf(query, "SELECT round_id FROM rounds WHERE match_id = %d AND round_type = 'V3'", match_id);
        if (mysql_query(g_db_conn, query) == 0) {
            MYSQL_RES *res = mysql_store_result(g_db_conn);
            MYSQL_ROW row = mysql_fetch_row(res);
            if (row) round_id = atoi(row[0]);
            mysql_free_result(res);
        }
        
        // Insert initial round_answers for all players (bao gồm cả người đã rời)
        printf("[ROUND3] Initializing round_answers for %d players (round_id=%d)\n", m->count_players, round_id);
        for (int i = 0; i < m->count_players; i++) {
            sprintf(query, "INSERT INTO round_answers (round_id, user_id, answer_choice, score_awarded, answer_timestamp) "
                          "VALUES (%d, %d, '0', 0, NOW())", round_id, m->player_ids[i]);
            int res = mysql_query(g_db_conn, query);
            printf("[ROUND3] Insert player %d (user_id=%d, has_left=%d): %s\n", 
                   i, m->player_ids[i], m->has_left[i], (res==0)?"OK":"FAIL");
        }
        
        pthread_mutex_unlock(&mutex);

        if (m->current_turn_index < m->count_players) {
            char json[BUFF_SIZE];
            sprintf(json, "{\"type\":\"ROUND_START\",\"round\":3,\"turn_user\":\"%s\"}", 
                    m->player_names[m->current_turn_index]);
            broadcast_match_json(m, json, GAME_START_NOTIFY);
        }
    }
}

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
    // Bắt đầu từ vòng 1
    new_m->current_round = 1; 
    new_m->current_turn_index = 0;
    new_m->next = head_match;
    head_match = new_m;

    // Load TẤT CẢ players from DB (kể cả người đã rời) theo thứ tự tham gia
    char query[1024];
    sprintf(query, "SELECT u.user_id, u.username, rm.left_at FROM room_members rm JOIN users u ON rm.user_id = u.user_id WHERE rm.room_id = %d AND rm.role = 'PLAYER' ORDER BY rm.joined_at ASC", room_id);
    
    if (mysql_query(g_db_conn, query) == 0) {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        MYSQL_ROW row;
        int count = 0;
        while ((row = mysql_fetch_row(res)) != NULL && count < MAX_PLAYERS) {
            new_m->player_ids[count] = atoi(row[0]);
            strcpy(new_m->player_names[count], row[1]);
            
            // Init all rounds data
            new_m->r1_scores[count] = 0;
            new_m->r2_scores[count] = 0;
            new_m->r3_scores[count] = 0;
            new_m->r3_spins[count] = 0;
            new_m->r3_passed[count] = 0;
            
            // Kiểm tra xem người này đã rời chưa (left_at không NULL)
            new_m->has_left[count] = (row[2] != NULL) ? 1 : 0;
            
            printf("[MATCH] Player %d: %s (user_id=%d, has_left=%d)\n", 
                   count, new_m->player_names[count], new_m->player_ids[count], new_m->has_left[count]);
            
            count++;
        }
        new_m->count_players = count;
        mysql_free_result(res);
    }
    printf("[MATCH] Match created in memory for Room %d with %d players (including left players). Round %d\n", room_id, new_m->count_players, new_m->current_round);
}
// Broadcast JSON message to all players in a match
void broadcast_match_json(Match *m, const char *json_data, int type) {
    Client *tmp = head_client;
    Message msg;
    msg.type = type;
    strncpy(msg.value, json_data, sizeof(msg.value) - 1);
    msg.value[sizeof(msg.value) - 1] = '\0';

    while (tmp != NULL) {
        if (tmp->room_id == m->room_id && tmp->login_status == AUTH) {
            // Ưu tiên gửi qua Async socket, nếu không có thì gửi qua socket chính
            int target_fd = (tmp->async_conn_fd > 0) ? tmp->async_conn_fd : tmp->conn_fd;
            if (target_fd > 0) {
                send(target_fd, &msg, sizeof(Message), 0);
                printf("Sent ROUND3 msg (type=%d) to %s (fd=%d, async_fd=%d, is_viewer=%d)\n", 
                       type, tmp->login_account, target_fd, tmp->async_conn_fd, tmp->is_viewer);
            }
        } else {
            printf("Skipped %s for ROUND3 (room_id=%d vs %d, login=%d)\n",
                   tmp->login_account, tmp->room_id, m->room_id, tmp->login_status);
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
        
        int spin_val = (rand() % 20 + 1) * 5; 
        m->r3_scores[p_idx] += spin_val;
        m->r3_spins[p_idx]++;

        // Lưu tạm vào DB (lượt quay hiện tại)
        char db_query[1024];
        sprintf(db_query, "INSERT INTO round_answers (round_id, user_id, answer_choice, score_awarded, answer_timestamp) "
                        "VALUES ((SELECT round_id FROM rounds WHERE match_id = (SELECT match_id FROM matches WHERE room_id = %d AND ended_at IS NULL) AND round_type = 'V3' LIMIT 1), "
                        "%d, '%d', %d, NOW()) "
                        "ON DUPLICATE KEY UPDATE answer_choice = CONCAT(answer_choice, ',', '%d'), score_awarded = %d", 
                        cli->room_id, m->player_ids[p_idx], spin_val, m->r3_scores[p_idx], spin_val, m->r3_scores[p_idx]);
        mysql_query(g_db_conn, db_query);

        char json_resp[BUFF_SIZE];
        sprintf(json_resp, "{\"type\":\"%s\",\"user\":\"%s\",\"spin_val\":%d,\"total\":%d,\"spins_count\":%d}", 
                SPIN_RESULT, m->player_names[p_idx], spin_val, m->r3_scores[p_idx], m->r3_spins[p_idx]);
        broadcast_match_json(m, json_resp, ROUND_RESULT);

        if (m->r3_spins[p_idx] == 2) turn_ended = 1;
        
    } 
    // --- XỬ LÝ BỎ LƯỢT (PASS) ---
    else if (strcmp(action, MOVE_PASS) == 0) {
        if (m->r3_spins[p_idx] >= 1) {
            turn_ended = 1;
        }
    }

    // --- KIỂM TRA CHUYỂN LƯỢT / KẾT THÚC GAME ---
    if (turn_ended) {
        // Tìm người chơi tiếp theo chưa rời
        m->current_turn_index++;
        while (m->current_turn_index < m->count_players && m->has_left[m->current_turn_index]) {
            printf("[Round3] Skipping player idx=%d (has_left)\n", m->current_turn_index);
            m->current_turn_index++;
        }
        
        if (m->current_turn_index >= m->count_players) {
            // TẤT CẢ ĐÃ XONG - XỬ LÝ KẾT THÚC MATCH
            char winner[50] = "";
            int max_score = -1;
            char scores_json[512] = "[";
            
            int current_match_id = 0;
            char match_q[256];
            sprintf(match_q, "SELECT match_id FROM matches WHERE room_id = %d AND ended_at IS NULL", cli->room_id);
            if (mysql_query(g_db_conn, match_q) == 0) {
                MYSQL_RES *res = mysql_store_result(g_db_conn);
                MYSQL_ROW row = mysql_fetch_row(res);
                if (row) current_match_id = atoi(row[0]);
                mysql_free_result(res);
            }

            // BƯỚC 1: Vòng lặp tính toán điểm cuối cùng và cập nhật DB cho từng người (bao gồm cả người đã rời)
            for (int i=0; i<m->count_players; i++) {
                int final_score = m->r3_scores[i];
                if (final_score > 100) final_score -= 100; // Luật > 100
                
                // Cập nhật lại điểm chuẩn vào DB để Ranking cộng đúng
                char update_score_q[512];
                sprintf(update_score_q, "UPDATE round_answers SET score_awarded = %d "
                                        "WHERE user_id = %d AND round_id = (SELECT round_id FROM rounds WHERE match_id = %d AND round_type = 'V3' LIMIT 1)", 
                        final_score, m->player_ids[i], current_match_id);
                mysql_query(g_db_conn, update_score_q);

                // Chỉ tính winner từ những người còn lại (chưa rời)
                if (!m->has_left[i] && final_score > max_score) {
                    max_score = final_score;
                    strcpy(winner, m->player_names[i]);
                }

                // Thêm thông tin vào JSON, đánh dấu người đã rời
                char entry[150];
                sprintf(entry, "{\"user\":\"%s\",\"score\":%d,\"left\":%s}", 
                       m->player_names[i], final_score, m->has_left[i] ? "true" : "false");
                strcat(scores_json, entry);
                if(i < m->count_players - 1) strcat(scores_json, ",");
                
                printf("[Round3] Player %s: score=%d, left=%d\n", m->player_names[i], final_score, m->has_left[i]);
            }
            strcat(scores_json, "]");

            // BƯỚC 2: Gửi thông báo kết quả Vòng 3 (ROUND3_END)
            char json_end[BUFF_SIZE];
            sprintf(json_end, "{\"type\":\"%s\",\"winner\":\"%s\",\"details\":%s}", ROUND3_END, winner, scores_json);
            broadcast_match_json(m, json_end, ROUND_RESULT);
            sleep(2); 
            // BƯỚC 3: Gửi bảng xếp hạng TỔNG KẾT (GAME_END)
            printf("[SERVER] Broadcasting FINAL ranking for room %d\n", cli->room_id);
            broadcast_final_ranking(cli->room_id, current_match_id);

            // BƯỚC 4: Cập nhật trạng thái kết thúc trong DB
            char close_query[512];
            sprintf(close_query, "UPDATE matches SET ended_at = NOW(), winner_user_id = (SELECT user_id FROM users WHERE username = '%s') "
                                 "WHERE match_id = %d", winner, current_match_id);
            mysql_query(g_db_conn, close_query);

            sprintf(close_query, "UPDATE rooms SET status = 'LOBBY' WHERE room_id = %d", cli->room_id);
            mysql_query(g_db_conn, close_query);

            // BƯỚC 5: Reset Client Status và dọn dẹp RAM
            Client *tmp_c = head_client;
            while (tmp_c != NULL) {
                if (tmp_c->room_id == cli->room_id) tmp_c->is_ready = 0;
                tmp_c = tmp_c->next;
            }

            Match *prev_m = NULL, *curr_m = head_match;
            while (curr_m) {
                if (curr_m->room_id == cli->room_id) {
                    if (prev_m) prev_m->next = curr_m->next;
                    else head_match = curr_m->next;
                    free(curr_m);
                    break;
                }
                prev_m = curr_m;
                curr_m = curr_m->next;
            }
        } else {
            // Chuyển sang người tiếp theo
            char json_turn[BUFF_SIZE];
            sprintf(json_turn, "{\"type\":\"TURN_CHANGE\",\"next_user\":\"%s\"}", m->player_names[m->current_turn_index]);
            broadcast_match_json(m, json_turn, ROUND_INFO); 
        }
    }

    pthread_mutex_unlock(&mutex);
}

// ==================== VIEWER FUNCTIONS ====================

int handle_join_as_viewer(Client *cli, char room_code[BUFF_SIZE]) {
    if (!cli) return JOIN_AS_VIEWER_FAIL;
    
    pthread_mutex_lock(&mutex);
    
    // Tìm room theo room_code
    char query[512];
    sprintf(query, "SELECT room_id, status FROM rooms WHERE room_code = '%s'", room_code);
    
    if (mysql_query(g_db_conn, query) != 0) {
        pthread_mutex_unlock(&mutex);
        return JOIN_AS_VIEWER_FAIL;
    }
    
    MYSQL_RES *res = mysql_store_result(g_db_conn);
    if (!res || mysql_num_rows(res) == 0) {
        if (res) mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return JOIN_AS_VIEWER_FAIL;
    }
    
    MYSQL_ROW row = mysql_fetch_row(res);
    int room_id = atoi(row[0]);
    char *status = row[1];
    mysql_free_result(res);
    
    // Chỉ cho phép xem nếu phòng đang PLAYING
    if (strcmp(status, "PLAYING") != 0) {
        pthread_mutex_unlock(&mutex);
        return JOIN_AS_VIEWER_FAIL;
    }
    
    // Lấy user_id từ username
    int user_id = db_get_user_id_by_username(cli->login_account);
    if (user_id < 0) {
        printf("[VIEWER] Failed to get user_id for %s\n", cli->login_account);
        pthread_mutex_unlock(&mutex);
        return JOIN_AS_VIEWER_FAIL;
    }
    
    // Lưu viewer vào database
    if (db_add_viewer_to_room(room_id, user_id) != 0) {
        printf("[VIEWER] Failed to add viewer to database\n");
        pthread_mutex_unlock(&mutex);
        return JOIN_AS_VIEWER_FAIL;
    }
    
    // Set viewer mode
    cli->room_id = room_id;
    cli->is_viewer = 1;
    cli->is_ready = 0;
    
    printf("[VIEWER] User %s (user_id=%d) joined room %d as viewer\n", cli->login_account, user_id, room_id);
    
    pthread_mutex_unlock(&mutex);
    
    // Send game state sync to viewer after successful join
    send_game_state_sync(cli, room_id);
    
    return JOIN_AS_VIEWER_SUCCESS;
}

int handle_leave_viewer(Client *cli) {
    if (!cli || !cli->is_viewer) return LEAVE_ROOM_SUCCESS;
    
    pthread_mutex_lock(&mutex);
    
    // Lấy user_id từ username
    int user_id = db_get_user_id_by_username(cli->login_account);
    if (user_id >= 0 && cli->room_id > 0) {
        // Cập nhật left_at trong database
        if (db_remove_viewer_from_room(cli->room_id, user_id) != 0) {
            printf("[VIEWER] Failed to update left_at for viewer in database\n");
        }
    }
    
    printf("[VIEWER] User %s left viewer mode from room %d\n", cli->login_account, cli->room_id);
    
    cli->room_id = 0;
    cli->is_viewer = 0;
    
    pthread_mutex_unlock(&mutex);
    return LEAVE_ROOM_SUCCESS;
}

void send_viewer_state(Client *cli) {
    if (!cli || !cli->is_viewer || cli->room_id <= 0) return;
    
    pthread_mutex_lock(&mutex);
    
    // Lấy thông tin room hiện tại
    char query[1024];
    sprintf(query, 
        "SELECT r.current_round, r.status, GROUP_CONCAT(u.username ORDER BY rm.joined_at SEPARATOR '|') "
        "FROM rooms r "
        "LEFT JOIN room_members rm ON r.room_id = rm.room_id AND rm.left_at IS NULL "
        "LEFT JOIN users u ON rm.user_id = u.user_id "
        "WHERE r.room_id = %d "
        "GROUP BY r.room_id", cli->room_id);
    
    printf("[VIEWER] Querying room info for viewer %s in room %d\n", cli->login_account, cli->room_id);
    
    if (mysql_query(g_db_conn, query) != 0) {
        printf("[VIEWER] Query failed: %s\n", mysql_error(g_db_conn));
        pthread_mutex_unlock(&mutex);
        return;
    }
    
    MYSQL_RES *res = mysql_store_result(g_db_conn);
    if (!res || mysql_num_rows(res) == 0) {
        if (res) mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return;
    }
    
    MYSQL_ROW row = mysql_fetch_row(res);
    int current_round = row[0] ? atoi(row[0]) : 0;
    char *status = row[1];
    char *members = row[2] ? row[2] : "";
    
    // Lấy điểm số từ match
    Match *m = find_match(cli->room_id);
    char scores_json[BUFF_SIZE] = "[";
    
    if (m) {
        for (int i = 0; i < m->count_players; i++) {
            char entry[256];
            int total_score = m->r1_scores[i] + m->r2_scores[i] + m->r3_scores[i];
            sprintf(entry, "{\"name\":\"%s\",\"r1\":%d,\"r2\":%d,\"r3\":%d,\"total\":%d,\"left\":%s}",
                   m->player_names[i], m->r1_scores[i], m->r2_scores[i], m->r3_scores[i], 
                   total_score, m->has_left[i] ? "true" : "false");
            strcat(scores_json, entry);
            if (i < m->count_players - 1) strcat(scores_json, ",");
        }
    }
    strcat(scores_json, "]");
    
    // Gửi state cho viewer
    char json_state[BUFF_SIZE * 2];
    sprintf(json_state, "{\"room_id\":%d,\"current_round\":%d,\"status\":\"%s\",\"members\":\"%s\",\"scores\":%s}",
           cli->room_id, current_round, status, members, scores_json);
    
    Message msg;
    msg.type = VIEWER_STATE_UPDATE;
    strcpy(msg.data_type, "string");
    msg.length = strlen(json_state);
    strncpy(msg.value, json_state, BUFF_SIZE - 1);
    msg.value[BUFF_SIZE - 1] = '\0';
    
    int target_fd = (cli->async_conn_fd >= 0) ? cli->async_conn_fd : cli->conn_fd;
    send(target_fd, &msg, sizeof(Message), 0);
    
    printf("[VIEWER] Sent state to %s: %s\n", cli->login_account, json_state);
    
    mysql_free_result(res);
    pthread_mutex_unlock(&mutex);
}

// Send complete game state to viewer when they join
void send_game_state_sync(Client *cli, int room_id) {
    if (!cli) return;
    
    pthread_mutex_lock(&mutex);
    
    char query[2048];
    char json_data[BUFF_SIZE * 2];
    
    // 1. Get current match and round info
    sprintf(query, 
        "SELECT m.match_id, m.current_round, r.round_id, r.round_type, r.question_id, "
        "r.time_limit_sec, r.threshold_pct, p.product_id, p.name, p.description, p.image_url, p.base_price "
        "FROM matches m "
        "LEFT JOIN rounds r ON m.match_id = r.match_id AND r.ended_at IS NULL "
        "LEFT JOIN round_products rp ON r.round_id = rp.round_id "
        "LEFT JOIN products p ON rp.product_id = p.product_id "
        "WHERE m.room_id = %d AND m.ended_at IS NULL "
        "LIMIT 1", room_id);
    
    if (mysql_query(g_db_conn, query) != 0) {
        pthread_mutex_unlock(&mutex);
        return;
    }
    
    MYSQL_RES *res = mysql_store_result(g_db_conn);
    if (!res || mysql_num_rows(res) == 0) {
        if (res) mysql_free_result(res);
        pthread_mutex_unlock(&mutex);
        return;
    }
    
    MYSQL_ROW row = mysql_fetch_row(res);
    int match_id = atoi(row[0]);
    int current_round = atoi(row[1]);
    int round_id = row[2] ? atoi(row[2]) : 0;
    char *round_type = row[3] ? row[3] : "UNKNOWN";
    int question_id = row[4] ? atoi(row[4]) : 0;
    int time_limit = row[5] ? atoi(row[5]) : 15;
    float threshold = row[6] ? atof(row[6]) : 0.0;
    
    // Product info (for Round 2)
    int product_id = row[7] ? atoi(row[7]) : 0;
    char product_name[256] = "";
    char product_desc[512] = "";
    char product_image[512] = "";
    int product_price = row[11] ? atoi(row[11]) : 0;
    
    if (row[8]) strncpy(product_name, row[8], sizeof(product_name) - 1);
    if (row[9]) strncpy(product_desc, row[9], sizeof(product_desc) - 1);
    if (row[10]) strncpy(product_image, row[10], sizeof(product_image) - 1);
    
    mysql_free_result(res);
    
    // 2. Get all player scores
    sprintf(query,
        "SELECT u.username, COALESCE(SUM(ra.score_awarded), 0) as total_score "
        "FROM room_members rm "
        "JOIN users u ON rm.user_id = u.user_id "
        "LEFT JOIN round_answers ra ON ra.user_id = rm.user_id AND ra.round_id IN "
        "(SELECT round_id FROM rounds WHERE match_id = %d) "
        "WHERE rm.room_id = %d AND rm.left_at IS NULL AND rm.role = 'PLAYER' "
        "GROUP BY u.username, rm.user_id "
        "ORDER BY total_score DESC", match_id, room_id);
    
    if (mysql_query(g_db_conn, query) != 0) {
        pthread_mutex_unlock(&mutex);
        return;
    }
    
    res = mysql_store_result(g_db_conn);
    char players_json[1024] = "[";
    int first = 1;
    
    while ((row = mysql_fetch_row(res)) != NULL) {
        if (!first) strcat(players_json, ",");
        char temp[128];
        sprintf(temp, "{\"username\":\"%s\",\"score\":%s}", row[0], row[1]);
        strcat(players_json, temp);
        first = 0;
    }
    strcat(players_json, "]");
    mysql_free_result(res);
    
    // 3. Build sync message based on round type
    if (strcmp(round_type, "ROUND1") == 0 && question_id > 0) {
        // Round 1: Get question details
        sprintf(query, "SELECT question_text, option_a, option_b, option_c, option_d FROM questions WHERE question_id = %d", question_id);
        if (mysql_query(g_db_conn, query) == 0) {
            res = mysql_store_result(g_db_conn);
            if (res && (row = mysql_fetch_row(res)) != NULL) {
                snprintf(json_data, sizeof(json_data),
                    "{\"type\":\"VIEWER_SYNC\",\"round\":%d,\"round_type\":\"ROUND1\","
                    "\"round_id\":%d,\"question_id\":%d,\"question\":\"%s\","
                    "\"optionA\":\"%s\",\"optionB\":\"%s\",\"optionC\":\"%s\",\"optionD\":\"%s\","
                    "\"time_limit\":%d,\"players\":%s}",
                    current_round, round_id, question_id, row[0], row[1], row[2], row[3], row[4],
                    time_limit, players_json);
                
                mysql_free_result(res);
            }
        }
    } else if ((strcmp(round_type, "V1") == 0 || strcmp(round_type, "V2") == 0 || 
                strcmp(round_type, "V4") == 0) && product_id > 0) {
        // Round 2 (V1/V2/V4): Send product info
        snprintf(json_data, sizeof(json_data),
            "{\"type\":\"VIEWER_SYNC\",\"round\":%d,\"round_type\":\"%s\","
            "\"round_id\":%d,\"product_id\":%d,\"product_name\":\"%s\","
            "\"product_desc\":\"%s\",\"product_image\":\"%s\",\"product_price\":%d,"
            "\"threshold\":%.2f,\"time_limit\":%d,\"players\":%s}",
            current_round, round_type, round_id, product_id, product_name,
            product_desc, product_image, product_price, threshold, time_limit, players_json);
    } else if (strcmp(round_type, "V3") == 0) {
        // Round 3: Just send player scores and round type
        snprintf(json_data, sizeof(json_data),
            "{\"type\":\"VIEWER_SYNC\",\"round\":%d,\"round_type\":\"V3\","
            "\"round_id\":%d,\"players\":%s}",
            current_round, round_id, players_json);
    } else {
        // No active round (likely in ranking) - send current_round and player scores
        snprintf(json_data, sizeof(json_data),
            "{\"type\":\"VIEWER_SYNC\",\"round\":%d,\"round_type\":\"RANKING\","
            "\"players\":%s}",
            current_round, players_json);
    }
    
    pthread_mutex_unlock(&mutex);
    
    // Send VIEWER_SYNC message
    Message sync_msg;
    sync_msg.type = VIEWER_SYNC;
    strncpy(sync_msg.value, json_data, BUFF_SIZE - 1);
    sync_msg.value[BUFF_SIZE - 1] = '\0';
    
    int target_fd = (cli->async_conn_fd >= 0) ? cli->async_conn_fd : cli->conn_fd;
    send(target_fd, &sync_msg, sizeof(Message), 0);
    
    printf("[VIEWER_SYNC] Sent game state to %s: %s\n", cli->login_account, json_data);
}
