/**
 * ChatGPT API Request Wrapper Class
 * 
 * Endpoint: POST https://api.openai.com/v1/responses
 * Response Path: output[0].content[0].text
 */
global class ChatGPTWrapperClass {

    global String model;
    global String input;
    global Boolean store;
    global Decimal temperature;

    global ChatGPTWrapperClass() {
        this.store = true;
        this.temperature = 0.5;
    }

    global ChatGPTWrapperClass(String model, String input, Boolean store) {
        this.model = model;
        this.input = input;
        this.store = store;
        this.temperature = 0.5;
    }
}
//Gitting
