import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// One numbered choice of a docked prompt: "❯ 1. Yes". The cursor row is accent.
Item {
    id: root
    property int number: 1
    property string label: ""
    property bool selected: false
    signal hovered()
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: text.implicitHeight + 4

    StyledText {
        id: text
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        wrapMode: Text.Wrap
        font.family: Appearance.font.family.monospace
        font.pixelSize: Ai.chatFontSize
        color: root.selected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
        text: `${root.selected ? "❯" : " "} <font color="${Appearance.colors.colSubtext}">${root.number}.</font> ${root.label}`
        textFormat: Text.StyledText
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.clicked()
    }
}
