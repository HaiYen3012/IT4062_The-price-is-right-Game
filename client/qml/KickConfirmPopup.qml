import QtQuick 2.12
import QtQuick.Controls 2.12

// Kick Confirmation Popup
Rectangle {
    id: kickPopup
    anchors.fill: parent
    color: "#80000000"
    visible: false
    z: 100
    
    property string targetUsername: ""
    property var backend: null
    
    signal confirmed()
    signal cancelled()
    
    MouseArea {
        anchors.fill: parent
        onClicked: {
            // Prevent clicks from passing through
        }
    }
    
    Rectangle {
        width: 400
        height: 250
        anchors.centerIn: parent
        radius: 20
        color: "#FFFFFF"
        border.color: "#FF5252"
        border.width: 4
        
        Column {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20
            
            // Warning Icon
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "⚠️"
                font.pixelSize: 50
            }
            
            // Title
            Text {
                width: parent.width
                text: "Kick Player"
                font.pixelSize: 24
                font.bold: true
                color: "#FF5252"
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Message
            Text {
                width: parent.width
                text: "Are you sure you want to kick\n\"" + targetUsername + "\" from the room?"
                font.pixelSize: 16
                color: "#333333"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            
            // Buttons Row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                
                // Cancel Button
                Rectangle {
                    width: 120
                    height: 45
                    radius: 22
                    color: "#90A4AE"
                    border.color: "#607D8B"
                    border.width: 3
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            kickPopup.visible = false
                            cancelled()
                        }
                    }
                }
                
                // Confirm Kick Button
                Rectangle {
                    width: 120
                    height: 45
                    radius: 22
                    color: "#FF5252"
                    border.color: "#D32F2F"
                    border.width: 3
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Kick"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (backend && targetUsername !== "") {
                                backend.kickUser(targetUsername)
                            }
                            kickPopup.visible = false
                            confirmed()
                        }
                    }
                }
            }
        }
    }
    
    function show(username) {
        targetUsername = username
        visible = true
    }
    
    function hide() {
        visible = false
    }
}
