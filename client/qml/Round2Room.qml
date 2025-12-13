import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: round2Room
    width: 800
    height: 600
    
    property var backend: null
    property int round2Id: 0
    property string productName: ""
    property string productDesc: ""
    property int thresholdPct: 10
    property int timeLimit: 20
    property int timeRemaining: 20
    property int guessedPrice: 0
    property bool priceSubmitted: false
    property int actualPrice: 0
    property bool showResult: false
    property var playerScores: []
    
    // Nhận parameters từ navigation
    property int roundId: 0
    property string roundType: ""
    property string prodName: ""
    property string prodDesc: ""
    property int threshold: 10
    property int timeLimit_: 20
    
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
            countdownTimer.running = true;
        }
        
        if (backend) {
            backend.roundStart.connect(handleRoundStart);
            backend.roundResult.connect(handleRoundResult);
            backend.gameEnd.connect(handleGameEnd);
            console.log("Round2Room signals connected");
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
                rankings: data.players 
            });
        } catch (e) {
            console.error("Failed to parse ranking data:", e);
        }
    }
    
    function handleRoundStart(roundId, roundType, prodName, prodDesc, threshold, timeLimit_) {
        console.log("=== Round 2 Start ===");
        console.log("Round:", roundId, "Type:", roundType);
        console.log("Product:", prodName, "-", prodDesc);
        console.log("Threshold:", threshold, "% Time:", timeLimit_, "s");
        
        // Stop timer
        countdownTimer.running = false;
        
        // Update Round 2 data
        round2Id = roundId;
        productName = prodName;
        productDesc = prodDesc;
        thresholdPct = threshold;
        timeLimit = timeLimit_;
        timeRemaining = timeLimit_;
        
        // Reset state
        guessedPrice = 0;
        priceSubmitted = false;
        showResult = false;
        actualPrice = 0;
        playerScores = [];
        
        // Start timer
        countdownTimer.running = true;
    }
    
    function handleRoundResult(resultData) {
        console.log("Round 2 Result received:", resultData);
        try {
            var result = JSON.parse(resultData);
            
            // Stop timer
            countdownTimer.running = false;
            
            // Update result data
            actualPrice = result.actual_price;
            playerScores = result.players;
            showResult = true;
            
        } catch (e) {
            console.error("Failed to parse round result:", e);
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
    
    Timer {
        id: countdownTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: {
            if (timeRemaining > 0) {
                timeRemaining--;
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
        
        // Product Display
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: 20
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#7C3AED" }
                GradientStop { position: 1.0; color: "#A78BFA" }
            }
            
            border.color: "#FCD34D"
            border.width: 4
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                z: 10
                
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 30
                    radius: 15
                    color: "#FCD34D"
                    Layout.alignment: Qt.AlignHCenter
                    z: 10
                    
                    Text {
                        anchors.centerIn: parent
                        text: "ĐOÁN GIÁ SẢN PHẨM"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#7C3AED"
                        z: 11
                    }
                }
                
                Text {
                    Layout.fillWidth: true
                    text: productName || "Đang tải..."
                    font.pixelSize: 32
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    style: Text.Outline
                    styleColor: "#7C3AED"
                    z: 10
                }
                
                Text {
                    Layout.fillWidth: true
                    text: productDesc || "..."
                    font.pixelSize: 18
                    font.bold: true
                    color: "#FCD34D"
                    horizontalAlignment: Text.AlignHCenter
                    style: Text.Outline
                    styleColor: "#7C3AED"
                    z: 10
                }
                
                Text {
                    Layout.fillWidth: true
                    text: "Lệch không quá ±" + thresholdPct + "%"
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    style: Text.Outline
                    styleColor: "#6D28D9"
                    z: 10
                }
            }
        }
        
        // Price Input
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 20
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#7C3AED" }
                GradientStop { position: 1.0; color: "#A78BFA" }
            }
            
            border.color: priceSubmitted ? "#10B981" : "#FCD34D"
            border.width: 4
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20
                
                Text {
                    text: "Nhập giá dự đoán"
                    font.pixelSize: 24
                    font.bold: true
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Rectangle {
                    Layout.preferredWidth: 400
                    Layout.preferredHeight: 80
                    radius: 15
                    color: "white"
                    border.color: "#7C3AED"
                    border.width: 3
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        
                        TextField {
                            id: priceInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: ""
                            placeholderText: "Nhập giá (VND)..."
                            font.pixelSize: 32
                            font.bold: true
                            color: "#7C3AED"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            enabled: !priceSubmitted && !showResult
                            
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
                            
                            background: Rectangle {
                                color: "transparent"
                                border.width: 0
                            }
                        }
                        
                        Text {
                            text: "đ"
                            font.pixelSize: 24
                            font.bold: true
                            color: "#7C3AED"
                        }
                    }
                }
                
                Button {
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 60
                    enabled: !priceSubmitted && !showResult && guessedPrice > 0
                    
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? "#6D28D9" : "#7C3AED") : "#9CA3AF"
                        radius: 15
                        border.color: "#FCD34D"
                        border.width: 3
                    }
                    
                    contentItem: Text {
                        text: priceSubmitted ? "✓ ĐÃ GỬI" : "GỬI DỰ ĐOÁN"
                        font.pixelSize: 20
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: submitPriceGuess()
                }
                
                Text {
                    text: priceSubmitted ? "Đang chờ kết quả..." : ""
                    font.pixelSize: 16
                    font.italic: true
                    color: "#FCD34D"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
        
        // Result and Leaderboard
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "#1F2937"
            radius: 10
            border.color: showResult ? "#10B981" : "#6B7280"
            border.width: 2
            opacity: showResult ? 1.0 : 0.0
            
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                
                // Actual Price Display
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#7C3AED"
                    radius: 8
                    border.color: "#FCD34D"
                    border.width: 3
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 15
                        
                        Text {
                            text: "GIÁ THỰC:"
                            font.pixelSize: 16
                            font.bold: true
                            color: "white"
                        }
                        
                        Text {
                            text: actualPrice.toLocaleString(Qt.locale(), 'f', 0) + " đ"
                            font.pixelSize: 24
                            font.bold: true
                            color: "#FCD34D"
                        }
                        
                        Text {
                            text: "(±" + thresholdPct + "%)"
                            font.pixelSize: 14
                            color: "#E0E7FF"
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
                                Layout.preferredWidth: 120
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
                                    }
                                    
                                    Text {
                                        text: "Dự đoán: " + modelData.guessed_price.toLocaleString(Qt.locale(), 'f', 0)
                                        font.pixelSize: 9
                                        color: "#E5E7EB"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
