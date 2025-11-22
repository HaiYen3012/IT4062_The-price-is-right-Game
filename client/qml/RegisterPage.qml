import QtQuick 2.15
import QtQuick.Controls 2.15

Page {
    id: registerPage
    width: 800
    height: 600

    background: Rectangle {
        anchors.fill: parent
        color: rootWindow.backgroundColor
    }

    // Game Logo (smaller)
    Text {
        id: logoText
        text: "?"
        font.pixelSize: 60
        font.bold: true
        color: "#FF4444"
        style: Text.Outline
        styleColor: "#FFFFFF"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
    }

    // Register Form Container
    Rectangle {
        id: registerForm
        width: 500
        height: 480
        anchors.centerIn: parent
        color: rootWindow.mainAppColor
        radius: 25
        border.color: rootWindow.buttonColor
        border.width: 4

        Column {
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 60

            // REGISTER Title
            Text {
                text: "REGISTER"
                font.pixelSize: 32
                font.bold: true
                color: rootWindow.textColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Username Field
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: "USERNAME"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 45
                    color: "#FFFFFF"
                    radius: 10

                    TextField {
                        id: usernameField
                        anchors.fill: parent
                        anchors.margins: 5
                        font.pixelSize: 16
                        placeholderText: ""
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            // Email Field
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: "E-MAIL"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 45
                    color: "#FFFFFF"
                    radius: 10

                    TextField {
                        id: emailField
                        anchors.fill: parent
                        anchors.margins: 5
                        font.pixelSize: 16
                        placeholderText: ""
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            // Password Field
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: "PASSWORD"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 45
                    color: "#FFFFFF"
                    radius: 10

                    TextField {
                        id: passwordField
                        anchors.fill: parent
                        anchors.margins: 5
                        font.pixelSize: 16
                        echoMode: TextInput.Password
                        placeholderText: ""
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            // Confirm Password Field
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: "CONFIRM"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 45
                    color: "#FFFFFF"
                    radius: 10

                    TextField {
                        id: confirmPasswordField
                        anchors.fill: parent
                        anchors.margins: 5
                        font.pixelSize: 16
                        echoMode: TextInput.Password
                        placeholderText: ""
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            // Agreement Checkbox
            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                CheckBox {
                    id: agreementCheckbox
                    checked: false
                    
                    indicator: Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 4
                        border.color: rootWindow.buttonColor
                        border.width: 2
                        color: agreementCheckbox.checked ? rootWindow.buttonColor : "#FFFFFF"

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            font.bold: true
                            visible: agreementCheckbox.checked
                        }
                    }
                }

                Text {
                    text: "AGREEMENT"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // Bottom Buttons
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        spacing: 40

        // CANCEL Button
        Button {
            id: cancelButton
            width: 200
            height: 60
            
            contentItem: Text {
                text: "CANCEL"
                font.pixelSize: 20
                font.bold: true
                color: rootWindow.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Rectangle {
                color: cancelButton.pressed ? Qt.darker("#888888", 1.2) : 
                       cancelButton.hovered ? Qt.lighter("#888888", 1.1) : 
                       "#888888"
                radius: 15
                border.color: "#666666"
                border.width: 3
                
                Behavior on color {
                    ColorAnimation { duration: 100 }
                }
            }
            
            onClicked: {
                stackView.pop()
            }
            
            scale: cancelButton.pressed ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }

        // CONFIRM Button
        Button {
            id: confirmButton
            width: 200
            height: 60
            
            contentItem: Text {
                text: "CONFIRM"
                font.pixelSize: 20
                font.bold: true
                color: rootWindow.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Rectangle {
                color: confirmButton.pressed ? Qt.darker(rootWindow.buttonColor, 1.2) : 
                       confirmButton.hovered ? Qt.lighter(rootWindow.buttonColor, 1.1) : 
                       rootWindow.buttonColor
                radius: 15
                border.color: "#004466"
                border.width: 3
                
                Behavior on color {
                    ColorAnimation { duration: 100 }
                }
            }
            
            onClicked: {
                if (usernameField.text === "" || emailField.text === "" || 
                    passwordField.text === "" || confirmPasswordField.text === "") {
                    notifyErrorPopup.popMessage = "Vui lòng nhập đầy đủ thông tin!"
                    notifyErrorPopup.open()
                } else if (passwordField.text !== confirmPasswordField.text) {
                    notifyErrorPopup.popMessage = "Mật khẩu không khớp!"
                    notifyErrorPopup.open()
                } else if (!agreementCheckbox.checked) {
                    notifyErrorPopup.popMessage = "Vui lòng đồng ý với điều khoản!"
                    notifyErrorPopup.open()
                } else {
                    rootWindow.currentAction = "signup"
                    waitPopup.popMessage = "Đang đăng ký..."
                    waitPopup.open()
                    backEnd.signUp(usernameField.text, passwordField.text)
                }
            }
            
            scale: confirmButton.pressed ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }
    }
}
