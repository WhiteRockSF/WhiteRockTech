import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getRecords from '@salesforce/apex/caseEditorController.getRecords';
import save from '@salesforce/apex/caseEditorController.save';
 
export default class OpportunityEditor extends LightningElement {
    @api recordId;
    @track isSpinner = false;

    oppRecord;
    
    connectedCallback() {
        setTimeout(() => { this.init();},1000)
    }

    init() {
        getRecords({recId: this.recordId})
        .then(data => {
            console.log('data', data);
            this.oppRecord = data[0];
            const inputFields = this.template.querySelectorAll(
                'lightning-input-field'
            );
            if (inputFields) {
                inputFields.forEach(field => {
                    console.log( field.value , field.fieldName)
                    field.value = this.oppRecord[field.fieldName];
                });
            }
        })
        .catch(error => {
            console.log('error', error);
        })
    }

    handleSubmit(event){
        event.preventDefault(); // stop the form from submitting
        const fields = event.detail.fields;
        fields.Id = this.recordId;
        console.log('fields', fields);
        this.isSpinner = true;
        save({record : JSON.stringify(fields)})
        .then(data => {
            
            const event = new ShowToastEvent({
                title: 'Success',
                message: 'Operation Successful',
                variant: 'success',
                mode: 'dismissable'
            });
            this.dispatchEvent(event);
            this.isSpinner = false;
            window.location.reload();
            this.dispatchEvent(new CustomEvent('close'));
        }) .catch(error => {
            console.log('error', error);
            this.isSpinner = false;
        })

     }

     
}