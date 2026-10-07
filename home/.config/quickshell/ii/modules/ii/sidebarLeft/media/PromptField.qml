import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import "MediaCopy.js" as C

ColumnLayout {
    id: root
    readonly property string m: MediaGen.mode()
    readonly property var copy: C.COPY[m] ?? C.COPY.t2i
    visible: m !== "upscale" && m !== "enhance"
    spacing: 6

    StyledText { text: root.copy[0]; color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.smallie; font.weight: Font.Medium; Layout.leftMargin: 2 }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.max(92, area.implicitHeight + 18)
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        border.width: area.activeFocus ? 2 : 0
        border.color: Appearance.colors.colPrimary
        TextEdit {
            id: area
            anchors { fill: parent; margins: 9; leftMargin: 11; rightMargin: 11 }
            wrapMode: TextEdit.Wrap
            color: Appearance.colors.colOnLayer2
            font.family: Appearance.font.family.main; font.pixelSize: Appearance.font.pixelSize.smallie
            selectionColor: Appearance.colors.colPrimaryContainer
            text: MediaGen.prompt
            onTextChanged: if (text !== MediaGen.prompt) MediaGen.prompt = text
            Keys.onPressed: (e) => { if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) { MediaGen.submit(); e.accepted = true; } }
            StyledText {
                anchors.fill: parent; visible: area.text.length === 0; wrapMode: Text.Wrap
                text: root.copy[2]; color: Appearance.colors.colSubtext; opacity: 0.6; font.pixelSize: Appearance.font.pixelSize.smallie
            }
        }
    }
    ColumnLayout {
        visible: area.activeFocus
        spacing: 6
        StyledText { text: root.copy[1]; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller; Layout.leftMargin: 2 }
        Flow {
            Layout.fillWidth: true; spacing: 5
            Repeater {
                model: root.copy[3].filter(w => !MediaGen.prompt.toLowerCase().includes(w))
                delegate: RippleButton {
                    required property string modelData
                    implicitHeight: 22; implicitWidth: chip.implicitWidth + 18
                    buttonRadius: Appearance.rounding.full
                    focusPolicy: Qt.NoFocus   // keep focus in the text area so the chips stay visible
                    onClicked: { MediaGen.prompt = C.appendSuggestion(MediaGen.prompt, modelData); area.forceActiveFocus(); area.cursorPosition = area.length; }
                    contentItem: StyledText { id: chip; anchors.centerIn: parent; text: "+ " + modelData; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
                    background: Rectangle { radius: Appearance.rounding.full; color: "transparent"; border.width: 1; border.color: Appearance.colors.colOutlineVariant }
                }
            }
        }
    }
}
