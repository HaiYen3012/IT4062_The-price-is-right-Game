// client/src/networkmanager.cpp
#include "networkmanager.h"
#include <QHostAddress>

NetworkManager::NetworkManager(QObject *parent)
    : QObject(parent)
{
    connect(&m_socket, &QTcpSocket::connected,
            this, &NetworkManager::onConnected);
    connect(&m_socket, &QTcpSocket::readyRead,
            this, &NetworkManager::onReadyRead);
    connect(&m_socket,
            QOverload<QAbstractSocket::SocketError>::of(&QTcpSocket::errorOccurred),
            this, &NetworkManager::onErrorOccurred);

    setStatusText("Chưa kết nối");
}

void NetworkManager::connectToServer()
{
    if (m_socket.state() == QAbstractSocket::ConnectedState) {
        setStatusText("Đã kết nối rồi");
        return;
    }

    setStatusText("Đang kết nối tới server...");
    m_socket.connectToHost(QHostAddress::LocalHost, 5555);
}

void NetworkManager::onConnected()
{
    setStatusText("Kết nối thành công, gửi 'HELLO'...");

    QByteArray data("HELLO FROM CLIENT\n");
    m_socket.write(data);
    m_socket.flush();
}

void NetworkManager::onReadyRead()
{
    QByteArray data = m_socket.readAll();
    setStatusText("Nhận từ server: " + QString::fromUtf8(data));
}

void NetworkManager::onErrorOccurred(QAbstractSocket::SocketError)
{
    setStatusText("Lỗi socket: " + m_socket.errorString());
}

void NetworkManager::setStatusText(const QString &text)
{
    if (m_statusText == text)
        return;
    m_statusText = text;
    emit statusTextChanged();
}
