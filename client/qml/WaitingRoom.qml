import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: waitingRoom
    width: 800
    height: 600

    property string roomCode: "ROOM 01"
    property int currentPlayers: 3
    property int maxPlayers: 5
    property string hostName: "NKDUYEN"
    property bool isHost: true
    property bool isReady: false
    property var backend: null
    
    // Player ready states
    property var playerReadyStates: [true, true, false, false, false] // Host always ready, player1 ready, player2-4 not ready
    
    function allPlayersReady() {
        for (var i = 0; i < currentPlayers; i++) {
            if (!playerReadyStates[i]) return false;
        }
        return currentPlayers === maxPlayers;
    }

    // Background with animated sunburst
    Rectangle {
        anchors.fill: parent
        color: "#E3F2FD"
        
        Canvas {
            id: sunburst
            anchors.fill: parent
            property real rotation: 0
            
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var centerX = width / 2;
                var centerY = height / 2;
                var numRays = 24;
                
                for (var i = 0; i < numRays; i++) {
                    var angle = (i * (360 / numRays) + rotation) * Math.PI / 180;
                    var gradient = ctx.createLinearGradient(
                        centerX, centerY,
                        centerX + Math.cos(angle) * width,
                        centerY + Math.sin(angle) * height
                    );
                    
                    if (i % 2 === 0) {
                        gradient.addColorStop(0, "#0DCDFF");
                        gradient.addColorStop(1, "#FFFFFF");
                    } else {
                        gradient.addColorStop(0, "#0DCDFF");
                        gradient.addColorStop(1, "#0096C8");
                    }
                    
                    ctx.fillStyle = gradient;
                    ctx.beginPath();
                    ctx.moveTo(centerX, centerY);
                    
                    var a1 = angle - (Math.PI / numRays);
                    var a2 = angle + (Math.PI / numRays);
                    ctx.lineTo(centerX + Math.cos(a1) * width * 2, centerY + Math.sin(a1) * height * 2);
                    ctx.lineTo(centerX + Math.cos(a2) * width * 2, centerY + Math.sin(a2) * height * 2);
                    ctx.closePath();
                    ctx.fill();
                }
            }
            
            Timer {
                interval: 50
                running: true
                repeat: true
                onTriggered: {
                    sunburst.rotation += 0.5;
                    if (sunburst.rotation >= 360) sunburst.rotation = 0;
                    sunburst.requestPaint();
                }
            }
        }
    }

    // Left Panel - Online Players List
    Rectangle {
        id: leftPanel
        width: 250
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 20
        radius: 14
        color: "#FFDCC5"
        z: 2

        Column {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 10

            // Online Header
            Rectangle {
                width: parent.width - 20
                height: 45
                radius: 12
                color: "#5FC8FF"
                anchors.horizontalCenter: parent.horizontalCenter
                
                Text {
                    anchors.centerIn: parent
                    text: "Online"
                    color: "white"
                    font.pixelSize: 22
                    font.bold: true
                }
            }

            // Online Players List
            ListView {
                id: onlinePlayersList
                width: parent.width - 10
                height: parent.height - 80
                clip: true
                spacing: 8
                
                model: ListModel {
                    ListElement { playerName: "Player1" }
                    ListElement { playerName: "Player2" }
                    ListElement { playerName: "Player3" }
                    ListElement { playerName: "Player4" }
                    ListElement { playerName: "Player5" }
                    ListElement { playerName: "Player6" }
                }
                
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 60
                    color: "transparent"
                    
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 5
                        spacing: 8
                        
                        // Player Avatar
                        Rectangle {
                            width: 45
                            height: 45
                            radius: 22
                            color: "#FF6B6B"
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Image {
                                anchors.centerIn: parent
                                source: "qrc:/ui/pic.png"
                                width: 40
                                height: 40
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                        
                        // Player Name
                        Text {
                            text: playerName
                            color: "#333"
                            font.pixelSize: 14
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                            width: 80
                            elide: Text.ElideRight
                        }
                        
                        // Invite Button
                        Rectangle {
                            width: 65
                            height: 32
                            radius: 16
                            color: "#F4A800"
                            border.color: "#D89000"
                            border.width: 2
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                anchors.centerIn: parent
                                text: "INVITE"
                                color: "white"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    console.log("Invite player:", playerName)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Right Panel - Room Panel
    Rectangle {
        id: rightPanel
        width: 480
        height: 580
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 20
        radius: 20
        color: "#CCEEFF"
        border.color: "#5FC8FF"
        border.width: 4
        z: 3

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // Room Header
            Rectangle {
                width: parent.width
                height: 60
                radius: 14
                color: "#5FC8FF"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    
                    Text {
                        text: roomCode
                        color: "white"
                        font.pixelSize: 28
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    Item { 
                        Layout.fillWidth: true 
                    }
                    
                    // Players Count
                    Rectangle {
                        id: playersCountRect
                        width: 80
                        height: 40
                        radius: 10
                        color: "white"
                        Layout.alignment: Qt.AlignVCenter
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            
                            Image {
                                source: "qrc:/ui/pic.png"
                                width: 24
                                height: 24
                            }
                            
                            Text {
                                text: currentPlayers + "/" + maxPlayers
                                color: "#333"
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // Player Slots
            Column {
                width: parent.width
                spacing: 8

                // Host Slot
                Rectangle {
                    width: parent.width
                    height: 65
                    radius: 12
                    color: "#90A4AE"
                    border.color: "#607D8B"
                    border.width: 3
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15
                        
                        // Host Avatar
                        Rectangle {
                            width: 50
                            height: 50
                            radius: 25
                            color: "#FFD700"
                            border.color: "#FFA000"
                            border.width: 3
                            Layout.alignment: Qt.AlignVCenter
                            
                            Image {
                                anchors.centerIn: parent
                                source: "qrc:/ui/pic.png"
                                width: 45
                                height: 45
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                        
                        Column {
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter
                            
                            Text {
                                text: hostName
                                color: "white"
                                font.pixelSize: 18
                                font.bold: true
                            }
                            
                            Text {
                                text: "HOST"
                                color: "#FFD700"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // Ready Indicator - Host luôn ready (dấu tích xanh)
                        Rectangle {
                            width: 50
                            height: 50
                            radius: 25
                            color: "#4CAF50"
                            Layout.alignment: Qt.AlignVCenter
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "white"
                                font.pixelSize: 32
                                font.bold: true
                            }
                        }
                    }
                }

                // Player Slots
                Repeater {
                    model: 4
                    
                    Rectangle {
                        width: parent.width
                        height: 65
                        radius: 12
                        color: index < currentPlayers - 1 ? "#90A4AE" : "#78909C"
                        border.color: "#607D8B"
                        border.width: 3
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 15
                            
                            // Player Avatar
                            Rectangle {
                                width: 50
                                height: 50
                                radius: 25
                                color: index < currentPlayers - 1 ? "#5FC8FF" : "#B0BEC5"
                                border.color: "#0096C8"
                                border.width: 3
                                Layout.alignment: Qt.AlignVCenter
                                
                                Image {
                                    anchors.centerIn: parent
                                    source: "qrc:/ui/pic.png"
                                    width: 45
                                    height: 45
                                    fillMode: Image.PreserveAspectFit
                                    visible: index < currentPlayers - 1
                                }
                            }
                            
                            Text {
                                text: index < currentPlayers - 1 ? "PLAYER " + (index + 1) : "Waiting for player..."
                                color: "white"
                                font.pixelSize: 18
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            // Ready Status Indicator
                            Rectangle {
                                width: 50
                                height: 50
                                radius: 25
                                visible: index < currentPlayers - 1
                                color: playerReadyStates[index + 1] ? "#4CAF50" : "#F44336"
                                Layout.alignment: Qt.AlignVCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: playerReadyStates[index + 1] ? "✓" : "✗"
                                    color: "white"
                                    font.pixelSize: 32
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            // Bottom Buttons
            Row {
                spacing: 20
                anchors.horizontalCenter: parent.horizontalCenter

                // Leave Room Button
                Rectangle {
                    width: 140
                    height: 60
                    radius: 30
                    color: "#FF5252"
                    border.color: "#D32F2F"
                    border.width: 4
                    
                    Text {
                        anchors.centerIn: parent
                        text: "LEAVE ROOM"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Navigate back to HomeUser
                            stackView.pop()
                        }
                    }
                }

                // Ready/Unready Button (for non-host)
                Rectangle {
                    visible: !isHost
                    width: 140
                    height: 60
                    radius: 30
                    color: isReady ? "#2196F3" : "#4CAF50"
                    border.color: isReady ? "#1976D2" : "#388E3C"
                    border.width: 4
                    
                    Text {
                        anchors.centerIn: parent
                        text: isReady ? "UN READY" : "READY"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            isReady = !isReady
                            // Update player ready state
                            if (backend) {
                                // backend.toggleReady()
                            }
                        }
                    }
                }

                // Start Game Button (for host only) - chỉ enable khi tất cả ready
                Rectangle {
                    visible: isHost
                    width: 140
                    height: 60
                    radius: 30
                    color: allPlayersReady() ? "#4CAF50" : "#90A4AE"
                    border.color: allPlayersReady() ? "#388E3C" : "#607D8B"
                    border.width: 4
                    opacity: allPlayersReady() ? 1.0 : 0.6
                    
                    Text {
                        anchors.centerIn: parent
                        text: "START GAME"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: allPlayersReady() ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        enabled: allPlayersReady()
                        onClicked: {
                            if (allPlayersReady()) {
                                // Start the game
                                console.log("Starting game...")
                            }
                        }
                    }
                }
            }
        }
    }
}
