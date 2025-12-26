import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: room3
    width: 800
    height: 600

    property var backend: null
    property string hostName: "Host"
    property int currentPlayerIndex: 0
    property bool spinning: false
    property real spinnerOffset: 0
    property int itemHeight: 40
    property int cycles: 6
    property int spinTargetIndex: 0
    property bool spinnerInitialized: false
    property string displayedNumber: "000"
    property int shuffleTick: 0
    property int shuffleMax: 25
    
    property string myUserName: backend ? backend.user_name : ""
    
    // Biến đếm lượt quay (0, 1, 2)
    property int currentTurnSpins: 0 
    
    property var currentServerResult: null 
    property string pendingNextUser: ""
    
    // Round 3 result display
    property var round3Results: null  // Store ROUND3_END data
    property var finalRankings: null  // Store final rankings from GAME_END
    property bool finalRankingPushed: false  // Prevent double navigation

    property var numbers: ["050","005","060","070","025","080","040","095","010","085","075","035","000","045","090","020","065","055","030","100","015"]

    ListModel { id: playersModel }
    
    // Timer to show Round 3 result popup then push to RankingPage
    Timer {
        id: round3ResultTimer
        interval: 3000  // Show result for 3 seconds
        running: false
        onTriggered: {
            console.log("Round3: Result display timeout - pushing to RankingPage");
            
            // Safe stringify với try-catch
            if (finalRankings) {
                try {
                    console.log("Final rankings to push:", JSON.stringify(finalRankings));
                } catch (e) {
                    console.log("Final rankings to push: [unable to stringify]");
                }
            } else {
                console.log("Final rankings to push: null");
            }
            
            // Close popup before navigating away so it does not linger
            if (round3ResultPopup.visible) {
                round3ResultPopup.close();
            }
            // Navigation now handled in popup.onClosed to ensure popup fully disappears first
        }
    }

    Timer {
        id: shuffleTimer
        interval: 80
        repeat: true
        running: false
        onTriggered: {
            shuffleTick += 1
            if (shuffleTick >= shuffleMax) {
                displayedNumber = numbers[spinTargetIndex]
                running = false
                endCurrentTurn()
                return
            }
            displayedNumber = numbers[Math.floor(Math.random() * numbers.length)]
        }
    }

    Connections {
        target: backend
        enabled: room3.StackView.status === StackView.Active
        
        function onUpdateRoomState(data) {
            console.log("Room3 - onUpdateRoomState:", data);
            try {
                var info = JSON.parse(data);
                if (info.members) {
                    var memberNames = info.members.split('|');
                    console.log("Room members update, count:", memberNames.length);
                    
                    // KHÔNG rebuild playersModel vì sẽ làm mất index
                    // Chỉ kiểm tra xem có người rời không (để xử lý nếu cần)
                    
                    // Nếu không còn ai, quay về home
                    if (memberNames.length === 0) {
                        console.log("All players left, returning to home");
                        stackView.replace("qrc:/qml/HomeUser.qml", {backend: backend});
                    } else if (memberNames.length === 1) {
                        console.log("Only 1 player remaining, game continues");
                    }
                }
            } catch (e) {
                console.error("Room3 - Failed to parse UPDATE_ROOM_STATE:", e);
            }
        }
        
        function onLeaveRoomSuccess() {
            console.log("Room3 - Leave room successful");
            stackView.replace("qrc:/qml/HomeUser.qml", {backend: backend});
        }
        
        function onRoundResult(resultJson) {
            try {
                var res = JSON.parse(resultJson)
                console.log("Receive:", resultJson)

                if (res.type === "PLAYER_LEFT") {
                    // Người chơi rời phòng
                    console.log("Player left:", res.username);
                    
                    // Đánh dấu người chơi đã rời
                    for (var i = 0; i < playersModel.count; i++) {
                        if (playersModel.get(i).name === res.username) {
                            playersModel.set(i, { 
                                name: playersModel.get(i).name, 
                                score: playersModel.get(i).score, 
                                eliminated: true  // Đánh dấu đã OUT
                            });
                            console.log("Marked player", res.username, "as eliminated");
                            break;
                        }
                    }
                }
                else if (res.type === "SPIN_RESULT") {
                    // CHỈ gán result khi đúng là tin nhắn quay số
                    currentServerResult = res 
                    var p = playersModel.get(currentPlayerIndex)
                    if (p && res.user === p.name) {
                        currentTurnSpins = res.spins_count
                    }
                    handleSpinResult(res)
                }
                else if (res.type === "TURN_CHANGE") {
                    pendingNextUser = res.next_user
                    if (!spinning) {
                        applyNextTurn()
                    }
                }
                else if (res.type === "ROUND3_END") {
                    // Round 3 ended - store results and show popup
                    console.log("Vòng 3 kết thúc - Nhận kết quả:", JSON.stringify(res));
                    round3Results = res.details || [];  // Array of {user, score, left}
                    spinning = false;
                    
                    // Show result popup
                    round3ResultPopup.open();
                    
                    // Start timer to auto-dismiss; if rankings not yet available we'll push once GAME_END arrives
                    console.log("Starting result timer after ROUND3_END");
                    round3ResultTimer.start();
                }
            } catch (e) {
                console.error("Lỗi xử lý JSON:", e)
            }
        }
        
        function onGameEnd(rankingData) {
            console.log("=== GAME END received in Room3 ===");
            console.log("Ranking data:", rankingData);
            try {
                var data = JSON.parse(rankingData);
                var players = data.players || [];
                console.log("Parsed final ranking, players count:", players.length);
                console.log("Final rankings from server:", JSON.stringify(players));
                
                // Server đã gửi rank và total_score sẵn, không cần sort lại
                // Chỉ cần sử dụng trực tiếp
                var finalRankings = players;
                spinning = false;
                
                // Store final rankings for timer callback
                room3.finalRankings = finalRankings;
                
                // If popup is showing (or timer is running), let timer close then navigate; otherwise navigate immediately
                if (!finalRankingPushed) {
                    if (round3ResultPopup.visible || round3ResultTimer.running) {
                        console.log("GAME_END received while popup active -> ensure timer is running; navigation will occur on popup close");
                        round3ResultTimer.start();
                    } else {
                        console.log("GAME_END received after popup closed -> replacing to RankingPage now");
                        stackView.replace("qrc:/qml/RankingPage.qml", {
                            backend: backend,
                            rankings: finalRankings,
                            roundNumber: 3,
                            isFinalRanking: true
                        });
                        finalRankingPushed = true;
                    }
                }
            } catch (e) {
                console.error("Room3 - Failed to parse GAME_END data:", e);
            }
        }
    }

    function applyNextTurn() {
        console.log("applyNextTurn: pendingNextUser =", pendingNextUser, "currentPlayerIndex =", currentPlayerIndex);
        console.log("applyNextTurn: playersModel.count =", playersModel.count);
        
        if (pendingNextUser !== "") {
            var found = false;
            for (var i = 0; i < playersModel.count; i++) {
                console.log("applyNextTurn: Checking player", i, ":", playersModel.get(i).name, "===", pendingNextUser, "?");
                if (playersModel.get(i).name === pendingNextUser) {
                    currentPlayerIndex = i;
                    console.log("applyNextTurn: Found player at index", i);
                    found = true;
                    break;
                }
            }
            if (!found) {
                console.error("applyNextTurn: pendingNextUser '" + pendingNextUser + "' NOT FOUND in playersModel!");
                console.log("Players in model:", JSON.stringify(playersModel));
            }
            // Reset trạng thái người mới
            currentTurnSpins = 0 
            pendingNextUser = ""
        }
    }

    function handleSpinResult(res) {
        console.log("handleSpinResult: spin_val =", res.spin_val, "spins_count =", res.spins_count);
        
        var val = res.spin_val
        var targetIdx = -1
        
        for (var i = 0; i < numbers.length; i++) {
            if (parseInt(numbers[i]) === val) { targetIdx = i; break; }
        }

        if (targetIdx !== -1) {
            spinTargetIndex = targetIdx

            // Cập nhật lượt quay từ server
            currentTurnSpins = res.spins_count;
            console.log("handleSpinResult: Updated currentTurnSpins to", currentTurnSpins);

            // Hiệu ứng xáo số trong ô đỏ
            shuffleTick = 0
            spinning = true
            shuffleTimer.start()
        }
    }

    function endCurrentTurn() {
        // Kết thúc quay -> spinning = false -> Các nút sẽ tự động sáng lại (nhờ binding)
        spinning = false
        
        if (currentServerResult) {
            var user = currentServerResult.user
            var total = currentServerResult.total
            
            for (var i = 0; i < playersModel.count; i++) {
                if (playersModel.get(i).name === user) {
                    playersModel.set(i, { name: user, score: total })
                    break
                }
            }
            currentServerResult = null
        }
        applyNextTurn()
    }

    // --- GIAO DIỆN ---
    Image {
        id: bgImage
        anchors.fill: parent
        anchors.bottomMargin: footerBar.height
        source: "qrc:/ui/bgroom3.png"
        fillMode: Image.PreserveAspectCrop
        z: -1
        opacity: 0.7
    }

    Rectangle {
        id: headerBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 64; color: "#ffffff"; border.color: "#e0eef6"; border.width: 1
        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 16
            Image { source: "qrc:/ui/trophy.png"; width: 40; height: 40; Layout.preferredWidth: 40; Layout.preferredHeight: 40 }
            Column { 
                spacing: 2; Layout.alignment: Qt.AlignVCenter
                Text { text: "ROOM 03"; font.pixelSize: 20; font.bold: true; color: "#0B5E8A" }
                Text { text: "Host: " + hostName; font.pixelSize: 12; color: "#666" }
            }
            Item { Layout.fillWidth: true }
            Rectangle { 
                width: 150; height: 36; radius: 18; color: "#FFCA28"; border.color: "#FFB300"; Layout.alignment: Qt.AlignVCenter
                Row {
                    anchors.centerIn: parent; spacing: 5
                    Text { text: "Player:"; font.pixelSize: 12; color: "#444" }
                    Text { text: myUserName; font.bold: true; color: "#D32F2F" }
                }
            }
        }
    }

    // Left Player Box - Current User
    Rectangle {
        id: leftPlayerBox
        x: 20; y: headerBar.height + 20
        width: 160; height: 220; radius: 12; color: "#FFDCC5"; z: 10
        
        property int myIndex: {
            for (var i = 0; i < playersModel.count; i++) {
                if (playersModel.get(i).name === myUserName) return i
            }
            return -1
        }
        
        Column { 
            anchors.fill: parent; anchors.margins: 12; spacing: 8; anchors.horizontalCenter: parent.horizontalCenter
            
            Text {
                text: "YOU"
                font.pixelSize: 14
                font.bold: true
                color: "#D32F2F"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Rectangle { 
                width: 100; height: 100; radius: 50; color: "#ffffff"; border.width: 3; border.color: currentPlayerIndex === leftPlayerBox.myIndex ? "#29B6F6" : "#d6eaf2"; anchors.horizontalCenter: parent.horizontalCenter
                Image { anchors.centerIn: parent; source: "qrc:/ui/pic.png"; width: 80; height: 80; fillMode: Image.PreserveAspectFit }
            }
            
            Text { 
                text: leftPlayerBox.myIndex >= 0 ? playersModel.get(leftPlayerBox.myIndex).name : myUserName
                font.bold: true
                font.pixelSize: 14
                color: "#D32F2F"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Rectangle {
                width: 120
                height: 35
                radius: 17
                color: "#FF9800"
                border.color: "#F57C00"
                border.width: 2
                anchors.horizontalCenter: parent.horizontalCenter
                
                Text { 
                    anchors.centerIn: parent
                    text: leftPlayerBox.myIndex >= 0 ? playersModel.get(leftPlayerBox.myIndex).score + " pts" : "0 pts"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                }
            }
            
            Rectangle { 
                visible: currentPlayerIndex === leftPlayerBox.myIndex
                width: 16; height: 16; radius: 8; color: "#29B6F6"
                anchors.horizontalCenter: parent.horizontalCenter
                
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: currentPlayerIndex === leftPlayerBox.myIndex
                    NumberAnimation { from: 1.0; to: 0.3; duration: 500 }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 500 }
                }
            }
        }
    }

    // Right Players - Other players
    Column {
        id: rightPlayersBox
        x: parent.width - 20 - 160; y: headerBar.height + 20
        width: 160; spacing: 12; z: 10
        
        Repeater {
            model: playersModel.count
            delegate: Rectangle {
                visible: playersModel.get(index).name !== myUserName
                width: 160; height: 110; radius: 12
                color: playersModel.get(index).eliminated ? "#CCCCCC" : "#FFDCC5"
                border.width: currentPlayerIndex === index ? 3 : 0
                border.color: "#29B6F6"
                opacity: playersModel.get(index).eliminated ? 0.6 : 1.0
                
                Column { 
                    anchors.fill: parent; anchors.margins: 10; spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                    
                    Rectangle { 
                        width: 60; height: 60; radius: 30
                        color: "#ffffff"
                        border.width: 2
                        border.color: currentPlayerIndex === index ? "#29B6F6" : "#d6eaf2"
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        Image { 
                            anchors.centerIn: parent
                            source: "qrc:/ui/pic.png"
                            width: 48; height: 48
                            fillMode: Image.PreserveAspectFit
                            opacity: playersModel.get(index).eliminated ? 0.5 : 1.0
                        }
                        
                        // OUT badge
                        Rectangle {
                            visible: playersModel.get(index).eliminated
                            width: 35; height: 18
                            radius: 4
                            color: "#DC2626"
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: -5
                            
                            Text {
                                anchors.centerIn: parent
                                text: "OUT"
                                font.pixelSize: 10
                                font.bold: true
                                color: "white"
                            }
                        }
                    }
                    
                    Text { 
                        text: playersModel.get(index).name
                        font.bold: true
                        font.pixelSize: 13
                        color: playersModel.get(index).eliminated ? "#888888" : (currentPlayerIndex === index ? "#0B5E8A" : "#222")
                        anchors.horizontalCenter: parent.horizontalCenter
                        elide: Text.ElideRight
                        width: parent.width - 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Rectangle {
                        width: 100
                        height: 28
                        radius: 14
                        color: playersModel.get(index).eliminated ? "#999999" : "#FF9800"
                        border.color: playersModel.get(index).eliminated ? "#777777" : "#F57C00"
                        border.width: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        Text { 
                            anchors.centerIn: parent
                            text: playersModel.get(index).score + " pts"
                            font.pixelSize: 13
                            font.bold: true
                            color: "white"
                        }
                    }
                }
            }
        }
    }

    // Center Area
    Rectangle {
        id: centerArea
        anchors.left: leftPlayerBox.right
        anchors.right: rightPlayersBox.left
        anchors.top: headerBar.bottom
        anchors.bottom: footerBar.top
        anchors.margins: 20
        color: "transparent"
        z: 1
        
        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.5
            
            Text {
                text: "ROOM 03 - SPIN WHEEL"
                font.pixelSize: 22
                font.bold: true
                color: "#043B56"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                id: spinnerViewport
                width: 140
                height: 220
                color: "transparent"
                clip: true
                radius: 6
                anchors.horizontalCenter: parent.horizontalCenter
                
                Item {
                    id: spinnerContent
                    width: spinnerViewport.width
                    height: numbers.length * itemHeight * (cycles + 2)
                    x: 0
                    y: spinnerOffset
                    
                    Repeater {
                        model: numbers.length * (cycles + 2)
                        delegate: Rectangle {
                            width: spinnerViewport.width
                            height: itemHeight
                            y: index * itemHeight
                            color: index % numbers.length === spinTargetIndex ? "#FF5252" : "#E3F2FD"
                            border.color: "#90CAF9"
                            border.width: 1
                            
                            Text {
                                anchors.centerIn: parent
                                text: numbers[index % numbers.length]
                                font.pixelSize: 18
                                font.bold: true
                                color: index % numbers.length === spinTargetIndex ? "white" : "#0B5E8A"
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: 140
                height: 60
                radius: 8
                color: "#FF5252"
                border.color: "#D32F2F"
                border.width: 3
                anchors.horizontalCenter: parent.horizontalCenter
                
                Text {
                    anchors.centerIn: parent
                    text: displayedNumber
                    font.pixelSize: 28
                    font.bold: true
                    color: "white"
                }
            }

            // --- NÚT BẤM (Với màu sắc và hover rõ ràng hơn) ---
            Row {
                spacing: 15
                anchors.horizontalCenter: parent.horizontalCenter
                
                property bool isMyTurn: {
                    if (playersModel.count === 0) return false
                    if (currentPlayerIndex >= playersModel.count) return false
                    return playersModel.get(currentPlayerIndex).name === myUserName
                }

                Button {
                    id: spinBtn
                    width: 120
                    height: 50
                    text: spinning ? "SPINNING..." : (currentTurnSpins === 0 ? "SPIN 1" : "SPIN 2")
                    
                    // Logic tự động: Chỉ cần khai báo ở đây, KHÔNG can thiệp thủ công
                    enabled: parent.isMyTurn && !spinning && backend !== null && currentTurnSpins < 2
                    
                    background: Rectangle {
                        radius: 12
                        color: {
                            if (!parent.enabled) return "#9E9E9E"
                            if (parent.hovered) return "#388E3C"
                            return "#4CAF50"
                        }
                        border.color: parent.enabled ? "#2E7D32" : "#757575"
                        border.width: 3
                        
                        // Shine effect
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: 9
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.3) }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.1) }
                            }
                        }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 16
                        font.bold: true
                        color: parent.enabled ? "white" : "#E0E0E0"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    scale: hovered && enabled ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }
                    
                    onClicked: {
                        if (spinning) return
                        console.log("Sending SPIN request...")
                        backend.sendRoundAnswer("SPIN")
                    }
                }

                Button {
                    id: passBtn
                    text: "⏭️ PASS"
                    width: 120
                    height: 50
                    
                    enabled: parent.isMyTurn && !spinning && backend !== null && currentTurnSpins >= 1
                    
                    background: Rectangle {
                        radius: 12
                        color: {
                            if (!parent.enabled) return "#9E9E9E"
                            if (parent.hovered) return "#F57C00"
                            return "#FF9800"
                        }
                        border.color: parent.enabled ? "#E65100" : "#757575"
                        border.width: 3
                        
                        // Shine effect
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: 9
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.3) }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.1) }
                            }
                        }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 16
                        font.bold: true
                        color: parent.enabled ? "white" : "#E0E0E0"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    scale: hovered && enabled ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }
                    
                    onClicked: {
                        console.log("Sending PASS request...")
                        backend.sendRoundAnswer("PASS")
                    }
                }
            }

            Text {
                id: infoText
                text: {
                    if (playersModel.count > currentPlayerIndex) {
                        var curr = playersModel.get(currentPlayerIndex).name
                        if (curr === myUserName) return "Lượt của BẠN! Hãy quay số."
                        return "Đến lượt: " + curr
                    }
                    return "Waiting..."
                }
                anchors.horizontalCenter: parent.horizontalCenter
                color: (infoText.text.indexOf("BẠN") !== -1) ? "#D32F2F" : "#043B56"
                font.pixelSize: 16
                font.bold: true
            }
        }
    }

    Rectangle {
        id: footerBar
        height: 80
        anchors.bottom: parent.bottom
        width: parent.width
        z: 10
        color: "transparent"
        
        // Leave button
        Rectangle {
            anchors.centerIn: parent
            width: 120
            height: 45
            radius: 8
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#DC2626" }
                GradientStop { position: 1.0; color: "#991B1B" }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (backend) {
                        console.log("Leaving room from Round 3");
                        spinning = false;
                        shuffleTimer.stop();
                        round3ResultTimer.stop();
                        backend.leaveRoom();
                        // Không replace ngay, chờ onLeaveRoomSuccess signal
                    }
                }
            }
            
            Text {
                anchors.centerIn: parent
                text: "LEAVE"
                font.pixelSize: 16
                font.bold: true
                color: "#FFFFFF"
            }
        }
    }
    
    // Round 3 Result Popup
    Popup {
        id: round3ResultPopup
        x: (parent.width - 500) / 2
        y: (parent.height - 350) / 2
        width: 500
        height: 350
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose

        onClosed: {
            console.log("Round3 popup closed");
            if (finalRankings && !finalRankingPushed) {
                console.log("Pushing RankingPage after popup closed");
                
                // Tạo bản copy an toàn của finalRankings
                var rankingsCopy = [];
                try {
                    if (Array.isArray(finalRankings)) {
                        for (var i = 0; i < finalRankings.length; i++) {
                            rankingsCopy.push(finalRankings[i]);
                        }
                    }
                } catch (e) {
                    console.error("Error copying finalRankings:", e);
                    rankingsCopy = [];
                }
                
                stackView.replace("qrc:/qml/RankingPage.qml", {
                    backend: backend,
                    rankings: rankingsCopy,
                    roundNumber: 3,
                    isFinalRanking: true
                });
                finalRankingPushed = true;
            } else if (!finalRankings) {
                console.warn("Popup closed but final rankings not yet available; will push when GAME_END arrives");
            }
        }
        
        background: Rectangle {
            color: "#1F2937"
            radius: 15
            border.color: "#FFD700"
            border.width: 3
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            // Title
            Text {
                text: "*** VÒNG 3 KẾT THÚC ***"
                font.pixelSize: 28
                font.bold: true
                color: "#FFD700"
                Layout.alignment: Qt.AlignHCenter
                style: Text.Outline
                styleColor: "#0B5E8A"
            }
            
            // Results list
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                
                ListView {
                    anchors.fill: parent
                    spacing: 10
                    clip: true
                    
                    model: round3Results || []
                    
                    delegate: Rectangle {
                        width: parent.width
                        height: 50
                        radius: 8
                        color: "#374151"
                        border.color: "#4B5563"
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 15
                            
                            Text {
                                text: modelData.user || modelData.username || "Unknown"
                                font.pixelSize: 16
                                font.bold: true
                                color: "white"
                                Layout.fillWidth: true
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 40
                                radius: 20
                                color: "#10B981"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData.score || 0) + " pts"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "white"
                                }
                            }
                        }
                    }
                }
            }
            
            // Message
            Text {
                text: "Dữ liệu tổng được tải..."
                font.pixelSize: 12
                color: "#9CA3AF"
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
    
    Popup {
        id: eliminationPopup
        property string popMessage: ""
        x: (parent.width - 360)/2
        y: (parent.height-200)/2
        width: 360
        height: 200
        modal: true
        focus: true
        
        background: Rectangle {
            radius: 12
            color: "#ffffff"
            border.color: "#DD3333"
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            anchors.horizontalCenter: parent.horizontalCenter
            
            Text {
                text: eliminationPopup.popMessage
                wrapMode: Text.WordWrap
                font.pixelSize: 16
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
            
            Button {
                text: "OK"
                onClicked: eliminationPopup.close()
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Component.onCompleted: {
        if (backend) {
            var infoStr = backend.getRoomInfo()
            if (infoStr !== "") {
                try {
                    var info = JSON.parse(infoStr)
                    var members = info.members.split('|')
                    playersModel.clear()
                    for (var i = 0; i < members.length; i++) {
                        playersModel.append({ name: members[i], score: 0, eliminated: false })
                    }
                } catch(e) {}
            } else { setupDummyPlayers() }
        } else { setupDummyPlayers() }

        if (spinnerViewport) {
            spinnerOffset = - ((cycles) * numbers.length) * itemHeight + (spinnerViewport.height/2 - itemHeight/2)
            spinnerInitialized = true
        }

        if (numbers.length > 0) {
            displayedNumber = numbers[0]
        }
    }

    Component.onDestruction: {
        console.log("Room3 being destroyed - stopping all timers");
        round3ResultTimer.stop();
        shuffleTimer.stop();
        spinning = false;
    }

    function setupDummyPlayers() {
        playersModel.clear()
        var me = myUserName ? myUserName : "You"
        playersModel.append({ name: me, score: 0, eliminated: false })
        playersModel.append({ name: "Player 1", score: 0, eliminated: false })
        currentPlayerIndex = 0
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