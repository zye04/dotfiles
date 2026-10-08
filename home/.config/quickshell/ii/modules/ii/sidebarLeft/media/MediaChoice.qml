import qs.modules.common
import qs.modules.common.widgets
import QtQuick

StyledComboBox {
    id: root
    property string label: ""
    property var options: []
    property var selectedValue
    signal picked(var value)
    model: options.map(o => ({ value: o[0], label: o[1] + (o[2] ? " · " + o[2] : ""), hint: o[2] ?? "", icon: "" }))
    textRole: "label"
    valueRole: "value"
    function syncSelection() { currentIndex = options.findIndex(o => o[0] === selectedValue); }
    onSelectedValueChanged: syncSelection()
    onModelChanged: Qt.callLater(syncSelection)
    Component.onCompleted: syncSelection()
    displayText: (label ? label + " · " : "") + (options[currentIndex]?.[1] ?? "")
    implicitWidth: Math.max(100, metrics.width + 68)
    onActivated: picked(currentValue)
    Binding { target: root.popup; property: "width"; value: Math.max(root.width, 260) }
    TextMetrics { id: metrics; font.family: Appearance.font.family.main; font.pixelSize: Appearance.font.pixelSize.small; text: root.displayText }
    StyledToolTip { text: root.options[root.currentIndex]?.[2] ?? "" }
}
