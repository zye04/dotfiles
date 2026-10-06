import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: true

    // local-suite: frontier planner login status and local model list
    property string claudeStatus: Translation.tr("checking…")
    property var localModels: []
    property string modelNote: Translation.tr("A new model loads on the next message.")
    readonly property string suiteDir: "/home/zye/Projects/dev/local-suite"

    function refreshClaudeStatus() { claudeStatusProc.running = true; }
    function refreshModels() { modelListProc.running = true; }
    Component.onCompleted: { refreshClaudeStatus(); refreshModels(); }

    Process {
        id: claudeStatusProc
        command: ["claude", "auth", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.claudeStatus = d.loggedIn ? `${d.email ?? d.authMethod} · ${d.subscriptionType ?? d.authMethod}` : Translation.tr("not logged in");
                } catch (e) {
                    root.claudeStatus = Translation.tr("not logged in");
                }
            }
        }
    }
    Process {
        id: claudeLoginProc
        command: ["kitty", "-e", "claude", "auth", "login"]
        onExited: root.refreshClaudeStatus()
    }
    Process {
        id: modelListProc
        command: ["python3", `${root.suiteDir}/tools/local-model/models.py`, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.localModels = JSON.parse(text).filter(m => m.format === "exl3"); } catch (e) { root.localModels = []; }
            }
        }
    }
    Process {
        id: modelSelectProc
        property string name: ""
        command: ["python3", `${root.suiteDir}/tools/local-model/models.py`, "select", modelSelectProc.name]
        onExited: code => {
            root.modelNote = code === 0 ? Translation.tr("Switched to %1. It loads on the next message.").arg(name) : Translation.tr("Switch failed (see qs log).");
            root.refreshModels();
        }
    }

    ContentSection {
        icon: "neurology"
        title: Translation.tr("AI")

        ContentSubsection {
            title: Translation.tr("Default reasoning effort")
            Layout.bottomMargin: 6
            tooltip: Translation.tr("How long the model thinks before answering.\nThe sidebar starts with this; /effort or the reasoning chip change it for the current session")

            ConfigSelectionArray {
                buttonWidth: 112 // 4 x 112 + spacing = same total width as Launch mode
                currentValue: Config.options.ai.reasoningEffort
                onSelected: newValue => {
                    Config.options.ai.reasoningEffort = newValue;
                }
                options: [
                    { displayName: Translation.tr("Off"), value: "off" },
                    { displayName: Translation.tr("Low"), value: "low" },
                    { displayName: Translation.tr("Medium"), value: "medium" },
                    { displayName: Translation.tr("High"), value: "high" },
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Launch mode")
            Layout.bottomMargin: 6
            tooltip: Translation.tr("When the local model gets loaded into VRAM (~5-10 s).\nEither way it unloads by itself after 5 min idle.")

            ConfigSelectionArray {
                buttonWidth: 226 // 2 x 226 + spacing = same total width as reasoning effort
                currentValue: Config.options.ai.wakeOnOpen
                onSelected: newValue => {
                    Config.options.ai.wakeOnOpen = newValue;
                }
                options: [
                    { displayName: Translation.tr("When sidebar opens"), value: true },
                    { displayName: Translation.tr("On first message"), value: false },
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Frontier planner")
            Layout.bottomMargin: 6
            tooltip: Translation.tr("/plan-frontier asks Claude (through your Claude Code login) for a plan, which the local agent then runs.\n/frontier-model and /frontier-effort change these for the current session")

            ConfigRow {
                StyledText {
                    Layout.fillWidth: true
                    text: root.claudeStatus
                    color: Appearance.colors.colSubtext
                }
                RippleButtonWithIcon {
                    materialIcon: "login"
                    mainText: Translation.tr("Log in")
                    onClicked: claudeLoginProc.running = true
                }
            }
            ContentSubsectionLabel { text: Translation.tr("Model") }
            ConfigSelectionArray {
                buttonWidth: 148
                currentValue: Config.options.ai.frontierModel
                onSelected: newValue => { Config.options.ai.frontierModel = newValue; }
                options: [
                    { displayName: "Opus", value: "opus" },
                    { displayName: "Sonnet", value: "sonnet" },
                    { displayName: "Haiku", value: "haiku" },
                ]
            }
            ContentSubsectionLabel { text: Translation.tr("Effort") }
            ConfigSelectionArray {
                buttonWidth: 89
                currentValue: Config.options.ai.frontierEffort
                onSelected: newValue => { Config.options.ai.frontierEffort = newValue; }
                options: [
                    { displayName: Translation.tr("Low"), value: "low" },
                    { displayName: Translation.tr("Medium"), value: "medium" },
                    { displayName: Translation.tr("High"), value: "high" },
                    { displayName: "xhigh", value: "xhigh" },
                    { displayName: "max", value: "max" },
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Local model")
            Layout.bottomMargin: 6
            tooltip: Translation.tr("EXL3 models in ~/local-models. Models without a tool-call profile (tabby_config.yml) are disabled.\nSwitching restarts llama-swap, which unloads the current model.")

            StyledComboBox {
                id: localModelSelector
                buttonIcon: "memory"
                textRole: "displayName"
                model: root.localModels.map(m => ({
                    displayName: m.name + (m.active ? " (active)" : !m.profiled ? " (no profile)" : ""),
                    value: m.name,
                    enabled: m.profiled && !m.active
                }))
                currentIndex: Math.max(0, root.localModels.findIndex(m => m.active))
                onActivated: index => {
                    modelSelectProc.name = model[index].value;
                    modelSelectProc.running = true;
                }
            }
            StyledText {
                text: root.modelNote
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }

        ContentSubsectionLabel { text: Translation.tr("Agent server URL") }
        MaterialTextArea {
            Layout.fillWidth: true
            text: Config.options.ai.agentServerUrl
            onTextChanged: Qt.callLater(() => Config.options.ai.agentServerUrl = text.trim())
        }

        ContentSubsectionLabel { text: Translation.tr("Default agent directory") }
        MaterialTextArea {
            Layout.fillWidth: true
            text: Config.options.ai.agentDirectory
            onTextChanged: Qt.callLater(() => Config.options.ai.agentDirectory = text.trim())
        }

        ContentSubsectionLabel {
            text: Translation.tr("System prompt")
        }

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("System prompt")
            text: Config.options.ai.systemPrompt
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Qt.callLater(() => {
                    Config.options.ai.systemPrompt = text;
                });
            }
        }
    }

    ContentSection {
        icon: "music_cast"
        title: Translation.tr("Music Recognition")

        ConfigSpinBox {
            icon: "timer_off"
            text: Translation.tr("Total duration timeout (s)")
            value: Config.options.musicRecognition.timeout
            from: 10
            to: 100
            stepSize: 2
            onValueChanged: {
                Config.options.musicRecognition.timeout = value;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (s)")
            value: Config.options.musicRecognition.interval
            from: 2
            to: 10
            stepSize: 1
            onValueChanged: {
                Config.options.musicRecognition.interval = value;
            }
        }
    }

    ContentSection {
        icon: "cell_tower"
        title: Translation.tr("Networking")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("User agent (for services that require it)")
            text: Config.options.networking.userAgent
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.networking.userAgent = text;
            }
        }
    }

    ContentSection {
        icon: "memory"
        title: Translation.tr("Resources")

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (ms)")
            value: Config.options.resources.updateInterval
            from: 100
            to: 10000
            stepSize: 100
            onValueChanged: {
                Config.options.resources.updateInterval = value;
            }
        }
        
    }

    ContentSection {
        icon: "file_open"
        title: Translation.tr("Save paths")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Video Recording Path")
            text: Config.options.screenRecord.savePath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.screenRecord.savePath = text;
            }
        }
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Screenshot Path (leave empty to just copy)")
            text: Config.options.screenSnip.savePath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.screenSnip.savePath = text;
            }
        }
    }

    ContentSection {
        icon: "search"
        title: Translation.tr("Search")

        ConfigSwitch {
            text: Translation.tr("Use Levenshtein distance-based algorithm instead of fuzzy")
            checked: Config.options.search.sloppy
            onCheckedChanged: {
                Config.options.search.sloppy = checked;
            }
            StyledToolTip {
                text: Translation.tr("Could be better if you make a ton of typos,\nbut results can be weird and might not work with acronyms\n(e.g. \"GIMP\" might not give you the paint program)")
            }
        }

        ContentSubsection {
            title: Translation.tr("Prefixes")
            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Action")
                    text: Config.options.search.prefix.action
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.action = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Clipboard")
                    text: Config.options.search.prefix.clipboard
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.clipboard = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Emojis")
                    text: Config.options.search.prefix.emojis
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.emojis = text;
                    }
                }
            }

            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Math")
                    text: Config.options.search.prefix.math
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.math = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Shell command")
                    text: Config.options.search.prefix.shellCommand
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.shellCommand = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Web search")
                    text: Config.options.search.prefix.webSearch
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.webSearch = text;
                    }
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Web search")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Base URL")
                text: Config.options.search.engineBaseUrl
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.search.engineBaseUrl = text;
                }
            }
        }
    }

    // There's no update indicator in ii for now so we shouldn't show this yet
    // ContentSection {
    //     icon: "deployed_code_update"
    //     title: Translation.tr("System updates (Arch only)")

    //     ConfigSwitch {
    //         text: Translation.tr("Enable update checks")
    //         checked: Config.options.updates.enableCheck
    //         onCheckedChanged: {
    //             Config.options.updates.enableCheck = checked;
    //         }
    //     }

    //     ConfigSpinBox {
    //         icon: "av_timer"
    //         text: Translation.tr("Check interval (mins)")
    //         value: Config.options.updates.checkInterval
    //         from: 60
    //         to: 1440
    //         stepSize: 60
    //         onValueChanged: {
    //             Config.options.updates.checkInterval = value;
    //         }
    //     }
    // }

    ContentSection {
        icon: "weather_mix"
        title: Translation.tr("Weather")
        ConfigRow {
            ConfigSwitch {
                buttonIcon: "assistant_navigation"
                text: Translation.tr("Enable GPS based location")
                checked: Config.options.bar.weather.enableGPS
                onCheckedChanged: {
                    Config.options.bar.weather.enableGPS = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "thermometer"
                text: Translation.tr("Fahrenheit unit")
                checked: Config.options.bar.weather.useUSCS
                onCheckedChanged: {
                    Config.options.bar.weather.useUSCS = checked;
                }
                StyledToolTip {
                    text: Translation.tr("It may take a few seconds to update")
                }
            }
        }
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("City name")
            text: Config.options.bar.weather.city
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.bar.weather.city = text;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (m)")
            value: Config.options.bar.weather.fetchInterval
            from: 5
            to: 50
            stepSize: 5
            onValueChanged: {
                Config.options.bar.weather.fetchInterval = value;
            }
        }
    }
}
