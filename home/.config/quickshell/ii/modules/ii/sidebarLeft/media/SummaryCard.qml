import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    property string kind: "finish"
    signal openRequested()
    readonly property bool isFinish: kind === "finish"
    readonly property var finishRows: [["upscale", "Upscale 2×"], ["cinematic24", "Cinematic 24 fps"], ["grain", "Film grain"]]
    readonly property int changed: ["steps", "cfg", "seed"].filter(k => MediaGen.adv[k] !== null).length
    visible: isFinish ? MediaGen.kind === "video" : (MediaGen.mode() !== "upscale" && MediaGen.mode() !== "enhance")
    implicitHeight: col.implicitHeight + 20
    buttonRadius: Appearance.rounding.normal
    colBackground: Appearance.colors.colLayer1
    colBackgroundHover: Appearance.colors.colLayer2
    onClicked: openRequested()
    contentItem: ColumnLayout {
        id: col
        anchors { fill: parent; margins: 10; leftMargin: 12; rightMargin: 12 }
        spacing: 5
        RowLayout {
            StyledText {
                textFormat: Text.StyledText; font.pixelSize: Appearance.font.pixelSize.smallie; font.weight: Font.Medium; color: Appearance.colors.colOnLayer1
                text: root.isFinish ? "Finish" : "Advanced <font color=\"" + Appearance.colors.colSubtext + "\">· " + (root.changed ? root.changed + " changed" : MediaGen.quality + " preset") + "</font>"
            }
            Item { Layout.fillWidth: true }
            MaterialSymbol { text: root.isFinish ? "edit" : "tune"; iconSize: 16; color: Appearance.colors.colSubtext; opacity: root.hovered ? 1 : 0
                             Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) } }
        }
        Repeater {
            model: root.isFinish ? root.finishRows : []
            delegate: RowLayout {
                required property var modelData
                readonly property bool on: MediaGen.finish[modelData[0]]
                Layout.fillWidth: true
                MaterialSymbol { text: parent.on ? "check" : "remove"; iconSize: 15; color: parent.on ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext }
                StyledText { text: modelData[1]; font.pixelSize: Appearance.font.pixelSize.smaller; color: parent.on ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext; Layout.fillWidth: true }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext
                    text: parent.on ? "+" + MediaGen.fmtDuration((MediaGen.presets?.estimates_s.finish_per_beat[modelData[0]] ?? 0) * MediaGen.lengthS / 5).slice(1) : "off"
                }
            }
        }
        StyledText {
            visible: !root.isFinish
            textFormat: Text.StyledText; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1
            readonly property string dim: Appearance.colors.colSubtext
            readonly property string dot: " <font color=\"" + Appearance.colors.colPrimary + "\">•</font>"
            text: (MediaGen.adv.steps ?? MediaGen.presetValue("steps") ?? "–") + " <font color=\"" + dim + "\">steps</font>" + (MediaGen.adv.steps !== null ? dot : "")
                + "&nbsp;&nbsp;<font color=\"" + dim + "\">strength</font> " + (MediaGen.adv.cfg ?? MediaGen.presetValue("cfg") ?? "–") + (MediaGen.adv.cfg !== null ? dot : "")
                + "&nbsp;&nbsp;<font color=\"" + dim + "\">seed</font> " + (MediaGen.adv.seed ?? "random") + (MediaGen.adv.seed !== null ? dot : "")
        }
    }
}
