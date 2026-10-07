import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Qt5Compat.GraphicalEffects

ListView {
    id: root
    visible: MediaGen.items.length > 0 || MediaGen.busy
    implicitHeight: 62
    orientation: ListView.Horizontal
    spacing: 8
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    header: Item {
        width: MediaGen.busy ? 100 : 0; height: 58; visible: MediaGen.busy
        Rectangle { width: 92; height: 58; radius: Appearance.rounding.small; color: Appearance.colors.colLayer1
            MaterialSymbol { anchors.centerIn: parent; text: "progress_activity"; iconSize: 22; color: Appearance.colors.colPrimary
                RotationAnimation on rotation { running: MediaGen.busy; from: 0; to: 360; duration: 1200; loops: Animation.Infinite } } }
    }
    model: MediaGen.items
    delegate: Rectangle {
        required property var modelData
        width: 92; height: 58; radius: Appearance.rounding.small; color: Appearance.colors.colLayer1
        border.width: 2; border.color: MediaGen.selectedId === modelData.id ? Appearance.colors.colPrimary : "transparent"
        Rectangle {
            anchors { fill: parent; margins: 2 }
            id: thumbBox
            radius: Appearance.rounding.small - 2; color: "transparent"
            layer.enabled: true
            layer.effect: OpacityMask { maskSource: Rectangle { width: thumbBox.width; height: thumbBox.height; radius: thumbBox.radius } }
            Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; source: MediaGen.thumbUrl(modelData.id) }
        }
        MaterialSymbol { anchors.centerIn: parent; visible: modelData.kind === "video"; text: "play_circle"; iconSize: 22; color: "#eeffffff" }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MediaGen.selectedId = modelData.id }
    }
}
