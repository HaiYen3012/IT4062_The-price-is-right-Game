// server/include/server.h
#ifndef SERVER_H
#define SERVER_H

#include <netinet/in.h>

#define SERVER_PORT 5555
#define BACKLOG 10
#define BUF_SIZE 1024

void start_server(int port);

#endif
