import { LightningElement, wire, api, track } from 'lwc';
import {getRecord, getFieldValue} from 'lightning/uiRecordApi';
import {showToastMessage} from 'c/lwcUtils';
import {refreshApex} from '@salesforce/apex';

import createZoomMeetingAndSendInvite from '@salesforce/apex/ZoomIntegrationController.createZoomMeetingAndSendInvite';

export default class ZoomIntegrationLwc extends LightningElement {

    isLoaded = true;
    @api recordId;
    idOfSelectedRecordInRecordPicker;
    emailOfSelectedRecordInRecordPicker;
    @api objectApiName;
    @api emailField; // set in app builder like Contact.Email
    @api objectFields; // set in app builder Contact.Email,Contact.Name or CustomObject__c.Email__c
    wiredObjectResult;
    currentRecordEmail;

    isFutureMeeting = false;
    meetingType = 1;
    timezone = '';
    hostEmail = '';

    @track selectedRecordsForAttendees = [];
    selectedObjectApiName = "Contact";
    selectedObjectLabel = 'Contact';
    objectOptions = [
        
        {
            label:"Contact",
            value:"Contact"
        },
        {
            label:"User",
            value:"User"
        },
        {
            label:"Lead",
            value:"Lead"
        }
    ];
    

    matchingInfo = {
        primaryField: { fieldPath: 'Name' },
        additionalFields: [{ fieldPath: 'Email' }],
    };


    get displayInfo() {
        debugger;
        console.log(`Email Field: ${this.emailField}`); // Contact.Email

        if (this.emailField) 
        {
            const primaryField = 'Name';
            const additionalFields = [this.emailField.split('.')[1]];
            return { primaryField, additionalFields };
        } 
        else 
        {
            return { primaryField: 'Name', additionalFields: [] };
        }
    }
    


    // convert string objectFields to array so that we can pass to fieldsparamter
    get objectFieldsAsArray(){
        return this.objectFields.split(',').map(eachField => eachField.trim());
    }

    // Create a computed property to get dynamic fields for wire
    get emailFieldForSelectedRecord() {
        if (this.selectedObjectApiName && this.emailField) {
            const fieldsVal = `${this.selectedObjectApiName}.${this.emailField.split('.')[1]}`;
            //alert('emailFieldForSelectedRecord, fieldsVal='+fieldsVal);
            return [fieldsVal];
        }
        return [];
    }

    @wire(getRecord, {recordId : '$idOfSelectedRecordInRecordPicker', fields : '$emailFieldForSelectedRecord'})
    wiredRecordPicker(result)
    {
        this.wiredSelectedRecordResult = result;

        if(this.wiredSelectedRecordResult.data)
        {
            this.emailOfSelectedRecordInRecordPicker = getFieldValue(result.data, `${this.selectedObjectApiName}.${this.emailField.split('.')[1]}`);
        }
    }
    
        // get currentRecordEmail(){
    
    // get current contact sObject record's email address using the recordId
    @wire(getRecord, {recordId : '$recordId', fields : '$objectFieldsAsArray'})
    wiredRecord(result){
        this.wiredObjectResult = result;

        if(this.wiredObjectResult.data)
        {
            this.currentRecordEmail = getFieldValue(this.wiredObjectResult.data, this.emailField);
            this.addRecordToSelectedRecordsForAttendees({id : this.recordId, label : this.currentRecordEmail});
        }
    }


    get placeholderVal(){

        return `Type here to search ${this.selectedObjectLabel} records...`
    }

    addRecordToSelectedRecordsForAttendees(recordToAdd){

        console.log(`addRecordToSelectedRecordsForAttendees called with recordToAdd= ${JSON.stringify(recordToAdd)}`);
        
        // Before adding , first check if this record is already present
        const isRecordAlreadyPresent = this.selectedRecordsForAttendees.some(eachRec => eachRec.id === recordToAdd.id);
        
        if(isRecordAlreadyPresent)
        {
            showToastMessage(this, 'Error', `${recordToAdd.label} is already added.`, 'error', 'dismissible');
        }
        else
        {
            this.selectedRecordsForAttendees = [...this.selectedRecordsForAttendees, recordToAdd];
        }
        
    }


    removeRecordFromSelectedRecordsForAttendees(recordToRemove){

        console.log(`removeRecordFromSelectedRecordsForAttendees called with recordToRemove= ${recordToRemove}`);
        
        this.selectedRecordsForAttendees = this.selectedRecordsForAttendees.filter(eachRec => eachRec.id != recordToRemove.id);        
    }


    handleRemoveRecipient(event){
        //alert(`handling the event in grand parent ZoomIntegrationLwc ${JSON.stringify(event.detail)}`);
        this.removeRecordFromSelectedRecordsForAttendees(event.detail);
    }


    handleObjectChange(event){
        this.idOfSelectedRecordInRecordPicker = '';
        this.emailOfSelectedRecordInRecordPicker = '';
        this.selectedObjectApiName = event.target.value;
        this.selectedObjectLabel = this.objectOptions.find(eachRec => eachRec.value === event.target.value).label;
    }

