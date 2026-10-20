import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property int selectedIndex: 1
    readonly property var proposal: Ai.reviewCurrent
    readonly property var replies: ["apply", "skip", "stop"]
    readonly property var choices: ["Apply", "Skip", "Stop (keep the rest pending)"]
    Layout.fillWidth: true
    implicitHeight: visible ? body.implicitHeight + 16 : 0
    color: Appearance.colors.colLayer2
    onVisibleChanged: if (visible) selectedIndex = 1
    onProposalChanged: selectedIndex = 1

    function move(delta) { selectedIndex = (selectedIndex + delta + 3) % 3; }
    function acceptSelected() { Ai.reviewDecision(replies[selectedIndex]); }

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
        StyledFlickable {
            id: previewFlick
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            Layout.preferredHeight: Math.min(previewText.implicitHeight, previewText.font.pixelSize * 1.6 * 12)
            contentWidth: width
            contentHeight: previewText.implicitHeight
            clip: true
            StyledText {
                id: previewText
                width: previewFlick.width
                text: root.proposal?.preview ?? ""
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                color: Appearance.colors.colSubtext
            }
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
