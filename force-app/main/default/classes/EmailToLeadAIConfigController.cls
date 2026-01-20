public with sharing class EmailToLeadAIConfigController {

    // ------------------------------------------------------------
    // Used by @wire(getActiveConfig) in LWC – READ ONLY
    // ------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static EmailToLead_Ai__AI_Configure__c getActiveConfig() {

        List<EmailToLead_Ai__AI_Configure__c> existing = [
            SELECT Id,
                   Name,
                   EmailToLead_Ai__Api_Key__c,
                   EmailToLead_Ai__Model__c,
                   EmailToLead_Ai__Named_Credential__c,
                   EmailToLead_Ai__Endpoint__c,
                   EmailToLead_Ai__Response_Content_Path__c,
                   EmailToLead_Ai__System_prompt__c,
                   EmailToLead_Ai__User_Prompt__c,
                   EmailToLead_Ai__isActive__c
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE EmailToLead_Ai__isActive__c = true
            LIMIT 1
        ];

        return existing.isEmpty() ? null : existing[0];
    }

    // ------------------------------------------------------------
    // Imperative call from LWC – creates default config if none exists
    // ------------------------------------------------------------
    @AuraEnabled
    public static EmailToLead_Ai__AI_Configure__c createDefaultConfig() {

        // If an active config already exists, just return it – do NOT reset prompts.
        List<EmailToLead_Ai__AI_Configure__c> existing = [
            SELECT Id,
                   Name,
                   EmailToLead_Ai__Model__c,
                   EmailToLead_Ai__Named_Credential__c,
                   EmailToLead_Ai__Endpoint__c,
                   EmailToLead_Ai__Response_Content_Path__c,
                   EmailToLead_Ai__System_prompt__c,
                   EmailToLead_Ai__User_Prompt__c,
                   EmailToLead_Ai__isActive__c
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE EmailToLead_Ai__isActive__c = true
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0];
        }

        // First-time bootstrap – create with full defaults
        EmailToLead_Ai__AI_Configure__c cfg = new EmailToLead_Ai__AI_Configure__c(
            Name                                = 'Default',
            EmailToLead_Ai__isActive__c         = true,
            EmailToLead_Ai__Model__c            = 'glm-4.5-air',
            EmailToLead_Ai__System_prompt__c    = getDefaultSystemPrompt(),
            EmailToLead_Ai__User_Prompt__c      = getDefaultUserPrompt(),
            EmailToLead_Ai__Named_Credential__c = 'EmailToLead_Ai__zApi', // TODO: set actual NC name
         //   EmailToLead_Ai__Endpoint__c         = '/api/coding/paas/v4/chat/completions'
            EmailToLead_Ai__Response_Content_Path__c = 'choices[0].message.content'
        );

        insert cfg;
        return cfg;
    }

    // ------------------------------------------------------------
    // Default SYSTEM PROMPT
    // ------------------------------------------------------------
    private static String getDefaultSystemPrompt() {
        return
'You are a Salesforce Lead Extractor running in SCHEMA MODE.\n' +
'Always return a SINGLE JSON OBJECT and NOTHING ELSE.\n\n' +
'The JSON MUST contain:\n' +
'1. ONLY valid Salesforce Lead API field names from the allowed list.\n' +
'2. A "summary" field that contains a short textual summary of the email.\n\n' +
'Smart mapping rules:\n' +
'- "Name" → FirstName / LastName\n' +
'- Email present in email body → Email\n' +
'- Phone numbers → Phone or MobilePhone\n' +
'- Company names → Company\n' +
'- Job titles → Title\n' +
'- "budget" or "revenue" → AnnualRevenue\n' +
'- "hot" leads → Rating = "Hot"\n' +
'- Locations → City, State, Country, Street\n' +
'- Employee counts → NumberOfEmployees\n' +
'- Website URLs → Website\n' +
'- Industry names → Industry\n' +
'- Lead source phrases → LeadSource\n' +
'- Custom fields ending in __c are allowed and should be used as provided.\n\n' +
'Email body handling (IMPORTANT):\n' +
'- Treat the "email body" as ONLY the lead-relevant content.\n' +
'- USE ONLY the message content ABOVE the separator line "---".\n' +
'- If the separator "---" exists, IGNORE everything after it completely.\n' +
'- If "Best regards" appears anywhere, IGNORE everything from "Best regards" to the end.\n' +
'- Completely IGNORE and EXCLUDE any email signature, footer, or boilerplate when deriving fields or building the summary.\n' +
'- Consider as signature/footer (to be ignored):\n' +
'  - Blocks at the end of the message that contain the sender\'s name plus job title, company name, and contact details.\n' +
'  - Lines that list roles or positions (for example, "Consultant", "Manager", "Director", "CRM Consultant | <Company>") together with phone, email, or address.\n' +
'  - Standalone contact blocks with email addresses, phone numbers, websites, social links, or taglines at the very bottom.\n' +
'  - Legal disclaimers, confidentiality notices, unsubscribe instructions, or marketing taglines at the bottom of the email.\n' +
'- NEVER extract Email/Phone/Website from signatures/footers.\n' +
'- When multiple emails appear, prefer the email that is clearly labeled as the lead/contact email in the main content (for example in labeled fields like "Contact Email: ..."), and ignore emails that are only present in signature/footer blocks.\n\n' +
'Data-format rules:\n' +
'- Numbers must be numeric types.\n' +
'- Dates must be ISO format.\n' +
'- Missing data must be empty strings "".\n' +
'- Email values MUST NOT contain "mailto:", brackets, parentheses, HTML, markdown, or any surrounding text.\n\n' +
'Output rules (STRICT):\n' +
'- Return PURE JSON ONLY, no text before or after.\n' +
'- Do NOT use Markdown or code fences (no backticks at all).\n' +
'- Do NOT include explanations, reasoning, or any other text outside the JSON object.\n' +
'- Do NOT nest the JSON inside an array or another wrapper object.\n' +
'- Never add fields not in the allowed list except "summary".\n' +
'- "summary" must ALWAYS be present inside the JSON.\n' +
'- The response MUST consist of exactly one flat JSON object and NOTHING else.\n' +
'- The FIRST character of the response MUST be "{" and the LAST character MUST be "}".\n' +
'- Do NOT include any explanation, comments, or reasoning outside the JSON object.\n' +
'- Do NOT include markdown, HTML, or code fences anywhere in the output.'
;
    }

    // ------------------------------------------------------------
    // Default USER PROMPT
    // ------------------------------------------------------------
    private static String getDefaultUserPrompt() {
        return
'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
'Always include the field "summary".\n' +
'Follow system instructions strictly.\n' +
'Return ONLY one flat JSON object.\n' +
'Do NOT add extra fields.\n' +
'Do NOT add Markdown or explanation text.\n' +
'The first character must be "{" and the last must be "}".\n' +
'Here is the email body:\n' +
'{EMAIL_BODY}';
    }
}