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
            stackView.push("qrc:/qml/HomeGuest.qml")
        }

        onConnectFail: {
            rootWindow.connectionFailed = true
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
           // notifySuccessPopup.popMessage = "Login successful! Welcome " + backEnd.user_name
            //notifySuccessPopup.open()
            // TODO: Navigate to main menu or game screen
            // stackView.push("qrc:/qml/MainMenu.qml")
            stackView.push("qrc:/qml/RoomV1.qml")
        }

        onAccountNotExist: {
            waitPopup.close()
            rootWindow.loginStatus = "ACCOUNT_NOT_EXIST"
            notifyErrorPopup.popMessage = "Account does not exist!"
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
