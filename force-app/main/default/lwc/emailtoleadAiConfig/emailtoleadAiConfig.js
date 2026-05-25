import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveConfig from '@salesforce/apex/EmailToLeadAIConfigController.getActiveConfig';
import createDefaultConfig from '@salesforce/apex/EmailToLeadAIConfigController.createDefaultConfig';
import getActiveModels from '@salesforce/apex/EmailToLeadAIConfigController.getActiveModels';

// ------------------------------------------------------------
// DEFAULT PROMPTS (FULL - same idea as Apex)
// ------------------------------------------------------------
const DEFAULT_SYSTEM_PROMPT =
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
    '- Custom fields ending in __c are allowed.\n\n' +
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
    '- The FIRST character MUST be "{" and the LAST MUST be "}".';

const DEFAULT_USER_PROMPT =
    'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
    'Always include "summary", "email_body", "email_header", "email_footer".\n' +
    'Follow system instructions strictly.\n' +
    'IMPORTANT: If you see multiple "INQ-" numbers or the email is a daily summary → return {}.\n' +
    'Do NOT add extra fields.\n' +
    'Do NOT add Markdown or explanation text.\n' +
    'The first character must be "{" and the last must be "}".\n' +
    'Here is the email body:\n' +
    '{EMAIL_BODY}';

// Default model
const DEFAULT_MODEL = 'gpt-5.4-mini';

// Default retry hours (for scheduler)
const DEFAULT_RETRY_HOURS = 1;

export default class EmailtoleadAiConfig extends LightningElement {
    @track configId;
    @track loaded = false;

    @track retryHours = DEFAULT_RETRY_HOURS;
    savedRetryHours = DEFAULT_RETRY_HOURS;

    @track modelOptions = [];

    @track systemPrompt = DEFAULT_SYSTEM_PROMPT;
    @track userPrompt = DEFAULT_USER_PROMPT;
    @track modelValue = DEFAULT_MODEL;

    savedSystemPrompt = DEFAULT_SYSTEM_PROMPT;
    savedUserPrompt = DEFAULT_USER_PROMPT;

    wasAutoCreated = false;
    hasSavedOnce = false;
    isInitialized = false;
    isCreating = false;

    @wire(getActiveModels)
    wiredModels({ data, error }) {
        console.log('### emailtoleadAiConfig: wiredModels called');
        if (data) {
            console.log('### wiredModels Data:', data);
            this.modelOptions = data.map((m) => ({ label: m, value: m }));
            if (this.modelOptions.length > 0) {
                const values = this.modelOptions.map((x) => x.value);
                if (!values.includes(this.modelValue)) {
                    this.modelValue = this.modelOptions[0].value;
                }
            }
        } else if (error) {
            console.error('### wiredModels ERROR:', JSON.stringify(error));
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    @wire(getActiveConfig)
    wiredConfig({ data, error }) {
        console.log('### emailtoleadAiConfig: wiredConfig called');
        if (this.isInitialized) {
            console.log('### wiredConfig: already initialized, skipping');
            return;
        }
        if (data) {
            console.log('### wiredConfig Data:', data);
            this.configId = data.Id;
            this.savedSystemPrompt = data.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;
            this.savedUserPrompt = data.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;
            this.systemPrompt = this.savedSystemPrompt;
            this.userPrompt = this.savedUserPrompt;
            this.modelValue = data.EmailToLead_Ai__Model__c || DEFAULT_MODEL;
            this.retryHours = data.EmailToLead_Ai__Scheduler_Retry_Hours__c != null
                ? data.EmailToLead_Ai__Scheduler_Retry_Hours__c
                : DEFAULT_RETRY_HOURS;
            this.savedRetryHours = this.retryHours;
            this.wasAutoCreated = false;
            this.hasSavedOnce = true;
            this.loaded = true;
            this.isInitialized = true;
            return;
        }
        if (data === null && !this.isCreating) {
            console.log('### wiredConfig: no data, initiating default config creation');
            this.isCreating = true;
            this.initDefaultConfig();
            return;
        }
        if (error) {
            console.error('### wiredConfig ERROR:', JSON.stringify(error));
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    initDefaultConfig() {
        console.log('### emailtoleadAiConfig: initDefaultConfig START');
        createDefaultConfig()
            .then((cfg) => {
                console.log('### initDefaultConfig SUCCESS:', cfg);
                this.configId = cfg.Id;
                this.savedSystemPrompt = cfg.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;
                this.savedUserPrompt = cfg.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;
                this.systemPrompt = this.savedSystemPrompt;
                this.userPrompt = this.savedUserPrompt;
                this.modelValue = cfg.EmailToLead_Ai__Model__c || DEFAULT_MODEL;
                this.retryHours = cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c != null
                    ? cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c
                    : DEFAULT_RETRY_HOURS;
                this.savedRetryHours = this.retryHours;
                this.wasAutoCreated = true;
                this.hasSavedOnce = false;
                this.loaded = true;
                this.isInitialized = true;
            })
            .catch((error) => {
                console.error('### initDefaultConfig ERROR:', JSON.stringify(error));
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isCreating = false;
            });
    }

    handleSystemPromptChange(event) {
        this.systemPrompt = event.detail.value;
    }

    handleUserPromptChange(event) {
        this.userPrompt = event.detail.value;
    }

    handleModelChange(event) {
        this.modelValue = event.detail.value;
    }

    handleRetryHoursChange(event) {
        this.retryHours = event.detail.value;
    }

    handleSubmit(event) {
        console.log('### handleSubmit START');
        event.preventDefault();
        const fields = event.detail.fields || {};
        
        // Ensure manual mapping for fields
        fields.EmailToLead_Ai__System_prompt__c = this.systemPrompt;
        fields.EmailToLead_Ai__User_Prompt__c = this.userPrompt;
        fields.EmailToLead_Ai__Model__c = this.modelValue;

        console.log('### Submitting fields:', JSON.stringify(fields));
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess(event) {
        console.log('### handleSuccess START');
        if (!this.configId && event.detail?.id) {
            this.configId = event.detail.id;
        }
        this.savedSystemPrompt = this.systemPrompt;
        this.savedUserPrompt = this.userPrompt;
        
        const msg = this.wasAutoCreated && !this.hasSavedOnce
                ? 'AI configuration record created.'
                : 'AI configuration record updated.';
        this.wasAutoCreated = false;
        this.hasSavedOnce = true;

        this.showToast('Success', msg, 'success');
    }

    handleError(event) {
        const msg = event?.detail?.detail || 'Unknown error occurred.';
        this.showToast('Error', msg, 'error');
    }

    handleReset() {
        this.systemPrompt = this.savedSystemPrompt || DEFAULT_SYSTEM_PROMPT;
        this.userPrompt = this.savedUserPrompt || DEFAULT_USER_PROMPT;
        this.retryHours = this.savedRetryHours != null ? this.savedRetryHours : DEFAULT_RETRY_HOURS;
        this.showToast('Reset', 'Prompts reset to last saved values.', 'info');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
//Gitting
