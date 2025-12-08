import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: waitingRoom
    width: 800
    height: 600

    property string roomCode: "ROOM 01"
    property int currentPlayers: 1
    property int maxPlayers: 4
    property string hostName: ""
    property bool isHost: false
    property bool isReady: false
    property var backend: null
    property var roomMembers: []
    
    // Player ready states
    property var playerReadyStates: [true, false, false, false] // Host always ready
    
    // Revision counter to force QML re-render when arrays change
    property int stateRevision: 0
    
    function allPlayersReady() {
        for (var i = 0; i < currentPlayers; i++) {
            if (!playerReadyStates[i]) return false;
        }
        return currentPlayers >= 2 && currentPlayers <= maxPlayers;
    }
    
    function refreshRoomInfo() {
        if (!backend) return;
        
        try {
            var roomInfoJson = backend.getRoomInfo();
            if (roomInfoJson === "") return;
            
            var roomInfo = JSON.parse(roomInfoJson);
            roomCode = roomInfo.room_code || roomCode;
            maxPlayers = parseInt(roomInfo.max_players) || 4;
            hostName = roomInfo.host_name || "";
            
            // Parse members
            if (roomInfo.members) {
                roomMembers = roomInfo.members.split('|');
                currentPlayers = roomMembers.length;
                
                // Only initialize ready states if not already set (first time or changed player count)
                if (playerReadyStates.length !== currentPlayers) {
                    playerReadyStates = [];
                    for (var i = 0; i < currentPlayers; i++) {
                        playerReadyStates.push(i === 0); // Only host (first member) is ready by default
                    }
                    roomStateVersion++;
                }
            }
            
            // Verify if current user is host (only update if username matches host)
            if (backend.user_name === hostName) {
                isHost = true;
                isReady = true;
            } else {
                // Explicitly set false if not host
                isHost = false;
            }
            
            console.log("Room refreshed:", roomCode, "Players:", currentPlayers, "Host:", hostName, "isHost:", isHost, "user:", backend.user_name);
        } catch (e) {
            console.error("Failed to parse room info:", e);
        }
    }
    
    function parseRoomState(stateJson) {
        // Parse UPDATE_ROOM_STATE message: [{"username":"duyen","is_ready":true}, ...]
        try {
            var members = JSON.parse(stateJson);
            var newMembers = [];
            var newReadyStates = [];
            
            for (var i = 0; i < members.length; i++) {
                newMembers.push(members[i].username);
                newReadyStates.push(members[i].is_ready);
                
                // Update current user's ready state
                if (members[i].username === backend.user_name) {
                    isReady = members[i].is_ready;
                }
            }
            
            // Assign new arrays to trigger property change
            roomMembers = newMembers;
            playerReadyStates = newReadyStates;
            currentPlayers = roomMembers.length;
            
            // Increment revision to force UI update
            stateRevision++;
            
            console.log("Room state parsed:", roomMembers, "Ready states:", playerReadyStates);
        } catch (e) {
            console.error("Failed to parse room state:", e, stateJson);
        }
    }
    
    function refreshOnlineUsers() {
        if (!backend) return;
        
        try {
            var usersJson = backend.fetchOnlineUsers();
            if (usersJson === "") return;
            
            var users = JSON.parse(usersJson);
            onlinePlayersModel.clear();
            
            for (var i = 0; i < users.length; i++) {
                // Don't show users already in room
                if (roomMembers.indexOf(users[i]) === -1) {
                    onlinePlayersModel.append({ playerName: users[i] });
                }
            }
        } catch (e) {
            console.error("Failed to parse online users:", e);
        }
    }
    
    Timer {
        id: refreshTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            refreshRoomInfo();
            refreshOnlineUsers();
        }
    }
    
    Component.onCompleted: {
        refreshRoomInfo();
        refreshOnlineUsers();
        
        if (backend) {
            backend.leaveRoomSuccess.connect(function() {
                stackView.pop()
            })
            
            backend.inviteSuccess.connect(function() {
                console.log("Invitation sent successfully!")
            })
            
            backend.inviteFail.connect(function() {
                console.log("Failed to send invitation!")
            })
            
            backend.readyUpdate.connect(function() {
                console.log("Ready status updated!")
                // Refresh to get updated ready state (will be sent via broadcast)
                refreshRoomInfo()
            })
            
            backend.startGameSuccess.connect(function() {
                console.log("=== GAME STARTED SIGNAL RECEIVED ===")
                console.log("Current user:", backend.user_name)
                console.log("Navigating to Round1Room...")
                // Navigate to Round 1 game screen
                stackView.push("qrc:/qml/Round1Room.qml", { backend: backend })
            })
            
            backend.startGameFail.connect(function() {
                console.log("Failed to start game!")
            })
            
            backend.updateRoomState.connect(function(membersJson) {
                console.log("Room state updated:", membersJson)
                parseRoomState(membersJson)
            })
        }
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
                    id: onlinePlayersModel
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
                                    if (backend) {
                                        backend.inviteUser(playerName)
                                    }
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
        height: 550
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
            spacing: 10

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
                spacing: 6

                // Host Slot
                Rectangle {
                    width: parent.width
                    height: 70
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
                    model: 3
                    
                    Rectangle {
                        width: parent.width
                        height: 70
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
                                text: {
                                    stateRevision; // Force re-evaluation
                                    return index < currentPlayers - 1 && roomMembers[index + 1] ? roomMembers[index + 1] : "Waiting for player...";
                                }
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
                                color: {
                                    stateRevision; // Force re-evaluation
                                    return (playerReadyStates[index + 1] !== undefined && playerReadyStates[index + 1]) ? "#4CAF50" : "#F44336";
                                }
                                Layout.alignment: Qt.AlignVCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        stateRevision; // Force re-evaluation
                                        return (playerReadyStates[index + 1] !== undefined && playerReadyStates[index + 1]) ? "✓" : "✗";
                                    }
                                    color: "white"
                                    font.pixelSize: 32
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            // Spacer để đẩy buttons xuống
            Item {
                width: parent.width
                height: 10
            }

            // Bottom Buttons
            Row {
                spacing: 20
                anchors.horizontalCenter: parent.horizontalCenter

                // Leave Room Button
                Rectangle {
                    width: 140
                    height: 50
                    radius: 25
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
                            if (backend) {
                                backend.leaveRoom()
                            } else {
                                stackView.pop()
                            }
                        }
                    }
                }

                // Ready/Unready Button (for non-host)
                Rectangle {
                    visible: !isHost
                    width: 140
                    height: 50
                    radius: 25
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
                            if (backend) {
                                backend.readyToggle()
                            }
                        }
                    }
                }

                // Start Game Button (for host only) - chỉ enable khi tất cả ready
                Rectangle {
                    visible: isHost
                    width: 140
                    height: 50
                    radius: 25
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
                            if (allPlayersReady() && backend) {
                                backend.startGame()
                            }
                        }
                    }
                }
            }
        }
    }
}
