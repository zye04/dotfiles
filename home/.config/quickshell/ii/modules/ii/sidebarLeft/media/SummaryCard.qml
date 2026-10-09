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
    readonly property bool generation: MediaGen.regionPath !== "" || !["upscale", "enhance"].includes(MediaGen.mode())
    readonly property var modelNotes: Object.entries(MediaGen.adv.models ?? {}).filter(e => MediaGen.modelRoles().includes(e[0]) && MediaGen.presets?.models?.[e[0]]).map(e => MediaGen.presets.models[e[0]].options[e[1]]?.label ?? e[1])
    readonly property var loraNotes: Object.entries(MediaGen.loraOverrides(MediaGen.regionPath !== "" ? "region" : MediaGen.apiMode())).map(e => (MediaGen.loraMeta(e[0])?.label ?? e[0]) + " " + (e[1] < 0.025 ? "off" : e[1].toFixed(2)))
    readonly property int changed: (generation ? ["steps", "cfg", "seed"].filter(k => MediaGen.adv[k] !== null).length : 0) + modelNotes.length + loraNotes.length
    visible: isFinish ? MediaGen.kind === "video" : MediaGen.modelRoles().length > 0
    implicitHeight: col.implicitHeight + 20
    buttonRadius: Appearance.rounding.normal
    colBackground: Appearance.colors.colLayer1
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    onClicked: openRequested()
    contentItem: ColumnLayout {
        id: col
        anchors { fill: parent; margins: 10; leftMargin: 12; rightMargin: 12 }
        spacing: 5
        RowLayout {
            StyledText {
                textFormat: Text.StyledText; font.pixelSize: Appearance.font.pixelSize.smallie; font.weight: Font.Medium; color: Appearance.colors.colOnLayer1
                text: root.isFinish ? "Finish" : "Advanced <font color=\"" + Appearance.colors.colSubtext + "\">· " + (root.changed ? root.changed + " changed" : root.generation ? MediaGen.quality.charAt(0).toUpperCase() + MediaGen.quality.slice(1) + " preset" : "Models") + "</font>"
            }
            Item { Layout.fillWidth: true }
            MaterialSymbol { text: root.isFinish ? "edit" : "tune"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext; opacity: root.hovered ? 1 : 0
                             Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) } }
        }
        Repeater {
            model: root.isFinish ? root.finishRows : []
            delegate: RowLayout {
                required property var modelData
                readonly property bool on: MediaGen.finish[modelData[0]]
                Layout.fillWidth: true
                MaterialSymbol { text: parent.on ? "check" : "remove"; iconSize: Appearance.font.pixelSize.small; color: parent.on ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext }
                StyledText { text: modelData[1]; font.pixelSize: Appearance.font.pixelSize.smaller; color: parent.on ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext; Layout.fillWidth: true }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext
                    text: parent.on ? "+" + MediaGen.fmtDuration((MediaGen.presets?.estimates_s.finish_per_beat[modelData[0]] ?? 0) * MediaGen.costBeats()).slice(1) : "off"
                }
            }
        }
        StyledText {
            visible: !root.isFinish
            Layout.fillWidth: true; wrapMode: Text.Wrap
            textFormat: Text.StyledText; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1
            readonly property string dim: Appearance.colors.colSubtext
            readonly property string dot: " <font color=\"" + Appearance.colors.colPrimary + "\">•</font>"
            text: !root.generation ? MediaGen.modelRoles().map(r => MediaGen.presets?.models?.[r]?.options?.[MediaGen.modelKey(r)]?.label ?? r).join(" · ") : (MediaGen.adv.steps ?? MediaGen.presetValue("steps") ?? "–") + " <font color=\"" + dim + "\">steps</font>" + (MediaGen.adv.steps !== null ? dot : "")
                + "&nbsp;&nbsp;<font color=\"" + dim + "\">strength</font> " + (MediaGen.adv.cfg ?? MediaGen.presetValue("cfg") ?? "–") + (MediaGen.adv.cfg !== null ? dot : "")
                + "&nbsp;&nbsp;<font color=\"" + dim + "\">seed</font> " + (MediaGen.adv.seed ?? "random") + (MediaGen.adv.seed !== null ? dot : "")
                + (root.modelNotes.length ? "<br><font color=\"" + dim + "\">model</font> " + root.modelNotes.join(", ") + dot : "")
                + (root.loraNotes.length ? "<br><font color=\"" + dim + "\">LoRAs</font> " + root.loraNotes.join(", ") + dot : "")
        }
    }
}
