import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: round1Room
    width: 800
    height: 600
    
    property var backend: null
    property int currentRoundId: 0
    property string currentQuestion: ""
    property string optionA: ""
    property string optionB: ""
    property string optionC: ""
    property string optionD: ""
    property int timeRemaining: 15  // 15s for answering
    property bool answered: false
    property string selectedAnswer: ""
    property var playerScores: []
    property string correctAnswer: ""
    property bool showResult: false
    property bool isResetting: false  // Flag to prevent multiple updates during reset
    
    // Button colors - stored as properties to prevent re-evaluation
    property string colorA_top: "#3B82F6"
    property string colorA_bottom: "#2563EB"
    property string colorB_top: "#3B82F6"
    property string colorB_bottom: "#2563EB"
    property string colorC_top: "#3B82F6"
    property string colorC_bottom: "#2563EB"
    property string colorD_top: "#3B82F6"
    property string colorD_bottom: "#2563EB"
    
    // Function to update button colors
    function updateButtonColors() {
        console.log("=== UPDATE COLORS ===");
        console.log("selectedAnswer:", selectedAnswer);
        console.log("showResult:", showResult);
        console.log("correctAnswer:", correctAnswer);
        
        // Reset all to blue first
        colorA_top = "#3B82F6";
        colorA_bottom = "#2563EB";
        colorB_top = "#3B82F6";
        colorB_bottom = "#2563EB";
        colorC_top = "#3B82F6";
        colorC_bottom = "#2563EB";
        colorD_top = "#3B82F6";
        colorD_bottom = "#2563EB";
        
        // If nothing selected, keep all blue
        if (selectedAnswer === "") {
            console.log("No answer selected, all blue");
            return;
        }
        
        // Determine colors for selected answer
        var topColor, bottomColor;
        
        if (!showResult) {
            // Yellow when selected
            topColor = "#FBBF24";
            bottomColor = "#F59E0B";
            console.log("Selected but no result yet -> YELLOW");
        } else {
            // Check if correct
            if (correctAnswer === selectedAnswer) {
                // Green when correct
                topColor = "#10B981";
                bottomColor = "#059669";
                console.log("Selected and CORRECT -> GREEN");
            } else {
                // Red when wrong
                topColor = "#DC2626";
                bottomColor = "#991B1B";
                console.log("Selected and WRONG -> RED");
            }
        }
        
        // Apply color to selected button only
        if (selectedAnswer === "A") {
            colorA_top = topColor;
            colorA_bottom = bottomColor;
            console.log("Applied color to button A");
        } else if (selectedAnswer === "B") {
            colorB_top = topColor;
            colorB_bottom = bottomColor;
            console.log("Applied color to button B");
        } else if (selectedAnswer === "C") {
            colorC_top = topColor;
            colorC_bottom = bottomColor;
            console.log("Applied color to button C");
        } else if (selectedAnswer === "D") {
            colorD_top = topColor;
            colorD_bottom = bottomColor;
            console.log("Applied color to button D");
        }
        console.log("===================");
    }
    
    // Watch for changes
    onSelectedAnswerChanged: {
        if (isResetting) return;  // Skip during reset
        console.log("selectedAnswer changed to:", selectedAnswer);
        updateButtonColors();
    }
    onShowResultChanged: {
        if (isResetting) return;  // Skip during reset
        console.log("showResult changed to:", showResult);
        if (showResult) {
            // Only update when result is shown, not when it's hidden
            updateButtonColors();
        }
    }
    onCorrectAnswerChanged: {
        if (isResetting) return;  // Skip during reset
        console.log("correctAnswer changed to:", correctAnswer);
        if (showResult) {
            // Only update if we're showing results
            updateButtonColors();
        }
    }
    
    Component.onCompleted: {
        console.log("Round1Room loaded, backend:", backend);
        if (backend) {
            backend.questionStart.connect(handleQuestionStart);
            backend.questionResult.connect(handleQuestionResult);
            backend.roundStart.connect(handleRoundStart);
            backend.gameEnd.connect(handleGameEnd);
            console.log("Round1Room signals connected");
        } else {
            console.error("Backend is null!");
        }
    }
    
    function handleGameEnd(rankingData) {
        console.log("Game ended, showing ranking:", rankingData);
        try {
            var data = JSON.parse(rankingData);
            stackView.push("qrc:/qml/RankingPage.qml", { 
                backend: backend,
                rankings: data.players,
                roundNumber: 1  // Round 1 ranking
            });
        } catch (e) {
            console.error("Failed to parse ranking data:", e);
        }
    }
    
    // Handler để chuyển sang Round 2 khi nhận ROUND_START từ server
    function handleRoundStart(roundId, roundType, prodName, prodDesc, threshold, timeLimit) {
        console.log("=== ROUND_START received - Switching to Round2Room ===");
        console.log("Round:", roundId, "Type:", roundType);
        console.log("Product:", prodName);
        
        // Chuyển sang Round2Room
        stackView.push("qrc:/qml/Round2Room.qml", {
            backend: backend
        });
    }
    
    function handleQuestionStart(roundId, question, optA, optB, optC, optD) {
        console.log("=== Question received ===");
        console.log("Round:", roundId);
        console.log("Question:", question);
        console.log("Option A:", optA);
        console.log("Option B:", optB);
        console.log("Option C:", optC);
        console.log("Option D:", optD);
        
        // Stop timer first
        countdownTimer.running = false;
        
        // Set resetting flag to prevent multiple color updates
        isResetting = true;
        
        // Reset all states in correct order to prevent UI jumping
        answered = false;
        showResult = false;
        correctAnswer = "";
        selectedAnswer = "";
        playerScores = [];
        
        // Clear resetting flag
        isResetting = false;
        
        // Now manually reset colors once
        updateButtonColors();
        
        // Assign new question data
        currentRoundId = roundId;
        currentQuestion = question;
        round1Room.optionA = optA;
        round1Room.optionB = optB;
        round1Room.optionC = optC;
        round1Room.optionD = optD;
        timeRemaining = 15;  // Reset to 15s
        
        console.log("After assignment - optionA:", round1Room.optionA);
        console.log("After assignment - optionC:", round1Room.optionC);
        
        // Start countdown timer after everything is set
        countdownTimer.running = true;
    }
    
    function handleQuestionResult(resultData) {
        console.log("Result received:", resultData);
        try {
            var result = JSON.parse(resultData);
            
            // Stop timer
            countdownTimer.running = false;
            
            // Set resetting flag to batch updates
            isResetting = true;
            
            // Update result data
            correctAnswer = result.correct;
            playerScores = result.players;
            showResult = true;
            
            // Clear flag
            isResetting = false;
            
            // Now update colors once with correct data
            console.log("Result applied - correct:", correctAnswer, "selected:", selectedAnswer);
            updateButtonColors();
            
        } catch (e) {
            console.error("Failed to parse result:", e);
        }
    }
    
    function submitAnswer(answer) {
        if (answered || showResult) return;
        
        console.log("Submitting answer:", answer, "for round:", currentRoundId);
        selectedAnswer = answer;
        answered = true;
        
        if (backend) {
            backend.submitAnswer(currentRoundId, answer);
        }
    }
    
    Timer {
        id: countdownTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: {
            if (timeRemaining > 0) {
                timeRemaining--;
                console.log("Time remaining:", timeRemaining);
            } else {
                running = false;
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
                        text: "ROUND 1 - MULTIPLE CHOICE"
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
        
        // Answer Options (2x2 grid)
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
                    GradientStop { 
                        position: 0.0
                        color: colorA_top
                    }
                    GradientStop { 
                        position: 1.0
                        color: colorA_bottom
                    }
                }
                
                border.color: selectedAnswer === "A" ? "#FFD93D" : "white"
                border.width: selectedAnswer === "A" ? 5 : 4
                
                // Visual effects
                scale: mouseAreaA.containsMouse && mouseAreaA.enabled ? 1.05 : 1.0
                opacity: (!mouseAreaA.enabled && !showResult) ? 0.6 : 1.0
                
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
                
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    // A badge
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
                    
                    // Option text
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
                
                MouseArea {
                    id: mouseAreaA
                    anchors.fill: parent
                    enabled: !answered && !showResult && currentQuestion !== ""
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true
                    onClicked: submitAnswer("A")
                }
            }
            
            // Option B
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                radius: 15
                
                gradient: Gradient {
                    GradientStop { 
                        position: 0.0
                        color: colorB_top
                    }
                    GradientStop { 
                        position: 1.0
                        color: colorB_bottom
                    }
                }
                
                border.color: selectedAnswer === "B" ? "#FFD93D" : "white"
                border.width: selectedAnswer === "B" ? 5 : 4
                
                // Visual effects
                scale: mouseAreaB.containsMouse && mouseAreaB.enabled ? 1.05 : 1.0
                opacity: (!mouseAreaB.enabled && !showResult) ? 0.6 : 1.0
                
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
                
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    // B badge
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
                    
                    // Option text
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
                
                MouseArea {
                    id: mouseAreaB
                    anchors.fill: parent
                    enabled: !answered && !showResult && currentQuestion !== ""
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true
                    onClicked: submitAnswer("B")
                }
            }
            
            // Option C
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                radius: 15
                
                gradient: Gradient {
                    GradientStop { 
                        position: 0.0
                        color: colorC_top
                    }
                    GradientStop { 
                        position: 1.0
                        color: colorC_bottom
                    }
                }
                
                border.color: selectedAnswer === "C" ? "#FFD93D" : "white"
                border.width: selectedAnswer === "C" ? 5 : 4
                
                // Visual effects
                scale: mouseAreaC.containsMouse && mouseAreaC.enabled ? 1.05 : 1.0
                opacity: (!mouseAreaC.enabled && !showResult) ? 0.6 : 1.0
                
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
                
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    // C badge
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
                    
                    // Option text
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
                
                MouseArea {
                    id: mouseAreaC
                    anchors.fill: parent
                    enabled: !answered && !showResult && currentQuestion !== ""
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true
                    onClicked: submitAnswer("C")
                }
            }
            
            // Option D
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                radius: 15
                
                gradient: Gradient {
                    GradientStop { 
                        position: 0.0
                        color: colorD_top
                    }
                    GradientStop { 
                        position: 1.0
                        color: colorD_bottom
                    }
                }
                
                border.color: selectedAnswer === "D" ? "#FFD93D" : "white"
                border.width: selectedAnswer === "D" ? 5 : 4
                
                // Visual effects
                scale: mouseAreaD.containsMouse && mouseAreaD.enabled ? 1.05 : 1.0
                opacity: (!mouseAreaD.enabled && !showResult) ? 0.6 : 1.0
                
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
                
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    // D badge
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
                    
                    // Option text
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
                
                MouseArea {
                    id: mouseAreaD
                    anchors.fill: parent
                    enabled: !answered && !showResult && currentQuestion !== ""
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true
                    onClicked: submitAnswer("D")
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
                                        text: modelData.username
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
                            backend.leaveRoom();
                        }
                    }
                }
            }
        }
    }
}
