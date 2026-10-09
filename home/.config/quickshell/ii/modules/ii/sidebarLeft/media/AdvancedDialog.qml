import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

WindowDialog {
    id: root
    backgroundWidth: 400
    onDismiss: show = false
    readonly property bool generation: MediaGen.regionPath !== "" || !["upscale", "enhance"].includes(MediaGen.mode())
    readonly property bool anyChanged: MediaGen.adv.steps !== null || MediaGen.adv.cfg !== null || MediaGen.adv.seed !== null || Object.keys(MediaGen.adv.models ?? {}).length > 0 || Object.keys(MediaGen.adv.loras ?? {}).length > 0
    function setAdv(k, v) { const a = Object.assign({}, MediaGen.adv); a[k] = v; MediaGen.adv = a; }

    component HelpIcon: MaterialSymbol {
        property string tip: ""
        property bool hovered: hover.hovered
        visible: tip !== ""
        text: "help"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext
        HoverHandler { id: hover }
        StyledToolTip { text: parent.tip.replace(/(.{1,48})(\s+|$)/g, "$1\n").trim() }  // shared tooltip has no max width
    }

    WindowDialogTitle { text: "Advanced" }
    WindowDialogParagraph { text: root.generation ? "Overrides the " + MediaGen.quality.charAt(0).toUpperCase() + MediaGen.quality.slice(1) + " preset for this job only." : "Model choices for this job." }

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
            Rectangle { width: 6; height: 6; radius: Appearance.rounding.full; color: Appearance.colors.colPrimary; visible: MediaGen.adv[sr.key] !== null }
            Item { Layout.fillWidth: true }
            StyledText { text: sr.step < 1 ? sr.current.toFixed(1) : Math.round(sr.current); font.pixelSize: Appearance.font.pixelSize.smallie }
        }
        StyledSlider {
            Layout.fillWidth: true
            from: sr.from; to: sr.to; stepSize: sr.step; value: sr.current
            usePercentTooltip: false
            tooltipContent: sr.step < 1 ? value.toFixed(1) : String(Math.round(value))
            onMoved: root.setAdv(sr.key, value === MediaGen.presetValue(sr.key) ? null : value)
        }
        RowLayout {
            StyledText { text: sr.lo; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
            Item { Layout.fillWidth: true }
            StyledText { text: sr.hi; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
        }
    }

    SliderRow { visible: root.generation; key: "steps"; label: "Steps"; from: 4; to: 30; step: 1; lo: "faster"; hi: "more detail" }
    SliderRow { visible: root.generation; key: "cfg"; label: "Prompt strength"; from: 1; to: 7; step: 0.5; lo: "looser"; hi: "follows the prompt" }
    ColumnLayout {
        visible: root.generation
        Layout.fillWidth: true; spacing: 6
        RowLayout {
            StyledText { text: "Seed"; font.pixelSize: Appearance.font.pixelSize.smallie }
            Rectangle { width: 6; height: 6; radius: Appearance.rounding.full; color: Appearance.colors.colPrimary; visible: MediaGen.adv.seed !== null }
            Item { Layout.fillWidth: true }
            StyledText { text: "same seed + settings = same result"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
        }
        RowLayout {
            spacing: 6
            Rectangle { Layout.fillWidth: true; implicitHeight: 32; radius: Appearance.rounding.full; color: Appearance.colors.colLayer2
                StyledText { anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 } text: MediaGen.adv.seed ?? "random"; color: Appearance.colors.colOnLayer2 } }
            RippleButton { implicitWidth: 32; implicitHeight: 32; buttonRadius: Appearance.rounding.full; colBackground: Appearance.colors.colLayer2; colBackgroundHover: Appearance.colors.colLayer2Hover; colRipple: Appearance.colors.colLayer2Active
                onClicked: root.setAdv("seed", Math.floor(Math.random() * 2147483647))
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "casino" } StyledToolTip { text: "New random seed" } }
            RippleButton { implicitWidth: 32; implicitHeight: 32; buttonRadius: Appearance.rounding.full; colBackground: Appearance.colors.colLayer2; colBackgroundHover: Appearance.colors.colLayer2Hover; colRipple: Appearance.colors.colLayer2Active
                onClicked: root.setAdv("seed", null)
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "shuffle" } StyledToolTip { text: "Back to random" } }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 6
        visible: MediaGen.modelRoles().length > 0
        StyledText { text: "Models"; font.pixelSize: Appearance.font.pixelSize.smallie; color: Appearance.colors.colOnLayer1 }
        Repeater {
            model: MediaGen.modelRoles()
            delegate: RowLayout {
                id: mr
                required property string modelData
                readonly property var info: MediaGen.presets.models[modelData]
                readonly property var keys: Object.keys(info.options)
                readonly property string curLabel: info.options[MediaGen.modelKey(modelData)]?.label ?? MediaGen.modelKey(modelData)
                Layout.fillWidth: true; spacing: 6
                StyledText { text: ({ image: "Image generator", video: "Video generator", upscaler: "Upscaler", interpolation: "Frame interpolation" })[mr.modelData] ?? mr.modelData
                             font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                HelpIcon { tip: mr.info.options[MediaGen.modelKey(mr.modelData)]?.help ?? "" }
                Rectangle { width: 6; height: 6; radius: Appearance.rounding.full; color: Appearance.colors.colPrimary; visible: MediaGen.adv.models?.[mr.modelData] !== undefined }
                Item { Layout.fillWidth: true }
                StyledText { visible: mr.keys.length < 2; text: mr.curLabel; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                StyledComboBox {
                    id: modelPicker
                    visible: mr.keys.length >= 2
                    Layout.preferredWidth: 170; Layout.minimumWidth: 0
                    implicitHeight: 32
                    textRole: "label"; valueRole: "key"
                    model: mr.keys.map(k => ({ key: k, label: mr.info.options[k].label, icon: "" }))
                    readonly property int selectedIndex: mr.keys.indexOf(MediaGen.modelKey(mr.modelData))
                    onSelectedIndexChanged: currentIndex = selectedIndex
                    onModelChanged: Qt.callLater(() => currentIndex = selectedIndex)
                    Component.onCompleted: currentIndex = selectedIndex
                    onActivated: (index) => MediaGen.setModel(mr.modelData, mr.keys[index])
                }
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 6
        visible: MediaGen.loraKeys().length > 0
        StyledText { text: "LoRAs"; font.pixelSize: Appearance.font.pixelSize.smallie; color: Appearance.colors.colOnLayer1 }
        Repeater {
            model: MediaGen.loraKeys()
            delegate: ColumnLayout {
                id: lr
                required property string modelData
                readonly property var meta: MediaGen.loraMeta(modelData)
                readonly property real val: MediaGen.loraValue(modelData)
                Layout.fillWidth: true; spacing: 0
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    StyledText { Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; text: lr.meta?.label ?? lr.modelData; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                    HelpIcon { tip: lr.meta?.help ?? "" }
                    Rectangle { width: 6; height: 6; radius: Appearance.rounding.full; color: Appearance.colors.colPrimary; visible: MediaGen.adv.loras?.[lr.modelData] !== undefined }
                    Item { Layout.fillWidth: true }
                    StyledText { text: lr.val < 0.025 ? "off" : lr.val.toFixed(2); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                }
                StyledSlider {
                    Layout.fillWidth: true
                    from: 0; to: 1.5; stepSize: 0.05; value: lr.val
                    usePercentTooltip: false
                    tooltipContent: value < 0.025 ? "off" : value.toFixed(2)
                    onMoved: MediaGen.setLora(lr.modelData, value)
                }
            }
        }
    }
    WindowDialogButtonRow {
        DialogButton { buttonText: "Reset"; enabled: root.anyChanged; onClicked: MediaGen.adv = { steps: null, cfg: null, seed: null, models: {}, loras: {} } }
        Item { Layout.fillWidth: true }
        DialogButton { buttonText: "Done"; onClicked: root.show = false }
    }
}
