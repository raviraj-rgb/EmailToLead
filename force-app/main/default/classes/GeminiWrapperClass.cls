/**
 * Google Gemini API Request Wrapper Class
 * API Docs: https://ai.google.dev/api/generate-content
 * 
 * Endpoint: POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
 * Response Path: candidates[0].content.parts[0].text
 */
global class GeminiWrapperClass {

    global List<Content> contents;
    global GenerationConfig generationConfig;
    global List<SafetySetting> safetySettings;
    global SystemInstruction systemInstruction;

    global GeminiWrapperClass() {
        contents = new List<Content>();
    }

    // Add user message
    global void addUserMessage(String text) {
        Content c = new Content();
        c.role = 'user';
        c.parts = new List<Part>{ new Part(text) };
        contents.add(c);
    }

    // Add model/assistant message
    global void addModelMessage(String text) {
        Content c = new Content();
        c.role = 'model';
        c.parts = new List<Part>{ new Part(text) };
        contents.add(c);
    }

    // Set system instruction (Gemini's way of system prompt)
    global void setSystemInstruction(String text) {
        systemInstruction = new SystemInstruction();
        systemInstruction.parts = new List<Part>{ new Part(text) };
    }

    global class Content {
        global String role;             // "user" or "model"
        global List<Part> parts;

        global Content() {
            parts = new List<Part>();
        }
    }

    global class Part {
        global String text;

        global Part() {}

        global Part(String t) {
            text = t;
        }
    }

    global class SystemInstruction {
        global List<Part> parts;

        global SystemInstruction() {
            parts = new List<Part>();
        }
    }

    global class GenerationConfig {
        global Double temperature;          // 0.0 to 2.0
        global Integer maxOutputTokens;
        global Double topP;
        global Integer topK;
    }

    global class SafetySetting {
        global String category;             // e.g., "HARM_CATEGORY_HARASSMENT"
        global String threshold;            // e.g., "BLOCK_MEDIUM_AND_ABOVE"
    }
}
//Gitting
