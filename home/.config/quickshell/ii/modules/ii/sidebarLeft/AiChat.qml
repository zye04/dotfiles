import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarLeft.aiChat
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

Item {
    id: root
    property real padding: 4
    property var inputField: messageInputField
    property string commandPrefix: "/"

    property var suggestionQuery: ""
    property var suggestionList: []

    Binding {
        target: Ai
        property: "statusPolling"
        value: GlobalStates.sidebarLeftOpen
    }

    // Start loading the model as soon as the sidebar opens, so it's usually ready
    // by the time the first message is typed. llama-swap unloads it when idle.
    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (GlobalStates.sidebarLeftOpen && Config.options.ai.wakeOnOpen) Ai.wakeLocalModel();
        }
    }

    onFocusChanged: focus => {
        if (focus) {
            root.inputField.forceActiveFocus();
        }
    }

    Keys.onPressed: event => {
        messageInputField.forceActiveFocus();
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                messageListView.contentY = Math.max(0, messageListView.contentY - messageListView.height / 2);
                event.accepted = true;
            } else if (event.key === Qt.Key_PageDown) {
                messageListView.contentY = Math.min(messageListView.contentHeight - messageListView.height / 2, messageListView.contentY + messageListView.height / 2);
                event.accepted = true;
            }
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_O) {
            Ai.clearMessages();
        }
    }

    // local-suite: command set modelled on Claude Code's slash commands.
    // takesArgs: Enter fills "/name " and lists arguments instead of running.
    property var allCommands: [
        { name: "help", description: Translation.tr("List commands"), takesArgs: false,
            execute: () => Ai.addMessage(root.allCommands.map(cmd => `- \`${root.commandPrefix}${cmd.name}\` ${cmd.description}`).join("\n"), Ai.interfaceRole) },
        { name: "clear", description: Translation.tr("Clear the conversation"), takesArgs: false,
            execute: () => Ai.clearMessages() },
        { name: "model", description: Translation.tr("Choose the model"), takesArgs: true,
            execute: args => Ai.setModel(args[0]) },
        { name: "effort", description: Translation.tr("Reasoning effort: off, low, medium, high"), takesArgs: true,
            execute: args => Ai.setEffort(args[0]) },
        { name: "attach", description: Translation.tr("Attach an image (path). Ctrl+V pastes a copied image"), takesArgs: true,
            execute: args => Ai.attachFile(args.join(" ").trim()) },
        { name: "resume", description: Translation.tr("Resume a saved conversation"), takesArgs: true,
            execute: args => {
                const name = args.join(" ").trim();
                if (name.length === 0) Ai.addMessage(Translation.tr("Usage: %1resume NAME").arg(root.commandPrefix), Ai.interfaceRole);
                else Ai.loadChat(name);
            } },
        { name: "export", description: Translation.tr("Save this conversation under a name"), takesArgs: true,
            execute: args => {
                const name = args.join(" ").trim();
                if (name.length === 0) Ai.addMessage(Translation.tr("Usage: %1export NAME").arg(root.commandPrefix), Ai.interfaceRole);
                else {
                    Ai.saveChat(name);
                    Ai.addMessage(Translation.tr("Saved as %1").arg(name), Ai.interfaceRole);
                }
            } },
        { name: "retry", description: Translation.tr("Regenerate the last reply"), takesArgs: false,
            execute: () => Ai.retryLast() },
        { name: "copy", description: Translation.tr("Copy the conversation (or the last N messages: /copy 3)"), takesArgs: false,
            execute: args => Ai.copyMessages(parseInt(args[0]) || 0) },
        { name: "status", description: Translation.tr("Model, server, VRAM and context usage"), takesArgs: false,
            execute: () => Ai.printStatus() },
        { name: "unload", description: Translation.tr("Unload the local model and free VRAM"), takesArgs: false,
            execute: () => Ai.unloadLocalModel() },
        { name: "prompt", description: Translation.tr("Show or load the system prompt"), takesArgs: true,
            execute: args => {
                if (args.length === 0 || args[0] === "get") Ai.printPrompt();
                else Ai.loadPrompt(args.join(" ").trim());
            } },
        { name: "temp", description: Translation.tr("Show or set the temperature"), takesArgs: true,
            execute: args => {
                if (args.length == 0 || args[0] == "get") Ai.printTemperature();
                else Ai.setTemperature(parseFloat(args[0]));
            } },
        { name: "key", description: Translation.tr("Set an API key (cloud models only)"), takesArgs: true,
            execute: args => {
                if (args[0] == "get") Ai.printApiKey();
                else Ai.setApiKey(args[0]);
            } },
    ]

    readonly property var effortDescriptions: ({
        "off": Translation.tr("No reasoning. Fastest"),
        "low": Translation.tr("Short reasoning"),
        "medium": Translation.tr("More reasoning for harder problems"),
        "high": Translation.tr("Maximum reasoning. Slow"),
    })

    // Items for the command menu, for the current input text.
    function suggestionsFor(text) {
        if (!text.startsWith(root.commandPrefix)) return [];
        const words = text.split(" ");
        const command = words[0].substring(1);
        const query = words.slice(1).join(" ").trim();
        if (words.length === 1) {
            return root.allCommands
                .filter(cmd => cmd.name.startsWith(command))
                .map(cmd => ({ name: `${root.commandPrefix}${cmd.name}`, description: cmd.description, run: !cmd.takesArgs }));
        }
        const filter = (list, key) => list.filter(item => key(item).toLowerCase().includes(query.toLowerCase()));
        const chatName = path => FileUtils.trimFileExt(FileUtils.fileNameForPath(path)).trim();
        switch (command) {
        case "model":
            return filter(Ai.modelList, id => Ai.models[id].name + id)
                .map(id => ({ name: `/model ${id}`, displayName: Ai.models[id].name, description: Ai.models[id].description, run: true }));
        case "effort":
            return filter(Ai.effortLevels, level => level)
                .map(level => ({ name: `/effort ${level}`, displayName: level + (level === Ai.effort ? " ✓" : ""), description: root.effortDescriptions[level], run: true }));
        case "resume":
            return filter(Ai.savedChats, chatName)
                .map(path => ({ name: `/resume ${chatName(path)}`, displayName: chatName(path), description: path, run: true }));
        case "export":
            return filter(Ai.savedChats, chatName)
                .map(path => ({ name: `/export ${chatName(path)}`, displayName: chatName(path), description: Translation.tr("Overwrite this save"), run: true }));
        case "prompt":
            return filter(Ai.promptFiles, path => path)
                .map(path => ({ name: `/prompt ${path}`, displayName: FileUtils.trimFileExt(FileUtils.fileNameForPath(path)), description: path, run: true }));
        default:
            return [];
        }
    }

    // Tab: complete only. Enter: complete, and run it if nothing more is needed.
    function acceptSuggestion(item, run) {
        if (!item) return;
        if (run && item.run) {
            messageInputField.clear();
            root.handleInput(item.name);
            return;
        }
        messageInputField.text = item.name + " ";
        messageInputField.cursorPosition = messageInputField.text.length;
        messageInputField.forceActiveFocus();
    }

    function handleInput(inputText) {
        if (inputText.startsWith(root.commandPrefix)) {
            // Handle special commands
            const command = inputText.split(" ")[0].substring(1);
            const args = inputText.split(" ").slice(1);
            const commandObj = root.allCommands.find(cmd => cmd.name === `${command}`);
            if (commandObj) {
                commandObj.execute(args);
            } else {
                Ai.addMessage(Translation.tr("Unknown command: ") + command, Ai.interfaceRole);
            }
        } else {
            Ai.sendUserMessage(inputText);
        }

        // Always scroll to bottom when user sends a message
        messageListView.positionViewAtEnd();
    }

    Process {
        id: decodeImageAndAttachProc
        property string imageDecodePath: Directories.cliphistDecode
        property string imageDecodeFileName: "image"
        property string imageDecodeFilePath: `${imageDecodePath}/${imageDecodeFileName}`
        function handleEntry(entry: string) {
            imageDecodeFileName = parseInt(entry.match(/^(\d+)\t/)[1]);
            decodeImageAndAttachProc.exec(["bash", "-c", `[ -f ${imageDecodeFilePath} ] || echo '${StringUtils.shellSingleQuoteEscape(entry)}' | ${Cliphist.cliphistBinary} decode > '${imageDecodeFilePath}'`]);
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Ai.attachFile(imageDecodeFilePath);
            } else {
                console.error("[AiChat] Failed to decode image in clipboard content");
            }
        }
    }

    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        Item {
            // Messages
            Layout.fillWidth: true
            Layout.fillHeight: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: swipeView.width
                    height: swipeView.height
                    radius: Appearance.rounding.small
                }
            }

            ScrollEdgeFade {
                z: 1
                target: messageListView
                vertical: true
            }

            StyledListView { // Message list
                id: messageListView
                z: 0
                anchors.fill: parent
                spacing: 10
                popin: false
                topMargin: 6

                touchpadScrollFactor: Config.options.interactions.scrolling.touchpadScrollFactor * 1.4
                mouseScrollFactor: Config.options.interactions.scrolling.mouseScrollFactor * 1.4

                property int lastResponseLength: 0
                // onContentHeightChanged: {
                //     if (atYEnd)
                //         Qt.callLater(positionViewAtEnd);
                // }
                // onCountChanged: {
                //     // Auto-scroll when new messages are added
                //     if (atYEnd)
                //         Qt.callLater(positionViewAtEnd);
                // }

                add: null // Prevent function calls from being janky

                model: ScriptModel {
                    values: Ai.messageIDs.filter(id => {
                        const message = Ai.messageByID[id];
                        return message?.visibleToUser ?? true;
                    })
                }
                delegate: AiMessage {
                    required property var modelData
                    required property int index
                    messageIndex: index
                    messageData: {
                        Ai.messageByID[modelData];
                    }
                    messageInputField: root.inputField
                }
            }

            PagePlaceholder {
                z: 2
                shown: Ai.messageIDs.length === 0
                icon: "neurology"
                title: Ai.getModel()?.name ?? Translation.tr("No model")
                description: Translation.tr("Type / for commands\nCtrl+O expand · Ctrl+P pin · Ctrl+D detach")
                shape: MaterialShape.Shape.PixelCircle
            }

            ScrollToBottomButton {
                z: 3
                target: messageListView
            }
        }

        CommandMenu {
            id: commandMenu
            items: root.suggestionList
            onAccepted: name => root.acceptSuggestion(root.suggestionList.find(item => item.name === name), true)
        }

        Rectangle { // Input area
            id: inputWrapper
            property real spacing: 5
            Layout.fillWidth: true
            radius: Appearance.rounding.normal - root.padding
            color: Appearance.colors.colLayer2
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + inputFieldRowLayout.anchors.topMargin + commandButtonsRow.implicitHeight + commandButtonsRow.anchors.bottomMargin + spacing, 45) + (attachedFileIndicator.implicitHeight + spacing + attachedFileIndicator.anchors.topMargin)
            clip: true

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }

            AttachedFileIndicator {
                id: attachedFileIndicator
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: visible ? 5 : 0
                }
                filePath: Ai.pendingFilePath
                onRemove: Ai.attachFile("")
            }

            RowLayout { // Input field and send button
                id: inputFieldRowLayout
                anchors {
                    bottom: commandButtonsRow.top
                    left: parent.left
                    right: parent.right
                    bottomMargin: 5
                }
                spacing: 0

                ScrollView {
                    id: inputScrollView
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(root.height * 3/5, messageInputField.height)
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    StyledTextArea { // The actual TextArea (inside ScrollView to enable scrolling)
                        id: messageInputField
                        anchors.fill: parent
                        wrapMode: TextArea.Wrap
                        padding: 10
                        color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                        placeholderText: Translation.tr('Message %1… "%2" for commands').arg(Ai.getModel()?.name ?? "").arg(root.commandPrefix)

                        background: null

                        onTextChanged: {
                            root.suggestionList = root.suggestionsFor(messageInputField.text);
                        }

                        function accept() {
                            root.handleInput(text);
                            text = "";
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab) {
                                root.acceptSuggestion(root.suggestionList[commandMenu.selectedIndex], false);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up && commandMenu.visible) {
                                commandMenu.move(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down && commandMenu.visible) {
                                commandMenu.move(1);
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                                const typed = messageInputField.text.trim();
                                const selected = root.suggestionList[commandMenu.selectedIndex];
                                if (!(event.modifiers & Qt.ShiftModifier) && commandMenu.visible && selected && selected.name !== typed) {
                                    // Enter on a menu row: complete it (and run it when it needs nothing more)
                                    root.acceptSuggestion(selected, true);
                                    event.accepted = true;
                                } else if (event.modifiers & Qt.ShiftModifier) {
                                    // Insert newline
                                    messageInputField.insert(messageInputField.cursorPosition, "\n");
                                    event.accepted = true;
                                } else {
                                    // Accept text
                                    const inputText = messageInputField.text;
                                    messageInputField.clear();
                                    root.handleInput(inputText);
                                    event.accepted = true;
                                }
                            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                                // Intercept Ctrl+V to handle image/file pasting
                                if (event.modifiers & Qt.ShiftModifier) {
                                    // Let Shift+Ctrl+V = plain paste
                                    messageInputField.text += Quickshell.clipboardText;
                                    event.accepted = true;
                                    return;
                                }
                                // Try image paste first
                                const currentClipboardEntry = Cliphist.entries[0];
                                const cleanCliphistEntry = StringUtils.cleanCliphistEntry(currentClipboardEntry);
                                if (/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(currentClipboardEntry)) {
                                    // First entry = currently copied entry = image?
                                    decodeImageAndAttachProc.handleEntry(currentClipboardEntry);
                                    event.accepted = true;
                                    return;
                                } else if (cleanCliphistEntry.startsWith("file://")) {
                                    // First entry = currently copied entry = image?
                                    const fileName = decodeURIComponent(cleanCliphistEntry);
                                    Ai.attachFile(fileName);
                                    event.accepted = true;
                                    return;
                                }
                                event.accepted = false; // No image, let text pasting proceed
                            } else if (event.key === Qt.Key_Escape) {
                                // Esc closes the command menu first, then detaches a file
                                if (commandMenu.visible) {
                                    root.suggestionList = [];
                                    event.accepted = true;
                                } else if (Ai.pendingFilePath.length > 0) {
                                    Ai.attachFile("");
                                    event.accepted = true;
                                } else {
                                    event.accepted = false;
                                }
                            }
                        }
                    }
                }
                RippleButton { // Send button
                    id: sendButton
                    Layout.alignment: Qt.AlignBottom
                    Layout.rightMargin: 5
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.small
                    enabled: messageInputField.text.length > 0
                    toggled: enabled

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: sendButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const inputText = messageInputField.text;
                            root.handleInput(inputText);
                            messageInputField.clear();
                        }
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        iconSize: 22
                        color: sendButton.enabled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2Disabled
                        text: "arrow_upward"
                    }
                }
            }

            RowLayout { // Controls
                id: commandButtonsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.leftMargin: 12.5 // 13 px orb centred at x = 19, like the message bullets
                anchors.rightMargin: 5
                spacing: 4

                property var commandsShown: [
                    {
                        name: "",
                        sendDirectly: false,
                        dontAddSpace: true
                    },
                    {
                        name: "clear",
                        sendDirectly: true
                    },
                ]

                RowLayout {
                    // Orb · model · reasoning (click to cycle) · context used (dim).
                    // The orb (13 px) and the 10 px bullet column of the messages share
                    // their centre: commandButtonsRow leftMargin is set from it below.
                    spacing: 6

                    Orb {
                        size: 13
                        // RowLayout centres on line boxes (which include descender space);
                        // shift so the orb's centre meets the visual middle of the text.
                        transform: Translate {
                            y: modelNameText.baselineOffset + modelNameMetrics.glyphCenter() - modelNameText.height / 2
                        }
                    }
                    StyledText {
                        id: modelNameText
                        text: Ai.getModel()?.name ?? "-"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        FontMetrics {
                            id: modelNameMetrics
                            font: modelNameText.font
                            function glyphCenter() {
                                const x = tightBoundingRect("x"), h = tightBoundingRect("H");
                                return ((x.y + x.height / 2) + (h.y + h.height / 2)) / 2;
                            }
                        }
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        text: "·"
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: Translation.tr("reasoning: %1").arg(Ai.effort)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: reasoningMouse.containsMouse ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
                        MouseArea {
                            id: reasoningMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ai.setEffort(Ai.effortLevels[(Ai.effortLevels.indexOf(Ai.effort) + 1) % Ai.effortLevels.length])
                        }
                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: reasoningMouse.containsMouse
                            text: Translation.tr("Reasoning effort for this session. Click to cycle off → low → medium → high\nDefault: Settings → Services → AI")
                        }
                    }
                    StyledText {
                        visible: Ai.tokenCount.total > 0
                        text: "·"
                        color: Appearance.colors.colSubtext
                        opacity: 0.6
                    }
                    StyledText {
                        visible: Ai.tokenCount.total > 0
                        text: `${(Ai.tokenCount.total / 1000).toFixed(1)}K/${Math.round((Ai.getModel()?.context_size ?? 0) / 1024)}K`
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        opacity: 0.6
                        MouseArea {
                            id: contextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: contextMouse.containsMouse
                            text: Translation.tr("Context used by this conversation\nInput: %1 · Output: %2").arg(Ai.tokenCount.input).arg(Ai.tokenCount.output)
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Row {
                    // Command shortcuts, styled like the command menu rows
                    spacing: 2

                    Repeater {
                        model: commandButtonsRow.commandsShown
                        delegate: Rectangle {
                            id: shortcut
                            required property var modelData
                            property string commandRepresentation: `${root.commandPrefix}${modelData.name}`
                            implicitWidth: shortcutText.implicitWidth + 16
                            implicitHeight: shortcutText.implicitHeight + 10
                            radius: Appearance.rounding.verysmall
                            color: shortcutMouse.containsMouse ? Appearance.colors.colSecondaryContainer : "transparent"

                            StyledText {
                                id: shortcutText
                                anchors.centerIn: parent
                                text: shortcut.commandRepresentation
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colPrimary
                            }

                            MouseArea {
                                id: shortcutMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (shortcut.modelData.sendDirectly) {
                                        messageInputField.text = "";
                                        root.handleInput(shortcut.commandRepresentation);
                                    } else {
                                        messageInputField.text = shortcut.commandRepresentation + (shortcut.modelData.dontAddSpace ? "" : " ");
                                        messageInputField.cursorPosition = messageInputField.text.length;
                                        messageInputField.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
