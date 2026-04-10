/*import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveConfig from '@salesforce/apex/EmailToLeadAIConfigController.getActiveConfig';
import createDefaultConfig from '@salesforce/apex/EmailToLeadAIConfigController.createDefaultConfig';

// ---------- DEFAULT PROMPTS (same as Apex) ----------
const DEFAULT_SYSTEM_PROMPT =
    /* 'You are a Salesforce Lead Extractor running in SCHEMA MODE.\n' +
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
     '- Completely IGNORE and EXCLUDE any email signature, footer, or boilerplate when deriving fields or building the summary.\n' +
     '- Consider as signature/footer (to be ignored):\n' +
     '  - Blocks at the end of the message that contain the sender\'s name plus job title, company name, and contact details.\n' +
     '  - Lines that list roles or positions (for example, "Consultant", "Manager", "Director", "CRM Consultant | <Company>") together with phone, email, or address.\n' +
     '  - Standalone contact blocks with email addresses, phone numbers, websites, social links, or taglines at the very bottom.\n' +
     '  - Legal disclaimers, confidentiality notices, unsubscribe instructions, or marketing taglines at the bottom of the email.\n' +
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
     '- The FIRST character of the response MUST be "{", and the LAST character MUST be "}".\n' +
     '- Do NOT include any explanation, comments, or reasoning outside the JSON object.\n' +
     '- Do NOT include markdown, HTML, or code fences anywhere in the output.';
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

const DEFAULT_USER_PROMPT =
    'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
    'Always include the field "summary".\n' +
    'Follow system instructions strictly.\n' +
    'Return ONLY one flat JSON object.\n' +
    'Do NOT add extra fields.\n' +
    'Do NOT add Markdown or explanation text.\n' +
    'The first character must be "{" and the last must be "}".\n' +
    'Here is the email body:\n' +
    '{EMAIL_BODY}';

// default model (must match what you set in Apex)
const DEFAULT_MODEL = 'glm-4.5-air';

// default retry hours
const DEFAULT_RETRY_HOURS = 4;

export default class EmailtoleadAiConfig extends LightningElement {
    @track configId;
    @track loaded = false;

    // UI starts with defaults so the user sees them immediately
    @track systemPrompt = DEFAULT_SYSTEM_PROMPT;
    @track userPrompt = DEFAULT_USER_PROMPT;
    @track modelValue = DEFAULT_MODEL;
    @track retryHours = DEFAULT_RETRY_HOURS;

    // last saved values (for Reset)
    savedSystemPrompt = DEFAULT_SYSTEM_PROMPT;
    savedUserPrompt = DEFAULT_USER_PROMPT;

    // flags for toast behaviour
    isCreateMode = false;
    wasAutoCreated = false;
    hasSavedOnce = false;

    // 1) Try to load existing active config (read-only)
    @wire(getActiveConfig)
    wiredConfig({ data, error }) {
        if (data) {
            // Existing EmailToLead_Ai__AI_Configure__c
            this.configId = data.Id;

            this.savedSystemPrompt =
                data.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;
            this.savedUserPrompt =
                data.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

            this.systemPrompt = this.savedSystemPrompt;
            this.userPrompt = this.savedUserPrompt;
            this.modelValue =
                data.EmailToLead_Ai__Model__c || DEFAULT_MODEL;
            this.retryHours =
                data.EmailToLead_Ai__Scheduler_Retry_Hours__c || DEFAULT_RETRY_HOURS;

            this.wasAutoCreated = false;
            this.hasSavedOnce = true;
            this.loaded = true;
        } else if (error) {
            this.showToast(
                'Error',
                error.body ? error.body.message : error.message,
                'error'
            );
        } else if (!data && !this.configId && !this.loaded) {
            // No record exists - create one
            this.initDefaultConfig();
        }
    }

    initDefaultConfig() {
        createDefaultConfig()
            .then((cfg) => {
                // Newly created or returned active config
                this.configId = cfg.Id;

                this.savedSystemPrompt =
                    cfg.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;
                this.savedUserPrompt =
                    cfg.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

                this.systemPrompt = this.savedSystemPrompt;
                this.userPrompt = this.savedUserPrompt;
                this.modelValue =
                    cfg.EmailToLead_Ai__Model__c || DEFAULT_MODEL;
                this.retryHours =
                    cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c || DEFAULT_RETRY_HOURS;

                this.wasAutoCreated = true;   // created on first open
                this.hasSavedOnce = false;
                this.loaded = true;
            })
            .catch((error) => {
                this.showToast(
                    'Error',
                    error.body ? error.body.message : error.message,
                    'error'
                );
            });
    }

    // 3) Handlers for user edits
    handleSystemPromptChange(event) {
        this.systemPrompt = event.target.value;
    }

    handleUserPromptChange(event) {
        this.userPrompt = event.target.value;
    }

    handleModelChange(event) {
        this.modelValue = event.target.value;
    }

    handleRetryHoursChange(event) {
        this.retryHours = event.target.value;
    }

    // 4) Before save, inject textarea values into fields
    handleSubmit(event) {
        event.preventDefault();

        if (this.wasAutoCreated && !this.hasSavedOnce) {
            this.isCreateMode = true;
        } else {
            this.isCreateMode = false;
        }

        const fields = event.detail.fields;
        fields.EmailToLead_Ai__System_prompt__c = this.systemPrompt;
        fields.EmailToLead_Ai__User_Prompt__c = this.userPrompt;
        fields.EmailToLead_Ai__Scheduler_Retry_Hours__c = this.retryHours;
        // Model is already in fields via lightning-input-field,
        // but you can force it from JS if you want:
        // fields.EmailToLead_Ai__Model__c = this.modelValue;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    // 5) After save, sync local state and show toast
    handleSuccess(event) {
        if (!this.configId && event.detail && event.detail.id) {
            this.configId = event.detail.id;
        }

        this.savedSystemPrompt = this.systemPrompt;
        this.savedUserPrompt = this.userPrompt;

        const msg = this.isCreateMode
            ? 'AI configuration record created.'
            : 'AI configuration record updated.';

        this.wasAutoCreated = false;
        this.hasSavedOnce = true;
        this.isCreateMode = false;

        this.showToast('Success', msg, 'success');
    }

    // 6) Reset to last saved prompts
    handleReset() {
        this.systemPrompt =
            this.savedSystemPrompt || DEFAULT_SYSTEM_PROMPT;
        this.userPrompt =
            this.savedUserPrompt || DEFAULT_USER_PROMPT;

        this.showToast(
            'Reset',
            'Prompts reset to last saved values.',
            'info'
        );
    }

    // 7) Toast helper
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}*/

