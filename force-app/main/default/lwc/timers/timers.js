import { LightningElement, track, wire } from 'lwc';
import saveCardsLwc from '@salesforce/apex/TimerController.saveCardsLwc';
import getCards from '@salesforce/apex/TimerController.getCards';
import deleteCards from '@salesforce/apex/TimerController.deleteCards';
import getTaskRayMonthSummary from '@salesforce/apex/TimerController.getTaskRayMonthSummary';
import getTaskRayChatterActivity from '@salesforce/apex/TimerController.getTaskRayChatterActivity';
import getMyTaskRayMentions from '@salesforce/apex/TimerController.getMyTaskRayMentions';
import getTaskRayStatusFillEvents from '@salesforce/apex/TimerController.getTaskRayStatusFillEvents';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_LAST_NAME from '@salesforce/schema/User.LastName';

export default class Timer extends LightningElement {
    
    @track isEdited = false;
    @track toggleSaveLabel = 'Save';
    @track myList = [];
    @track newCard = {};
    @track calendarDays = [];
    @track currentMonth = '';
    @track currentYear = '';
    isSpinner = false;
    startDate='';
    endDate='';
    isShow = false;
    @track totalOfPer = 0;
    @track periodTotalHours = 0;
    @track remainingTo8hMonth = 0;
    @track maxCanTrackMonth = 0;
    @track taskRayTrackedHours = 0;
    @track taskRayRemainingHours = 0;
    @track fillPlan = [];
    @track fillPlanTotal = 0;
    @track chatterActivity = [];
    @track chatterMentionsCount = 0;
    @track statusFillEvents = [];
    selectedDate = null;
    currentMonthDate = new Date();
    userLastName = '';
    taskRayTasks = [];

    get canDownloadCsv() {
        return (this.userLastName || '').toLowerCase() === 'kotovich';
    }

    @wire(getRecord, { recordId: USER_ID, fields: [USER_LAST_NAME] })
    wiredUser({ data }) {
        if (data) {
            this.userLastName = getFieldValue(data, USER_LAST_NAME) || '';
        }
    }
    
    get monthlyWorkingHours() {
        // Calculate working days in current month (excluding weekends)
        const year = this.currentYear;
        const month = this.currentMonth;
        
        // Get month index from month name
        const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                           'July', 'August', 'September', 'October', 'November', 'December'];
        const monthIndex = monthNames.indexOf(month);
        
        if (monthIndex === -1) return 0;
        
        // Get first and last day of month
        const firstDay = new Date(year, monthIndex, 1);
        const lastDay = new Date(year, monthIndex + 1, 0);
        
        let workingDays = 0;
        
        // Count working days (Monday to Friday)
        for (let day = new Date(firstDay); day <= lastDay; day.setDate(day.getDate() + 1)) {
            const dayOfWeek = day.getDay();
            // 0 = Sunday, 6 = Saturday
            if (dayOfWeek !== 0 && dayOfWeek !== 6) {
                workingDays++;
            }
        }
        
