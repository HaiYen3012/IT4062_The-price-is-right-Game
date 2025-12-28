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
#define BUFF_SIZE 32768

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
  SYSTEM_ERROR,
  JOIN_AS_VIEWER,
  JOIN_AS_VIEWER_SUCCESS,
  JOIN_AS_VIEWER_FAIL,
  VIEWER_STATE_UPDATE,
  VIEWER_SYNC,
  LEAVE_VIEWER,
  ROOM_CLOSED,
  EDIT_PROFILE,
  EDIT_PROFILE_SUCCESS,
  EDIT_PROFILE_FAIL
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

// Callback for async messages
typedef void (*MessageCallback)(Message* msg);

/*--------------------- Function Declaration -------------------------*/
int connect_to_server(char ip[], int port);
int disconnect_to_server();
int register_async_socket(char username[]);
int login(char username[], char password[]);
int signup(char username[], char password[]);
int logout();
// Fetch JSON string of rooms into buffer (returns message type or -1 on error)
int get_rooms(char buffer[], int bufsize);
// Fetch JSON string of online users into buffer (returns message type or -1 on error)
int get_online_users(char buffer[], int bufsize);
// Room management
int create_room(char room_code[]);
int join_room(char room_code[]);
int leave_room();
int invite_user(char username[]);
int invite_response(int invitation_id, int accept);
int ready_toggle();
int kick_user(char username[]);
int start_game();
int get_room_info(char buffer[], int bufsize);
// Round 1 functions
int submit_answer(int round_id, char answer_choice[]);
// Round 2 functions
int submit_price(int round_id, int guessed_price);
// Viewer functions
int join_as_viewer(char room_code[]);
int leave_viewer();
// Profile management
int edit_profile(char new_username[], char new_password[]);
// Message listener
void set_message_callback(MessageCallback callback);
void start_message_listener();
void stop_message_listener();

#endif /* UTILS_H */
