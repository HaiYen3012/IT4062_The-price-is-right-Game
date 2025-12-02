#include "../headers/BackEnd.h"
#include <QDebug>

std::string BackEnd::server_ip = "";
int BackEnd::server_port = 0;
BackEnd *BackEnd::instance = nullptr;

// Static callback function for C
static void message_callback_wrapper(Message msg)
{
    if (BackEnd::instance) {
        if (msg.type == INVITE_NOTIFY) {
            // Parse: invitation_id|from_username|room_code
            int invitation_id;
            char from_user[256], room_code[256];
            sscanf(msg.value, "%d|%[^|]|%s", &invitation_id, from_user, room_code);
            
            emit BackEnd::instance->inviteNotify(invitation_id, 
                QString::fromUtf8(from_user), 
                QString::fromUtf8(room_code));
        }
        else if (msg.type == UPDATE_ROOM_STATE) {
            emit BackEnd::instance->updateRoomState(QString::fromUtf8(msg.value));
        }
    }
}

BackEnd::BackEnd(QObject *parent) : QObject(parent)
{
    instance = this;
    set_message_callback(message_callback_wrapper);
}

BackEnd::~BackEnd()
{
    stop_message_listener();
}

QString BackEnd::getUserName() const
{
    return user_name;
}

void BackEnd::setUserName(const QString &value)
{
    user_name = value;
    emit userNameChanged();
}

void BackEnd::connectToServer()
{
    qDebug() << "Connecting to server: " << server_ip.c_str() << ":" << server_port;
    
    char ip[256];
    strcpy(ip, server_ip.c_str());
    
    int result = connect_to_server(ip, server_port);
    
    if (result == 1) {
        qDebug() << "Connect success!";
        emit connectSuccess();
    } else {
        qDebug() << "Connect failed!";
        emit connectFail();
    }
}

void BackEnd::disconnectToServer()
{
    qDebug() << "Disconnecting from server...";
    disconnect_to_server();
}

void BackEnd::login(QString username, QString password)
{
    qDebug() << "Logging in with username: " << username;
    
    char user[256], pass[256];
    strcpy(user, username.toStdString().c_str());
    strcpy(pass, password.toStdString().c_str());
    
    int loginStatus = ::login(user, pass);
    
    switch(loginStatus) {
        case LOGIN_SUCCESS:
            qDebug() << "Login success!";
            user_name = username;
            emit userNameChanged();
            emit loginSuccess();
            break;
        case LOGGED_IN:
            qDebug() << "User already logged in!";
            emit loggedIn();
            break;
        case ACCOUNT_BLOCKED:
            qDebug() << "Account is blocked!";
            emit accountBlocked();
            break;
        case ACCOUNT_NOT_EXIST:
            qDebug() << "Account does not exist!";
            emit accountNotExist();
            break;
        case WRONG_PASSWORD:
            qDebug() << "Wrong password!";
            emit wrongPassword();
            break;
        default:
            qDebug() << "Unknown login error!";
            break;
    }
}

void BackEnd::signUp(QString username, QString password)
{
    qDebug() << "Signing up with username: " << username;
    
    char uname[256], pwd[256];
    strcpy(uname, username.toStdString().c_str());
    strcpy(pwd, password.toStdString().c_str());
    
    int result = signup(uname, pwd);
    
    switch(result) {
        case SIGNUP_SUCCESS:
            qDebug() << "Signup success!";
            emit signupSuccess();
            break;
        case ACCOUNT_EXIST:
            qDebug() << "Account already exists!";
            emit accountExist();
            break;
        default:
            qDebug() << "Unknown error!";
            break;
    }
}

void BackEnd::logOut()
{
    qDebug() << "Logging out...";
    logout();
    user_name = "";
    emit userNameChanged();
}

Q_INVOKABLE QString BackEnd::fetchRooms()
{
    char buf[4096];
    memset(buf, 0, sizeof(buf));
    int res = get_rooms(buf, sizeof(buf));
    if (res == GET_ROOMS_RESULT && strlen(buf) > 0) {
        qDebug() << "Rooms data:" << buf;
        return QString::fromUtf8(buf);
    }
    qDebug() << "No rooms data, returning empty array";
    return QString("[]");
}

