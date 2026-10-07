import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell

ColumnLayout {
    id: root
    readonly property var item: MediaGen.selectedItem()
    readonly property bool isVideo: item?.kind === "video"
    readonly property string compareSrc: item?.source && !/\.(mp4|webm|mkv|mov)$/i.test(item.source) ? "file://" + item.source : ""
    spacing: 8

    // Decode only while the Media tab is on screen.
    function syncPlay() { if (root.isVideo && MediaGen.tabVisible) player.play(); else player.pause(); }
    function act(kind, task) {
        MediaGen.setSource(root.item.path);
        if (kind === "image") { MediaGen.kind = "image"; MediaGen.task = task; }
        else if (kind === "video") { MediaGen.kind = "video"; MediaGen.setLength(5); }
    }

    Rectangle {
        id: frame
        Layout.fillWidth: true; Layout.fillHeight: true
        radius: Appearance.rounding.normal; color: "#0c0e12"; clip: true
        HoverHandler { id: hover }

        Image {
            anchors.fill: parent; fillMode: Image.PreserveAspectFit; asynchronous: true
            visible: !!root.item && !root.isVideo
            source: root.item && !root.isVideo ? "file://" + root.item.path : ""
            sourceSize.width: 2048
        }
        MediaPlayer {
            id: player
            source: root.isVideo ? "file://" + root.item.path : ""
            loops: MediaPlayer.Infinite
            videoOutput: video
            audioOutput: AudioOutput { id: audio; muted: true }
            onSourceChanged: root.syncPlay()
        }
        Connections { target: MediaGen; function onTabVisibleChanged() { root.syncPlay(); } }
        VideoOutput { id: video; anchors.fill: parent; visible: root.isVideo; fillMode: VideoOutput.PreserveAspectFit }

        ColumnLayout {   // empty state
            anchors.centerIn: parent; visible: !root.item; spacing: 10
            MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "photo_library"; iconSize: 42; color: Appearance.colors.colOutlineVariant }
            StyledText { Layout.alignment: Qt.AlignHCenter; text: "Nothing here yet"; color: Appearance.colors.colOnLayer1 }
            StyledText { Layout.alignment: Qt.AlignHCenter; text: "Results land here and in ~/agent/images · ~/agent/videos"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
        }

        component Glass: RippleButton {
            id: gbtn
            property string glyph
            property string label: ""
            implicitHeight: 34; implicitWidth: label !== "" ? gl.implicitWidth + 24 : 34
            buttonRadius: Appearance.rounding.full
            colBackground: Qt.alpha(Appearance.colors.colLayer0, 0.78)
            colBackgroundHover: Qt.alpha(Appearance.colors.colLayer2, 0.92)
            contentItem: RowLayout { id: gl; anchors.centerIn: parent; spacing: 6
                MaterialSymbol { text: gbtn.glyph; color: Appearance.colors.colOnLayer0 }
                StyledText { visible: text !== ""; text: gbtn.label; color: Appearance.colors.colOnLayer0; font.pixelSize: Appearance.font.pixelSize.smallie } }
        }

        Item {   // hover layer
            anchors { fill: parent; margins: 14 }
            visible: !!root.item
            opacity: hover.hovered || menu.visible ? 1 : 0
            enabled: opacity > 0.5
            Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }

            RowLayout { anchors { top: parent.top; right: parent.right } spacing: 6
                Glass { glyph: "compare"; visible: root.compareSrc !== ""; StyledToolTip { text: "Compare with source" }
                        downAction: () => compareImg.visible = true; releaseAction: () => compareImg.visible = false }
                Glass { glyph: "open_in_full"; StyledToolTip { text: "Fullscreen" }
                        onClicked: Quickshell.execDetached(["xdg-open", root.item.path]) }
            }
            RowLayout { anchors { left: parent.left; bottom: parent.bottom } spacing: 6
                Glass { visible: !root.isVideo; glyph: "edit"; label: "Edit"; onClicked: root.act("image", "edit") }
                Glass { visible: !root.isVideo; glyph: "movie"; label: "Animate"; onClicked: root.act("video") }
                Glass { visible: !root.isVideo; glyph: "hd"; label: "Upscale"; onClicked: root.act("image", "upscale") }
                Glass { visible: root.isVideo; glyph: "auto_fix_high"; label: "Enhance"; onClicked: { MediaGen.kind = "video"; MediaGen.setSource(root.item.path); } }
            }
            Glass { anchors { right: parent.right; bottom: parent.bottom } glyph: "more_horiz"; onClicked: menu.popup() }
            RowLayout {   // video player bar
                visible: root.isVideo
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 46 }
                spacing: 10
                MaterialSymbol { text: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"; color: "white"
                    MouseArea { anchors.fill: parent; onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play() } }
                StyledSlider { Layout.fillWidth: true; from: 0; to: Math.max(1, player.duration); value: player.position; onMoved: player.position = value }
                StyledText { color: "white"; font.pixelSize: Appearance.font.pixelSize.smaller
                    function t(ms) { const s = Math.floor(ms / 1000); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
                    text: t(player.position) + " / " + t(player.duration) }
                MaterialSymbol { text: audio.muted ? "volume_off" : "volume_up"; color: "white"
                    MouseArea { anchors.fill: parent; onClicked: audio.muted = !audio.muted } }
            }
        }
        Image { id: compareImg; anchors.fill: parent; visible: false; fillMode: Image.PreserveAspectFit; source: root.compareSrc }

        component Entry: MenuItem {
            id: mi
            property color textColor: Appearance.m3colors.m3onSurface
            implicitHeight: 36
            contentItem: StyledText {
                text: mi.text; font.pixelSize: Appearance.font.pixelSize.small
                color: mi.textColor; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Appearance.rounding.small
                color: mi.highlighted ? Appearance.colors.colLayer3Hover : "transparent"
            }
        }
        Menu {
            id: menu
            implicitWidth: 220
            background: Rectangle {
                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainerHigh
                border.width: 1; border.color: Appearance.colors.colOutlineVariant
            }
            Entry { text: "Reuse prompt & settings"; onTriggered: MediaGen.reuse(root.item) }
            Entry { text: "Copy prompt"; onTriggered: Quickshell.clipboardText = root.item.spec?.prompt ?? "" }
            Entry { text: "Show in folder"; onTriggered: Quickshell.execDetached(["dolphin", "--select", root.item.path]) }
            MenuSeparator {}
            Entry { textColor: Appearance.m3colors.m3error; text: "Delete"; onTriggered: confirm.show = true }
        }
        Loader {
            id: confirm
            property bool show: false
            anchors.fill: parent
            active: show
            onActiveChanged: if (active) { item.show = true; item.forceActiveFocus(); }
            Connections {
                target: confirm.item
                function onVisibleChanged() { if (!confirm.item.visible && !confirm.item.show) confirm.show = false; }
            }
            sourceComponent: WindowDialog {
                id: dlg
                backgroundWidth: 300
                onDismiss: show = false
                WindowDialogTitle { text: "Delete this " + (root.isVideo ? "video" : "image") + "?" }
                WindowDialogButtonRow {
                    DialogButton { buttonText: "Cancel"; onClicked: dlg.show = false }
                    DialogButton { buttonText: "Delete"; colEnabled: Appearance.m3colors.m3error; onClicked: { dlg.show = false; MediaGen.deleteItem(root.item.id); } }
                }
            }
        }
        Keys.onLeftPressed: { const i = MediaGen.items.findIndex(x => x.id === root.item?.id); if (i > 0) MediaGen.selectedId = MediaGen.items[i - 1].id; }
        Keys.onRightPressed: { const i = MediaGen.items.findIndex(x => x.id === root.item?.id); if (i >= 0 && i < MediaGen.items.length - 1) MediaGen.selectedId = MediaGen.items[i + 1].id; }
        TapHandler { onTapped: frame.forceActiveFocus() }
    }

    RowLayout {   // info line
        Layout.fillWidth: true; Layout.leftMargin: 4; Layout.rightMargin: 4
        visible: !!root.item; spacing: 16
        StyledText { Layout.fillWidth: true; elide: Text.ElideRight; text: root.item?.spec?.prompt ?? ""; color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.smaller }
        StyledText {
            color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller
            text: root.item ? root.item.w + "×" + root.item.h + " · " + (root.item.quality ?? "") + " · "
                + (root.isVideo ? Math.round(root.item.duration_s ?? 0) + " s clip" : Math.round(root.item.elapsed_s ?? 0) + " s") : ""
        }
    }
}
