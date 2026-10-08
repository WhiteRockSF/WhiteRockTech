import { LightningElement , api } from 'lwc';
import getEvents from '@salesforce/apex/EngagementReportController.getEvents';

export default class EngagementReport extends LightningElement {
    @api recordId;

    events = [];
    
    columns = [
        { label: 'Event Date', fieldName: 'Event_Date__c', type: 'date'  },
        { label: 'Resource', fieldName: 'Resource__c'  },
        { label: 'URL', fieldName: 'URL__c', type: 'url' },
        { label: 'Type', fieldName: 'Type__c' },
    ];

    connectedCallback() {
        getEvents({recId: this.recordId})
        .then(data => {
            this.events = [];
            this.events = data;
        }) 
        .catch(error => {

        }) 
    }
}