#include "../headers/BackEnd.h"
#include <QDebug>
#include <QMetaObject>
extern "C" int sockfd;

std::string BackEnd::server_ip = "";
int BackEnd::server_port = 0;
BackEnd *BackEnd::instance = nullptr;

// Static callback function for C
static void message_callback_wrapper(Message* msg)
{
    if (!msg || !BackEnd::instance) {
        return;
    }
    
    // Tạo bản copy an toàn của msg->value để tránh race condition
    // QUAN TRỌNG: Callback này được gọi từ pthread (background thread)
    // Không thể emit signal trực tiếp từ đây vì Qt không thread-safe
    // Phải dùng QMetaObject::invokeMethod để chuyển sang main thread
    
    // Tạo buffer an toàn với null terminator đảm bảo
    char safe_buffer[BUFF_SIZE];
    size_t len = strnlen(msg->value, BUFF_SIZE - 1);
    memcpy(safe_buffer, msg->value, len);
    safe_buffer[len] = '\0';
    
    QString msgValue = QString::fromUtf8(safe_buffer);
    int msgType = msg->type;
    
    // Gọi slot trong main thread thông qua Qt event queue
    QMetaObject::invokeMethod(BackEnd::instance, "handleMessageFromThread",
                              Qt::QueuedConnection,
                              Q_ARG(int, msgType),
                              Q_ARG(QString, msgValue));
}

BackEnd::BackEnd(QObject *parent) : QObject(parent), m_currentSeconds(0)
{
    // Chỉ set instance nếu chưa có instance nào
    if (!instance) {
        instance = this;
        set_message_callback(message_callback_wrapper);
        qDebug() << "BackEnd instance created and set as active";
    } else {
        qDebug() << "WARNING: Multiple BackEnd instances detected! This may cause duplicate notifications.";
    }
    
    // Initialize global timer
    m_globalTimer = new QTimer(this);
    m_globalTimer->setInterval(1000);
    connect(m_globalTimer, &QTimer::timeout, this, &BackEnd::onTimerTimeout);
}

