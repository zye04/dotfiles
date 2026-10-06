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
    implicitHeight: row.implicitHeight + 4
    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        spacing: 10
        StyledText { Layout.alignment: Qt.AlignTop; Layout.preferredWidth: 10; text: "⎿"; color: Appearance.colors.colSubtext }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: root.messageData?.todos ?? []
                delegate: StyledText {
                    required property var modelData
                    text: `${modelData.status === "completed" ? "☒" : "☐"} ${modelData.content ?? ""}`
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Ai.chatFontSize
                    color: modelData.status === "in_progress" ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
            }
        }
    }
}
