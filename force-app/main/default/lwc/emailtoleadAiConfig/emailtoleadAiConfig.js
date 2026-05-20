/*import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveConfig from '@salesforce/apex/EmailToLeadAIConfigController.getActiveConfig';
import createDefaultConfig from '@salesforce/apex/EmailToLeadAIConfigController.createDefaultConfig';
import getActiveModels from '@salesforce/apex/EmailToLeadAIConfigController.getActiveModels';

// ------------------------------------------------------------
// DEFAULT PROMPTS (FULL - same idea as Apex)
// ------------------------------------------------------------
const DEFAULT_SYSTEM_PROMPT =
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

const DEFAULT_USER_PROMPT =
    'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
    'Always include the field "summary".\n' +
    'Follow system instructions strictly.\n' +
    'IMPORTANT: If you see multiple "INQ-" numbers or multiple distinct leads, create a SEPARATE lead object for EACH one in a "leads" array.\n' +
    'Do NOT add extra fields.\n' +
    'Do NOT add Markdown or explanation text.\n' +
    'The first character must be "{" and the last must be "}".\n' +
    'Here is the email body:\n' +
    '{EMAIL_BODY}';

// Default model
const DEFAULT_MODEL = 'Mistral';

export default class EmailtoleadAiConfig extends LightningElement {

    @track configId;
    @track loaded = false;
    //for scheduling
    @track retryHours;
    savedRetryHours;


    // dynamic options
    @track modelOptions = [];

    // UI values
    @track systemPrompt = DEFAULT_SYSTEM_PROMPT;
    @track userPrompt = DEFAULT_USER_PROMPT;
    @track modelValue = DEFAULT_MODEL;

    // last saved (for reset)
    savedSystemPrompt = DEFAULT_SYSTEM_PROMPT;
    savedUserPrompt = DEFAULT_USER_PROMPT;

    // internal flags
    wasAutoCreated = false;
    hasSavedOnce = false;

    isInitialized = false;
    isCreating = false;

    // ------------------------------------------------------------
    // Load active models from Custom Setting
    // ------------------------------------------------------------
    @wire(getActiveModels)
    wiredModels({ data, error }) {
        if (data) {
            this.modelOptions = data.map(m => ({ label: m, value: m }));

            // keep current selection valid
            if (this.modelOptions.length > 0) {
                const values = this.modelOptions.map(x => x.value);
                if (!values.includes(this.modelValue)) {
                    this.modelValue = this.modelOptions[0].value;
                }
            }
        } else if (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    // ------------------------------------------------------------
    // Load active config from AI_Configure__c
    // ------------------------------------------------------------
    @wire(getActiveConfig)
    wiredConfig({ data, error }) {

        if (this.isInitialized) return;

        if (data) {
            this.configId = data.Id;

            this.savedSystemPrompt = data.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;
            this.savedUserPrompt = data.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

            this.systemPrompt = this.savedSystemPrompt;
            this.userPrompt = this.savedUserPrompt;
            this.modelValue = data.EmailToLead_Ai__Model__c || DEFAULT_MODEL;

            this.wasAutoCreated = false;
            this.hasSavedOnce = true;
            this.loaded = true;
            this.isInitialized = true;
            return;
        }

        // if none found create one
        if (data === null && !this.isCreating) {
            this.isCreating = true;
            this.initDefaultConfig();
            return;
        }

        if (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    // ------------------------------------------------------------
    // Create default config record once
    // ------------------------------------------------------------
    initDefaultConfig() {
        createDefaultConfig()
            .then(cfg => {
                this.configId = cfg.Id;

                this.savedSystemPrompt = cfg.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;
                this.savedUserPrompt = cfg.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

                this.systemPrompt = this.savedSystemPrompt;
                this.userPrompt = this.savedUserPrompt;
                this.modelValue = cfg.EmailToLead_Ai__Model__c || DEFAULT_MODEL;

                this.wasAutoCreated = true;
                this.hasSavedOnce = false;

                this.loaded = true;
                this.isInitialized = true;
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isCreating = false;
            });
    }

    // ------------------------------------------------------------
    // UI change handlers
    // ------------------------------------------------------------
    handleSystemPromptChange(event) {
        this.systemPrompt = event.target.value;
    }

    handleUserPromptChange(event) {
        this.userPrompt = event.target.value;
    }

    handleModelChange(event) {
        this.modelValue = event.detail.value;
    }

    // ------------------------------------------------------------
    // Save
    // ------------------------------------------------------------
    handleSubmit(event) {
        event.preventDefault();

        const fields = event.detail.fields;
        fields.EmailToLead_Ai__System_prompt__c = this.systemPrompt;
        fields.EmailToLead_Ai__User_Prompt__c = this.userPrompt;
        fields.EmailToLead_Ai__Model__c = this.modelValue;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

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

    handleError(event) {
        const msg = event?.detail?.detail || 'Unknown error occurred.';
        this.showToast('Error', msg, 'error');
    }

    // ------------------------------------------------------------
    // Reset to last saved values
    // ------------------------------------------------------------
    handleReset() {
        this.systemPrompt = this.savedSystemPrompt || DEFAULT_SYSTEM_PROMPT;
        this.userPrompt = this.savedUserPrompt || DEFAULT_USER_PROMPT;
        this.showToast('Reset', 'Prompts reset to last saved values.', 'info');
    }

    // ------------------------------------------------------------
    // Toast helper
    // ------------------------------------------------------------
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}*/
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveConfig from '@salesforce/apex/EmailToLeadAIConfigController.getActiveConfig';
import createDefaultConfig from '@salesforce/apex/EmailToLeadAIConfigController.createDefaultConfig';
import getActiveModels from '@salesforce/apex/EmailToLeadAIConfigController.getActiveModels';

