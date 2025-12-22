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
  LOGOUT,
  LOGOUT_SUCCESS,
  HEARTBEAT,
  HEARTBEAT_ACK,
  ASYNC_CONNECT,
  ASYNC_CONNECT_SUCCESS,
  CREATE_ROOM,
  CREATE_ROOM_SUCCESS,
  CREATE_ROOM_FAIL,
  JOIN_ROOM,
  JOIN_ROOM_SUCCESS,
  JOIN_ROOM_FAIL,
  ROOM_FULL,
  LEAVE_ROOM,
  LEAVE_ROOM_SUCCESS,
  GET_ROOM_INFO,
  GET_ROOM_INFO_RESULT,
  UPDATE_ROOM_STATE,
  INVITE_USER,
  INVITE_SUCCESS,
  INVITE_FAIL,
  INVITE_NOTIFY,
  INVITE_RESPONSE,
  READY_TOGGLE,
  READY_UPDATE,
  KICK_USER,
  KICK_SUCCESS,
  KICK_FAIL,
  KICK_NOTIFY,
  START_GAME,
  START_GAME_SUCCESS,
  START_GAME_FAIL,
  GAME_START,
  GAME_START_NOTIFY,
  ROUND_INFO,
  ROUND_ANSWER,
  QUESTION_START,
  ANSWER_SUBMIT,
  QUESTION_RESULT,
  ROUND_START,
  PRICE_SUBMIT,
  ROUND_RESULT,
  PLAYER_FORFEIT,
  PLAYER_FORFEIT_NOTIFY,
  GAME_END,
  MATCH_LOG_EVENT,
  STATS_REQUEST,
  STATS_RESPONSE,
  REPLAY_LIST_REQUEST,
  REPLAY_LIST_RESULT,
  REPLAY_GET_REQUEST,
  REPLAY_EVENT,
  CHAT_ROOM_SEND,
  CHAT_ROOM_BROADCAST,
  SPECTATE_JOIN,
  SPECTATE_JOIN_RESULT,
  SYSTEM_NOTICE,
  SYSTEM_ERROR
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

// Room game state structure
typedef struct _room_game_state
{
  int room_id;
  int current_round_id;
  char round_type[20];      // "ROUND1" or "ROUND2"
  time_t round_start_time;  // Thời điểm bắt đầu round hiện tại
  int time_limit_sec;       // Thời gian giới hạn của round
  struct _room_game_state *next;
} RoomGameState;

// Client structure
typedef struct _client
{
  char login_account[BUFF_SIZE];
  int conn_fd;
  int async_conn_fd;  // async socket for notifications (-1 if not set)
  int login_status; // UN_AUTH or AUTH
  int room_id;      // current room (0 if not in room)
  int is_ready;     // ready status in room (0 or 1)
  int is_spectator; // 1 if user is spectator, 0 if player
  struct _client *next;
} Client;

// Global variables
extern Client *head_client;
extern RoomGameState *head_room_state;
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

// Room game state management
RoomGameState *get_room_state(int room_id);
void update_room_state(int room_id, int round_id, const char *round_type, int time_limit_sec);
void clear_room_state(int room_id);

// Authentication functions
int handle_signup(char username[BUFF_SIZE], char password[BUFF_SIZE]);
int handle_login(Client *cli, char username[BUFF_SIZE], char password[BUFF_SIZE]);
int handle_async_connect(int conn_fd, char username[BUFF_SIZE]);

// Room management functions
int handle_create_room(Client *cli, char room_code[BUFF_SIZE]);
int handle_join_room(Client *cli, char room_code[BUFF_SIZE]);
int handle_leave_room(Client *cli);
int handle_invite_user(Client *cli, char target_username[BUFF_SIZE]);
int handle_invite_response(Client *cli, int invitation_id, int accept);
int handle_ready_toggle(Client *cli);
int handle_kick_user(Client *cli, char target_username[BUFF_SIZE]);
int handle_start_game(Client *cli);
void broadcast_room_state(int room_id);
void send_invite_notification(int to_user_id, int from_user_id, int room_id, int invitation_id);
void send_current_game_state(Client *cli, int room_id);
void *send_game_state_delayed(void *arg);

// Round 1 game functions
void *game_round_handler(void *arg);
void *start_round1_thread(void *arg);
void start_round1(int room_id);
int handle_answer_submit(Client *cli, char answer[]);
void broadcast_question_result(int room_id, int round_id);
void broadcast_final_ranking(int room_id, int match_id);

// Round 2 game functions
void start_round2(int room_id, int match_id);
int handle_price_submit(Client *cli, char price_data[]);
void broadcast_round2_result(int room_id, int round_id);

#endif
