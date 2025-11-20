// client/src/networkmanager.h
#ifndef NETWORKMANAGER_H
#define NETWORKMANAGER_H

#include <QObject>
#include <QTcpSocket>

class NetworkManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

public:
    explicit NetworkManager(QObject *parent = nullptr);

    Q_INVOKABLE void connectToServer();
    QString statusText() const { return m_statusText; }

signals:
    void statusTextChanged();

private slots:
    void onConnected();
    void onReadyRead();
    void onErrorOccurred(QAbstractSocket::SocketError socketError);

private:
    QTcpSocket m_socket;
    QString m_statusText;

    void setStatusText(const QString &text);
};

#endif // NETWORKMANAGER_H
