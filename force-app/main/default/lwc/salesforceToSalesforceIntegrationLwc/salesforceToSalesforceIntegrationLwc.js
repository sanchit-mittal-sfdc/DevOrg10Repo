import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from "lightning/navigation";
import handlePageLoad from '@salesforce/apex/SalesforceIntegrationController.handlePageLoad';
import FORM_FACTOR from '@salesforce/client/formFactor';
import Toast from 'lightning/toast';


//define row actions
const actions = [
    { 
        label: 'Re-Authorize Org', 
        name: 'reauthorize'
    }    
];

/*const dynamicColumns = [
    {
        label:"Account Name",
        fieldName:"Name"
    },
    {
        label:"Account Type",
        fieldName:"Type"
    }
];*/

const columns = [
    {
        label:'ORG Name', 
        fieldName:'orgName',
        type:'text',
        hideDefaultActions:false, // IMP- This is used for hiding WRAP TEXT and CLIP TEXT action at column header level
        
    },
    {
        label:'Connection Status', 
        fieldName:'connectionStatus', 
        hideDefaultActions:false,
        cellAttributes: {
            class: 'slds-text-title_caps'
        }
    },
    {
        label:'Details', 
        fieldName:'statusMessage', 
        hideDefaultActions:false,
        wrapText: true
    },
    {
        type:'action',
        typeAttributes:{
            rowActions: actions,
            menuAlignment:'right'
        }
    }

        /*,
    {
        type: 'button-icon',
        typeAttributes:
        {
            iconName: 'utility:delete',
            name: 'delete',
            iconClass: 'slds-icon-text-error'
        }
    },
    {
        type: 'button-icon',
        typeAttributes:
        {
            iconName: 'utility:edit',
            name: 'edit'
        }
    }*/
]

export default class SalesforceToSalesforceIntegrationLwc extends NavigationMixin(LightningElement) {
    
    loaded = false;
    columns = columns;
    @api orgSelected;
    @api titleVal;
    @track orgDetails = [];// = [{orgName:'Test1',isConnected:'true'}];
    @track mapOrgNameToDefaultRecords = new Map();
    @track mapOrgNameToLabelFieldDetails = new Map();
    @track dynamicColumns =[];
    @track orgOptions = [];
    /*
    = [
        {
            label:"Account Name",
            fieldName:"Name"
        },
        {
            label:"Account Type",
            fieldName:"Type"
        }
    ];
    */


    connectedCallback(){

        //call apex to get the connection details on page load. Also, data will be returned in wrapper response ONLY IF the existing access token(Not refreshed access token i.e. new access token obtained via refresh token) is till valid. 
        this.fetchOrgsStatus('connectedCallback');
    }

    //Refresh Orgs Status manually
    refreshOrgsStatus(){
        console.log('refreshOrgsStatus called');
        this.fetchOrgsStatus('refreshOrgsStatus');
    }

    fetchOrgsStatus(calledFrom){

        this.loaded = false;

        console.log('fetchOrgsStatus method is called from method: '+ calledFrom);

        handlePageLoad({}).then(response=>{

            if(response)
            {
                console.log('Response received fro handlePageLoad = '+response);
                console.log('Response received fro handlePageLoad JSON.stringify = ' + JSON.stringify(response));
                //debugger;
                //this.orgDetails = response;

                try{
                    // ############ IMP:  .map() javascript function being used as a forEacjh method as well so as to avoid extra forEach to populate mapOrgNameToLabelFieldDetails
                    this.orgDetails = response.map(eachOrg =>{

                        // Popuolate mapOrgNameToLabelFieldDetails
                        this.mapOrgNameToLabelFieldDetails.set( eachOrg.orgName, eachOrg.labelFieldMap ); 

                        // Iterate over org details and populate map having key as OrgName and value as List of default records that were fetched(if any)
                        this.mapOrgNameToDefaultRecords.set(eachOrg.orgName, eachOrg.records );
                        debugger;
                        // populate orgOptions
                        const label = eachOrg.orgName;
                        const value = eachOrg.orgName;
                        this.orgOptions.push({label, value});
                        debugger;

                        /*
                            ########## IMP CONCEPT

                            Implicit Global Variable: Without const, let, or var, JavaScript treats the variable as an implicit global variable. This can cause unintended behavior, especially if there's a variable with the same name in a different scope.
                            Code was not working and throwing excepption when I was not using const or let i.e. orgName = eachOr.orgname;   

                        */

                        const orgName = eachOrg.orgName;
                        const isConnected = eachOrg.isConnected;
                        const id = eachOrg.id;
                        const statusMessage = eachOrg.statusMessage;
                        const connectionStatus = eachOrg.isConnected ? 'Active' : 'Not Active';
                        const records = eachOrg.records;
                        const labelFieldMap = eachOrg.labelFieldMap;
    
                        return { orgName, isConnected, id, statusMessage, connectionStatus, records, labelFieldMap};
                    });
                    this.loaded = true;

                    
                    if(calledFrom === 'refreshOrgsStatus')
                    {
                        this.showToast('Success', 'Orgs\' statuses were successfully refreshed.', 'success', 'dismissible')
                    }
                }
                catch(error)
                {
                    console.log('Inside catch error='+error.message);
                    this.loaded = true;
                    this.showToast('Error', 'An error occurred while refreshing orgs\' statuses. Error message:'+error.message, 'error', 'dismissible')
                }
                
                debugger;

                // Dynamically populate data table columns based on orgSelected
                this.updateTableColumns();
            }
        }
        ).catch(error => {

        })
    }


