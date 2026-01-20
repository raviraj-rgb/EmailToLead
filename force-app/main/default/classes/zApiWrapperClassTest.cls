@IsTest
private class zApiWrapperClassTest {

    @IsTest
    static void testAddMessage() {
        // Arrange
        zApiWrapperClass wrapper = new zApiWrapperClass();

        // Act
        wrapper.model = 'gpt-4.1-mini';
        wrapper.addMessage('system', 'You are a helpful assistant');
        wrapper.addMessage('user', 'Hello');

        // Assert
        System.assertEquals('gpt-4.1-mini', wrapper.model, 'Model should be set correctly');
        System.assertNotEquals(null, wrapper.messages, 'Messages list should be initialized');
        System.assertEquals(2, wrapper.messages.size(), 'There should be 2 messages');

        System.assertEquals('system', wrapper.messages[0].role);
        System.assertEquals('You are a helpful assistant', wrapper.messages[0].content);

        System.assertEquals('user', wrapper.messages[1].role);
        System.assertEquals('Hello', wrapper.messages[1].content);
    }
}