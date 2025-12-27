// server/include/database.h
#ifndef DATABASE_H
#define DATABASE_H
#include <mysql/mysql.h>

extern MYSQL *g_db_conn;

int db_init(void);
int db_count_users(void);
int db_add_viewer_to_room(int room_id, int user_id);
int db_remove_viewer_from_room(int room_id, int user_id);
int db_get_user_id_by_username(const char *username);

void db_close(void);

#endif
