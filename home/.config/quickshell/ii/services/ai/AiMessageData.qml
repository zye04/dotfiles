import QtQuick;

/**
 * Represents a message in an AI conversation. (Kind of) follows the OpenAI API message structure.
 */
QtObject {
    property string role
    property string content
    property string rawContent
    property string fileMimeType
    property string fileUri
    property string localFilePath
    property string model
    property bool thinking: true
    property bool done: false
    property var annotations: []
    property var annotationSources: []
    property list<string> searchQueries: []
    property string functionName
    property var functionCall
    property string functionResponse
    property bool functionPending: false
    property bool visibleToUser: true
    // local-suite: shown in the reply footer
    property real startedAt: 0
    property real finishedAt: 0
    property real tokensPerSecond: 0
    property real thoughtEndedAt: 0 // when the reasoning part ended
    property string partType: ""
    property string partID: ""
    property string opencodeMessageID: ""
    property var toolPart: ({})
    property var requestData: ({})
    property string answer: ""
    property var todos: []
    property bool queued: false // user: sent while the agent was busy, not started yet
    property var tools: [] // toolgroup: [{partID, tool, target, status, summary, dir, errorText}]
    property string errorText: "" // tool: first line of the error message
    property int toolUses: 0 // task: tool calls made by the subagent
    property real durationMs: 0 // turnend
    property int outputTokens: 0 // turnend
    property real doneAt: 0 // turnend
}
