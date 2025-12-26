import QtQuick 2.12
import QtQuick.Controls 2.12
import ThePriceIsRight.BackEnd 1.0

ApplicationWindow {
    id: rootWindow
    visible: true
    width: 800
    height: 600
    maximumWidth: 800
    maximumHeight: 600
    minimumWidth: 800
    minimumHeight: 600
    title: qsTr("Hãy Chọn Giá Đúng - The Price is Right")

    property color backgroundColor: "#0DCDFF"
    property color mainAppColor: "#0096C8"
    property color textColor: "#FFFFFF"
    property color buttonColor: "#00648C"
    property color errorColor: "#FF4444"
    property color successColor: "#44FF44"
    
    property string currentAction: "none"
    property bool connectionFailed: false
    property string signupStatus: "none"
    property string loginStatus: "none"

    BackEnd {
        id: backEnd

        onConnectSuccess: {
            rootWindow.connectionFailed = false
            waitPopup.close()
            // Truyền backend sang trang tiếp theo
            stackView.push("qrc:/qml/HomeGuest.qml", { backend: backEnd })
        }

        onConnectFail: {
            rootWindow.connectionFailed = true
            waitPopup.close()
            notifyErrorPopup.popMessage = "Kết nối thất bại!"
            notifyErrorPopup.open()
        }

        onSignupSuccess: {
            rootWindow.signupStatus = "SIGNUP_SUCCESS"
        }

        onAccountExist: {
            rootWindow.signupStatus = "ACCOUNT_EXIST"
        }

        // Login signals
        onLoginSuccess: {
            waitPopup.close()
            rootWindow.loginStatus = "LOGIN_SUCCESS"
            notifySuccessPopup.popMessage = "Chào mừng " + backEnd.user_name
            notifySuccessPopup.open()
            stackView.push("qrc:/qml/HomeUser.qml", { userName: backEnd.user_name, backend: backEnd })
        }

        onAccountNotExist: { 
            waitPopup.close(); 
            notifyErrorPopup.popMessage = "Tài khoản không tồn tại!"; 
            notifyErrorPopup.open() 
        }

        onWrongPassword: {
            waitPopup.close()
            rootWindow.loginStatus = "WRONG_PASSWORD"
            notifyErrorPopup.popMessage = "Wrong password! Please try again."
            notifyErrorPopup.open()
        }

        onLoggedIn: {
            waitPopup.close()
            rootWindow.loginStatus = "LOGGED_IN"
            notifyErrorPopup.popMessage = "Account is already logged in!"
            notifyErrorPopup.open()
        }

        onAccountBlocked: {
            waitPopup.close()
            rootWindow.loginStatus = "ACCOUNT_BLOCKED"
            notifyErrorPopup.popMessage = "Your account has been blocked!"
            notifyErrorPopup.open()
        }
        onGameStarted: {
            console.log("Điều hướng game: " + data)
            if (data === "Game is starting!") {
                stackView.replace("qrc:/qml/Round1Room.qml", { backend: backEnd })
                return
            }
            try {
                var gameData = JSON.parse(data)
                if (gameData.type === "ROUND_START") {
                    if (gameData.round === 2) {
                        stackView.replace("qrc:/qml/Round2Room.qml", { 
                            backend: backEnd,
                            roundId: gameData.round_id,
                            prodName: gameData.product_name,
                            prodDesc: gameData.product_desc
                        })
                    } else if (gameData.round === 3) {
                        stackView.replace("qrc:/qml/Room3.qml", { 
                            backend: backEnd,
                            turnUser: gameData.turn_user 
                        })
                    }
                }
            } catch (e) {
                stackView.replace("qrc:/qml/Round1Room.qml", { backend: backEnd })
            }
        }

        // FINAL RANKING - Only when game completely ends (after Round 3)
        onGameEnd: { 
            console.log("[main.qml] Game ended, final ranking data: " + data)
            // NOTE: This should only be called at the very end of game (Round 3 end)
            // Individual rounds handle their own rankings via Room*.qml files
            // This is a fallback handler
        }
    }

    // Global Connections for system-wide signals (prevents signal accumulation)
    Connections {
        target: backEnd
        
        function onInviteNotify(invitationId, fromUser, roomCode) {
            globalInvitePopup.invitationId = invitationId
            globalInvitePopup.fromUser = fromUser
            globalInvitePopup.roomCode = roomCode
            globalInvitePopup.open()
        }
    }

    Component.onCompleted: {
        currentAction = "connect"
        waitPopup.popMessage = "Đang kết nối đến server..."
        waitPopup.open()
        backEnd.connectToServer()
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: Rectangle {
            color: backgroundColor
        }
    }

    // Success Popup
    Popup {
        id: notifySuccessPopup
        property alias popMessage: notifySuccessMessage.text

        background: Rectangle {
            implicitWidth: rootWindow.width
            implicitHeight: 60
            color: successColor
        }
        y: (rootWindow.height - 60)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnPressOutside
        
        Text {
            id: notifySuccessMessage
            anchors.centerIn: parent
            font.pointSize: 12
            font.bold: true
            color: textColor
        }
        
        onOpened: notifySuccessPopupTimer.start()
    }

    // Error Popup
    Popup {
        id: notifyErrorPopup
        property alias popMessage: notifyErrorMessage.text

        background: Rectangle {
            implicitWidth: rootWindow.width
            implicitHeight: 60
            color: errorColor
        }
        y: (rootWindow.height - 60)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnPressOutside
        
        Text {
            id: notifyErrorMessage
            anchors.centerIn: parent
            font.pointSize: 12
            font.bold: true
            color: textColor
        }
        
        onOpened: notifyErrorPopupTimer.start()
    }

    // Wait/Loading Popup
    Popup {
        id: waitPopup
        property alias popMessage: waitMessage.text

        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.NoAutoClose
        modal: true

        background: Rectangle {
            implicitWidth: 300
            implicitHeight: 200
            color: mainAppColor
            radius: 20
            border.color: buttonColor
            border.width: 3
            
            BusyIndicator {
                id: busyIndicator
                running: true
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 30

                contentItem: Item {
                    implicitWidth: 64
                    implicitHeight: 64

                    Item {
                        id: item
                        x: parent.width / 2 - 32
                        y: parent.height / 2 - 32
                        width: 64
                        height: 64
                        opacity: busyIndicator.running ? 1 : 0

                        Behavior on opacity {
                            OpacityAnimator {
                                duration: 250
                            }
                        }

                        RotationAnimator {
                            target: item
                            running: busyIndicator.visible && busyIndicator.running
                            from: 0
                            to: 360
                            loops: Animation.Infinite
                            duration: 1250
                        }

                        Repeater {
                            id: repeater
                            model: 6

                            Rectangle {
                                x: item.width / 2 - width / 2
                                y: item.height / 2 - height / 2
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: "white"
                                transform: [
                                    Translate {
                                        y: -Math.min(item.width, item.height) * 0.5 + 5
                                    },
                                    Rotation {
                                        angle: index / repeater.count * 360
                                        origin.x: 5
                                        origin.y: 5
                                    }
                                ]
                            }
                        }
                    }
                }
            }

            Text {
                id: waitMessage
                width: parent.width - 40
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 12
                font.bold: true
                color: textColor
                wrapMode: Text.WordWrap
            }
        }

        onOpened: waitPopupTimer.start()
    }

    // Global Invitation Popup (handles invites from anywhere in the app)
    Dialog {
        id: globalInvitePopup
        anchors.centerIn: parent
        width: 400
        height: 250
        modal: true
        title: "Room Invitation"
        
        property int invitationId: 0
        property string fromUser: ""
        property string roomCode: ""
        
        background: Rectangle {
            color: "white"
            radius: 10
            border.color: "#5FC8FF"
            border.width: 3
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 20
            
            Text {
                text: globalInvitePopup.fromUser + " invited you to join"
                font.pixelSize: 18
                font.bold: true
                color: "#333"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "Room: " + globalInvitePopup.roomCode
                font.pixelSize: 16
                color: "#5FC8FF"
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Row {
                spacing: 20
                anchors.horizontalCenter: parent.horizontalCenter
                
                Rectangle {
                    width: 120
                    height: 50
                    radius: 25
                    color: "#4CAF50"
                    border.color: "#388E3C"
                    border.width: 2
                    
                    Text {
                        anchors.centerIn: parent
                        text: "ACCEPT"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (backEnd) {
                                backEnd.inviteResponse(globalInvitePopup.invitationId, true)
                            }
                            globalInvitePopup.close()
                        }
                    }
                }
                
                Rectangle {
                    width: 120
                    height: 50
                    radius: 25
                    color: "#FF5252"
                    border.color: "#D32F2F"
                    border.width: 2
                    
                    Text {
                        anchors.centerIn: parent
                        text: "DECLINE"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (backEnd) {
                                backEnd.inviteResponse(globalInvitePopup.invitationId, false)
                            }
                            globalInvitePopup.close()
                        }
                    }
                }
            }
        }
    }

    // Timers
    Timer {
        id: notifySuccessPopupTimer
        interval: 2000
        onTriggered: notifySuccessPopup.close()
    }

    Timer {
        id: notifyErrorPopupTimer
        interval: 2000
        onTriggered: notifyErrorPopup.close()
    }

    Timer {
        id: waitPopupTimer
        interval: 2000
        onTriggered: {
            waitPopup.close()
            
            if (currentAction === "connect") {
                if (connectionFailed) {
                    notifyErrorPopup.popMessage = "Không thể kết nối đến server!"
                    notifyErrorPopup.open()
                    Qt.quit()
                }
            }
            else if (currentAction === "signup") {
                if (signupStatus === "SIGNUP_SUCCESS") {
                    notifySuccessPopup.popMessage = "Đăng ký thành công!"
                    notifySuccessPopup.open()
                    stackView.pop()
                }
                else if (signupStatus === "ACCOUNT_EXIST") {
                    notifyErrorPopup.popMessage = "Tài khoản đã tồn tại!"
                    notifyErrorPopup.open()
                }
            }
        }
    }
}
