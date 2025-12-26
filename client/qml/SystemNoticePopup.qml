import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: noticePopup
    width: 400
    height: 80
    color: "#1a1a1a"
    border.color: "#ffd700"
    border.width: 2
    radius: 10
    opacity: 0
    visible: false
    
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 80
    z: 1000
    
    property alias message: noticeText.text
    
    Text {
        id: noticeText
        anchors.centerIn: parent
        width: parent.width - 40
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        color: "#ffffff"
        font.pixelSize: 18
        font.bold: true
    }
    
    SequentialAnimation {
        id: showAnimation
        
        PropertyAction { target: noticePopup; property: "visible"; value: true }
        
        ParallelAnimation {
            NumberAnimation {
                target: noticePopup
                property: "opacity"
                from: 0
                to: 1
                duration: 300
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: noticePopup
                property: "anchors.topMargin"
                from: 50
                to: 80
                duration: 300
                easing.type: Easing.OutBack
            }
        }
        
        PauseAnimation { duration: 2000 }
        
        ParallelAnimation {
            NumberAnimation {
                target: noticePopup
                property: "opacity"
                from: 1
                to: 0
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }
        
        PropertyAction { target: noticePopup; property: "visible"; value: false }
    }
    
    function show(text) {
        message = text
        showAnimation.restart()
    }
}
