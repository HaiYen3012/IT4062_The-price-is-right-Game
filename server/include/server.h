// server/include/server.h
#ifndef SERVER_H
#define SERVER_H

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <ctype.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <pthread.h>
#include <errno.h>
#include <time.h>
#include <mysql/mysql.h>

#define SERVER_PORT 5555
#define BACKLOG 10
#define BUFF_SIZE 1024
#define TRUE 1
#define FALSE 0

// Message types - PHẢI GIỐNG CLIENT
enum msg_type
{
  DISCONNECT,
  LOGIN,
  LOGIN_SUCCESS,
  LOGGED_IN,
  WRONG_PASSWORD,
  ACCOUNT_NOT_EXIST,
  ACCOUNT_BLOCKED,
  SIGNUP,
  ACCOUNT_EXIST,
  SIGNUP_SUCCESS,
  CHANGE_PASSWORD,
  SAME_OLD_PASSWORD,
  CHANGE_PASSWORD_SUCCESS,
  GET_ROOMS,
  GET_ROOMS_RESULT,
  GET_ONLINE_USERS,
  GET_ONLINE_USERS_RESULT,
  LOGOUT
};

enum login_status
{
  AUTH,
  UN_AUTH
};

// Message structure - PHẢI GIỐNG CLIENT
typedef struct _message
{
  enum msg_type type;
  char data_type[25];
  int length;
  char value[BUFF_SIZE];
} Message;

// Client structure
typedef struct _client
{
  char login_account[BUFF_SIZE];
  int conn_fd;
  int login_status; // UN_AUTH or AUTH
  struct _client *next;
} Client;

// Global variables
extern Client *head_client;
extern pthread_mutex_t mutex;
extern MYSQL *g_mysql_conn;

// Function declarations
void start_server(int port);
void *handle_client(void *arg);
void catch_ctrl_c_and_exit(int sig);

// Client management
Client *new_client();
void add_client(int conn_fd);
void delete_client(int conn_fd);
Client *find_client(int conn_fd);

// Authentication functions
int handle_signup(char username[BUFF_SIZE], char password[BUFF_SIZE]);
int handle_login(Client *cli, char username[BUFF_SIZE], char password[BUFF_SIZE]);

#endif
