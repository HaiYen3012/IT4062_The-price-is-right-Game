// server/src/main.c
#include <stdio.h>
#include <stdlib.h>
#include <time.h> // Include time.h
#include "server.h"
#include "database.h"

int main(void) {
    printf("=== HayChonGiaDung C Server ===\n");

    // Init random seed cho quay số Round 3
    srand(time(NULL));

    if (db_init() != 0) {
        fprintf(stderr, "[SERVER] Failed to init database. Exit.\n");
        return 1;
    }
    int n_users = db_count_users();
    if (n_users >= 0) {
        printf("[DB] Current users in DB: %d\n", n_users);
    }

    // Start server logic
    start_server(SERVER_PORT);

    db_close();
    return 0;
}