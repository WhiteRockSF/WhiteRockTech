import { LightningElement, api, track, wire } from 'lwc';
import getCompanyIntents from '@salesforce/apex/BuyerIntentController.getCompanyIntents';

export default class BuyerIntentRecordDetail extends LightningElement {
    @api recordId;
    @api objectApiName;
    
    @track visitorData;
    @track isLoading = true;
    @track error;
    @track hasData = false;

    connectedCallback() {
        this.loadVisitorData();
    }

    loadVisitorData() {
        this.isLoading = true;
        getCompanyIntents()
            .then(result => {
                // Find matching company for this record
                const matchingCompany = result.find(company => 
                    company.salesforceId === this.recordId
                );
                
                if (matchingCompany) {
                    this.visitorData = matchingCompany;
                    this.hasData = true;
                } else {
                    this.hasData = false;
                }
                
                this.isLoading = false;
            })
            .catch(error => {
                this.error = error;
                this.isLoading = false;
                this.hasData = false;
            });
    }

    handleRefresh() {
        this.loadVisitorData();
    }

    get pageViewsLabel() {
        return `${this.visitorData.pageViews} Page Views`;
    }

    get uniqueVisitorsLabel() {
        return `${this.visitorData.uniqueVisitors} Unique Visitors`;
    }

    get lastVisitFormatted() {
        if (this.visitorData.lastVisit) {
            return new Date(this.visitorData.lastVisit).toLocaleString();
        }
        return 'N/A';
    }
}