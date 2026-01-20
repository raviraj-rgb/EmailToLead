import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveConfig from '@salesforce/apex/EmailToLeadAIConfigController.getActiveConfig';
import createDefaultConfig from '@salesforce/apex/EmailToLeadAIConfigController.createDefaultConfig';

// ---------- DEFAULT PROMPTS (same as Apex) ----------
/* OLD PROMPT - Single Lead Only
const DEFAULT_SYSTEM_PROMPT =
    'You are a Salesforce Lead Extractor running in SCHEMA MODE.\\n' +
    'Always return a SINGLE JSON OBJECT and NOTHING ELSE.\\n\\n' +
    'The JSON MUST contain:\\n' +
    '1. ONLY valid Salesforce Lead API field names from the allowed list.\\n' +
    '2. A \"summary\" field that contains a short textual summary of the email.\\n\\n' +
    'Smart mapping rules:\\n' +
    '- \"Name\" → FirstName / LastName\\n' +
    '- Email present in email body → Email\\n' +
    '- Phone numbers → Phone or MobilePhone\\n' +
    '- Company names → Company\\n' +
    '- Job titles → Title\\n' +
    '- \"budget\" or \"revenue\" → AnnualRevenue\\n' +
    '- \"hot\" leads → Rating = \"Hot\"\\n' +
    '- Locations → City, State, Country, Street\\n' +
    '- Employee counts → NumberOfEmployees\\n' +
    '- Website URLs → Website\\n' +
    '- Industry names → Industry\\n' +
    '- Lead source phrases → LeadSource\\n' +
    '- Custom fields ending in __c are allowed and should be used as provided.\\n\\n' +
    'Email body handling (IMPORTANT):\\n' +
    '- Treat the \"email body\" as ONLY the lead-relevant content.\\n' +
    '- Completely IGNORE and EXCLUDE any email signature, footer, or boilerplate when deriving fields or building the summary.\\n' +
    '- Consider as signature/footer (to be ignored):\\n' +
    '  - Blocks at the end of the message that contain the sender\\'s name plus job title, company name, and contact details.\\n' +
    '  - Lines that list roles or positions (for example, \"Consultant\", \"Manager\", \"Director\", \"CRM Consultant | <Company>\") together with phone, email, or address.\\n' +
    '  - Standalone contact blocks with email addresses, phone numbers, websites, social links, or taglines at the very bottom.\\n' +
    '  - Legal disclaimers, confidentiality notices, unsubscribe instructions, or marketing taglines at the bottom of the email.\\n' +
    '- When multiple emails appear, prefer the email that is clearly labeled as the lead/contact email in the main content (for example in labeled fields like \"Contact Email: ...\"), and ignore emails that are only present in signature/footer blocks.\\n\\n' +
    'Data-format rules:\\n' +
    '- Numbers must be numeric types.\\n' +
    '- Dates must be ISO format.\\n' +
    '- Missing data must be empty strings \"\".\\n' +
    '- Email values MUST NOT contain \"mailto:\", brackets, parentheses, HTML, markdown, or any surrounding text.\\n\\n' +
    'Output rules (STRICT):\\n' +
    '- Return PURE JSON ONLY, no text before or after.\\n' +
    '- Do NOT use Markdown or code fences (no backticks at all).\\n' +
    '- Do NOT include explanations, reasoning, or any other text outside the JSON object.\\n' +
    '- Do NOT nest the JSON inside an array or another wrapper object.\\n' +
    '- Never add fields not in the allowed list except \"summary\".\\n' +
    '- \"summary\" must ALWAYS be present inside the JSON.\\n' +
    '- The response MUST consist of exactly one flat JSON object and NOTHING else.\\n' +
    '- The FIRST character of the response MUST be \"{\", and the LAST character MUST be \"}\".\\n' +
    '- Do NOT include any explanation, comments, or reasoning outside the JSON object.\\n' +
    '- Do NOT include markdown, HTML, or code fences anywhere in the output.';
*/

