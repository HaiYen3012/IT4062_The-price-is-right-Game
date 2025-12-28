import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: round2Room
    width: 800
    height: 600
    
    property var backend: null
    property var stackView: StackView.view  // Use attached property as default
    property int round2Id: 0
    property string productName: ""
    property string productDesc: ""
    property string productImage: ""
    property int thresholdPct: 10
    property int timeLimit: 20
    property int timeRemaining: 20
    property int guessedPrice: 0
    property bool priceSubmitted: false
    property int actualPrice: 0
    property bool showResult: false
    property var playerScores: []
    property bool round2Started: false  // Track xem round 2 đã bắt đầu hay chưa
    property bool isNavigatingAway: false  // Flag để ngăn xử lý messages sau khi navigate
    
    // Nhận parameters từ navigation
    property int roundId: 0
    property string roundType: ""
    property string prodName: ""
    property string prodDesc: ""
    property int threshold: 10
    property int timeLimit_: 20
    
    // Timer để delay push RankingPage
    Timer {
        id: rankingDelayTimer
        interval: 500
        running: false
        onTriggered: {
            // Thêm rank vào playerScores trước khi push
            var rankedPlayers = [];
            if (playerScores && playerScores.length > 0) {
                // Sort by score descending
                var sortedPlayers = playerScores.slice().sort(function(a, b) {
                    return (b.score || 0) - (a.score || 0);
                });
                // Thêm rank
                for (var i = 0; i < sortedPlayers.length; i++) {
                    sortedPlayers[i].rank = i + 1;
                }
                rankedPlayers = sortedPlayers;
            }
            
            console.log("Ranked players (after delay):", JSON.stringify(rankedPlayers));
            
            // Replace to RankingPage - clear navigation history
            stackView.replace("qrc:/qml/RankingPage.qml", {
                backend: backend,
                rankings: rankedPlayers,
                roundNumber: 2
            });
        }
    }
    
    // Timer để tự động chuyển sang ranking sau khi hiển thị kết quả
    Timer {
        id: resultDisplayTimer
        interval: 3000  // Hiển thị kết quả 3 giây rồi push RankingPage
        running: false
        onTriggered: {
            console.log("Round2Room: Result display timeout - pushing to RankingPage");
            rankingDelayTimer.running = true;
        }
    }
    
    Component.onCompleted: {
        console.log("Round2Room loaded, backend:", backend);
        console.log("Navigation params - roundId:", roundId, "prodName:", prodName, "prodDesc:", prodDesc);
        
        // Nếu có parameters từ navigation, sử dụng ngay
        if (roundId > 0 && prodName.length > 0) {
            console.log("Using navigation parameters");
            round2Id = roundId;
            productName = prodName;
            productDesc = prodDesc;
            thresholdPct = threshold;
            timeLimit = timeLimit_;
            timeRemaining = timeLimit_;
            priceSubmitted = false;
            showResult = false;
            if (backend) {
                backend.startCountdown(timeLimit_);
            }
        }
        
        if (!backend) {
            console.error("Backend is null!");
        }
    }
    
    Component.onDestruction: {
        // Stop timer when page is destroyed
        if (backend) {
            backend.stopCountdown();
            console.log("Round2Room destroyed, timer stopped");
        }
    }
    
    function handleGameEnd(rankingData) {
        // Guard: Nếu đang navigate away, bỏ qua
        if (isNavigatingAway) {
            console.log("Round2Room: Ignoring GAME_END because navigating away");
            return;
        }
        
        console.log("=== GAME END received in Round2Room ===" );
        console.log("Ranking data:", rankingData);
        try {
            var data = JSON.parse(rankingData);
            console.log("Parsed ranking data, players count:", data.players ? data.players.length : 0);
            
            // Tắt timer
            if (backend) {
                backend.stopCountdown();
            }
            
            // Replace (không push) sang RankingPage final với tổng điểm cả 3 vòng
            stackView.replace("qrc:/qml/RankingPage.qml", { 
                backend: backend,
                rankings: data.players || [],
                roundNumber: 3,
                isFinalRanking: true
            });
        } catch (e) {
            console.error("Round2Room - Failed to parse GAME_END data:", e);
        }
    }
    
    function handleRoundStart(roundId, roundType, prodName, prodDesc, threshold, timeLimit_, imageUrl) {
        console.log("=== handleRoundStart called ===");
        console.log("Round:", roundId, "Type:", roundType);
        console.log("round2Started:", round2Started);
        
        // Nếu Round 2 chưa bắt đầu -> khởi động Round 2
        if (!round2Started) {
            console.log("=== Round 2 Start ===");
            console.log("Product:", prodName, "-", prodDesc);
            console.log("Threshold:", threshold, "% Time:", timeLimit_, "s");
            
            // Stop timer
            if (backend) {
                backend.stopCountdown();
            }
            
            // Update Round 2 data
            round2Id = roundId;
            productName = prodName;
            productDesc = prodDesc;
            productImage = imageUrl || "";
            thresholdPct = threshold;
            timeLimit = timeLimit_;
            timeRemaining = timeLimit_;
            round2Started = true;
            
            // Reset state
            guessedPrice = 0;
            priceSubmitted = false;
            showResult = false;
            actualPrice = 0;
            playerScores = [];
            
            // Start timer
            if (backend) {
                backend.startCountdown(timeLimit_);
            }
        } else {
            // Round 2 đã bắt đầu -> này là ROUND_START cho round tiếp theo (Round 3)
            console.log("=== ROUND_START Round 3 received - Navigating to Room3 ===");
            console.log("Round 3 type:", roundType);
            if (backend) {
                backend.stopCountdown();
            }
            resultDisplayTimer.running = false;
            rankingDelayTimer.running = false;
            
            // Set flag để ngăn xử lý thêm messages
            isNavigatingAway = true;
            
            // Disconnect signals trước khi navigate để tránh nhận messages cho Round 3
            if (backend) {
                try {
                    backend.roundStart.disconnect(handleRoundStart);
                    backend.roundResult.disconnect(handleRoundResult);
                    backend.gameEnd.disconnect(handleGameEnd);
                    console.log("Round2Room signals disconnected before navigating to Room3");
                } catch (e) {
                    console.log("Error disconnecting signals:", e);
                }
            }
            
            // Chuyển sang Room3
            stackView.replace("qrc:/qml/Round3Room.qml", { 
                backend: backend
            });
        }
    }
    
    function handleRoundResult(resultData) {
        // Guard: Nếu đang navigate away, bỏ qua tất cả messages
        if (isNavigatingAway) {
            console.log("Round2Room: Ignoring message because navigating away");
            return;
        }
        
        try {
            var result = JSON.parse(resultData);
            
            // CỬA BẢO VỆ: Nếu tin nhắn không phải của Round 2 (không có actual_price) thì bỏ qua
            if (result.actual_price === undefined) {
                console.log("Round2Room: Nhận nhầm dữ liệu của Round khác, bỏ qua.");
                return;
            }

            actualPrice = result.actual_price;
            playerScores = result.players || [];
            showResult = true;
            if (backend) {
                backend.stopCountdown();
            }
            console.log("Round2Room - Kết quả hiển thị: giá thực:", actualPrice, "điểm người chơi:", playerScores.length);
            
            // Chỉ stringify nếu playerScores hợp lệ
            if (playerScores && playerScores.length > 0) {
                try {
                    console.log("Round2Room - playerScores data:", JSON.stringify(playerScores));
                } catch (e) {
                    console.log("Round2Room - Could not stringify playerScores:", e);
                }
            }
            
            // Start timer to show result for 3 seconds, then push to ranking
            resultDisplayTimer.running = true;
        } catch (e) {
            console.error("Round2Room - Lỗi parse kết quả:", e);
        }
    }
    
    function submitPriceGuess() {
        if (priceSubmitted || showResult || guessedPrice <= 0) return;
        
        console.log("Submitting price guess:", guessedPrice, "for round:", round2Id);
        priceSubmitted = true;
        
        if (backend) {
            backend.submitPrice(round2Id, guessedPrice);
        }
    }
    
    // Use Connections instead of .connect() to prevent accumulation
    Connections {
        target: backend
        enabled: round2Room.StackView.status === StackView.Active && !isNavigatingAway
        
        function onRoundStart(roundId, roundType, prodName, prodDesc, threshold, timeLimit_, imageUrl) {
            handleRoundStart(roundId, roundType, prodName, prodDesc, threshold, timeLimit_, imageUrl);
        }
        
        function onRoundResult(resultData) {
            handleRoundResult(resultData);
        }
        
        function onGameEnd(rankingData) {
            handleGameEnd(rankingData);
        }
        
        function onTimerTick(secondsRemaining) {
            timeRemaining = secondsRemaining;
        }
        
        function onLeaveRoomSuccess() {
            console.log("Round2Room - Leave room successful, returning to home");
            if (backend) {
                backend.stopCountdown();
            }
            resultDisplayTimer.stop();
            rankingDelayTimer.stop();
            stackView.replace("qrc:/qml/HomeUser.qml", {backend: backend});
        }
        
        function onUpdateRoomState(data) {
            console.log("Round2Room - onUpdateRoomState:", data);
            try {
                var info = JSON.parse(data);
                if (info.members) {
                    var memberNames = info.members.split('|');
                    console.log("Updated members count:", memberNames.length);
                    
                    // Nếu không còn ai, quay về trang chủ
                    if (memberNames.length === 0) {
                        console.log("All players left, returning to home");
                        if (backend) backend.stopCountdown();
                        resultDisplayTimer.stop();
                        rankingDelayTimer.stop();
                        stackView.replace("qrc:/qml/HomeUser.qml", {backend: backend});
                    }
                }
            } catch (e) {
                console.error("Round2Room - Failed to parse UPDATE_ROOM_STATE:", e);
            }
        }
    }
    
    // Background - vibrant game show style
    Rectangle {
        anchors.fill: parent
        
        // Animated gradient background
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#667EEA" }
            GradientStop { position: 0.5; color: "#764BA2" }
            GradientStop { position: 1.0; color: "#F093FB" }
        }
        
        // Animated circles decoration
        Repeater {
            model: 5
            Rectangle {
                width: 150 + index * 50
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 2
                x: parent.width / 2 - width / 2
                y: parent.height / 2 - height / 2
                
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    NumberAnimation { 
                        from: 1.0
                        to: 1.2
                        duration: 2000 + index * 400
                        easing.type: Easing.InOutQuad 
                    }
                    NumberAnimation { 
                        from: 1.2
                        to: 1.0
                        duration: 2000 + index * 400
                        easing.type: Easing.InOutQuad 
                    }
                }
                
                opacity: 0.3 - index * 0.05
            }
        }
    }
    
    // Main layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 8
        z: 1
        
        // Header: Logo and Timer
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            spacing: 20
            
            Item { Layout.fillWidth: true }
            
            // The Price is Right Logo
            Rectangle {
                Layout.preferredWidth: 400
                Layout.preferredHeight: 70
                radius: 15
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#FF6B6B" }
                    GradientStop { position: 1.0; color: "#EE5A6F" }
                }
                
                border.color: "#FFD93D"
                border.width: 4
                
                // Shine effect
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 11
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.2) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                    }
                }
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    
                    Text {
                        text: "THE PRICE IS RIGHT"
                        font.pixelSize: 24
                        font.bold: true
                        color: "white"
                        Layout.alignment: Qt.AlignHCenter
                        style: Text.Outline
                        styleColor: "#C92A2A"
                    }
                    
                    Text {
                        text: "ROUND 2 - PRICE GUESSING"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#FFD93D"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
                
                // Pulse animation
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.03; duration: 1000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.03; to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Timer Circle
            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80
                radius: 40
                color: timeRemaining <= 5 ? "#FF4757" : "#6C5CE7"
                border.color: "white"
                border.width: 4
                
                // Shadow effect
                layer.enabled: true
                layer.effect: ShaderEffect {
                    fragmentShader: "
                        uniform lowp sampler2D source;
                        varying highp vec2 qt_TexCoord0;
                        void main() {
                            gl_FragColor = texture2D(source, qt_TexCoord0) * 1.2;
                        }
                    "
                }
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    
                    Text {
                        text: timeRemaining
                        font.pixelSize: 40
                        font.bold: true
                        color: "white"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    Text {
                        text: "SEC"
                        font.pixelSize: 10
                        font.bold: true
                        color: "white"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
                
                // Urgent pulse when time is low
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: timeRemaining <= 5
                    NumberAnimation { from: 1.0; to: 1.15; duration: 300 }
                    NumberAnimation { from: 1.15; to: 1.0; duration: 300 }
                }
            }
        }
        
        // Product Display
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            radius: 20
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#7C3AED" }
                GradientStop { position: 1.0; color: "#A78BFA" }
            }
            
            border.color: "#FCD34D"
            border.width: 4
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15
                
                // Product Image
                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.fillHeight: true
                    radius: 12
                    color: "white"
                    border.color: "#FCD34D"
                    border.width: 3
                    
                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: productImage || ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                        
                        onStatusChanged: {
                            console.log("Image status:", status, "URL:", productImage)
                        }
                        
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            visible: parent.status === Image.Loading
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Loading..."
                                color: "#7C3AED"
                                font.pixelSize: 20
                                font.bold: true
                            }
                        }
                        
                        Rectangle {
                            anchors.fill: parent
                            color: "#f5f5f5"
                            visible: parent.status === Image.Error || productImage === ""
                            
                            Text {
                                anchors.centerIn: parent
                                text: "No Image"
                                font.pixelSize: 24
                                color: "#999"
                                font.bold: true
                            }
                        }
                    }
                }
                
                // Product Info
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 5
                    
                    Rectangle {
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 30
                        radius: 15
                        color: "#FCD34D"
                        Layout.alignment: Qt.AlignHCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: "GUESS THE PRICE"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#7C3AED"
                        }
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: productName || "Loading..."
                        font.pixelSize: 26
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        style: Text.Outline
                        styleColor: "#7C3AED"
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: productDesc || "..."
                        font.pixelSize: 13
                        color: "#FCD34D"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: "Within ±" + thresholdPct + "%"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#E0E7FF"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
        
        // Price Input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 165
            radius: 20
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#6366F1" }
                GradientStop { position: 1.0; color: "#8B5CF6" }
            }
            
            border.color: priceSubmitted ? "#10B981" : "#FCD34D"
            border.width: 4
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "Enter Your Price Guess"
                    font.pixelSize: 22
                    font.bold: true
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                    style: Text.Outline
                    styleColor: "#4C1D95"
                }
                
                Rectangle {
                    Layout.preferredWidth: 420
                    Layout.preferredHeight: 65
                    radius: 16
                    color: "white"
                    border.color: priceInput.activeFocus ? "#10B981" : "#7C3AED"
                    border.width: 3
                    Layout.alignment: Qt.AlignHCenter
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5
                        
                        TextField {
                            id: priceInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: ""
                            placeholderText: "Enter price (VND)..."
                            font.pixelSize: 28
                            font.bold: true
                            color: "#7C3AED"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            enabled: !priceSubmitted && !showResult
                            leftPadding: 5
                            rightPadding: 5
                            topPadding: 0
                            bottomPadding: 0
                            
                            validator: IntValidator {
                                bottom: 0
                                top: 999999999
                            }
                            
                            onTextChanged: {
                                console.log("TextField text changed:", text);
                                if (text.length > 0) {
                                    guessedPrice = parseInt(text);
                                    console.log("Guessed price:", guessedPrice);
                                } else {
                                    guessedPrice = 0;
                                }
                            }
                            
                            background: Item {}
                            
                            // Placeholder text style
                            placeholderTextColor: "#C4B5FD"
                        }
                        
                        Text {
                            text: "đ"
                            font.pixelSize: 24
                            font.bold: true
                            color: "#7C3AED"
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                
                Button {
                    Layout.preferredWidth: 250
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignHCenter
                    enabled: !priceSubmitted && !showResult && guessedPrice > 0
                    
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? "#6D28D9" : "#7C3AED") : "#9CA3AF"
                        radius: 16
                        border.color: "#FCD34D"
                        border.width: 3
                    }
                    
                    contentItem: Text {
                        text: priceSubmitted ? "✓ SUBMITTED" : "SUBMIT GUESS"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: submitPriceGuess()
                    
                    scale: hovered && enabled ? 1.05 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 150 }
                    }
                }
                
                Text {
                    text: priceSubmitted ? "⏳ Waiting for other players..." : ""
                    font.pixelSize: 13
                    font.italic: true
                    color: "#FCD34D"
                    Layout.alignment: Qt.AlignHCenter
                    visible: priceSubmitted && !showResult
                    
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: priceSubmitted && !showResult
                        NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                    }
                }
            }
        }
        
        // Result and Leaderboard (Footer giống Room 1)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#1F2937"
            radius: 10
            border.color: showResult ? "#10B981" : "#6B7280"
            border.width: 2
            opacity: showResult ? 1.0 : 0.0
            
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                
                // Actual Price Display
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true
                    color: "#10B981"
                    radius: 8
                    border.color: "#059669"
                    border.width: 3
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        
                        Text {
                            text: "ACTUAL PRICE"
                            font.pixelSize: 11
                            font.bold: true
                            color: "white"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Text {
                            text: actualPrice.toLocaleString(Qt.locale(), 'f', 0) + " đ"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#FCD34D"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Text {
                            text: "(±" + thresholdPct + "%)"
                            font.pixelSize: 10
                            color: "#D1FAE5"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
                
                // Leaderboard
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#374151"
                    radius: 8
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 5
                        
                        Text {
                            text: "SCORES:"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#FCD34D"
                        }
                        
                        Repeater {
                            model: playerScores
                            
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.fillHeight: true
                                color: modelData.is_correct ? "#10B981" : "#6B7280"
                                radius: 5
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    
                                    Text {
                                        text: modelData.is_correct ? "✓ " + modelData.username : modelData.username
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "white"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Text {
                                        text: modelData.score + " pts"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "white"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Text {
                                        text: modelData.guessed_price ? modelData.guessed_price.toLocaleString(Qt.locale(), 'f', 0) : "0"
                                        font.pixelSize: 9
                                        color: "#E5E7EB"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Leave button
                Button {
                    Layout.preferredWidth: 80
                    Layout.fillHeight: true
                    text: "LEAVE"
                    
                    background: Rectangle {
                        color: "#DC2626"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 12
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        if (backend) {
                            backend.leaveRoom();
                        }
                    }
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
