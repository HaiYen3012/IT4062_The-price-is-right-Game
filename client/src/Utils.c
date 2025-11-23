#include "../headers/Utils.h"

int sockfd;
int recvBytes, sendBytes;
char sendBuff[MAX_LINE] = {0}, recvBuff[MAX_LINE];
struct sockaddr_in server, client;
Account acc;

int connect_to_server(char serverIP[], int serverPort)
{
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

  printf("Connecting....\n");
  if (connect(sockfd, (struct sockaddr *)&server, sizeof(server)) < 0)
  {
    printf("Connection Failed \n");
    return 0;
  }
  printf("Connected!\n");
  return 1;
}

int disconnect_to_server()
{
  Message msg;
  msg.type = DISCONNECT;
  send(sockfd, &msg, sizeof(Message), 0);
  close(sockfd);
  printf("Disconnected!\n");
  return 1;
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
