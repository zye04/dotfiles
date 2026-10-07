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
    ColumnLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 8
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 76
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer1
            RowLayout {
                id: toolRow
                enabled: !root.editor.applying
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
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
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: tb.sym; iconSize: 20; color: tb.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1 }
                    StyledToolTip { text: tb.tip }
                }
                ToolButton { sym: "brush"; tip: "Brush (E)"; active: canvas.tool === "brush"; onClicked: canvas.tool = "brush" }
                ToolButton { sym: "ink_eraser"; tip: "Eraser (E)"; active: canvas.tool === "eraser"; onClicked: canvas.tool = "eraser" }
                ToolButton { sym: "undo"; tip: "Undo (Ctrl+Z)"; onClicked: canvas.undo() }
                ToolButton { sym: "redo"; tip: "Redo (Ctrl+Shift+Z)"; onClicked: canvas.redo() }
                ToolButton { sym: "delete"; tip: "Clear this area"; onClicked: canvas.clearRegion() }
                ToolButton { sym: "crop_free"; tip: "Show boxes"; active: canvas.showBoxes; onClicked: canvas.showBoxes = !canvas.showBoxes }
                StyledSlider {
                    Layout.fillWidth: true; Layout.minimumWidth: 80; Layout.preferredWidth: 120
                    Layout.leftMargin: 8
                    from: 4; to: 400; stepSize: 1
                    value: canvas.brushSize
                    usePercentTooltip: false
                    tooltipContent: Math.round(value) + " px"
                    onMoved: canvas.brushSize = value
                    focusPolicy: Qt.NoFocus
                }
                StyledText {
                    Layout.preferredWidth: 48
                    text: Math.round(canvas.brushSize) + " px"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
            StyledText {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                text: "Scroll zoom · Space+drag pan · [ ] brush size"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
        RegionCanvas {
            id: canvas
            Layout.fillWidth: true; Layout.fillHeight: true
            source: MediaGen.regionPath
            frozen: root.editor.applying
        }
    }
}
