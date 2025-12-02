// server/src/server.c
#include "server.h"
#include "database.h"

// Global variables
Client *head_client = NULL;
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
extern MYSQL *g_db_conn;  // From database.c

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

int handle_signup(char username[], char password[])
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

int handle_login(Client *cli, char username[], char password[])
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

int handle_async_connect(int conn_fd, char username[])
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
                break;
                
            case GET_ROOMS:
                {
                    printf("[%d] Client requested room list\n", conn_fd);
                    pthread_mutex_lock(&mutex);
                    char q[512];
                    // Chỉ hiển thị phòng LOBBY và có ít nhất 1 người trong phòng
                    sprintf(q, "SELECT room_id, room_code, max_players, "
                               "(SELECT COUNT(*) FROM room_members rm WHERE rm.room_id = r.room_id AND rm.left_at IS NULL) AS current_players "
                               "FROM rooms r "
                               "WHERE r.status = 'LOBBY' "
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
                            const char *cur_p = row[3] ? row[3] : "0";
                            snprintf(entry, sizeof(entry), "{\"room_id\":%s,\"room_code\":\"%s\",\"players\":\"%s/%s\"}", room_id, room_code, cur_p, max_p);
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
                    msg.type = result;
                    send(conn_fd, &msg, sizeof(Message), 0);
                    if (result == LEAVE_ROOM_SUCCESS && old_room > 0) {
                        broadcast_room_state(old_room);
                    }
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
                            " WHERE rm.room_id = r.room_id AND rm.left_at IS NULL) AS members, "
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
    sprintf(query, "SELECT COUNT(*) FROM room_members WHERE room_id = %d AND left_at IS NULL", room_id);
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
    
    // Cập nhật left_at
    sprintf(query, "UPDATE room_members SET left_at = NOW() WHERE room_id = %d AND user_id = %d", 
            room_id, user_id);
    mysql_query(g_db_conn, query);
    
    // Kiểm tra xem user có phải host không
    sprintf(query, "SELECT host_user_id FROM rooms WHERE room_id = %d", room_id);
    if (mysql_query(g_db_conn, query) == 0) {
        res = mysql_store_result(g_db_conn);
        row = mysql_fetch_row(res);
        if (row != NULL && atoi(row[0]) == user_id) {
            // Host rời phòng
            mysql_free_result(res);
            
            // Kiểm tra còn members nào trong phòng không (không tính host đang rời)
            sprintf(query, "SELECT user_id FROM room_members WHERE room_id = %d AND user_id != %d AND left_at IS NULL ORDER BY joined_at LIMIT 1", 
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
                    // Không còn ai -> đóng phòng
                    mysql_free_result(res);
                    sprintf(query, "UPDATE rooms SET status = 'CLOSED' WHERE room_id = %d", room_id);
                    mysql_query(g_db_conn, query);
                    printf("[%d] Host left, room closed\n", cli->conn_fd);
                }
            }
        } else {
            mysql_free_result(res);
        }
    }
    
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
    sprintf(query, "SELECT COUNT(*) FROM room_members WHERE room_id = %d AND left_at IS NULL", cli->room_id);
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
    
    pthread_mutex_unlock(&mutex);
    
    printf("[%d] Game started in room %d\n", cli->conn_fd, cli->room_id);
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
    sprintf(query, "SELECT u.username FROM room_members rm JOIN users u ON rm.user_id = u.user_id WHERE rm.room_id = %d AND rm.left_at IS NULL ORDER BY rm.joined_at", room_id);
    
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
                    while (tmp != NULL) {
                        if (strcmp(tmp->login_account, target_username) == 0) {
                            // Send on async socket if available, otherwise use main socket
                            int target_fd = (tmp->async_conn_fd >= 0) ? tmp->async_conn_fd : tmp->conn_fd;
                            send(target_fd, &msg, sizeof(Message), 0);
                            printf("Sent INVITE_NOTIFY to %s on fd %d (async=%d)\n", 
                                   target_username, target_fd, tmp->async_conn_fd);
                            break;
                        }
                        tmp = tmp->next;
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
