import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property int selectedIndex: 0
    readonly property var replies: ["run", "edit", "discard"]
    readonly property var choices: ["Run with local agent", "Edit in input", "Discard"]
    Layout.fillWidth: true
    implicitHeight: visible ? body.implicitHeight + 16 : 0
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2
    focus: visible
    onVisibleChanged: if (visible) { selectedIndex = 0; forceActiveFocus(); }

    function move(delta) { selectedIndex = (selectedIndex + delta + 3) % 3; }
    function acceptSelected() { Ai.planDecision(replies[selectedIndex]); }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Up) move(-1);
        else if (event.key === Qt.Key_Down) move(1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) acceptSelected();
        else if (event.key === Qt.Key_Escape) Ai.planDecision("discard");
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_3) Ai.planDecision(replies[event.key - Qt.Key_1]);
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
                text: "Run this plan?"
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                font.weight: Font.Medium
                color: Appearance.m3colors.m3onSurface
            }
            StyledText {
                Layout.fillWidth: true
                text: "PLAN.md in " + Ai.agentDirectory
                elide: Text.ElideMiddle
                maximumLineCount: 1
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
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
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Ai.chatFontSize
                    color: Appearance.colors.colPrimary
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = choice.index
                    onClicked: Ai.planDecision(root.replies[choice.index])
                }
            }
        }
    }
}