Q_INVOKABLE QString BackEnd::fetchOnlineUsers()
{
    char buf[4096];
    memset(buf, 0, sizeof(buf));
    int res = get_online_users(buf, sizeof(buf));
    if (res == GET_ONLINE_USERS_RESULT && strlen(buf) > 0) {
        qDebug() << "Online users data:" << buf;
        return QString::fromUtf8(buf);
    }
    qDebug() << "No online users data, returning empty array";
    return QString("[]");
}

void BackEnd::createRoom(QString roomCode)
{
    qDebug() << "Creating room:" << roomCode;
    
    char code[256];
    strcpy(code, roomCode.toStdString().c_str());
    
    int result = create_room(code);
    
    switch(result) {
        case CREATE_ROOM_SUCCESS:
            qDebug() << "Room created successfully!";
            emit createRoomSuccess();
            break;
        case CREATE_ROOM_FAIL:
            qDebug() << "Failed to create room!";
            emit createRoomFail();
            break;
        default:
            qDebug() << "Unknown error!";
            break;
    }
}

void BackEnd::joinRoom(QString roomCode)
{
    qDebug() << "Joining room:" << roomCode;
    
    char code[256];
    strcpy(code, roomCode.toStdString().c_str());
    
    int result = join_room(code);
    
    switch(result) {
        case JOIN_ROOM_SUCCESS:
            qDebug() << "Joined room successfully!";
            emit joinRoomSuccess();
            break;
        case JOIN_ROOM_FAIL:
            qDebug() << "Failed to join room!";
            emit joinRoomFail();
            break;
        case ROOM_FULL:
            qDebug() << "Room is full!";
            emit roomFull();
            break;
        default:
            qDebug() << "Unknown error!";
            break;
    }
}

void BackEnd::leaveRoom()
{
    qDebug() << "Leaving room...";
    
    int result = leave_room();
    
    if (result == LEAVE_ROOM_SUCCESS) {
        qDebug() << "Left room successfully!";
        emit leaveRoomSuccess();
    }
}

void BackEnd::inviteUser(QString username)
{
    qDebug() << "Inviting user:" << username;
    
    char user[256];
    strcpy(user, username.toStdString().c_str());
    
    int result = invite_user(user);
    
    switch(result) {
        case INVITE_SUCCESS:
            qDebug() << "Invitation sent!";
            emit inviteSuccess();
            break;
        case INVITE_FAIL:
            qDebug() << "Failed to send invitation!";
            emit inviteFail();
            break;
        default:
            qDebug() << "Unknown error!";
            break;
    }
}

void BackEnd::inviteResponse(int invitationId, bool accept)
{
    qDebug() << "Responding to invitation:" << invitationId << "accept:" << accept;
    
    int result = invite_response(invitationId, accept ? 1 : 0);
    
    if (accept) {
        if (result == JOIN_ROOM_SUCCESS) {
            qDebug() << "Joined room via invitation!";
            emit joinRoomSuccess();
        } else if (result == ROOM_FULL) {
            qDebug() << "Room is full!";
            emit roomFull();
        } else {
            qDebug() << "Failed to join room via invitation, result:" << result;
            emit joinRoomFail();
        }
    } else {
        qDebug() << "Invitation declined";
    }
}

void BackEnd::readyToggle()
{
    qDebug() << "Toggling ready status...";
    
    int result = ready_toggle();
    
    if (result == READY_UPDATE) {
        qDebug() << "Ready status updated!";
        emit readyUpdate();
    }
}

void BackEnd::startGame()
{
    qDebug() << "Starting game...";
    
    int result = start_game();
    
    switch(result) {
        case START_GAME_SUCCESS:
            qDebug() << "Game started!";
            emit startGameSuccess();
            break;
        case START_GAME_FAIL:
            qDebug() << "Failed to start game!";
            emit startGameFail();
            break;
        default:
            qDebug() << "Unknown error!";
            break;
    }
}

QString BackEnd::getRoomInfo()
{
    char buf[4096];
    int res = get_room_info(buf, sizeof(buf));
    if (res == GET_ROOM_INFO_RESULT) {
        return QString::fromUtf8(buf);
    }
    return QString();
}
