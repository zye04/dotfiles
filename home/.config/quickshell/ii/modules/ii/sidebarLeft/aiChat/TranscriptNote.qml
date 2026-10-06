import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

// A dim one-line note in the transcript (turn end, interruption): glyph in the bullet column, then text.
Item {
    id: root
    property string glyph
    property string text
    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: label.implicitHeight + 4

    StyledText {
        width: 10
        x: 14
        y: 2
        horizontalAlignment: Text.AlignHCenter
        text: root.glyph
        font.family: Appearance.font.family.monospace
        font.pixelSize: Ai.chatFontSize
        color: Appearance.colors.colSubtext
    }
    StyledText {
        id: label
        x: 34
        y: 2
        width: parent.width - 34 - 8
        wrapMode: Text.Wrap
        text: root.text
        font.family: Appearance.font.family.monospace
        font.pixelSize: Ai.chatFontSize
        color: Appearance.colors.colSubtext
    }
}
