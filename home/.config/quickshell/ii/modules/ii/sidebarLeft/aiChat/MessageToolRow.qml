import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import "Markdown.js" as Markdown

Item {
    id: root
    property var messageData
    property var part: messageData?.toolPart ?? {}
    property var state: part.state ?? {}
    property bool expanded: false
    property real now: Date.now()
    readonly property bool running: state.status === "pending" || state.status === "running"
    readonly property bool failed: state.status === "error"
    readonly property string tool: part.tool ?? ""
    readonly property string output: String(state.output ?? "").replace(/^(\s*\n)+/, "").replace(/\s+$/, "")
    readonly property string taskText: (output.match(/<task_result>\n?([\s\S]*?)\n?<\/task_result>/)?.[1] ?? output).trim().replace(/^ANSWER:\s*/i, "")
    readonly property var lines: (tool === "task" ? taskText : output).split("\n")
    readonly property int previewLines: tool === "task" ? 1 : 3
    readonly property string path: Ai.relPath(state.input?.filePath ?? state.input?.path ?? "")
    readonly property string diff: state.metadata?.diff ?? state.input?.diff ?? ""
    readonly property var diffLines: diff.split("\n").filter(s => s.length > 0)
    readonly property int added: state.metadata?.filediff?.additions ?? diffLines.filter(s => s.startsWith("+") && !s.startsWith("+++")).length
    readonly property int removed: state.metadata?.filediff?.deletions ?? diffLines.filter(s => s.startsWith("-") && !s.startsWith("---")).length
    readonly property real elapsedMs: (state.time?.end ?? now) - (state.time?.start ?? now)
    readonly property string elapsed: `${Math.max(0, Math.round(elapsedMs / 1000))}s`
    readonly property string toolUses: `${messageData?.toolUses ?? 0} tool use${messageData?.toolUses === 1 ? "" : "s"} · ${elapsed}`
    readonly property string heading: {
        const input = state.input ?? {};
        if (tool === "frontier") return `Frontier(${state.title ?? ""})`;
        if (tool === "task") {
            const agent = String(input.subagent_type ?? "explore");
            return `${agent.charAt(0).toUpperCase() + agent.slice(1)}(${input.description ?? state.title ?? ""})`;
        }
        if (tool === "bash") return `Bash(${String(input.command ?? "").split("\n")[0]})`;
        if (tool === "write") return `Write(${path})`;
        if (tool === "edit" || tool === "patch") return `Update(${path})`;
        if (tool.startsWith("web_")) return `Web(${input.query ?? input.url ?? ""})`;
        return `${tool}(${path || state.title || ""})`;
    }
    readonly property string summary: {
        if (tool === "frontier") return (expanded ? lines : lines.slice(-4)).filter(Boolean).join("\n") || (running ? "planning…" : "");
        if (tool === "task") {
            if (running) return toolUses;
            const first = taskText.split("\n")[0];
            return `Done (${toolUses})` + (first ? "\n" + (expanded ? taskText : first) : "");
        }
        if (running) return "running…";
        if (failed) return `Error: ${messageData?.errorText || "failed"}`;
        if (tool === "write") {
            const n = String(state.input?.content ?? "").replace(/\n$/, "").split("\n").length;
            return `Wrote ${n} line${n === 1 ? "" : "s"} to ${path}`;
        }
        if (tool === "edit" || tool === "patch") return `Added ${added} line${added === 1 ? "" : "s"}, removed ${removed}`;
        return lines.slice(0, expanded ? lines.length : previewLines).join("\n");
    }
    readonly property int hiddenLines: !expanded && !running && !failed && (tool === "bash" || tool === "task") ? Math.max(0, lines.length - previewLines) : 0

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: column.implicitHeight + 4

    Timer {
        interval: 1000
        repeat: true
        running: root.running && root.tool === "task"
        onTriggered: root.now = Date.now()
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            StyledText {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 10
                horizontalAlignment: Text.AlignHCenter
                text: "●"
                font.pixelSize: Appearance.font.pixelSize.small / 2
                color: root.failed ? Appearance.m3colors.m3error : root.running ? Appearance.colors.colSubtext : Appearance.m3colors.m3success
            }
            StyledText {
                Layout.fillWidth: true
                text: root.heading
                elide: Text.ElideRight
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                color: Appearance.colors.colSubtext
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            visible: root.summary.length > 0
            spacing: 6
            StyledText {
                Layout.alignment: Qt.AlignTop
                text: "⎿"
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                // Explore answers are prose, so render their inline code; other output stays literal
                textFormat: root.tool === "task" && !root.running ? Text.RichText : Text.PlainText
                text: textFormat === Text.RichText ? Markdown.inline(root.summary, { code: String(Appearance.colors.colPrimary), link: String(Appearance.colors.colPrimary) }).replace(/\n/g, "<br>") : root.summary
                wrapMode: Text.Wrap
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                color: root.failed ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
            }
        }
        StyledText {
            Layout.leftMargin: 20 + 6 + Ai.chatFontSize
            visible: root.hiddenLines > 0
            text: `… +${root.hiddenLines} lines (click to expand)`
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: Appearance.colors.colSubtext
        }
        Repeater {
            model: root.expanded ? root.diffLines : []
            delegate: StyledText {
                required property string modelData
                Layout.fillWidth: true
                Layout.leftMargin: 20 + 6 + Ai.chatFontSize
                text: modelData
                wrapMode: Text.WrapAnywhere
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                color: modelData.startsWith("+") && !modelData.startsWith("+++") ? Appearance.m3colors.m3success
                    : modelData.startsWith("-") && !modelData.startsWith("---") ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }
}