/*import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getActiveConfig from '@salesforce/apex/EmailToLeadAIConfigController.getActiveConfig';
import createDefaultConfig from '@salesforce/apex/EmailToLeadAIConfigController.createDefaultConfig';

import ensureActiveConfig from '@salesforce/apex/EmailToLeadAIConfigController.ensureActiveConfig';

/* ============================================================
   DEFAULT SYSTEM PROMPT
============================================================ */

/*const DEFAULT_SYSTEM_PROMPT =
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
    /*'- "Name" → FirstName / LastName\n' +*/
/*  '- "Name" → FirstName / LastName. If the name starts with a title prefix (Pastor, Dr., Rev., Father, Mr., Mrs., Ms., Prof.), extract the title prefix to the Title field.\n' +
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


/* ============================================================
 DEFAULT USER PROMPT
============================================================ */

/*const DEFAULT_USER_PROMPT =
    'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
    'Always include the field "summary".\n' +
    'Follow system instructions strictly.\n' +
    'Return ONLY one flat JSON object.\n' +
    'Do NOT add extra fields.\n' +
    'Do NOT add Markdown or explanation text.\n' +
    'The first character must be "{" and the last must be "}".\n' +
    'Here is the email body:\n' +
    '{EMAIL_BODY}';


/* ============================================================
   DEFAULT VALUES
============================================================ */

/*const DEFAULT_MODEL = 'Mistral';


/* ============================================================
   COMPONENT
============================================================ */

/*export default class EmailtoleadAiConfig extends LightningElement {

    /* ================= TRACKED ================= */

/*  @track configId;
  @track loaded = false;

  @track systemPrompt = DEFAULT_SYSTEM_PROMPT;
  @track userPrompt = DEFAULT_USER_PROMPT;
  @track modelValue = DEFAULT_MODEL;
  @track retryHours = DEFAULT_RETRY_HOURS;

  savedSystemPrompt = DEFAULT_SYSTEM_PROMPT;
  savedUserPrompt = DEFAULT_USER_PROMPT;

  isCreateMode = false;
  wasAutoCreated = false;
  hasSavedOnce = false;


  /* ============================================================
     MODEL OPTIONS FOR COMBOBOX
  ============================================================ */

/*  get modelOptions() {
      return [
          { label: 'Mistral', value: 'Mistral' },
          { label: 'ZAi', value: 'ZAi' }
      ];
  }


  /* ============================================================
     LOAD ACTIVE CONFIG
  ============================================================ */

