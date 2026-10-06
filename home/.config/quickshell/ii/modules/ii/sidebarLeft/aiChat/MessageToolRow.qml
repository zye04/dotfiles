import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var messageData
    property var part: messageData?.toolPart ?? {}
    property var state: part.state ?? {}
    property bool expanded: false
    readonly property bool running: state.status === "pending" || state.status === "running"
    readonly property bool failed: state.status === "error"
    readonly property string tool: part.tool ?? ""
    readonly property string output: String(state.output ?? "")
    readonly property string taskText: (output.match(/<task_result>\n?([\s\S]*?)\n?<\/task_result>/)?.[1] ?? output).trim()
    readonly property var lines: (tool === "task" ? taskText : output).split("\n")
    readonly property int previewLines: tool === "task" ? 1 : 3
    readonly property string path: state.input?.filePath ?? state.input?.path ?? ""
    readonly property string diff: state.metadata?.diff ?? state.input?.diff ?? ""
    readonly property string heading: {
        const input = state.input ?? {};
        if (tool === "task") {
            const agent = String(state.input?.subagent_type ?? "explore");
            return `${agent.charAt(0).toUpperCase() + agent.slice(1)}(${state.input?.description ?? state.title ?? ""})`;
        }
        if (tool === "bash") return `Bash(${String(input.command ?? "").split("\n")[0]})`;
        if (tool === "read") return `Read(${path})`;
        if (tool === "write") return `Write(${path})`;
        if (tool === "edit" || tool === "patch") return `Update(${path})`;
        if (tool === "glob" || tool === "grep") return `Search(${input.pattern ?? input.path ?? ""})`;
        if (tool.startsWith("web_")) return `Web(${input.query ?? input.url ?? ""})`;
        return `${tool}(${path || state.title || ""})`;
    }
    readonly property string summary: {
        if (running) return "running…";
        if (failed) return output || "failed";
        if (tool === "read") return `Read ${lines.length} lines`;
        if (tool === "write") return `Wrote ${String(state.input?.content ?? "").split("\n").length} lines`;
        if (tool === "edit" || tool === "patch") {
            const plus = diff.split("\n").filter(s => s.startsWith("+") && !s.startsWith("+++")).length;
            const minus = diff.split("\n").filter(s => s.startsWith("-") && !s.startsWith("---")).length;
            return `+${plus} −${minus}`;
        }
        return lines.slice(0, expanded ? lines.length : previewLines).join("\n");
    }

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: row.implicitHeight + 4

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        anchors.topMargin: 2
        spacing: 10

        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 10
            implicitHeight: titleText.implicitHeight
            Orb {
                visible: root.running
                follow: false
                spinning: true
                size: 11
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                visible: !root.running
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                text: "●"
                font.pixelSize: Appearance.font.pixelSize.small / 2
                color: root.failed ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                id: titleText
                Layout.fillWidth: true
                text: root.heading
                elide: Text.ElideRight
                font.family: Appearance.font.family.monospace
                font.pixelSize: 13
                color: root.failed ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: "⎿ " + root.summary
                wrapMode: Text.Wrap
                font.family: Appearance.font.family.monospace
                font.pixelSize: 13
                color: Appearance.colors.colSubtext
            }
            StyledText {
                visible: !root.expanded && !root.running && root.lines.length > root.previewLines && (root.tool === "bash" || root.tool === "task")
                text: `… +${root.lines.length - root.previewLines} lines (click to expand)`
                font.family: Appearance.font.family.monospace
                font.pixelSize: 13
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.expanded && root.diff.length > 0
                text: root.diff
                wrapMode: Text.WrapAnywhere
                font.family: Appearance.font.family.monospace
                font.pixelSize: 13
                color: Appearance.colors.colSubtext
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }
}
