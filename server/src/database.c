#include "database.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// Cấu hình DB (khớp với DATABASE_SETUP.md)
#define DB_HOST "localhost"
#define DB_USER "admin"
#define DB_PASS "123456"
#define DB_NAME "hay_chon_gia_dung"
#define DB_PORT 3306

MYSQL *g_db_conn = NULL;

// Hàm tự động detect MySQL socket path
const char* detect_mysql_socket(void) {
    // Thử các socket paths phổ biến
    const char* socket_paths[] = {
        "/var/run/mysqld/mysqld.sock",     // Ubuntu/Debian default
        "/tmp/mysql.sock",                  // macOS/some Linux
        "/var/lib/mysql/mysql.sock",        // RedHat/CentOS
        "/opt/lampp/var/mysql/mysql.sock",  // XAMPP (nếu ai đó vẫn dùng)
        NULL
    };
    
    for (int i = 0; socket_paths[i] != NULL; i++) {
        if (access(socket_paths[i], F_OK) == 0) {
            printf("[DB] Detected MySQL socket: %s\n", socket_paths[i]);
            return socket_paths[i];
        }
    }
    
    printf("[DB] No socket file found, using NULL (TCP connection)\n");
    return NULL;  // Fallback to TCP connection
}

int db_init(void) {
    g_db_conn = mysql_init(NULL);
    if (g_db_conn == NULL) {
        fprintf(stderr, "[DB] mysql_init() failed\n");
        return -1;
    }

    // Auto-detect socket path
    const char* socket_path = detect_mysql_socket();
    
    if (mysql_real_connect(
            g_db_conn,
            DB_HOST,
            DB_USER,
            DB_PASS,
            DB_NAME,
            DB_PORT,
            socket_path,  // Auto-detected hoặc NULL
            0
        ) == NULL)
    {
        fprintf(stderr, "[DB] mysql_real_connect() failed: %s\n",
                mysql_error(g_db_conn));
        fprintf(stderr, "[DB] Check if MySQL is running: sudo service mysql start\n");
        fprintf(stderr, "[DB] Or verify credentials in database.c (user='%s', db='%s')\n", 
                DB_USER, DB_NAME);
        mysql_close(g_db_conn);
        g_db_conn = NULL;
        return -1;
    }

    printf("[DB] Connected to MySQL database '%s' as user '%s'\n",
           DB_NAME, DB_USER);

    // test query nhẹ
    if (mysql_query(g_db_conn, "SELECT 1")) {
        fprintf(stderr, "[DB] Test query failed: %s\n", mysql_error(g_db_conn));
        return -1;
    } else {
        MYSQL_RES *res = mysql_store_result(g_db_conn);
        if (res) mysql_free_result(res);
        printf("[DB] Test query OK.\n");
    }

    return 0;
}

int db_count_users(void) {
    if (mysql_query(g_db_conn, "SELECT COUNT(*) FROM users")) {
        fprintf(stderr, "[DB] db_count_users failed: %s\n", mysql_error(g_db_conn));
        return -1;
    }

    MYSQL_RES *res = mysql_store_result(g_db_conn);
    if (!res) return -1;

    MYSQL_ROW row = mysql_fetch_row(res);
    int count = 0;
    if (row && row[0]) {
        count = atoi(row[0]);
    }
    mysql_free_result(res);
    return count;
}

void db_close(void) {
    if (g_db_conn != NULL) {
        mysql_close(g_db_conn);
        g_db_conn = NULL;
        printf("[DB] Connection closed.\n");
    }
}
