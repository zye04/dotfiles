import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "MediaCopy.js" as C

RowLayout {
    id: root
    readonly property string m: MediaGen.mode()
    readonly property bool showShape: (m === "t2i" || m === "t2v" || m === "long") && MediaGen.srcPath === ""
    readonly property bool showLength: MediaGen.kind === "video" && m !== "enhance"
    readonly property bool showScale: m === "upscale"
    readonly property bool showQuality: m !== "upscale" && m !== "enhance"
    visible: showShape || showLength || showScale || showQuality
    spacing: 6

    component Pill: RippleButton {
        id: pill
        property string label
        property string value
        property var options: []           // [[value, display, hint]]
        signal picked(var v)
        implicitHeight: 32; implicitWidth: pillRow.implicitWidth + 22
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        onClicked: menu.open()
        contentItem: RowLayout {
            id: pillRow; anchors.centerIn: parent; spacing: 4
            StyledText { text: pill.label; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smallie }
            StyledText { text: pill.value; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.smallie }
            MaterialSymbol { text: "expand_more"; iconSize: 16; color: Appearance.colors.colSubtext }
        }
        Popup {
            id: menu
            y: pill.height + 6
            padding: 4
            background: Rectangle { radius: Appearance.rounding.small; color: Appearance.colors.colLayer2; border.width: 0
                StyledRectangularShadow { target: parent } }
            contentItem: ColumnLayout {
                spacing: 0
                Repeater {
                    model: pill.options
                    delegate: RippleButton {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 32; implicitWidth: optRow.implicitWidth + 20
                        buttonRadius: 8
                        colBackground: modelData[1] === pill.value ? Appearance.colors.colSecondaryContainer : "transparent"
                        onClicked: { pill.picked(modelData[0]); menu.close(); }
                        contentItem: RowLayout {
                            id: optRow; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 16
                            StyledText { text: modelData[1]; font.pixelSize: Appearance.font.pixelSize.smallie; color: Appearance.colors.colOnLayer2 }
                            Item { Layout.fillWidth: true }
                            StyledText { text: modelData[2] ?? ""; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                        }
                    }
                }
            }
        }
    }

    Pill { visible: root.showShape; label: "Shape"; value: MediaGen.shape
           options: C.SHAPES.map(s => [s[0], s[0], s[1]]); onPicked: (v) => MediaGen.shape = v }
    Pill { visible: root.showLength; label: "Length"; value: MediaGen.lengthS + " s"
           options: C.LENGTHS.map(l => [l[0], l[0] + " s", l[1]]); onPicked: (v) => MediaGen.setLength(v) }
    Pill { visible: root.showScale; label: "Scale"; value: MediaGen.scale === 1.5 ? "1.5×" : "2×"
           options: [[1.5, "1.5×", ""], [2.0, "2×", ""]]; onPicked: (v) => MediaGen.scale = v }
    Pill { visible: root.showQuality; label: "Quality"; value: MediaGen.quality.charAt(0).toUpperCase() + MediaGen.quality.slice(1)
           options: ["draft", "balanced", "realistic"].map(q => [q, q.charAt(0).toUpperCase() + q.slice(1), (MediaGen.kind === "video" ? C.QUALITY_HINT_VIDEO : C.QUALITY_HINT_IMAGE)[q]])
           onPicked: (v) => MediaGen.quality = v }
    Item { Layout.fillWidth: true }
}
