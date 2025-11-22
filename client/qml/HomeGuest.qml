import QtQuick 2.15
import QtQuick.Controls 2.15

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
        anchors.topMargin: 100
        width: 500
        height: 200

        // Multi-line colored title
        Column {
            anchors.centerIn: parent
            spacing: -10

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 15
                
                Text {
                    text: "HÃY"
                    font.pixelSize: 48
                    font.bold: true
                    font.family: "Arial"
                    color: "#FF4444"
                    style: Text.Outline
                    styleColor: "#FFFFFF"
                }
                Text {
                    text: "CHỌN"
                    font.pixelSize: 48
                    font.bold: true
                    font.family: "Arial"
                    color: "#FFAA00"
                    style: Text.Outline
                    styleColor: "#FFFFFF"
                }
            }
            
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 15
                
                Text {
                    text: "GIÁ"
                    font.pixelSize: 48
                    font.bold: true
                    font.family: "Arial"
                    color: "#FF4444"
                    style: Text.Outline
                    styleColor: "#FFFFFF"
                }
                Text {
                    text: "ĐÚNG"
                    font.pixelSize: 48
                    font.bold: true
                    font.family: "Arial"
                    color: "#FFAA00"
                    style: Text.Outline
                    styleColor: "#FFFFFF"
                }
            }
        }

        // Question mark decoration
        Text {
            text: "?"
            font.pixelSize: 100
            font.bold: true
            color: "#FFAA00"
            style: Text.Outline
            styleColor: "#FFFFFF"
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            rotation: -15
        }

        Text {
            text: "?"
            font.pixelSize: 100
            font.bold: true
            color: "#FF4444"
            style: Text.Outline
            styleColor: "#FFFFFF"
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            rotation: 15
        }
    }

    // REGISTER Button (centered)
    Button {
        id: registerButton
        width: 300
        height: 80
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 120
        
        contentItem: Text {
            text: "REGISTER"
            font.pixelSize: 28
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
