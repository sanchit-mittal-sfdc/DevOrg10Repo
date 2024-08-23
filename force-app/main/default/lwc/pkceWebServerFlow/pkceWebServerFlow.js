import { LightningElement, wire, track } from 'lwc';
import Toast from 'lightning/toast';
import getPKCEFlowGeneric from '@salesforce/apex/WebServerFlowWithPKCEController.getPKCEFlowGeneric';
import fetchSObjectListFromLoggedIndOrg from '@salesforce/apex/WebServerFlowWithPKCEController.fetchSObjectListFromLoggedIndOrg';
import fetchFieldsOfSelectedObject from '@salesforce/apex/WebServerFlowWithPKCEController.fetchFieldsOfSelectedObject';
import fetchOrgDomainUrl from '@salesforce/apex/WebServerFlowWithPKCEController.fetchOrgDomainUrl';
import fetchRecords from '@salesforce/apex/WebServerFlowWithPKCEController.fetchRecords';
import checkAndReturnCurrentUserOauthRec from '@salesforce/apex/WebServerFlowWithPKCEController.checkAndReturnCurrentUserOauthRec';
import setAccessTokenInOauthDetailRec from '@salesforce/apex/WebServerFlowWithPKCEController.setAccessTokenInOauthDetailRec';
import createOauthFlowDetailRec from '@salesforce/apex/WebServerFlowWithPKCEController.createOauthFlowDetailRec';
import {toUpper, showToastMessage} from 'c/lwcUtils';
import { getRecord, getFieldValue, deleteRecord } from 'lightning/uiRecordApi';
import OAUTHFLOWDETAILS_OBJECT from '@salesforce/schema/OAuthFlowDetails__c';
import CODE_CHALLENGE_FIELD from '@salesforce/schema/OAuthFlowDetails__c.Code_Challenge__c';
import STATE_FIELD from '@salesforce/schema/OAuthFlowDetails__c.State__c';


const APPLICATION_NAME = 'WebServerFlowWithPKCE';
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

export default class PkceWebServerFlow extends LightningElement {

    isLoaded = true;
    pageTopTitle = 'Please log in to your Salesforce org to query records.';
    isUserLoggedIn = false;
    areFieldsPopulated = false;
    areRecordsFetched = false;
    showFieldsTable = true;
    clientId;
    pkceFlowConfig;
    instanceUrl;
    selectedObjectApiName;
    selectedObjectLabel;
    @track sObjectOptions = [];
    fieldColumns = FIELD_COLUMNS;
    @track fieldsData = [];
    @track fetchedRecords = [];
    @track dynamicColumnsForFetchedRecords = [];
    @track selectedRowsInFieldsTable = [];
    soqlQueryClause = '';
    orgDomainUrl;
    applicationNameVal = APPLICATION_NAME;
    oauthFlowDetailRecId;
    oauthFlowFields = [CODE_CHALLENGE_FIELD, STATE_FIELD];
    code_challenge;
    state;


    connectedCallback() {
        //   this.startOAuthFlow();
        console.log('connectedCallback is called');
        debugger;

        console.log('window.location.href='+window.location.href); 

        const queryString = window.location.search;// window.location.search is a JavaScript property that returns the query string part of the URL, including the ? at the beginning
        const urlParams = new URLSearchParams(queryString);

        const code = urlParams.get('c__code');
        console.log(`c__code is ${code}`);

        const stateVal = urlParams.get('c__state');
        console.log(`code is ${stateVal}`);

        
        
        if(code)
        {
            console.log('window.location.href contains code=');
            window.history.replaceState(null, null, window.location.href.split('?')[0]);
            this.isLoaded = false;

            setAccessTokenInOauthDetailRec({code:code, stateFromAuthServer:stateVal}).then(response => {
                debugger;
                if(response.isSuccess === true)
                {

                    this.instanceUrl = response.instanceUrl; 
                    this.oauthFlowDetailRecId =  response.oauthFlowDetailRecId;                  
                    this.isUserLoggedIn = true;
                    this.isLoaded = true;
                    this.getSObjectListFromLoggedIndOrg();
                    showToastMessage(this, 'Success', 'Successfully authorized', 'success', 'dismissible');
                    
                }
            }).catch(error => {
                this.isLoaded = true;
                console.log(`Error occurred while setting access token in oauth flow detail record: ${error.body.message}`);
                showToastMessage(this, 'Error', error.body.message, 'error', 'sticky');
            })

            
        }
        else
        {
            this.isLoaded = false;
            checkAndReturnCurrentUserOauthRec({applicationName: this.applicationNameVal}).then(response => {

                debugger;
                if(response && response.recId)
                {
                    this.isLoaded = true;
                    this.oauthFlowDetailRecId = response.recId;

                    if(response.isAccessTokenPresent && response.instanceUrl)
                    {

                        this.isUserLoggedIn = true;
                        this.instanceUrl = response.instanceUrl;
                        this.getSObjectListFromLoggedIndOrg();
                        //showToastMessage(this, 'Success', 'Successfully authorized', 'success', 'dismissible');
                    }
                }
                else
                {
                    createOauthFlowDetailRec({applicationName:this.applicationNameVal}).then(response => {
                        debugger;
                        this.isLoaded = true;
                        if(response)
                        {
                            this.oauthFlowDetailRecId = response;
                        }
                    }).catch(error => {
                        console.log(`Error occurred: ${error.body.message}`);
                        showToastMessage(this, 'Error', error.body.message, 'error', 'sticky');
                        this.isLoaded = true;
                    })
                }
                
            }).catch(error => {
                console.log(`Error occurred: ${error.body.message}`);
                this.isLoaded = true;
                showToastMessage(this, 'Error', error.body.message, 'error', 'sticky');
            })
            //##############################################
        }
    }


