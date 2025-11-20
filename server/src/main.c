// server/src/main.c
#include <stdio.h>
#include "server.h"
#include "database.h"

int main(void) {
    printf("=== HayChonGiaDung C Server ===\n");

    if (db_init() != 0) {
        fprintf(stderr, "[SERVER] Failed to init database. Exit.\n");
        return 1;
    }
    int n_users = db_count_users();
    if (n_users >= 0) {
        printf("[DB] Current users in DB: %d\n", n_users);
    }

    // ở Sprint sau sẽ dùng start_server() thật;
    start_server(SERVER_PORT);

    db_close();
    return 0;
}
