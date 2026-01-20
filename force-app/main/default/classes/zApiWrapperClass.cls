global class zApiWrapperClass {

    global String model;
    global List<Message> messages;

    global zApiWrapperClass() {
        messages = new List<Message>();
    }

    global void addMessage(String role, String content) {
        messages.add(new Message(role, content));
    }

    global class Message {
        global String role;
        global String content;

        global Message(String r, String c) {
            role = r;
            content = c;
        }
    }
}