#include "../headers/Utils.h"

int sockfd;  // Main socket for request/response
int async_sockfd = -1;  // Async socket for notifications
int recvBytes, sendBytes;
char sendBuff[MAX_LINE] = {0}, recvBuff[MAX_LINE];
struct sockaddr_in server, client;
Account acc;

// Message listener globals
MessageCallback g_message_callback = NULL;
pthread_t listener_thread;
int listener_running = 0;
char server_ip[256];
int server_port;

int connect_to_server(char serverIP[], int serverPort)
{
  // Save server info for async socket
  strcpy(server_ip, serverIP);
  server_port = serverPort;
  
  // Create main socket
  if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
  {
    printf("\n Socket creation error \n");
    return 0;
  }
  printf("Server Address: %s:%d\n", serverIP, serverPort);

  memset(&server, 0, sizeof(server));
  server.sin_family = AF_INET;
  server.sin_addr.s_addr = inet_addr(serverIP);
  inet_aton(serverIP, &server.sin_addr);
  server.sin_port = htons(serverPort);

  printf("Connecting main socket....\n");
  if (connect(sockfd, (struct sockaddr *)&server, sizeof(server)) < 0)
  {
    printf("Connection Failed \n");
    return 0;
  }
  printf("Main socket connected!\n");
  
  return 1;
}

int disconnect_to_server()
{
  Message msg;
  msg.type = DISCONNECT;
  send(sockfd, &msg, sizeof(Message), 0);
  close(sockfd);
  
  if (async_sockfd >= 0)
  {
    close(async_sockfd);
    async_sockfd = -1;
  }
  
  printf("Disconnected!\n");
  return 1;
}

int register_async_socket(char username[])
{
  // Create async notification socket
  if ((async_sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
  {
    printf("Async socket creation error\n");
    return 0;
  }
  
  struct sockaddr_in async_server;
  memset(&async_server, 0, sizeof(async_server));
  async_server.sin_family = AF_INET;
  async_server.sin_addr.s_addr = inet_addr(server_ip);
  inet_aton(server_ip, &async_server.sin_addr);
  async_server.sin_port = htons(server_port);
  
  printf("Connecting async socket...\n");
  if (connect(async_sockfd, (struct sockaddr *)&async_server, sizeof(async_server)) < 0)
  {
    printf("Async connection failed, notifications disabled\n");
    close(async_sockfd);
    async_sockfd = -1;
    return 0;
  }
  
  Message msg;
  msg.type = ASYNC_CONNECT;
  strcpy(msg.data_type, "string");
  strcpy(msg.value, username);
  msg.length = strlen(msg.value);
  
  if (send(async_sockfd, &msg, sizeof(Message), 0) < 0)
  {
    printf("Failed to register async socket\n");
    close(async_sockfd);
    async_sockfd = -1;
    return 0;
  }
  
  if (recv(async_sockfd, &msg, sizeof(Message), 0) < 0)
  {
    printf("Failed to receive async registration response\n");
    close(async_sockfd);
    async_sockfd = -1;
    return 0;
  }
  
  if (msg.type == ASYNC_CONNECT_SUCCESS)
  {
    printf("Async socket registered successfully\n");
    return 1;
  }
  
  printf("Async socket registration failed\n");
  close(async_sockfd);
  async_sockfd = -1;
  return 0;
}

int login(char username[], char password[])
{
  Message msg;
  msg.type = LOGIN;
  strcpy(msg.data_type, "string");
  // Format: username | password
  strcpy(msg.value, username);
  strcat(msg.value, " | ");
  strcat(msg.value, password);
  msg.length = strlen(msg.value);
  
  if (send(sockfd, &msg, sizeof(Message), 0) < 0)
  {
    printf("Send failed");
    return -1;
  }

  if (recv(sockfd, &msg, sizeof(Message), 0) < 0)
  {
    printf("Receive failed");
    return -1;
  }

  if (msg.type == LOGIN_SUCCESS)
  {
    strcpy(acc.username, username);
    acc.login_status = 1;
    
    // Register async socket for notifications
    if (register_async_socket(username)) {
      // Start listener thread after async socket registered
      start_message_listener();
    }
  }

  return msg.type;
}

int signup(char username[], char password[])
{
  Message msg;
  msg.type = SIGNUP;
  strcpy(msg.data_type, "string");
  // Format: username | password
  strcpy(msg.value, username);
  strcat(msg.value, " | ");
  strcat(msg.value, password);
  msg.length = strlen(msg.value);
  if (send(sockfd, &msg, sizeof(Message), 0) < 0)
  {
    printf("Send failed");
    return -1;
  }

  if (recv(sockfd, &msg, sizeof(Message), 0) < 0)
  {
    printf("Receive failed");
    return -1;
  }

  return msg.type;
}

int logout()
{
  Message msg;
  msg.type = LOGOUT;
  if (send(sockfd, &msg, sizeof(Message), 0) < 0)
  {
    printf("Send failed");
    return -1;
  }
  return msg.type;
}

int get_rooms(char buffer[], int bufsize)
{
  Message msg;
  msg.type = GET_ROOMS;
  strcpy(msg.data_type, "json");
  msg.length = 0;
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) { printf("Send failed\n"); return -1; }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) { printf("Receive failed\n"); return -1; }
  if (msg.type == GET_ROOMS_RESULT) {
    strncpy(buffer, msg.value, bufsize-1); buffer[bufsize-1] = '\0';
    return msg.type;
  }
  return msg.type;
}

