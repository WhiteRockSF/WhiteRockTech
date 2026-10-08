import { LightningElement, api } from 'lwc';
import LOCALE from '@salesforce/i18n/locale';

export default class CustomFormattedTime extends LightningElement {
    @api number;
    formattedNumber = '';
    connectedCallback() {
        console.log(this.number);
        this.formattedNumber = new Intl.DateTimeFormat(LOCALE, { hour:"numeric", minute: "numeric", hour12: false}).format(this.number);
    }
    
}