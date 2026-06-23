@isTest
private class ChatGPTWrapperClassTest {

    @isTest
    static void testConstructors() {
        // Test no-arg constructor
        ChatGPTWrapperClass wrapper1 = new ChatGPTWrapperClass();
        System.assertEquals(true, wrapper1.store, 'Store should default to true');

        // Test parameterized constructor
        ChatGPTWrapperClass wrapper2 = new ChatGPTWrapperClass('gpt-3.5-turbo', 'Hello world', false);
        System.assertEquals('gpt-3.5-turbo', wrapper2.model, 'Model should match');
        System.assertEquals('Hello world', wrapper2.input, 'Input should match');
        System.assertEquals(false, wrapper2.store, 'Store should match');
    }
}
