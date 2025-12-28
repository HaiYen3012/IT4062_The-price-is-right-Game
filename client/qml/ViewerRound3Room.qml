import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: viewerRound3Room
    width: 800
    height: 600
    
    property var backend: null
    property var stackView: StackView.view  // Use attached property as default
    property string roomCode: ""
    property string syncData: ""  // Initial sync data from server
    property var currentState: null
    
    Component.onCompleted: {
        console.log("[VIEWER R3] ViewerRound3Room loaded for room:", roomCode);
        console.log("[VIEWER R3] syncData:", syncData);
        
        // Parse initial sync data to populate players
        if (syncData && syncData !== "") {
            try {
                var data = JSON.parse(syncData);
                console.log("[VIEWER R3] Parsed sync data:", JSON.stringify(data));
                
                var players = data.players || [];
                console.log("[VIEWER R3] Players count:", players.length);
                
                playersModel.clear();
                for (var i = 0; i < players.length; i++) {
                    var player = players[i];
                    console.log("[VIEWER R3] Player:", player.username, "total_score:", player.total_score);
                    playersModel.append({
                        name: player.username || "",
                        r1Score: 0,  // We don't have individual round scores in sync
                        r2Score: 0,
                        r3Score: 0,
                        totalScore: player.total_score || 0,
                        eliminated: false
                    });
                }
            } catch (e) {
                console.error("[VIEWER R3] Failed to parse initial sync data:", e);
            }
        }
    }
    
    Connections {
        target: backend
        enabled: viewerRound3Room.StackView.status === StackView.Active
        
        function onRoundResult(resultJson) {
            console.log("[VIEWER R3] Round result:", resultJson);
            try {
                var res = JSON.parse(resultJson);
                
                if (res.type === "PLAYER_LEFT") {
                    console.log("[VIEWER R3] Player left:", res.username);
                    // Update player list to show eliminated
                    for (var i = 0; i < playersModel.count; i++) {
                        if (playersModel.get(i).name === res.username) {
                            playersModel.setProperty(i, "eliminated", true);
                            break;
                        }
                    }
                }
                else if (res.type === "SPIN_RESULT") {
                    console.log("[VIEWER R3] Spin result for:", res.user, "value:", res.value);
                    // Update player's R3 score
                    for (var j = 0; j < playersModel.count; j++) {
                        if (playersModel.get(j).name === res.user) {
                            var currentR3 = playersModel.get(j).r3Score;
                            var newR3 = currentR3 + res.value;
                            playersModel.setProperty(j, "r3Score", newR3);
                            
                            var r1 = playersModel.get(j).r1Score;
                            var r2 = playersModel.get(j).r2Score;
                            playersModel.setProperty(j, "totalScore", r1 + r2 + newR3);
                            console.log("[VIEWER R3] Updated", res.user, "R3 score to", newR3);
                            break;
                        }
                    }
                }
                else if (res.type === "TURN_CHANGE") {
                    console.log("[VIEWER R3] Turn changed to:", res.next_user);
                    // Could highlight current player if needed
                }
            } catch (e) {
                console.error("[VIEWER R3] Failed to parse result:", e);
            }
        }
        
        function onGameEnd(rankingData) {
            console.log("[VIEWER R3] GAME_END received, navigating to final ranking");
            try {
                var data = JSON.parse(rankingData);
                var players = data.players || [];
                
                // Sort and add rank
                var sortedPlayers = players.slice().sort(function(a, b) {
                    return (b.total_score || 0) - (a.total_score || 0);
                });
                for (var i = 0; i < sortedPlayers.length; i++) {
                    sortedPlayers[i].rank = i + 1;
                }
                
                stackView.replace("qrc:/qml/RankingPage.qml", {
                    backend: backend,
                    rankings: sortedPlayers,
                    roundNumber: 3,
                    isFinalRanking: true,
                    isViewer: true,
                    roomCode: roomCode
                });
            } catch (e) {
                console.error("[VIEWER R3] Failed to parse GAME_END:", e);
            }
        }
        
        function onViewerStateUpdate(data) {
            console.log("[VIEWER R3] State update:", data);
            try {
                currentState = JSON.parse(data);
                updateDisplay();
            } catch (e) {
                console.error("[VIEWER R3] Failed to parse viewer state:", e);
            }
        }
        
        function onLeaveRoomSuccess() {
            console.log("[VIEWER R3] Left room");
            stackView.replace("qrc:/qml/HomeUser.qml", {backend: backend});
        }
    }
    
    function updateDisplay() {
        if (!currentState) return;
        
        playersModel.clear();
        if (currentState.scores) {
            for (var i = 0; i < currentState.scores.length; i++) {
                var player = currentState.scores[i];
                playersModel.append({
                    name: player.name,
                    r1Score: player.r1 || 0,
                    r2Score: player.r2 || 0,
                    r3Score: player.r3 || 0,
                    totalScore: (player.r1 || 0) + (player.r2 || 0) + (player.r3 || 0),
                    eliminated: player.left || false
                });
            }
        }
    }
    
    // Background
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#FFF3E0" }
            GradientStop { position: 0.5; color: "#FFE0B2" }
            GradientStop { position: 1.0; color: "#FFCC80" }
        }
    }
    
    // Header
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        color: "#E65100"
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20
            
            Image {
                source: "qrc:/ui/trophy.png"
                width: 50
                height: 50
            }
            
            Column {
                spacing: 5
                Text {
                    text: "ROUND 3 - VIEWER MODE"
                    font.pixelSize: 24
                    font.bold: true
                    color: "white"
                }
                Text {
                    text: "Room: " + roomCode
                    font.pixelSize: 14
                    color: "#FFE0B2"
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Rectangle {
                width: 120
                height: 50
                radius: 8
                color: "#DC2626"
                
                Text {
                    anchors.centerIn: parent
                    text: "LEAVE"
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (backend) {
                            backend.leaveViewer();
                        }
                    }
                }
            }
        }
    }
    
    // Main content
    ColumnLayout {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 20
        
        // Players scores
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 280
            radius: 12
            color: "#FFFFFF"
            border.color: "#E65100"
            border.width: 2
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10
                
                Text {
                    text: "Players Scores (All Rounds)"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#E65100"
                }
                
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    
                    model: ListModel {
                        id: playersModel
                    }
                    
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 70
                        radius: 8
                        color: model.eliminated ? "#E0E0E0" : "#FFE0B2"
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            
                            Text {
                                text: model.name
                                font.pixelSize: 16
                                font.bold: true
                                color: model.eliminated ? "#757575" : "#BF360C"
                                Layout.preferredWidth: 100
                            }
                            
                            Column {
                                spacing: 3
                                Text {
                                    text: "R1: " + model.r1Score
                                    font.pixelSize: 11
                                    color: "#666"
                                }
                                Text {
                                    text: "R2: " + model.r2Score
                                    font.pixelSize: 11
                                    color: "#666"
                                }
                                Text {
                                    text: "R3: " + model.r3Score
                                    font.pixelSize: 11
                                    color: "#666"
                                }
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Rectangle {
                                width: 100
                                height: 50
                                radius: 25
                                color: model.eliminated ? "#9E9E9E" : "#FF9800"
                                
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text {
                                        text: "TOTAL"
                                        font.pixelSize: 10
                                        color: "white"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: model.totalScore + " pts"
                                        font.pixelSize: 18
                                        font.bold: true
                                        color: "white"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                            
                            Text {
                                visible: model.eliminated
                                text: "LEFT"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#DC2626"
                            }
                        }
                    }
                }
            }
        }
        
        // Info message
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#E1F5FE"
            border.color: "#0277BD"
            border.width: 2
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20
                
                Image {
                    source: "qrc:/ui/pic.png"
                    width: 100
                    height: 100
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "👁️ VIEWER MODE 👁️"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#01579B"
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "You are watching Round 3.\nSpin wheel game in progress..."
                    font.pixelSize: 16
                    color: "#0288D1"
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
    
    // System Notice Popup
    SystemNoticePopup {
        id: systemNoticePopup
    }
    
    Connections {
        target: backend
        function onSystemNotice(message) {
            systemNoticePopup.show(message)
        }
    }
}
