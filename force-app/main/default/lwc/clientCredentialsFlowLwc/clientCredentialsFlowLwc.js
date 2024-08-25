import { LightningElement, wire, track, api } from 'lwc';
import Toast from 'lightning/toast';
import fetchSObjectListFromLoggedIndOrg from '@salesforce/apex/ClientCredentialsFlowLwcController.fetchSObjectListFromLoggedIndOrg';
import fetchFieldsOfSelectedObject from '@salesforce/apex/ClientCredentialsFlowLwcController.fetchFieldsOfSelectedObject';
import fetchRecords from '@salesforce/apex/ClientCredentialsFlowLwcController.fetchRecords';
import {toUpper, showToastMessage} from 'c/lwcUtils';

const FIELD_COLUMNS = [

    {
        label:'Field Label',
        fieldName: 'fieldLabel',
        type:'text'
    },
    {
        label:'Field API Name',
        fieldName:'fieldApiName',
        type:'text'
    }
];

export default class ClientCredentialsFlowLwc extends LightningElement {

    @api SFDCConfigRecordName;
    isLoaded = true;
    pageTopTitle;
    isUserLoggedIn = false;
    areFieldsPopulated = false;
    areRecordsFetched = false;
    showFieldsTable = true;
    selectedObjectApiName;
    selectedObjectLabel;
    @track sObjectOptions = [];
    fieldColumns = FIELD_COLUMNS;
    @track fieldsData = [];
    @track fetchedRecords = [];
    @track dynamicColumnsForFetchedRecords = [];
    @track selectedRowsInFieldsTable = [];
    soqlQueryClause = '';
    


    async connectedCallback() {
        //   this.startOAuthFlow();
        console.log('connectedCallback is called');
        this.isLoaded = false;

        try
        {
            // to fetch the list of sObjects from logged in org
            const response = await fetchSObjectListFromLoggedIndOrg({SFDCConfigRecName : this.SFDCConfigRecordName, isFetchNewAccessToken: false})
            
            debugger;
            console.log('response='+response);
            if(response && response.length > 0)
            {
                this.sObjectOptions = response.map( eachVal => {
                    const label = eachVal.sObjectLabel;
                    const value = eachVal.sObjectApiName;

                    return {label, value};
                });
            }
            this.pageTopTitle = `You are connected using SFDC Config custom metadata record: ${this.SFDCConfigRecordName}`;
            this.isLoaded = true;
            this.isUserLoggedIn = true;
        }
        catch(error)
        {
            debugger;
            console.log('error.body.message='+error.body.message);

            Toast.show({
                label:"Error",
                message: `An error occurred: ${error.body.message}`,
                variant:"error",
                mode:"sticky"
            }, this);
            this.isLoaded = true;
        }
    }
        
    


    // this is called when the user selects an option from the SOBJECTS dropdown child comp...i.e a event gets fired from child which is handled here in parent component
    optionSelectedHandler(event)
    {
        debugger;
        this.isLoaded = false;
        this.areRecordsFetched = false;
        this.selectedObjectApiName = event.detail.selectedOptionValue;
        this.selectedObjectLabel = event.detail.selectedOptionLabel;
        console.log('In parent comp, optionSelectedHandler: this.selectedObjectApiName='+this.selectedObjectApiName);

        fetchFieldsOfSelectedObject({sObjectApiName:this.selectedObjectApiName, SFDCConfigRecName:this.SFDCConfigRecordName}).then(response =>{
            debugger;
            console.log(JSON.stringify(response));
            
            this.fieldsData = response;
            this.isLoaded = true;
            this.areFieldsPopulated = true;
            this.showFieldsTable = true;
            this.selectedRowsInFieldsTable = [];
            this.soqlQueryClause = '';
        }).catch(error =>{
            Toast.show({
                label:"Error",
                message:`An error occurred while fetching fields of selected object: ${error.body.message}`,
                variant:"error",
                mode:"sticky"
            }, this);
            this.areFieldsPopulated = false;
            this.isLoaded = true;
        })
    }



