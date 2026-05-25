public class zApiWrapperClass {

    public String model { get; set; }
    public List<Message> messages { get; set; }
 
    public class Message {
         public String role { get; set; }
        public String content { get; set; }

        public Message(String r, String c) {
            role = r;
            content = c;
        }
    }
}