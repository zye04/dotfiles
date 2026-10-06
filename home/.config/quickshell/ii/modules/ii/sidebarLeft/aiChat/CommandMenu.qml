import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// local-suite: Claude Code-style command menu above the chat input.
// One row per item: name (accent colour) + description (dimmed), filtered by
// the caller; Up/Down move, Tab/Enter accept, Esc closes.
Rectangle {
    id: root
    property var items: [] // [{ name, displayName?, description }]
    property int selectedIndex: 0
    property int maxRows: 8
    readonly property real rowHeight: 34
    signal accepted(string name)

    visible: items.length > 0
    Layout.fillWidth: true
    implicitHeight: Math.min(items.length, maxRows) * rowHeight + 8
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2
    onItemsChanged: selectedIndex = 0

    function move(delta) {
        selectedIndex = Math.max(0, Math.min(items.length - 1, selectedIndex + delta));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function acceptSelected() {
        if (selectedIndex >= 0 && selectedIndex < items.length) root.accepted(items[selectedIndex].name);
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.items

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: ListView.view.width
            height: root.rowHeight
            radius: Appearance.rounding.verysmall
            color: index === root.selectedIndex ? Appearance.colors.colSecondaryContainer : "transparent"

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 14

                StyledText {
                    text: row.modelData.displayName ?? row.modelData.name
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colPrimary
                    Layout.preferredWidth: Math.min(implicitWidth, row.width * 0.45)
                    elide: Text.ElideRight
                }
                StyledText {
                    text: row.modelData.description ?? ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = row.index
                onClicked: root.accepted(row.modelData.name)
            }
        }
    }
}
