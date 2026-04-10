/*public with sharing class EmailToLeadAIConfigController {

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
    // LWC combobox models list (from Custom Setting: AI_Configs__c)
    // Returns list of active Provider Names (ZAi, Groq, Mistral...)
    // ------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<String> getActiveModels() {

        Map<String, EmailToLead_Ai__AI_Configs__c> allModels =
            EmailToLead_Ai__AI_Configs__c.getAll();

        List<String> modelNames = new List<String>();

        if (allModels == null || allModels.isEmpty()) {
            return modelNames;
        }

        for (String key : allModels.keySet()) {
            EmailToLead_Ai__AI_Configs__c cfg = allModels.get(key);

            if (cfg != null && cfg.EmailToLead_Ai__Is_Active__c == true) {
                // Provider key stored in Name ("Groq", "Mistral", "ZAi")
                modelNames.add(cfg.Name);
            }
        }

        modelNames.sort();
        return modelNames;
    }

    // ------------------------------------------------------------
    // Imperative call from LWC – creates default config if none exists
    // ------------------------------------------------------------
    @AuraEnabled
    public static EmailToLead_Ai__AI_Configure__c createDefaultConfig() {

        List<EmailToLead_Ai__AI_Configure__c> existing = [
            SELECT Id, Name, EmailToLead_Ai__Model__c,
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

        // ✅ Default Provider (must match Custom Setting Name)
        String defaultProvider = 'Mistral';

        // Validate provider exists + active; otherwise fallback to first active
        Map<String, EmailToLead_Ai__AI_Configs__c> allModels =
            EmailToLead_Ai__AI_Configs__c.getAll();

        if (allModels != null && !allModels.isEmpty()) {
            EmailToLead_Ai__AI_Configs__c def = allModels.get(defaultProvider);
            if (def == null || def.EmailToLead_Ai__Is_Active__c == false) {
                // fallback to first active provider
                for (String k : allModels.keySet()) {
                    EmailToLead_Ai__AI_Configs__c temp = allModels.get(k);
                    if (temp != null && temp.EmailToLead_Ai__Is_Active__c == true) {
                        defaultProvider = temp.Name;
                        break;
                    }
                }
            }
        }

        EmailToLead_Ai__AI_Configure__c cfg = new EmailToLead_Ai__AI_Configure__c(
            Name                             = 'Default',
            EmailToLead_Ai__isActive__c      = true,
            EmailToLead_Ai__Model__c         = defaultProvider,
            EmailToLead_Ai__System_prompt__c = getDefaultSystemPrompt(),
            EmailToLead_Ai__User_Prompt__c   = getDefaultUserPrompt()
        );

        insert cfg;
        return cfg;
    }

    // ------------------------------------------------------------
    // Default SYSTEM PROMPT
    // ------------------------------------------------------------
    private static String getDefaultSystemPrompt() {
        return
'You are a Salesforce Lead Extractor running in SCHEMA MODE.\n\n' +
'OUTPUT FORMAT RULES:\n' +
'1. SINGLE LEAD: Return a single flat JSON object { ... }.\n' +
'2. MULTIPLE LEADS: If you detect multiple leads (e.g., multiple "INQ-" numbers, or multiple distinct contact blocks), return { "leads": [ {...}, {...} ] }.\n\n' +
'The JSON MUST contain:\n' +
'1. ONLY valid Salesforce Lead API field names from the allowed list.\n' +
'2. A "summary" field that contains a short textual summary of the email.\n' +
'3. An "email_body" field - see TEMPLATE DETECTION rules below.\n' +
'4. An "email_header" field - find the LAST From/Sent/To/Subject header block that appears IMMEDIATELY before the lead data (just before "Your daily summary", "A new LSI Lead", or the actual lead content). This is the header of the email that CONTAINS the lead, NOT the outer forwarding headers. Include From, Sent/Date, To, Subject, Cc lines only. If no header exists directly above the lead content, return "".\n' +
'5. An "email_footer" field - footer text below lead content like "View the detailed information available on Play365". If none, return "".\n\n' +

'TEMPLATE DETECTION (check these keywords IN ORDER):\n' +
'IF email contains "Your daily summary of Leads" AND "Lead Inquiry Number" AND "Contact Methods" → TEMPLATE A (Daily Summary Table)\n' +
'ELSE IF email contains "A new LSI Lead Inquiry has been assigned" AND "Rep Org ID:" AND "Lead Inquiry Number:" → TEMPLATE B (LSI Single Lead)\n' +
'ELSE → TEMPLATE C (Free-form Human Email)\n\n' +

'LEAD IDENTIFICATION:\n' +
'- Search for "INQ-" followed by digits. Each INQ- = one separate lead.\n' +
'- TEMPLATE A: Multiple INQ- = multiple leads in "leads" array.\n' +
'- TEMPLATE B/C: Single lead = flat JSON.\n\n' +

'BUILD "email_body" PER LEAD (label: value format):\n\n' +

'TEMPLATE A (Daily Summary Table):\n' +
'- Column headers: Lead Inquiry Number, Contact Methods, Promotion (Lead Source) Description, Company Name, Contact Name, Address, Email, Phone, Product Interest, Project Type, Sales Literature Items, Inquiry Comments, LSI Comments.\n' +
'- Map each column header to that lead row\'s value.\n' +
'- Example: "Lead Inquiry Number: INQ-0090086\\nContact Methods: Contact-LSI-Consultant\\nCompany Name: Oak Tree Learning Center\\nContact Name: OAK A Hernandez\\nAddress: 1900 N D St San Bernardino, CA 92405 USA\\nEmail: jhernandez@oaktreelearningcenter.com\\nPhone: 9093522497\\nProduct Interest: Shade\\nProject Type: Childcare\\nInquiry Comments: Single post shade..."\n' +
'- SKIP empty columns. EXCLUDE footer and forwarded headers.\n\n' +

'TEMPLATE B (LSI Single Lead):\n' +
'- email_body MUST include the COMPLETE lead content starting from "A new LSI Lead Inquiry has been assigned" line, including Rep Org ID, Lead Inquiry Number, and ALL label:value pairs through LSI Comments.\n' +
'- Labels: Rep Org ID, Lead Inquiry Number, Contact Email, Company Name, Contact Name, Contact Title, Address, Company Phone, Mobile Phone, LSI Marketing Consent, Contact Method, Lead Source Description, Business Segment, Project Type, Product Interest, Inquiry Comments, LSI Comments.\n' +
'- Build email_body as "Label: Value" pairs, one per line, preserving ALL labels even if value is empty.\n' +
'- EXCLUDE footer and forwarded headers.\n\n' +

'TEMPLATE C (Free-form Human Email):\n' +
'- Return actual email body content as-is.\n' +
'- EXCLUDE forwarded headers, signatures (Regards/name/contact at bottom), disclaimers.\n\n' +

'For MULTIPLE LEADS: email_header and email_footer go at root level. Each lead object has its OWN email_body.\n\n' +
'Smart mapping rules:\n' +
'- "Name" → FirstName / LastName. Title prefixes (Pastor, Dr., Rev., Mr., Mrs., Ms., Prof.) → Title field.\n' +
'- Email in body → Email. Phone numbers → Phone or MobilePhone.\n' +
'- Company names → Company. Job titles → Title.\n' +
'- Locations → City, State, Country, Street.\n' +
'- Lead source phrases → LeadSource. Industry names → Industry.\n' +
'- Custom fields ending in __c are allowed.\n\n' +

'IMPORTANT:\n' +
'- NEVER extract Email/Phone/Website from signatures/footers.\n' +
'- Numbers must be numeric types. Dates in ISO format. Missing data = "".\n' +
'- Email values MUST NOT contain "mailto:", brackets, HTML.\n\n' +

'SUMMARY WRITING RULES:\n' +
'- Write in clear, natural, professional English. One concise sentence.\n' +
'- Do NOT use template phrases like "Lead INQ-" or field labels.\n' +
'- Focus on the customer\'s intent and business need.\n\n' +

'Output rules (STRICT):\n' +
'- Return PURE JSON ONLY. No markdown, no code fences, no explanation.\n' +
'- Never add fields not in the allowed list except "summary", "email_body", "email_header", "email_footer".\n' +
'- "summary" and "email_body" MUST be present in each lead object.\n' +
'- "email_header" and "email_footer" at root level (or in each lead if single).\n' +
'- The FIRST character MUST be "{" and the LAST MUST be "}".';
    }

    // ------------------------------------------------------------
    // Default USER PROMPT
    // ------------------------------------------------------------
    private static String getDefaultUserPrompt() {
        return
'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
'Always include "summary", "email_body", "email_header", "email_footer".\n' +
'Follow system instructions strictly.\n' +
'IMPORTANT: If you see multiple "INQ-" numbers or multiple distinct leads, create a SEPARATE lead object for EACH one in a "leads" array.\n' +
'Do NOT add extra fields.\n' +
'Do NOT add Markdown or explanation text.\n' +
'The first character must be "{" and the last must be "}".\n' +
'Here is the email body:\n' +
'{EMAIL_BODY}';
    }
}*/
/*public with sharing class EmailToLeadAIConfigController {
    
    //adding scheduler method
    // Add this method inside EmailToLeadAIConfigController
@AuraEnabled
public static void updateRetryHours(Decimal retryHours) {

    Integer hours = 1;

    if (retryHours != null && retryHours > 0) {
        hours = Integer.valueOf(retryHours);
    }

    EmailToLead_Ai__AI_Configure__c cfg = [
        SELECT Id, EmailToLead_Ai__Scheduler_Retry_Hours__c
        FROM EmailToLead_Ai__AI_Configure__c
        WHERE EmailToLead_Ai__isActive__c = true
        LIMIT 1
    ];

    if (cfg == null) {
        throw new AuraHandledException('Active AI configuration not found.');
    }

    cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c = hours;
    update cfg;

    // Ensure the hourly scheduler is active
    EmailToLeadRetryScheduler.scheduleHourly();
}


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
                   EmailToLead_Ai__Scheduler_Retry_Hours__c,
                   EmailToLead_Ai__isActive__c
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE EmailToLead_Ai__isActive__c = true
            LIMIT 1
        ];

        return existing.isEmpty() ? null : existing[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getActiveModels() {

        Map<String, EmailToLead_Ai__AI_Configs__c> allModels =
            EmailToLead_Ai__AI_Configs__c.getAll();

        List<String> modelNames = new List<String>();

        if (allModels == null || allModels.isEmpty()) {
            return modelNames;
        }

        for (String key : allModels.keySet()) {
            EmailToLead_Ai__AI_Configs__c cfg = allModels.get(key);

            if (cfg != null && cfg.EmailToLead_Ai__Is_Active__c == true) {
                modelNames.add(cfg.Name);
            }
        }

        modelNames.sort();
        return modelNames;
    }

    @AuraEnabled
    public static EmailToLead_Ai__AI_Configure__c createDefaultConfig() {

        List<EmailToLead_Ai__AI_Configure__c> existing = [
            SELECT Id, Name, EmailToLead_Ai__Model__c,
                   EmailToLead_Ai__System_prompt__c,
                   EmailToLead_Ai__User_Prompt__c,
                   EmailToLead_Ai__Scheduler_Retry_Hours__c,
                   EmailToLead_Ai__isActive__c
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE EmailToLead_Ai__isActive__c = true
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0];
        }

        String defaultProvider = 'Mistral';

        Map<String, EmailToLead_Ai__AI_Configs__c> allModels =
            EmailToLead_Ai__AI_Configs__c.getAll();

        if (allModels != null && !allModels.isEmpty()) {
            EmailToLead_Ai__AI_Configs__c def = allModels.get(defaultProvider);
            if (def == null || def.EmailToLead_Ai__Is_Active__c == false) {
                for (String k : allModels.keySet()) {
                    EmailToLead_Ai__AI_Configs__c temp = allModels.get(k);
                    if (temp != null && temp.EmailToLead_Ai__Is_Active__c == true) {
                        defaultProvider = temp.Name;
                        break;
                    }
                }
            }
        }

        EmailToLead_Ai__AI_Configure__c cfg = new EmailToLead_Ai__AI_Configure__c(
            Name                                 = 'Default',
            EmailToLead_Ai__isActive__c          = true,
            EmailToLead_Ai__Model__c             = defaultProvider,
            EmailToLead_Ai__System_prompt__c     = getDefaultSystemPrompt(),
            EmailToLead_Ai__User_Prompt__c       = getDefaultUserPrompt(),
            EmailToLead_Ai__Scheduler_Retry_Hours__c = 1
        );

        insert cfg;
        return cfg;
    }
private static String getDefaultSystemPrompt() {
    return
'You are a Salesforce Lead Extractor running in SCHEMA MODE.\n\n' +
'OUTPUT FORMAT RULES:\n' +
'1. SINGLE LEAD: Return a single flat JSON object { ... }.\n' +
'2. MULTIPLE LEADS: If you detect multiple leads (e.g., multiple "INQ-" numbers, or multiple distinct contact blocks), return { "leads": [ {...}, {...} ] }.\n\n' +
'The JSON MUST contain:\n' +
'1. ONLY valid Salesforce Lead API field names from the allowed list.\n' +
'2. A "summary" field that contains a short textual summary of the email.\n\n' +

'SUMMARY WRITING RULES (CRITICAL):\n' +
'- The "summary" must be written in clear, natural, professional English.\n' +
'- It must sound like a human sales representative wrote it.\n' +
'- Do NOT use template phrases like "Lead INQ-", "Contact:", or field labels.\n' +
'- Do NOT repeat internal IDs, inquiry numbers, or system codes.\n' +
'- Focus on the customer’s intent and business need.\n' +
'- Prefer one concise sentence when possible.\n' +
'- Make it suitable for quick reading inside Salesforce.\n\n' +

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
'- Never add fields not in the allowed list except "summary".\n' +
'- "summary" must ALWAYS be present inside the JSON (or inside each lead object if multiple).\n' +
'- The FIRST character of the response MUST be "{" and the LAST character MUST be "}".\n' +
'- Do NOT include any explanation, comments, or reasoning outside the JSON object.\n' +
'- Do NOT include markdown, HTML, or code fences anywhere in the output.';
} 

 /* private static String getDefaultSystemPrompt() {
        return
'You are a Salesforce Lead Extractor running in SCHEMA MODE.\n\n' +
'OUTPUT FORMAT RULES:\n' +
'1. SINGLE LEAD: Return a single flat JSON object { ... }.\n' +
'2. MULTIPLE LEADS: If you detect multiple leads (e.g., multiple "INQ-" numbers, or multiple distinct contact blocks), return { "leads": [ {...}, {...} ] }.\n\n' +
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
'- Never add fields not in the allowed list except "summary".\n' +
'- "summary" must ALWAYS be present inside the JSON (or inside each lead object if multiple).\n' +
'- The FIRST character of the response MUST be "{" and the LAST character MUST be "}".\n' +
'- Do NOT include any explanation, comments, or reasoning outside the JSON object.\n' +
'- Do NOT include markdown, HTML, or code fences anywhere in the output.';

    }

    private static String getDefaultUserPrompt() {
        return
'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
'Always include the field "summary".\n' +
'Follow system instructions strictly.\n' +
'IMPORTANT: If you see multiple "INQ-" numbers or multiple distinct leads, create a SEPARATE lead object for EACH one in a "leads" array.\n' +
'Do NOT add extra fields.\n' +
'Do NOT add Markdown or explanation text.\n' +
'The first character must be "{" and the last must be "}".\n' +
'Here is the email body:\n' +
'{EMAIL_BODY}';
    }
}*/
public with sharing class EmailToLeadAIConfigController {
    
    //adding scheduler method
    // Add this method inside EmailToLeadAIConfigController
@AuraEnabled
public static void updateRetryHours(Decimal retryHours) {

    Integer hours = 1;

    if (retryHours != null && retryHours > 0) {
        hours = Integer.valueOf(retryHours);
    }

    EmailToLead_Ai__AI_Configure__c cfg = [
        SELECT Id, EmailToLead_Ai__Scheduler_Retry_Hours__c
        FROM EmailToLead_Ai__AI_Configure__c
        WHERE EmailToLead_Ai__isActive__c = true
        LIMIT 1
    ];

    if (cfg == null) {
        throw new AuraHandledException('Active AI configuration not found.');
    }

    cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c = hours;
    update cfg;

    // Ensure the hourly scheduler is active
    EmailToLeadRetryScheduler.scheduleHourly();
}


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
                   EmailToLead_Ai__Scheduler_Retry_Hours__c,
                   EmailToLead_Ai__isActive__c
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE EmailToLead_Ai__isActive__c = true
            LIMIT 1
        ];

        return existing.isEmpty() ? null : existing[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getActiveModels() {

        Map<String, EmailToLead_Ai__AI_Configs__c> allModels =
            EmailToLead_Ai__AI_Configs__c.getAll();

        List<String> modelNames = new List<String>();

        if (allModels == null || allModels.isEmpty()) {
            return modelNames;
        }

        for (String key : allModels.keySet()) {
            EmailToLead_Ai__AI_Configs__c cfg = allModels.get(key);

            if (cfg != null && cfg.EmailToLead_Ai__Is_Active__c == true) {
                modelNames.add(cfg.Name);
            }
        }

        modelNames.sort();
        return modelNames;
    }
    @AuraEnabled
public static EmailToLead_Ai__AI_Configure__c ensureActiveConfig() {

    // Lock any existing active config
    List<EmailToLead_Ai__AI_Configure__c> existing = [
        SELECT Id,
               Name,
               EmailToLead_Ai__Model__c,
               EmailToLead_Ai__System_prompt__c,
               EmailToLead_Ai__User_Prompt__c,
               EmailToLead_Ai__Scheduler_Retry_Hours__c,
               EmailToLead_Ai__isActive__c
        FROM EmailToLead_Ai__AI_Configure__c
        WHERE EmailToLead_Ai__isActive__c = true
        LIMIT 1
        FOR UPDATE
    ];

    // If active config already exists, return it
    if (!existing.isEmpty()) {
        return existing[0];
    }

    // Otherwise create safely
    EmailToLead_Ai__AI_Configure__c cfg = createDefaultConfig();

    return cfg;
}

    @AuraEnabled
    public static EmailToLead_Ai__AI_Configure__c createDefaultConfig() {

        List<EmailToLead_Ai__AI_Configure__c> existing = [
            SELECT Id, Name, EmailToLead_Ai__Model__c,
                   EmailToLead_Ai__System_prompt__c,
                   EmailToLead_Ai__User_Prompt__c,
                   EmailToLead_Ai__Scheduler_Retry_Hours__c,
                   EmailToLead_Ai__isActive__c
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE EmailToLead_Ai__isActive__c = true
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0];
        }

        String defaultProvider = 'Mistral';

        Map<String, EmailToLead_Ai__AI_Configs__c> allModels =
            EmailToLead_Ai__AI_Configs__c.getAll();

        if (allModels != null && !allModels.isEmpty()) {
            EmailToLead_Ai__AI_Configs__c def = allModels.get(defaultProvider);
            if (def == null || def.EmailToLead_Ai__Is_Active__c == false) {
                for (String k : allModels.keySet()) {
                    EmailToLead_Ai__AI_Configs__c temp = allModels.get(k);
                    if (temp != null && temp.EmailToLead_Ai__Is_Active__c == true) {
                        defaultProvider = temp.Name;
                        break;
                    }
                }
            }
        }

        EmailToLead_Ai__AI_Configure__c cfg = new EmailToLead_Ai__AI_Configure__c(
            Name                                 = 'Default',
            EmailToLead_Ai__isActive__c          = true,
            EmailToLead_Ai__Model__c             = defaultProvider,
            EmailToLead_Ai__System_prompt__c     = getDefaultSystemPrompt(),
            EmailToLead_Ai__User_Prompt__c       = getDefaultUserPrompt(),
            EmailToLead_Ai__Scheduler_Retry_Hours__c = 1
        );

        insert cfg;
        return cfg;
    }
