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

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 2
        color: Appearance.colors.colPrimary
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        anchors.topMargin: 10
        spacing: 3
        StyledText {
            text: "Run this plan?"
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            font.weight: Font.Bold
            color: Appearance.colors.colPrimary
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
        Repeater {
            model: root.choices
            delegate: PromptOption {
                required property int index
                required property string modelData
                number: index + 1
                label: modelData
                selected: index === root.selectedIndex
                onHovered: root.selectedIndex = index
                onClicked: Ai.planDecision(root.replies[index])
            }
        }
        StyledText {
            text: "esc to cancel"
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: Appearance.colors.colSubtext
        }
    }
}
