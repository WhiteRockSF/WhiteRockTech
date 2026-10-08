import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
 
export default class CloseCase extends LightningElement {
    @api recordId;
    isShow = false;
    get inputVariables() {
        return [this.inputVariable];
    }

    connectedCallback() {
         
        setTimeout(() => {
            if (this.recordId) {
                this.inputVariable = {
                    name: 'recordId',
                    type: 'String',
                    value: this.recordId
                };
                this.isShow = true;
            }
        }, 1000);
 
    }

    handleStatusChange(event) {
        console.log('event.detail.status ', event.detail.status );
        if (event.detail.status === "FINISHED_SCREEN") {
            
            this.dispatchEvent(new CustomEvent('close'));
            window.location.reload();
        }
    }
}