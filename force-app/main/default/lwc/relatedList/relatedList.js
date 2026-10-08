import { LightningElement, api, track, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import createNewRecord from "@salesforce/apex/DatatableController.createNewRecord";

import SUBJECT_FIELD from '@salesforce/schema/Case.Subject';
import DESCRIPTION_FIELD from '@salesforce/schema/Case.Trello_Description__c';
import REASON_FIELD from '@salesforce/schema/Case.Reason';
import TOPIC_FIELD from '@salesforce/schema/Case.Type';

import Utils from 'c/utils';

export default class RelatedList extends LightningElement {
  @api showAddButton;
  @api modalEdit;
  _title;
  isSpinner = false;
  @api
  get title() {
    return this._title || (this.objectInfo && this.objectInfo.labelPlural) || this.sObject;
  }
  set title(value) {
    this._title = value;
  }
  @api recordId;
  @api objectApiName
  @api sObject;
  @api fields;
  @api sortedBy;
  @api sortedDirection;
  _filter;
  @track value = 'Open';


  @api
  get filter() {
    if (this._filter && this.parentRelationship) {
      return this.parentRelationship + ' AND ' + this._filter;
    }
    if (Utils.getCookie('WRContactId')) {
      if (this.value === 'Open') {
        return `ContactId = '${Utils.getCookie('WRContactId')}' AND Status != 'Closed'`;
      } else {
        return `ContactId = '${Utils.getCookie('WRContactId')}' AND Status = 'Closed'`;
      }

    }



    return this._filter || this.parentRelationship;
  }
  set filter(value) {
    this._filter = value;
  }
  @api hideCheckboxColumn;
  @api enableInfiniteLoading;
  @api recordsPerBatch = 50;
  @api initialRecords;
  @api customColoum;
  @api showSoql;
  @api parentRecordField;
  @api childRecordField;
  @api editable;
  @api height;
  @api enableLiveUpdates;
  @api iconName;

  recId;
  _parentRecordField;
  _childRecordField;


  fieldsR = [TOPIC_FIELD, REASON_FIELD, SUBJECT_FIELD, DESCRIPTION_FIELD];

  @track objectInfo;

  @wire(getObjectInfo, { objectApiName: '$sObject' })
  wiredObjectInfo({ error, data }) {
    this.isSpinner = true;
    if (data) {
      this.isSpinner = false;
      this.objectInfo = data;
    } else if (error) {
      this.isSpinner = false;
      this.error(error.statusText + ': ' + error.body.message);
    }
  }


  @wire(getRecord, { recordId: "$recordId", fields: "$fullParentRecordField" })
  parentRecord;

  get fullParentRecordField() {
    return this.objectApiName + "." + this.parentRecordField;
  }

  get acceptedFormats() {
    return ['.docx', '.pdf', '.ppt', '.pptx', '.xls', '.xlsx', '.jpg', '.jpeg', '.png', '.gif', '.svg'];
  }

  get parentRecordId() {
    if (!this.parentRecordField) {
      return undefined;
    } else if (this.parentRecord && this.parentRecord.data) {
      return getFieldValue(this.parentRecord.data, this.fullParentRecordField);
    }
    return "";
  }

  get parentRelationship() {
    if (this.childRecordField && typeof this.parentRecordId !== undefined) {
      return `${this.childRecordField}='${this.parentRecordId}'`;
    }
    return "";
  }

  // used to render datatable. Important because otherwise, initial query can be very inefficient and cause slow load times
  get ready() {
    return !!this.parentRecordId || !this.parentRecordField;
  }

  refresh() {
    this.template.querySelector('c-datatable').refresh();
  }
  get customStyle() {
    if (this.height) {
      return 'height:' + this.height + 'px';
    }
    return '';
  }

  get addRecordTitle() {
    return this.objectInfo ? 'New ' + this.objectInfo.label : 'Loading...';
  }

  get options() {
    return [
      { label: 'Open', value: 'Open' },
      { label: 'Closed', value: 'Closed' }
    ];
  }


  handleChange(event) {

    this.value = event.detail.value;
  }


  createNew() {
    // // console.log('createNew');
    // // console.log('fieldsR', this.fieldsR);

    this.template.querySelector('[data-id="new"]').open();
  }


  handleSubmit(event) {
    event.preventDefault(); // stop the form from submitting

    let fields = event.detail.fields;
    let contactId = Utils.getCookie('WRContactId');
    // // console.log('contactId ', contactId);
    if (contactId) {
      fields.ContactId = contactId;
    }
    fields.Status = 'Trello Backlog';

    // console.log('fields', JSON.stringify(fields));
    // fields.LastName = 'My Custom Last Name'; // modify a field
    // console.log('fields123');
    try {
      this.isSpinner = true;
      createNewRecord({ objName: this.objectApiName, generalData: fields })
        .then(data => {
          // console.log('data ', data);
          this.recId = data;
          this.isSpinner = false;
          this.handleSuccess(this.recId);
        })
        .catch(error => {
          this.isSpinner = false;
          // console.log('error ', error);
          this.errorMessage(error);
        })

    } catch (e) {
      // console.log('e', e);
    }
  }


  errorMessage(error) {
    let errors = Utils.reduceErrors(error);
    const event = new ShowToastEvent({
      title: 'Error',
      message: errors[0],
      variant: 'Error',
      mode: 'dismissable'
    });
    this.dispatchEvent(event);
  }

  handleNewCancel(event) {
    this.template.querySelector('c-datatable').refresh();
    this.template.querySelector('[data-id="new"]').close();
  }
  handleFileCancel(event) {
    this.template.querySelector('c-datatable').refresh();
    this.template.querySelector('[data-id="files"]').close();
  }

  close() {
    this.template.querySelector('c-datatable').refresh();
    this.template.querySelector('[data-id="new"]').close();
  }
  closeF() {
    this.template.querySelector('c-datatable').refresh();
    this.template.querySelector('[data-id="files"]').close();
  }
  handleSuccess(recId) {

    this.recId = recId;

    this.template.querySelector('c-datatable').refresh();
    this.template.querySelector('[data-id="new"]').close();
    this.template.querySelector('[data-id="files"]').open();
  }
  handleUploadFinished(event) {
    // Get the list of uploaded files
    this.template.querySelector('c-datatable').refresh();
    this.template.querySelector('[data-id="files"]').close();
  }
}