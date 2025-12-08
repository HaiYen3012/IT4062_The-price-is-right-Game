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
    
    property string myUserName: backend ? backend.user_name : ""
    
    // Biến đếm lượt quay (0, 1, 2)
    property int currentTurnSpins: 0 
    
    property var currentServerResult: null 
    property string pendingNextUser: ""

    property var numbers: ["050","005","060","070","025","080","040","095","010","085","075","035","000","045","090","020","065","055","030","100","015"]

    ListModel { id: playersModel }

    Connections {
        target: backend
        
        function onRoundResult(resultJson) {
            try {
                var res = JSON.parse(resultJson)
                console.log("Receive:", resultJson)

                if (res.type === "SPIN_RESULT") {
                    currentServerResult = res
                    // Cập nhật số lần quay
                    if (res.user === playersModel.get(currentPlayerIndex).name) {
                        currentTurnSpins = res.spins_count
                    }
                    handleSpinResult(res)
                } 
                else if (res.type === "TURN_CHANGE") {
                    pendingNextUser = res.next_user
                    // Nếu không đang quay (PASS) -> chuyển luôn
                    if (!spinning) {
                        applyNextTurn()
                    }
                }
                else if (res.type === "ROUND3_END") {
                    var msg = "NGƯỜI THẮNG: " + res.winner + "\n\n--- BẢNG ĐIỂM ---\n"
                    if (res.details) {
                        for (var i = 0; i < res.details.length; i++) {
                            msg += res.details[i].user + ": " + res.details[i].score + " điểm\n"
                        }
                    }
                    eliminationPopup.popMessage = msg
                    eliminationPopup.open()
                }
            } catch (e) {
                console.error("Lỗi xử lý JSON:", e)
            }
        }
    }

    function applyNextTurn() {
        if (pendingNextUser !== "") {
            for (var i = 0; i < playersModel.count; i++) {
                if (playersModel.get(i).name === pendingNextUser) {
                    currentPlayerIndex = i
                    break
                }
            }
            // Reset trạng thái người mới
            currentTurnSpins = 0 
            pendingNextUser = ""
        }
    }

    function handleSpinResult(res) {
        var val = res.spin_val
        var targetIdx = -1
        
        for (var i = 0; i < numbers.length; i++) {
            if (parseInt(numbers[i]) === val) { targetIdx = i; break; }
        }

        if (targetIdx !== -1) {
            spinTargetIndex = targetIdx
            var len = numbers.length
            var finalOffset = - ( (cycles) * len + spinTargetIndex ) * itemHeight + (spinnerViewport.height/2 - itemHeight/2)
            
            // [QUAN TRỌNG] Chỉ set spinning = true, KHÔNG set enabled = false thủ công
            spinning = true
            
            spinAnim.from = spinnerOffset
            spinAnim.to = finalOffset
            spinAnim.duration = 4000 
            spinAnim.easing.type = Easing.OutCubic
            spinAnim.running = true
        }
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

    // Left Player Box
    Rectangle {
        id: leftPlayerBox
        x: 20; y: headerBar.height + 20
        width: 160; height: 200; radius: 12; color: "#FFDCC5"; z: 10
        Column { 
            anchors.fill: parent; anchors.margins: 12; spacing: 8; anchors.horizontalCenter: parent.horizontalCenter
            Rectangle { 
                width: 100; height: 100; radius: 50; color: "#ffffff"; border.width: 2; border.color: "#d6eaf2"; anchors.horizontalCenter: parent.horizontalCenter
                Image { anchors.centerIn: parent; source: "qrc:/ui/pic.png"; width: 80; height: 80; fillMode: Image.PreserveAspectFit }
            }
            Text { 
                text: playersModel.count > 0 ? playersModel.get(0).name : "..."
                font.bold: true
                color: (playersModel.count > 0 && playersModel.get(0).name === myUserName) ? "#D32F2F" : (currentPlayerIndex === 0 ? "#0B5E8A" : "#222")
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text { 
                text: playersModel.count > 0 ? playersModel.get(0).score + " pts" : "0 pts"
                color: "#666"; font.pointSize: 12; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle { visible: currentPlayerIndex === 0; width: 14; height: 14; radius: 7; color: "#29B6F6"; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }

    // Right Players
    Column {
        id: rightPlayersBox
        x: parent.width - 20 - 160; y: headerBar.height + 20
        width: 160; spacing: 12; z: 10
        Repeater {
            model: Math.max(0, playersModel.count - 1)
            delegate: Rectangle {
                width: 160; height: 90; radius: 12; color: "#FFDCC5"
                Column { 
                    anchors.fill: parent; anchors.margins: 8; spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle { 
                        width: 60; height: 60; radius: 30; color: "#ffffff"; border.width: 2; border.color: "#d6eaf2"; anchors.horizontalCenter: parent.horizontalCenter
                        Image { anchors.centerIn: parent; source: "qrc:/ui/pic.png"; width: 48; height: 48; fillMode: Image.PreserveAspectFit }
                    }
                    Text { 
                        text: playersModel.count > (index + 1) ? playersModel.get(index + 1).name : "..."
                        font.bold: true; font.pixelSize: 12
                        color: (playersModel.count > (index + 1) && playersModel.get(index+1).name === myUserName) ? "#D32F2F" : (currentPlayerIndex === (index + 1) ? "#0B5E8A" : "#222")
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text { 
                        text: playersModel.count > (index + 1) ? playersModel.get(index + 1).score + " pts" : "0 pts"
                        font.pixelSize: 11; color: "#666"; anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    // Center Area
    Rectangle {
        id: centerArea
        anchors.left: leftPlayerBox.right; anchors.right: rightPlayersBox.left; anchors.top: headerBar.bottom; anchors.bottom: footerBar.top; anchors.margins: 20
        color: "transparent"; z: 1
        Column {
            anchors.centerIn: parent; spacing: 12; width: parent.width * 0.5
            Text { text: "ROOM 03 - SPIN WHEEL"; font.pixelSize: 22; font.bold: true; color: "#043B56"; anchors.horizontalCenter: parent.horizontalCenter }

            Rectangle {
                id: spinnerViewport
                width: 140; height: 220; color: "transparent"; clip: true; radius: 6; anchors.horizontalCenter: parent.horizontalCenter
                Item {
                    id: spinnerContent
                    width: spinnerViewport.width
                    height: numbers.length * itemHeight * (cycles + 2)
                    x: 0; y: spinnerOffset
                    Repeater {
                        model: cycles + 2
                        delegate: Column {
                            Repeater {
                                model: numbers.length
                                delegate: Rectangle {
                                    width: spinnerViewport.width; height: itemHeight
                                    color: "#111"; border.width: 4; border.color: "#FFD300"; radius: 4; anchors.horizontalCenter: parent.horizontalCenter
                                    Text { anchors.centerIn: parent; text: numbers[index]; font.pixelSize: 18; font.bold: true; color: "#ffffff" }
                                }
                            }
                        }
                    }
                }
                NumberAnimation { id: spinAnim; target: room3; property: "spinnerOffset"; onStopped: { endCurrentTurn() } }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height/2 - itemHeight/2; width: parent.width; height: itemHeight; color: "transparent"; border.width: 3; border.color: "#FF4F00"; radius: 4 }
            }

            // --- NÚT BẤM (ĐÃ FIX: XÓA enabled = false THỦ CÔNG) ---
            Row { 
                spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                
                property bool isMyTurn: {
                    if (playersModel.count === 0) return false
                    if (currentPlayerIndex >= playersModel.count) return false
                    return playersModel.get(currentPlayerIndex).name === myUserName
                }

                Button { 
                    id: spinBtn
                    width: 100; height: 40
                    text: spinning ? "..." : (currentTurnSpins === 0 ? "SPIN 1" : "SPIN 2")
                    font.pixelSize: 14
                    
                    // Logic tự động: Chỉ cần khai báo ở đây, KHÔNG can thiệp thủ công
                    enabled: parent.isMyTurn && !spinning && backend !== null && currentTurnSpins < 2
                    
                    onClicked: {
                        if (spinning) return
                        console.log("Sending SPIN request...")
                        backend.sendRoundAnswer("SPIN")
                        
                        // [QUAN TRỌNG] ĐÃ XÓA DÒNG: spinBtn.enabled = false
                        // Lý do: Khi gửi lệnh xong, biến 'spinning' sẽ được set = true (trong hàm handleSpinResult),
                        // lúc đó công thức 'enabled' bên trên sẽ tự động tắt nút này.
                    } 
                }

                Button { 
                    id: passBtn
                    text: "PASS"; width: 100; height: 40; font.pixelSize: 14
                    
                    enabled: parent.isMyTurn && !spinning && backend !== null && currentTurnSpins >= 1
                    opacity: enabled ? 1.0 : 0.5
                    
                    onClicked: { 
                        console.log("Sending PASS request...")
                        backend.sendRoundAnswer("PASS")
                        
                        // [QUAN TRỌNG] ĐÃ XÓA CÁC DÒNG gán enabled = false
                    } 
                }
            }

            Text { 
                id: infoText
                text: {
                    if (playersModel.count > currentPlayerIndex) {
                        var curr = playersModel.get(currentPlayerIndex).name
                        if (curr === myUserName) return "Lượt của BẠN! Hãy quay số."
                        return "Đến lượt: " + curr
                    }
                    return "Waiting..."
                }
                anchors.horizontalCenter: parent.horizontalCenter
                color: (infoText.text.indexOf("BẠN") !== -1) ? "#D32F2F" : "#043B56"
                font.pixelSize: 16; font.bold: true
            }
        }
    }

    Rectangle { id: footerBar; height: 50; anchors.bottom: parent.bottom; width: parent.width; z: 10 }
    Popup {
        id: eliminationPopup
        property string popMessage: ""; x: (parent.width - 360)/2; y: (parent.height-200)/2; width: 360; height: 200; modal: true; focus: true
        background: Rectangle { radius: 12; color: "#ffffff"; border.color: "#DD3333" }
        Column { anchors.fill: parent; anchors.margins: 12; spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
            Text { text: eliminationPopup.popMessage; wrapMode: Text.WordWrap; font.pixelSize: 16; width: parent.width; horizontalAlignment: Text.AlignHCenter }
            Button { text: "OK"; onClicked: eliminationPopup.close(); anchors.horizontalCenter: parent.horizontalCenter }
        }
    }

    Component.onCompleted: {
        if (backend) {
            var infoStr = backend.getRoomInfo()
            if (infoStr !== "") {
                try {
                    var info = JSON.parse(infoStr)
                    var members = info.members.split('|')
                    playersModel.clear()
                    for (var i = 0; i < members.length; i++) {
                        playersModel.append({ name: members[i], score: 0, eliminated: false })
                    }
                } catch(e) {}
            } else { setupDummyPlayers() }
        } else { setupDummyPlayers() }

        if (spinnerViewport) {
            spinnerOffset = - ((cycles) * numbers.length) * itemHeight + (spinnerViewport.height/2 - itemHeight/2)
            spinnerInitialized = true
        }
    }

    function setupDummyPlayers() {
        playersModel.clear()
        var me = myUserName ? myUserName : "You"
        playersModel.append({ name: me, score: 0, eliminated: false })
        playersModel.append({ name: "Player 1", score: 0, eliminated: false })
        currentPlayerIndex = 0
    }
}