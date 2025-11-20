// server/src/server.c
#include "server.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>         // close()
#include <sys/socket.h>     // socket, bind, listen, accept
#include <arpa/inet.h>      // inet_ntoa

void start_server(int port) {
    int listen_fd, conn_fd;
    struct sockaddr_in servaddr, cliaddr;
    socklen_t cli_len;
    char buf[BUF_SIZE];

    // 1. Tạo socket TCP
    listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        perror("socket() failed");
        exit(EXIT_FAILURE);
    }

    // Optional: reuse address
    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    // 2. Gán địa chỉ + port cho socket (bind)
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family      = AF_INET;
    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    servaddr.sin_port        = htons(port);

    if (bind(listen_fd, (struct sockaddr*)&servaddr, sizeof(servaddr)) < 0) {
        perror("bind() failed");
        close(listen_fd);
        exit(EXIT_FAILURE);
    }

    // 3. listen() – chuyển sang socket thụ động
    if (listen(listen_fd, BACKLOG) < 0) {
        perror("listen() failed");
        close(listen_fd);
        exit(EXIT_FAILURE);
    }

    printf("[SERVER] Listening on port %d ...\n", port);

    // 4. Vòng lặp accept từng client
    while (1) {
        cli_len = sizeof(cliaddr);
        conn_fd = accept(listen_fd, (struct sockaddr*)&cliaddr, &cli_len);
        if (conn_fd < 0) {
            perror("accept() failed");
            continue;
        }

        printf("[SERVER] New client from %s:%d\n",
               inet_ntoa(cliaddr.sin_addr),
               ntohs(cliaddr.sin_port));

        // Đọc dữ liệu client gửi
        memset(buf, 0, sizeof(buf));
        ssize_t n = read(conn_fd, buf, sizeof(buf) - 1);
        if (n > 0) {
            printf("[SERVER] Received: %s\n", buf);
        } else if (n == 0) {
            printf("[SERVER] Client closed connection.\n");
        } else {
            perror("read() error");
        }

        // Gửi lại thông điệp Hello
        const char *reply = "Hello from C server!\n";
        if (write(conn_fd, reply, strlen(reply)) < 0) {
            perror("Write failed");
        }
        close(conn_fd);
        printf("[SERVER] Connection closed.\n");
    }

    close(listen_fd);
}
