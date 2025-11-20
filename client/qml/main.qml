// client/qml/main.qml
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15

Window {
    visible: true
    width: 800
    height: 600
    title: qsTr("Hãy Chọn Giá Đúng - Hello Test")

    Column {
        anchors.centerIn: parent
        spacing: 12

        Text {
            text: networkManager.statusText
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Button {
            text: "Kết nối tới server"
            onClicked: networkManager.connectToServer()
        }
    }
}
