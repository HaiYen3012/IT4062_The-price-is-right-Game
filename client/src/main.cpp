#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCoreApplication>
#include "../headers/BackEnd.h"

int main(int argc, char *argv[])
{
    if(argc != 3)
    {
        printf("Usage: %s <server_ip> <server_port>\n", argv[0]);
        exit(0);
    }

    BackEnd::server_ip = "127.0.0.1";
    BackEnd::server_port = 5555;

    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("applicationDirPath", 
        QUrl::fromLocalFile(QCoreApplication::applicationDirPath()));
    
    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));

    qmlRegisterType<BackEnd>("ThePriceIsRight.BackEnd", 1, 0, "BackEnd");

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
