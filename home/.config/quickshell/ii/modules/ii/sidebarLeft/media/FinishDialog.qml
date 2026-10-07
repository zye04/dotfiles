import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

WindowDialog {
    id: root
    backgroundWidth: 400
    onDismiss: show = false
    readonly property var dims: MediaGen.videoDims()
    readonly property string upscaleNote: dims ? "Sharper, " + dims[0] + "×" + dims[1] + " → " + dims[0] * 2 + "×" + dims[1] * 2 : "Sharper, twice the resolution"
    WindowDialogTitle { text: "Finish" }
    WindowDialogParagraph { text: "Runs after generation. Each step adds time." }
    Repeater {
        model: [["upscale", "hd", "Upscale 2×", root.upscaleNote],
                ["cinematic24", "animation", "Cinematic 24 fps", MediaGen.mode() === "enhance" ? "Film-like motion blur" : "Film-like motion blur, from 16 fps"],
                ["grain", "grain", "Film grain", "Subtle sensor noise, reads more like camera footage"]]
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: 12
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                RowLayout { spacing: 6
                    MaterialSymbol { text: modelData[1]; color: Appearance.colors.colOnLayer1 }
                    StyledText { text: modelData[2]; font.pixelSize: Appearance.font.pixelSize.small } }
                StyledText {
                    Layout.fillWidth: true; wrapMode: Text.Wrap; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller
                    text: modelData[3] + " · +" + MediaGen.fmtDuration((MediaGen.presets?.estimates_s.finish_per_beat[modelData[0]] ?? 0) * MediaGen.costBeats()).slice(1)
                }
            }
            StyledSwitch {
                checked: MediaGen.finish[modelData[0]]
                onToggled: { const f = Object.assign({}, MediaGen.finish); f[modelData[0]] = checked; MediaGen.finish = f; }
            }
        }
    }
    WindowDialogButtonRow {
        Item { Layout.fillWidth: true }
        DialogButton { buttonText: "Done"; onClicked: root.show = false }
    }
}
