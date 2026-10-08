import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property var editor
    property alias canvas: canvas
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer0
    clip: true
    TextMetrics { id: sizeMetrics; font.family: Appearance.font.family.main; font.pixelSize: Appearance.font.pixelSize.small; text: "400 px" }
    ColumnLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 8
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: toolbar.implicitHeight + 16
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer1
            ColumnLayout {
                id: toolbar
                anchors { fill: parent; margins: 8 }
                spacing: 8
            RowLayout {
                id: toolRow
                enabled: !root.editor.applying
                Layout.fillWidth: true
                spacing: 4
                component ToolButton: RippleButton {
                    id: tb
                    property string sym
                    property string tip
                    property bool active: false
                    implicitWidth: 36; implicitHeight: 36
                    buttonRadius: Appearance.rounding.full
                    toggled: active
                    focusPolicy: Qt.NoFocus
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: tb.sym; iconSize: Appearance.font.pixelSize.larger; color: tb.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1 }
                    StyledToolTip { text: tb.tip }
                }
                ToolButton { sym: "brush"; tip: "Brush (E)"; active: canvas.tool === "brush"; onClicked: canvas.tool = "brush" }
                ToolButton { sym: "ink_eraser"; tip: "Eraser (E)"; active: canvas.tool === "eraser"; onClicked: canvas.tool = "eraser" }
                ToolButton { sym: "undo"; tip: "Undo (Ctrl + Z)"; onClicked: canvas.undo() }
                ToolButton { sym: "redo"; tip: "Redo (Ctrl + Shift + Z)"; onClicked: canvas.redo() }
                ToolButton { sym: "delete"; tip: "Clear this area"; onClicked: canvas.clearRegion() }
                ToolButton { sym: "crop_free"; tip: "Show boxes"; active: canvas.showBoxes; onClicked: canvas.showBoxes = !canvas.showBoxes }
                StyledSlider {
                    Layout.fillWidth: true; Layout.minimumWidth: 80; Layout.preferredWidth: 120
                    Layout.leftMargin: 8
                    configuration: StyledSlider.Configuration.M; stopIndicatorValues: []
                    from: 0; to: 1
                    value: Math.log(canvas.brushSize / 4) / Math.log(100)
                    usePercentTooltip: false
                    tooltipContent: Math.round(4 * Math.pow(100, value)) + " px"
                    onMoved: canvas.brushSize = Math.round(4 * Math.pow(100, value))
                    focusPolicy: Qt.NoFocus
                }
                StyledText {
                    Layout.preferredWidth: sizeMetrics.width
                    text: Math.round(canvas.brushSize) + " px"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
            StyledText {
                Layout.fillWidth: true; wrapMode: Text.Wrap
                text: "Scroll zoom · Space + drag pan · [ ] brush size"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
            }
        }
        RegionCanvas {
            id: canvas
            Layout.fillWidth: true
            Layout.preferredHeight: imgW > 0 ? Math.min(root.height - toolbar.implicitHeight - 48, width * imgH / imgW) : root.height - toolbar.implicitHeight - 48
            source: MediaGen.regionPath
            frozen: root.editor.applying
        }
        Item { Layout.fillHeight: true }
    }
}
