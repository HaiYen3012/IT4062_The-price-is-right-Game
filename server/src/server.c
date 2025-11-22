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
            case SIGNUP:
                {
                    char username[BUFF_SIZE], password[BUFF_SIZE];
                    sscanf(msg.value, "%s %s", username, password);
                    
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
