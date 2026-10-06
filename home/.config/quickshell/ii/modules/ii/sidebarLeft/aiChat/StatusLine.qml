import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Live status under the transcript: "✢ Thinking… (4s · ↓ 331 tokens · esc to interrupt)".
// Pinned between the list and the input, so it never scrolls away. It keeps its height when idle.
Item {
    id: root
    readonly property bool active: Ai.busy && Ai.liveState !== "idle"
    readonly property var glyphs: ["·", "✢", "✳", "✶", "✻", "✽", "*"]
    readonly property string verb: ({ thinking: "Thinking", streaming: "Writing", tool: "Working", waiting: "Waiting for you" })[Ai.liveState] ?? "Working"
    property int tick: 0
    readonly property int elapsed: Ai.turnStartedAt > 0 ? Math.max(0, Math.floor((Date.now() - Ai.turnStartedAt) / 1000)) + 0 * tick : 0

    Layout.fillWidth: true
    implicitHeight: label.implicitHeight + 2

    Timer {
        interval: 200
        repeat: true
        running: root.active
        onTriggered: root.tick++
    }

    Row {
        visible: root.active
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        StyledText {
            width: 10
            horizontalAlignment: Text.AlignHCenter
            text: root.glyphs[root.tick % root.glyphs.length]
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: Appearance.colors.colPrimary
        }
        StyledText {
            id: label
            textFormat: Text.StyledText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: Appearance.colors.colPrimary
            text: {
                const tokens = Ai.liveOutputTokens > 0 ? ` · ↓ ${Ai.liveOutputTokens} tokens` : "";
                return `${root.verb}… <font color="${Appearance.colors.colSubtext}">(${root.elapsed}s${tokens} · esc to interrupt)</font>`;
            }
        }
    }
}