// NEW: Apex method to update retry hours + reschedule scheduler
import updateRetryHours from '@salesforce/apex/EmailToLeadAIConfigController.updateRetryHours';

// ------------------------------------------------------------
// DEFAULT PROMPTS (FULL - same idea as Apex)
// ------------------------------------------------------------
const DEFAULT_SYSTEM_PROMPT =
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

const DEFAULT_USER_PROMPT =
    'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
    'Always include the field "summary".\n' +
    'Follow system instructions strictly.\n' +
    'IMPORTANT: If you see multiple "INQ-" numbers or multiple distinct leads, create a SEPARATE lead object for EACH one in a "leads" array.\n' +
    'Do NOT add extra fields.\n' +
    'Do NOT add Markdown or explanation text.\n' +
    'The first character must be "{" and the last must be "}".\n' +
    'Here is the email body:\n' +
    '{EMAIL_BODY}';

// Default model (Provider Key from Custom Setting: ZAi / Mistral / Groq)
const DEFAULT_MODEL = 'Mistral';

// Default retry hours (for scheduler)
const DEFAULT_RETRY_HOURS = 1;

export default class EmailtoleadAiConfig extends LightningElement {
    @track configId;
    @track loaded = false;

    // ------------------------------------------------------------
    // Scheduling Retry Hours
    // Stored in AI_Configure__c.EmailToLead_Ai__Scheduler_Retry_Hours__c
    // ------------------------------------------------------------
    @track retryHours = DEFAULT_RETRY_HOURS;
    savedRetryHours = DEFAULT_RETRY_HOURS;

    // dynamic options
    @track modelOptions = [];

    // UI values
    @track systemPrompt = DEFAULT_SYSTEM_PROMPT;
    @track userPrompt = DEFAULT_USER_PROMPT;
    @track modelValue = DEFAULT_MODEL;

    // last saved (for reset)
    savedSystemPrompt = DEFAULT_SYSTEM_PROMPT;
    savedUserPrompt = DEFAULT_USER_PROMPT;

    // internal flags
    wasAutoCreated = false;
    hasSavedOnce = false;

    isInitialized = false;
    isCreating = false;

