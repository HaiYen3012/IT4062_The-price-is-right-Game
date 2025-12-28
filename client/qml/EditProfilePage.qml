import QtQuick 2.12
import QtQuick.Controls 2.12

Page {
    id: editProfilePage
    width: 800
    height: 600

    property var backend: null
    property var stackView: null

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
        anchors.topMargin: 15
    }

    // Edit Profile Form Container
    Rectangle {
        id: editForm
        width: 500
        height: 400
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logoText.bottom
        anchors.topMargin: 10
        color: rootWindow.mainAppColor
        radius: 25
        border.color: rootWindow.buttonColor
        border.width: 4

        Column {
            anchors.top: parent.top
            anchors.topMargin: 15
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            width: parent.width - 60

            // EDIT PROFILE Title
            Text {
                text: "EDIT PROFILE"
                font.pixelSize: 28
                font.bold: true
                color: rootWindow.textColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Current Username Display
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: "CURRENT USERNAME"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#E0E0E0"
                    radius: 10

                    Text {
                        anchors.centerIn: parent
                        text: backend ? backend.user_name : ""
                        font.pixelSize: 14
                        font.bold: true
                        color: "#666666"
                    }
                }
            }

            // New Username Field
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: "NEW USERNAME (leave empty to keep current)"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#FFFFFF"
                    radius: 10

                    TextField {
                        id: newUsernameField
                        anchors.fill: parent
                        anchors.margins: 5
                        font.pixelSize: 14
                        placeholderText: "Enter new username..."
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            // New Password Field
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: "NEW PASSWORD (leave empty to keep current)"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#FFFFFF"
                    radius: 10

                    TextField {
                        id: newPasswordField
                        anchors.fill: parent
                        anchors.margins: 5
                        font.pixelSize: 14
                        echoMode: TextInput.Password
                        placeholderText: "Enter new password..."
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
                    text: "CONFIRM PASSWORD"
                    font.pixelSize: 14
                    font.bold: true
                    color: rootWindow.textColor
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#FFFFFF"
                    radius: 10

                    TextField {
                        id: confirmPasswordField
                        anchors.fill: parent
                        anchors.margins: 5
                        font.pixelSize: 14
                        echoMode: TextInput.Password
                        placeholderText: "Re-enter password..."
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }
        }
    }

    // Bottom Buttons
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: editForm.bottom
        anchors.topMargin: 15
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
                border.width: 3
                
                Behavior on color {
                    ColorAnimation { duration: 100 }
                }
            }
            
            onClicked: {
                if (stackView) stackView.pop()
            }
            
            scale: cancelButton.pressed ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }

        // UPDATE Button
        Button {
            id: updateButton
            width: 180
            height: 50
            
            contentItem: Text {
                text: "UPDATE"
                font.pixelSize: 20
                font.bold: true
                color: rootWindow.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Rectangle {
                color: updateButton.pressed ? Qt.darker(rootWindow.buttonColor, 1.2) : 
                       updateButton.hovered ? Qt.lighter(rootWindow.buttonColor, 1.1) : 
                       rootWindow.buttonColor
                radius: 15
                border.color: "#004466"
                border.width: 3
                
                Behavior on color {
                    ColorAnimation { duration: 100 }
                }
            }
            
            onClicked: {
                var newUser = newUsernameField.text.trim()
                var newPass = newPasswordField.text
                var confirmPass = confirmPasswordField.text
                
                // Validate input - must change at least one thing
                if (newUser === "" && newPass === "") {
                    notifyErrorPopup.popMessage = "Please change at least one field!"
                    notifyErrorPopup.open()
                    return
                }
                
                // If password fields are filled, they must match
                if (newPass !== "" || confirmPass !== "") {
                    if (newPass !== confirmPass) {
                        notifyErrorPopup.popMessage = "Passwords do not match!"
                        notifyErrorPopup.open()
                        return
                    }
                    
                    if (newPass.length < 6) {
                        notifyErrorPopup.popMessage = "Password must be at least 6 characters!"
                        notifyErrorPopup.open()
                        return
                    }
                }
                
                // Prepare final values
                var finalUsername = newUser === "" ? backend.user_name : newUser
                var finalPassword = newPass === "" ? backend.user_name : newPass
                
                if (backend) {
                    rootWindow.currentAction = "editprofile"
                    waitPopup.popMessage = "Updating..."
                    waitPopup.open()
                    backend.editProfile(finalUsername, finalPassword)
                }
            }
            
            scale: updateButton.pressed ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }
    }

    // Connections to backend signals
    Connections {
        target: backend
        function onEditProfileSuccess() {
            if (typeof waitPopup !== 'undefined' && waitPopup.visible) waitPopup.close();
            if (typeof updating !== 'undefined') updating = false;
            editProfilePage.message = "Cập nhật thành công!";
            if (typeof homeUser !== 'undefined') homeUser.userName = backend.user_name;
            if (typeof homeUser !== 'undefined' && typeof homeUser.notifySuccessPopup !== 'undefined') {
                homeUser.notifySuccessPopup.popMessage = "Cập nhật thành công!";
                homeUser.notifySuccessPopup.open();
            }
            if (typeof stackView !== 'undefined') {
                stackView.pop();
            }
        }
        function onEditProfileFail() {
            if (typeof waitPopup !== 'undefined' && waitPopup.visible) waitPopup.close();
            if (typeof updating !== 'undefined') updating = false;
            editProfilePage.message = "Cập nhật thất bại!";
            if (typeof homeUser !== 'undefined' && typeof homeUser.notifyErrorPopup !== 'undefined') {
                homeUser.notifyErrorPopup.popMessage = "Cập nhật thất bại!";
                homeUser.notifyErrorPopup.open();
            }
        }
    }

    // Success Popup
    Popup {
        id: notifySuccessPopup
        property string popMessage: ""
        x: (parent.width - 400) / 2
        y: (parent.height - 120) / 2
        width: 400
        height: 120
        modal: true
        closePolicy: Popup.NoAutoClose
        
        background: Rectangle {
            color: "#4CAF50"
            radius: 16
            border.color: "#388E3C"
            border.width: 3
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 10
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "✓"
                color: "white"
                font.pixelSize: 36
                font.bold: true
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: notifySuccessPopup.popMessage
                color: "white"
                font.pixelSize: 18
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Error Popup
    Popup {
        id: notifyErrorPopup
        property string popMessage: ""
        x: (parent.width - 400) / 2
        y: (parent.height - 120) / 2
        width: 400
        height: 120
        modal: true
        
        background: Rectangle {
            color: "#FF5252"
            radius: 16
            border.color: "#D32F2F"
            border.width: 3
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 10
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "✗"
                color: "white"
                font.pixelSize: 36
                font.bold: true
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: notifyErrorPopup.popMessage
                color: "white"
                font.pixelSize: 18
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width - 40
            }
        }
        
        Timer {
            interval: 2500
            running: notifyErrorPopup.visible
            onTriggered: notifyErrorPopup.close()
        }
    }

    // Wait Popup
    Popup {
        id: waitPopup
        property string popMessage: "Processing..."
        x: (parent.width - 300) / 2
        y: (parent.height - 100) / 2
        width: 300
        height: 100
        modal: true
        closePolicy: Popup.NoAutoClose
        
        background: Rectangle {
            color: rootWindow.buttonColor
            radius: 16
            border.color: "#004466"
            border.width: 3
        }
        
        Text {
            anchors.centerIn: parent
            text: waitPopup.popMessage
            color: "white"
            font.pixelSize: 18
            font.bold: true
        }
    }

    // Timer to go back after success
    Timer {
        id: backTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: {
            console.log("Back timer triggered, popping to home")
            notifySuccessPopup.close()
            if (stackView) {
                stackView.pop()
            }
        }
    }
}