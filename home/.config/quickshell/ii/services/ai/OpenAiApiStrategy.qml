import QtQuick

ApiStrategy {
    property bool isReasoning: false
    
    function buildEndpoint(model: AiModel): string {
        // console.log("[AI] Endpoint: " + model.endpoint);
        return model.endpoint;
    }

    // Placeholder for an attached image; the request script swaps it for a base64
    // data URL (see Ai.qml), so the QML side never holds the image bytes.
    function imagePlaceholder(path: string): string {
        return `@@IMAGE:${path}@@`;
    }

    // Assistant replies are stored with their thinking inline as <think>...</think>
    // (that's how the chat renders it). Send it back as reasoning_content instead,
    // so the chat template sees the same shape it produced and the server can
    // reuse its cache for the earlier part of the conversation.
    function splitThinking(text: string): var {
        const match = text.match(/^\s*<think>([\s\S]*?)<\/think>\s*/);
        if (!match) return { reasoning: "", content: text };
        return { reasoning: match[1].trim(), content: text.slice(match[0].length) };
    }

    function buildMessage(message) {
        if (message.role === "assistant") {
            const parts = splitThinking(message.rawContent);
            return parts.reasoning.length > 0
                ? { "role": "assistant", "content": parts.content, "reasoning_content": parts.reasoning }
                : { "role": "assistant", "content": parts.content };
        }
        if (message.localFilePath && message.localFilePath.length > 0) {
            return {
                "role": message.role,
                "content": [
                    { "type": "text", "text": message.rawContent },
                    { "type": "image_url", "image_url": { "url": imagePlaceholder(message.localFilePath) } },
                ],
            };
        }
        return { "role": message.role, "content": message.rawContent };
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let baseData = {
            "model": model.model,
            "messages": [
                {role: "system", content: systemPrompt},
                ...messages.map(message => buildMessage(message)),
            ],
            "stream": true,
            "stream_options": { "include_usage": true },
            "temperature": temperature,
        };
        if (tools && tools.length > 0) baseData.tools = tools;
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function parseResponseLine(line, message) {
        // Remove 'data: ' prefix if present and trim whitespace
        let cleanData = line.trim();
        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }

        // console.log("[AI] OpenAI: Data:", cleanData);
        
        // Handle special cases
        if (!cleanData || cleanData.startsWith(":")) return {};
        if (cleanData === "[DONE]") {
            return { finished: true };
        }
        
        // Real stuff
        try {
            const dataJson = JSON.parse(cleanData);

            // Error response handling
            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            let newContent = "";

            const responseContent = dataJson.choices[0]?.delta?.content || dataJson.message?.content;
            const responseReasoning = dataJson.choices[0]?.delta?.reasoning || dataJson.choices[0]?.delta?.reasoning_content;

            if (responseContent && responseContent.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    message.thoughtEndedAt = Date.now();
                    const endBlock = "\n\n</think>\n\n";
                    message.content += endBlock;
                    message.rawContent += endBlock;
                }
                newContent = responseContent;
            } else if (responseReasoning && responseReasoning.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    const startBlock = "\n\n<think>\n\n";
                    message.rawContent += startBlock;
                    message.content += startBlock;
                }
                newContent = responseReasoning;
            }

            message.content += newContent;
            message.rawContent += newContent;

            // llama-server adds generation speed to the final chunk
            if (dataJson.timings?.predicted_per_second) {
                message.tokensPerSecond = dataJson.timings.predicted_per_second;
            }

            // Usage metadata
            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }

            if (dataJson.done) {
                return { finished: true };
            }
            
        } catch (e) {
            console.log("[AI] OpenAI: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }
        
        return {};
    }
    
    function onRequestFinished(message) {
        // OpenAI format doesn't need special finish handling
        return {};
    }
    
    function reset() {
        isReasoning = false;
    }

}
