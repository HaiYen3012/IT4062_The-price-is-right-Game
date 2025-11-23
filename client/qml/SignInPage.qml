import QtQuick 2.12
import QtQuick.Controls 2.12

Page {
    id: signInPage
    width: 800
    height: 600

    property bool showPassword: false

    background: Rectangle {
        anchors.fill: parent
        color: rootWindow.backgroundColor
    }

    // Game Logo (smaller)
    Text {
        id: logoText
        text: "?"
        font.pixelSize: 50
        font.bold: true
        color: "#FF4444"
        style: Text.Outline
        styleColor: "#FFFFFF"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
    }

    // Login Form Container
    Rectangle {
        id: loginForm
        width: 500
        height: 320
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logoText.bottom
        anchors.topMargin: 30
        color: rootWindow.mainAppColor
        radius: 25
        border.color: rootWindow.buttonColor
        border.width: 4

        Column {
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18
            width: parent.width - 60

            // SIGN IN Title
            Text {
                text: "SIGN IN"
                font.pixelSize: 32
                font.bold: true
                color: rootWindow.textColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Username Field
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "USERNAME"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    color: "#FFFFFF"
                    radius: 12

                    TextField {
                        id: usernameField
                        anchors.fill: parent
                        anchors.margins: 8
                        font.pixelSize: 16
                        placeholderText: "Enter your username"
                        placeholderTextColor: "#999999"
                        color: "#333333"
                        selectByMouse: true
                        background: Rectangle {
                            color: "transparent"
                        }

                        Keys.onReturnPressed: {
                            if (text.length > 0 && passwordField.text.length > 0) {
                                loginButton.clicked()
                            } else if (text.length > 0) {
                                passwordField.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // Password Field
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "PASSWORD"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    color: "#FFFFFF"
                    radius: 12

                    TextField {
                        id: passwordField
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 50
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        font.pixelSize: 16
                        placeholderText: "Enter your password"
                        placeholderTextColor: "#999999"
                        color: "#333333"
                        echoMode: showPassword ? TextInput.Normal : TextInput.Password
                        selectByMouse: true
                        background: Rectangle {
                            color: "transparent"
                        }

                        Keys.onReturnPressed: {
                            if (usernameField.text.length > 0 && text.length > 0) {
                                loginButton.clicked()
                            }
                        }
                    }

                    // Show/Hide Password Button
                    Rectangle {
                        id: eyeButton
                        width: 40
                        height: 40
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        visible: passwordField.text.length > 0

                        Text {
                            text: showPassword ? "👁" : "👁‍🗨"
                            font.pixelSize: 24
                            anchors.centerIn: parent
                            color: "#666666"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                showPassword = !showPassword
                            }
                        }

                        // Hover effect
                        Rectangle {
                            anchors.fill: parent
                            color: "#E0E0E0"
                            radius: 8
                            opacity: eyeMouseArea.containsMouse ? 0.3 : 0
                        }

                        HoverHandler {
                            id: eyeMouseArea
                        }
                    }
                }
            }

            // Remember me and Forgot password row
            Row {
                width: parent.width
                height: 30
                spacing: 0

                CheckBox {
                    id: rememberCheckbox
                    checked: false
                    width: parent.width / 2
                    height: parent.height
                    
                    indicator: Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        x: rememberCheckbox.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 4
                        border.color: rootWindow.textColor
                        border.width: 2
                        color: rememberCheckbox.checked ? rootWindow.buttonColor : "#FFFFFF"

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "#FFFFFF"
                            font.pixelSize: 14
                            font.bold: true
                            visible: rememberCheckbox.checked
                        }
                    }

                    contentItem: Text {
                        text: "Remember me"
                        font.pixelSize: 12
                        color: rootWindow.textColor
                        leftPadding: rememberCheckbox.indicator.width + rememberCheckbox.spacing
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Item {
                    width: parent.width / 2
                    height: parent.height

                    Text {
                        text: "Forgot Password?"
                        font.pixelSize: 12
                        font.underline: forgotPasswordMA.containsMouse
                        color: rootWindow.textColor
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            id: forgotPasswordMA
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                notifyErrorPopup.popMessage = "Feature coming soon!"
                                notifyErrorPopup.open()
                            }
                        }
                    }
                }
            }
        }
    }

    // Bottom Buttons
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: loginForm.bottom
        anchors.topMargin: 30
        spacing: 40

        // CANCEL Button
        Button {
            id: cancelButton
            width: 180
            height: 50
            
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
                border.width: 2
            }
            
            onClicked: {
                stackView.pop()
            }
        }

        // LOGIN Button
        Button {
            id: loginButton
            width: 180
            height: 50
            enabled: usernameField.text.length > 0 && passwordField.text.length > 0
            
            contentItem: Text {
                text: "LOGIN"
                font.pixelSize: 20
                font.bold: true
                color: rootWindow.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Rectangle {
                color: !loginButton.enabled ? "#CCCCCC" :
                       loginButton.pressed ? Qt.darker(rootWindow.buttonColor, 1.3) : 
                       loginButton.hovered ? Qt.lighter(rootWindow.buttonColor, 1.2) : 
                       rootWindow.buttonColor
                radius: 15
                border.color: !loginButton.enabled ? "#999999" : "#004466"
                border.width: 2
            }
            
            onClicked: {
                if (usernameField.text.length === 0) {
                    notifyErrorPopup.popMessage = "Please enter username!"
                    notifyErrorPopup.open()
                    return
                }
                
                if (passwordField.text.length === 0) {
                    notifyErrorPopup.popMessage = "Please enter password!"
                    notifyErrorPopup.open()
                    return
                }

                // Show loading
                rootWindow.currentAction = "login"
                waitPopup.popMessage = "Logging in..."
                waitPopup.open()
                
                // Call backend
                backEnd.login(usernameField.text, passwordField.text)
            }
        }
    }

    // Bottom text - link to register
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        spacing: 5

        Text {
            text: "Don't have an account?"
            font.pixelSize: 14
            color: rootWindow.textColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "Sign Up"
            font.pixelSize: 14
            font.bold: true
            font.underline: registerLinkMA.containsMouse
            color: rootWindow.buttonColor
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                id: registerLinkMA
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    stackView.push("qrc:/qml/RegisterPage.qml")
                }
            }
        }
    }

    // Set focus to username field when page loads
    Component.onCompleted: {
        usernameField.forceActiveFocus()
    }
}
