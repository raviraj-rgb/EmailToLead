/*import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeadFieldsWithSelection
    from '@salesforce/apex/EmailLeadFieldConfigController.getLeadFieldsWithSelection';
import saveSelectedFields
    from '@salesforce/apex/EmailLeadFieldConfigController.saveSelectedFields';

export default class FieldSelectorUI extends LightningElement {

    // ------------------------------------------------------------
    // STATE
    // ------------------------------------------------------------
    @track fieldOptions = [];
    @track selectedValues = [];
    @track longTextFieldOptions = [];
    @track emailBodyField;
    @track summaryField;
    @track isSaving = false;
    @track saveStatusMessage = '';

    // ------------------------------------------------------------
    // Email-to-Lead Service Address
    // ------------------------------------------------------------
    emailServiceAddress =
        'emailtolead@2njru6jfn9d3ji7zbxwad81wnuiedryolcaj6yme4j9j5o0moo.3i-tza0eaa.usa544.apex.salesforce.com';

    // ------------------------------------------------------------
    // Polling control
    // ------------------------------------------------------------
    pollTimer;
    pollAttempts = 0;
    MAX_POLL_ATTEMPTS = 8;      // ~24 seconds total
    POLL_INTERVAL_MS = 3000;   // 3 seconds

    // ------------------------------------------------------------
    // UTILITIES
    // ------------------------------------------------------------

    // Remove managed-package namespace from API names
    normalizeApi(apiName) {
        if (!apiName) return apiName;
        return apiName.startsWith('emailtoleadai__')
            ? apiName.replace('emailtoleadai__', '')
            : apiName;
    }

    // Normalize CSV for reliable comparison
    normalizeCsv(values) {
        return (values || [])
            .map(v => v.trim().toLowerCase())
            .sort()
            .join(',');
    }

    // ------------------------------------------------------------
    // LIFECYCLE
    // ------------------------------------------------------------
    connectedCallback() {
        this.loadConfig();
    }

    // ------------------------------------------------------------
    // LOAD CMDT CONFIGURATION
    // ------------------------------------------------------------
    async loadConfig() {
        try {
            const data = await getLeadFieldsWithSelection();

            // All Lead fields
            this.fieldOptions = (data.allFields || []).map(f => ({
                label: f.label,
                value: this.normalizeApi(f.apiName)
            }));

            // Selected Lead fields
            this.selectedValues = (data.allFields || [])
                .filter(f => f.isSelected === true)
                .map(f => this.normalizeApi(f.apiName));

            // Long Text Area fields
            this.longTextFieldOptions = (data.longTextFields || []).map(f => ({
                label: f.label,
                value: this.normalizeApi(f.apiName)
            }));

            // Target fields
            this.emailBodyField = this.normalizeApi(data.emailBodyField);
            this.summaryField = this.normalizeApi(data.summaryField);

        } catch (error) {
            this.showToast(
                'Error',
                error?.body?.message || error.message,
                'error'
            );
        }
    }

    // ------------------------------------------------------------
    // UI HANDLERS
    // ------------------------------------------------------------
    handleChange(event) {
        this.selectedValues = event.detail.value;
    }

    handleEmailBodyFieldChange(event) {
        this.emailBodyField = event.detail.value;
    }

    handleSummaryFieldChange(event) {
        this.summaryField = event.detail.value;
    }

    // ------------------------------------------------------------
    // COPY EMAIL ADDRESS
    // ------------------------------------------------------------
    async handleCopyEmail() {
        try {
            if (navigator.clipboard && window.isSecureContext) {
                await navigator.clipboard.writeText(this.emailServiceAddress);
            } else {
                const textarea = document.createElement('textarea');
                textarea.value = this.emailServiceAddress;
                textarea.setAttribute('readonly', '');
                textarea.style.position = 'absolute';
                textarea.style.left = '-9999px';
                document.body.appendChild(textarea);
                textarea.select();
                document.execCommand('copy');
                document.body.removeChild(textarea);
            }

            this.showToast('Copied', 'Email address copied.', 'success');
        } catch (e) {
            this.showToast('Error', 'Unable to copy email address.', 'error');
        }
    }

    // ------------------------------------------------------------
    // SAVE + POLLING
    // ------------------------------------------------------------
    async handleSave() {
        this.isSaving = true;
        this.saveStatusMessage = 'Saving configuration…';

        const expectedCsv = this.normalizeCsv(this.selectedValues);

        try {
            await saveSelectedFields({
                fieldApiNames: this.selectedValues,
                emailBodyFieldApi: this.emailBodyField,
                summaryFieldApi: this.summaryField
            });

            // Start polling until CMDT reflects saved state
            this.pollAttempts = 0;
            this.saveStatusMessage = 'Applying configuration, please wait…';
            this.startPolling(expectedCsv);

        } catch (error) {
            this.isSaving = false;
            this.saveStatusMessage = '';
            this.showToast(
                'Error',
                error?.body?.message || error.message,
                'error'
            );
        }
    }

    startPolling(expectedCsv) {
        this.pollTimer = setInterval(async () => {
            this.pollAttempts++;

            this.saveStatusMessage =
                `Applying configuration… (${this.pollAttempts}/${this.MAX_POLL_ATTEMPTS})`;

            try {
                const data = await getLeadFieldsWithSelection();

                const actualSelected = (data.allFields || [])
                    .filter(f => f.isSelected)
                    .map(f => this.normalizeApi(f.apiName));

                const actualCsv = this.normalizeCsv(actualSelected);

                if (actualCsv === expectedCsv) {
                    this.stopPolling(true);
                    return;
                }

                if (this.pollAttempts >= this.MAX_POLL_ATTEMPTS) {
                    this.stopPolling(false);
                }

            } catch (e) {
                this.stopPolling(false);
            }

        }, this.POLL_INTERVAL_MS);
    }

    stopPolling(success) {
        clearInterval(this.pollTimer);
        this.isSaving = false;
        this.saveStatusMessage = '';

        if (success) {
            this.loadConfig();
            this.showToast(
                'Success',
                'Configuration applied successfully.',
                'success'
            );
        } else {
            this.showToast(
                'Warning',
                'Configuration saved, but may take a little longer to apply.',
                'warning'
            );
        }
    }

    // ------------------------------------------------------------
    // TOAST HELPER
    // ------------------------------------------------------------
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}*/

