#ifndef UTILS_H
#define UTILS_H

#include <stdio.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <pthread.h>
#include <ctype.h>
#include <time.h>

#define MAX_LINE 1024
#define BUFF_SIZE 1024

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

typedef struct _message
{
  enum msg_type type;
  char data_type[25];
  int length;
  char value[BUFF_SIZE];    // value phải có dạng "<param1> | <param2> | ..."
} Message;

typedef struct _account
{
  char username[MAX_LINE];
  int login_status; // 0: not login; 1: logged in
} Account;

/*--------------------- Function Declaration -------------------------*/
int connect_to_server(char ip[], int port);
int disconnect_to_server();
int login(char username[], char password[]);
int signup(char username[], char password[]);
int logout();
// Fetch JSON string of rooms into buffer (returns message type or -1 on error)
int get_rooms(char buffer[], int bufsize);
// Fetch JSON string of online users into buffer (returns message type or -1 on error)
int get_online_users(char buffer[], int bufsize);

#endif /* UTILS_H */
