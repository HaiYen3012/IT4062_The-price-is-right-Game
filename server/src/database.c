#include "database.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <mysql/mysql.h>
#include <string.h> // thêm để dùng strchr, strcspn

#define DEFAULT_DB_HOST "localhost"
#define DEFAULT_DB_USER "admin"
#define DEFAULT_DB_PASS "123456"
#define DEFAULT_DB_NAME "hay_chon_gia_dung"
#define DEFAULT_DB_PORT 3306

MYSQL *g_db_conn = NULL;

void load_env_file(const char* filename) {
    FILE *f = fopen(filename, "r");
    if (!f) return;

    char line[512];
    while (fgets(line, sizeof(line), f)) {
        if (line[0] == '#' || line[0] == '\n') continue;
        char *eq = strchr(line, '=');
        if (!eq) continue;
        *eq = 0;
        char *key = line;
        char *val = eq + 1;

        val[strcspn(val, "\r\n")] = 0;

        setenv(key, val, 1);
    }
    fclose(f);
}

static const char* get_env_or_default(const char* env_var, const char* default_val) {
    const char* val = getenv(env_var);
    return val ? val : default_val;
}

const char* detect_mysql_socket(void) {
    const char* socket_paths[] = {"/tmp/mysql.sock", NULL};
    for (int i = 0; socket_paths[i] != NULL; i++) {
        if (access(socket_paths[i], F_OK) == 0) {
            printf("[DB] Detected MySQL socket: %s\n", socket_paths[i]);
            return socket_paths[i];
        }
    }
    printf("[DB] No socket file found, using NULL (TCP connection)\n");
    return NULL;
}

int db_init(void) {
    load_env_file(".env");

    g_db_conn = mysql_init(NULL);
    if (!g_db_conn) {
        fprintf(stderr, "[DB] mysql_init() failed\n");
        return -1;
    }

    const char* db_host = get_env_or_default("DB_HOST", DEFAULT_DB_HOST);
    const char* db_user = get_env_or_default("DB_USER", DEFAULT_DB_USER);
    const char* db_pass = get_env_or_default("DB_PASS", DEFAULT_DB_PASS);
    const char* db_name = get_env_or_default("DB_NAME", DEFAULT_DB_NAME);
    const char* db_port_str = getenv("DB_PORT");
    unsigned int db_port = db_port_str ? atoi(db_port_str) : DEFAULT_DB_PORT;

    const char* socket_path = detect_mysql_socket();

    if (!mysql_real_connect(g_db_conn, db_host, db_user, db_pass, db_name, db_port, (char*)socket_path, 0)) {
        fprintf(stderr, "[DB] mysql_real_connect() failed: %s\n", mysql_error(g_db_conn));
        mysql_close(g_db_conn);
        g_db_conn = NULL;
        return -1;
    }

    printf("[DB] Connected to MySQL database '%s' as user '%s'\n", db_name, db_user);
    return 0;
}

int db_count_users(void) {
    if (!g_db_conn) return -1;

    if (mysql_query(g_db_conn, "SELECT COUNT(*) FROM users")) return -1;

    MYSQL_RES *res = mysql_store_result(g_db_conn);
    if (!res) return -1;

    MYSQL_ROW row = mysql_fetch_row(res);
    int count = row && row[0] ? atoi(row[0]) : 0;

    mysql_free_result(res);
    return count;
}

void db_close(void) {
    if (g_db_conn) {
        mysql_close(g_db_conn);
        g_db_conn = NULL;
        printf("[DB] Connection closed.\n");
    }
}

int db_get_user_id_by_username(const char *username) {
    if (!g_db_conn || !username) return -1;

    char query[512];
    snprintf(query, sizeof(query), "SELECT user_id FROM users WHERE username = '%s'", username);

    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "[DB] db_get_user_id_by_username query failed: %s\n", mysql_error(g_db_conn));
        return -1;
    }

    MYSQL_RES *res = mysql_store_result(g_db_conn);
    if (!res) return -1;

    MYSQL_ROW row = mysql_fetch_row(res);
    int user_id = row && row[0] ? atoi(row[0]) : -1;

    mysql_free_result(res);
    return user_id;
}

int db_add_viewer_to_room(int room_id, int user_id) {
    if (!g_db_conn) return -1;

    char query[512];
    snprintf(query, sizeof(query),
        "INSERT INTO room_members (room_id, user_id, role, joined_at, left_at) "
        "VALUES (%d, %d, 'SPECTATOR', NOW(), NULL)",
        room_id, user_id);

    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "[DB] db_add_viewer_to_room failed: %s\n", mysql_error(g_db_conn));
        return -1;
    }

    printf("[DB] Added viewer user_id=%d to room_id=%d\n", user_id, room_id);
    return 0;
}

int db_remove_viewer_from_room(int room_id, int user_id) {
    if (!g_db_conn) return -1;

    // Cập nhật left_at cho bản ghi gần nhất của viewer này trong room
    char query[512];
    snprintf(query, sizeof(query),
        "UPDATE room_members "
        "SET left_at = NOW() "
        "WHERE room_id = %d AND user_id = %d AND role = 'SPECTATOR' AND left_at IS NULL "
        "ORDER BY joined_at DESC LIMIT 1",
        room_id, user_id);

    if (mysql_query(g_db_conn, query)) {
        fprintf(stderr, "[DB] db_remove_viewer_from_room failed: %s\n", mysql_error(g_db_conn));
        return -1;
    }

    printf("[DB] Removed viewer user_id=%d from room_id=%d\n", user_id, room_id);
    return 0;
}
