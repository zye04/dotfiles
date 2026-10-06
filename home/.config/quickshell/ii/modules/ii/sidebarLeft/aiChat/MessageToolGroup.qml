import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var messageData
    property bool expanded: false
    readonly property var tools: messageData?.tools ?? []
    readonly property bool running: !(messageData?.done ?? true)
    readonly property var current: tools.filter(t => t.status === "running" || t.status === "pending").slice(-1)[0]

    readonly property int errors: tools.filter(t => t.status === "error").length
    function count(pred) { return tools.filter(pred).length; }
    function plural(n, one, many) { return `${n} ${n === 1 ? one : many}`; }
    readonly property string summary: {
        const files = count(t => t.tool === "read" && !t.dir), dirs = count(t => t.dir), searches = count(t => t.tool === "glob" || t.tool === "grep");
        const parts = [];
        if (files) parts.push(`${running ? "Reading" : "Read"} ${plural(files, "file", "files")}`);
        if (searches) parts.push(`${running ? "searching" : "searched"} ${plural(searches, "pattern", "patterns")}`);
        if (dirs) parts.push(`${running ? "listing" : "listed"} ${plural(dirs, "directory", "directories")}`);
        let text = parts.join(", ");
        if (text) text = text.charAt(0).toUpperCase() + text.slice(1);
        return text + (running ? "…" : "");
    }

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: column.implicitHeight + 4

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
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                textFormat: Text.RichText
                text: root.summary + (root.errors > 0 ? `<font color="${Appearance.m3colors.m3error}"> · ${root.plural(root.errors, "error", "errors")}</font>` : "") + (root.expanded ? "" : "  (click to expand)")
                wrapMode: Text.Wrap
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                color: Appearance.colors.colSubtext
            }
        }
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            visible: root.running && !root.expanded && root.current !== undefined
            text: root.current ? `⎿ ${root.current.tool} ${root.current.target}` : ""
            elide: Text.ElideMiddle
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: Appearance.colors.colSubtext
        }
        Repeater {
            model: root.expanded ? root.tools : []
            delegate: StyledText {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 20
                readonly property bool failed: modelData.status === "error"
                text: `⎿ ${modelData.tool}(${modelData.target}) ${failed ? "Error: " + modelData.errorText : modelData.summary}`
                wrapMode: Text.Wrap
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                color: failed ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }
}
