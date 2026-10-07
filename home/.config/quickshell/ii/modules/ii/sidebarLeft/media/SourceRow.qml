import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import "MediaCopy.js" as C

// Empty: one quiet row. Filled: thumbnail card with its role. Accepts drops, Ctrl+V (handled by MediaStudio) and click → picker.
Item {
    id: root
    implicitHeight: MediaGen.srcPath === "" ? 40 : 56
    Behavior on implicitHeight { animation: Appearance.animation.elementMove.numberAnimation.createObject(this) }

    DropArea {
        anchors.fill: parent
        onDropped: (drop) => { if (drop.hasUrls) for (const u of drop.urls) MediaGen.addImage(decodeURIComponent(u.toString().replace("file://", ""))); }
    }
    RippleButton {
        anchors.fill: parent
        visible: MediaGen.srcPath === ""
        buttonRadius: Appearance.rounding.small
        colBackground: Appearance.colors.colLayer1
        onClicked: MediaGen.pickSource()
        contentItem: RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 10
            MaterialSymbol { text: "add_photo_alternate"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer1 }
            StyledText { Layout.fillWidth: MediaGen.kind === "video"; elide: Text.ElideRight; text: MediaGen.kind === "video" ? "Start from an image or a video" : "Start from one or more images"; color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.smallie }
            MaterialSymbol {
                visible: MediaGen.kind === "image"
                text: "help"; iconSize: 15; color: Appearance.colors.colSubtext
                HoverHandler { id: helpHover }
                property bool hovered: helpHover.hovered
                StyledToolTip { text: "The first image is the one that gets edited.\nAdd up to 3 more as references (people, objects,\nclothes, places) and mention them in the prompt\nas \"image 2\", \"image 3\" and so on." }
            }
            Item { visible: MediaGen.kind === "image"; Layout.fillWidth: true }
            StyledText { text: "optional · drop or Ctrl V"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: MediaGen.srcPath !== ""
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        RowLayout {
            anchors { fill: parent; margins: 8 }
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 58; Layout.preferredHeight: 38; radius: 9; clip: true; color: Appearance.colors.colLayer1
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 116
                        source: MediaGen.srcKind === "image" ? "file://" + MediaGen.srcPath : "" }
                MaterialSymbol { anchors.centerIn: parent; visible: MediaGen.srcKind === "video"; text: "movie"; color: Appearance.colors.colOnLayer1 }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                StyledText { Layout.fillWidth: true; elide: Text.ElideMiddle; text: MediaGen.srcPath.split("/").pop(); font.pixelSize: Appearance.font.pixelSize.smallie }
                StyledText { text: (C.ROLE[MediaGen.mode()] ?? "") + (MediaGen.refs.length ? " · +" + MediaGen.refs.length + (MediaGen.refs.length === 1 ? " reference" : " references") : ""); color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
            }
            RippleButton {
                implicitWidth: 30; implicitHeight: 30; buttonRadius: Appearance.rounding.full
                onClicked: MediaGen.clearSource()
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; color: Appearance.colors.colSubtext }
                StyledToolTip { text: "Remove" }
            }
        }
    }
}