private static String getDefaultSystemPrompt() {
    return
'You are a Salesforce Lead Extractor running in SCHEMA MODE.\n\n' +
'OUTPUT FORMAT RULES:\n' +
'1. SINGLE LEAD: Return a single flat JSON object { ... }.\n' +
'2. MULTIPLE LEADS: If you detect multiple leads (e.g., multiple "INQ-" numbers, or multiple distinct contact blocks), return { "leads": [ {...}, {...} ] }.\n\n' +
'The JSON MUST contain:\n' +
'1. ONLY valid Salesforce Lead API field names from the allowed list.\n' +
'2. A "summary" field that contains a short textual summary of the email.\n' +
'3. An "email_body" field - see TEMPLATE DETECTION rules below.\n' +
'4. An "email_header" field - find the LAST From/Sent/To/Subject header block that appears IMMEDIATELY before the lead data (just before "Your daily summary", "A new LSI Lead", or the actual lead content). This is the header of the email that CONTAINS the lead, NOT the outer forwarding headers. Include From, Sent/Date, To, Subject, Cc lines only. If no header exists directly above the lead content, return "".\n' +
'5. An "email_footer" field - footer text below lead content like "View the detailed information available on Play365". If none, return "".\n\n' +

'TEMPLATE DETECTION (check these keywords IN ORDER):\n' +
'IF email contains "Your daily summary of Leads" AND "Lead Inquiry Number" AND "Contact Methods" → TEMPLATE A (Daily Summary Table)\n' +
'ELSE IF email contains "A new LSI Lead Inquiry has been assigned" AND "Rep Org ID:" AND "Lead Inquiry Number:" → TEMPLATE B (LSI Single Lead)\n' +
'ELSE → TEMPLATE C (Free-form Human Email)\n\n' +

'LEAD IDENTIFICATION:\n' +
'- ONLY Template A (Daily Summary) can contain multiple leads.\n' +
'- Template B and C are ALWAYS single lead = flat JSON { ... }.\n' +
'- In Template A: the email lists column headers vertically first, then each lead\'s values follow in the SAME order.\n' +
'- Each "INQ-" marks the START of a new lead. From one INQ to the next INQ is one complete lead\'s data.\n' +
'- Multiple INQ- in Template A = return { "leads": [ {...}, {...} ] } array.\n' +
'- Single INQ- or no INQ- = return flat JSON { ... }.\n\n' +

'BUILD "email_body" PER LEAD:\n\n' +

'TEMPLATE A (Daily Summary):\n' +
'- The column headers are: Lead Inquiry Number, Contact Methods, Promotion (Lead Source) Description, Company Name, Contact Name, Address, Email, Phone, Product Interest, Project Type, Sales Literature Items, Inquiry Comments, LSI Comments.\n' +
'- These headers appear once at the top. After them, each lead\'s values appear in the SAME order, starting with its INQ- number.\n' +
'- Map each value to its corresponding column header by position order.\n' +
'- Build email_body as "Label: Value" pairs, one per line.\n' +
'- Each lead MUST include ALL values from its INQ to the next INQ or end of content.\n' +
'- SKIP empty values. EXCLUDE footer and forwarded headers.\n\n' +

'TEMPLATE B (LSI Single Lead):\n' +
'- email_body MUST include the COMPLETE lead content starting from "A new LSI Lead Inquiry has been assigned" line, including Rep Org ID, Lead Inquiry Number, and ALL label:value pairs through LSI Comments.\n' +
'- Labels: Rep Org ID, Lead Inquiry Number, Contact Email, Company Name, Contact Name, Contact Title, Address, Company Phone, Mobile Phone, LSI Marketing Consent, Contact Method, Lead Source Description, Business Segment, Project Type, Product Interest, Inquiry Comments, LSI Comments.\n' +
'- Build email_body as "Label: Value" pairs, one per line, preserving ALL labels even if value is empty.\n' +
'- EXCLUDE footer and forwarded headers.\n\n' +

'TEMPLATE C (Free-form Human Email):\n' +
'- email_body MUST contain the COMPLETE original email text exactly as written.\n' +
'- Include greeting, all paragraphs, all content lines — do NOT restructure or convert to label:value format.\n' +
'- ONLY exclude: forwarded message headers (---------- Forwarded message ---------), email signature block (Regards/name/contact info at the very bottom), and disclaimers.\n' +
'- Keep everything else intact — introductions, context sentences, closing lines.\n\n' +

'For MULTIPLE LEADS (Template A only): email_header and email_footer go at root level. Each lead object has its OWN email_body covering its FULL data from its INQ to the next INQ or end.\n\n' +

'Smart mapping rules:\n' +
'- "Name" → FirstName / LastName. Title prefixes (Pastor, Dr., Rev., Mr., Mrs., Ms., Prof.) → Title field.\n' +
'- Email in body → Email. Phone numbers → Phone or MobilePhone.\n' +
'- Company names → Company. Job titles → Title.\n' +
'- Locations → City, State, Country, Street.\n' +
'- Lead source phrases → LeadSource. Industry names → Industry.\n' +
'- Custom fields ending in __c are allowed.\n\n' +

'IMPORTANT:\n' +
'- For ALL templates: completely IGNORE and EXCLUDE forwarded message headers (---------- Forwarded message ---------, -------- Original Message --------, etc.), email signatures, footers, and boilerplate. Only extract data from the actual lead content.\n' +
'- NEVER extract Email/Phone/Website from signatures/footers.\n' +
'- Numbers must be numeric types. Dates in ISO format. Missing data = "".\n' +
'- Email values MUST NOT contain "mailto:", brackets, HTML.\n\n' +

'SUMMARY WRITING RULES:\n' +
'- Write in clear, natural, professional English. One concise sentence.\n' +
'- Do NOT use template phrases like "Lead INQ-" or field labels.\n' +
'- Focus on the customer\'s intent and business need.\n\n' +

'Output rules (STRICT):\n' +
'- Return PURE JSON ONLY. No markdown, no code fences, no explanation.\n' +
'- Never add fields not in the allowed list except "summary", "email_body", "email_header", "email_footer".\n' +
'- "summary" and "email_body" MUST be present in each lead object.\n' +
'- "email_header" and "email_footer" at root level (or in each lead if single).\n' +
'- The FIRST character MUST be "{" and the LAST MUST be "}".';
}

    private static String getDefaultUserPrompt() {
        return
'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
'Always include "summary", "email_body", "email_header", "email_footer".\n' +
'Follow system instructions strictly.\n' +
'IMPORTANT: If you see multiple "INQ-" numbers or multiple distinct leads, create a SEPARATE lead object for EACH one in a "leads" array.\n' +
'Do NOT add extra fields.\n' +
'Do NOT add Markdown or explanation text.\n' +
'The first character must be "{" and the last must be "}".\n' +
'Here is the email body:\n' +
'{EMAIL_BODY}';
    }
}