import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getLeadFieldsWithSelection from '@salesforce/apex/EmailLeadFieldConfigController.getLeadFieldsWithSelection';
import saveSelectedFields from '@salesforce/apex/EmailLeadFieldConfigController.saveSelectedFields';

export default class EmailLeadFieldSelector extends LightningElement {
    @track fieldOptions = [];
    @track selectedValues = [];
    @track isSaving = false;
    @track longTextFieldOptions = [];
    @track emailBodyField;
    @track summaryField;

    wiredResult; // ✅ store wire result to use refreshApex

    emailServiceAddress =
        'emailtolead@2njru6jfn9d3ji7zbxwad81wnuiedryolcaj6yme4j9j5o0moo.3i-tza0eaa.usa544.apex.salesforce.com';

    @wire(getLeadFieldsWithSelection)
    wiredFields(result) {
        this.wiredResult = result; // ✅ store full wire result

        const { error, data } = result;

        if (data) {
            // Add null safety for arrays
            const allFields = data.allFields || [];
            const longTextFields = data.longTextFields || [];

            this.fieldOptions = allFields.map(f => ({
                label: f.label,
                value: f.apiName
            }));

            this.selectedValues = allFields
                .filter(f => f.isSelected)
                .map(f => f.apiName);

            this.longTextFieldOptions = longTextFields.map(f => ({
                label: f.label,
                value: f.apiName
            }));

            this.emailBodyField = data.emailBodyField || '';
            this.summaryField = data.summaryField || '';
        } else if (error) {
            console.error('Error loading field configuration:', error);
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    handleEmailBodyFieldChange(event) {
        this.emailBodyField = event.detail.value;
    }

    handleSummaryFieldChange(event) {
        this.summaryField = event.detail.value;
    }

    handleChange(event) {
        this.selectedValues = event.detail.value;
    }

    // Copy email to clipboard
    async handleCopyEmail() {
        try {
            if (navigator.clipboard && window.isSecureContext) {
                await navigator.clipboard.writeText(this.emailServiceAddress);
            } else {
                const textarea = document.createElement('textarea');
                textarea.value = this.emailServiceAddress;
                textarea.setAttribute('readonly', '');
                textarea.style.position = 'absolute';
                textarea.style.left = '-9999px';
                document.body.appendChild(textarea);
                textarea.select();
                document.execCommand('copy');
                document.body.removeChild(textarea);
            }

            this.showToast('Copied', 'Email address copied to clipboard.', 'success');
        } catch (e) {
            this.showToast('Error', 'Unable to copy email address.', 'error');
        }
    }

    handleSave() {
        // Final validation before save
        if (this.emailBodyField && this.summaryField &&
            this.emailBodyField === this.summaryField) {
            this.showToast(
                'Validation Error',
                'Email Body Field and Summary Field cannot be the same. Please select different fields.',
                'error'
            );
            return;
        }

        this.isSaving = true;

        saveSelectedFields({
            fieldApiNames: this.selectedValues,
            emailBodyFieldApi: this.emailBodyField,
            summaryFieldApi: this.summaryField
        })
            .then(() => {
                this.showToast(
                    'Success',
                    'Configuration saved. New emails will use these fields and text-area targets.',
                    'success'
                );

                // ✅ refresh wire data so UI stays consistent after save / tab change
                return refreshApex(this.wiredResult);
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}