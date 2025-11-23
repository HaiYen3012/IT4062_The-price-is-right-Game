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
        if (tmp->conn_fd == conn_fd) {
            if (prev == NULL)
                head_client = tmp->next;
            else
                prev->next = tmp->next;
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
                    sprintf(q, "SELECT room_id, room_code, max_players, (SELECT COUNT(*) FROM room_members rm WHERE rm.room_id = r.room_id AND rm.left_at IS NULL) AS current_players FROM rooms r");
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
    
    // Cleanup
    if (cli && cli->login_status == AUTH) {
        pthread_mutex_lock(&mutex);
        char query[256];
        sprintf(query, "UPDATE users SET is_online = 0 WHERE username = '%s'", cli->login_account);
        mysql_query(g_db_conn, query);
        pthread_mutex_unlock(&mutex);
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
