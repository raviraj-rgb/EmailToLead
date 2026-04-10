@isTest
private class GeminiApiWrapperTest {
    @isTest
    static void testGeminiWrapperCreation() {
        String systemPrompt = 'You are a helpful assistant.';
        String userPrompt = 'Extract lead data from: John Doe at Acme Corp.';
        
        Test.startTest();
        GeminiApiWrapper wrapper = new GeminiApiWrapper(systemPrompt, userPrompt);
        Test.stopTest();
        
        System.assertNotEquals(null, wrapper.contents, 'Contents should not be null');
        System.assertEquals(1, wrapper.contents.size(), 'Should have one content block');
        System.assertNotEquals(null, wrapper.contents[0].parts, 'Parts should not be null');
        System.assertEquals(1, wrapper.contents[0].parts.size(), 'Should have one part');
        
        String expectedText = systemPrompt + '\n\n' + userPrompt;
        System.assertEquals(expectedText, wrapper.contents[0].parts[0].text, 'Text should match combined prompts');
    }
}