// NEW PROMPT - Supports Multiple Leads (Daily Summary format)
const DEFAULT_SYSTEM_PROMPT =
    'You are a Salesforce Lead Extractor.\\n\\n' +
    'OUTPUT FORMAT RULES:\\n' +
    '1. SINGLE LEAD: Return a single flat JSON object { ... }.\\n' +
    '2. MULTIPLE LEADS: If you detect multiple leads (e.g., multiple "INQ-" numbers, or multiple distinct contact blocks), return { "leads": [ {...}, {...} ] }.\\n\\n' +
    'The JSON MUST contain ONLY valid Salesforce Lead API field names from the allowed list, plus a "summary" field.\\n\\n' +
    'Smart mapping rules:\\n' +
    '- \"Name\" → FirstName / LastName\\n' +
    '- Email present in email body → Email\\n' +
    '- Phone numbers → Phone or MobilePhone\\n' +
    '- Company names → Company\\n' +
    '- Job titles → Title\\n' +
    '- Locations → City, State, Country, Street\\n' +
    '- Website URLs → Website\\n' +
    '- Industry names → Industry\\n' +
    '- Lead source phrases → LeadSource\\n' +
    '- Custom fields ending in __c are allowed.\\n\\n' +
    'Email body handling (IMPORTANT):\\n' +
    '- IGNORE email signatures, footers, disclaimers, and boilerplate.\\n' +
    '- When multiple emails appear, prefer the one labeled as the lead/contact email.\\n\\n' +
    'Data-format rules:\\n' +
    '- Numbers must be numeric types.\\n' +
    '- Dates must be ISO format.\\n' +
    '- Missing data must be empty strings \"\".\\n' +
    '- Email values MUST NOT contain \"mailto:\", brackets, or HTML.\\n\\n' +
    'Output rules (STRICT):\\n' +
    '- Return PURE JSON ONLY, no text before or after.\\n' +
    '- Do NOT use Markdown or code fences.\\n' +
    '- The FIRST character MUST be \"{\" and the LAST character MUST be \"}\".\\n' +
    '- \"summary\" must ALWAYS be present inside each lead object.';

/* OLD USER PROMPT - Single Lead Only
const DEFAULT_USER_PROMPT =
    'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\\n' +
    'Always include the field "summary".\\n' +
    'Follow system instructions strictly.\\n' +
    'Return ONLY one flat JSON object.\\n' +
    'Do NOT add extra fields.\\n' +
    'Do NOT add Markdown or explanation text.\\n' +
    'The first character must be "{" and the last must be "}".\\n' +
    'Here is the email body:\\n' +
    '{EMAIL_BODY}';
*/

// NEW USER PROMPT - Supports Multiple Leads
const DEFAULT_USER_PROMPT =
    'Extract valid Salesforce Lead fields into JSON.\\n' +
    'IMPORTANT for Daily Summaries: If you see multiple "INQ-" numbers or multiple distinct contact blocks, create a SEPARATE lead object for EACH one in a "leads" array.\\n' +
    'Allowed Fields: {ALLOWED_FIELDS}.\\n' +
    'Always include the field "summary" in each lead.\\n' +
    'Do NOT add Markdown or explanation text.\\n' +
    'The first character must be "{" and the last must be "}".\\n' +
    'Here is the email body:\\n' +
    '{EMAIL_BODY}';

// default model (must match what you set in Apex)
const DEFAULT_MODEL = 'glm-4.5-air';

export default class EmailtoleadAiConfig extends LightningElement {
    @track configId;
    @track loaded = false;
    modelOptions = [
        { label: 'glm-4.5-air', value: 'glm-4.5-air' }
    ];

    // UI starts with defaults so user sees immediately
    @track systemPrompt = DEFAULT_SYSTEM_PROMPT;
    @track userPrompt = DEFAULT_USER_PROMPT;
    @track modelValue = DEFAULT_MODEL;

