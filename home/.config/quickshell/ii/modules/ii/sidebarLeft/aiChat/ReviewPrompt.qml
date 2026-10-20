import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property int selectedIndex: 0
    readonly property var proposal: Ai.reviewCurrent
    readonly property var replies: ["apply", "skip", "stop"]
    readonly property var choices: ["Apply", "Skip", "Stop (keep the rest pending)"]
    Layout.fillWidth: true
    implicitHeight: visible ? body.implicitHeight + 16 : 0
    color: Appearance.colors.colLayer2
    focus: visible
    onVisibleChanged: if (visible) { selectedIndex = 0; forceActiveFocus(); }
    onProposalChanged: selectedIndex = 0

    function move(delta) { selectedIndex = (selectedIndex + delta + 3) % 3; }
    function acceptSelected() { Ai.reviewDecision(replies[selectedIndex]); }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Up) move(-1);
        else if (event.key === Qt.Key_Down) move(1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) acceptSelected();
        else if (event.key === Qt.Key_Escape) Ai.reviewDecision("stop");
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_3) Ai.reviewDecision(replies[event.key - Qt.Key_1]);
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
            Layout.fillWidth: true
            text: root.proposal?.title ?? ""
            wrapMode: Text.Wrap
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            font.weight: Font.Bold
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            text: `${root.proposal?.kind ?? ""} · ${root.proposal?.action ?? ""} · ${root.proposal?.target ?? ""}`
            elide: Text.ElideMiddle
            maximumLineCount: 1
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            text: root.proposal?.why ?? ""
            wrapMode: Text.Wrap
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            text: root.proposal?.preview ?? ""
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
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
                onClicked: Ai.reviewDecision(root.replies[index])
            }
        }
        StyledText {
            text: "esc to stop"
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: Appearance.colors.colSubtext
        }
    }
}
