import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import "MediaCopy.js" as C

ColumnLayout {
    id: root
    visible: MediaGen.mode() === "long"
    spacing: 1
    StyledText {
        Layout.leftMargin: 2; Layout.bottomMargin: 4
        textFormat: Text.StyledText
        text: "Then <font color=\"" + Appearance.colors.colSubtext + "\">· one line per 5 s</font>"
        color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.smallie; font.weight: Font.Medium
    }
    Repeater {
        model: MediaGen.lengthS / 5 - 1
        delegate: Rectangle {
            id: row
            required property int index
            readonly property var beat: MediaGen.beats[index] ?? { text: "", camera: "" }
            readonly property var beatState: MediaGen.busy ? (MediaGen.state.beats?.[index + 1]?.state ?? "next") : ""
            Layout.fillWidth: true
            implicitHeight: 32
            radius: Appearance.rounding.small
            color: (hover.hovered || input.activeFocus) ? Appearance.colors.colLayer1 : "transparent"
            Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
            HoverHandler { id: hover }
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 8
                StyledText { Layout.preferredWidth: 30; text: ((row.index + 1) * 5) + " s"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
                StyledTextInput {
                    id: input
                    Layout.fillWidth: true
                    clip: true
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    text: row.beat.text
                    onTextChanged: { if (text === row.beat.text) return; const b = MediaGen.beats.slice(); b[row.index] = { text: text, camera: row.beat.camera }; MediaGen.beats = b; }
                    StyledText { anchors.fill: parent; visible: input.text.length === 0; text: C.THEN[row.index] ?? "then…"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smallie; elide: Text.ElideRight }
                }
                RippleButton {
                    visible: hover.hovered || input.activeFocus || row.beat.camera !== ""
                    implicitHeight: 20; implicitWidth: camRow.implicitWidth + 16
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer3
                    colBackgroundHover: Appearance.colors.colLayer3Hover
                    colRipple: Appearance.colors.colLayer3Active
                    onClicked: { const b = MediaGen.beats.slice(); const i = C.CAMERAS.indexOf(row.beat.camera); b[row.index] = { text: row.beat.text, camera: C.CAMERAS[(i + 1) % C.CAMERAS.length] }; MediaGen.beats = b; }
                    contentItem: RowLayout {
                        id: camRow; anchors.centerIn: parent; spacing: 3
                        MaterialSymbol { text: "videocam"; iconSize: Appearance.font.pixelSize.smallie; color: Appearance.colors.colOnLayer1 }
                        StyledText { text: C.CAMERA_LABEL[row.beat.camera]; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                    }
                }
                MaterialSymbol {
                    visible: row.beatState !== "" && row.beatState !== "now"
                    text: row.beatState === "done" ? "check_circle" : "radio_button_unchecked"
                    color: Appearance.colors.colSubtext; iconSize: Appearance.font.pixelSize.small
                }
                MaterialLoadingIndicator { visible: row.beatState === "now"; loading: visible; implicitSize: Appearance.font.pixelSize.large }
            }
        }
    }
}
