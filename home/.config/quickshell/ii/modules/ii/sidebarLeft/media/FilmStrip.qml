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
            MaterialLoadingIndicator { anchors.centerIn: parent; implicitSize: Appearance.font.pixelSize.hugeass; loading: MediaGen.busy } }
    }
    model: MediaGen.items
    delegate: RippleButton {
        id: tile
        required property var modelData
        width: 92; height: 58; buttonRadius: Appearance.rounding.small
        colBackground: Appearance.colors.colLayer1
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colRipple: Appearance.colors.colLayer1Active
        onClicked: MediaGen.selectedId = modelData.id
        contentItem: Item {}
        Rectangle {
            anchors { fill: parent; margins: 2 }
            id: thumbBox
            radius: Appearance.rounding.verysmall; color: "transparent"
            opacity: tile.down ? 0.75 : tile.hovered ? 0.9 : 1
            Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
            layer.enabled: true
            layer.effect: OpacityMask { maskSource: Rectangle { width: thumbBox.width; height: thumbBox.height; radius: thumbBox.radius } }
            Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; source: MediaGen.thumbUrl(modelData.id) }
        }
        Rectangle {
            anchors.centerIn: parent; visible: modelData.kind === "video"
            width: 28; height: 28; radius: Appearance.rounding.full; color: Appearance.m3colors.m3surfaceContainerHigh
            MaterialSymbol { anchors.centerIn: parent; text: "play_arrow"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.m3colors.m3onSurface }
        }
        Rectangle {
            anchors.fill: parent; radius: tile.buttonRadius; color: "transparent"
            border.width: 2; border.color: MediaGen.selectedId === modelData.id ? Appearance.colors.colPrimary : tile.hovered ? Appearance.colors.colOutline : "transparent"
            Behavior on border.color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
        }
    }
}
