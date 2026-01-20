/**
 * Anthropic Claude API Request Wrapper Class
 * API Docs: https://docs.anthropic.com/en/api/messages
 * 
 * Endpoint: POST https://api.anthropic.com/v1/messages
 * Headers: x-api-key, anthropic-version: "2023-06-01"
 * Response Path: content[0].text
 */
global class ClaudeWrapperClass {

    global String model;                    // e.g., "claude-3-opus-20240229", "claude-3-sonnet-20240229"
    global Integer max_tokens;              // Required - max response tokens
    global String system_prompt;            // System prompt (Claude uses separate field, renamed to avoid reserved word)
    global List<Message> messages;
    global Double temperature;              // 0.0 to 1.0
    global Double top_p;                    // Nucleus sampling
    global Integer top_k;                   // Top-k sampling
    global List<String> stop_sequences;     // Stop sequences

    global ClaudeWrapperClass() {
        messages = new List<Message>();
    }

    global void setSystemPrompt(String prompt) {
        system_prompt = prompt;
    }

    global void addMessage(String role, String content) {
        messages.add(new Message(role, content));
    }

    global class Message {
        global String role;     // "user" or "assistant"
        global String content;

        global Message() {}

        global Message(String r, String c) {
            role = r;
            content = c;
        }
    }

    // Custom JSON serialization to rename system_prompt to "system"
    global String toJSON() {
        Map<String, Object> jsonMap = new Map<String, Object>();
        jsonMap.put('model', model);
        jsonMap.put('max_tokens', max_tokens);
        if (String.isNotBlank(system_prompt)) {
            jsonMap.put('system', system_prompt);  // Claude uses "system" not "system_prompt"
        }
        if (temperature != null) {
            jsonMap.put('temperature', temperature);
        }
        if (top_p != null) {
            jsonMap.put('top_p', top_p);
        }
        if (top_k != null) {
            jsonMap.put('top_k', top_k);
        }
        if (stop_sequences != null && !stop_sequences.isEmpty()) {
            jsonMap.put('stop_sequences', stop_sequences);
        }
        
        List<Map<String, Object>> msgList = new List<Map<String, Object>>();
        for (Message m : messages) {
            Map<String, Object> msgMap = new Map<String, Object>();
            msgMap.put('role', m.role);
            msgMap.put('content', m.content);
            msgList.add(msgMap);
        }
        jsonMap.put('messages', msgList);
        
        return JSON.serialize(jsonMap);
    }
}
