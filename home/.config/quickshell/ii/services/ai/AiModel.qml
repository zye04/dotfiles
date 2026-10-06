import QtQuick;

/**
 * An AI model representation.
 * - name: Friendly name of the model
 * - icon: Icon name of the model
 * - description: Description of the model
 * - endpoint: Endpoint of the model
 * - model: Model code (like gpt-4.1 or gemini-2.5-flash)
 * - requires_key: Whether the model requires an API key
 * - key_id: The identifier of the API key. Use the same identifier for models that can be accessed with the same key.
 * - key_get_link: Link to get an API key
 * - key_get_description: Description of pricing and how to get an API key
 * - api_format: The API format of the model. Only "openai" is supported.
 * - extraParams: Extra parameters to be passed to the model. This is a JSON object.
 * - efforts: Map of effort level -> model name to request (e.g. {"low": "qwen:low"}).
 * - context_size: Context window in tokens, shown in /status.
 */

QtObject {
    property string name
    property string icon
    property string description
    property string homepage
    property string endpoint
    property string model
    property bool requires_key: true
    property string key_id
    property string key_get_link
    property string key_get_description
    property string api_format: "openai"
    property var tools
    property var extraParams: ({})
    property var efforts: ({})
    property int context_size: 0
}
