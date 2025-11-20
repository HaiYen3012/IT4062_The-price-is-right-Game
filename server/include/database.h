// server/include/database.h
#ifndef DATABASE_H
#define DATABASE_H
#include <mysql/mysql.h>

extern MYSQL *g_db_conn;

int db_init(void);
int db_count_users(void);

void db_close(void);

#endif