    // Getter to return pikclist options for "Select an Org"
    get isOrgOptionsPresent(){
        if( this.orgOptions && this.orgOptions.length > 0)
            return true;
        return false;
    }
        


    // When Re-Authorize is clicked
    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        const sfdcConfigName = row.orgName
        debugger;
        switch (action.name) {
            case 'reauthorize':

                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__webPage',
                    attributes: {
                        url: '/apex/FetchAuthCodeAndAccessTokenVF?sfdcconfigname='+sfdcConfigName
                    }
                }).then(generatedUrl => {
                    window.open(generatedUrl, '_blank');
                });

                break;
        }
    }


    get sObjectRecordsToDisplay(){
        return this.mapOrgNameToDefaultRecords.get(this.orgSelected);
    }

    get isDesktop(){
        return FORM_FACTOR == 'Large';
    }



    // Handler for Picklist change
    handleOrgChange(event){
        console.log("Org Selected=" + event.target.value);
        this.orgSelected = event.target.value;

        this.updateTableColumns();
    }


    // To dynamically update columns in the table according to the org selected
    /*
                            ################################## VIMP Javascript Concepts ###################################################

                            CONCEPT 1:
                            const [label, fieldName] = labelField.split(':');
                            This basically assigns the first part to variable "label" and second part to variable "fieldName"
                            
                            This is equivalent to below:
                            const label = labelField.split(':')[0];
                            const fieldName = labelField.split(':')[1];


                            CONCEPT 2: Shorthand Property Names and SPREAD Operator (...)
                            If the property names are the same as the variable names, you can use shorthand notation to simplify object creation. The following code:

                            This basically returns an object with label and fieldName as properties.
                            This is equivalent to below:
                            return {
                                label: labelField.split(':')[0],
                                fieldName: labelField.split(':')[1],
                            };

                            BASIC EXAMPLE:
                            <script>
                                // Create an Object:
                                name = 'Ankit@Mittal';
                                const [firstName, lastName] = name.split('@'); // defining variable using const/let/var is mandatory otherwise error will come
                                age= 35;
                                eyeColor= "blue";
                                
                                const person = {
                                firstName,lastName,age,eyeColor
                                };

                                const clonedPerson = {
                                                        ...person, // copying all properties from person using SPREAD OPERATOR
                                                        firstName:'Sanchit', // Overriding "firstName" property
                                                        age:'32',
                                                        profession:'Salesforce Architect' // Adding new property
                                                        };

                                // Display Data from the Object:
                                document.getElementById("demo").innerHTML =
                                person.firstName + " is " + person.age + " years old and his younger brother "+clonedPerson.firstName +"("+clonedPerson.profession +")" + " is " + clonedPerson.age + " years old.";
                            </script>

                            Output: Ankit is 35 years old and his younger brother Sanchit(Salesforce Architect) is 32 years old.

                            ################################## VIMP Javascript Concepts ###################################################
                        */
    updateTableColumns()
    {
        console.log('updateTableColumns called');
        console.log('this.orgSelected = '+this.orgSelected);
        console.log('this.mapOrgNameToLabelFieldDetails = '+this.mapOrgNameToLabelFieldDetails);
        console.log('this.mapOrgNameToLabelFieldDetails.get(this.orgSelected) = '+this.mapOrgNameToLabelFieldDetails.get(this.orgSelected));
        debugger;
        const labelFieldDetails = this.mapOrgNameToLabelFieldDetails.get(this.orgSelected);

        console.log('labelFieldDetails = '+labelFieldDetails);

        if(labelFieldDetails)
        {
            this.dynamicColumns = labelFieldDetails.split('@').map( eachLabelField => {
                const [label, fieldName] = eachLabelField.split(':');
                return {label, fieldName};
            })
        }
    }



    // To show toast notifications
    showToast(label, message, variant, mode) {
        
        console.log('showToast is called');

        Toast.show({
            label: label,
            message: message,
            mode: mode,
            variant: variant
        }, this);
    }

    
}