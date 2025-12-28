import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: matchSummaryPage
    width: 800
    height: 600

    property var backend: null
    property var stackView: StackView.view  // Use attached property as default
    property var rankings: []
    property var matchData: null
    property bool isViewer: false
    property string roomCode: ""

    // Current round being displayed (1, 2, 3)
    property int currentRound: 1

    // Parse round data from matchData
    property var round1Data: matchData && matchData.round1 ? matchData.round1 : null
    property var round2Data: matchData && matchData.round2 ? matchData.round2 : null
    property var round3Data: matchData && matchData.round3 ? matchData.round3 : null

    // Get current round data
    function getCurrentRoundData() {
        if (currentRound === 1) return round1Data;
        if (currentRound === 2) return round2Data;
        if (currentRound === 3) return round3Data;
        return null;
    }

    // Get round title
    function getRoundTitle() {
        var data = getCurrentRoundData();
        if (!data) return "Vòng " + currentRound;
        
        var typeMap = {
            "BIDDING": "Vòng 1 - Đoán Giá",
            "HIGHEST_PRICE": "Vòng 2 - Sắp Xếp Giá",
            "WHEEL": "Vòng 3 - Vòng Quay"
        };
        return typeMap[data.type] || ("Vòng " + currentRound);
    }

    // Update table when round changes
    onCurrentRoundChanged: {
        updateTable();
    }

    Component.onCompleted: {
        console.log("MatchSummaryPage loaded");
        console.log("matchData:", JSON.stringify(matchData));
        updateTable();
    }

    function updateTable() {
        answersModel.clear();
        var data = getCurrentRoundData();
        if (!data || !data.answers) {
            console.log("No data for round", currentRound);
            return;
        }

        var answers = data.answers;
        console.log("Round", currentRound, "answers:", JSON.stringify(answers));

        for (var i = 0; i < answers.length; i++) {
            var a = answers[i];
            var answerText = "";
            var resultText = "";

            if (currentRound === 1) {
                // Round 1: answer_choice (A/B/C/D), is_correct
                answerText = a.answer_choice || "-";
                resultText = a.is_correct ? "Dung" : "Sai";
            } else if (currentRound === 2) {
                // Round 2: answer_price (gia doan), is_correct
                var price = a.answer_price;
                answerText = (price === 0 || price) ? price : "-";
                resultText = a.is_correct ? "Dung" : "Sai";
            } else if (currentRound === 3) {
                // Round 3: answer_choice (spin value) + score_awarded
                var spinValue = a.answer_choice || "";
                // Bỏ số 0 ở đầu nếu có (ví dụ: 0,70 → ,70)
                if (spinValue.startsWith("0,") || spinValue.startsWith("0.")) {
                    spinValue = spinValue.substring(1);
                }
                answerText = spinValue ? ("Quay: " + spinValue) : "-";
                // Hiển thị điểm riêng của lần quay này
                resultText = a.score_awarded ? ("+" + a.score_awarded) : "0";
            }

            answersModel.append({
                rank: i + 1,
                username: a.username || "Unknown",
                answer: answerText,
                result: resultText,
                score: a.score_awarded || 0
            });
        }
    }

    ListModel {
        id: answersModel
    }

    // Background
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1a2e" }
            GradientStop { position: 1.0; color: "#16213e" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Title (no icons)
        Text {
            text: "Replay trận đấu"
            font.pixelSize: 26
            font.bold: true
            color: "#FFD700"
            Layout.alignment: Qt.AlignHCenter
        }

        // Round indicator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#2d3748"
            radius: 10

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10

                // Prev button
                Button {
                    text: "Trước"
                    enabled: currentRound > 1
                    Layout.preferredWidth: 100
                    onClicked: currentRound--

                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#3182ce" : "#4299e1") : "#4a5568"
                        radius: 5
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Round title
                Text {
                    text: getRoundTitle()
                    font.pixelSize: 20
                    font.bold: true
                    color: "#FFD700"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // Next button
                Button {
                    text: "Sau"
                    enabled: currentRound < 3
                    Layout.preferredWidth: 100
                    onClicked: currentRound++

                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#3182ce" : "#4299e1") : "#4a5568"
                        radius: 5
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Table header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#4a5568"
            radius: 5

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 5

                Text {
                    text: "#"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#FFD700"
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: "Người chơi"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#FFD700"
                    Layout.preferredWidth: 150
                }
                Text {
                    text: "Câu trả lời"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#FFD700"
                    Layout.fillWidth: true
                }
                Text {
                    text: "Kết quả"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#FFD700"
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: "Điểm"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#FFD700"
                    Layout.preferredWidth: 80
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // Table content
        ListView {
            id: answersListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: answersModel
            clip: true
            spacing: 2

            delegate: Rectangle {
                width: answersListView.width
                height: 45
                color: index % 2 === 0 ? "#2d3748" : "#374151"
                radius: 3

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 5

                    Text {
                        text: model.rank
                        font.pixelSize: 14
                        color: "white"
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        text: model.username
                        font.pixelSize: 14
                        font.bold: true
                        color: "#60a5fa"
                        Layout.preferredWidth: 150
                        elide: Text.ElideRight
                    }
                    Text {
                        text: model.answer
                        font.pixelSize: 14
                        color: "white"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: model.result
                        font.pixelSize: 14
                        font.bold: true
                        color: model.result.indexOf("Dung") >= 0 ? "#10b981" : (model.result.indexOf("Sai") >= 0 ? "#ef4444" : "#9ca3af")
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        text: model.score > 0 ? ("+" + model.score) : model.score
                        font.pixelSize: 14
                        font.bold: true
                        color: model.score > 0 ? "#10b981" : "#9ca3af"
                        Layout.preferredWidth: 80
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                text: "Không có dữ liệu vòng này"
                font.pixelSize: 16
                color: "#9ca3af"
                visible: answersModel.count === 0
            }
        }

        // Round indicator dots
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Repeater {
                model: 3
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: (index + 1) === currentRound ? "#FFD700" : "#4a5568"
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: currentRound = index + 1
                    }
                }
            }
        }

        // Back to waiting room button
        Button {
            text: "Quay về phòng chờ"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 45

            onClicked: {
                console.log("Returning to waiting room");
                if (isViewer) {
                    stackView.replace("qrc:/qml/WaitingRoom.qml", {
                        backend: backend,
                        isHost: false,
                        roomCode: roomCode
                    });
                } else {
                    stackView.replace("qrc:/qml/WaitingRoom.qml", {
                        backend: backend,
                        isHost: (backend && rankings && rankings.length > 0 && backend.user_name === rankings[0].name),
                        roomCode: roomCode
                    });
                }
            }

            background: Rectangle {
                color: parent.pressed ? "#d97706" : "#f59e0b"
                radius: 8
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 16
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
