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

    // end-turn helper: apply spin result (if any), handle elimination and advance to next player
    function endCurrentTurn(fromSpin) {
        // re-enable controls
        spinning = false
        spinBtn.enabled = true

        // If we just spun, add score
        if (fromSpin) {
            var landed = spinTargetIndex
            var val = parseInt(numbers[landed])
            var p = playersModel.get(currentPlayerIndex)
            var newScore = p.score + val
            if (newScore > 100) {
                // mark eliminated
                playersModel.set(currentPlayerIndex, { name: p.name, score: newScore, eliminated: true })
                eliminationPopup.popMessage = p.name + " bị loại với " + newScore + " điểm"
                eliminationPopup.open()
            } else {
                playersModel.set(currentPlayerIndex, { name: p.name, score: newScore, eliminated: p.eliminated })
            }
        }

        // Advance to next non-eliminated player
        var start = currentPlayerIndex
        var found = false
        for (var i=1;i<=playersModel.count;i++) {
            var idx = (start + i) % playersModel.count
            var p2 = playersModel.get(idx)
            if (!p2.eliminated) { currentPlayerIndex = idx; found = true; break }
        }

        if (!found) {
            // Round finished: determine lowest-score (among non-eliminated if any, otherwise among all)
            var lowestIdx = -1; var lowestScore = 1e9
            for (var j=0;j<playersModel.count;j++) {
                var pp = playersModel.get(j)
                if (!pp.eliminated) {
                    if (pp.score < lowestScore) { lowestScore = pp.score; lowestIdx = j }
                }
            }
            if (lowestIdx === -1) {
                // everyone eliminated or no players left
                eliminationPopup.popMessage = "Vòng kết thúc. Không còn người chơi."
                eliminationPopup.open()
            } else {
                // eliminate lowest
                var lp = playersModel.get(lowestIdx)
                playersModel.set(lowestIdx, { name: lp.name, score: lp.score, eliminated: true })
                eliminationPopup.popMessage = "Vòng kết thúc. Người có điểm thấp nhất bị loại: " + lp.name + " (" + lp.score + " điểm)"
                eliminationPopup.open()
            }
        }
    }

    // numbers on wheel (strings keep leading zeros)
    property var numbers: ["050","005","060","070","025","080","040","095","010","085","075","035","000","045","090","020","065","055","030","100","015"]

    ListModel {
        id: playersModel
    }

    // room background (stop above footer so footer area remains white)
    Image {
        id: bgImage
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // reserve footerBar.height pixels at bottom
        height: parent.height - footerBar.height
        source: "qrc:/ui/bgroom3.png"
        fillMode: Image.PreserveAspectCrop
        z: -1
        opacity: 0.7
    }

    // Header: room title + host
    Rectangle {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 64
        color: "#ffffff"
        border.color: "#e0eef6"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 16

            Image { source: "qrc:/ui/trophy.png"; width: 40; height: 40; Layout.preferredWidth: 40; Layout.preferredHeight: 40 }

            Column { spacing: 2; Layout.alignment: Qt.AlignVCenter
                Text { text: "ROOM 03"; font.pixelSize: 20; font.bold: true; color: "#0B5E8A" }
                Text { text: "Host: " + hostName; font.pixelSize: 12; color: "#666" }
            }

            Item { Layout.fillWidth: true }

            Rectangle { width: 120; height: 36; radius: 18; color: "#FFCA28"; border.color: "#FFB300"; Layout.alignment: Qt.AlignVCenter
                Text { anchors.centerIn: parent; text: "Players: " + playersModel.count; color: "#212121" }
            }
        }
    }

    // Left side: Player 1
    Rectangle {
        id: leftPlayerBox
        x: 20; y: headerBar.height + 20
        width: 160; height: 200
        radius: 12; color: "#FFDCC5"
        z: 10
        
        Column { anchors.fill: parent; anchors.margins: 12; spacing: 8; anchors.horizontalCenter: parent.horizontalCenter
            Rectangle { width: 100; height: 100; radius: 50; color: "#ffffff"; border.width: 2; border.color: "#d6eaf2"; anchors.horizontalCenter: parent.horizontalCenter
                Image { anchors.centerIn: parent; source: "qrc:/ui/pic.png"; width: 80; height: 80; fillMode: Image.PreserveAspectFit }
            }
            Text { 
                text: playersModel.count > 0 ? playersModel.get(0).name : "Player 1"
                font.bold: true; color: currentPlayerIndex === 0 && !playersModel.get(0).eliminated ? "#0B5E8A" : (playersModel.count > 0 && playersModel.get(0).eliminated ? "#999" : "#222")
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text { 
                text: playersModel.count > 0 ? playersModel.get(0).score + " pts" : "0 pts"
                color: "#666"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle { visible: currentPlayerIndex === 0 && playersModel.count > 0 && !playersModel.get(0).eliminated; width: 14; height: 14; radius: 7; color: "#29B6F6"; anchors.horizontalCenter: parent.horizontalCenter }
            Text { visible: playersModel.count > 0 && playersModel.get(0).eliminated; text: "ELIM"; color: "#D32F2F"; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }

    // Right side: Player 2 & Player 3
    Column {
        id: rightPlayersBox
        x: parent.width - 20 - 160; y: headerBar.height + 20
        width: 160; spacing: 12
        z: 10

        Repeater {
            model: 2
            delegate: Rectangle {
                width: 160; height: 90; radius: 12; color: "#FFDCC5"
                
                Column { anchors.fill: parent; anchors.margins: 8; spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle { width: 60; height: 60; radius: 30; color: "#ffffff"; border.width: 2; border.color: "#d6eaf2"; anchors.horizontalCenter: parent.horizontalCenter
                        Image { anchors.centerIn: parent; source: "qrc:/ui/pic.png"; width: 48; height: 48; fillMode: Image.PreserveAspectFit }
                    }
                    Text { 
                        text: playersModel.count > (1 + index) ? playersModel.get(1 + index).name : ("Player " + (2 + index))
                        font.bold: true; font.pixelSize: 12
                        color: currentPlayerIndex === (1 + index) && playersModel.count > (1 + index) && !playersModel.get(1 + index).eliminated ? "#0B5E8A" : (playersModel.count > (1 + index) && playersModel.get(1 + index).eliminated ? "#999" : "#222")
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text { 
                        text: playersModel.count > (1 + index) ? playersModel.get(1 + index).score + " pts" : "0 pts"
                        font.pixelSize: 11
                        color: "#666"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    // Center: spinner & UI
    Rectangle {
        id: centerArea
        anchors.left: leftPlayerBox.right
        anchors.right: rightPlayersBox.left
        anchors.top: headerBar.bottom
        anchors.bottom: footerBar.top
        anchors.margins: 20
        color: "transparent"
        z: 1

        // overlay for interactive elements
        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.5

            Text { id: roundLabel; text: "ROOM 03 - SPIN WHEEL"; font.pixelSize: 22; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter; color: "#043B56" }

            // spinner viewport: narrow column with stacked number boxes
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
                        model: cycles + 2
                        delegate: Column {
                            Repeater {
                                model: numbers.length
                                delegate: Rectangle {
                                    width: spinnerViewport.width
                                    height: itemHeight
                                    color: "#111"  // black box
                                    border.width: 4
                                    border.color: "#FFD300" // yellow border
                                    radius: 4
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Text { anchors.centerIn: parent; text: numbers[index]; font.pixelSize: 18; font.bold: true; color: "#ffffff" }
                                }
                            }
                        }
                    }
                }

                // animation used to move spinnerOffset (configured and started from JS)
                NumberAnimation {
                    id: spinAnim
                    target: room3
                    property: "spinnerOffset"
                    onStopped: {
                        endCurrentTurn(true)
                    }
                }

                // center highlight (frame of selected value)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height/2 - itemHeight/2
                    width: parent.width
                    height: itemHeight
                    color: "transparent"
                    border.width: 3
                    border.color: "#FF4F00"
                    radius: 4
                }
            }

            Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                Button { id: spinBtn; width: 100; height: 40; text: spinning ? "SPINNING..." : "SPIN"; font.pixelSize: 14; enabled: !spinning && (playersModel.get(currentPlayerIndex) ? !playersModel.get(currentPlayerIndex).eliminated : false); onClicked: {
                            if (spinning) return
                            var len = numbers.length
                            spinTargetIndex = Math.floor(Math.random() * len)
                            var finalOffset = - ( (cycles) * len + spinTargetIndex ) * itemHeight + (spinnerViewport.height/2 - itemHeight/2)
                            spinning = true; spinBtn.enabled = false
                            spinAnim.from = spinnerOffset; spinAnim.to = finalOffset; spinAnim.duration = 1200 + Math.random()*1200; spinAnim.easing.type = Easing.OutCubic; spinAnim.running = true
                        } }

                Button { text: "END TURN"; width: 100; height: 40; font.pixelSize: 14; onClicked: { endCurrentTurn(false) } }
                Button { text: "RESET"; width: 80; height: 40; font.pixelSize: 14; onClicked: {
                            for (var i=0;i<playersModel.count;i++) playersModel.set(i, { name: playersModel.get(i).name, score: 0, eliminated: false })
                            currentPlayerIndex = 0
                        } }
            }

            Text { id: infoText; text: "Current: " + (playersModel.count>0?playersModel.get(currentPlayerIndex).name : "-") + " | Score: " + (playersModel.count>0?playersModel.get(currentPlayerIndex).score : 0); anchors.horizontalCenter: parent.horizontalCenter; color: "#043B56"; font.pixelSize: 14 }
        }
    }

    // Footer: Room name & Rules
    Rectangle {
        id: footerBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 100
        color: "#ffffff"
        border.color: "#e0eef6"
        border.width: 1
        z: 10

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 24

            Column { spacing: 4; Layout.alignment: Qt.AlignVCenter
                Text { text: "ROUND 3"; font.pixelSize: 18; font.bold: true; color: "#0B5E8A" }
                Text { text: "ROOM CODE: 003"; font.pixelSize: 14; color: "#666" }
            }

            Item { Layout.fillWidth: true }

            Column { spacing: 4; Layout.alignment: Qt.AlignVCenter
                Text { text: "RULES"; font.pixelSize: 16; font.bold: true; color: "#043B56" }
                Text { text: "• Mỗi lượt spin 1 lần hoặc dừng\n• Nếu >100 điểm bị loại ngay\n• Hết vòng, người thấp bị loại"; font.pixelSize: 11; color: "#333"; wrapMode: Text.WordWrap; lineHeight: 1.2 }
            }
        }
    }

    // simple popup to announce eliminations / round end
    Popup {
        id: eliminationPopup
        property string popMessage: ""
        x: (parent.width - 360) / 2
        y: (parent.height - 140) / 2
        width: 360; height: 140
        modal: true
        focus: true
        background: Rectangle { radius: 12; color: "#ffffff"; border.color: "#DD3333" }
        Column { anchors.fill: parent; anchors.margins: 12; spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
            Text { text: eliminationPopup.popMessage; wrapMode: Text.WordWrap; font.pixelSize: 16; color: "#333" }
            Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                Button { text: "OK"; onClicked: eliminationPopup.close() }
            }
        }
    }

    Component.onCompleted: {
        // prepare players for test: host + two bots
        playersModel.clear()
        var me = hostName ? hostName : "You"
        playersModel.append({ name: me, score: 0, eliminated: false })
        playersModel.append({ name: "Player 1", score: 0, eliminated: false })
        playersModel.append({ name: "Player 2", score: 0, eliminated: false })
        currentPlayerIndex = 0
        if (spinnerViewport && spinnerViewport.height > 0 && !spinnerInitialized) {
            spinnerOffset = - ((cycles) * numbers.length) * itemHeight + (spinnerViewport.height/2 - itemHeight/2)
            spinnerInitialized = true
        }
    }
}