    @wire(getRecord, {recordId : '$oauthFlowDetailRecId', fields : '$oauthFlowFields'})
    wiredOauthFlowRec({error, data}){
        if(data)
        {
            this.code_challenge = getFieldValue(data, CODE_CHALLENGE_FIELD);
            this.state = getFieldValue(data, STATE_FIELD);
            console.log(`code_challenge in wire: ${this.code_challenge}`);
            console.log(`state in wire: ${this.state}`);
        }
        else if (error) {
            console.error('Error in wiredOauthFlowRec:', error);
        }
    }



    // to fetch the current my domain url
    @wire(fetchOrgDomainUrl, {})
    wiredOrgDomainUrl({error, data}){
        if(data)
        {
            this.orgDomainUrl = data;
        }
    }

    // to fetch the custom metadata SFDCConfig
    @wire(getPKCEFlowGeneric, {})
    wiredConfig({error,data}){

        if(data)
        {
            debugger;
            this.pkceFlowConfig = {
                ...data
            };
            this.error = undefined;
            //alert(this.pkceFlowConfig.Label);
        } 

        if(error)
        {
            this.pkceFlowConfig = undefined;
            this.error = error;
        }
    } 




    // This is called when user clicks "login using salesforce"
    startWebServerFlowWithPKCE() {

        // Ensure code_challenge and state have been populated
        if (this.code_challenge && this.state) 
        {
            debugger;
            const client_id = this.pkceFlowConfig.ClientID__c;
            const redirect_uri = `${this.orgDomainUrl}/apex/PkceWebServerFlowRedirectVF`; // No need to use encodeUriCOmponent() here because new URLSearchParams will automatically encode it
            console.log('redirect_uri = '+redirect_uri);
            const authEndpoint = 'https://login.salesforce.com/services/oauth2/authorize';
            const response_type = 'code'; 
            let code_challenge = this.code_challenge;
            const prompt = 'login';
            const code_challenge_method = 'S256';
            const state = this.state;

            const urlParams = new URLSearchParams({response_type,redirect_uri,client_id,code_challenge,code_challenge_method,prompt,state});
            // WITHOUT PKCE : const urlParams = new URLSearchParams({response_type,redirect_uri,client_id,prompt,state});
            const urlParamsString = urlParams.toString();
            console.log(`urlParamsString = ${urlParamsString}`);

            //const authUrl = `${authEndpoint}?response_type=${responseType}&client_id=${clientId}&redirect_uri=${redirectUri}&prompt=login&code_challenge_method=S256&code_challenge=${codeChallenge}&state=ankit`;
            const authUrl = `${authEndpoint}?${urlParamsString}`;
            console.log(`authUrl = ${authUrl}`);
            //alert(`authUrl = ${authUrl}`);
            window.location.href = authUrl;
        }
        else
        {
            console.error('code_challenge or state not set yet.');
        }


    }



    // to fetch the list of sObjects from logged in org
    getSObjectListFromLoggedIndOrg()
    {
        debugger;
        this.isLoaded = false;
        fetchSObjectListFromLoggedIndOrg({instanceUrl : this.instanceUrl}).then( response => {
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
            this.pageTopTitle = `You are successfully connected to: ${this.instanceUrl}`;
            this.isLoaded = true;

        }).catch(error => {
            debugger;
            console.log('error.body.message='+error.body.message);

            Toast.show({
                label:"Error",
                message: `An error occurred: ${error.body.message}`,
                variant:"error",
                mode:"sticky"
            }, this);
            this.isLoaded = true;
        })
    }


    // this i called when the user selects an option from the SOBJECTS dropdown child comp...i.e a event gets fired from child which is handled here in parent component
    optionSelectedHandler(event)
    {
        debugger;
        this.isLoaded = false;
        this.areRecordsFetched = false;
        this.selectedObjectApiName = event.detail.selectedOptionValue;
        this.selectedObjectLabel = event.detail.selectedOptionLabel;
        console.log('In parent comp, optionSelectedHandler: this.selectedObjectApiName='+this.selectedObjectApiName);

        fetchFieldsOfSelectedObject({sObjectApiName:this.selectedObjectApiName, instanceUrl:this.instanceUrl}).then(response =>{
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
        })
    }


    // handleFieldsTableRowSelection
    handleFieldsTableRowSelection(event){

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
                fetchRecords({sObjectApiName:this.selectedObjectApiName, commaSeparatedFieldsList:selectedFieldsString, instanceUrl:this.instanceUrl, soqlQueryClauseVal:this.soqlQueryClause}).then(response =>{
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


    // to logout
    async doLogOutOrReauthorize(event){
        debugger;
        try
        {
            await deleteRecord(this.oauthFlowDetailRecId);
            showToastMessage(this, 'Success', 'You have been successfully logged out. The page will now refresh automatically after 5 seconds. Please log in again to proceed.', 'success', 'sticky');
            debugger;
            setTimeout(()=>{
                window.location.href = window.location.origin + '/lightning/n/OAuth_2_0_Web_Server_Flow_WITH_PKCE';
            }, 5000);
            
        }
        catch(error)
        {
            console.log('Error occurred while deleting oauth flow detail record: ');
            showToastMessage(this, 'Error','Error occurred while deleting oauth flow detail record', 'error', 'sticky');
        }
    }

}