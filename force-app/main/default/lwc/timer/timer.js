import { LightningElement, track } from 'lwc';
import saveCardsLwc from '@salesforce/apex/TimerController.saveCardsLwc';
import getCards from '@salesforce/apex/TimerController.getCards';
import deleteCards from '@salesforce/apex/TimerController.deleteCards';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Timer extends LightningElement {
    
    @track isEdited = false;
    @track toggleSaveLabel = 'Save';
    @track myList = [];
    isSpinner = false;
    startDate='';
    endDate='';
    isShow = false;
    @track totalOfPer = 0;
    /*--------------------Mapping field values to the list onchange START --------------------*/                
    handleNameChange(event) {
        // console.log(event.target.dataset.id);
        // console.log(event.target.dataset.key);
        // console.log(event.target.value);
        let element = this.myList.find(ele  =>  event.target.dataset.id  !== undefined? ele.Id === event.target.dataset.id :  ele.key === event.target.dataset.key);
        element[event.target.name] = event.target.value;
        this.myList = [...this.myList];
        // console.log(JSON.stringify(this.myList));
    }


    handleChange(event) { 
        
        if (event.target.name === 'startDate') {
            this.startDate = event.target.value; 
        }

        if (event.target.name === 'endDate') {
            this.endDate = event.target.value; 
        }

        this.run();
        
    }

    run() {
        this.getCardRecords();
    }

    handleSelection1(event) {
        let eventData = event.detail;
        let id = event.detail.selectedId;
        let uniqueKey = event.target.dataset.key;       
        console.log('id' , id);
        console.log('event.target.dataset.key' , event.target.dataset.key);
        console.log('this.myList' , JSON.parse(JSON.stringify(this.myList)));
        let element = this.myList.find(ele => ele.key === uniqueKey);
        console.log('this' , JSON.parse(JSON.stringify(element)));
        console.log('handleSelection1 element' , event.target.dataset.key);
            element.TaskRay_Task__c = id; 
        
        this.myList = [...this.myList];
        console.log('this.myList' , JSON.parse(JSON.stringify(this.myList)));
    }

    handleSelection2(event) {
        let eventData = event.detail;
        let id = event.detail.selectedId;
        let uniqueKey = event.target.dataset.key;
       
        console.log('id' , id);
        // console.log('uniqueKey' , JSON.stringify(eventData));
        let element = this.myList.find(ele  => ele.key === uniqueKey);
      
            element.Service__c = id; 
        
       
        this.myList = [...this.myList];
    }

    handleSelection3(event) {
        let eventData = event.detail;
        let id = event.detail.selectedId;
        let uniqueKey = event.target.dataset.key;
       
        console.log('id' , id);
        console.log('event.target.dataset.key' , event.target.dataset.key);
        console.log('this.myList' , JSON.parse(JSON.stringify(this.myList)));
        let element = this.myList.find(ele => ele.key === uniqueKey);
        console.log('this' , JSON.parse(JSON.stringify(this.myList.find(ele => ele.key === uniqueKey))));
        console.log('handleSelection3 element' , event.target.dataset.key);
        // console.log('handleSelection3 uniqueKey' , unliqueKey);
        element.Production__c = id; 
        
         console.log('hanelement' , element);
        this.myList = [...this.myList];

        console.log('this.myList' , JSON.parse(JSON.stringify(this.myList)));
    }
    
    /*--------------------Mapping field values to the list onchange END --------------------*/    

    add() {
        let date = new Date();  
        let firstMonth = date.getMonth() + 1 < 10 ? `0${date.getMonth() + 1}` : date.getMonth() + 1;
        let firstDay = date.getDate() < 10 ? `0${date.getDate()}` : date.getDate();
    
        let tDate =`${date.getFullYear()}-${firstMonth}-${firstDay}`; 

        let newList = this.myList;
        newList.push({Production__c : "", TaskRay_Task__c : "",Service__c : "", key : (Math.random().toString(36).substring(2, 15)),
        Date_of_Service__c: tDate , Start_Time__c: '00:00:00.000', End_Time__c: '00:00:00.000',Service_Notes__c: ''});
        this.myList = newList;
        // console.log('add', JSON.stringify( this.myList) );
    }

    remove(event) { 
        let indexPosition = event.currentTarget.name;
        const recId = event.currentTarget.dataset.id;
        // console.log('recId ' , recId);       
        // console.log('indexPosition ' , indexPosition); 
             
        deleteCards({toDeleteId : recId})
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title : 'Success',
                    message : `Record deleted succesfully!`,
                    variant : 'success',
                }),
            )
           
            this.error = undefined;
        })
        .catch(error => {
            this.error = error;
        })

        if(this.myList.length > 1) 
        this.myList.splice(indexPosition, 1);
    }

    validation() {
        try {
        const allValid = [
            ...this.template.querySelectorAll('lightning-input')
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        const allValidText = [
            ...this.template.querySelectorAll('lightning-textarea')
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        let isBlank = false; 




        // console.log('this.myList ', JSON.stringify(this.myList))
        this.myList.forEach((element, index) => {
              console.log('element.Production__c', element.Production__c)
              console.log('element.Service__c', element.Service__c)
            if (element.Production__c === undefined || element.Production__c === '') {
                let target = this.template.querySelector(`[data-prod="${element.key}"]`);
                // console.log('target.classList', target.classList)
                target.classList.add('req');
                isBlank = true;
            } else {
                // console.log('element.Production__c');
                // let target = this.template.querySelector(`[data-prod="${element.key}"]`);
                // target.classList.remove('req');
            }

            if (element.Service__c === undefined || element.Service__c === '') {
               
                let target = this.template.querySelector(`[data-service="${element.key}"]`);
                // console.log('target.classList', target.classList)
                target.classList.add('req');
                
                isBlank = true;
            }
            else {
                // console.log('element.service');
                // let target = this.template.querySelector(`[data-service="${element.key}"]`);
                // target.classList.remove('req');
            }

            
            // if (element.TaskRay_Task__c === undefined || element.TaskRay_Task__c === '') {
               
            //     let target = this.template.querySelector(`[data-task="${element.key}"]`);
            //     // console.log('target.classList', target.classList)
            //     target.classList.add('req');
                
            //     isBlank = true;
            // }
            // else {
            //     // console.log('element.service');
            //     // let target = this.template.querySelector(`[data-service="${element.key}"]`);
            //     // target.classList.remove('req');
            // }
            
            
          
            
        });
        
 
        if (!allValid || !allValidText || isBlank) {
            return false;
        }

        return true;
        } catch (e) {
           
            console.log(e);
             return false;
        }
      
    }

    handleSave() {
        this.isSpinner = false;
        console.log('this.validation() ', this.validation());
        if (!this.validation()) { this.isSpinner = false; return; }
        this.toggleSaveLabel = 'Saving...'
        let toSaveList = this.myList;
        toSaveList.forEach((element, index) => {
            if(element.Name === ''){
                toSaveList.splice(index, 1);
            }
        });

        console.log('handleSave toSaveList', JSON.parse(JSON.stringify(toSaveList)));


        this.myList = toSaveList;
        // console.log('toSaveList ', toSaveList);
        saveCardsLwc({records : toSaveList})
        .then((data) => {

            // console.log('saveCardsLwc ', data);

            if (data.status === 'Success') {
                this.toggleSaveLabel = 'Saved';
            
                this.dispatchEvent(
                    new ShowToastEvent({
                        title : 'Success',
                        message : `Records saved succesfully!`,
                        variant : 'success',
                    })
                )
               
                this.isEdited = false;
                this.error = undefined;

                this.getCardRecords();

            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title : 'Error',
                        message : data.message,
                        variant : 'Error',
                    })
                );
               
            }
            
            this.isSpinner = false;
            
        })
        .catch(error => {
            this.error = error;
            this.record = undefined;
            console.log("Error in Save call back:", this.error);
            this.isSpinner = false;
        })
        .finally(() => {
            setTimeout(() => {
                this.toggleSaveLabel = 'Save';
            }, 3000);
            this.isSpinner = false;
        });
    }

    connectedCallback() {
        let date = new Date();  
        let firstday  = new Date(date.getFullYear(), date.getMonth(), 1);
        let lastDay  = new Date(date.getFullYear(), date.getMonth() + 1, 0);
        // console.log(firstday   + ' ' +  lastDay  );
        let firstMonth = firstday.getMonth() + 1 < 10 ? `0${firstday.getMonth() + 1}` : firstday.getMonth() + 1;
        let firstDay = firstday.getDate() < 10 ? `0${firstday.getDate()}` : firstday.getDate();
        let endMonth = lastDay.getMonth() + 1 < 10 ? `0${lastDay.getMonth() + 1}` : lastDay.getMonth() + 1;
        let endDay = lastDay.getDate() < 10 ? `0${lastDay.getDate()}` : lastDay.getDate();

        this.startDate =`${firstday.getFullYear()}-${firstMonth}-${firstDay}`; 
        this.endDate = `${lastDay.getFullYear()}-${endMonth}-${endDay}`;  
        // console.log(this.startDate  + ' ' +  this.endDate );
        this.isShow = true;
        this.getCardRecords();
    }

    getCardRecords() {
        this.totalOfPer = 0;
        // console.log('getCardRecords ' + this.startDate, this.endDate);
        getCards({sDt:this.startDate, eDt:this.endDate})
            .then(result => {
                this.record = result;
                for(let i = 0; i < this.record.length; i++) {
                    if(this.record[i].Production__c) {
                        this.record[i].ProductionName = this.record[i].Production__r.Name;
                        this.record[i].ProductionUrl = `/${this.record[i].Production__c}`;
                    }

                    if(this.record[i].TaskRay_Task__c) {
                        const taskName = this.record[i].TaskRay_Task__r.Name;
                        const projectName = this.record[i].TaskRay_Task__r.TASKRAY__Project__r?.Name;
                        this.record[i].TaskName = projectName ? `${taskName} · ${projectName}` : taskName;
                        this.record[i].TaskUrl = `/${this.record[i].TaskRay_Task__c}`;
                    }

                    if(this.record[i].Service__c) {
                        this.record[i].ServiceName = this.record[i].Service__r.Name;
                        this.record[i].ServiceUrl = `/${this.record[i].Service__c}`;
                    }

                    if(this.record[i].Id) {
                        this.record[i].recordUrl = `/${this.record[i].Id}`;
                    }

                    if(this.record[i].Id) {
                        this.record[i].recordUrl = `/${this.record[i].Id}`;
                    }
               
                    if(this.record[i].Start_Time__c) {
                        this.record[i].Start_Time__c = this.convertTime(this.record[i].Start_Time__c);
                    } else {
                        this.record[i].Start_Time__c = '00:00:00.000';
                    }
                         
                    if(this.record[i].End_Time__c) {
                        this.record[i].End_Time__c = this.convertTime(this.record[i].End_Time__c);
                    }

                    this.record[i].key = (Math.random().toString(36).substring(2, 15));
                    this.totalOfPer += +this.record[i].Ticket_Time__c;
                }
                this.myList = this.record;
                // console.log('this.myList ', JSON.parse(JSON.stringify(this.myList)));
                this.error = undefined;
                this.isSpinner = false;
            })
            .catch(error => {
                // console.log('getCardRecords error' + JSON.stringify(error));
                this.error = error;
                this.isSpinner = false;
                this.record = undefined;
            });
    }

    convertTime(seconds) {
        console.log('seconds ', seconds);
        if (seconds === 0) {
            return '08:00:00.000'; 
        }

        let date = new Date(seconds);
        let hh = date.getUTCHours();
        let mm = date.getUTCMinutes();
        let ss = date.getSeconds();
        // If you were building a timestamp instead of a duration, you would uncomment the following line to get 12-hour (not 24) time
        // if (hh > 12) {hh = hh % 12;}
        // These lines ensure you have two-digits
        if (hh < 10) {hh = "0"+hh;}
        if (mm < 10) {mm = "0"+mm;}
        if (ss < 10) {ss = "0"+ss;}

        console.log(seconds);
        // This formats your string to HH:MM:SS
        return hh+':'+mm+':'+ss+'.000'; 
    }
    onDoubleClickEdit() {
        this.isEdited = true;
    }

    handleCancel() {
        this.isEdited = false;
    }
}