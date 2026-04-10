public class GeminiApiWrapper {
    public List<Content> contents;

    public class Content {
        public List<Part> parts;
    }

    public class Part {
        public String text;
    }

    public GeminiApiWrapper(String systemPrompt, String userPrompt) {
        this.contents = new List<Content>();
        Content userContent = new Content();
        userContent.parts = new List<Part>();
        
        Part p = new Part();
        // Gemini often works best when system instructions are clearly demarcated or 
        // prepended to the user prompt if a system instruction field isn't explicitly used.
        p.text = systemPrompt + '\n\n' + userPrompt;
        userContent.parts.add(p);
        
        this.contents.add(userContent);
    }
}
