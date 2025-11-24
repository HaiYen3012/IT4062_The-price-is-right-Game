#include "../headers/BackEnd.h"
#include <QDebug>

std::string BackEnd::server_ip = "";
int BackEnd::server_port = 0;
BackEnd *BackEnd::instance = nullptr;

BackEnd::BackEnd(QObject *parent) : QObject(parent)
{
    instance = this;
}

BackEnd::~BackEnd()
{
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
    int res = get_rooms(buf, sizeof(buf));
    if (res == GET_ROOMS_RESULT) {
        return QString::fromUtf8(buf);
    }
    return QString();
}

Q_INVOKABLE QString BackEnd::fetchOnlineUsers()
{
    char buf[4096];
    int res = get_online_users(buf, sizeof(buf));
    if (res == GET_ONLINE_USERS_RESULT) {
        return QString::fromUtf8(buf);
    }
    return QString();
}
