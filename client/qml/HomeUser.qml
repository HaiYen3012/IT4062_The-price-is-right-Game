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
    property string pendingRoomCode: ""
    property var stackView

    function refreshOnlineUsers() {
        if (!backend) return;
        try {
            var json = JSON.parse(backend.fetchOnlineUsers());
            onlineList.model.clear();
            for (var i = 0; i < json.length; i++) {
                onlineList.model.append({ displayName: json[i] });
            }
        } catch (e) {
            console.error("Failed to refresh online users:", e);
        }
    }

    function refreshRoomsList() {
        if (!backend) return;
        try {
            var json = JSON.parse(backend.fetchRooms());
            roomsList.model.clear();
            for (var i = 0; i < json.length; i++) {
                roomsList.model.append({
                    room_code: json[i].room_code,
                    players: json[i].players,
                    status: json[i].status || "LOBBY"
                });
            }
        } catch (e) {
            console.error("Failed to refresh rooms:", e);
        }
    }

    Timer {
        id: refreshTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            refreshOnlineUsers();
            refreshRoomsList();
        }
    }

    // Use Connections instead of .connect() to avoid signal accumulation
    Connections {
        target: backend
        enabled: homeUser.StackView.status === StackView.Active
        
        function onCreateRoomSuccess() {
            stackView.push("qrc:/qml/WaitingRoom.qml", { 
                roomCode: pendingRoomCode,
                isHost: true,
                backend: backend
            })
        }
        
        function onCreateRoomFail() {
            notifyErrorPopup.popMessage = "Failed to create room!"
            notifyErrorPopup.open()
        }
        
        function onJoinRoomSuccess() {
            roomListPopup.close()
            stackView.push("qrc:/qml/WaitingRoom.qml", { 
                roomCode: pendingRoomCode,
                isHost: false,
                backend: backend
            })
        }
        
        function onJoinRoomFail() {
            notifyErrorPopup.popMessage = "Failed to join room!"
            notifyErrorPopup.open()
        }
        
        function onRoomFull() {
            notifyErrorPopup.popMessage = "Room is full!"
            notifyErrorPopup.open()
        }
        
        function onJoinAsViewerSuccess() {
            console.log("Viewer join success, waiting for VIEWER_SYNC...");
            // Don't navigate yet, wait for viewerSync signal with game state
        }
        
        function onViewerSync(syncData) {
            console.log("Received VIEWER_SYNC:", syncData);
            roomListPopup.close();
            
            try {
                var data = JSON.parse(syncData);
                var state = data.state || "";
                var roundType = data.round_type || "UNKNOWN";
                var currentRound = data.round || 1;
                
                console.log("Sync data - State:", state, "Round:", currentRound, "Type:", roundType);
                
                // Handle based on state field first
                if (state === "QUESTION" || (state === "" && roundType === "ROUND1" && data.question)) {
                    // Round 1: Currently showing question
                    console.log("Viewer joining during QUESTION");
                    stackView.push("qrc:/qml/ViewerRound1Room.qml", {
                        backend: backend,
                        roomCode: pendingRoomCode,
                        syncData: syncData
                    });
                } else if (state === "RESULT") {
                    // Round 1: Currently showing result
                    console.log("Viewer joining during RESULT");
                    stackView.push("qrc:/qml/ViewerRound1Room.qml", {
                        backend: backend,
                        roomCode: pendingRoomCode,
                        syncData: syncData,
                        initialState: "RESULT"
                    });
                } else if (state === "ROUND2" || state === "ROUND2_RESULT" || (roundType === "V1" || roundType === "V2" || roundType === "V4")) {
                    // Round 2: Showing product or result
                    var isResult = (state === "ROUND2_RESULT");
                    console.log("Viewer joining during ROUND2", isResult ? "(RESULT)" : "(QUESTION)");
                    
                    // Use time_remaining if available, otherwise fallback to time_limit
                    var timeToUse = data.time_remaining !== undefined ? data.time_remaining : (data.time_limit || 30);
                    console.log("Round 2 time - remaining:", data.time_remaining, "limit:", data.time_limit, "using:", timeToUse);
                    
                    stackView.push("qrc:/qml/ViewerRound2Room.qml", {
                        backend: backend,
                        roomCode: pendingRoomCode,
                        round2Id: data.round_id || 0,
                        productName: data.product_name || "",
                        productDesc: data.product_desc || "",
                        productImage: data.product_image || "",
                        thresholdPct: data.threshold || 0,
                        timeRemaining: timeToUse,
                        actualPrice: data.product_price || 0,
                        playerScores: data.players || [],
                        showResult: isResult,
                        initialState: isResult ? "RESULT" : "QUESTION"
                    });
                } else if (state === "ROUND3" || roundType === "V3") {
                    // Round 3 - Use Round3Room with viewer mode
                    console.log("Viewer joining during ROUND3");
                    
                    // Parse players from sync data
                    var players = data.players || [];
                    console.log("Round 3 players:", JSON.stringify(players));
                    
                    stackView.push("qrc:/qml/Round3Room.qml", {
                        backend: backend,
                        isViewerMode: true,
                        initialPlayers: players  // Pass players to initialize
                    });
                } else if (state === "RANKING" || roundType === "RANKING") {
                    // Currently in ranking page between rounds
                    console.log("Viewer joining during RANKING");
                    
                    // Sort players and add rank (same as Round1Room does)
                    var players = data.players || [];
                    var sortedPlayers = players.slice().sort(function(a, b) {
                        return (b.total_score || b.score || 0) - (a.total_score || a.score || 0);
                    });
                    for (var i = 0; i < sortedPlayers.length; i++) {
                        sortedPlayers[i].rank = i + 1;
                    }
                    
                    stackView.push("qrc:/qml/RankingPage.qml", {
                        backend: backend,
                        rankings: sortedPlayers,
                        roundNumber: currentRound,
                        isFinalRanking: false,
                        isViewer: true,
                        roomCode: pendingRoomCode
                    });
                } else {
                    // Unknown - fallback to Round1
                    console.warn("Unknown state/round type:", state, roundType);
                    stackView.push("qrc:/qml/ViewerRound1Room.qml", {
                        backend: backend,
                        roomCode: pendingRoomCode
                    });
                }
            } catch (e) {
                console.error("Failed to parse VIEWER_SYNC:", e);
                // Fallback to Round1
                stackView.push("qrc:/qml/ViewerRound1Room.qml", {
                    backend: backend,
                    roomCode: pendingRoomCode
                });
            }
        }
        
        function onJoinAsViewerFail() {
            notifyErrorPopup.popMessage = "Cannot view this room!"
            notifyErrorPopup.open()
        }
        
        function onUpdateProfileSuccess() {
            // Cập nhật username hiển thị ngay
            if (backend && backend.user_name) {
                homeUser.userName = backend.user_name;
            }
            notifySuccessPopup.popMessage = "Cập nhật thành công!";
            notifySuccessPopup.open();
            backToHomeTimer.start();
        }

        function onUpdateProfileFail() {
            notifyErrorPopup.popMessage = "Cập nhật thất bại!";
            notifyErrorPopup.open();
        }
    }
    
