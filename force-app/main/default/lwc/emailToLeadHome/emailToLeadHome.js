import { LightningElement, track } from 'lwc';

export default class EmailToLeadHome extends LightningElement {
    @track showField = true;
    @track showAi = false;

    get fieldVariant() { return this.showField ? 'brand' : 'neutral'; }
    get aiVariant() { return this.showAi ? 'brand' : 'neutral'; }

    showFieldSelector() { this.showField = true; this.showAi = false; }
    showAiConfig() { this.showField = false; this.showAi = true; }
}