    // ------------------------------------------------------------
    // Load active models from Custom Setting
    // ------------------------------------------------------------
    @wire(getActiveModels)
    wiredModels({ data, error }) {
        if (data) {
            this.modelOptions = data.map((m) => ({ label: m, value: m }));

            // keep current selection valid
            if (this.modelOptions.length > 0) {
                const values = this.modelOptions.map((x) => x.value);
                if (!values.includes(this.modelValue)) {
                    this.modelValue = this.modelOptions[0].value;
                }
            }
        } else if (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    // ------------------------------------------------------------
    // Load active config from AI_Configure__c
    // ------------------------------------------------------------
    @wire(getActiveConfig)
    wiredConfig({ data, error }) {
        if (this.isInitialized) return;

        if (data) {
            this.configId = data.Id;

            this.savedSystemPrompt = data.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;
            this.savedUserPrompt = data.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

            this.systemPrompt = this.savedSystemPrompt;
            this.userPrompt = this.savedUserPrompt;
            this.modelValue = data.EmailToLead_Ai__Model__c || DEFAULT_MODEL;

            // Load retry hours
            this.retryHours =
                data.EmailToLead_Ai__Scheduler_Retry_Hours__c != null
                    ? data.EmailToLead_Ai__Scheduler_Retry_Hours__c
                    : DEFAULT_RETRY_HOURS;

            this.savedRetryHours = this.retryHours;

            this.wasAutoCreated = false;
            this.hasSavedOnce = true;
            this.loaded = true;
            this.isInitialized = true;
            return;
        }

        // if none found create one
        if (data === null && !this.isCreating) {
            this.isCreating = true;
            this.initDefaultConfig();
            return;
        }

        if (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    // ------------------------------------------------------------
    // Create default config record once
    // ------------------------------------------------------------
    initDefaultConfig() {
        createDefaultConfig()
            .then((cfg) => {
                this.configId = cfg.Id;

                this.savedSystemPrompt = cfg.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;
                this.savedUserPrompt = cfg.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

                this.systemPrompt = this.savedSystemPrompt;
                this.userPrompt = this.savedUserPrompt;
                this.modelValue = cfg.EmailToLead_Ai__Model__c || DEFAULT_MODEL;

                // default retry hours from record if present
                this.retryHours =
                    cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c != null
                        ? cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c
                        : DEFAULT_RETRY_HOURS;

                this.savedRetryHours = this.retryHours;

                this.wasAutoCreated = true;
                this.hasSavedOnce = false;

                this.loaded = true;
                this.isInitialized = true;
            })
            .catch((error) => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isCreating = false;
            });
    }

    // ------------------------------------------------------------
    // UI change handlers
    // ------------------------------------------------------------
    handleSystemPromptChange(event) {
        this.systemPrompt = event.target.value;
    }

    handleUserPromptChange(event) {
        this.userPrompt = event.target.value;
    }

    handleModelChange(event) {
        this.modelValue = event.detail.value;
    }

    handleRetryHoursChange(event) {
        this.retryHours = event.target.value;
    }

    // ------------------------------------------------------------
    // Save
    // ------------------------------------------------------------
    handleSubmit(event) {
        event.preventDefault();

        const fields = event.detail.fields;
        fields.EmailToLead_Ai__System_prompt__c = this.systemPrompt;
        fields.EmailToLead_Ai__User_Prompt__c = this.userPrompt;
        fields.EmailToLead_Ai__Model__c = this.modelValue;

        // Save retry hours into AI_Configure__c
        fields.EmailToLead_Ai__Scheduler_Retry_Hours__c = this.retryHours;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    // ------------------------------------------------------------
    // UPDATED: After saving config, re-schedule scheduler immediately
    // So if user changes retry hours (1 -> 2 -> 3), next run updates accordingly.
    // ------------------------------------------------------------
    handleSuccess(event) {
        if (!this.configId && event.detail?.id) {
            this.configId = event.detail.id;
        }

        this.savedSystemPrompt = this.systemPrompt;
        this.savedUserPrompt = this.userPrompt;

        // Save retryHours state for Reset
        this.savedRetryHours = this.retryHours;

        const msg =
            this.wasAutoCreated && !this.hasSavedOnce
                ? 'AI configuration record created.'
                : 'AI configuration record updated.';

        this.wasAutoCreated = false;
        this.hasSavedOnce = true;

        // NEW: Update config + reschedule scheduler job according to latest retryHours
        updateRetryHours({ retryHours: this.retryHours })
            .then(() => {
                this.showToast('Success', msg + ' Scheduler updated successfully.', 'success');
            })
            .catch((error) => {
                const errMsg =
                    error?.body?.message || error?.message || 'Scheduler update failed.';
                this.showToast('Warning', msg + ' but scheduler update failed: ' + errMsg, 'warning');
            });
    }

    handleError(event) {
        const msg = event?.detail?.detail || 'Unknown error occurred.';
        this.showToast('Error', msg, 'error');
    }

    // ------------------------------------------------------------
    // Reset to last saved values
    // ------------------------------------------------------------
    handleReset() {
        this.systemPrompt = this.savedSystemPrompt || DEFAULT_SYSTEM_PROMPT;
        this.userPrompt = this.savedUserPrompt || DEFAULT_USER_PROMPT;

        // Reset retry hours
        this.retryHours =
            this.savedRetryHours != null ? this.savedRetryHours : DEFAULT_RETRY_HOURS;

        this.showToast('Reset', 'Prompts reset to last saved values.', 'info');
    }

    // ------------------------------------------------------------
    // Toast helper
    // ------------------------------------------------------------
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
