import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: rankingPage
    width: 800
    height: 600
    
    property var backend: null
    property var rankings: []
    property var matchData: null  // Full match data with round details for replay
    property int roundNumber: 1  // Round number (1, 2, 3, ...)
    property bool isFinalRanking: false  // True only for Round 3 total ranking
    property bool isViewer: false  // True if viewer mode
    property string roomCode: ""  // Room code for viewer

    // Prevent multiple navigations when auto-returning to waiting room
    property bool navigatedBack: false

    Timer {
        id: finalReturnTimer
        interval: 5000  // 5 giây để xem ranking rồi chuyển sang MatchSummaryPage
        running: isFinalRanking
        repeat: false
        onTriggered: {
            if (isViewer) {
                leaveRoomAndReturnHome();  // Viewer về trang chủ
            } else {
                navigateToMatchSummary();  // Player đi tới trang tổng kết ván đấu
            }
        }
    }
    
    onRankingsChanged: {
        console.log("RankingPage: rankings changed, now has", rankings.length, "players");
        console.log("RankingPage: Updated rankings:", JSON.stringify(rankings));
    }
    
    Component.onCompleted: {
        console.log("=== RankingPage onCompleted ===");
        console.log("RankingPage loaded with", rankings.length, "players, after Round", roundNumber);
        console.log("Rankings data:", JSON.stringify(rankings));
        console.log("Viewer mode:", isViewer);
        
        // Kết nối signal để tự động chuyển sang Round tiếp theo khi server gửi ROUND_START
        if (backend) {
            backend.roundStart.connect(handleRoundStart);
            backend.gameStarted.connect(handleGameStartNotify);
            console.log("RankingPage: Connected to roundStart and gameStarted signals");
        }

        if (isFinalRanking) {
            console.log("RankingPage: Final ranking received, will return to waiting room");
            finalReturnTimer.start();
        } else {
            if (!backend) console.error("RankingPage: Backend is null!");
        }
    }
    
    Component.onDestruction: {
        // Ngắt kết nối khi thoát để tránh duplicate connections
        if (backend) {
            backend.roundStart.disconnect(handleRoundStart);
            backend.gameStarted.disconnect(handleGameStartNotify);
        }
    }
    
    // Handler để chuyển sang Round 2 khi nhận ROUND_START từ server
    function handleRoundStart(roundId, roundType, prodName, prodDesc, threshold, timeLimit, imageUrl) {
        console.log("=== RankingPage: ROUND_START received - Switching to Round2 ===");
        console.log("Round:", roundId, "Type:", roundType);
        console.log("Product:", prodName, "Desc:", prodDesc);
        console.log("Threshold:", threshold, "% Time:", timeLimit, "s");
        console.log("Image URL:", imageUrl);
        console.log("Viewer mode:", isViewer);
        
        if (isViewer) {
            // Viewer: Chuyển sang ViewerRound2Room với đầy đủ parameters
            stackView.push("qrc:/qml/ViewerRound2Room.qml", {
                backend: backend,
                roomCode: roomCode,
                round2Id: roundId,
                productName: prodName,
                productDesc: prodDesc,
                productImage: imageUrl,
                thresholdPct: threshold,
                timeRemaining: timeLimit
            });
        } else {
            // Player: Chuyển sang Round2Room với đầy đủ parameters
            stackView.push("qrc:/qml/Round2Room.qml", {
                backend: backend,
                roundId: roundId,
                roundType: roundType,
                prodName: prodName,
                prodDesc: prodDesc,
                threshold: threshold,
                timeLimit_: timeLimit,
                productImage: imageUrl
            });
        }
    }
    
    // Handler để chuyển sang Round 3 khi nhận GAME_START_NOTIFY
    function handleGameStartNotify(data) {
        console.log("=== RankingPage: GAME_STARTED received ===");
        console.log("Data:", data);
        console.log("Viewer mode:", isViewer);
        console.log("Round number:", roundNumber);
        
        try {
            var info = JSON.parse(data);
            if (info.round === 3) {
                if (isViewer) {
                    // Viewer: Sử dụng Round3Room với overlay viewer mode
                    console.log("Switching viewer to Round3Room (viewer mode)");
                    stackView.replace("qrc:/qml/Round3Room.qml", {
                        backend: backend,
                        isViewerMode: true
                    });
                } else {
                    // Player: Chuyển sang Round3Room
                    console.log("Switching player to Round3Room");
                    stackView.replace("qrc:/qml/Round3Room.qml", {
                        backend: backend
                    });
                }
            }
        } catch (e) {
            console.error("[RankingPage] Failed to parse gameStarted:", e);
        }
    }

    function navigateBackToWaitingRoom() {
        if (navigatedBack) return;
        if (!backend) {
            console.warn("Cannot navigate back, backend is null");
            return;
        }
        navigatedBack = true;
        console.log("Navigating back to WaitingRoom after final ranking");
        // Use replace to clear navigation history and reset waiting room state
        stackView.replace("qrc:/qml/WaitingRoom.qml", { 
            backend: backend,
            hasReceivedRoomState: false  // Force waiting room to reset ready states
        });
    }
    
    function navigateToMatchSummary() {
        if (navigatedBack) return;
        if (!backend) {
            console.warn("Cannot navigate to match summary, backend is null");
            return;
        }
        navigatedBack = true;
        console.log("Navigating to MatchSummaryPage with rankings:", JSON.stringify(rankings));
        console.log("Match data for replay:", JSON.stringify(matchData));
        stackView.replace("qrc:/qml/MatchSummaryPage.qml", {
            backend: backend,
            rankings: rankings,
            matchData: matchData,  // Pass full match data for replay
            isViewer: isViewer,
            roomCode: roomCode
        });
    }

    function leaveRoomAndReturnHome() {
        if (!backend) return;
        backend.leaveRoom();
        navigatedBack = true;
        stackView.replace("qrc:/qml/HomeUser.qml", { userName: backend.user_name, backend: backend });
    }
    
    // Animated gradient background
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#667EEA" }
            GradientStop { position: 0.5; color: "#764BA2" }
            GradientStop { position: 1.0; color: "#F093FB" }
        }
        
        // Animated circles
        Rectangle {
            width: 300
            height: 300
            radius: 150
            color: "#33FFFFFF"
            x: parent.width * 0.1
            y: parent.height * 0.2
            
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 2000 }
                NumberAnimation { to: 0.1; duration: 2000 }
            }
        }
        
        Rectangle {
            width: 250
            height: 250
            radius: 125
            color: "#33FFFFFF"
            x: parent.width * 0.7
            y: parent.height * 0.6
            
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 2500 }
                NumberAnimation { to: 0.05; duration: 2500 }
            }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 20
        
        // Title with Trophy
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "transparent"
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "♛"
                    font.pixelSize: 60
                    color: "#FFD700"
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "ROUND " + roundNumber + " RANKING"
                    font.pixelSize: 36
                    font.bold: true
                    color: "white"
                    style: Text.Outline
                    styleColor: "#4A5568"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
        
        // Rankings List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1F2937"
            radius: 15
            border.color: "#4B5563"
            border.width: 2
            
            // Show message if rankings are empty
            Text {
                id: emptyStateText
                visible: rankings.length === 0
                anchors.centerIn: parent
                text: "Đang tải bảng xếp hạng..."
                font.pixelSize: 24
                font.bold: true
                color: "white"
                style: Text.Outline
                styleColor: "#4A5568"
            }
            
            ListView {
                id: rankingListView
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                clip: true
                visible: rankings.length > 0
                
                model: rankings
                
                delegate: Rectangle {
                    width: rankingListView.width
                    height: 80
                    radius: 10
                    
                    // Medal colors for top 3
                    gradient: Gradient {
                        GradientStop { 
                            position: 0.0
                            color: {
                                if (modelData.rank === 1) return "#FFD700";  // Gold
                                if (modelData.rank === 2) return "#C0C0C0";  // Silver
                                if (modelData.rank === 3) return "#CD7F32";  // Bronze
                                return "#374151";  // Gray for others
                            }
                        }
                        GradientStop { 
                            position: 1.0
                            color: {
                                if (modelData.rank === 1) return "#FFA500";
                                if (modelData.rank === 2) return "#A8A8A8";
                                if (modelData.rank === 3) return "#8B4513";
                                return "#1F2937";
                            }
                        }
                    }
                    
                    border.color: {
                        if (modelData.rank === 1) return "#FFD700";
                        if (modelData.rank === 2) return "#C0C0C0";
                        if (modelData.rank === 3) return "#CD7F32";
                        return "#4B5563";
                    }
                    border.width: 3
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15
                        
                        // Rank with Medal
                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 60
                            radius: 30
                            color: (modelData.rank || index + 1) <= 3 ? "#1F2937" : "#4B5563"
                            border.color: "white"
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0
                                
                                Text {
                                    text: {
                                        var rank = modelData.rank || (index + 1);
                                        return "#" + rank;
                                    }
                                    font.pixelSize: 28
                                    font.bold: true
                                    color: {
                                        var rank = modelData.rank || (index + 1);
                                        if (rank === 1) return "#FFD700";
                                        if (rank === 2) return "#C0C0C0";
                                        if (rank === 3) return "#CD7F32";
                                        return "white";
                                    }
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                        
                        // Username
                        Text {
                            text: modelData.username || modelData.user || "Unknown"
                            font.pixelSize: 24
                            font.bold: true
                            color: (modelData.rank || index + 1) <= 3 ? "#1F2937" : "white"
                            Layout.fillWidth: true
                        }
                        
                        // Score Badge
                        Rectangle {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 50
                            radius: 25
                            color: "#10B981"
                            border.color: "#059669"
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0
                                
                                Text {
                                    text: modelData.total_score !== undefined ? modelData.total_score : (modelData.score || 0)
                                    font.pixelSize: 22
                                    font.bold: true
                                    color: "white"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: "points"
                                    font.pixelSize: 10
                                    color: "white"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Waiting for Round 2 Message
        // Footer action area
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: 16
            color: "#111827"
            border.color: "#4B5563"
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    visible: !isFinalRanking
                    text: "Waiting for Round " + (roundNumber + 1) + " to start..."
                    font.pixelSize: 20
                    font.bold: true
                    color: "white"
                }

                // Pulsing dots for mid-round waiting
                RowLayout {
                    visible: !isFinalRanking
                    spacing: 8
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 10; height: 10; radius: 5; color: "white"
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 500; from: 1.0; running: true; } 
                                NumberAnimation { to: 1.0; duration: 500; running: true; }
                            }
                        }
                    }
                }

                // Final ranking auto-return notice
                RowLayout {
                    visible: isFinalRanking
                    spacing: 8

                    Text {
                        text: "🏆 Bảng xếp hạng cuối cùng"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                    }

                    Text {
                        text: "Xem chi tiết ván đấu sau 5 giây..."
                        color: "#E5E7EB"
                        font.pixelSize: 14
                    }

                    // Fallback button nếu auto-transition không chạy
                    Button {
                        text: "Xem replay ngay"
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 150
                        onClicked: navigateToMatchSummary()

                        background: Rectangle {
                            color: parent.pressed ? "#2563eb" : "#3b82f6"
                            radius: 8
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
