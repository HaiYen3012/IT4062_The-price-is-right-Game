#ifndef BACKEND_H
#define BACKEND_H

#include <QObject>
#include <QString>
#include <QTimer>
#include <string>

extern "C" {
  #include "Utils.h"
}

class BackEnd : public QObject
{
    Q_OBJECT
public:
    static std::string server_ip;
    static int server_port;
    static BackEnd *instance;

    Q_PROPERTY(QString user_name READ getUserName WRITE setUserName NOTIFY userNameChanged)

    explicit BackEnd(QObject *parent = nullptr);
    ~BackEnd();

    QString getUserName() const;
    void setUserName(const QString &value);

    Q_INVOKABLE void connectToServer();
    Q_INVOKABLE void disconnectToServer();
    Q_INVOKABLE void login(QString username, QString password);
    Q_INVOKABLE void signUp(QString username, QString password);
    Q_INVOKABLE void logOut();
    Q_INVOKABLE QString fetchRooms();
    Q_INVOKABLE QString fetchOnlineUsers();
    Q_INVOKABLE void createRoom(QString roomCode);
    Q_INVOKABLE void joinRoom(QString roomCode);
    Q_INVOKABLE void leaveRoom();
    Q_INVOKABLE void inviteUser(QString username);
    Q_INVOKABLE void inviteResponse(int invitationId, bool accept);
    Q_INVOKABLE void readyToggle();
    Q_INVOKABLE void kickUser(QString username);
    Q_INVOKABLE void startGame();
    Q_INVOKABLE QString getRoomInfo();
    Q_INVOKABLE void submitAnswer(int roundId, QString answer);
    Q_INVOKABLE void submitPrice(int roundId, int guessedPrice);
    Q_INVOKABLE void sendRoundAnswer(QString answer);
    Q_INVOKABLE void startCountdown(int seconds);
    Q_INVOKABLE void stopCountdown();
    Q_INVOKABLE void joinAsViewer(QString roomCode);
    Q_INVOKABLE void leaveViewer();

signals:
    void userNameChanged();
    void connectSuccess();
    void connectFail();
    void signupSuccess();
    void accountExist();
    void loginSuccess();
    void loggedIn();
    void accountBlocked();
    void accountNotExist();
    void wrongPassword();
    void createRoomSuccess();
    void createRoomFail();
    void joinRoomSuccess();
    void joinRoomFail();
    void roomFull();
    void leaveRoomSuccess();
    void updateRoomState(QString data);
    void inviteSuccess();
    void inviteFail();
    void inviteNotify(int invitationId, QString fromUser, QString roomCode);
    void readyUpdate();
    void kickedFromRoom(QString hostName);
    void kickSuccess();
    void kickFail();
    void startGameSuccess();
    void startGameFail();
    void questionStart(int roundId, QString question, QString optionA, QString optionB, QString optionC, QString optionD);
    void questionResult(QString resultData);
    void roundStart(int roundId, QString roundType, QString productName, QString productDesc, int thresholdPct, int timeLimit, QString imageUrl);
    void roundResult(QString resultData);
    void gameEnd(QString rankingData);
    void gameStarted(QString data);
    void timerTick(int secondsRemaining);
    void systemNotice(QString message);
    void joinAsViewerSuccess();
    void joinAsViewerFail();
    void viewerStateUpdate(QString data);
    void viewerSync(QString syncData);

public slots:
    void handleMessageFromThread(int msgType, QString msgValue);

private:
    QString user_name;
    QTimer *m_globalTimer;
    int m_currentSeconds;
    void onTimerTimeout();
};

#endif // BACKEND_H
