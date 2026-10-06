pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "Markdown.js" as Markdown

ColumnLayout {
    id: root
    // These are needed on the parent loader
    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ({})
    property var messageData: {}
    property bool done: true
    property var listContext: [] // open list items from earlier blocks of the message

    property list<string> renderedLatexHashes: []
    property string renderedSegmentContent: ""
    property string shownText: ""
    // local-suite: lets AiMessage centre its bullet on the first line of text
    readonly property var firstTextItem: textArea
    readonly property bool dimmed: messageData?.thinking || messageData?.partType === "reasoning" || messageData?.role === "interface"
    readonly property color accentColor: Appearance.colors.colPrimary
    readonly property color dimColor: Appearance.colors.colSubtext
    readonly property color bodyColor: dimmed ? dimColor
        : Appearance.m3colors.darkmode ? Qt.lighter(Appearance.m3colors.m3onSurface, 1.12) : Appearance.m3colors.m3onSurface
    FontMetrics {
        id: metrics
        font.family: Appearance.font.family.monospace
        font.pixelSize: Ai.chatFontSize
    }
    readonly property string richText: Markdown.render(shownText, {
        cw: metrics.advanceWidth("0"), gap: Math.round(metrics.height),
        code: String(accentColor), link: String(accentColor), dim: String(dimColor),
        rule: String(Qt.alpha(dimColor, 0.5))
    }, listContext).html

    Layout.fillWidth: true

    Timer {
        id: renderTimer
        interval: 1000
        repeat: false
        onTriggered: {
            renderLatex()
            for (const hash of renderedLatexHashes) {
                handleRenderedLatex(hash, true);
            }
        }
    }

    function renderLatex() {
        // Regex for $...$, $$...$$, \[...\]
        // Note: This is a simple approach and may need refinement for edge cases
        let regex = /(\$\$([\s\S]+?)\$\$)|(\$([^\$]+?)\$)|(\\\[((?:.|\n)+?)\\\])|(\\\(([\s\S]+?)\\\))/g;
        let match;
        while ((match = regex.exec(segmentContent)) !== null) {
            let expression = match[1] || match[2] || match[3] || match[4] || match[5] || match[6] || match[7] || match[8];
            if (expression) {
                Qt.callLater(() => {
                    const [renderHash, isNew] = LatexRenderer.requestRender(expression.trim());
                    if (!renderedLatexHashes.includes(renderHash)) {
                        renderedLatexHashes.push(renderHash);
                    }
                });
            }
        }
    }

    function handleRenderedLatex(hash, force = false) {
        if (renderedLatexHashes.includes(hash) || force) {
            const imagePath = LatexRenderer.renderedImagePaths[hash];
            const markdownImage = `![latex](${imagePath})`;

            const expression = LatexRenderer.processedExpressions[hash];
            renderedSegmentContent = renderedSegmentContent.replace(expression, markdownImage);
        }
    }

    onDoneChanged: {
        renderTimer.restart();
    }
    onEditingChanged: {
        if (!editing) {
            renderLatex()
        } else {
            // console.log("Editing mode enabled", segmentContent)
            root.shownText = segmentContent
        }
    }

    onSegmentContentChanged: {
        // console.log("Segment content changed: " + segmentContent);
        renderedSegmentContent = segmentContent;
        if (!root.editing && segmentContent) {
            root.renderLatex();
        }
    }

    onRenderedSegmentContentChanged: {
        // console.log("Rendered segment content changed: " + renderedSegmentContent);
        if (renderedSegmentContent) {
            root.shownText = renderedSegmentContent;
        }
    }

    // When something finishes rendering
    // 1. Check if the hash is in the list
    // 2. If it is, replace the expression with the image path
    Connections {
        target: LatexRenderer
        function onRenderFinished(hash, imagePath) {
            const expression = LatexRenderer.processedExpressions[hash];
            // console.log("Render finished: " + hash + " " + expression);
            handleRenderedLatex(hash);
        }
    }

    spacing: 0
    TextArea {
        id: textArea
        Layout.fillWidth: true
        topPadding: 0
        bottomPadding: 0
        background: null
        palette.link: root.accentColor
        readOnly: !editing
        selectByMouse: enableMouseSelection || editing
        renderType: Text.NativeRendering
        font.family: Appearance.font.family.monospace
        font.hintingPreference: Font.PreferNoHinting // Prevent weird bold text
        font.pixelSize: Ai.chatFontSize
        selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
        selectionColor: Appearance.colors.colSecondaryContainer
        wrapMode: TextEdit.Wrap
        color: root.bodyColor
        textFormat: renderMarkdown && !editing ? TextEdit.RichText : TextEdit.PlainText
        text: renderMarkdown && !editing ? root.richText : root.shownText

        onTextChanged: {
            if (!root.editing) return
            segmentContent = text
        }

        onLinkActivated: (link) => {
            Qt.openUrlExternally(link)
            GlobalStates.sidebarLeftOpen = false
        }

        MouseArea { // Pointing hand for links
            anchors.fill: parent
            acceptedButtons: Qt.NoButton // Only for hover
            hoverEnabled: true
            cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor :
                (enableMouseSelection || editing) ? Qt.IBeamCursor : Qt.ArrowCursor
        }
    }
}