/*  @wire(getActiveConfig)
  wiredConfig({ data, error }) {

      if (data) {

          this.configId = data.Id;

          this.savedSystemPrompt =
              data.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;

          this.savedUserPrompt =
              data.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

          this.systemPrompt = this.savedSystemPrompt;
          this.userPrompt = this.savedUserPrompt;

          this.modelValue =
              data.EmailToLead_Ai__Model__c || DEFAULT_MODEL;

          this.retryHours =
              data.EmailToLead_Ai__Scheduler_Retry_Hours__c || DEFAULT_RETRY_HOURS;

          this.wasAutoCreated = false;
          this.hasSavedOnce = true;
          this.loaded = true;

      } else if (error) {

          this.showToast(
              'Error',
              error.body ? error.body.message : error.message,
              'error'
          );

      } else if (!this.loaded && !this.configId) {

          this.initDefaultConfig();
      }
  }


  /* ============================================================
     CREATE DEFAULT CONFIG
  ============================================================ */

/*  initDefaultConfig() {

      ensureActiveConfig()

          .then(cfg => {

              this.configId = cfg.Id;

              this.savedSystemPrompt =
                  cfg.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;

              this.savedUserPrompt =
                  cfg.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

              this.systemPrompt = this.savedSystemPrompt;
              this.userPrompt = this.savedUserPrompt;

              this.modelValue =
                  cfg.EmailToLead_Ai__Model__c || DEFAULT_MODEL;

              this.retryHours =
                  cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c || DEFAULT_RETRY_HOURS;

              this.wasAutoCreated = true;
              this.hasSavedOnce = false;
              this.loaded = true;
          })

          .catch(error => {

              this.showToast(
                  'Error',
                  error.body ? error.body.message : error.message,
                  'error'
              );
          });
  }


  /* ============================================================
     INPUT HANDLERS
  ============================================================ */

/*   handleSystemPromptChange(event) {
       this.systemPrompt = event.target.value;
   }

   handleUserPromptChange(event) {
       this.userPrompt = event.target.value;
   }

   handleModelChange(event) {
       this.modelValue = event.target.value;
   }

   handleRetryHoursChange(event) {
       this.retryHours = parseInt(event.target.value, 10) || DEFAULT_RETRY_HOURS;
   }


   /* ============================================================
      SAVE HANDLER
   ============================================================ */

/*   handleSubmit(event) {

       event.preventDefault();

       this.isCreateMode =
           this.wasAutoCreated && !this.hasSavedOnce;

       const fields = event.detail.fields;

       // Manually add fields that use standalone components (not lightning-input-field)
       fields.EmailToLead_Ai__System_prompt__c = this.systemPrompt;
       fields.EmailToLead_Ai__User_Prompt__c = this.userPrompt;
       fields.EmailToLead_Ai__Model__c = this.modelValue;
       fields.EmailToLead_Ai__Scheduler_Retry_Hours__c = parseInt(this.retryHours, 10) || DEFAULT_RETRY_HOURS;

       console.log('Saving fields:', JSON.stringify(fields));  // Debug log

       this.template
           .querySelector('lightning-record-edit-form')
           .submit(fields);
   }


   /* ============================================================
      SUCCESS HANDLER
   ============================================================ */

/*  handleSuccess(event) {

      if (!this.configId && event.detail?.id) {
          this.configId = event.detail.id;
      }

      this.savedSystemPrompt = this.systemPrompt;
      this.savedUserPrompt = this.userPrompt;

      // isCreateMode is set in handleSubmit based on wasAutoCreated && !hasSavedOnce
      // First save after auto-creation shows "created", subsequent saves show "updated"
      const msg = this.isCreateMode
          ? 'AI configuration created.'
          : 'AI configuration updated.';

      this.wasAutoCreated = false;
      this.hasSavedOnce = true;
      this.isCreateMode = false;

      this.showToast('Success', msg, 'success');
  }


  /* ============================================================
     RESET HANDLER
  ============================================================ */

/*  handleReset() {

      this.systemPrompt = this.savedSystemPrompt;
      this.userPrompt = this.savedUserPrompt;

      this.showToast(
          'Reset',
          'Prompts restored to saved values.',
          'info'
      );
  }


  /* ============================================================
     TOAST
  ============================================================ */

/*   showToast(title, message, variant) {

       this.dispatchEvent(
           new ShowToastEvent({
               title,
               message,
               variant
           })
       );
   }

}*/
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getActiveConfig from '@salesforce/apex/EmailToLeadAIConfigController.getActiveConfig';
import ensureActiveConfig from '@salesforce/apex/EmailToLeadAIConfigController.ensureActiveConfig';

/* ============================================================
   DEFAULT SYSTEM PROMPT
============================================================ */

const DEFAULT_SYSTEM_PROMPT =
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


/* ============================================================
   DEFAULT USER PROMPT
============================================================ */

const DEFAULT_USER_PROMPT =
    'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}.\n' +
    'Always include "summary", "email_body", "email_header", "email_footer".\n' +
    'Follow system instructions strictly.\n' +
    'IMPORTANT: If you see multiple "INQ-" numbers or multiple distinct leads, create a SEPARATE lead object for EACH one in a "leads" array.\n' +
    'Do NOT add extra fields.\n' +
    'Do NOT add Markdown or explanation text.\n' +
    'The first character must be "{" and the last must be "}".\n' +
    'Here is the email body:\n' +
    '{EMAIL_BODY}';


