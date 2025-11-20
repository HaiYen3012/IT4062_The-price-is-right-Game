#include "database.h"
#include <stdio.h>
#include <stdlib.h>

// cấu hình DB tạm hardcode (sau này có thể đọc từ config.ini)
#define DB_HOST "localhost"
#define DB_USER "admin"
#define DB_PASS "123456"  // sửa giống MySQL
#define DB_NAME "hay_chon_gia_dung"
#define DB_PORT 0    

MYSQL *g_db_conn = NULL;

int db_init(void) {
    g_db_conn = mysql_init(NULL);
    if (g_db_conn == NULL) {
        fprintf(stderr, "[DB] mysql_init() failed\n");
        return -1;
    }

    if (mysql_real_connect(
            g_db_conn,
            DB_HOST,
            DB_USER,
            DB_PASS,
            DB_NAME,
            DB_PORT,
            NULL,
            0
        ) == NULL)
    {
        fprintf(stderr, "[DB] mysql_real_connect() failed: %s\n",
                mysql_error(g_db_conn));
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