    async handleRecordClickInRecordPicker(event){
        debugger;
        event.target.clearSelection();
        this.emailOfSelectedRecordInRecordPicker = '';

        this.idOfSelectedRecordInRecordPicker = event.detail.recordId;
        //alert('in handleRecordClickInRecordPicker before refreshapex, idOfSelectedRecordInRecordPicker='+this.idOfSelectedRecordInRecordPicker);
        try
        {
            await refreshApex(this.wiredSelectedRecordResult);
        }
        catch(error)
        {
            showToastMessage(this, 'Error', `Error in refreshing Apex: ${error.body.message} `, 'error', 'sticky');
        }
        
        //alert(`handleRecordClickInRecordPicker called with idOfSelectedRecordInRecordPicker= ${this.idOfSelectedRecordInRecordPicker} and emailOfSelectedRecordInRecordPicker = ${this.emailOfSelectedRecordInRecordPicker}`);
        if(this.emailOfSelectedRecordInRecordPicker)
        {
            this.addRecordToSelectedRecordsForAttendees({id : this.idOfSelectedRecordInRecordPicker, label : this.emailOfSelectedRecordInRecordPicker});
        }
        else
        {
            showToastMessage(this, 'Error', `No email found for this record.`, 'error', 'sticky');
        }
    }

    handleFutureMeetingCheckboxChange(event){
        this.isFutureMeeting = event.target.checked;
    }


    async handleSendZoomInviteClick(event){
        debugger;
        let areAllInputsValid = true;

        this.template.querySelectorAll('lightning-input').forEach(eachElem => {
            eachElem.reportValidity();

            if(!eachElem.reportValidity())
            {
                areAllInputsValid = false;
            }
        })

        const topicElem = this.template.querySelector('lightning-input[data-id="topic"]');
        if(topicElem.value && topicElem.value.trim().length === 0)
        {
            topicElem.setCustomValidity('Only whitespaces found in Topic.');
            topicElem.reportValidity();
            areAllInputsValid = false;
        }
        else
        {
            topicElem.setCustomValidity('');
            topicElem.reportValidity();
        }


        const agendaElem = this.template.querySelector('lightning-textarea[data-id="agenda"]');

        if(!agendaElem.reportValidity())
        {
            areAllInputsValid = false;
        }

        if(!areAllInputsValid){
            return;
        }
        if(this.selectedRecordsForAttendees === undefined || this.selectedRecordsForAttendees.length === 0)
        {
            showToastMessage(this, 'Error', `Please select at least one record to send Zoom Invite.`, 'error', 'sticky');
            return;
        }
        try
        {
            
            const isFutureMeeting = this.isFutureMeeting;
            const topic = this.template.querySelector('lightning-input[data-id="topic"]').value;

            if( !(topic && topic.trim().length > 0))
            {
                showToastMessage(this, 'Error', `Please enter the Topic.`, 'error', 'sticky');
                return;
            }

            const agenda = this.template.querySelector('lightning-textarea[data-id="agenda"]').value;
            if( !(agenda && agenda.trim().length > 0))
            {
                showToastMessage(this, 'Error', `Please enter the Agenda.`, 'error', 'sticky');
                return;
            }

            const duration = this.template.querySelector('lightning-input[data-id="duration"]').value;
            if( !(duration && duration > 0))
            {
                showToastMessage(this, 'Error', `Please enter the Duration.`, 'error', 'sticky');
                return;
            }

            

            let start_time = '';
            if (this.isFutureMeeting) 
            {
                const localStartTime = this.template.querySelector('lightning-input[data-id="start_time"]').value;
                if (!localStartTime) {
                    showToastMessage(this, 'Error', `Please enter the start time.`, 'error', 'sticky');
                    return;
                }

                // Create a Date object from the local datetime string
                const localDate = new Date(localStartTime);

                // Manually convert the local date to UTC
                const utcYear = localDate.getUTCFullYear();
                const utcMonth = String(localDate.getUTCMonth() + 1).padStart(2, '0'); // Months are zero-based
                const utcDay = String(localDate.getUTCDate()).padStart(2, '0');
                const utcHours = String(localDate.getUTCHours()).padStart(2, '0');
                const utcMinutes = String(localDate.getUTCMinutes()).padStart(2, '0');
                const utcSeconds = String(localDate.getUTCSeconds()).padStart(2, '0');

                start_time = `${utcYear}-${utcMonth}-${utcDay}T${utcHours}:${utcMinutes}:${utcSeconds}Z`;
            }

            const meetingType = isFutureMeeting ? 2 : 1;
            const timezone = this.timezone;
            const hostEmail = this.hostEmail;
            
            const attendeesEmailList = this.selectedRecordsForAttendees.map(eachRec => eachRec.label);
            this.isLoaded = false;
            const zoomResult = await createZoomMeetingAndSendInvite({isFutureMeeting, topic, meetingType, start_time, duration, timezone, agenda, attendeesEmailList, hostEmail});
            this.isLoaded = true;

            if(zoomResult.isSuccess)
            {
                showToastMessage(this, 'Success', `Zoom meeting created and invite sent successfully.`, 'success', 'dismissible');
            }
            else
            {
                showToastMessage(this, 'Error', `Error in creating Zoom meeting and sending invite: ${zoomResult.errorMessage} `, 'error', 'sticky');
            }
            console.log(`zoomResult = ${JSON.stringify(zoomResult)}`);
        }
        catch(error)
        {
            showToastMessage(this, 'Error', `Error in creating Zoom meeting and sending invite: ${error.body.message} `, 'error', 'sticky');
        }
    }
}