import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "Markdown.js" as Markdown

// local-suite: Claude Code-style message. No card or header:
// - user:      tinted row with a "›" prefix
// - assistant: small dotted-globe orb, then a dim footer (time · speed · clock)
// - interface: dim "⎿" line (command output, not sent to the model)
// Double-click copies the whole message; drag selects part of it.
Item {
    id: root
    property int messageIndex
    property var messageData
    property var messageInputField

    readonly property string role: messageData?.role ?? ""
    readonly property bool isUser: role === "user"
    readonly property bool isAssistant: role === "assistant"
    property bool copiedFlash: false

    property list<var> messageBlocks: root.isUser ? [{ type: "text", content: root.messageData?.content ?? "" }] : StringUtils.splitMarkdownBlocks(root.messageData?.content)

    // Centring the prefix: the visual middle of a text line is halfway between the
    // middle of its lowercase letters and the middle of its capitals, measured from
    // the baseline. Line boxes include descender space, so centring on them looks off.
    FontMetrics {
        id: readingMetrics
        font.family: Appearance.font.family.monospace
        font.pixelSize: Ai.chatFontSize
    }
    function glyphCenter(metrics) { // offset from the baseline (negative = up)
        const x = metrics.tightBoundingRect("x"), h = metrics.tightBoundingRect("H");
        return ((x.y + x.height / 2) + (h.y + h.height / 2)) / 2;
    }
    // y of the first line's visual middle, in `row` coordinates
    property real firstLineCenterY: 6 + readingMetrics.ascent + glyphCenter(readingMetrics)
    function updateFirstLineCenter() {
        const text = blocksRepeater.count > 0 ? blocksRepeater.itemAt(0)?.firstTextItem : null;
        if (!text) return;
        root.firstLineCenterY = text.mapToItem(row, 0, text.baselineOffset + glyphCenter(readingMetrics)).y;
    }
    onWidthChanged: updateFirstLineCenter()
    Component.onCompleted: updateFirstLineCenter()

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: background.implicitHeight

    function plainText() {
        return (root.messageData?.rawContent ?? "").replace(/<think>[\s\S]*?<\/think>\s*/g, "").trim();
    }

    Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: root.copiedFlash = false
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onDoubleTapped: {
            Quickshell.clipboardText = root.plainText();
            root.copiedFlash = true;
            copiedTimer.restart();
        }
    }

    Rectangle {
        id: background
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: row.implicitHeight + (root.isUser ? 10 : 4)
        radius: Appearance.rounding.small
        color: root.copiedFlash ? Appearance.colors.colSecondaryContainer :
            root.isUser ? Appearance.colors.colLayer2 : "transparent"
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        RowLayout {
            id: row
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                // Bullet column centred at x = 19 and text starting at x = 34, the same as
                // the orb and model name in the prompt area below (AiChat.qml).
                leftMargin: 14
                rightMargin: 8
                topMargin: root.isUser ? 5 : 2
            }
            spacing: 10

            Item { // Prefix, centred on the visual middle of the first line
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 10
                implicitHeight: root.firstLineCenterY * 2

                StyledText {
                    id: prefixText
                    visible: !root.isAssistant
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.firstLineCenterY - (baselineOffset + root.glyphCenter(prefixMetrics))
                    text: root.isUser ? "›" : "⎿"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Ai.chatFontSize
                    color: Appearance.colors.colSubtext
                    FontMetrics {
                        id: prefixMetrics
                        font: prefixText.font
                    }
                }
                Orb { // Same globe as the prompt area, scaled down; spins while this reply streams
                    visible: root.isAssistant
                    follow: false
                    size: 11
                    spinning: !(root.messageData?.done ?? true)
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.firstLineCenterY - height / 2
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                spacing: readingMetrics.height // one blank line between blocks
                onImplicitHeightChanged: root.updateFirstLineCenter()
                opacity: root.isUser || root.isAssistant ? 1 : 0.75

                Loader { // Attached image
                    Layout.fillWidth: true
                    visible: active
                    active: root.messageData?.localFilePath && root.messageData?.localFilePath.length > 0
                    sourceComponent: AttachedFileIndicator {
                        filePath: root.messageData?.localFilePath
                        canRemove: false
                    }
                }

                Item { // Waiting for the first token
                    Layout.fillWidth: true
                    implicitHeight: loadingIndicatorLoader.shown ? loadingIndicatorLoader.implicitHeight : 0
                    visible: implicitHeight > 0
                    FadeLoader {
                        id: loadingIndicatorLoader
                        anchors.left: parent.left
                        shown: (root.messageBlocks.length < 1) && (!root.messageData?.done)
                        sourceComponent: MaterialLoadingIndicator {
                            loading: true
                        }
                    }
                }

                Repeater {
                    id: blocksRepeater
                    onItemAdded: root.updateFirstLineCenter()
                    model: ScriptModel {
                        values: root.messageBlocks
                    }
                    delegate: DelegateChooser {
                        role: "type"

                        DelegateChoice { roleValue: "code"; MessageCodeBlock {
                            enableMouseSelection: true
                            segmentContent: modelData.content
                            segmentLang: modelData.lang
                            indentCols: Markdown.context(root.messageBlocks, index).col
                            messageData: root.messageData
                        } }
                        DelegateChoice { roleValue: "think"; MessageThinkBlock {
                            enableMouseSelection: true
                            segmentContent: modelData.content
                            messageData: root.messageData
                            done: root.messageData?.done ?? false
                            completed: modelData.completed ?? false
                        } }
                        DelegateChoice { roleValue: "text"; MessageTextBlock {
                            enableMouseSelection: true
                            renderMarkdown: !root.isUser
                            segmentContent: modelData.content
                            listContext: root.isUser ? [] : Markdown.context(root.messageBlocks, index).stack
                            messageData: root.messageData
                            done: root.messageData?.done ?? false
                        } }
                    }
                }
            }
        }
    }
}
