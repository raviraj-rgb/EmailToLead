@IsTest
private class zApiWrapperClassTest {

    @IsTest
    static void testZApiWrapperClass_basicUsage() {
        // Arrange
        zApiWrapperClass wrapper = new zApiWrapperClass();
        wrapper.model = 'gpt-4-mini';

        List<zApiWrapperClass.Message> msgs = new List<zApiWrapperClass.Message>();
        msgs.add(new zApiWrapperClass.Message('system', 'You are a test system.'));
        msgs.add(new zApiWrapperClass.Message('user', 'Hello from test.'));
        wrapper.messages = msgs;

        // Act + Assert
        System.assertEquals(
            'gpt-4-mini',
            wrapper.model,
            'Model should be stored correctly in the wrapper'
        );
        System.assertNotEquals(
            null,
            wrapper.messages,
            'Messages list should not be null after assignment'
        );
        System.assertEquals(
            2,
            wrapper.messages.size(),
            'Wrapper should contain two messages'
        );
        System.assertEquals(
            'system',
            wrapper.messages[0].role,
            'First message role should match constructor argument'
        );
        System.assertEquals(
            'Hello from test.',
            wrapper.messages[1].content,
            'Second message content should match constructor argument'
        );
    }
}