/* ============================================================
   DEFAULT VALUES
============================================================ */

const DEFAULT_MODEL = 'Mistral';


/* ============================================================
   COMPONENT
============================================================ */

export default class EmailtoleadAiConfig extends LightningElement {

    /* ================= TRACKED ================= */

    @track configId;
    @track loaded = false;

    @track systemPrompt = DEFAULT_SYSTEM_PROMPT;
    @track userPrompt = DEFAULT_USER_PROMPT;
    @track modelValue = DEFAULT_MODEL;

    savedSystemPrompt;
    savedUserPrompt;

    wasAutoCreated = false;
    hasSavedOnce = false;
    isCreateMode = false;
    isCreating = false;


    /* ============================================================
       MODEL OPTIONS
    ============================================================ */

    get modelOptions() {
        return [
            { label: 'Gemini', value: 'Gemini' },
            { label: 'Mistral', value: 'Mistral' },
            { label: 'ZAi', value: 'ZAi' }
        ];
    }


    /* ============================================================
       LOAD ACTIVE CONFIG
    ============================================================ */

    @wire(getActiveConfig)
    wiredConfig({ data, error }) {

        if (data) {

            this.configId = data.Id;

            this.systemPrompt =
                data.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;

            this.userPrompt =
                data.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

            this.modelValue =
                data.EmailToLead_Ai__Model__c || DEFAULT_MODEL;

            this.savedSystemPrompt = this.systemPrompt;
            this.savedUserPrompt = this.userPrompt;

            this.wasAutoCreated = false;
            this.hasSavedOnce = true;
            this.loaded = true;

        } else if (error) {

            this.showToast(
                'Error',
                error.body?.message || error.message,
                'error'
            );

        } else if (!this.loaded && !this.configId && !this.isCreating) {

            this.initDefaultConfig();
        }
    }


    /* ============================================================
       CREATE DEFAULT CONFIG
    ============================================================ */

    initDefaultConfig() {

        this.isCreating = true;
        ensureActiveConfig()

            .then(cfg => {

                this.configId = cfg.Id;

                this.systemPrompt =
                    cfg.EmailToLead_Ai__System_prompt__c || DEFAULT_SYSTEM_PROMPT;

                this.userPrompt =
                    cfg.EmailToLead_Ai__User_Prompt__c || DEFAULT_USER_PROMPT;

                this.modelValue =
                    cfg.EmailToLead_Ai__Model__c || DEFAULT_MODEL;

                this.savedSystemPrompt = this.systemPrompt;
                this.savedUserPrompt = this.userPrompt;

                this.wasAutoCreated = true;
                this.hasSavedOnce = false;
                this.loaded = true;
            })

            .catch(err => {

                this.isCreating = false;
                this.showToast(
                    'Error',
                    err.body?.message || err.message,
                    'error'
                );
            });
    }


    /* ============================================================
       INPUT HANDLERS
    ============================================================ */

    handleSystemPromptChange(e) {
        this.systemPrompt = e.target.value;
    }

    handleUserPromptChange(e) {
        this.userPrompt = e.target.value;
    }

    handleModelChange(e) {
        this.modelValue = e.target.value;
    }


    /* ============================================================
       SAVE
    ============================================================ */

    handleSubmit(event) {

        event.preventDefault();

        this.isCreateMode =
            this.wasAutoCreated && !this.hasSavedOnce;

        const fields = event.detail.fields;

        fields.EmailToLead_Ai__System_prompt__c = this.systemPrompt;
        fields.EmailToLead_Ai__User_Prompt__c = this.userPrompt;
        fields.EmailToLead_Ai__Model__c = this.modelValue;

        this.template
            .querySelector('lightning-record-edit-form')
            .submit(fields);
    }


    /* ============================================================
       SUCCESS
    ============================================================ */

    handleSuccess(event) {

        if (!this.configId && event.detail?.id) {
            this.configId = event.detail.id;
        }

        this.savedSystemPrompt = this.systemPrompt;
        this.savedUserPrompt = this.userPrompt;

        this.showToast('Success', 'Record is Saved', 'success');

        this.wasAutoCreated = false;
        this.hasSavedOnce = true;
        this.isCreateMode = false;
    }


    /* ============================================================
       RESET
    ============================================================ */

    handleReset() {

        this.systemPrompt = this.savedSystemPrompt;
        this.userPrompt = this.savedUserPrompt;

        this.showToast(
            'Reset',
            'Prompts restored.',
            'info'
        );
    }


    /* ============================================================
       TOAST
    ============================================================ */

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}