// Add this to HomeUser.qml Component.onCompleted
Component.onCompleted: {
    if (userName === "" && backend) userName = backend.user_name
    
    // Initial load
    refreshOnlineUsers();
    refreshRoomsList();
}

// Add this handler to update username when page becomes active again
StackView.onActivated: {
    console.log("HomeUser activated, updating username from backend")
    if (backend && backend.user_name) {
        userName = backend.user_name
        console.log("Updated username to:", userName)
    }
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

            Button {
                text: "Edit profile"
                width: 120; height: 40
                onClicked: {
                    if (stackView)
                        stackView.push("qrc:/qml/EditProfilePage.qml", { backend: backend, stackView: stackView, homeUser: homeUser })
                }
            }
            Button {
                text: "LOGOUT"; width: 120; height: 40
                onClicked: {
                    console.log("Logging out...")
                    if (backend) {
                        backend.logOut()
                    }
                    // Quay về HomeGuest với backend để có thể login lại
                    stackView.replace("qrc:/qml/HomeGuest.qml", { backend: backend })
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
            // Online users list
            ListView {
                id: onlineList
                model: ListModel {
                    id: onlineUsersModel
                }
                width: parent.width
                height: 200
                clip: true
                delegate: Rectangle { 
                    width: onlineList.width
                    height: 40
                    color: "transparent"
                    Row { 
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 8
                        Image { 
                            source: "qrc:/ui/pic.png"
                            width: 28
                            height: 28
                        }
                        Text { 
                            text: displayName || ""
                            color: "#222"
                            anchors.verticalCenter: parent.verticalCenter
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

            SequentialAnimation on scale {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 1.08; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.08; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
    }

        Row {
            spacing: 40
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 160; height: 100; radius: 16; color: orange
                border.color: "#aa6e00"; border.width: 4
                Text { anchors.centerIn: parent; text: "CREATE\nROOM"; font.pixelSize: 20; font.bold: true; color: "#fff"; horizontalAlignment: Text.AlignHCenter }
                MouseArea { 
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { 
                        pendingRoomCode = "ROOM" + Math.floor(Math.random() * 1000)
                        if (backend) {
                            backend.createRoom(pendingRoomCode)
                        }
                    }
                }
            }

            Rectangle {
                width: 160; height: 100; radius: 16; color: primaryBlue
                border.color: "#2a85b0"; border.width: 4
                Text { anchors.centerIn: parent; text: "JOIN\nROOM"; font.pixelSize: 20; font.bold: true; color: "#fff"; horizontalAlignment: Text.AlignHCenter }
                MouseArea { 
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: roomListPopup.open()
                }
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
                model: ListModel {
                    id: roomsListModel
                }
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
                            Text { 
                                text: room_code
                                color: "white"
                                font.pixelSize: 22
                                font.bold: true
                            }
                            Row {
                                spacing: 8
                                Text { 
                                    text: players
                                    color: "#E8F5E9"
                                    font.pixelSize: 18
                                }
                                Rectangle {
                                    visible: status === "PLAYING"
                                    width: 70
                                    height: 24
                                    radius: 12
                                    color: "#4CAF50"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "PLAYING"
                                        color: "white"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: status === "LOBBY"
                            width: 100; height: 50
                            radius: 25
                            color: "#FFCA28"
                            border.width: 4
                            border.color: "#FFB300"
                            Text { anchors.centerIn: parent; text: "JOIN"; color: "#212121"; font.pixelSize: 20; font.bold: true }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Không đóng popup ngay, chờ kết quả từ server
                                    pendingRoomCode = room_code
                                    if (backend) {
                                        backend.joinRoom(room_code)
                                    }
                                }
                            }
                        }
                        
                        Rectangle {
                            visible: status === "PLAYING"
                            width: 100; height: 50
                            radius: 25
                            color: "#29B6F6"
                            border.width: 4
                            border.color: "#0277BD"
                            Text { anchors.centerIn: parent; text: "VIEW"; color: "white"; font.pixelSize: 20; font.bold: true }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pendingRoomCode = room_code
                                    if (backend) {
                                        backend.joinAsViewer(room_code)
                                    }
                                }
                            }
                        }
                    }
                }

                Component.onCompleted: {
                    refreshRoomsList()
                }
                
                function refreshRoomsList() {
                    if (backend) {
                        try {
                            var result = backend.fetchRooms()
                            if (result && result !== "") {
                                var json = JSON.parse(result)
                                roomsList.model.clear()
                                for (var i = 0; i < json.length; i++) {
                                    roomsList.model.append({
                                        room_code: json[i].room_code,
                                        players: json[i].players,
                                        status: json[i].status || "LOBBY"
                                    })
                                }
                            }
                        } catch (e) { 
                            console.log("Error loading rooms:", e, "Data:", result) 
                        }
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
                        roomsList.refreshRoomsList()
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
    
    Popup {
        id: notifyErrorPopup
        property string popMessage: ""
        x: (parent.width - 320) / 2
        y: 100
        width: 320; height: 100
        modal: true
        background: Rectangle { color: "#FF5252"; radius: 16 }
        Text {
            anchors.centerIn: parent
            text: notifyErrorPopup.popMessage
            color: "white"
            font.pixelSize: 18
            font.bold: true
        }
        Timer {
            interval: 2000
            running: notifyErrorPopup.visible
            onTriggered: notifyErrorPopup.close()
        }
    }

    Timer {
        id: backToHomeTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: {
            if (stackView) {
                // Quay về HomeUser nếu đang ở EditProfilePage
                while (stackView.depth > 1) stackView.pop();
            }
        }
    }
}
