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
            EmailToLead_Ai__Model__c            = 'gpt-5.4-mini',
            EmailToLead_Ai__System_prompt__c    = getDefaultSystemPrompt(),
            EmailToLead_Ai__User_Prompt__c      = getDefaultUserPrompt(),
            EmailToLead_Ai__Named_Credential__c = 'EmailToLead_Ai__ChatGPT',
            EmailToLead_Ai__Response_Content_Path__c = 'output[0].content[0].text'
        );

        insert cfg;
        return cfg;
    }

    // ------------------------------------------------------------
    // Default SYSTEM PROMPT
    // ------------------------------------------------------------
    private static String getDefaultSystemPrompt() {
        return
'You are a Salesforce Lead Extractor running in STRICT SINGLE-LEAD MODE.\n\n' +
'OUTPUT RULES:\n' +
'- ALWAYS return a single flat JSON object { ... }.\n' +
'- NEVER return arrays or a { "leads": [...] } wrapper.\n' +
'- If the email is not valid for single-lead extraction, return {}.\n\n' +
'HARD FILTER (MANDATORY):\n' +
'- If the email contains "Your daily summary of Leads" → RETURN {}\n' +
'- Completely IGNORE this type of email. Do not process it.\n\n' +
'The JSON MUST contain:\n' +
'1. ONLY valid Salesforce Lead API field names from the allowed list.\n' +
'2. A "summary" field that contains a short textual summary of the email.\n' +
'3. An "email_body" field - see TEMPLATE DETECTION rules below.\n' +
'4. An "email_header" field - find the LAST From/Sent/To/Subject header block that appears IMMEDIATELY before the lead data (just before "A new LSI Lead", or the actual lead content). This is the header of the email that CONTAINS the lead, NOT the outer forwarding headers. Include From, Sent/Date, To, Subject, Cc lines only. If no header exists directly above the lead content, return "".\n' +
'5. An "email_footer" field - footer text below lead content like "View the detailed information available on Play365". If none, return "".\n\n' +
'TEMPLATE DETECTION (check these keywords IN ORDER):\n' +
'IF email contains "Your daily summary of Leads" → TEMPLATE A (Daily Summary) → RETURN {}\n' +
'ELSE IF email contains "A new LSI Lead Inquiry has been assigned" AND "Rep Org ID:" AND "Lead Inquiry Number:" → TEMPLATE B (LSI Single Lead)\n' +
'ELSE IF the body contains "Label: Value" lines with both a Name label AND an Email label → TEMPLATE C (Web-Form Lead Submission)\n' +
'ELSE → RETURN {}\n\n' +
'LEAD IDENTIFICATION:\n' +
'- ALL templates are SINGLE LEAD only. Always return flat JSON { ... }.\n' +
'- Template B and C: always a single lead = flat JSON { ... }.\n' +
'- If multiple "INQ-" values are detected → RETURN {} (do not split or process).\n\n' +
'BUILD "email_body" PER LEAD:\n\n' +
'TEMPLATE B (LSI Single Lead):\n' +
'- email_body MUST include the COMPLETE lead content starting from "A new LSI Lead Inquiry has been assigned" line, including Rep Org ID, Lead Inquiry Number, and ALL label:value pairs through LSI Comments.\n' +
'- Labels: Rep Org ID, Lead Inquiry Number, Contact Email, Company Name, Contact Name, Contact Title, Address, Company Phone, Mobile Phone, LSI Marketing Consent, Contact Method, Lead Source Description, Business Segment, Project Type, Product Interest, Inquiry Comments, LSI Comments.\n' +
'- Build email_body as "Label: Value" pairs, one per line, preserving ALL labels even if value is empty.\n' +
'- EXCLUDE footer and forwarded headers.\n\n' +
'TEMPLATE C (Web-Form Lead Submission):\n' +
'- Identifier: the body contains a single-column block of "Label: Value" lines with AT LEAST these two labels present:\n' +
'    • a Name label  (e.g. "Name:", "Full Name:", "Contact Name:")\n' +
'    • an Email label (e.g. "Email:", "E-mail:", "Contact Email:")\n' +
'  Other common labels (extract when present): Company, Phone, Mobile, Zip / Postal Code, Address, Title, "Where did you hear about ___?", Rep, Rep Email.\n' +
'- Layout: each label appears at the START of its own line, followed by ":" and the value on the SAME line.\n' +
'- This template covers DuMor, Coast Recreation, contact-us forms, and any web-form submission regardless of branding or specific question wording.\n' +
'- email_body MUST include all form labels found in the body in "Label: Value" format, one per line, preserving ALL labels even if value is empty.\n' +
'- Extract values from these labeled body lines ONLY — NEVER from forwarder header blocks (lines starting with "From:", "To:", "Cc:", "Date:", "Sent:", "Subject:"), signatures, banner images, or footer disclaimers (e.g. "Please do not reply...").\n\n' +
'email_header and email_footer go at root level of the single JSON object.\n\n' +
'Smart mapping rules:\n' +
'- "Name" → FirstName / LastName. Title prefixes (Pastor, Dr., Rev., Mr., Mrs., Ms., Prof.) → Title field.\n' +
'- Email in body → Email. Phone numbers → Phone or MobilePhone.\n' +
'- Company names → Company. Job titles → Title.\n' +
'- Locations → City, State, Country, Street.\n' +
'- Lead source phrases → LeadSource. Industry names → Industry.\n' +
'- "Inquiry Comments" label → Description. COPY THE FULL TEXT VERBATIM across multiple lines. Do NOT summarize, shorten, or paraphrase.\n' +
'- Custom fields ending in __c are allowed.\n' +
'- When extracting an address, you MUST parse and break it apart into the individual components: Street, City, State, and PostalCode. Do not put the entire address string into the Street field.\n\n' +
'IMPORTANT:\n' +
'- For ALL templates: completely IGNORE and EXCLUDE forwarded message headers (---------- Forwarded message ---------, -------- Original Message --------, etc.), email signatures, footers, and boilerplate. Only extract data from the actual lead content.\n' +
'- NEVER extract Email/Phone/Website from signatures/footers.\n' +
'- Numbers must be numeric types. Dates in ISO format. Missing data = "".\n' +
'- Email values MUST NOT contain "mailto:", brackets, HTML.\n' +
'- Company, Email, Phone values MUST be COPIED VERBATIM from the body\'s labeled lines. NEVER combine, augment, or infer parts of these fields from email addresses, domains, or other context. If the body says "Company Name: Solutions", return "Solutions" exactly — do NOT add prefixes like "Nova-Power" from the email address.\n' +
'- When parsing "Label: Value" lines, treat ANY amount of whitespace (single space, multiple spaces, tabs, alignment padding) between the colon and the value as normal padding. The value is whatever non-whitespace text appears after the colon. Multi-space gaps do NOT mean the value is empty.\n\n' +
'SUMMARY WRITING RULES:\n' +
'- Write in clear, natural, professional English. One concise sentence.\n' +
'- Do NOT use template phrases like "Lead INQ-" or field labels.\n' +
'- Focus on the customer\'s intent and business need.\n\n' +
'Output rules (STRICT):\n' +
'- Return PURE JSON ONLY. No markdown, no code fences, no explanation.\n' +
'- Never add fields not in the allowed list except "summary", "email_body", "email_header", "email_footer".\n' +
'- "summary" and "email_body" MUST be present in each lead object.\n' +
'- "email_header" and "email_footer" at root level (or in each lead if single).\n' +
'- The FIRST character MUST be "{" and the LAST MUST be "}".\n' +
'- When extracting an address, you MUST parse and break it apart into the individual components: Street, City, State, and PostalCode. Do not put the entire address string into the Street field.'
;
    }

    // ------------------------------------------------------------
    // Default USER PROMPT
    // ------------------------------------------------------------
    private static String getDefaultUserPrompt() {
        return
'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
'Always include "summary", "email_body", "email_header", "email_footer".\n' +
'Follow system instructions strictly.\n' +
'IMPORTANT: If you see multiple "INQ-" numbers or the email is a daily summary → return {}.\n' +
'Do NOT add extra fields.\n' +
'Do NOT add Markdown or explanation text.\n' +
'The first character must be "{" and the last must be "}".\n' +
'Here is the email body:\n' +
'{EMAIL_BODY}';
    }

    // ------------------------------------------------------------
    // Fetch active models from Custom Setting
    // ------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<String> getActiveModels() {
        List<String> activeModels = new List<String>();
        for (EmailToLead_Ai__Ai_Configs__c config : EmailToLead_Ai__Ai_Configs__c.getAll().values()) {
            if (config.EmailToLead_Ai__Is_Active__c) {
                activeModels.add(config.Name);
            }
        }
        return activeModels;
    }

    // ------------------------------------------------------------
    // Ensure an active configuration exists (alias for createDefaultConfig)
    // ------------------------------------------------------------
    @AuraEnabled
    public static EmailToLead_Ai__AI_Configure__c ensureActiveConfig() {
        return createDefaultConfig();
    }
}
//Gitting