BackEnd::~BackEnd()
{
    // Stop timer if running
    if (m_globalTimer && m_globalTimer->isActive()) {
        m_globalTimer->stop();
    }
    
    // Chỉ clear instance và callback nếu đây là instance đang active
    if (instance == this) {
        instance = nullptr;
        set_message_callback(nullptr);
        qDebug() << "BackEnd instance destroyed and cleared";
    }
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
    
    // Chỉ gửi request, không chờ response đồng bộ
    // Response sẽ được xử lý qua handleMessageFromThread -> emit leaveRoomSuccess
    int result = leave_room();
    
    if (result < 0) {
        qDebug() << "Failed to send leave room request!";
        // Vẫn emit success để client có thể quay về trang chủ
        emit leaveRoomSuccess();
    } else {
        qDebug() << "Leave room request sent, waiting for server response...";
        // KHÔNG emit leaveRoomSuccess ở đây
        // Sẽ emit khi nhận được LEAVE_ROOM_SUCCESS từ handleMessageFromThread
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

void BackEnd::kickUser(QString username)
{
    qDebug() << "Kicking user:" << username;
    
    char user[256];
    strcpy(user, username.toStdString().c_str());
    
    int result = kick_user(user);
    
    switch(result) {
        case KICK_SUCCESS:
            qDebug() << "User kicked successfully!";
            emit kickSuccess();
            break;
        case KICK_FAIL:
            qDebug() << "Failed to kick user!";
            emit kickFail();
            break;
        default:
            qDebug() << "Unknown error!";
            break;
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

void BackEnd::sendRoundAnswer(QString answer)
{
    qDebug() << "Sending round answer/move:" << answer;
    
    Message msg;
    msg.type = ROUND_ANSWER; // Đảm bảo Enum này khớp với Utils.h
    strcpy(msg.data_type, "text");
    
    // Copy dữ liệu an toàn
    QByteArray ba = answer.toUtf8();
    strncpy(msg.value, ba.constData(), BUFF_SIZE - 1);
    msg.value[BUFF_SIZE - 1] = '\0';
    msg.length = strlen(msg.value);
    
    ::send(sockfd, &msg, sizeof(Message), 0);
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

void BackEnd::submitAnswer(int roundId, QString answer)
{
    qDebug() << "Submitting answer for round" << roundId << ":" << answer;
    
    char ans[10];
    strcpy(ans, answer.toStdString().c_str());
    
    int result = submit_answer(roundId, ans);
    
    if (result == ANSWER_SUBMIT) {
        qDebug() << "Answer submitted successfully!";
    } else {
        qDebug() << "Failed to submit answer!";
    }
}

void BackEnd::submitPrice(int roundId, int guessedPrice)
{
    qDebug() << "Submitting price for round" << roundId << ":" << guessedPrice;
    
    int result = submit_price(roundId, guessedPrice);
    
    if (result == PRICE_SUBMIT) {
        qDebug() << "Price submitted successfully!";
    } else {
        qDebug() << "Failed to submit price!";
    }
}

void BackEnd::editProfile(QString newUsername, QString newPassword) {
    if (newUsername.isEmpty() || newPassword.isEmpty()) {
        emit editProfileFail();
        return;
    }
    Message msg;
    msg.type = EDIT_PROFILE;
    strcpy(msg.data_type, "profile");
    msg.length = newUsername.length() + newPassword.length() + 2;
    QByteArray data = newUsername.toUtf8() + "|" + newPassword.toUtf8();
    strncpy(msg.value, data.constData(), BUFF_SIZE-1);
    msg.value[BUFF_SIZE-1] = '\0';
    send(sockfd, &msg, sizeof(Message), 0);
    // Đợi phản hồi trong hàm nhận dữ liệu (handleMessage)
}

// Slot được gọi từ main thread để xử lý message từ background thread
void BackEnd::handleMessageFromThread(int msgType, QString msgValue)
{
    QByteArray msgValueBytes = msgValue.toUtf8();
    const char* safe_value = msgValueBytes.constData();
    
    if (msgType == LEAVE_ROOM_SUCCESS) {
        qDebug() << "LEAVE_ROOM_SUCCESS received from server";
        emit leaveRoomSuccess();
    }
    else if (msgType == INVITE_NOTIFY) {
        // Parse: invitation_id|from_username|room_code
        int invitation_id;
        char from_user[256], room_code[256];
        sscanf(safe_value, "%d|%[^|]|%s", &invitation_id, from_user, room_code);
        
        emit inviteNotify(invitation_id, 
            QString::fromUtf8(from_user), 
            QString::fromUtf8(room_code));
    }
    else if (msgType == UPDATE_ROOM_STATE) {
        emit updateRoomState(msgValue);
    }
    else if (msgType == GAME_START_NOTIFY) {
        qDebug() << "Game starting notification received!" << msgValue;
        emit gameStarted(msgValue);
        emit startGameSuccess();
    }
    else if (msgType == KICK_NOTIFY) {
        qDebug() << "KICK_NOTIFY received from:" << msgValue;
        emit kickedFromRoom(msgValue);
    }
    else if (msgType == QUESTION_START) {
        qDebug() << "QUESTION_START received, raw data:" << msgValue;
        
        int round_id;
        char question[512], opt_a[256], opt_b[256], opt_c[256], opt_d[256];
        
        char buffer[2048];
        strncpy(buffer, safe_value, sizeof(buffer) - 1);
        buffer[sizeof(buffer) - 1] = '\0';
        
        char *token = strtok(buffer, "|");
        if (token) {
            round_id = atoi(token);
            qDebug() << "Round ID:" << round_id;
            
            token = strtok(NULL, "|");
            if (token) {
                strcpy(question, token);
                qDebug() << "Question:" << question;
            }
            
            token = strtok(NULL, "|");
            if (token) {
                strcpy(opt_a, token);
                qDebug() << "Option A:" << opt_a;
            }
            
            token = strtok(NULL, "|");
            if (token) {
                strcpy(opt_b, token);
                qDebug() << "Option B:" << opt_b;
            }
            
            token = strtok(NULL, "|");
            if (token) {
                strcpy(opt_c, token);
                qDebug() << "Option C:" << opt_c;
            }
            
            token = strtok(NULL, "|");
            if (token) {
                strcpy(opt_d, token);
                qDebug() << "Option D:" << opt_d;
            }
            
            qDebug() << "Emitting questionStart signal...";
            emit questionStart(round_id,
                QString::fromUtf8(question),
                QString::fromUtf8(opt_a),
                QString::fromUtf8(opt_b),
                QString::fromUtf8(opt_c),
                QString::fromUtf8(opt_d));
        } else {
            qDebug() << "ERROR: Failed to parse QUESTION_START!";
        }
    }
    else if (msgType == QUESTION_RESULT) {
        emit questionResult(msgValue);
    }
    else if (msgType == ROUND_START) {
        qDebug() << "ROUND_START received, raw data:" << msgValue;
        
        char buffer[2048];
        strncpy(buffer, safe_value, sizeof(buffer) - 1);
        buffer[sizeof(buffer) - 1] = '\0';
        
        int round_id = 0;
        char round_type[50] = "", product_name[256] = "", product_desc[256] = "", image_url[512] = "";
        int threshold_pct = 0, time_limit = 0;
        
        char *token = strtok(buffer, "|");
        if (token) {
            round_id = atoi(token);
            qDebug() << "Round ID:" << round_id;
            
            token = strtok(NULL, "|");
            if (token) {
                strcpy(round_type, token);
                qDebug() << "Round Type:" << round_type;
            }
            
            token = strtok(NULL, "|");
            if (token) {
                strcpy(product_name, token);
                qDebug() << "Product Name:" << product_name;
            }
            
            token = strtok(NULL, "|");
            if (token) {
                strcpy(product_desc, token);
                qDebug() << "Product Desc:" << product_desc;
            }
            
            token = strtok(NULL, "|");
            if (token) {
                threshold_pct = atoi(token);
                qDebug() << "Threshold %:" << threshold_pct;
            }
            
            token = strtok(NULL, "|");
            if (token) {
                time_limit = atoi(token);
                qDebug() << "Time Limit:" << time_limit;
            }
            
            token = strtok(NULL, "|");
            if (token) {
                strcpy(image_url, token);
                qDebug() << "Image URL:" << image_url;
            }
            
            qDebug() << "Emitting roundStart signal...";
            emit roundStart(round_id,
                QString::fromUtf8(round_type),
                QString::fromUtf8(product_name),
                QString::fromUtf8(product_desc),
                threshold_pct,
                time_limit,
                QString::fromUtf8(image_url));
        } else {
            qDebug() << "ERROR: Failed to parse ROUND_START!";
        }
    }
    else if (msgType == ROUND_RESULT) {
        emit roundResult(msgValue);
    }
    else if (msgType == ROUND_INFO) {
        qDebug() << "Received ROUND_INFO (Turn Change):" << msgValue;
        emit roundResult(msgValue);
    }
    else if (msgType == GAME_END) {
        emit gameEnd(msgValue);
    }
    else if (msgType == SYSTEM_NOTICE) {
        qDebug() << "SYSTEM_NOTICE received:" << msgValue;
        emit systemNotice(msgValue);
    }
    else if (msgType == VIEWER_STATE_UPDATE) {
        qDebug() << "VIEWER_STATE_UPDATE received:" << msgValue;
        emit viewerStateUpdate(msgValue);
    }
    else if (msgType == VIEWER_SYNC) {
        qDebug() << "VIEWER_SYNC received:" << msgValue;
        emit viewerSync(msgValue);
    }
    else if (msgType == ROOM_CLOSED) {
        qDebug() << "ROOM_CLOSED received:" << msgValue;
        emit roomClosed(msgValue);
    }
    else if (msgType == EDIT_PROFILE_SUCCESS) {
        emit editProfileSuccess();
    }
    else if (msgType == EDIT_PROFILE_FAIL) {
        emit editProfileFail();
    }
}

void BackEnd::startCountdown(int seconds)
{
    qDebug() << "Starting global countdown timer:" << seconds << "seconds";
    
    // Stop any existing timer first
    if (m_globalTimer->isActive()) {
        m_globalTimer->stop();
        qDebug() << "Stopped previous timer";
    }
    
    m_currentSeconds = seconds;
    emit timerTick(m_currentSeconds);  // Emit initial value
    m_globalTimer->start();
}

void BackEnd::stopCountdown()
{
    qDebug() << "Stopping global countdown timer";
    if (m_globalTimer->isActive()) {
        m_globalTimer->stop();
    }
    m_currentSeconds = 0;
}

void BackEnd::onTimerTimeout()
{
    if (m_currentSeconds > 0) {
        m_currentSeconds--;
        emit timerTick(m_currentSeconds);
        qDebug() << "Timer tick:" << m_currentSeconds;
    } else {
        m_globalTimer->stop();
        qDebug() << "Timer finished";
    }
}

void BackEnd::joinAsViewer(QString roomCode)
{
    qDebug() << "Joining as viewer:" << roomCode;
    QByteArray roomCodeBytes = roomCode.toUtf8();
    int result = join_as_viewer(roomCodeBytes.data());
    
    if (result == JOIN_AS_VIEWER_SUCCESS) {
        qDebug() << "Join as viewer success";
        emit joinAsViewerSuccess();
    } else {
        qDebug() << "Join as viewer failed";
        emit joinAsViewerFail();
    }
}

void BackEnd::leaveViewer()
{
    qDebug() << "Leaving viewer mode";
    int result = leave_viewer();
    
    if (result == LEAVE_ROOM_SUCCESS) {
        qDebug() << "Leave viewer success";
        emit leaveRoomSuccess();
    }
}
