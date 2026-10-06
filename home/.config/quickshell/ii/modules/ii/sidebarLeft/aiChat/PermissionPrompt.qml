import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property var messageData
    property var request: messageData?.requestData ?? {}
    property int selectedIndex: 0
    readonly property var replies: ["once", "always", "reject"]
    readonly property var choices: ["yes", "yes, and don't ask again", "no"]
    Layout.fillWidth: true
    implicitHeight: visible ? body.implicitHeight + 16 : 0
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2
    focus: visible
    onVisibleChanged: if (visible) forceActiveFocus()
    onMessageDataChanged: {
        selectedIndex = 0;
        if (messageData) forceActiveFocus();
    }

    function move(delta) { selectedIndex = (selectedIndex + delta + 3) % 3; }
    function acceptSelected() { if (messageData) Ai.answerPermission(messageData, replies[selectedIndex]); }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Up) move(-1);
        else if (event.key === Qt.Key_Down) move(1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) acceptSelected();
        else if (event.key === Qt.Key_Escape) Ai.answerPermission(messageData, "reject");
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_3) Ai.answerPermission(messageData, replies[event.key - Qt.Key_1]);
        else return;
        event.accepted = true;
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 3
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            StyledText {
                text: `Allow ${root.request.permission ?? "action"}?`
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.m3colors.m3onSurface
            }
            StyledText {
                Layout.fillWidth: true
                text: (root.request.patterns ?? []).join(", ")
                elide: Text.ElideMiddle
                maximumLineCount: 1
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }
        Repeater {
            model: root.choices
            delegate: Rectangle {
                id: choice
                required property int index
                required property string modelData
                Layout.fillWidth: true
                implicitHeight: label.implicitHeight + 8
                radius: Appearance.rounding.verysmall
                color: index === root.selectedIndex ? Appearance.colors.colSecondaryContainer : "transparent"
                StyledText {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    text: choice.modelData
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colPrimary
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = choice.index
                    onClicked: Ai.answerPermission(root.messageData, root.replies[choice.index])
                }
            }
        }
    }
}
