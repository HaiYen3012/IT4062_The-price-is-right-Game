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
        // prefer passed userName, otherwise read from backend
        if (userName === "" && backend) userName = backend.user_name
    }

    // Background sunburst reused
    Rectangle {
        anchors.fill: parent
        color: rootWindow.backgroundColor

        Canvas {
            anchors.fill: parent
            id: sunburst2
            property real rotation: 0
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0,0,width,height);
                var centerX = width/2; var centerY = height/2; var numRays = 24;
                for (var i=0;i<numRays;i++){
                    var angle = (i*(360/numRays)+rotation)*Math.PI/180;
                    var gradient = ctx.createLinearGradient(centerX, centerY, centerX+Math.cos(angle)*width, centerY+Math.sin(angle)*height);
                    if (i%2===0){ gradient.addColorStop(0, "#0DCDFF"); gradient.addColorStop(1, "#FFFFFF"); }
                    else { gradient.addColorStop(0, "#0DCDFF"); gradient.addColorStop(1, "#0096C8"); }
                    ctx.fillStyle = gradient;
                    ctx.beginPath(); ctx.moveTo(centerX, centerY);
                    var a1 = angle - (Math.PI/numRays); var a2 = angle + (Math.PI/numRays);
                    ctx.lineTo(centerX+Math.cos(a1)*width*2, centerY+Math.sin(a1)*height*2);
                    ctx.lineTo(centerX+Math.cos(a2)*width*2, centerY+Math.sin(a2)*height*2);
                    ctx.closePath(); ctx.fill();
                }
            }
            Timer { interval: 50; running: true; repeat: true; onTriggered: { sunburst2.rotation += 0.5; if (sunburst2.rotation>=360) sunburst2.rotation=0; sunburst2.requestPaint(); } }
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

            Image { source: "qrc:/ui/Home User.png"; width: 80; height: 80; fillMode: Image.PreserveAspectFit }
            Rectangle { width: 110; height: 28; radius: 14; color: "#FFFFFF"; Text { anchors.centerIn: parent; text: userName !== "" ? userName : "NKDuyen"; font.bold: true; color: "#333" } }

            Button { text: "SETTING"; width: 120; height: 40; onClicked: { /* TODO: setting */ } }
            Button { text: "LOGOUT"; width: 120; height: 40; onClicked: { backEnd.logOut(); stackView.push("qrc:/qml/HomeGuest.qml") } }
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
                delegate: Rectangle { width: parent.width; height: 40; color: "transparent"; Row { anchors.fill: parent; anchors.margins: 4; spacing: 8; Image { source: "qrc:/ui/Home User.png"; width: 28; height: 28 } Text { text: displayName; color: "#222" } } }
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

    // Center Controls (logo + buttons)
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 30
        z: 1

        Image {
            id: centerImage
            source: "qrc:/ui/image.png"
            width: 220
            height: 220
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Game title (simple)

        Row { spacing: 40; anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                id: createBtn
                width: 160; height: 100; radius: 16; color: orange
                border.color: "#aa6e00"; border.width: 4
                Text { anchors.centerIn: parent; text: "CREATE\nROOM"; font.pixelSize: 20; font.bold: true; color: "#fff"; horizontalAlignment: Text.AlignHCenter }
                MouseArea { anchors.fill: parent; onClicked: { /* TODO: create room */ } }
            }

            Rectangle {
                id: joinBtn
                width: 160; height: 100; radius: 16; color: primaryBlue
                border.color: "#2a85b0"; border.width: 4
                Text { anchors.centerIn: parent; text: "JOIN\nROOM"; font.pixelSize: 20; font.bold: true; color: "#fff"; horizontalAlignment: Text.AlignHCenter }
                MouseArea { anchors.fill: parent; onClicked: roomListPopup.open() }
            }
        }
    }

    // Room list popup
    Popup {
        id: roomListPopup
        modal: true
        focus: true
        x: (parent.width - 620)/2
        y: (parent.height - 420)/2
        closePolicy: Popup.CloseOnPressOutside

        background: Rectangle { width: 620; height: 420; radius: 16; color: "#DFF5FF"; border.color: "#9CCEF0" }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text { text: "LIST ROOMS"; font.pixelSize: 22; font.bold: true; color: "#0A6EA6"; anchors.horizontalCenter: parent.horizontalCenter }

            // Rooms list (dynamic)
            Item {
                id: roomsContainer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: joinRow.top

                ListView {
                    id: roomsList
                    anchors.fill: parent
                    model: ListModel {}
                    clip: true
                    delegate: Rectangle {
                        width: parent.width; height: 78; radius: 10;
                        gradient: Gradient { GradientStop { position: 0.0; color: "#EAF7FB" } GradientStop { position: 1.0; color: "#DFF5FF" } }
                        border.width: 1; border.color: "#9CCEF0"; anchors.margins: 6

                        Row { anchors.fill: parent; anchors.margins: 10; spacing: 12; anchors.verticalCenter: parent.verticalCenter
                            Rectangle { width: 56; height: 56; radius: 8; color: "#FFE89C"; border.color: "#B58C00"; Text { anchors.centerIn: parent; text: "🏆"; font.pixelSize: 18 } }

                            Column { spacing: 6; anchors.verticalCenter: parent.verticalCenter
                                Text { text: room_code; font.pixelSize: 18; font.bold: true; color: "#0A4C6A" }
                                Text { text: "Players: " + players; color: "#246"; font.pixelSize: 12 }
                            }

                            Item { Layout.fillWidth: true }

                            Column { anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                Button { text: "JOIN"; width: 72; onClicked: { roomsListPopup.close(); notifySuccessPopup.popMessage = "Bạn đã tham gia " + room_code; notifySuccessPopup.open(); } }
                                Button { text: "DETAILS"; width: 72; onClicked: { /* show details */ } }
                            }
                        }
                    }
                }

                // Placeholder when no rooms
                Text {
                    id: noRoomsText
                    anchors.centerIn: parent
                    text: "No available rooms"
                    visible: roomsList.count === 0
                    color: "#6A8";
                }
            }

            Row {
                id: joinRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24
                anchors.bottom: parent.bottom

                Button { text: "HOME"; onClicked: roomListPopup.close() }
                Button { text: "REFRESH"; onClicked: fetchAndPopulateRooms() }
            }

            // Fetch helper
            function fetchAndPopulateRooms() {
                if (!backend) return;
                var raw = backend.fetchRooms();
                if (!raw || raw.length === 0) {
                    roomsList.model.clear();
                    return;
                }
                try {
                    var arr = JSON.parse(raw);
                } catch(e) {
                    console.log("Failed to parse rooms JSON:", e, raw);
                    roomsList.model.clear();
                    return;
                }
                roomsList.model.clear();
                for (var i=0; i<arr.length; i++) {
                    roomsList.model.append({ room_id: arr[i].room_id, room_code: arr[i].room_code, players: arr[i].players });
                }
            }

            // Refresh when popup opens
            onOpened: fetchAndPopulateRooms()
        }
    }
}
