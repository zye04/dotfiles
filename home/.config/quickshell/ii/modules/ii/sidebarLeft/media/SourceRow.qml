import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import "MediaCopy.js" as C

// Empty: one quiet row. Filled: thumbnail card with its role. Accepts drops, Ctrl+V (handled by MediaStudio) and click → picker.
Item {
    id: root
    implicitHeight: MediaGen.srcPath === "" ? 40 : MediaGen.refs.length ? 70 : 56
    Behavior on implicitHeight { animation: Appearance.animation.elementMove.numberAnimation.createObject(this) }

    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (!drop.hasUrls || MediaGen.busy) return;
            const paths = drop.urls.map(u => u.toString()).filter(u => u.startsWith("file://") && /\.(png|jpe?g|webp|mp4|webm|mkv|mov)$/i.test(u));
            if (!paths.length) { MediaGen.lastError = "Choose a PNG, JPG or WebP image, or an MP4, WebM, MKV or MOV video"; return; }
            for (const u of paths) MediaGen.addImage(decodeURIComponent(u.replace("file://", "")));
            drop.acceptProposedAction();
        }
    }
    RippleButton {
        anchors.fill: parent
        visible: MediaGen.srcPath === ""
        buttonRadius: Appearance.rounding.small
        colBackground: Appearance.colors.colLayer1
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colRipple: Appearance.colors.colLayer1Active
        onClicked: MediaGen.pickSource()
        contentItem: RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 10
            MaterialSymbol { text: "add_photo_alternate"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer1 }
            StyledText { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: MediaGen.kind === "video" ? "Add an image or video" : "Add images"; color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.smallie }
            MaterialSymbol {
                visible: MediaGen.kind === "image"
                text: "help"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext
                HoverHandler { id: helpHover }
                property bool hovered: helpHover.hovered
                StyledToolTip { text: "The first image is the one that gets edited.\nAdd up to 3 more as references (people, objects,\nclothes, places) and mention them in the prompt\nas \"Photo 2\", \"Photo 3\" and so on." }
            }
            StyledText { Layout.maximumWidth: 120; elide: Text.ElideRight; text: "Drop · Ctrl + V"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
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
                visible: !MediaGen.refs.length
                Layout.preferredWidth: 58; Layout.preferredHeight: 38; radius: Appearance.rounding.verysmall; clip: true; color: Appearance.colors.colLayer1
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 116
                        source: MediaGen.srcKind === "image" ? "file://" + MediaGen.srcPath : "" }
                MaterialSymbol { anchors.centerIn: parent; visible: MediaGen.srcKind === "video"; text: "movie"; color: Appearance.colors.colOnLayer1 }
            }
            ColumnLayout {
                visible: !MediaGen.refs.length
                Layout.fillWidth: true; spacing: 0
                StyledText { Layout.fillWidth: true; elide: Text.ElideMiddle; text: (MediaGen.srcKind === "image" ? "Photo 1 · " : "") + MediaGen.srcPath.split("/").pop(); font.pixelSize: Appearance.font.pixelSize.smallie }
                StyledText { text: C.ROLE[MediaGen.mode()] ?? ""; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
            }
            // Numbered slots, so prompts can say "photo 2" and mean exactly this image.
            Repeater {
                model: MediaGen.refs.length ? [MediaGen.srcPath].concat(MediaGen.refs) : []
                delegate: ColumnLayout {
                    required property string modelData
                    required property int index
                    spacing: 2
                    Rectangle {
                        Layout.preferredWidth: 46; Layout.preferredHeight: 34; radius: Appearance.rounding.verysmall; clip: true; color: Appearance.colors.colLayer1
                        Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 92; source: "file://" + modelData }
                        HoverHandler { id: slotHover }
                        RippleButton {
                            visible: slotHover.hovered && !MediaGen.busy
                            anchors { top: parent.top; right: parent.right; margins: 2 }
                            implicitWidth: 18; implicitHeight: 18; buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer2
                            onClicked: MediaGen.removeImage(index)
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                        }
                    }
                    StyledText { Layout.alignment: Qt.AlignHCenter; text: "Photo " + (index + 1); color: index === 0 ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
                }
            }
            Item { visible: MediaGen.refs.length > 0; Layout.fillWidth: true }
            RippleButton {
                visible: MediaGen.srcKind === "image"
                implicitWidth: 30; implicitHeight: 30; buttonRadius: Appearance.rounding.full
                onClicked: {
                    const item = MediaGen.items.find(i => i.path === MediaGen.srcPath);
                    Quickshell.execDetached(["xdg-open", MediaGen.base + "/studio/?" + (item ? "item=" + encodeURIComponent(item.id) : "source=" + encodeURIComponent(MediaGen.srcPath))]);
                }
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "open_in_browser"; color: Appearance.colors.colSubtext }
                StyledToolTip { text: "Open in Studio" }
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