        // 8 hours per working day
        return workingDays * 8;
    }
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
        // Initialize new card with today's date
        const today = new Date();  
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');
        const tDate = `${year}-${month}-${day}`; 

        this.newCard = {
            Production__c: '',
            TaskRay_Task__c: '',
            Service__c: '',
            Date_of_Service__c: tDate,
            Start_Time__c: '08:00:00.000',
            End_Time__c: '17:00:00.000',
            Service_Notes__c: '',
            key: (Math.random().toString(36).substring(2, 15))
        };

        // Open the modal
        this.openModal();
    }

    openModal() {
        const modal = this.template.querySelector('c-modal');
        if (modal) {
            modal.open();
        }
    }

    handleModalClose() {
        const modal = this.template.querySelector('c-modal');
        if (modal) {
            modal.close();
        }
        // Reset the form
        this.newCard = {};
    }

    handleNewCardChange(event) {
        const field = event.target.name;
        const value = event.target.value;
        // Create new object to trigger LWC reactivity
        this.newCard = { ...this.newCard, [field]: value };
    }

    handleNewCardSelection(event) {
        console.log('handleNewCardSelection called');
        console.log('event.detail:', JSON.stringify(event.detail));
        
        const key = event.detail.key;
        const selectedId = event.detail.selectedId;
        
        console.log('key:', key);
        console.log('selectedId:', selectedId);
        
        // Map uniqueKey to field name
        const keyToFieldMap = {
            'newCard': 'Production__c',
            'newCardTask': 'TaskRay_Task__c',
            'newCardService': 'Service__c'
        };
        
        const field = keyToFieldMap[key];
        console.log('field:', field);
        
        if (field) {
            // Create new object to trigger LWC reactivity
            this.newCard = { ...this.newCard, [field]: selectedId };
            console.log('newCard after update:', JSON.stringify(this.newCard));
        } else {
            console.log('WARNING: field not found for key:', key);
        }
    }

    convertHoursToTimes(hours) {
        // Start time is always 8:00 AM
        const startHour = 8;
        const startMinute = 0;
        
        // Calculate end time by adding hours
        const totalMinutes = hours * 60;
        let endTotalMinutes = (startHour * 60) + startMinute + totalMinutes;
        
        const endHour = Math.floor(endTotalMinutes / 60);
        const endMinute = Math.floor(endTotalMinutes % 60);
        
        // Format as HH:MM:SS.mmm for Salesforce Time field
        const startTime = `${String(startHour).padStart(2, '0')}:${String(startMinute).padStart(2, '0')}:00.000`;
        const endTime = `${String(endHour).padStart(2, '0')}:${String(endMinute).padStart(2, '0')}:00.000`;
        
        return { startTime, endTime };
    }

    handleAddNewCard() {
        // Validate required fields
        if (!this.newCard.Production__c || !this.newCard.Service__c) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please fill in all required fields (Production and Service are required)',
                    variant: 'error',
                })
            );
            return;
        }

        // Validate all input fields in the modal
        const allValid = [...this.template.querySelectorAll('c-modal lightning-input, c-modal lightning-textarea')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (!allValid) {
            return;
        }

        // Convert hours to start/end times
        if (this.newCard.Hours__c) {
            const times = this.convertHoursToTimes(parseFloat(this.newCard.Hours__c));
            this.newCard.Start_Time__c = times.startTime;
            this.newCard.End_Time__c = times.endTime;
        }

        this.isSpinner = true;
        const isEditing = this.newCard.isEditing;

        // Check if editing existing card or adding new one
        if (isEditing) {
            // Update existing card
            const index = this.myList.findIndex(card => 
                (this.newCard.Id && card.Id === this.newCard.Id) || 
                (this.newCard.key && card.key === this.newCard.key)
            );
            
            if (index !== -1) {
                // Preserve existing properties and update with new values
                this.myList[index] = {
                    ...this.myList[index],
                    Production__c: this.newCard.Production__c,
                    TaskRay_Task__c: this.newCard.TaskRay_Task__c,
                    Service__c: this.newCard.Service__c,
                    Date_of_Service__c: this.newCard.Date_of_Service__c,
                    Start_Time__c: this.newCard.Start_Time__c,
                    End_Time__c: this.newCard.End_Time__c,
                    Service_Notes__c: this.newCard.Service_Notes__c
                };
            }
        } else {
            // Add new card to the list
            const newCardData = { ...this.newCard };
            delete newCardData.isEditing;
            delete newCardData.Hours__c; // Remove hours field, only save start/end times
            this.myList = [...this.myList, newCardData];
        }

        // Save to database immediately
        this.saveToDatabase(isEditing);
    }

    saveToDatabase(isEditing) {
        let toSaveList = [...this.myList];

        saveCardsLwc({records : toSaveList})
        .then((data) => {
            if (data.status === 'Success') {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title : 'Success',
                        message : isEditing ? 'Time card updated successfully!' : 'Time card added successfully!',
                        variant : 'success',
                    })
                );
               
                // Refresh data from server
                this.getCardRecords();

                // Close modal
                this.handleModalClose();

            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title : 'Error',
                        message : data.message,
                        variant : 'error',
                    })
                );
            }
            
            this.isSpinner = false;
            
        })
        .catch(error => {
            this.error = error;
            console.log("Error in Save call back:", error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title : 'Error',
                    message : 'Failed to save time card: ' + (error.body?.message || error.message),
                    variant : 'error',
                })
            );
            this.isSpinner = false;
        });
    }

    handleDayClick(event) {
        const dateStr = event.currentTarget.dataset.date;
        if (dateStr) {
            this.selectedDate = dateStr;
            this.newCard = {
                Production__c: '',
                TaskRay_Task__c: '',
                Service__c: '',
                Date_of_Service__c: dateStr,
                Start_Time__c: '08:00:00.000',
                End_Time__c: '17:00:00.000',
                Service_Notes__c: '',
                key: (Math.random().toString(36).substring(2, 15))
            };
            this.openModal();
        }
    }

    handleCardClick(event) {
        event.stopPropagation();
        const cardId = event.currentTarget.dataset.cardId;
        const cardKey = event.currentTarget.dataset.cardKey;
        
        // Find the card in myList
        const cardToEdit = this.myList.find(card => 
            (cardId && card.Id === cardId) || (cardKey && card.key === cardKey)
        );
        
        if (cardToEdit) {
            // Calculate hours from start/end times for display
            const hours = cardToEdit.Start_Time__c && cardToEdit.End_Time__c ? 
                this.calculateHours(cardToEdit.Start_Time__c, cardToEdit.End_Time__c) : '';
            
            // Open modal with card data for editing
            this.newCard = {
                Id: cardToEdit.Id,
                Production__c: cardToEdit.Production__c,
                TaskRay_Task__c: cardToEdit.TaskRay_Task__c,
                Service__c: cardToEdit.Service__c,
                Date_of_Service__c: cardToEdit.Date_of_Service__c,
                Start_Time__c: cardToEdit.Start_Time__c,
                End_Time__c: cardToEdit.End_Time__c,
                Service_Notes__c: cardToEdit.Service_Notes__c,
                Hours__c: hours,
                key: cardToEdit.key,
                isEditing: true
            };
            this.openModal();
        }
    }

    handleDeleteCard(event) {
        event.stopPropagation();
        const cardId = event.currentTarget.dataset.cardId;
        const cardKey = event.currentTarget.dataset.cardKey;
        
        // Confirm deletion
        if (!confirm('Are you sure you want to delete this time card?')) {
            return;
        }

        this.isSpinner = true;

        // If card has an Id, delete from database
        if (cardId) {
            deleteCards({toDeleteId: cardId})
            .then(() => {
                // Remove from local list
                this.myList = this.myList.filter(card => card.Id !== cardId && card.key !== cardKey);
                
                // Refresh calendar
                this.assignCardsToCalendar();
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Time card deleted successfully!',
                        variant: 'success',
                    })
                );
                
                this.isSpinner = false;
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to delete time card: ' + (error.body?.message || error.message),
                        variant: 'error',
                    })
                );
                this.isSpinner = false;
            });
        } else {
            // Just remove from local list if no Id (unsaved card)
            this.myList = this.myList.filter(card => card.key !== cardKey);
            this.assignCardsToCalendar();
            this.isSpinner = false;
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Time card removed!',
                    variant: 'success',
                })
            );
        }
    }

    handleDeleteCardFromModal() {
        const cardId = this.newCard.Id;
        const cardKey = this.newCard.key;
        
        // Confirm deletion
        if (!confirm('Are you sure you want to delete this time card?')) {
            return;
        }

        this.isSpinner = true;

        // If card has an Id, delete from database
        if (cardId) {
            deleteCards({toDeleteId: cardId})
            .then(() => {
                // Remove from local list
                this.myList = this.myList.filter(card => card.Id !== cardId && card.key !== cardKey);
                
                // Refresh calendar
                this.assignCardsToCalendar();
                
                // Close modal
                this.handleModalClose();
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Time card deleted successfully!',
                        variant: 'success',
                    })
                );
                
                this.isSpinner = false;
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to delete time card: ' + (error.body?.message || error.message),
                        variant: 'error',
                    })
                );
                this.isSpinner = false;
            });
        } else {
            // Just remove from local list if no Id (unsaved card)
            this.myList = this.myList.filter(card => card.key !== cardKey);
            this.assignCardsToCalendar();
            this.handleModalClose();
            this.isSpinner = false;
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Time card removed!',
                    variant: 'success',
                })
            );
        }
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
        this.currentMonthDate = new Date();
        this.updateCalendarDates();
        this.getCardRecords();
    }

    updateCalendarDates() {
        const date = this.currentMonthDate;
        const firstday = new Date(date.getFullYear(), date.getMonth(), 1);
        const lastDay = new Date(date.getFullYear(), date.getMonth() + 1, 0);
        
        const firstMonth = firstday.getMonth() + 1 < 10 ? `0${firstday.getMonth() + 1}` : firstday.getMonth() + 1;
        const firstDayNum = firstday.getDate() < 10 ? `0${firstday.getDate()}` : firstday.getDate();
        const endMonth = lastDay.getMonth() + 1 < 10 ? `0${lastDay.getMonth() + 1}` : lastDay.getMonth() + 1;
        const endDay = lastDay.getDate() < 10 ? `0${lastDay.getDate()}` : lastDay.getDate();

        this.startDate = `${firstday.getFullYear()}-${firstMonth}-${firstDayNum}`; 
        this.endDate = `${lastDay.getFullYear()}-${endMonth}-${endDay}`;
        
        // Update month/year display
        const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'];
        this.currentMonth = monthNames[date.getMonth()];
        this.currentYear = date.getFullYear();
        
        this.isShow = true;
        this.buildCalendar();
    }

    buildCalendar() {
        const year = this.currentMonthDate.getFullYear();
        const month = this.currentMonthDate.getMonth();
        
        // Get first day of month and last day
        const firstDay = new Date(year, month, 1);
        const lastDay = new Date(year, month + 1, 0);
        const daysInMonth = lastDay.getDate();
        
        // Get day of week for first day (0 = Sunday)
        const startingDayOfWeek = firstDay.getDay();
        
        // Build calendar array
        const calendar = [];
        let week = [];
        
        // Add empty cells for days before month starts
        for (let i = 0; i < startingDayOfWeek; i++) {
            week.push({ isEmpty: true, key: `empty-${i}` });
        }
        
        // Add days of the month
        for (let day = 1; day <= daysInMonth; day++) {
            const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            const isToday = this.isToday(year, month, day);
            
            week.push({
                day: day,
                dateStr: dateStr,
                isToday: isToday,
                isEmpty: false,
                cards: [],
                key: `day-${day}`
            });
            
            // Start new week on Sunday
            if (week.length === 7) {
                calendar.push({ days: week, key: `week-${calendar.length}` });
                week = [];
            }
        }
        
        // Fill remaining days in last week
        while (week.length > 0 && week.length < 7) {
            week.push({ isEmpty: true, key: `empty-end-${week.length}` });
        }
        
        if (week.length > 0) {
            calendar.push({ days: week, key: `week-${calendar.length}` });
        }
        
        this.calendarDays = calendar;
        this.assignCardsToCalendar();
    }

    assignCardsToCalendar() {
        // Group cards by date
        const cardsByDate = {};
        this.periodTotalHours = 0;
        this.myList.forEach(card => {
            if (card.Date_of_Service__c) {
                const dateKey = card.Date_of_Service__c.split('T')[0]; // Handle datetime format
                if (!cardsByDate[dateKey]) {
                    cardsByDate[dateKey] = [];
                }
                // Format times for display and calculate hours
                const totalHours = parseFloat(this.calculateHours(card.Start_Time__c, card.End_Time__c) || 0);
                this.periodTotalHours += totalHours;
                const cardWithFormattedTime = {
                    ...card,
                    displayStartTime: this.formatTimeForDisplay(card.Start_Time__c),
                    displayEndTime: this.formatTimeForDisplay(card.End_Time__c),
                    totalHours: totalHours.toFixed(2),
                    displayNotes: this.stripHtmlTags(card.Service_Notes__c)
                };
                cardsByDate[dateKey].push(cardWithFormattedTime);
            }
        });
        
        // Assign cards to calendar days
        this.calendarDays = this.calendarDays.map(week => {
            return {
                ...week,
                days: week.days.map(day => {
                    if (!day.isEmpty && day.dateStr) {
                        const dayCards = cardsByDate[day.dateStr] || [];
                        // Calculate total hours for the day
                        const totalHours = dayCards.reduce((sum, card) => {
                            return sum + parseFloat(card.totalHours || 0);
                        }, 0);

                        const dayOfWeek = new Date(`${day.dateStr}T00:00:00`).getDay();
                        const isWeekday = dayOfWeek !== 0 && dayOfWeek !== 6;
                        const remainingTo8 = isWeekday ? Math.max(0, 8 - totalHours) : 0;
                        
                        return {
                            ...day,
                            cards: dayCards,
                            totalHours: totalHours > 0 ? totalHours.toFixed(2) : null,
                            remainingTo8: (isWeekday && remainingTo8 > 0) ? remainingTo8.toFixed(2) : null,
                            isWeekday: isWeekday
                        };
                    }
                    return day;
                })
            };
        });

        this.computeMonthRemaining();
        this.buildFillPlan();
    }

    computeMonthRemaining() {
        const monthWorkingHours = this.monthlyWorkingHours || 0;
        const tracked = this.periodTotalHours || 0;
        const remaining = Math.max(0, monthWorkingHours - tracked);
        this.remainingTo8hMonth = remaining.toFixed(2);
        const maxCanTrack = Math.min(remaining, this.taskRayRemainingHours || 0);
        this.maxCanTrackMonth = maxCanTrack.toFixed(2);
    }

    toDateKey(value) {
        if (!value) return null;
        if (typeof value === 'string') return value.split('T')[0];
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return null;
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    }

    listWeekdayKeys(fromKey, toKey) {
        if (!fromKey || !toKey) return [];
        const start = new Date(`${fromKey}T00:00:00`);
        const end = new Date(`${toKey}T00:00:00`);
        if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end) return [];
        const keys = [];
        for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
            const dow = d.getDay();
            if (dow === 0 || dow === 6) continue;
            keys.push(
                `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
            );
        }
        return keys;
    }

    getDayDeficitsMap() {
        const deficits = new Map();
        (this.calendarDays || []).forEach((week) => {
            (week.days || []).forEach((day) => {
                if (day?.isEmpty || !day?.dateStr) return;
                const d = new Date(`${day.dateStr}T00:00:00`);
                const dow = d.getDay();
                if (dow === 0 || dow === 6) return;
                const total = parseFloat(day.totalHours || 0);
                deficits.set(day.dateStr, Math.max(0, 8 - total));
            });
        });
        return deficits;
    }

    listOpenWeekdaysFrom(fromKey, capacity) {
        const monthEnd = this.endDate;
        if (!fromKey || !monthEnd) return [];
        const start = new Date(`${fromKey}T00:00:00`);
        const end = new Date(`${monthEnd}T00:00:00`);
        if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end) return [];

        const keys = [];
        for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
            const dow = d.getDay();
            if (dow === 0 || dow === 6) continue;
            const dateKey = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
            if ((capacity.get(dateKey) || 0) > 0) keys.push(dateKey);
        }
        return keys;
    }

    allocateHoursAcrossDays({ hours, days, capacity, rows, keyPrefix, taskName, taskUrl, hint, source }) {
        let left = hours;
        days.forEach((dateKey, i) => {
            if (left <= 0) return;
            const room = capacity.get(dateKey) || 0;
            if (room <= 0) return;

            let chunk = Math.min(left, room);
            chunk = Math.floor(chunk * 4) / 4;
            if (chunk <= 0 && left > 0 && room >= 0.25) chunk = Math.min(0.25, left, room);
            if (chunk <= 0) return;

            rows.push({
                key: `${keyPrefix}-${dateKey}-${i}`,
                date: dateKey,
                taskName,
                taskUrl,
                hours: chunk.toFixed(2),
                hint,
                source
            });
            left -= chunk;
            capacity.set(dateKey, Math.max(0, room - chunk));
        });
        return left;
    }

    buildStatusFillRows(dayCapacity) {
        const rows = [];
        const capacity = new Map(dayCapacity);
        const events = Array.isArray(this.statusFillEvents) ? [...this.statusFillEvents] : [];
        // Deploys first: they must stay on status day; DEV then fills remaining room / spills forward.
        events.sort((a, b) => {
            const aDeploy = a?.newStatus === 'Internal Testing Production' ? 0 : 1;
            const bDeploy = b?.newStatus === 'Internal Testing Production' ? 0 : 1;
            if (aDeploy !== bDeploy) return aDeploy - bDeploy;
            return String(a?.eventDate || '').localeCompare(String(b?.eventDate || ''));
        });

        events.forEach((ev, idx) => {
            const eventDate = this.toDateKey(ev.eventDate);
            if (!eventDate) return;
            const taskName = ev.taskName || '';
            const taskUrl = ev.parentUrl || (ev.taskId ? `/${ev.taskId}` : '');

            if (ev.newStatus === 'Internal Testing Production') {
                // Prod deploy always stays on the status-change day (even if day already has DEV hours).
                rows.push({
                    key: `status-deploy-${ev.taskId || 'na'}-${eventDate}-${idx}`,
                    date: eventDate,
                    taskName,
                    taskUrl,
                    hours: '2.00',
                    hint: ev.hintText || 'Prod deploy (Internal Testing Production)',
                    source: 'STATUS_DEPLOY'
                });
                // Still reduce remaining day room so DEV/REMAINING don't overfill around it when possible.
                if (capacity.has(eventDate)) {
                    capacity.set(eventDate, Math.max(0, (capacity.get(eventDate) || 0) - 2));
                }
                return;
            }

            if (ev.newStatus !== 'Internal Testing') return;

            const suggested = parseFloat(ev.suggestedHours || 0);
            if (suggested <= 0) return;

            let fromKey = this.toDateKey(ev.developmentStartDate) || eventDate;
            if (fromKey > eventDate) fromKey = eventDate;
            const monthStart = this.startDate;
            if (monthStart && fromKey < monthStart) fromKey = monthStart;

            // Preferred window: development start .. event day (only open days).
            let openDays = this.listWeekdayKeys(fromKey, eventDate)
                .filter((d) => (capacity.get(d) || 0) > 0);

            // If preferred days are full (e.g. Aug 3 already at 8h), spill to following weekdays.
            if (!openDays.length) {
                openDays = this.listOpenWeekdaysFrom(eventDate, capacity);
            } else {
                // Also allow spill after event day if not enough room in preferred window.
                const after = this.listOpenWeekdaysFrom(
                    (() => {
                        const d = new Date(`${eventDate}T00:00:00`);
                        d.setDate(d.getDate() + 1);
                        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
                    })(),
                    capacity
                );
                openDays = [...openDays, ...after.filter((d) => !openDays.includes(d))];
            }
            if (!openDays.length) return;

            this.allocateHoursAcrossDays({
                hours: suggested,
                days: openDays,
                capacity,
                rows,
                keyPrefix: `status-dev-${ev.taskId || 'na'}-${idx}`,
                taskName,
                taskUrl,
                hint: ev.hintText || 'Development (moved to Internal Testing)',
                source: 'STATUS_DEV'
            });
        });

        return { rows, capacity };
    }

    buildFillPlan() {
        const dayCapacity = this.getDayDeficitsMap();
        const statusResult = this.buildStatusFillRows(dayCapacity);
        const plan = [...statusResult.rows];
        const capacity = statusResult.capacity;

        // Keep existing remaining-hours allocation (unspent estimate), after status rows.
        const maxToAllocate = parseFloat(this.maxCanTrackMonth || 0);
        if (maxToAllocate > 0) {
            const deficits = Array.from(capacity.entries())
                .filter(([, missing]) => missing > 0)
                .map(([date, missing]) => ({ date, missing }))
                .sort((a, b) => a.date.localeCompare(b.date));

            const touchedTaskMap = new Map();
            (this.myList || []).forEach((c) => {
                const taskId = c?.TaskRay_Task__c;
                if (!taskId) return;
                const taskName = c?.TaskName || '';
                const hint = this.stripHtmlTags(c?.Service_Notes__c || '');
                const existing = touchedTaskMap.get(taskId);
                if (!existing) {
                    touchedTaskMap.set(taskId, { taskId, taskName, hint, remainingHours: null });
                } else if (!existing.hint && hint) {
                    existing.hint = hint;
                }
            });

            const remainingByTask = new Map();
            (this.taskRayTasks || []).forEach((t) => {
                if (!t?.taskId) return;
                remainingByTask.set(t.taskId, parseFloat(t.remainingHours || 0));
            });
            touchedTaskMap.forEach((v) => {
                v.remainingHours = remainingByTask.has(v.taskId) ? remainingByTask.get(v.taskId) : 0;
            });

            let tasks = Array.from(touchedTaskMap.values())
                .filter((t) => (t.remainingHours || 0) > 0)
                .sort((a, b) => (b.remainingHours || 0) - (a.remainingHours || 0));

            if (tasks.length === 0) {
                tasks = [{
                    taskId: '',
                    taskName: 'General / Unassigned',
                    remainingHours: maxToAllocate,
                    hint: 'Unspent remaining'
                }];
            }

            let allocated = 0;
            let taskIdx = 0;
            for (const def of deficits) {
                if (allocated >= maxToAllocate) break;
                let dayRemaining = Math.min(def.missing, maxToAllocate - allocated);

                while (dayRemaining > 0 && taskIdx < tasks.length) {
                    const t = tasks[taskIdx];
                    const taskRemaining = t.remainingHours || 0;
                    if (taskRemaining <= 0) {
                        taskIdx++;
                        continue;
                    }

                    const chunk = Math.min(dayRemaining, taskRemaining);
                    const rounded = Math.floor(chunk * 4) / 4;
                    const toUse = rounded > 0 ? rounded : chunk;
                    if (toUse <= 0) break;

                    plan.push({
                        key: `remaining-${def.date}-${t.taskId || 'na'}-${plan.length}`,
                        date: def.date,
                        taskName: t.taskName || '',
                        taskUrl: t.taskId ? `/${t.taskId}` : '',
                        hours: toUse.toFixed(2),
                        hint: (t.hint ? `${t.hint} | ` : '') + 'Unspent remaining',
                        source: 'REMAINING'
                    });

                    t.remainingHours = taskRemaining - toUse;
                    dayRemaining -= toUse;
                    allocated += toUse;
                }
            }
        }

        plan.sort((a, b) => {
            const byDate = String(a.date).localeCompare(String(b.date));
            if (byDate !== 0) return byDate;
            return String(a.source).localeCompare(String(b.source));
        });

        const total = plan.reduce((s, r) => s + parseFloat(r.hours || 0), 0);
        this.fillPlan = plan;
        this.fillPlanTotal = total.toFixed(2);
    }

    downloadFillPlanCsv() {
        try {
            const header = ['Date', 'Task', 'Hours', 'Hint', 'Source', 'TaskUrl'];
            const rows = [header];
            (this.fillPlan || []).forEach((r) => {
                rows.push([r.date, r.taskName, r.hours, r.hint, r.source || '', r.taskUrl || '']);
            });
            const csv = rows
                .map((r) => r.map((v) => this.csvEscape(v)).join(','))
                .join('\n');
            const filename = `timesheet_fill_plan_${this.currentYear}_${String(this.currentMonthDate.getMonth() + 1).padStart(2, '0')}.csv`;
            this.triggerDownload(filename, csv);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('downloadFillPlanCsv failed', e);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to generate fill plan CSV: ' + (e?.message || 'Unknown error'),
                    variant: 'error',
                })
            );
        }
    }

    isToday(year, month, day) {
        const today = new Date();
        return today.getFullYear() === year && 
               today.getMonth() === month && 
               today.getDate() === day;
    }

    previousMonth() {
        this.currentMonthDate = new Date(
            this.currentMonthDate.getFullYear(),
            this.currentMonthDate.getMonth() - 1,
            1
        );
        this.updateCalendarDates();
        this.getCardRecords();
    }

    nextMonth() {
        this.currentMonthDate = new Date(
            this.currentMonthDate.getFullYear(),
            this.currentMonthDate.getMonth() + 1,
            1
        );
        this.updateCalendarDates();
        this.getCardRecords();
    }

    goToToday() {
        this.currentMonthDate = new Date();
        this.updateCalendarDates();
        this.getCardRecords();
    }

    formatTimeForDisplay(timeStr) {
        if (!timeStr) return '';
        // Extract HH:MM from time string
        const parts = timeStr.split(':');
        if (parts.length >= 2) {
            return `${parts[0]}:${parts[1]}`;
        }
        return timeStr;
    }

    get modalTitle() {
        return this.newCard && this.newCard.isEditing ? 'Edit Time Card' : 'Add New Time Card';
    }

    get modalButtonLabel() {
        return this.newCard && this.newCard.isEditing ? 'Update Time Card' : 'Add Time Card';
    }

    calculateHours(startTime, endTime) {
        if (!startTime || !endTime) return '0';
        
        try {
            // Parse time strings (format: HH:MM:SS.mmm)
            const parseTime = (timeStr) => {
                const parts = timeStr.split(':');
                const hours = parseInt(parts[0]) || 0;
                const minutes = parseInt(parts[1]) || 0;
                return hours + (minutes / 60);
            };
            
            const start = parseTime(startTime);
            const end = parseTime(endTime);
            
            let hours = end - start;
            if (hours < 0) hours += 24; // Handle overnight shifts
            
            return hours.toFixed(2);
        } catch (e) {
            return '0';
        }
    }

    stripHtmlTags(html) {
        if (!html) return '';
        
        // Remove HTML tags
        let text = html.replace(/<[^>]*>/g, '');
        // Decode HTML entities
        const textArea = document.createElement('textarea');
        textArea.innerHTML = text;
        text = textArea.value;
        // Truncate if too long
        return text.length > 50 ? text.substring(0, 50) + '...' : text;
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
                        this.record[i].TaskName = this.record[i].TaskRay_Task__r.Name;
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
                this.assignCardsToCalendar();
                this.refreshTaskRaySummary();
            })
            .catch(error => {
                // console.log('getCardRecords error' + JSON.stringify(error));
                this.error = error;
                this.isSpinner = false;
                this.record = undefined;
            });
    }

    refreshTaskRaySummary() {
        if (!this.startDate || !this.endDate) return;
        Promise.all([
            getTaskRayMonthSummary({ sDt: this.startDate, eDt: this.endDate }),
            getTaskRayStatusFillEvents({ sDt: this.startDate, eDt: this.endDate }).catch(() => [])
        ])
            .then(([res, statusEvents]) => {
                this.taskRayTrackedHours = parseFloat(res?.totalHours || 0);
                this.taskRayRemainingHours = parseFloat(res?.totalTaskRemainingHours || 0);
                this.taskRayTasks = Array.isArray(res?.tasks) ? res.tasks : [];
                this.statusFillEvents = Array.isArray(statusEvents) ? statusEvents : [];
                this.computeMonthRemaining();
                this.buildFillPlan();
                this.refreshChatterActivity();
            })
            .catch(() => {
                this.taskRayTrackedHours = 0;
                this.taskRayRemainingHours = 0;
                this.taskRayTasks = [];
                this.statusFillEvents = [];
                this.computeMonthRemaining();
                this.buildFillPlan();
                this.chatterActivity = [];
                this.chatterMentionsCount = 0;
            });
    }

    refreshChatterActivity() {
        if (!this.startDate || !this.endDate) {
            this.chatterActivity = [];
            this.chatterMentionsCount = 0;
            return;
        }
        // Pull mentions/my activity even if the task wasn't in time entries (late start date etc.)
        getMyTaskRayMentions({ sDt: this.startDate, eDt: this.endDate })
            .then((rows) => {
                const list = Array.isArray(rows) ? rows : [];
                const withKeys = list.map((r, idx) => ({
                    ...r,
                    key: `${r?.taskId || 'na'}-${r?.createdDate || 'na'}-${idx}`,
                }));
                this.chatterActivity = withKeys;
                this.chatterMentionsCount = withKeys.filter((r) => r?.isMention).length;
            })
            .catch(() => {
                this.chatterActivity = [];
                this.chatterMentionsCount = 0;
            });
    }

    downloadChatterCsv() {
        try {
            const header = ['CreatedDate', 'Task', 'Author', 'IsMention', 'IsByMe', 'Snippet', 'TaskUrl'];
            const rows = [header];
            (this.chatterActivity || []).forEach((r) => {
                rows.push([
                    r.createdDate,
                    r.taskName,
                    r.authorName,
                    r.isMention ? 'Y' : 'N',
                    r.isByMe ? 'Y' : 'N',
                    r.snippet,
                    r.parentUrl
                ]);
            });
            const csv = rows.map((r) => r.map((v) => this.csvEscape(v)).join(',')).join('\n');
            const filename = `taskray_chatter_activity_${this.currentYear}_${String(this.currentMonthDate.getMonth() + 1).padStart(2, '0')}.csv`;
            this.triggerDownload(filename, csv);
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to generate chatter CSV: ' + (e?.message || 'Unknown error'),
                    variant: 'error',
                })
            );
        }
    }

    downloadMonthContextJson() {
        try {
            const month = {
                year: this.currentYear,
                monthIndex: this.currentMonthDate.getMonth() + 1,
                monthName: this.currentMonth,
                startDate: this.startDate,
                endDate: this.endDate,
                monthlyWorkingHours: this.monthlyWorkingHours,
                periodTotalHoursFromCards: this.periodTotalHours,
                taskRayTrackedHours: this.taskRayTrackedHours,
                taskRayRemainingHours: this.taskRayRemainingHours,
                remainingTo8hMonth: parseFloat(this.remainingTo8hMonth || 0),
                maxCanTrackMonth: parseFloat(this.maxCanTrackMonth || 0),
            };

            const timeCards = (this.myList || []).map((c) => ({
                id: c.Id || null,
                date: c?.Date_of_Service__c ? String(c.Date_of_Service__c).split('T')[0] : null,
                startTime: c.Start_Time__c || null,
                endTime: c.End_Time__c || null,
                hours: parseFloat(this.calculateHours(c.Start_Time__c, c.End_Time__c) || 0),
                production: c.ProductionName || null,
                service: c.ServiceName || null,
                taskId: c.TaskRay_Task__c || null,
                taskName: c.TaskName || null,
                notes: this.stripHtmlTags(c.Service_Notes__c || ''),
            }));

            const tasks = (this.taskRayTasks || []).map((t) => ({
                taskId: t.taskId,
                taskName: t.taskName,
                startDate: t.startDate || null,
                estimatedEndDate: t.estimatedEndDate || null,
                estimatedHours: t.estimatedHours,
                totalTimeOnTask: t.totalTimeOnTask,
                remainingHours: t.remainingHours,
            }));

            const chatter = (this.chatterActivity || []).map((r) => ({
                taskId: r.taskId,
                taskName: r.taskName,
                createdDate: r.createdDate,
                authorName: r.authorName,
                isMention: !!r.isMention,
                isByMe: !!r.isByMe,
                snippet: r.snippet,
                parentUrl: r.parentUrl,
            }));

            const fillPlan = (this.fillPlan || []).map((r) => ({
                date: r.date,
                task: r.taskName,
                hours: r.hours,
                hint: r.hint,
                source: r.source || null,
                taskUrl: r.taskUrl || null,
            }));

            const statusEvents = (this.statusFillEvents || []).map((e) => ({
                taskId: e.taskId,
                taskName: e.taskName,
                eventDate: e.eventDate,
                developmentStartDate: e.developmentStartDate,
                newStatus: e.newStatus,
                oldStatus: e.oldStatus,
                estimatedHours: e.estimatedHours,
                totalTimeOnTask: e.totalTimeOnTask,
                remainingHours: e.remainingHours,
                suggestedHours: e.suggestedHours,
                hint: e.hintText,
                parentUrl: e.parentUrl,
            }));

            const payload = {
                month,
                tasks,
                timeCards,
                chatter,
                statusEvents,
                fillPlan,
            };

            const json = JSON.stringify(payload, null, 2);
            const filename = `month_context_${this.currentYear}_${String(this.currentMonthDate.getMonth() + 1).padStart(2, '0')}.json`;
            this.triggerDownload(filename, json);
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to generate month context JSON: ' + (e?.message || 'Unknown error'),
                    variant: 'error',
                })
            );
        }
    }

    downloadCsv() {
        try {
            const rows = [];
            const header = [
                'Date',
                'Hours',
                'Production',
                'Service',
                'TaskRay Task',
                'Notes',
                'RowType'
            ];
            rows.push(header);

            const cardsByDate = new Map();
            (this.myList || []).forEach((c) => {
                const dateKey = c?.Date_of_Service__c ? String(c.Date_of_Service__c).split('T')[0] : null;
                if (!dateKey) return;
                const hours = parseFloat(this.calculateHours(c.Start_Time__c, c.End_Time__c) || 0);
                if (!cardsByDate.has(dateKey)) cardsByDate.set(dateKey, []);
                cardsByDate.get(dateKey).push({
                    dateKey,
                    hours,
                    production: c.ProductionName || '',
                    service: c.ServiceName || '',
                    task: c.TaskName || '',
                    notes: this.stripHtmlTags(c.Service_Notes__c || ''),
                });
            });

            // Add actual card rows (sorted by date)
            Array.from(cardsByDate.keys()).sort().forEach((dateKey) => {
                const dayCards = cardsByDate.get(dateKey) || [];
                dayCards.forEach((c) => {
                    rows.push([
                        dateKey,
                        (c.hours || 0).toFixed(2),
                        c.production,
                        c.service,
                        c.task,
                        c.notes,
                        'CARD'
                    ]);
                });
            });

            // Add filler rows to bring weekdays to 8h
            const year = this.currentMonthDate.getFullYear();
            const month = this.currentMonthDate.getMonth(); // 0-based
            const lastDay = new Date(year, month + 1, 0).getDate();

            for (let day = 1; day <= lastDay; day++) {
                const d = new Date(year, month, day);
                const dow = d.getDay();
                const isWeekday = dow !== 0 && dow !== 6;
                if (!isWeekday) continue;

                const dateKey = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
                const dayCards = cardsByDate.get(dateKey) || [];
                const dayTotal = dayCards.reduce((s, c) => s + (c.hours || 0), 0);
                const missing = Math.max(0, 8 - dayTotal);
                if (missing > 0) {
                    rows.push([
                        dateKey,
                        missing.toFixed(2),
                        '',
                        '',
                        '',
                        '',
                        'FILL_TO_8H'
                    ]);
                }
            }

            const csv = rows
                .map((r) => r.map((v) => this.csvEscape(v)).join(','))
                .join('\n');
            const filename = `timecards_${this.currentYear}_${String(this.currentMonthDate.getMonth() + 1).padStart(2, '0')}.csv`;
            this.triggerDownload(filename, csv);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('downloadCsv failed', e);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to generate CSV: ' + (e?.message || 'Unknown error'),
                    variant: 'error',
                })
            );
        }
    }

    csvEscape(value) {
        const s = value === null || value === undefined ? '' : String(value);
        const needsQuotes = /[",\n\r]/.test(s);
        const escaped = s.replace(/"/g, '""');
        return needsQuotes ? `"${escaped}"` : escaped;
    }

    triggerDownload(filename, content) {
        const a = document.createElement('a');
        a.download = filename;
        a.style.display = 'none';

        // Some Salesforce embedded browsers reject Blob URLs / csv MIME.
        // Prefer a data URL first, then fallback to Blob if needed.
        try {
            const encoded = encodeURIComponent(content);
            a.href = `data:text/csv;charset=utf-8,${encoded}`;
        } catch (e) {
            const blob = new Blob([content], { type: 'text/plain;charset=utf-8;' });
            a.href = URL.createObjectURL(blob);
        }

        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);

        if (a.href && a.href.startsWith('blob:')) {
            URL.revokeObjectURL(a.href);
        }
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