    // this will returm the value selected from the SOBJECTS dropdown
    get objectSelectedVal(){
        if( this.selectedObjectLabel && this.selectedObjectApiName )
            return `${this.selectedObjectLabel} (${this.selectedObjectApiName})`;
        else
            return '';
    }


    // this is used to fetch records after the user selects fields and want to query the data
    fetchRecordsFromOrg(event){
        debugger;
        this.isLoaded = false;
        this.areRecordsFetched = false;
        //const fieldsTable = this.template.querySelector('lightning-datatable');
        const fieldsTable = this.template.querySelector('[data-tablename="FieldsTable"]');

        if(fieldsTable)
        {
            const selectedRows = fieldsTable.getSelectedRows();

            if(selectedRows && selectedRows.length > 0)
            {
                //const selectedFieldsString = Array.from(selectedRows.map(eachRow=> eachRow.fieldApiName)).join(',');
                this.selectedRowsInFieldsTable = selectedRows.map(eachRow=> eachRow.fieldApiName);
                const selectedFieldsString = Array.from(this.selectedRowsInFieldsTable).join(',');
                console.log(` selectedFieldsString = ${selectedFieldsString}`);

                const soqlQueryComp = this.template.querySelector('[data-name="soqlAdditionalClauses"]');
                if(soqlQueryComp)
                {
                    this.soqlQueryClause = soqlQueryComp.value;
                }

                console.log('Passing soqlQueryClause = '+this.soqlQueryClause);
                fetchRecords({sObjectApiName:this.selectedObjectApiName, commaSeparatedFieldsList:selectedFieldsString, soqlQueryClauseVal:this.soqlQueryClause, SFDCConfigRecName:this.SFDCConfigRecordName}).then(response =>{
                    debugger;

                    this.fetchedRecords = response;
                    this.dynamicColumnsForFetchedRecords = selectedRows.map(eachRow => {
                        const label = eachRow.fieldLabel;
                        const fieldName = eachRow.fieldApiName;

                        return {label, fieldName};
                    })
                    this.isLoaded = true;
                    this.areRecordsFetched = true;
                    this.showFieldsTable = false;
                }).catch(error =>{

                    Toast.show({
                        label:"Error",
                        message:`An error occurred while fetching records of selected object: ${error.body.message}`,
                        variant:"error",
                        mode:"sticky"
                    }, this);
                    this.isLoaded = true;
                    this.areRecordsFetched = false;
                })

            }
            else
            {
                Toast.show({
                    label:"Error",
                    message:"Please select at least 1 field to fetch record(s).",
                    variant:"error",
                    mode:"dismissible"
                },this);
                this.isLoaded = true;
                this.areRecordsFetched = false;
            }
        }
    }

    // togglle the visibility of fields table
    doHideOrShowFieldsTable(event){
        this.showFieldsTable = !this.showFieldsTable;
    }


    // dynamic label of hide/show fields button based on whether the fields table is visible or not
    get hideShowFieldsTableButtonLabel(){
        return this.showFieldsTable? 'Hide Fields':'Show Fields';
    }


    // dynamic icon of hide/show fields button based on whether the fields table is visible or not
    get hideShowFieldsTableButtonIcon(){
        return this.showFieldsTable? 'utility:hide':'utility:preview';
    }

    // dynamically generate fields table title using the selected object value
    get fieldsTableTitle(){
        return `Please select at least 1 field of sObject: ${this.selectedObjectLabel} (${this.selectedObjectApiName}) to query records`;
    }

    // dynamically generate fetched records table title using the selected object value
    get fetchedRecordsTableTitle(){
        const fetchedRecordsCount = this.fetchedRecords? this.fetchedRecords.length : 0;
        return `${fetchedRecordsCount} record(s) fetched from ${this.selectedObjectLabel} (${this.selectedObjectApiName})`;
            
    }

}