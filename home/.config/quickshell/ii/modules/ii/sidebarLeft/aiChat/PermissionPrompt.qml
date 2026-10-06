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
    readonly property string kind: request.permission ?? "action"
    readonly property var always: request.always ?? []
    readonly property string alwaysPattern: always.length === 0 || always[0] === "*" ? `all ${kind} requests` : always.join(", ")
    readonly property string title: kind === "edit" ? "Edit file" : kind === "bash" ? "Run command" :
        kind === "read" || kind === "external_directory" ? "Read outside project" : kind.charAt(0).toUpperCase() + kind.slice(1).replace(/_/g, " ")
    readonly property string target: request.metadata?.filepath ?? (request.patterns ?? []).join(", ")
    readonly property int maxDiffLines: 12
    // Hunk lines only: drop the Index/===/---/+++ header and the "\ No newline" notes.
    readonly property var diffLines: {
        const all = String(request.metadata?.diff ?? "").split("\n");
        const start = all.findIndex(l => l.startsWith("@@"));
        return start < 0 ? [] : all.slice(start + 1).filter(l => l.length > 0 && !l.startsWith("\\"));
    }
    readonly property var choices: [
        "Yes",
        `Yes, and don't ask again for ${alwaysPattern}`,
        "No, tell the agent what to do differently"
    ]
    Layout.fillWidth: true
    implicitHeight: visible ? body.implicitHeight + 16 : 0
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
            text: root.title
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            font.weight: Font.Bold
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            text: root.target
            elide: Text.ElideMiddle
            maximumLineCount: 1
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: Appearance.colors.colSubtext
        }
        ColumnLayout {
            visible: root.diffLines.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 3
            Layout.bottomMargin: 3
            spacing: 0
            Repeater {
                model: root.diffLines.slice(0, root.maxDiffLines)
                delegate: Rectangle {
                    id: diffRow
                    required property string modelData
                    readonly property bool added: modelData.startsWith("+")
                    readonly property bool removed: modelData.startsWith("-")
                    Layout.fillWidth: true
                    implicitHeight: diffText.implicitHeight
                    // m3success is a pastel that reads grey on dark themes, so use fixed saturated tints
                    color: added ? Qt.rgba(0.2, 0.75, 0.3, 0.3) : removed ? Qt.rgba(0.9, 0.25, 0.25, 0.3) : "transparent"
                    StyledText {
                        id: diffText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 4
                        text: diffRow.modelData
                        wrapMode: Text.Wrap
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
                        color: diffRow.added || diffRow.removed ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                    }
                }
            }
            StyledText {
                visible: root.diffLines.length > root.maxDiffLines
                text: `… +${root.diffLines.length - root.maxDiffLines} lines`
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
                onClicked: Ai.answerPermission(root.messageData, root.replies[index])
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
