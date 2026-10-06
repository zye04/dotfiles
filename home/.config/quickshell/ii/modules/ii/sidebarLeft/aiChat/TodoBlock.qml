import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var messageData
    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: list.implicitHeight + 4
    ColumnLayout {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        spacing: 2
        Repeater {
            model: root.messageData?.todos ?? []
            delegate: StyledText {
                required property var modelData
                readonly property bool done: modelData.status === "completed"
                Layout.fillWidth: true
                Layout.leftMargin: 20
                text: `${done ? "☒" : "☐"} ${modelData.content ?? ""}`
                wrapMode: Text.Wrap
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                font.strikeout: done
                color: modelData.status === "in_progress" ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
            }
        }
    }
}