int get_online_users(char buffer[], int bufsize)
{
  Message msg;
  msg.type = GET_ONLINE_USERS;
  strcpy(msg.data_type, "json");
  msg.length = 0;
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) { printf("Send failed\n"); return -1; }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) { printf("Receive failed\n"); return -1; }
  if (msg.type == GET_ONLINE_USERS_RESULT) {
    strncpy(buffer, msg.value, bufsize-1); buffer[bufsize-1] = '\0';
    return msg.type;
  }
  return msg.type;
}

int create_room(char room_code[])
{
  Message msg;
  msg.type = CREATE_ROOM;
  strcpy(msg.data_type, "string");
  strcpy(msg.value, room_code);
  msg.length = strlen(msg.value);
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Send failed\n");
    return -1;
  }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Receive failed\n");
    return -1;
  }
  return msg.type;
}

int join_room(char room_code[])
{
  Message msg;
  msg.type = JOIN_ROOM;
  strcpy(msg.data_type, "string");
  strcpy(msg.value, room_code);
  msg.length = strlen(msg.value);
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Send failed\n");
    return -1;
  }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Receive failed\n");
    return -1;
  }
  return msg.type;
}

int leave_room()
{
  Message msg;
  msg.type = LEAVE_ROOM;
  strcpy(msg.data_type, "string");
  msg.length = 0;
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Send failed\n");
    return -1;
  }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Receive failed\n");
    return -1;
  }
  return msg.type;
}

int invite_user(char username[])
{
  Message msg;
  msg.type = INVITE_USER;
  strcpy(msg.data_type, "string");
  strcpy(msg.value, username);
  msg.length = strlen(msg.value);
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Send failed\n");
    return -1;
  }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Receive failed\n");
    return -1;
  }
  return msg.type;
}

int invite_response(int invitation_id, int accept)
{
  Message msg;
  msg.type = INVITE_RESPONSE;
  strcpy(msg.data_type, "string");
  sprintf(msg.value, "%d|%d", invitation_id, accept);
  msg.length = strlen(msg.value);
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Send failed\n");
    return -1;
  }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Receive failed\n");
    return -1;
  }
  return msg.type;
}

int ready_toggle()
{
  Message msg;
  msg.type = READY_TOGGLE;
  strcpy(msg.data_type, "string");
  msg.length = 0;
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Send failed\n");
    return -1;
  }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Receive failed\n");
    return -1;
  }
  return msg.type;
}

int kick_user(char username[])
{
  Message msg;
  msg.type = KICK_USER;
  strcpy(msg.data_type, "string");
  strcpy(msg.value, username);
  msg.length = strlen(msg.value);
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Send failed\n");
    return -1;
  }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Receive failed\n");
    return -1;
  }
  return msg.type;
}

int start_game()
{
  Message msg;
  msg.type = START_GAME;
  strcpy(msg.data_type, "string");
  msg.length = 0;
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Send failed\n");
    return -1;
  }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Receive failed\n");
    return -1;
  }
  return msg.type;
}

int get_room_info(char buffer[], int bufsize)
{
  Message msg;
  msg.type = GET_ROOM_INFO;
  strcpy(msg.data_type, "json");
  msg.length = 0;
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) { printf("Send failed\n"); return -1; }
  if (recv(sockfd, &msg, sizeof(Message), 0) < 0) { printf("Receive failed\n"); return -1; }
  if (msg.type == GET_ROOM_INFO_RESULT) {
    strncpy(buffer, msg.value, bufsize);
    buffer[bufsize-1] = '\0';
  }
  return msg.type;
}

// ==================== ROUND 1 FUNCTIONS ====================

int submit_answer(int round_id, char answer_choice[])
{
  Message msg;
  msg.type = ANSWER_SUBMIT;
  strcpy(msg.data_type, "string");
  
  // Format: round_id|answer_choice
  sprintf(msg.value, "%d|%s", round_id, answer_choice);
  msg.length = strlen(msg.value);
  
  if (send(sockfd, &msg, sizeof(Message), 0) < 0) {
    printf("Send failed\n");
    return -1;
  }
  
  return ANSWER_SUBMIT;
}

// ==================== MESSAGE LISTENER ====================

// Message listener thread - uses async_sockfd
void *message_listener_thread(void *arg)
{
  (void)arg;
  Message msg;
  
  printf("Message listener thread started\n");
  
  while (listener_running)
  {
    if (async_sockfd < 0)
    {
      printf("Async socket closed, exiting listener\n");
      break;
    }
    
    int bytes = recv(async_sockfd, &msg, sizeof(Message), 0);
    if (bytes <= 0)
    {
      printf("Async socket disconnected\n");
      break;
    }
    
    printf("Received async message type: %d\n", msg.type);
    
    if (g_message_callback)
    {
      g_message_callback(msg);
    }
  }
  
  printf("Message listener thread exiting\n");
  return NULL;
}

void set_message_callback(MessageCallback callback)
{
  g_message_callback = callback;
}

void start_message_listener()
{
  if (async_sockfd < 0)
  {
    printf("Cannot start listener - async socket not available\n");
    return;
  }
  
  listener_running = 1;
  if (pthread_create(&listener_thread, NULL, message_listener_thread, NULL) != 0)
  {
    printf("Failed to create listener thread\n");
    listener_running = 0;
  }
  else
  {
    printf("Message listener started\n");
  }
}

void stop_message_listener()
{
  if (listener_running)
  {
    listener_running = 0;
    pthread_join(listener_thread, NULL);
    printf("Message listener stopped\n");
  }
}
