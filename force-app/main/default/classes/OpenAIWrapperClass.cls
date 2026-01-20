/**
 * OpenAI API Request Wrapper Class
 * API Docs: https://platform.openai.com/docs/api-reference/chat/create
 * 
 * Endpoint: POST https://api.openai.com/v1/chat/completions
 * Response Path: choices[0].message.content
 */
global class OpenAIWrapperClass {

    global String model;                    // e.g., "gpt-4", "gpt-3.5-turbo"
    global List<Message> messages;
    global Double temperature;              // 0.0 to 2.0
    global Integer max_tokens;              // Max response tokens
    global Double top_p;                    // Nucleus sampling
    global Double frequency_penalty;        // -2.0 to 2.0
    global Double presence_penalty;         // -2.0 to 2.0

    global OpenAIWrapperClass() {
        messages = new List<Message>();
    }

    global void addMessage(String role, String content) {
        messages.add(new Message(role, content));
    }

    global class Message {
        global String role;     // "system", "user", "assistant"
        global String content;

        global Message() {}

        global Message(String r, String c) {
            role = r;
            content = c;
        }
    }
}
