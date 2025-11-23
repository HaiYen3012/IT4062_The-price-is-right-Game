import QtQuick 2.12
import QtQuick.Controls 2.12

Page {
    id: homeGuest
    width: 800
    height: 600

    background: Rectangle {
        anchors.fill: parent
        color: rootWindow.backgroundColor

        // Animated sunburst background
        Canvas {
            id: sunburst
            anchors.fill: parent
            property real rotation: 0

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                
                var centerX = width / 2;
                var centerY = height / 2;
                var numRays = 24;
                
                for (var i = 0; i < numRays; i++) {
                    var angle = (i * (360 / numRays) + rotation) * Math.PI / 180;
                    var gradient = ctx.createLinearGradient(
                        centerX, centerY,
                        centerX + Math.cos(angle) * width,
                        centerY + Math.sin(angle) * height
                    );
                    
                    if (i % 2 === 0) {
                        gradient.addColorStop(0, "#0DCDFF");
                        gradient.addColorStop(1, "#FFFFFF");
                    } else {
                        gradient.addColorStop(0, "#0DCDFF");
                        gradient.addColorStop(1, "#0096C8");
                    }
                    
                    ctx.fillStyle = gradient;
                    ctx.beginPath();
                    ctx.moveTo(centerX, centerY);
                    
                    var angle1 = angle - (Math.PI / numRays);
                    var angle2 = angle + (Math.PI / numRays);
                    
                    ctx.lineTo(
                        centerX + Math.cos(angle1) * width * 2,
                        centerY + Math.sin(angle1) * height * 2
                    );
                    ctx.lineTo(
                        centerX + Math.cos(angle2) * width * 2,
                        centerY + Math.sin(angle2) * height * 2
                    );
                    ctx.closePath();
                    ctx.fill();
                }
            }

            Timer {
                interval: 50
                running: true
                repeat: true
                onTriggered: {
                    sunburst.rotation += 0.5;
                    if (sunburst.rotation >= 360) {
                        sunburst.rotation = 0;
                    }
                    sunburst.requestPaint();
                }
            }
        }
    }

    // Game Logo/Title
    Item {
        id: logoContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 80
        width: 650
        height: 220

        // Main title with gradient effect
        Column {
            anchors.centerIn: parent
            spacing: 5

            // THE PRICE
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                
                Text {
                    text: "THE"
                    font.pixelSize: 64
                    font.bold: true
                    font.family: "Arial Black, Impact, sans-serif"
                    color: "#FFD700"
                    style: Text.Outline
                    styleColor: "#FF4444"
                    
                    SequentialAnimation on scale {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 1.08; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.08; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
                }
                
                Text {
                    text: "PRICE"
                    font.pixelSize: 64
                    font.bold: true
                    font.family: "Arial Black, Impact, sans-serif"
                    color: "#FF4444"
                    style: Text.Outline
                    styleColor: "#FFD700"
                    
                    SequentialAnimation on scale {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 1.08; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.08; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: 100 }
                    }
                }
            }
            
            // IS RIGHT
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                
                Text {
                    text: "IS"
                    font.pixelSize: 64
                    font.bold: true
                    font.family: "Arial Black, Impact, sans-serif"
                    color: "#FFD700"
                    style: Text.Outline
                    styleColor: "#FF4444"
                    
                    SequentialAnimation on scale {
                        running: true
                        loops: Animation.Infinite
                        PauseAnimation { duration: 100 }
                        NumberAnimation { from: 1.0; to: 1.08; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.08; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
                }
                
                Text {
                    text: "RIGHT"
                    font.pixelSize: 64
                    font.bold: true
                    font.family: "Arial Black, Impact, sans-serif"
                    color: "#FF4444"
                    style: Text.Outline
                    styleColor: "#FFD700"
                    
                    SequentialAnimation on scale {
                        running: true
                        loops: Animation.Infinite
                        PauseAnimation { duration: 200 }
                        NumberAnimation { from: 1.0; to: 1.08; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.08; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }

        // Question mark decorations with animation
        Text {
            text: "?"
            font.pixelSize: 120
            font.bold: true
            color: "#FFD700"
            style: Text.Outline
            styleColor: "#FF4444"
            anchors.left: parent.left
            anchors.leftMargin: 0
            anchors.verticalCenter: parent.verticalCenter
            rotation: -15
            opacity: 0.8
            
            SequentialAnimation on rotation {
                running: true
                loops: Animation.Infinite
                NumberAnimation { from: -15; to: -20; duration: 1500; easing.type: Easing.InOutQuad }
                NumberAnimation { from: -20; to: -15; duration: 1500; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            text: "?"
            font.pixelSize: 120
            font.bold: true
            color: "#FF4444"
            style: Text.Outline
            styleColor: "#FFD700"
            anchors.right: parent.right
            anchors.rightMargin: 0
            anchors.verticalCenter: parent.verticalCenter
            rotation: 15
            opacity: 0.8
            
            SequentialAnimation on rotation {
                running: true
                loops: Animation.Infinite
                NumberAnimation { from: 15; to: 20; duration: 1500; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 20; to: 15; duration: 1500; easing.type: Easing.InOutQuad }
            }
        }
    }

    // Button Container
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 100
        spacing: 20

        // LOGIN Button
        Button {
            id: loginButton
            width: 300
            height: 70
            anchors.horizontalCenter: parent.horizontalCenter
            
            contentItem: Text {
                text: "LOGIN"
                font.pixelSize: 26
                font.bold: true
                color: rootWindow.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Rectangle {
                color: loginButton.pressed ? Qt.darker("#FF6B35", 1.2) : 
                       loginButton.hovered ? Qt.lighter("#FF6B35", 1.1) : 
                       "#FF6B35"
                radius: 15
                border.color: "#CC5529"
                border.width: 4
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    color: "transparent"
                    radius: 12
                    border.color: Qt.lighter("#FF6B35", 1.3)
                    border.width: 2
                }
                
                Behavior on color {
                    ColorAnimation { duration: 100 }
                }
            }
            
            onClicked: {
                stackView.push("qrc:/qml/SignInPage.qml")
            }
            
            scale: loginButton.pressed ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }

        // REGISTER Button
        Button {
            id: registerButton
            width: 300
            height: 70
            anchors.horizontalCenter: parent.horizontalCenter
            
            contentItem: Text {
                text: "REGISTER"
                font.pixelSize: 26
                font.bold: true
                color: rootWindow.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Rectangle {
                color: registerButton.pressed ? Qt.darker(rootWindow.buttonColor, 1.2) : 
                       registerButton.hovered ? Qt.lighter(rootWindow.buttonColor, 1.1) : 
                       rootWindow.buttonColor
                radius: 15
                border.color: "#004466"
                border.width: 4
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    color: "transparent"
                    radius: 12
                    border.color: Qt.lighter(rootWindow.buttonColor, 1.3)
                    border.width: 2
                }
                
                Behavior on color {
                    ColorAnimation { duration: 100 }
                }
            }
            
            onClicked: {
                stackView.push("qrc:/qml/RegisterPage.qml")
            }
            
            scale: registerButton.pressed ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }
    }
}
