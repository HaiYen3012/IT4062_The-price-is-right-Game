import QtQuick 2.15
import QtQuick.Controls 2.15

Page {
    id: loginPage
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
        font.pixelSize: 70
        font.bold: true
        color: "#FFAA00"
        style: Text.Outline
        styleColor: "#FFFFFF"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 50
    }

    // Login Form Container
    Rectangle {
        id: loginForm
        width: 500
        height: 400
        anchors.centerIn: parent
        color: rootWindow.mainAppColor
        radius: 25
        border.color: rootWindow.buttonColor
        border.width: 4

        Column {
            anchors.centerIn: parent
            spacing: 25
            width: parent.width - 60

            // LOGIN Title
            Text {
                text: "LOGIN"
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
                    font.pixelSize: 16
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    color: "#FFFFFF"
                    radius: 10

                    TextField {
                        id: usernameField
                        anchors.fill: parent
                        anchors.margins: 5
                        font.pixelSize: 18
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
                    font.pixelSize: 16
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    color: "#FFFFFF"
                    radius: 10

                    TextField {
                        id: passwordField
                        anchors.fill: parent
                        anchors.margins: 5
                        font.pixelSize: 18
                        echoMode: TextInput.Password
                        placeholderText: ""
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            // Remember Checkbox
            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                CheckBox {
                    id: rememberCheckbox
                    checked: false
                    
                    indicator: Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 4
                        border.color: rootWindow.buttonColor
                        border.width: 2
                        color: rememberCheckbox.checked ? rootWindow.buttonColor : "#FFFFFF"

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            font.bold: true
                            visible: rememberCheckbox.checked
                        }
                    }
                }

                Text {
                    text: "REMEMBER"
                    font.pixelSize: 16
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
        anchors.bottomMargin: 60
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
                if (usernameField.text === "" || passwordField.text === "") {
                    notifyErrorPopup.popMessage = "Vui lòng nhập đầy đủ thông tin!"
                    notifyErrorPopup.open()
                } else {
                    rootWindow.currentAction = "login"
                    waitPopup.popMessage = "Đang đăng nhập..."
                    waitPopup.open()
                    backEnd.signIn(usernameField.text, passwordField.text)
                }
            }
            
            scale: confirmButton.pressed ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }
    }
}
