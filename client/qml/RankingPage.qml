import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

Page {
    id: rankingPage
    width: 800
    height: 600
    
    property var backend: null
    property var rankings: []
    
    // Animated gradient background
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#667EEA" }
            GradientStop { position: 0.5; color: "#764BA2" }
            GradientStop { position: 1.0; color: "#F093FB" }
        }
        
        // Animated circles
        Rectangle {
            width: 300
            height: 300
            radius: 150
            color: "#33FFFFFF"
            x: parent.width * 0.1
            y: parent.height * 0.2
            
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 2000 }
                NumberAnimation { to: 0.1; duration: 2000 }
            }
        }
        
        Rectangle {
            width: 250
            height: 250
            radius: 125
            color: "#33FFFFFF"
            x: parent.width * 0.7
            y: parent.height * 0.6
            
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 2500 }
                NumberAnimation { to: 0.05; duration: 2500 }
            }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 20
        
        // Title with Trophy
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "transparent"
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "🏆"
                    font.pixelSize: 60
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "FINAL RANKING"
                    font.pixelSize: 36
                    font.bold: true
                    color: "white"
                    style: Text.Outline
                    styleColor: "#4A5568"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
        
        // Rankings List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1F2937"
            radius: 15
            border.color: "#4B5563"
            border.width: 2
            
            ListView {
                id: rankingListView
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                clip: true
                
                model: rankings
                
                delegate: Rectangle {
                    width: rankingListView.width
                    height: 80
                    radius: 10
                    
                    // Medal colors for top 3
                    gradient: Gradient {
                        GradientStop { 
                            position: 0.0
                            color: {
                                if (modelData.rank === 1) return "#FFD700";  // Gold
                                if (modelData.rank === 2) return "#C0C0C0";  // Silver
                                if (modelData.rank === 3) return "#CD7F32";  // Bronze
                                return "#374151";  // Gray for others
                            }
                        }
                        GradientStop { 
                            position: 1.0
                            color: {
                                if (modelData.rank === 1) return "#FFA500";
                                if (modelData.rank === 2) return "#A8A8A8";
                                if (modelData.rank === 3) return "#8B4513";
                                return "#1F2937";
                            }
                        }
                    }
                    
                    border.color: {
                        if (modelData.rank === 1) return "#FFD700";
                        if (modelData.rank === 2) return "#C0C0C0";
                        if (modelData.rank === 3) return "#CD7F32";
                        return "#4B5563";
                    }
                    border.width: 3
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15
                        
                        // Rank with Medal
                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 60
                            radius: 30
                            color: modelData.rank <= 3 ? "#1F2937" : "#4B5563"
                            border.color: "white"
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0
                                
                                Text {
                                    text: {
                                        if (modelData.rank === 1) return "🥇";
                                        if (modelData.rank === 2) return "🥈";
                                        if (modelData.rank === 3) return "🥉";
                                        return "#" + modelData.rank;
                                    }
                                    font.pixelSize: modelData.rank <= 3 ? 32 : 24
                                    font.bold: true
                                    color: "white"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                        
                        // Username
                        Text {
                            text: modelData.username
                            font.pixelSize: 24
                            font.bold: true
                            color: modelData.rank <= 3 ? "#1F2937" : "white"
                            Layout.fillWidth: true
                        }
                        
                        // Score Badge
                        Rectangle {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 50
                            radius: 25
                            color: "#10B981"
                            border.color: "#059669"
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0
                                
                                Text {
                                    text: modelData.total_score
                                    font.pixelSize: 22
                                    font.bold: true
                                    color: "white"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: "points"
                                    font.pixelSize: 10
                                    color: "white"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                    
                    // Scale animation on appear
                    scale: 0
                    opacity: 0
                    Component.onCompleted: {
                        scaleAnim.start()
                        opacityAnim.start()
                    }
                    
                    NumberAnimation {
                        id: scaleAnim
                        target: parent
                        property: "scale"
                        from: 0
                        to: 1
                        duration: 500
                        easing.type: Easing.OutBack
                    }
                    
                    NumberAnimation {
                        id: opacityAnim
                        target: parent
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 500
                    }
                }
            }
        }
        
        // Back Button
        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50
            
            background: Rectangle {
                radius: 25
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3B82F6" }
                    GradientStop { position: 1.0; color: "#2563EB" }
                }
                border.color: "white"
                border.width: 2
            }
            
            contentItem: Text {
                text: "Back to Home"
                font.pixelSize: 18
                font.bold: true
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                stackView.pop(null);  // Go back to home
            }
        }
    }
}
