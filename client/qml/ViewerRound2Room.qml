import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: viewerRound2Room
    width: 800
    height: 600
    
    property var backend: null
    property string roomCode: ""
    property string initialState: "QUESTION"  // Can be "QUESTION" or "RESULT"
    property int round2Id: 0
    property string productName: ""
    property string productDesc: ""
    property string productImage: ""
    property int thresholdPct: 10
    property int timeRemaining: 20
    property int actualPrice: 0
    property bool showResult: false
    property var playerScores: []
    property bool justJoinedDuringResult: false  // Flag to track if viewer joined during result phase
    property string pendingRankingData: ""  // Store ranking data during delay
    
    // Timer để hiển thị result trước khi chuyển ranking (giống player)
    Timer {
        id: resultDisplayTimer
        interval: 3000  // 3 giây hiển thị kết quả
        repeat: false
        onTriggered: {
            console.log("[VIEWER R2] Result display timeout, showing ranking");
            rankingDelayTimer.start();
        }
    }
    
    // Timer để delay nhỏ trước khi push ranking
    Timer {
        id: rankingDelayTimer
        interval: 500  // 0.5 giây delay (giống player)
        repeat: false
        onTriggered: {
            console.log("[VIEWER R2] Timer expired, navigating to ranking");
            showRankingPage();
        }
    }
    
    function showRankingPage() {
        console.log("[VIEWER R2] showRankingPage called");
        var players = [];
        
        // Try to use pendingRankingData first, otherwise use current playerScores
        if (pendingRankingData) {
            try {
                var data = JSON.parse(pendingRankingData);
                players = data.players || [];
                console.log("[VIEWER R2] Using pending ranking data with", players.length, "players");
            } catch (e) {
                console.error("[VIEWER R2] Failed to parse pending ranking data:", e);
                players = playerScores;
            }
        } else {
            players = playerScores;
            console.log("[VIEWER R2] Using current playerScores with", players.length, "players");
        }
        
        // Sort and add rank
        var sortedPlayers = players.slice().sort(function(a, b) {
            return (b.total_score || b.score || 0) - (a.total_score || a.score || 0);
        });
        for (var i = 0; i < sortedPlayers.length; i++) {
            sortedPlayers[i].rank = i + 1;
        }
        
        stackView.replace("qrc:/qml/RankingPage.qml", { 
            backend: backend,
            rankings: sortedPlayers,
            roundNumber: 2,
            isViewer: true,
            roomCode: roomCode
        });
    }
    
    Component.onCompleted: {
        console.log("ViewerRound2Room loaded for room:", roomCode);
        console.log("[VIEWER R2] initialState:", initialState);
        console.log("[VIEWER R2] showResult:", showResult);
        console.log("[VIEWER R2] actualPrice:", actualPrice);
        console.log("[VIEWER R2] timeRemaining:", timeRemaining);
        
        // If viewer joined during result phase, start timer to show ranking
        if (initialState === "RESULT" && showResult) {
            justJoinedDuringResult = true;
            console.log("[VIEWER R2] Joined during RESULT phase, starting timer");
            resultDisplayTimer.start();  // Start 3 second timer to match player experience
        } else if (initialState === "QUESTION" && timeRemaining > 0) {
            // If viewer joined during active question/product display, start countdown
            console.log("[VIEWER R2] Joined during QUESTION phase, starting countdown with", timeRemaining, "seconds");
            if (backend) {
                backend.startCountdown(timeRemaining);
            }
        }
    }
    
    Connections {
        target: backend
        enabled: viewerRound2Room.StackView.status === StackView.Active
        
        function onRoundStart(roundId, roundType, prodName, prodDesc, threshold, timeLimit_, imageUrl) {
            console.log("[VIEWER R2] ROUND_START received - Round:", roundId, "Type:", roundType);
            
            // This should be Round 2 start
            console.log("[VIEWER R2] Round 2 started:", prodName);
            round2Id = roundId;
            productName = prodName;
            productDesc = prodDesc;
            productImage = imageUrl || "";
            thresholdPct = threshold;
            timeRemaining = timeLimit_;
            showResult = false;
            actualPrice = 0;
            playerScores = [];
            
            // Start countdown timer
            if (backend && timeLimit_ > 0) {
                backend.startCountdown(timeLimit_);
                console.log("[VIEWER R2] Started countdown with", timeLimit_, "seconds");
            }
        }
        
        function onRoundResult(resultData) {
            console.log("[VIEWER R2] Round 2 result received:", resultData);
            try {
                var result = JSON.parse(resultData);
                if (result.actual_price !== undefined) {
                    actualPrice = result.actual_price;
                    playerScores = result.players || [];
                    showResult = true;
                    
                    // Reset flag since we're now seeing result in real-time
                    justJoinedDuringResult = false;
                    console.log("[VIEWER R2] Result displayed, starting timer");
                    
                    // Start timer to show ranking after 3 seconds (match player)
                    resultDisplayTimer.start();
                }
            } catch (e) {
                console.error("[VIEWER R2] Failed to parse result:", e);
            }
        }
        
        function onGameEnd(rankingData) {
            console.log("[VIEWER R2] GAME_END received (final ranking after all rounds)");
            console.log("[VIEWER R2] Ranking data:", rankingData);
            
            // This is final ranking after Round 3, not Round 2 ranking
            // Stop timers and navigate to final ranking
            resultDisplayTimer.stop();
            rankingDelayTimer.stop();
            
            try {
                var data = JSON.parse(rankingData);
                var players = data.players || [];
                console.log("[VIEWER R2] Final ranking, players count:", players.length);
                
                // Sort and add rank
                var sortedPlayers = players.slice().sort(function(a, b) {
                    return (b.total_score || 0) - (a.total_score || 0);
                });
                for (var i = 0; i < sortedPlayers.length; i++) {
                    sortedPlayers[i].rank = i + 1;
                }
                
                console.log("[VIEWER R2] Switching to final RankingPage");
                stackView.replace("qrc:/qml/RankingPage.qml", { 
                    backend: backend,
                    rankings: sortedPlayers,
                    roundNumber: 3,
                    isFinalRanking: true,
                    isViewer: true,
                    roomCode: roomCode
                });
            } catch (e) {
                console.error("[VIEWER R2] Failed to parse GAME_END:", e);
            }
        }
        
        function onTimerTick(secondsRemaining) {
            timeRemaining = secondsRemaining;
        }
        
        function onViewerStateUpdate(data) {
            console.log("[VIEWER] State update:", data);
            try {
                var state = JSON.parse(data);
                
                // Update product info if available
                if (state.product_name) {
                    productName = state.product_name;
                }
                if (state.product_desc) {
                    productDesc = state.product_desc;
                }
                if (state.product_image) {
                    productImage = state.product_image;
                }
                if (state.threshold !== undefined) {
                    thresholdPct = state.threshold;
                }
                if (state.time_remaining !== undefined) {
                    timeRemaining = state.time_remaining;
                }
                if (state.actual_price !== undefined) {
                    actualPrice = state.actual_price;
                    showResult = true;
                }
                if (state.scores) {
                    playerScores = state.scores;
                }
            } catch (e) {
                console.error("[VIEWER] Failed to parse viewer state:", e);
            }
        }
        
        function onLeaveRoomSuccess() {
            console.log("[VIEWER] Left room");
            stackView.replace("qrc:/qml/HomeUser.qml", {backend: backend});
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
                        text: "ROUND 2 - VIEWER MODE"
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
        
        // Price Input Display (Disabled for Viewer)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 165
            radius: 20
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#6366F1" }
                GradientStop { position: 1.0; color: "#8B5CF6" }
            }
            
            border.color: "#FCD34D"
            border.width: 4
            opacity: 0.6
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 15
                
                Text {
                    text: "👁️ VIEWER MODE 👁️"
                    font.pixelSize: 28
                    font.bold: true
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                    style: Text.Outline
                    styleColor: "#4C1D95"
                }
                
                Text {
                    text: "You are watching this round.\nYou cannot submit a price guess."
                    font.pixelSize: 16
                    color: "#FCD34D"
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        
        // Result and Leaderboard
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
                            backend.leaveViewer();
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
        
        function onRoomClosed(message) {
            console.log("[VIEWER R2] Room closed:", message);
            stackView.replace("qrc:/qml/HomeUser.qml", {backend: backend});
        }
    }
}