    // last saved values (for Reset)
    savedSystemPrompt = DEFAULT_SYSTEM_PROMPT;
    savedUserPrompt = DEFAULT_USER_PROMPT;

    // toast flags
    wasAutoCreated = false;
    hasSavedOnce = false;

    // guards
    isInitialized = false; // prevents wire reruns overwriting UI
    isCreating = false;    // prevents double create

    // 1) Try to load existing active config
    @wire(getActiveConfig)
    wiredConfig({ data, error }) {
        // prevent wire reruns from overriding changes
        if (this.isInitialized) {
            return;
        }

        if (data) {
            // Existing record found
            this.configId = data.Id;

            this.savedSystemPrompt =
                data.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;
            this.savedUserPrompt =
                data.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

            this.systemPrompt = this.savedSystemPrompt;
            this.userPrompt = this.savedUserPrompt;
            this.modelValue =
                data.EmailToLead_Ai__Model__c || DEFAULT_MODEL;

            this.wasAutoCreated = false;
            this.hasSavedOnce = true;
            this.loaded = true;
            this.isInitialized = true;
            return;
        }

        // ✅ If no record exists -> create default ONCE
        if (data === null && !this.isCreating) {
            this.isCreating = true;
            this.initDefaultConfig();
            return;
        }

        if (error) {
            this.showToast(
                'Error',
                error.body ? error.body.message : error.message,
                'error'
            );
        }
    }

    initDefaultConfig() {
        createDefaultConfig()
            .then((cfg) => {
                this.configId = cfg.Id;

                this.savedSystemPrompt =
                    cfg.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;
                this.savedUserPrompt =
                    cfg.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

                this.systemPrompt = this.savedSystemPrompt;
                this.userPrompt = this.savedUserPrompt;
                this.modelValue =
                    cfg.EmailToLead_Ai__Model__c || DEFAULT_MODEL;

                this.wasAutoCreated = true;   // created on first open
                this.hasSavedOnce = false;
                this.loaded = true;
                this.isInitialized = true;
            })
            .catch((error) => {
                this.showToast(
                    'Error',
                    error.body ? error.body.message : error.message,
                    'error'
                );
            })
            .finally(() => {
                this.isCreating = false;
            });
    }

    // Handlers for user edits
    handleSystemPromptChange(event) {
        this.systemPrompt = event.target.value;
    }

    handleUserPromptChange(event) {
        this.userPrompt = event.target.value;
    }

    handleModelChange(event) {
        this.modelValue = event.target.value;
    }

    // Before save, inject textarea values into fields
    handleSubmit(event) {
        event.preventDefault();

        const fields = event.detail.fields;
        fields.EmailToLead_Ai__System_prompt__c = this.systemPrompt;
        fields.EmailToLead_Ai__User_Prompt__c = this.userPrompt;

        // ✅ Important: Always submit model even if user doesn’t change picklist
        fields.EmailToLead_Ai__Model__c = this.modelValue;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    // After save, sync local state and show toast
    handleSuccess(event) {
        if (!this.configId && event.detail?.id) {
            this.configId = event.detail.id;
        }

        this.savedSystemPrompt = this.systemPrompt;
        this.savedUserPrompt = this.userPrompt;

        const msg = (this.wasAutoCreated && !this.hasSavedOnce)
            ? 'AI configuration record created.'
            : 'AI configuration record updated.';

        this.wasAutoCreated = false;
        this.hasSavedOnce = true;

        this.showToast('Success', msg, 'success');
    }

    // Recommended: handle errors on save
    handleError(event) {
        const msg = event?.detail?.detail || 'Unknown error occurred.';
        this.showToast('Error', msg, 'error');
    }

    // Reset to last saved prompts
    handleReset() {
        this.systemPrompt = this.savedSystemPrompt || DEFAULT_SYSTEM_PROMPT;
        this.userPrompt = this.savedUserPrompt || DEFAULT_USER_PROMPT;

        this.showToast(
            'Reset',
            'Prompts reset to last saved values.',
            'info'
        );
    }

    // Toast helper
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
