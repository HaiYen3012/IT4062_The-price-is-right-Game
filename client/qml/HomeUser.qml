import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: homeUser
    width: 800
    height: 600

    property color panelColor: "#FFDCC5"
    property color primaryBlue: "#5FC8FF"
    property color orange: "#F4A800"
    property string userName: ""
    property var backend: null

    Component.onCompleted: {
        if (userName === "" && backend) userName = backend.user_name
    }

    // Background sunburst
    Rectangle {
        anchors.fill: parent
        color: "#E3F2FD"
        Canvas {
            anchors.fill: parent
            id: sunburst2
            property real rotation: 0
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0,0,width,height);
                var centerX = width/2; var centerY = height/2; var numRays = 24;
                for (var i = 0; i < numRays; i++) {
                    var angle = (i * (360/numRays) + rotation) * Math.PI / 180;
                    var gradient = ctx.createLinearGradient(centerX, centerY,
                        centerX + Math.cos(angle) * width,
                        centerY + Math.sin(angle) * height);
                    if (i % 2 === 0) {
                        gradient.addColorStop(0, "#0DCDFF"); gradient.addColorStop(1, "#FFFFFF");
                    } else {
                        gradient.addColorStop(0, "#0DCDFF"); gradient.addColorStop(1, "#0096C8");
                    }
                    ctx.fillStyle = gradient;
                    ctx.beginPath(); ctx.moveTo(centerX, centerY);
                    var a1 = angle - (Math.PI / numRays);
                    var a2 = angle + (Math.PI / numRays);
                    ctx.lineTo(centerX + Math.cos(a1) * width * 2, centerY + Math.sin(a1) * height * 2);
                    ctx.lineTo(centerX + Math.cos(a2) * width * 2, centerY + Math.sin(a2) * height * 2);
                    ctx.closePath(); ctx.fill();
                }
            }
            Timer {
                interval: 50; running: true; repeat: true
                onTriggered: {
                    sunburst2.rotation += 0.5
                    if (sunburst2.rotation >= 360) sunburst2.rotation = 0
                    sunburst2.requestPaint()
                }
            }
        }
    }

    // Left profile panel
    Rectangle {
        id: leftPanel
        width: 150
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 20
        radius: 14
        color: panelColor
        z: 2

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 14

            Image { source: "qrc:/ui/pic.png"; width: 80; height: 80; fillMode: Image.PreserveAspectFit}
            Rectangle { width: 110; height: 28; radius: 14; color: "#FFFFFF";
                Text { anchors.centerIn: parent; text: userName !== "" ? userName : "NKDuyen"; font.bold: true; color: "#333" }
            }
            Button { text: "SETTING"; width: 120; height: 40 }
            Button {
                text: "LOGOUT"; width: 120; height: 40
                onClicked: {
                    if (backend) backend.logOut()
                    stackView.push("qrc:/qml/HomeGuest.qml")
                }
            }
        }
    }

 // Right online-list panel
    Rectangle {
        id: rightPanel
        width: 150
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 20
        radius: 14
        color: panelColor
        z: 2
        Column {
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Rectangle { width: 110; height: 32; radius: 12; color: primaryBlue; Text { anchors.centerIn: parent; text: "Online"; color: "#fff"; font.bold: true } }
            // Sample online users
            ListView {
                id: onlineList
                model: ListModel {}
                width: parent.width
                height: 200
                delegate: Rectangle { width: parent.width; height: 40; color: "transparent"; Row { anchors.fill: parent; anchors.margins: 4; spacing: 8; Image { source: "qrc:/ui/pic.png"; width: 28; height: 28 } Text { text: displayName; color: "#222" } } }
                Component.onCompleted: {
                    if (backend) {
                        var json = JSON.parse(backend.fetchOnlineUsers())
                        onlineList.model.clear()
                        for (var i=0;i<json.length;i++) {
                            onlineList.model.append({ displayName: json[i] })
                        }
                    }
                }
            }
        }
    }
  

    // Center Controls
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 30
        z: 1

       Image {
        source: "qrc:/ui/image.png"
        width: 220
        height: 220
        fillMode: Image.PreserveAspectFit
        anchors.horizontalCenter: parent.horizontalCenter   // thêm dòng này để căn giữa hoàn hảo
    }

        Row {
            spacing: 40
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 160; height: 100; radius: 16; color: orange
                border.color: "#aa6e00"; border.width: 4
                Text { anchors.centerIn: parent; text: "CREATE\nROOM"; font.pixelSize: 20; font.bold: true; color: "#fff"; horizontalAlignment: Text.AlignHCenter }
                MouseArea { anchors.fill: parent; onClicked: { /* TODO: create room */ } }
            }

            Rectangle {
                width: 160; height: 100; radius: 16; color: primaryBlue
                border.color: "#2a85b0"; border.width: 4
                Text { anchors.centerIn: parent; text: "JOIN\nROOM"; font.pixelSize: 20; font.bold: true; color: "#fff"; horizontalAlignment: Text.AlignHCenter }
                MouseArea { anchors.fill: parent; onClicked: roomListPopup.open() }
            }
        }
    }

    // Popup LIST ROOMS - GIỐNG HỆT ẢNH
    Popup {
        id: roomListPopup
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: (parent.width - 620) / 2
        y: (parent.height - 540) / 2
        width: 620
        height: 540

        background: Rectangle {
            radius: 24
            color: "#E8F9FF"
            border.color: "#A0D8F0"
            border.width: 4

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#B3E5FC" }
                    GradientStop { position: 0.1; color: "#E3F8FF" }
                    GradientStop { position: 0.9; color: "#E3F8FF" }
                    GradientStop { position: 1.0; color: "#B3E5FC" }
                }
                rotation: 45
                opacity: 0.6
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20

            Text {
                text: "LIST ROOMS"
                font.pixelSize: 36
                font.bold: true
                color: "#0066AA"
                Layout.alignment: Qt.AlignHCenter
            }

            ListView {
                id: roomsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: ListModel {}
                spacing: 14

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 86
                    radius: 16
                    color: "#B0BEC5"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 20

                        Rectangle {
                            width: 60; height: 60
                            radius: 12
                            color: "white"
                            border.width: 5
                            border.color: "#FFB300"
                            Image { anchors.centerIn: parent; source: "qrc:/ui/trophy.png"; width: 40; height: 40 }
                        }

                        Column {
                            spacing: 6
                            Text { text: room_code; color: "white"; font.pixelSize: 22; font.bold: true }
                            Text { text: players; color: "#E8F5E9"; font.pixelSize: 18 }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 100; height: 50
                            radius: 25
                            color: "#FFCA28"
                            border.width: 4
                            border.color: "#FFB300"
                            Text { anchors.centerIn: parent; text: "JOIN"; color: "#212121"; font.pixelSize: 20; font.bold: true }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    roomListPopup.close()
                                    notifySuccessPopup.popMessage = "Bạn đã tham gia " + (room_code)
                                    notifySuccessPopup.open()
                                }
                            }
                        }
                    }
                }

                Component.onCompleted: {
                    if (backend) {
                        try {
                            var json = JSON.parse(backend.fetchRooms())
                            roomsList.model.clear()
                            for (var i = 0; i < json.length; i++) {
                                roomsList.model.append({
                                    room_code: json[i].room_code,
                                    players: (json[i].current_players || json[i].players) + " / 4"
                                })
                            }
                        } catch (e) { console.log("Lỗi load rooms:", e) }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 60

                Button {
                    text: "HOME"
                    font.pixelSize: 20; font.bold: true
                    contentItem: Text { text: parent.text; color: "white"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: 30; color: "#FF9800"; implicitWidth: 150; implicitHeight: 60 }
                    onClicked: roomListPopup.close()
                }

                Button {
                    text: "REFRESHING"
                    font.pixelSize: 20; font.bold: true
                    contentItem: Text { text: parent.text; color: "white"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: 30; color: "#29B6F6"; implicitWidth: 180; implicitHeight: 60 }
                    onClicked: {
                        if (backend) {
                            try {
                                var json = JSON.parse(backend.fetchRooms())
                                roomsList.model.clear()
                                for (var i = 0; i < json.length; i++) {
                                    roomsList.model.append({
                                        room_code: json[i].room_code,
                                        players: (json[i].current_players || json[i].players) + " / 4"
                                    })
                                }
                            } catch (e) { console.log("Refresh failed:", e) }
                        }
                    }
                }
            }
        }
    }

    // Popup thông báo (nếu chưa có thì thêm vào)
    Popup {
        id: notifySuccessPopup
        property string popMessage: ""
        x: (parent.width - 320) / 2
        y: 100
        width: 320; height: 100
        modal: true
        background: Rectangle { color: "#4CAF50"; radius: 16 }
        Text {
            anchors.centerIn: parent
            text: notifySuccessPopup.popMessage
            color: "white"
            font.pixelSize: 18
            font.bold: true
        }
    }
}