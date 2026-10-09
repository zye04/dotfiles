import qs.services
import qs.modules.common
import qs.modules.common.functions
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
        radius: Appearance.rounding.normal; color: Appearance.colors.colLayer0; clip: true
        HoverHandler { id: hover }

        Image {
            id: preview
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
            onSourceChanged: Qt.callLater(() => { if (root && typeof root.syncPlay === "function") root.syncPlay(); })
        }
        Connections { target: MediaGen; function onTabVisibleChanged() { root.syncPlay(); } }
        VideoOutput { id: video; anchors.fill: parent; visible: root.isVideo; fillMode: VideoOutput.PreserveAspectFit }

        ColumnLayout {   // empty state
            anchors.centerIn: parent; visible: !root.item; spacing: 10
            MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "photo_library"; iconSize: Appearance.font.pixelSize.hugeass; color: Appearance.colors.colOutlineVariant }
            StyledText { Layout.alignment: Qt.AlignHCenter; text: "Nothing here yet"; color: Appearance.colors.colOnLayer1 }
            StyledText { Layout.alignment: Qt.AlignHCenter; text: "Results land here and in ~/agent/images · ~/agent/videos"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
        }

        MaterialLoadingIndicator {
            anchors.centerIn: parent
            visible: !!root.item && (root.isVideo ? player.mediaStatus === MediaPlayer.LoadingMedia || player.mediaStatus === MediaPlayer.BufferingMedia : preview.status === Image.Loading)
            loading: visible
            implicitSize: Appearance.font.pixelSize.hugeass
        }

        component Glass: RippleButton {
            id: gbtn
            property string glyph
            property string label: ""
            implicitHeight: 34; implicitWidth: label !== "" ? gl.implicitWidth + 24 : 34
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.m3colors.m3surfaceContainerHigh
            colBackgroundHover: ColorUtils.mix(Appearance.m3colors.m3surfaceContainerHigh, Appearance.m3colors.m3onSurface, 0.9)
            colRipple: ColorUtils.mix(Appearance.m3colors.m3surfaceContainerHigh, Appearance.m3colors.m3onSurface, 0.8)
            contentItem: RowLayout { id: gl; anchors.centerIn: parent; spacing: 6
                MaterialSymbol { text: gbtn.glyph; color: Appearance.m3colors.m3onSurface }
                StyledText { visible: text !== ""; text: gbtn.label; color: Appearance.m3colors.m3onSurface; font.pixelSize: Appearance.font.pixelSize.smallie } }
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
                Glass { glyph: "open_in_full"; StyledToolTip { text: "Open full screen" }
                        onClicked: Quickshell.execDetached(["mpv", "--fullscreen", "--image-display-duration=inf", "--loop-file=inf", root.item.path]) }
            }
            RowLayout { anchors { left: parent.left; bottom: parent.bottom } spacing: 6
                Glass { visible: !root.isVideo; glyph: "edit"; label: "Edit"; onClicked: root.act("image", "edit") }
                Glass { visible: !root.isVideo; glyph: "movie"; label: "Animate"; onClicked: root.act("video") }
                Glass { visible: !root.isVideo; glyph: "hd"; label: "Upscale"; onClicked: root.act("image", "upscale") }
                Glass { visible: !root.isVideo; glyph: "brush"; label: "Region"; onClicked: MediaGen.openRegionEditor(root.item.path, null)
                        StyledToolTip { text: "Change only a painted area" } }
                Glass { visible: root.isVideo; glyph: "auto_fix_high"; label: "Enhance"; onClicked: { MediaGen.kind = "video"; MediaGen.setSource(root.item.path); } }
            }
            Glass { anchors { right: parent.right; bottom: parent.bottom } glyph: "more_horiz"; onClicked: menu.popup() }
            Rectangle {   // video player bar
                visible: root.isVideo
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 46 }
                implicitHeight: 40
                radius: Appearance.rounding.full
                color: Appearance.m3colors.m3surfaceContainerHigh
                RowLayout {
                    anchors { fill: parent; margins: 3; rightMargin: 6 }
                    spacing: 10
                    Glass { glyph: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"
                        onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play() }
                    StyledSlider { Layout.fillWidth: true; from: 0; to: Math.max(1, player.duration); value: player.position; onMoved: player.position = value }
                    StyledText { color: Appearance.m3colors.m3onSurface; font.pixelSize: Appearance.font.pixelSize.smaller
                        function t(ms) { const s = Math.floor(ms / 1000); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
                        text: t(player.position) + " / " + t(player.duration) }
                    Glass { glyph: audio.muted ? "volume_off" : "volume_up"; onClicked: audio.muted = !audio.muted }
                }
            }
        }
        Image { id: compareImg; anchors.fill: parent; visible: false; fillMode: Image.PreserveAspectFit; source: root.compareSrc }

        component Entry: MenuItem {
            id: mi
            property color textColor: Appearance.m3colors.m3onSurface
            implicitHeight: 36
            contentItem: StyledText {
                text: mi.text; font.pixelSize: Appearance.font.pixelSize.small
                color: mi.enabled ? mi.textColor : Appearance.colors.colSubtext; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Appearance.rounding.small
                color: mi.down ? Appearance.colors.colLayer3Active : mi.highlighted || mi.hovered ? Appearance.colors.colLayer3Hover : "transparent"
                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
            }
        }
        Menu {
            id: menu
            implicitWidth: 220
            background: Rectangle {
                StyledRectangularShadow { target: parent }
                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainerHigh
                border.width: 1; border.color: Appearance.colors.colOutlineVariant
            }
            Entry { visible: !root.isVideo; text: "Open in Studio"; onTriggered: Quickshell.execDetached(["xdg-open", MediaGen.base + "/studio/?item=" + encodeURIComponent(root.item.id)]) }
            Entry { text: "Reuse prompt and settings"; onTriggered: MediaGen.reuse(root.item) }
            Entry { text: "Copy prompt"; onTriggered: Quickshell.clipboardText = root.item.spec?.prompt ?? "" }
            Entry { text: "Show in folder"; onTriggered: Quickshell.execDetached(["dolphin", "--select", root.item.path]) }
            MenuSeparator {
                contentItem: Rectangle { implicitHeight: 1; color: Appearance.colors.colOutlineVariant }
                topPadding: 4; bottomPadding: 4
            }
            Entry { textColor: Appearance.colors.colError; text: "Delete"; onTriggered: confirm.show = true }
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
                    DialogButton { buttonText: "Delete"; colEnabled: Appearance.colors.colError; onClicked: { dlg.show = false; MediaGen.deleteItem(root.item.id); } }
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
