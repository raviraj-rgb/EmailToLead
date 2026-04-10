import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import Response_Json from '@salesforce/schema/Custom_Exception__c.ResponseJSON__c';
import Request_Json from '@salesforce/schema/Custom_Exception__c.RequestJSON__c';

const fields = [Response_Json, Request_Json];
export default class jsonParsor extends LightningElement {
    @api recordId;
    log;

    // Safely parse JSON. Returns null if not valid JSON.
    safeParse(input) {
        if (typeof input !== 'string') {
            return null;
        }
        try {
            return JSON.parse(input);
        } catch (e) {
            return null;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: fields })
    wiredRecord({ error, data }) {
        if (data) {
            console.log(data);
            this.log = data;
            // These handlers are now safe and won't throw inside @wire
            this.handlePrettify();
            this.handlePrettifyReq();
        } else if (error) {
            // Handle error
            console.error('jsonParsor wire error:', error);
        }
    }

    handlePrettify() {
        const inputJsonField = getFieldValue(this.log, Response_Json);
        console.log(inputJsonField);
        if (!inputJsonField) {
            return;
        }

        const parsed = this.safeParse(inputJsonField);
        if (parsed !== null) {
            const prettify = JSON.stringify(parsed, null, 2);
            this.refs.outputArea.value = prettify;
        } else {
            // Not valid JSON: show raw text to avoid runtime exception
            this.refs.outputArea.value = inputJsonField;
        }
    }
    handlePrettifyReq() {
        const inputJsonField = getFieldValue(this.log, Request_Json);
        console.log(inputJsonField);
        if (!inputJsonField) {
            return;
        }

        const parsed = this.safeParse(inputJsonField);
        if (parsed !== null) {
            const prettify = JSON.stringify(parsed, null, 2);
            this.refs.inputArea.value = prettify;
        } else {
            // If request body is plain text, render it as-is
            this.refs.inputArea.value = inputJsonField;
        }
    }


    // handleFormat(){
    //     const inputJsonField = this.refs.inputArea.value;
    //     const formatted = JSON.stringify(JSON.parse(inputJsonField), null, 4);
    //     this.refs.outputArea.value = formatted;
    //     }

    //     handleMinify(){
    //         const inputJsonField = this.refs.inputArea.value;
    //         const minified = JSON.stringify(JSON.parse(inputJsonField));
    //         this.refs.outputArea.value = minified;
    //     }

    //     handlePrettify(){
    //         const inputJsonField = this.refs.inputArea.value;
    //         const prettify = JSON.stringify(JSON.parse(inputJsonField),null,2);
    //         this.refs.outputArea.value = prettify;
    //     }
}