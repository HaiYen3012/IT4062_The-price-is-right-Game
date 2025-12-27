import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: viewerRound1Room
    width: 800
    height: 600
    
    property var backend: null
    property string roomCode: ""
    property string syncData: ""  // Sync data from server
    property string initialState: "QUESTION"  // Can be "QUESTION" or "RESULT"
    property int currentRoundId: 0
    property string currentQuestion: ""
    property string optionA: ""
    property string optionB: ""
    property string optionC: ""
    property string optionD: ""
    property int timeRemaining: 15
    property var playerScores: []
    property string correctAnswer: ""
    property bool showResult: false
    property bool justJoinedDuringResult: false  // Flag to track if viewer joined during result phase
    
    // Timer to delay transition to ranking (to match player experience)
    Timer {
        id: rankingDelayTimer
        interval: 5000  // 5 seconds delay before showing ranking
        repeat: false
        onTriggered: {
            console.log("[VIEWER] Timer expired, navigating to ranking");
            showRankingPage();
        }
    }
    
    function showRankingPage() {
        if (pendingRankingData) {
            try {
                var data = JSON.parse(pendingRankingData);
                var players = data.players || [];
                
                // Thêm rank vào dữ liệu
                var sortedPlayers = players.slice().sort(function(a, b) {
                    return (b.total_score || 0) - (a.total_score || 0);
                });
                for (var i = 0; i < sortedPlayers.length; i++) {
                    sortedPlayers[i].rank = i + 1;
                }
                
                // Chuyển sang RankingPage (viewer mode)
                stackView.replace("qrc:/qml/RankingPage.qml", { 
                    backend: backend,
                    rankings: sortedPlayers,
                    roundNumber: 1,
                    isViewer: true,
                    roomCode: roomCode
                });
            } catch (e) {
                console.error("[VIEWER] Failed to parse ranking data:", e);
            }
        }
    }
    
    property string pendingRankingData: ""
    
    Component.onCompleted: {
        console.log("ViewerRound1Room loaded for room:", roomCode);
        console.log("[VIEWER] syncData type:", typeof syncData, "value:", syncData);
        console.log("[VIEWER] syncData length:", syncData ? syncData.length : 0);
        console.log("[VIEWER] initialState:", initialState);
        
        // Process sync data if available
        if (syncData && syncData !== "" && syncData.length > 0) {
            console.log("[VIEWER] Processing sync data:", syncData);
            try {
                var data = JSON.parse(syncData);
                var state = data.state || "";
                console.log("[VIEWER] Parsed data, state:", state, "question_id:", data.question_id);
                
                // Set initial display based on state
                if (state === "RESULT" || initialState === "RESULT") {
                    // Viewer joined during result phase
                    console.log("[VIEWER] Showing result immediately");
                    // Set question data first
                    currentQuestion = data.question || "";
                    optionA = data.optionA || "";
                    optionB = data.optionB || "";
                    optionC = data.optionC || "";
                    optionD = data.optionD || "";
                    // Then set result
                    correctAnswer = data.correct_answer || "";
                    playerScores = data.players || [];
                    showResult = true;
                    justJoinedDuringResult = true;  // Mark that we joined during result
                    console.log("[VIEWER] Question:", currentQuestion);
                    console.log("[VIEWER] Correct answer:", correctAnswer);
                    // Don't show question first, show result directly
                } else if (data.question_id) {
                    // Viewer joined during question phase
                    console.log("[VIEWER] Showing question");
                    currentRoundId = data.round_id || 0;
                    currentQuestion = data.question || "";
                    optionA = data.optionA || "";
                    optionB = data.optionB || "";
                    optionC = data.optionC || "";
                    optionD = data.optionD || "";
                    
                    // Use time_remaining if available, otherwise use time_limit
                    var timeToUse = data.time_remaining !== undefined ? data.time_remaining : (data.time_limit || 15);
                    timeRemaining = timeToUse;
                    playerScores = data.players || [];
                    showResult = false;
                    
                    console.log("[VIEWER] Synced question:", currentQuestion);
                    console.log("[VIEWER] Options:", optionA, optionB, optionC, optionD);
                    console.log("[VIEWER] Time remaining:", timeToUse, "seconds");
                    
                    // Start countdown with remaining time
                    if (backend && timeToUse > 0) {
                        backend.startCountdown(timeToUse);
                        console.log("[VIEWER] Started countdown with", timeToUse, "seconds");
                    }
                } else {
                    console.warn("[VIEWER] No question_id or state in sync data");
                }
            } catch (e) {
                console.error("[VIEWER] Failed to parse sync data:", e);
            }
        } else {
            console.log("[VIEWER] No sync data available, waiting for signals");
        }
    }
    
    Connections {
        target: backend
        enabled: viewerRound1Room.StackView.status === StackView.Active
        
        function onQuestionStart(roundId, question, optA, optB, optC, optD) {
            console.log("[VIEWER] Question received:", question);
            currentRoundId = roundId;
            currentQuestion = question;
            optionA = optA;
            optionB = optB;
            optionC = optC;
            optionD = optD;
            timeRemaining = 15;
            showResult = false;
            correctAnswer = "";
            playerScores = [];
            
            // Start countdown timer
            if (backend) {
                backend.startCountdown(15);
                console.log("[VIEWER] Started countdown for new question");
            }
        }
        function onQuestionResult(resultData) {
            console.log("[VIEWER] Result received:", resultData);
            try {
                var result = JSON.parse(resultData);
                correctAnswer = result.correct;
                playerScores = result.players;
                showResult = true;
                justJoinedDuringResult = false;  // Reset flag since we're now in sync
            } catch (e) {
                console.error("[VIEWER] Failed to parse result:", e);
            }
        }
        
        function onGameEnd(rankingData) {
            console.log("[VIEWER] GAME_END received");
            pendingRankingData = rankingData;
            
            // If viewer just joined during result phase, they haven't seen the result long enough
            // so we need to delay the transition to ranking to match player experience
            if (justJoinedDuringResult && showResult) {
                console.log("[VIEWER] Delaying ranking transition to allow viewing result");
                rankingDelayTimer.start();
            } else {
                // Normal case: viewer was present from the start or during question
                // They already saw the result for 8 seconds like players, so show ranking immediately
                console.log("[VIEWER] Showing ranking immediately");
                showRankingPage();
            }
        }
        
        function onTimerTick(secondsRemaining) {
            timeRemaining = secondsRemaining;
        }
        
        function onViewerStateUpdate(data) {
            console.log("[VIEWER] State update:", data);
            try {
                var state = JSON.parse(data);
                
                // Update question if available
                if (state.question) {
                    currentQuestion = state.question;
                }
                if (state.options) {
                    optionA = state.options.A || "";
                    optionB = state.options.B || "";
                    optionC = state.options.C || "";
                    optionD = state.options.D || "";
                }
                if (state.time_remaining !== undefined) {
                    timeRemaining = state.time_remaining;
                }
                if (state.correct_answer) {
                    correctAnswer = state.correct_answer;
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
        anchors.margins: 20
        spacing: 15
        z: 1
        
        // Header: Logo and Timer
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            spacing: 20
            
            Item { Layout.fillWidth: true }
            
            // The Price is Right Logo
            Rectangle {
                Layout.preferredWidth: 400
                Layout.preferredHeight: 80
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
                        font.family: "Arial Black"
                        style: Text.Outline
                        styleColor: "#C92A2A"
                    }
                    
                    Text {
                        text: "ROUND 1 - VIEWER MODE"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#FFD93D"
                        Layout.alignment: Qt.AlignHCenter
                        font.family: "Arial"
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
                Layout.preferredWidth: 100
                Layout.preferredHeight: 100
                radius: 50
                color: timeRemaining <= 5 ? "#FF4757" : "#6C5CE7"
                border.color: "white"
                border.width: 5
                
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
                        font.pixelSize: 48
                        font.bold: true
                        color: "white"
                        Layout.alignment: Qt.AlignHCenter
                        font.family: "Arial Black"
                    }
                    
                    Text {
                        text: "SEC"
                        font.pixelSize: 12
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
        
        // Question Display
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: 20
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1E3A8A" }
                GradientStop { position: 1.0; color: "#3B82F6" }
            }
            
            border.color: "#FCD34D"
            border.width: 4
            
            // Sparkle effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 16
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.3)
                border.width: 2
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 30
                    radius: 15
                    color: "#FCD34D"
                    Layout.alignment: Qt.AlignHCenter
                    
                    Text {
                        anchors.centerIn: parent
                        text: "QUESTION"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#1E3A8A"
                        font.family: "Arial Black"
                    }
                }
                
                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: currentQuestion || "Waiting for question..."
                    font.pixelSize: 20
                    font.bold: true
                    color: "white"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: "Arial"
                }
            }
        }
        
        // Answer Options (2x2 grid) - VIEWER MODE: No interaction
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 15
            columnSpacing: 15
            
            // Option A
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 15
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3B82F6" }
                    GradientStop { position: 1.0; color: "#2563EB" }
                }
                
                border.color: "white"
                border.width: 4
                opacity: 0.7
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        color: "#991B1B"
                        radius: 25
                        border.color: "#FCD34D"
                        border.width: 2
                        
                        Text {
                            anchors.centerIn: parent
                            text: "A"
                            font.pixelSize: 32
                            font.bold: true
                            color: "white"
                            font.family: "Arial Black"
                        }
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: optionA || "..."
                        font.pixelSize: 14
                        font.bold: true
                        color: "white"
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            
            // Option B
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 15
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3B82F6" }
                    GradientStop { position: 1.0; color: "#2563EB" }
                }
                
                border.color: "white"
                border.width: 4
                opacity: 0.7
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        color: "#1E40AF"
                        radius: 25
                        border.color: "#FCD34D"
                        border.width: 2
                        
                        Text {
                            anchors.centerIn: parent
                            text: "B"
                            font.pixelSize: 32
                            font.bold: true
                            color: "white"
                            font.family: "Arial Black"
                        }
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: optionB || "..."
                        font.pixelSize: 14
                        font.bold: true
                        color: "white"
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            
            // Option C
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 15
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3B82F6" }
                    GradientStop { position: 1.0; color: "#2563EB" }
                }
                
                border.color: "white"
                border.width: 4
                opacity: 0.7
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        color: "#D97706"
                        radius: 25
                        border.color: "#1F2937"
                        border.width: 2
                        
                        Text {
                            anchors.centerIn: parent
                            text: "C"
                            font.pixelSize: 32
                            font.bold: true
                            color: "white"
                            font.family: "Arial Black"
                        }
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: optionC || "..."
                        font.pixelSize: 14
                        font.bold: true
                        color: "white"
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            
            // Option D
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 15
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3B82F6" }
                    GradientStop { position: 1.0; color: "#2563EB" }
                }
                
                border.color: "white"
                border.width: 4
                opacity: 0.7
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        color: "#047857"
                        radius: 25
                        border.color: "#FCD34D"
                        border.width: 2
                        
                        Text {
                            anchors.centerIn: parent
                            text: "D"
                            font.pixelSize: 32
                            font.bold: true
                            color: "white"
                            font.family: "Arial Black"
                        }
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: optionD || "..."
                        font.pixelSize: 14
                        font.bold: true
                        color: "white"
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
        
        // Bottom: Result and Leaderboard
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
                
                // Correct Answer Badge
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.fillHeight: true
                    color: "#10B981"
                    radius: 8
                    border.color: "#059669"
                    border.width: 3
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        
                        Text {
                            text: "✓ CORRECT ANSWER"
                            font.pixelSize: 12
                            font.bold: true
                            color: "white"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 60
                            radius: 30
                            color: "white"
                            border.color: "#059669"
                            border.width: 3
                            Layout.alignment: Qt.AlignHCenter
                            
                            Text {
                                anchors.centerIn: parent
                                text: correctAnswer
                                font.pixelSize: 36
                                font.bold: true
                                color: "#10B981"
                                font.family: "Arial Black"
                            }
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
                                        text: modelData.username || modelData.name || ""
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "white"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Text {
                                        text: (modelData.total_score || modelData.score || 0) + " pts"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "white"
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: "Arial Black"
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
            console.log("[VIEWER R1] Room closed:", message);
            stackView.replace("qrc:/qml/HomeUser.qml", {backend: backend});
        }
    }
}
