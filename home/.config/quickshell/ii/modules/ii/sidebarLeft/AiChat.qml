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
    property bool sessionsLoading: false
    property var cwdSuggestions: []
    property string cwdQuery: ""

    Process {
        id: cwdHere
        command: ["python3", "-c", `import json, os, subprocess
try:
    pid = int(json.loads(subprocess.check_output(['hyprctl', 'activewindow', '-j']))['pid'])
    queue = [pid]
    found = ''
    while queue:
        current = queue.pop(0)
        try:
            name = open(f'/proc/{current}/comm').read().strip()
            if current != pid and name in ('bash', 'zsh', 'fish', 'sh', 'nu'):
                found = os.readlink(f'/proc/{current}/cwd')
                break
            queue.extend(int(x) for x in open(f'/proc/{current}/task/{current}/children').read().split())
        except (OSError, ValueError):
            pass
    print(found)
except (KeyError, OSError, ValueError, subprocess.CalledProcessError):
    print('')`]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path) Ai.setAgentDirectory(path);
                else Ai.addMessage("⎿ no shell found for the focused window", Ai.interfaceRole);
            }
        }
    }

    Process {
        id: cwdCheck
        property string candidate: ""
        onExited: (code, status) => {
            if (code === 0) Ai.setAgentDirectory(candidate);
            else Ai.addMessage(`⎿ directory not found: ${candidate}`, Ai.interfaceRole);
        }
    }

    Process {
        id: cwdComplete
        property string query: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (cwdComplete.query !== root.cwdQuery) return;
                try { root.cwdSuggestions = JSON.parse(text); }
                catch (e) { root.cwdSuggestions = []; }
                if (messageInputField.text.startsWith("/cwd ")) root.suggestionList = root.suggestionsFor(messageInputField.text);
            }
        }
    }

    function completeCwd(query) {
        root.cwdQuery = query;
        cwdComplete.query = query;
        cwdComplete.exec(["python3", "-c", `import json, os, sys
path = os.path.expanduser(sys.argv[1])
parent, prefix = (path, '') if path.endswith('/') else os.path.split(path)
parent = parent or '.'
try:
    names = [os.path.join(parent, name) for name in os.listdir(parent) if name.startswith(prefix) and os.path.isdir(os.path.join(parent, name))]
    print(json.dumps(sorted(names)[:20]))
except OSError:
    print('[]')`, query]);
    }

    Connections {
        target: Ai
        function onSessionsChanged() {
            root.sessionsLoading = false;
            if (messageInputField.text.startsWith("/resume ")) root.suggestionList = root.suggestionsFor(messageInputField.text);
        }
    }

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
                messageListView.scrollBy(-messageListView.height / 2);
                event.accepted = true;
            } else if (event.key === Qt.Key_PageDown) {
                messageListView.scrollBy(messageListView.height / 2);
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
            execute: () => Ai.effectiveMode === "agent" ? Ai.newAgentSession() : Ai.clearMessages() },
        { name: "model", description: Translation.tr("Choose the model"), takesArgs: true,
            execute: args => Ai.setModel(args[0]) },
        { name: "effort", description: Translation.tr("Reasoning effort: off, low, medium, high"), takesArgs: true,
            execute: args => Ai.setEffort(args[0]) },
        { name: "plan-frontier", description: Translation.tr("Plan with Claude (read-only), then run the plan locally"), takesArgs: true,
            execute: args => Ai.planFrontier(args.join(" ")) },
        { name: "frontier-model", description: Translation.tr("Claude model for /plan-frontier: opus, sonnet, haiku"), takesArgs: true,
            execute: args => Ai.setFrontierModel(args[0]) },
        { name: "frontier-effort", description: Translation.tr("Claude effort for /plan-frontier: low, medium, high, xhigh, max"), takesArgs: true,
            execute: args => Ai.setFrontierEffort(args[0]) },
        { name: "attach", description: Translation.tr("Attach an image (path). Ctrl+V pastes a copied image"), takesArgs: true,
            execute: args => Ai.attachFile(args.join(" ").trim()) },
        { name: "resume", description: Translation.tr("Resume a conversation"), takesArgs: true,
            execute: args => {
                const name = args.join(" ").trim();
                if (Ai.effectiveMode === "agent") {
                    if (name === "all") {
                        Ai.listAgentSessions();
                        messageInputField.text = "/resume all ";
                    } else if (name.length === 0) { Ai.listAgentSessions(); }
                    else Ai.loadAgentSession(args[0] === "all" ? args[1] : args[0]);
                } else if (name.length === 0) Ai.addMessage(Translation.tr("Usage: %1resume NAME").arg(root.commandPrefix), Ai.interfaceRole);
                else Ai.loadChat(name);
            } },
        { name: "compact", description: Translation.tr("Summarize the agent context"), takesArgs: false,
            execute: () => Ai.compact() },
        { name: "rewind", description: Translation.tr("Undo to a user message"), takesArgs: true,
            execute: args => { if (args[0]) Ai.rewind(args[0]); } },
        { name: "unrevert", description: Translation.tr("Restore the rewound messages"), takesArgs: false,
            execute: () => Ai.unrevert() },
        { name: "stop", description: Translation.tr("Stop the current reply"), takesArgs: false,
            execute: () => Ai.stop() },
        { name: "plan", description: Translation.tr("Use the read-only plan agent for the next prompt"), takesArgs: false,
            execute: () => { Ai.planNext = true; Ai.addMessage("⎿ next prompt uses plan", Ai.interfaceRole); } },
        { name: "accept", description: Translation.tr("Toggle accept-edits mode (Shift+Tab)"), takesArgs: false,
            execute: () => Ai.setAcceptEdits(!Ai.acceptEdits) },
        { name: "cwd", description: Translation.tr("Working directory for new agent sessions"), takesArgs: true,
            execute: args => {
                if (args[0] === "here") cwdHere.running = true;
                else if (args.length && args[0]) {
                    cwdCheck.candidate = args.join(" ").replace(/^~/, "/home/zye");
                    cwdCheck.exec(["test", "-d", cwdCheck.candidate]);
                }
                else Ai.addMessage(`⎿ cwd: ${Ai.agentDirectory}`, Ai.interfaceRole);
            } },
        { name: "chat", description: Translation.tr("Use direct model chat"), takesArgs: false,
            execute: () => Ai.setMode("chat") },
        { name: "agent", description: Translation.tr("Use the local agent"), takesArgs: false,
            execute: () => Ai.setMode("agent") },
        { name: "todo", description: Translation.tr("Show the agent todo list"), takesArgs: false,
            execute: () => Ai.fetchTodos() },
        { name: "permissions", description: Translation.tr("Show pending and saved agent permissions"), takesArgs: false,
            execute: () => Ai.showPermissions() },
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
        case "frontier-model":
            return filter(Ai.frontierModels, m => m)
                .map(m => ({ name: `/frontier-model ${m}`, displayName: m + (m === Ai.frontierModel ? " ✓" : ""), description: "", run: true }));
        case "frontier-effort":
            return filter(Ai.frontierEfforts, e => e)
                .map(e => ({ name: `/frontier-effort ${e}`, displayName: e + (e === Ai.frontierEffort ? " ✓" : ""), description: "", run: true }));
        case "resume":
            if (Ai.effectiveMode === "agent") {
                if (!root.sessionsLoading && Ai.sessions.length === 0) {
                    root.sessionsLoading = true;
                    Ai.listAgentSessions();
                }
                const all = query === "all" || query.startsWith("all ");
                const search = query.replace(/^all\s*/, "");
                return Ai.sessions.filter(s => all || s.directory === Ai.agentDirectory)
                    .filter(s => ((s.title ?? "") + s.id + (s.directory ?? "")).toLowerCase().includes(search.toLowerCase()))
                    .map(s => ({ name: `/resume ${all ? "all " : ""}${s.id}`, displayName: s.title ?? s.id,
                        description: `${Qt.formatDateTime(new Date(s.time?.updated ?? 0), "MMM d hh:mm")}${all ? " · " + s.directory : ""}`, run: true }));
            }
            return filter(Ai.savedChats, chatName)
                .map(path => ({ name: `/resume ${chatName(path)}`, displayName: chatName(path), description: path, run: true }));
        case "rewind":
            return filter(Ai.userMessageIDs, m => m.text)
                .map(m => ({ name: `/rewind ${m.id}`, displayName: m.text.split("\n")[0], description: m.id, run: true }));
        case "cwd":
            return [{ name: "/cwd here", displayName: "here", description: "focused window's shell", run: true },
                ...(Config.options.ai.recentDirectories ?? []).map(path => ({ name: `/cwd ${path}`, displayName: path, description: "recent", run: true })),
                ...root.cwdSuggestions.map(path => ({ name: `/cwd ${path}`, displayName: path, description: "directory", run: true }))]
                .filter(item => item.name.toLowerCase().includes(query.toLowerCase()));
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
        messageListView.followTail = true;
        messageListView.snapToEnd();
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

            ListView { // Message list
                id: messageListView
                z: 0
                anchors.fill: parent
                spacing: 3
                topMargin: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Keep the tail delegates instantiated so contentHeight is exact at the end.
                cacheBuffer: 4000
                reuseItems: false

                readonly property real touchpadScrollFactor: Config.options.interactions.scrolling.touchpadScrollFactor * 1.4
                readonly property real mouseScrollFactor: Config.options.interactions.scrolling.mouseScrollFactor * 1.4

                // Append-only feel: while following, contentY is pinned to the end synchronously
                // (no animation, no forceLayout). Only user-initiated scrolling animates.
                property bool followTail: true
                // A function, not a binding: a binding re-evaluates after originY's change handlers have already run, so it lags
                function endY() { return Math.max(originY - topMargin, originY + contentHeight - height + bottomMargin); }
                function snapToEnd() {
                    jumpAnim.stop();
                    contentY = endY();
                }
                function scrollBy(delta) {
                    const base = jumpAnim.running ? jumpAnim.to : contentY;
                    const next = Math.max(originY - topMargin, Math.min(base + delta, endY()));
                    followTail = delta >= 0 && next >= endY() - 1;
                    jumpAnim.stop();
                    jumpAnim.from = contentY;
                    jumpAnim.to = next;
                    jumpAnim.start();
                }
                NumberAnimation {
                    id: jumpAnim
                    target: messageListView
                    property: "contentY"
                    duration: 120
                    easing.type: Easing.OutCubic
                }
                onContentHeightChanged: if (followTail) snapToEnd()
                onOriginYChanged: if (followTail) snapToEnd()
                onHeightChanged: if (followTail) snapToEnd()
                onCountChanged: {
                    if (count === 0) followTail = true;
                    if (followTail) snapToEnd();
                }
                onMovementStarted: { jumpAnim.stop(); followTail = false; }
                onMovementEnded: followTail = contentY >= endY() - 1
                WheelHandler {
                    target: null
                    onWheel: event => {
                        const delta = event.pixelDelta.y || event.angleDelta.y / 120 * messageListView.mouseScrollFactor;
                        messageListView.scrollBy(-delta);
                        event.accepted = true;
                    }
                }
                ScrollBar.vertical: StyledScrollBar {
                    onPressedChanged: {
                        if (pressed) { jumpAnim.stop(); messageListView.followTail = false; }
                        else messageListView.followTail = messageListView.contentY >= messageListView.endY() - 1;
                    }
                }

                add: null // Prevent function calls from being janky

                model: ScriptModel {
                    values: Ai.messageIDs.filter(id => {
                        const message = Ai.messageByID[id];
                        return message?.visibleToUser ?? true;
                    })
                }
                delegate: Loader {
                    required property var modelData
                    required property int index
                    property var entry: Ai.messageByID[modelData]
                    // An assistant row with no text yet (tool-only turn, or waiting for the first token) takes no space.
                    readonly property bool blank: entry?.role === "assistant" && (!entry?.partType?.length || entry.partType === "text")
                        && !(entry?.content ?? "").trim() && !(entry?.rawContent ?? "").trim() && !entry?.localFilePath
                    width: messageListView.width
                    visible: !blank
                    height: blank ? 0 : (item?.implicitHeight ?? 0)
                    sourceComponent: !entry ? null : entry.partType === "tool" ? toolRow :
                        entry.partType === "toolgroup" ? toolGroupRow :
                        entry.partType === "turnend" ? turnEndRow :
                        entry.partType === "interrupted" ? interruptedRow :
                        entry.partType === "permission" ? permissionRow :
                        entry.partType === "question" ? questionRow :
                        entry.partType === "todo" ? todoRow : normalRow
                    Component {
                        id: normalRow
                        Item {
                            implicitHeight: message.implicitHeight + (entry?.queued ? queuedMark.implicitHeight + 2 : 0)
                            AiMessage { id: message; messageIndex: index; messageData: entry; messageInputField: root.inputField }
                            StyledText {
                                id: queuedMark
                                visible: entry?.queued ?? false
                                anchors.top: message.bottom
                                anchors.left: parent.left
                                anchors.leftMargin: 34
                                text: "queued"
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Ai.chatFontSize
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                    Component { id: toolRow; MessageToolRow { messageData: entry } }
                    Component { id: toolGroupRow; MessageToolGroup { messageData: entry } }
                    Component {
                        id: turnEndRow
                        TranscriptNote {
                            glyph: "✻"
                            text: {
                                const secs = Math.round((entry?.durationMs ?? 0) / 1000);
                                const took = secs >= 60 ? `${Math.floor(secs / 60)}m ${secs % 60}s` : `${secs}s`;
                                return `Worked for ${took} · done ${Qt.formatDateTime(new Date(entry?.doneAt ?? 0), "hh:mm")}`;
                            }
                        }
                    }
                    Component { id: interruptedRow; TranscriptNote { glyph: "⎿"; text: "Interrupted · what should the agent do instead?" } }
                    Component { id: permissionRow; PermissionPrompt { messageData: entry } }
                    Component { id: questionRow; QuestionPrompt { messageData: entry } }
                    Component { id: todoRow; TodoBlock { messageData: entry } }
                }
            }

            PagePlaceholder {
                z: 2
                shown: Ai.messageIDs.length === 0
                icon: "neurology"
                title: Ai.getModel()?.name ?? Translation.tr("No model")
                description: Translation.tr("Type / for commands\nCtrl+O expand · Ctrl+P pin · Ctrl+D detach")
                descriptionHorizontalAlignment: Text.AlignHCenter
                shape: MaterialShape.Shape.PixelCircle
            }

            ScrollToBottomButton {
                z: 3
                target: messageListView
                // Shown only when the user scrolled away from the tail, never while content streams in.
                opacity: messageListView.followTail ? 0 : 1
                scale: messageListView.followTail ? 0.7 : 1
                downAction: () => {
                    messageListView.followTail = true;
                    messageListView.snapToEnd();
                }
            }
        }

        StatusLine {}

        CommandMenu {
            id: commandMenu
            items: root.suggestionList
            visible: Ai.activePermission === null && root.suggestionList.length > 0
            onAccepted: name => root.acceptSuggestion(root.suggestionList.find(item => item.name === name), true)
        }

        PlanPrompt {
            id: planPopup
            visible: Ai.frontierPending && Ai.activePermission === null
        }

        Connections {
            target: Ai
            function onFrontierPlanEdit(plan) {
                messageInputField.text = plan;
                messageInputField.cursorPosition = plan.length;
                messageInputField.forceActiveFocus();
            }
            function onInputTextRequested(text) {
                messageInputField.text = text;
                messageInputField.cursorPosition = text.length;
            }
            function onCommandRequested(text) { root.handleInput(text); }
        }

        PermissionPrompt {
            id: permissionPopup
            visible: Ai.activePermission !== null
            messageData: Ai.activePermission
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
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
                        anchors.fill: parent
                        wrapMode: TextArea.Wrap
                        padding: 10
                        color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                        placeholderText: Translation.tr('Message %1… "%2" for commands').arg(Ai.getModel()?.name ?? "").arg(root.commandPrefix)

                        background: null
                        // The default caret sometimes isn't repainted after whitespace-only edits; a delegate follows cursorRectangle reliably.
                        cursorDelegate: Rectangle {
                            width: 2
                            color: Appearance.m3colors.m3onSurface
                            visible: messageInputField.cursorVisible
                            SequentialAnimation on opacity {
                                id: caretBlink
                                loops: Animation.Infinite
                                running: messageInputField.cursorVisible
                                PropertyAction { value: 1 }
                                PauseAnimation { duration: 530 }
                                PropertyAction { value: 0 }
                                PauseAnimation { duration: 530 }
                            }
                            Connections {
                                target: messageInputField
                                function onCursorPositionChanged() { caretBlink.restart(); }
                                function onTextChanged() { caretBlink.restart(); }
                            }
                        }

                        onTextChanged: {
                            if (messageInputField.text.startsWith("/cwd ")) root.completeCwd(messageInputField.text.slice(5).trim());
                            root.suggestionList = root.suggestionsFor(messageInputField.text);
                        }

                        function accept() {
                            root.handleInput(text);
                            text = "";
                        }

                        Keys.onPressed: event => {
                            if (Ai.frontierPending && !Ai.activePermission) {
                                const choice = event.key >= Qt.Key_1 && event.key <= Qt.Key_3 ? planPopup.replies[event.key - Qt.Key_1] :
                                    event.key === Qt.Key_Escape ? "discard" : "";
                                if (choice) { Ai.planDecision(choice); event.accepted = true; return; }
                                if (event.key === Qt.Key_Up) { planPopup.move(-1); event.accepted = true; return; }
                                if (event.key === Qt.Key_Down) { planPopup.move(1); event.accepted = true; return; }
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { planPopup.acceptSelected(); event.accepted = true; return; }
                            }
                            if (Ai.activePermission) {
                                const reply = event.key === Qt.Key_1 ? "once" : event.key === Qt.Key_2 ? "always" :
                                    (event.key === Qt.Key_3 || event.key === Qt.Key_Escape) ? "reject" : "";
                                if (reply) { Ai.answerPermission(Ai.activePermission, reply); event.accepted = true; return; }
                                if (event.key === Qt.Key_Up) { permissionPopup.move(-1); event.accepted = true; return; }
                                if (event.key === Qt.Key_Down) { permissionPopup.move(1); event.accepted = true; return; }
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { permissionPopup.acceptSelected(); event.accepted = true; return; }
                            }
                            if (event.key === Qt.Key_Backtab) {
                                if (Ai.effectiveMode === "agent") Ai.setAcceptEdits(!Ai.acceptEdits);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
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
                                } else if (Ai.busy) {
                                    Ai.stop();
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
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
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
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
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
                        visible: Ai.effectiveMode === "agent"
                        text: "·"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
                        color: Appearance.colors.colSubtext
                    }
                    StyledText { // The only segment that shrinks: middle-elided before anything else clips
                        visible: Ai.effectiveMode === "agent"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideMiddle
                        text: Ai.agentDirectory.split("/").filter(Boolean).pop()
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: "·"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: commandButtonsRow.width < 600 ? Ai.effort : Translation.tr("reasoning: %1").arg(Ai.effort)
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
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
                        text: "·"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        readonly property int used: Math.max(0, Ai.tokenCount.total)
                        readonly property int limit: Ai.effectiveMode === "agent" ? Ai.contextLimit : (Ai.getModel()?.context_size ?? 0)
                        readonly property bool nearLimit: limit > 0 && used / limit >= 0.8
                        function short(n) { return n < 1000 ? `${n}` : `${(n / 1000).toFixed(n < 10000 ? 1 : 0)}k`; }
                        text: `ctx ${short(used)}/${short(limit)}`
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
                        color: nearLimit ? Appearance.colors.colError : Appearance.colors.colSubtext
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
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Ai.chatFontSize
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

        StyledText { // Mode hint: one fixed slot under the input, empty in the default mode
            Layout.fillWidth: true
            Layout.leftMargin: 8
            elide: Text.ElideRight
            Layout.preferredHeight: modeHintMetrics.height
            FontMetrics { id: modeHintMetrics; font.family: Appearance.font.family.monospace; font.pixelSize: Ai.chatFontSize }
            text: Ai.effectiveMode !== "agent" ? "" : Ai.planNext ? "⏸ plan mode on" :
                Ai.acceptEdits ? "⏵⏵ accept edits on (shift+tab to cycle)" : ""
            font.family: Appearance.font.family.monospace
            font.pixelSize: Ai.chatFontSize
            color: Appearance.colors.colSubtext
        }
    }
}
