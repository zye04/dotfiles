import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtMultimedia

// local-suite: Sarah's stage, next to the chat. She owns it: the scene (layout, items, captions, title) comes from her
// sarah_stage_show tool through media.service's state. The only control is hiding it until she shows something new.
Rectangle {
    id: root
    readonly property var scene: MediaGen.stage
    readonly property var items: scene?.items ?? []
    readonly property string layout: scene?.layout ?? "single"
    property int seqIndex: 0
    onSceneChanged: seqIndex = 0
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer0
    clip: true

    Timer {   // sequence: images stay 6 s; a video advances when it ends
        running: root.layout === "sequence" && root.items.length > 1 && root.items[root.seqIndex]?.kind === "image"
        interval: 6000; repeat: true
        onTriggered: root.seqIndex = (root.seqIndex + 1) % root.items.length
    }

    ColumnLayout {
        anchors { fill: parent; margins: 14 }
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true; elide: Text.ElideRight
                text: root.scene?.title || "Sarah"
                font.pixelSize: Appearance.font.pixelSize.normal; font.weight: Font.Medium; color: Appearance.colors.colOnLayer0
            }
            RippleButton {
                implicitWidth: 28; implicitHeight: 28; buttonRadius: Appearance.rounding.full
                onClicked: MediaGen.stageHiddenId = root.scene?.id ?? ""
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; color: Appearance.colors.colSubtext }
                StyledToolTip { text: "Hide until she shows something new" }
            }
        }
        GridLayout {
            id: grid
            Layout.fillWidth: true; Layout.fillHeight: true
            readonly property int n: root.layout === "sequence" ? 1 : root.items.length
            columns: root.layout === "grid" ? Math.ceil(Math.sqrt(n)) : n
            rowSpacing: 10; columnSpacing: 10
            Repeater {
                model: root.layout === "sequence" ? root.items.slice(root.seqIndex, root.seqIndex + 1) : root.items
                delegate: ColumnLayout {
                    id: cell
                    required property var modelData
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.preferredWidth: 1; Layout.preferredHeight: 1
                    spacing: 6
                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        opacity: 0
                        Component.onCompleted: opacity = 1
                        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                        Image {
                            id: pic
                            anchors.fill: parent; visible: cell.modelData.kind === "image"
                            fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                            source: cell.modelData.kind === "image" ? "file://" + cell.modelData.path : ""
                        }
                        MediaPlayer {
                            id: player
                            source: cell.modelData.kind === "video" ? "file://" + cell.modelData.path : ""
                            videoOutput: out
                            audioOutput: AudioOutput { muted: true }
                            loops: root.layout === "sequence" && root.items.length > 1 ? 1 : MediaPlayer.Infinite
                            Component.onCompleted: if (cell.modelData.kind === "video") play()
                            onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia && root.layout === "sequence" && root.items.length > 1)
                                root.seqIndex = (root.seqIndex + 1) % root.items.length
                        }
                        VideoOutput { id: out; anchors.fill: parent; visible: cell.modelData.kind === "video"; fillMode: VideoOutput.PreserveAspectFit }
                        Rectangle {   // caption, over the bottom of the picture itself
                            visible: (cell.modelData.caption ?? "") !== ""
                            readonly property real picH: cell.modelData.kind === "video" ? out.contentRect.height : pic.paintedHeight
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.verticalCenter; bottomMargin: -picH / 2 + 10 }
                            width: Math.min(parent.width - 20, cap.implicitWidth + 20); height: cap.implicitHeight + 10
                            radius: Appearance.rounding.small; color: Qt.rgba(0, 0, 0, 0.55)
                            StyledText {
                                id: cap; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.parent.width - 40)
                                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                                text: cell.modelData.caption ?? ""; font.pixelSize: Appearance.font.pixelSize.smallie; color: "white"
                            }
                        }
                    }
                }
            }
        }
        Row {   // sequence position
            visible: root.layout === "sequence" && root.items.length > 1
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Repeater {
                model: root.items.length
                delegate: Rectangle {
                    required property int index
                    width: 6; height: 6; radius: 3
                    color: index === root.seqIndex ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    opacity: index === root.seqIndex ? 1 : 0.4
                }
            }
        }
    }
}
