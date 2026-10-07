import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

WindowDialog {
    id: root
    backgroundWidth: 400
    onDismiss: show = false
    readonly property bool anyChanged: MediaGen.adv.steps !== null || MediaGen.adv.cfg !== null || MediaGen.adv.seed !== null
    function setAdv(k, v) { const a = Object.assign({}, MediaGen.adv); a[k] = v; MediaGen.adv = a; }

    WindowDialogTitle { text: "Advanced" }
    WindowDialogParagraph { text: "Overrides the " + MediaGen.quality + " preset for this job only." }

    component SliderRow: ColumnLayout {
        id: sr
        property string key
        property string label
        property real from
        property real to
        property real step
        property string lo
        property string hi
        readonly property real current: MediaGen.adv[key] ?? MediaGen.presetValue(key) ?? from
        Layout.fillWidth: true; spacing: 2
        RowLayout {
            StyledText { text: sr.label; font.pixelSize: Appearance.font.pixelSize.smallie; color: Appearance.colors.colOnLayer1 }
            Rectangle { width: 6; height: 6; radius: 3; color: Appearance.colors.colPrimary; visible: MediaGen.adv[sr.key] !== null }
            Item { Layout.fillWidth: true }
            StyledText { text: sr.current; font.pixelSize: Appearance.font.pixelSize.smallie }
        }
        StyledSlider {
            Layout.fillWidth: true
            from: sr.from; to: sr.to; stepSize: sr.step; value: sr.current
            onMoved: root.setAdv(sr.key, value === MediaGen.presetValue(sr.key) ? null : value)
        }
        RowLayout {
            StyledText { text: sr.lo; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
            Item { Layout.fillWidth: true }
            StyledText { text: sr.hi; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
        }
    }

    SliderRow { key: "steps"; label: "Steps"; from: 4; to: 30; step: 1; lo: "faster"; hi: "more detail" }
    SliderRow { key: "cfg"; label: "Prompt strength"; from: 1; to: 7; step: 0.5; lo: "looser"; hi: "follows the prompt" }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 6
        RowLayout {
            StyledText { text: "Seed"; font.pixelSize: Appearance.font.pixelSize.smallie }
            Rectangle { width: 6; height: 6; radius: 3; color: Appearance.colors.colPrimary; visible: MediaGen.adv.seed !== null }
            Item { Layout.fillWidth: true }
            StyledText { text: "same seed + settings = same result"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
        }
        RowLayout {
            spacing: 6
            Rectangle { Layout.fillWidth: true; implicitHeight: 32; radius: Appearance.rounding.full; color: Appearance.colors.colLayer2
                StyledText { anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 } text: MediaGen.adv.seed ?? "random"; color: Appearance.colors.colOnLayer2 } }
            RippleButton { implicitWidth: 32; implicitHeight: 32; buttonRadius: Appearance.rounding.full; colBackground: Appearance.colors.colLayer2
                onClicked: root.setAdv("seed", Math.floor(Math.random() * 2147483647))
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "casino" } StyledToolTip { text: "New random seed" } }
            RippleButton { implicitWidth: 32; implicitHeight: 32; buttonRadius: Appearance.rounding.full; colBackground: Appearance.colors.colLayer2
                onClicked: root.setAdv("seed", null)
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "shuffle" } StyledToolTip { text: "Back to random" } }
        }
    }
    WindowDialogButtonRow {
        DialogButton { buttonText: "Reset"; enabled: root.anyChanged; opacity: enabled ? 1 : 0.35; onClicked: MediaGen.adv = { steps: null, cfg: null, seed: null } }
        Item { Layout.fillWidth: true }
        DialogButton { buttonText: "Done"; onClicked: root.show = false }
    }
}
