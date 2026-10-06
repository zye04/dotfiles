pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// local-suite: Claude Code-style reasoning line. A dim "∗ Thought for 2.1s" (or
// "∗ Thinking…") in the same font and padding as the message text; click to show
// the reasoning, indented and dimmed.
Item {
    id: root
    // These are needed on the parent loader
    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ({})
    property var messageData: {}
    property bool done: true
    property bool completed: false

    property bool collapsed: true
    readonly property var firstTextItem: header // lets AiMessage centre its bullet on this line

    Layout.fillWidth: true
    implicitHeight: columnLayout.implicitHeight

    function headerText() {
        if (!root.completed) return Translation.tr("∗ Thinking…");
        const m = root.messageData;
        const secs = (m?.thoughtEndedAt > 0 && m?.startedAt > 0) ? ((m.thoughtEndedAt - m.startedAt) / 1000).toFixed(1) : "";
        const label = secs.length > 0 ? Translation.tr("∗ Thought for %1s").arg(secs) : Translation.tr("∗ Thought");
        return label + (root.collapsed ? "  ▸" : "  ▾");
    }

    ColumnLayout {
        id: columnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        TextArea { // Same control as the message text, so line height and padding match
            id: header
            Layout.fillWidth: true
            readOnly: true
            selectByMouse: false
            background: null
            text: root.headerText()
            renderType: Text.NativeRendering
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: headerMouse.containsMouse && root.completed ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                enabled: root.completed
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.collapsed = !root.collapsed
            }
        }

        Item { // Reasoning text, shown when expanded
            id: contentWrapper
            Layout.fillWidth: true
            Layout.leftMargin: 12
            implicitHeight: root.collapsed ? 0 : messageTextBlock.implicitHeight
            visible: !root.collapsed
            opacity: 0.7

            // Load data for the message at the correct scope
            property bool editing: root.editing
            property bool renderMarkdown: root.renderMarkdown
            property bool enableMouseSelection: root.enableMouseSelection
            property var messageData: root.messageData
            property bool done: root.done

            MessageTextBlock {
                id: messageTextBlock
                anchors.left: parent.left
                anchors.right: parent.right
                segmentContent: root.segmentContent
                enableMouseSelection: root.enableMouseSelection
                messageData: root.messageData
                done: root.done
            }
        }
    }
}
