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
    property int shuffleTick: 0
    property int shuffleMax: 25
    
    property string myUserName: backend ? backend.user_name : ""
    property bool isViewerMode: false  // For viewers watching the game
    property var initialPlayers: []  // For viewer mode - initial players from sync
    
    // Biến đếm lượt quay (0, 1, 2)
    property int currentTurnSpins: 0 
    
    property var currentServerResult: null 
    property string pendingNextUser: ""
    
    // Round 3 result display
    property var round3Results: null  // Store ROUND3_END data
    property var finalRankings: null  // Store final rankings from GAME_END
    property var matchData: null      // Store full match data for MatchSummaryPage (round1, round2, round3 details)
    property bool finalRankingPushed: false  // Prevent double navigation
    
    // Pending ROUND3_END handling (wait for animation to complete)
    property bool pendingRound3End: false
    property var pendingRound3Results: null
    
    // Sync flags for shuffle and wheel animation completion
    property bool shuffleComplete: false
    property bool wheelComplete: false

    property var numbers: [5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,100]
    property real wheelRotation: 0
    property int targetValue: 5
    property string displayedNumber: "005"

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
    
    // Timer for delay display before showing ROUND3_END popup (let user see final result)
    // Bắt đầu ngay khi nhận ROUND3_END để đồng bộ giữa các clients
    Timer {
        id: absoluteDelayTimer
        interval: 6000  // Default 6 giây
        running: false
        onTriggered: {
            // Nếu animation vẫn đang chạy, đợi thêm 500ms rồi thử lại
            if (spinning) {
                console.log("Popup timer triggered but animation still running, waiting 500ms more...");
                absoluteDelayTimer.interval = 500;
                absoluteDelayTimer.start();
                return;
            }
            
            if (pendingRound3Results) {
                console.log("Displaying ROUND3_END popup after delay (synced across clients)");
                round3Results = pendingRound3Results.details || [];
                round3ResultPopup.open();
                round3ResultTimer.start();
                
                // Reset pending
                pendingRound3End = false;
                pendingRound3Results = null;
            }
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
                displayedNumber = String(targetValue).padStart(3, "0")
                running = false
                shuffleComplete = true  // Set flag
                console.log("Shuffle complete, wheelComplete=", wheelComplete);
                
                // Check nếu cả hai complete
                if (shuffleComplete && wheelComplete) {
                    endCurrentTurn();
                }
                return
            }
            displayedNumber = String(numbers[Math.floor(Math.random() * numbers.length)]).padStart(3, "0")
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
                    
                    // Luôn lưu pending và start timer ngay lập tức
                    // Timer start cùng lúc ở tất cả clients (vì nhận message broadcast cùng lúc)
                    pendingRound3End = true;
                    pendingRound3Results = res;
                    
                    // Tính delay để đồng bộ popup giữa các clients
                    var delayMs = 6000;  // Default: 6s (3s animation + 3s xem kết quả)
                    
                    // Nếu BE gửi 'timestamp' (server time in ms), tính remaining delay chính xác hơn
                    if (res.timestamp && typeof res.timestamp === 'number') {
                        var currentTime = Date.now();
                        var serverTimestamp = res.timestamp;
                        var elapsed = currentTime - serverTimestamp;
                        var remaining = 6000 - elapsed;
                        
                        // Clamp: không âm và không quá 6s
                        if (remaining < 0) remaining = 0;
                        if (remaining > 6000) remaining = 6000;
                        
                        delayMs = remaining;
                        console.log("Using server timestamp sync: elapsed=", elapsed, "ms, remaining=", remaining, "ms");
                    } else {
                        console.log("No server timestamp, using fixed 6s delay");
                    }
                    
                    console.log("Starting absolute delay timer (" + delayMs + "ms) for synced popup across all clients");
                    absoluteDelayTimer.interval = delayMs;
                    absoluteDelayTimer.start();
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
                var finalRankings = players;
                
                // Store final rankings for timer callback
                room3.finalRankings = finalRankings;
                
                // Store full match data including round1, round2, round3 details for MatchSummaryPage
                room3.matchData = data;
                console.log("Stored matchData with round details:", 
                    "round1:", data.round1 ? "yes" : "no",
                    "round2:", data.round2 ? "yes" : "no", 
                    "round3:", data.round3 ? "yes" : "no");
                
                // Store final rankings for timer callback
                room3.finalRankings = finalRankings;
                
                // Nếu đang hiện Popup kết quả vòng 3 HOẶC đang quay bánh xe HOẶC timer đang chạy
                // -> Không chuyển trang ngay, để cho các process đó hoàn tất
                if (round3ResultPopup.visible || round3ResultTimer.running || spinning) {
                    console.log("GAME_END received while popup/spinning/timer active -> will navigate after completion");
                    // Đảm bảo timer đang chạy để sau khi popup đóng sẽ chuyển trang
                    if (!round3ResultTimer.running) {
                        round3ResultTimer.start();
                    }
                } else {
                    // Chỉ chuyển trang ngay nếu mọi thứ đã xong xuôi
                    if (!finalRankingPushed) {
                        console.log("GAME_END received after all processes done -> replacing to RankingPage now");
                        stackView.replace("qrc:/qml/RankingPage.qml", {
                            backend: backend,
                            rankings: finalRankings,
                            matchData: room3.matchData,
                            roundNumber: 3,
                            isFinalRanking: true,
                            isViewer: isViewerMode
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
        targetValue = val
        
        // Tính góc quay đến giá trị mục tiêu
        var targetIdx = numbers.indexOf(val)
        if (targetIdx === -1) targetIdx = 0
        
        // Mỗi ô chiếm 360/20 = 18 độ
        var anglePerItem = 360.0 / numbers.length
        
        // Normalize góc hiện tại về khoảng [0, 360)
        var currentNormalized = ((wheelRotation % 360) + 360) % 360
        
        // Góc đích để segment targetIdx ở vị trí con trỏ (phía trên)
        var targetNormalized = (360 - (targetIdx * anglePerItem)) % 360
        
        // Tính độ lệch từ vị trí hiện tại đến vị trí đích
        var deltaAngle = targetNormalized - currentNormalized
        
        // Đảm bảo quay theo hướng ngắn nhất nhưng luôn quay ít nhất 3 vòng
        if (deltaAngle > 0) {
            deltaAngle = deltaAngle - 360
        }
        
        // Quay thêm 3-5 vòng đầy đủ
        var extraRotations = 3 + Math.floor(Math.random() * 3)
        var totalRotation = -extraRotations * 360 + deltaAngle

        // Cập nhật lượt quay từ server
        currentTurnSpins = res.spins_count;
        console.log("handleSpinResult: currentRotation=" + wheelRotation + ", targetIdx=" + targetIdx + ", totalRotation=" + totalRotation);

        // Reset completion flags trước khi start animation
        shuffleComplete = false;
        wheelComplete = false;
        
        // Hiệu ứng xáo số trong ô đỏ
        shuffleTick = 0
        spinning = true
        
        // Animation quay vòng
        wheelAnimation.from = wheelRotation
        wheelAnimation.to = wheelRotation + totalRotation
        wheelAnimation.start()
        
        shuffleTimer.start()
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
        
        // Không cần start timer ở đây nữa - absoluteDelayTimer đã start ngay khi nhận ROUND3_END
        // để đồng bộ popup giữa tất cả clients
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

            // Vòng xoay tròn
            Item {
                id: wheelContainer
                width: 280
                height: 280
                anchors.horizontalCenter: parent.horizontalCenter
                
                // Con trỏ cố định ở trên
                Canvas {
                    id: pointerCanvas
                    width: 30
                    height: 30
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: -5
                    z: 100
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.fillStyle = "#FF5252"
                        ctx.beginPath()
                        ctx.moveTo(15, 28)
                        ctx.lineTo(0, 0)
                        ctx.lineTo(30, 0)
                        ctx.closePath()
                        ctx.fill()
                    }
                }
                
                // Vòng xoay
                Item {
                    id: wheel
                    width: parent.width
                    height: parent.height
                    anchors.centerIn: parent
                    rotation: wheelRotation
                    
                    // Animation quay
                    NumberAnimation {
                        id: wheelAnimation
                        target: wheel
                        property: "rotation"
                        duration: 3000
                        easing.type: Easing.OutCubic
                        onStopped: {
                            wheelRotation = wheel.rotation % 360
                            wheelComplete = true  // Set flag
                            console.log("Wheel animation complete, shuffleComplete=", shuffleComplete);
                            
                            // Check nếu cả hai complete
                            if (shuffleComplete && wheelComplete) {
                                endCurrentTurn();
                            }
                        }
                    }
                    
                    // Vòng tròn nền
                    Rectangle {
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: "#ffffff"
                        border.color: "#0B5E8A"
                        border.width: 4
                    }
                    
                    // Các ô số trên vòng tròn
                    Repeater {
                        model: numbers.length
                        delegate: Item {
                            id: segment
                            width: wheel.width
                            height: wheel.height
                            rotation: index * (360 / numbers.length)
                            
                            property int segmentValue: numbers[index]
                            
                            Canvas {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                
                                onPaint: {
                                    var ctx = getContext("2d")
                                    var centerX = width / 2
                                    var centerY = height / 2
                                    var radius = width / 2 - 4
                                    var anglePerSegment = 2 * Math.PI / numbers.length
                                    var startAngle = -Math.PI / 2
                                    var endAngle = startAngle + anglePerSegment
                                    
                                    // Màu xen kẽ đậm hơn
                                    ctx.fillStyle = index % 2 === 0 ? "#81D4FA" : "#4FC3F7"
                                    
                                    ctx.beginPath()
                                    ctx.moveTo(centerX, centerY)
                                    ctx.arc(centerX, centerY, radius, startAngle, endAngle)
                                    ctx.closePath()
                                    ctx.fill()
                                    
                                    // Viền rõ hơn
                                    ctx.strokeStyle = "#0277BD"
                                    ctx.lineWidth = 2
                                    ctx.stroke()
                                }
                            }
                            
                            // Số trên mỗi ô - đặt gần viền ngoài hơn
                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -parent.height * 0.35
                                text: segment.segmentValue
                                font.pixelSize: 18
                                font.bold: true
                                color: "#FFFFFF"
                                rotation: -segment.rotation - wheel.rotation
                                style: Text.Outline
                                styleColor: "#0277BD"
                            }
                        }
                    }
                    
                    // Tâm vòng xoay
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: "#FF9800"
                        border.color: "#F57C00"
                        border.width: 3
                        anchors.centerIn: parent
                        
                        Text {
                            anchors.centerIn: parent
                            text: "🎯"
                            font.pixelSize: 20
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
                    text: spinning ? "..." : (currentTurnSpins === 0 ? "SPIN 1" : "SPIN 2")
                    
                    // Logic tự động: Chỉ cần khai báo ở đây, KHÔNG can thiệp thủ công
                    // Disable buttons in viewer mode
                    enabled: !isViewerMode && parent.isMyTurn && !spinning && backend !== null && currentTurnSpins < 2
                    visible: !isViewerMode  // Hide button for viewers
                    
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
                    text: "PASS"
                    width: 120
                    height: 50
                    
                    enabled: !isViewerMode && parent.isMyTurn && !spinning && backend !== null && currentTurnSpins >= 1
                    visible: !isViewerMode  // Hide button for viewers
                    
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
                    if (isViewerMode) {
                        return "🎬 VIEWER MODE - Đang xem ván đấu"
                    }
                    if (playersModel.count > currentPlayerIndex) {
                        var curr = playersModel.get(currentPlayerIndex).name
                        if (curr === myUserName) return "Lượt của BẠN! Hãy quay số."
                        return "Đến lượt: " + curr
                    }
                    return "Waiting..."
                }
                anchors.horizontalCenter: parent.horizontalCenter
                color: {
                    if (isViewerMode) return "#9333EA"
                    if (infoText.text.indexOf("BẠN") !== -1) return "#D32F2F"
                    return "#043B56"
                }
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
                    matchData: room3.matchData,
                    roundNumber: 3,
                    isFinalRanking: true,
                    isViewer: isViewerMode
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
        console.log("[Round3] Component loaded, isViewerMode:", isViewerMode);
        
        // For viewer mode, use initialPlayers if provided
        if (isViewerMode && initialPlayers && initialPlayers.length > 0) {
            console.log("[Round3] Initializing viewer mode with players:", JSON.stringify(initialPlayers));
            playersModel.clear();
            for (var i = 0; i < initialPlayers.length; i++) {
                var player = initialPlayers[i];
                playersModel.append({ 
                    name: player.username || "", 
                    score: player.total_score || 0,
                    eliminated: false 
                });
                console.log("[Round3] Added player:", player.username, "score:", player.total_score);
            }
        }
        // For player mode, use room info
        else if (backend) {
            var infoStr = backend.getRoomInfo()
            if (infoStr !== "") {
                try {
                    var info = JSON.parse(infoStr)
                    var members = info.members.split('|')
                    playersModel.clear()
                    for (var j = 0; j < members.length; j++) {
                        playersModel.append({ name: members[j], score: 0, eliminated: false })
                    }
                } catch(e) {
                    console.error("[Round3] Failed to parse room info:", e);
                }
            } else { 
                setupDummyPlayers() 
            }
        } else { 
            setupDummyPlayers() 
        }

        // Khởi tạo giá trị hiển thị
        if (numbers.length > 0) {
            displayedNumber = String(numbers[0]).padStart(3, "0")
            targetValue = numbers[0]
        }
        
        wheelRotation = 0
    }

    Component.onDestruction: {
        console.log("Room3 being destroyed - stopping all timers");
        round3ResultTimer.stop();
        shuffleTimer.stop();
        absoluteDelayTimer.stop();
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
        
        function onRoomClosed(message) {
            console.log("[Round3] Room closed:", message);
            if (isViewerMode) {
                stackView.replace("qrc:/qml/HomeUser.qml", {backend: backend});
            }
        }
    }
}