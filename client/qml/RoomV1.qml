import QtQuick 2.12
import QtQuick.Controls 2.12
import QtGraphicalEffects 1.12 
import ThePriceIsRight.BackEnd 1.0

Page {
    id: roomV1
    width: 800
    height: 600

    BackEnd {
        id: backend
    }

    // ====== DATA GIẢ LẬP ĐỂ TEST GIAO DIỆN ======
    property bool isCorrectBanner: true
    property string correctAnswer: "A"
    property int currentRound: 1
    property int myIndex: 0
    property string myPick: ""
    property bool pickLocked: false

    property var players: [
        { name: "NKDUYEN", score: "1/5", pick: "" },
        { name: "PLAYER 1", score: "0/5", pick: "B" },
        { name: "PLAYER 2", score: "0/5", pick: "B" },
        { name: "PLAYER 3", score: "0/5", pick: "B" },
        { name: "PLAYER 4", score: "0/5", pick: "C" }
    ]

    property string questionText: "QUESTION\nChọn đáp án đúng nhất cho câu hỏi này?"
    // ĐÁP ÁN GIẢ LẬP LUÔN HIỂN THỊ CHO FRONTEND
    property var choices: [
        { key: "A", price: "120.000đ" },
        { key: "B", price: "150.000đ" },
        { key: "C", price: "90.000đ" },
        { key: "D", price: "200.000đ" }
    ]

    function setMyPick(p) {
        myPick = p
        // Update giả vào mảng players để thấy UI thay đổi
        var temp = players
        temp[myIndex].pick = p
        players = temp 
    }

    // ====== NỀN ======
    Rectangle {
        anchors.fill: parent
        color: "#212121"
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.3
            z: 1
        }
    }

    // ====== LAYOUT CHÍNH ======
    Column {
        anchors.fill: parent
        spacing: 0
        z: 2

        // 1. TOP BAR (Kết quả & Đáp án)
        Item {
            id: topBar
            height: 100
            width: parent.width

            // Báo Đúng/Sai: Nếu đúng thì hiện ảnh lớn sát góc trên trái, sai thì hiện chữ
            Item {
                width: 320; height: 120
                anchors.left: parent.left
                anchors.top: parent.top
                z: 10
                Image {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    source: isCorrectBanner ? "qrc:/ui/correct.png" : ""
                    visible: isCorrectBanner
                    width: 320; height: 120; fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.centerIn: parent
                    text: isCorrectBanner ? "" : "WRONG"
                    font.bold: true; font.pixelSize: 32; color: "#D32F2F"
                    visible: !isCorrectBanner
                }
            }

            // Đáp án đúng
            Rectangle {
                width: 120; height: 70
                anchors.right: parent.right; anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                radius: 10
                color: "#FFECB3"
                border.color: "white"; border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text { text: "ANSWER"; font.bold: true; color: "#E65100"; font.pixelSize: 12 }
                    Text { text: correctAnswer; font.bold: true; color: "#1565C0"; font.pixelSize: 30 }
                }
            }
        }

        // 2. MIDDLE AREA (Danh sách người chơi)
        Item {
            id: middleArea
            height: 370 // tăng chiều cao để hạ thấp box
            width: parent.width

            Row {
                anchors.centerIn: parent
                spacing: 15

                Repeater {
                    // --- [ĐÃ SỬA LỖI TẠI ĐÂY] ---
                    model: players // Truyền cả mảng vào, KHÔNG dùng players.length
                    // ----------------------------

                    delegate: Column {
                        width: 130 // rộng hơn cho avatar to
                        spacing: 12 // giãn cách hơn

                        // Avatar tròn (to hơn)
                        Item {
                            width: 100; height: 100
                            anchors.horizontalCenter: parent.horizontalCenter
                            Image {
                                id: userImg
                                anchors.fill: parent
                                source: "qrc:/ui/user.png"
                                fillMode: Image.PreserveAspectCrop
                                visible: true // Luôn hiển thị
                                // Fallback nếu ảnh lỗi
                                onStatusChanged: if (status === Image.Error) source = "qrc:/ui/pic.png"
                            }
                            OpacityMask {
                                anchors.fill: parent
                                source: userImg
                                maskSource: Rectangle {
                                    width: 100; height: 100; radius: 50
                                    visible: true
                                }
                            }
                        }

                        // Tên & Điểm
                        Rectangle {
                            width: parent.width; height: 44
                            color: "#FFEB3B"; radius: 6
                            border.color: "white"; border.width: 2
                            Column {
                                anchors.centerIn: parent
                                Text { 
                                    text: modelData.name // Giờ nó đã hiểu modelData là object
                                    font.bold: true; width: parent.width; 
                                    horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight 
                                }
                                Text { text: modelData.score; font.pixelSize: 11 }
                            }
                        }

                        // Đáp án của người chơi
                        Rectangle {
                            width: parent.width; height: 50
                            radius: 6
                            color: {
                                var p = modelData.pick
                                if (p==="A") return "#E53935"
                                if (p==="B") return "#1E88E5"
                                if (p==="C") return "#FDD835"
                                if (p==="D") return "#43A047"
                                return "#616161"
                            }
                            border.color: "white"; border.width: 2
                            Text {
                                anchors.centerIn: parent
                                text: modelData.pick === "" ? "?" : modelData.pick
                                font.bold: true; font.pixelSize: 24; color: "white"
                            }
                        }
                    }
                }
            }
        }

        // 3. BOTTOM AREA (Câu hỏi & Nút bấm)
        Rectangle {
            id: bottomArea
            width: parent.width
            height: parent.height - topBar.height - middleArea.height
            color: "white"

            Row {
                anchors.fill: parent
                
                // Panel trái
                Rectangle {
                    width: 150; height: parent.height
                    color: "#F5F5F5"; border.color: "#E0E0E0"
                    Column {
                        anchors.centerIn: parent
                        spacing: 15
                        Text { 
                            text: "ROUND " + currentRound; 
                            font.bold: true; font.pixelSize: 20; color: "#3F51B5" 
                        }
                        Button {
                            text: "QUIT"
                            background: Rectangle { color: "#D32F2F"; radius: 5 }
                            contentItem: Text { text: "QUIT"; color: "white"; anchors.centerIn: parent }
                            onClicked: console.log("Quit clicked")
                        }
                    }
                }

                // Panel phải
                Item {
                    width: parent.width - 150; height: parent.height
                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 15

                        Text {
                            width: parent.width
                            text: questionText
                            wrapMode: Text.WordWrap
                            font.pixelSize: 16
                            color: "#212121"
                        }

                        Row {
                            spacing: 15
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: choices
                                delegate: Item {
                                    width: 120; height: 70
                                    Rectangle {
                                        id: answerCard
                                        anchors.fill: parent
                                        radius: 16
                                        color: {
                                            if (modelData.key==="A") return "#FF8A65"
                                            if (modelData.key==="B") return "#64B5F6"
                                            if (modelData.key==="C") return "#FFF176"
                                            return "#81C784"
                                        }
                                        border.color: myPick === modelData.key ? "#212121" : "#BDBDBD"
                                        border.width: myPick === modelData.key ? 5 : 2
                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            color: myPick === modelData.key ? "#212121" : "#888"
                                            radius: myPick === modelData.key ? 16 : 8
                                            samples: 16
                                            transparentBorder: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !pickLocked
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: setMyPick(modelData.key)
                                        }
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 2
                                            Text {
                                                text: modelData.key
                                                font.bold: true
                                                font.pixelSize: 28
                                                color: myPick === modelData.key ? "#212121" : "white"
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            Text {
                                                text: modelData.price
                                                font.pixelSize: 16
                                                color: myPick === modelData.key ? "#212121" : "white"
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }

                            Button {
                                width: 80; height: 50
                                enabled: myPick !== "" && !pickLocked
                                background: Rectangle {
                                    color: enabled ? "#212121" : "#BDBDBD"
                                    radius: 8
                                }
                                contentItem: Text { text: "OK"; color: "white"; anchors.centerIn: parent; font.bold: true }
                                onClicked: {
                                    console.log("Submitting: " + myPick)
                                    pickLocked = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}