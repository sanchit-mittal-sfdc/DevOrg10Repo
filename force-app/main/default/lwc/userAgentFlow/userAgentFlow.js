import { LightningElement, wire, track } from 'lwc';
import Toast from 'lightning/toast';
import getUserAgentFlowGeneric from '@salesforce/apex/UserAgentFlowController.getUserAgentFlowGeneric';
import fetchSObjectListFromLoggedIndOrg from '@salesforce/apex/UserAgentFlowController.fetchSObjectListFromLoggedIndOrg';
import fetchFieldsOfSelectedObject from '@salesforce/apex/UserAgentFlowController.fetchFieldsOfSelectedObject';
import fetchRecords from '@salesforce/apex/UserAgentFlowController.fetchRecords';


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

export default class UserAgentFlow extends LightningElement {

    isLoaded = true;
    clientId;
    userAgentFlowConfig;
    accessToken;
    instanceUrl;
    selectedObjectApiName;
    selectedObjectLabel;
    @track sObjectOptions = [];
    fieldColumns = FIELD_COLUMNS;
    @track fieldsData = [];
    @track fetchedRecords = [];
    @track dynamicColumnsForFetchedRecords = [];

    connectedCallback() {
        //   this.startOAuthFlow();
        console.log('connectedCallback is called');
        debugger;


        /* ############################################################## NOTES ##########################################################################################
         * SAMPLE URL:-
        
        https://oatmilk-galaxy-7067-dev-ed.scratch.lightning.force.com/lightning/n/oAuth_2_0_User_Agent_Flow#access_token=00D6F000001gFIu%21AQcAQCw4UZr0s3G27u2YGUzeqiE4JxVlJP.Z.JGf7Lj.4Y6Z5rRco2RzNdHqtrmblp3QJFmCQU3.1pRqjxnivG.FXvvVuAaJ
                                                                                    &instance_url=https%3A%2F%2Fsanchitmittal2-dev-ed.my.salesforce.com
                                                                                    &id=https%3A%2F%2Flogin.salesforce.com%2Fid%2F00D6F000001gFIuUAM%2F0056F000006dtLZQAY
                                                                                    &issued_at=1723818507202
                                                                                    &signature=p6Vord8D1AbKYH8XkXU6%2BQC4h%2FMB0vyHA7pFhx4yolE%3D
                                                                                    &scope=api+web+full
                                                                                    &token_type=Bearer
        
        This `handleRedirect` function is designed to handle the redirection after a user has authenticated with Salesforce using the OAuth 2.0 User-Agent flow. Here's a detailed breakdown of what each part of the code does:

            ### 1. **Extract the URL Fragment Containing the Access Token:**
            ```javascript
            const urlFragment = window.location.hash.substring(1);
            ```
            - **Purpose:** After the user successfully authenticates, Salesforce redirects them back to the specified redirect URI. The access token is passed in the URL fragment (also known as the hash). 
            - **`window.location.hash`:** This property contains everything after the `#` in the URL. For example, if the URL is `https://yourapp.com/#access_token=abc123&...`, `window.location.hash` would be `#access_token=abc123&...`.
            - **`.substring(1)`:** This removes the leading `#` from the `window.location.hash`, leaving only the key-value pairs.

            ### 2. **Parse the Fragment to Extract the Access Token:**
            ```javascript
            const params = new URLSearchParams(urlFragment);
            this.accessToken = params.get('access_token');
            alert('this.accessToken = '+this.accessToken);
            ```
            - **`URLSearchParams(urlFragment)`:** This is a convenient way to parse the URL parameters from the fragment string.
            - **`.get('access_token')`:** This retrieves the value associated with the `access_token` key from the parsed parameters.
            - **Purpose:** The access token is required to make authenticated API requests to Salesforce on behalf of the user. The `alert` is used to display the retrieved access token for debugging purposes.

            ### 3. **Check if the Access Token Was Successfully Retrieved:**
            ```javascript
            if (this.accessToken) {
                console.log('Access Token:', this.accessToken);
            ```
            - **Purpose:** This checks whether the access token was successfully extracted. If it was, the code proceeds to the next steps; otherwise, an error is logged.

            ### 4. **Secure the Access Token by Removing It from the URL History:**
            ```javascript
            // window.location.replace(window.location.href.split('#')[0]);
            ```
            - **Purpose:** After the token is extracted, you typically want to remove it from the URL to prevent it from being exposed in the browser history. The commented-out line would replace the current URL with a version that removes everything after the `#`, ensuring the token is not stored in the browser's history.
            - **Why Commented Out?**: It may be commented out for testing purposes, but it should be used in production to enhance security.

            ### 5. **Fetch Salesforce Account Records Using the Access Token:**
            ```javascript
            this.fetchAccounts();
            ```
            - **Purpose:** Once the access token is retrieved, the function `fetchAccounts()` is called to use this token to fetch data from Salesforce, such as account records.

            ### 6. **Error Handling:**
            ```javascript
            } else {
                console.error('Access Token not found.');
            }
            ```
            - **Purpose:** If the access token is not found in the URL fragment, an error is logged to the console. This helps identify issues if the authentication process didn't work as expected.

            ### Summary

            - **Purpose:** The function `handleRedirect()` is responsible for extracting the access token from the URL after a successful OAuth 2.0 User-Agent flow login. It then securely removes the token from the URL and uses it to fetch data from Salesforce.
            - **Key Concepts:**
            - **URL Fragment Handling:** Extracting and parsing the token.
            - **Security:** Ensuring the token isn't left in the URL history.
            - **API Integration:** Using the token to fetch protected resources from Salesforce.

            This function is critical in the OAuth flow for ensuring that your client-side application can make authenticated API calls on behalf of the user after login.
        ############################################################## NOTES ##########################################################################################*/


        const urlFromHash = window.location.hash;

        if( urlFromHash && urlFromHash.length > 0 )
        {
            console.log('Access token is present in url so will now be extracting it from url');

            const urlAfterHashContainingJustParams = urlFromHash.substring(1);

            // Parse the fragment to extract the access token
            const urlParams = new URLSearchParams(urlAfterHashContainingJustParams);

            this.accessToken = urlParams.get('access_token');
            this.instanceUrl = urlParams.get('instance_url');

            if(this.accessToken && this.accessToken.length >0 && this.instanceUrl && this.instanceUrl.length > 0)
            {
                console.log('access token and instance url is successfully extracted from url');

                Toast.show({
                    label:"Success",
                    message:"Salesforce Org(" +this.instanceUrl + ") is successfully logged in",
                    variant:"success",
                    mode:"dismissible"
                }, this);

                this.getSObjectListFromLoggedIndOrg();
            }
            else
            {
                console.log('failed to extract access token from url');
            }
        }
        else
        {
            console.log('Access token is not present in url');
        }

        
    }


    @wire(getUserAgentFlowGeneric, {})
    wiredConfig({error,data}){

        if(data)
        {
            debugger;
            this.userAgentFlowConfig = {
                ...data
            };
            this.error = undefined;
            //alert(this.userAgentFlowConfig.Label);
        } 

        if(error)
        {
            this.userAgentFlowConfig = undefined;
            this.error = error;
        }
    } 



    startUserAgentFlow() {
        debugger;
        const clientId = '3MVG9ZL0ppGP5UrAYqpIcm8xwPWyNABNftpF4fig6Lk0.qquC6eTRl758xRUJyckGgbLgZBnI1rAg0RB2pdku';
        const redirectUri = encodeURIComponent(`${window.location.origin}/lightning/n/oAuth_2_0_User_Agent_Flow`);

        console.log('redirectUri = '+redirectUri);
        //alert(redirectUri);

        const authEndpoint = 'https://login.salesforce.com/services/oauth2/authorize';
        const responseType = 'token'; // ONLY THIS MAKE IT A USER AGENT FLOW...in web server flow response_type=code but here it is directly token.

        // Construct the authorization URL
        const authUrl = `${authEndpoint}?response_type=${responseType}&client_id=${clientId}&redirect_uri=${redirectUri}`;

        // Redirect the user to the Salesforce authorization page
        /**
         * Instead of using NavigationMixin.GenerateUrl, which is intended for Salesforce Lightning components to navigate within 
         * the Salesforce environment, use window.location.href to navigate to the external Salesforce authorization page.
         */
        window.location.href = authUrl;

    }




    getSObjectListFromLoggedIndOrg()
    {
        fetchSObjectListFromLoggedIndOrg({accessToken : this.accessToken, instanceUrl : this.instanceUrl}).then( response => {
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
            

        }).catch(error => {

            console.log('error.body.message='+error.body.message);

            Toast.show({
                label:"Error",
                message: `An error occurred: ${error.body.message}`,
                variant:"error",
                mode:"sticky"
            }, this);
        })
    }


    // this i called when the user selects an option from the dropdown
    optionSelectedHandler(event)
    {
        debugger;
        this.isLoaded = false;
        this.selectedObjectApiName = event.detail.selectedOptionValue;
        this.selectedObjectLabel = event.detail.selectedOptionLabel;
        console.log('In parent comp, optionSelectedHandler: this.selectedObjectApiName='+this.selectedObjectApiName);

        fetchFieldsOfSelectedObject({sObjectApiName:this.selectedObjectApiName, accessToken:this.accessToken, instanceUrl:this.instanceUrl}).then(response =>{
            debugger;
            console.log(JSON.stringify(response));
            
            this.fieldsData = response;
            this.isLoaded = true;
            
        }).catch(error =>{
            Toast.show({
                label:"Error",
                message:`An error occurred while fetching fields of selected object: ${error.body.message}`,
                variant:"error",
                mode:"sticky"
            }, this);
        })
    }
    

    // this is called when a user selects/de-selects a field in the fields data table
    handleFieldsTableRowSelectionUnselection(event){

        debugger;
        const currentRow = event.detail.row;
        debugger;        
    }


    // this is used to fetch records after the user selects fields and want to query the data
    fetchRecordsFromOrg(event){
        debugger;
        this.isLoaded = false;
        const fieldsTable = this.template.querySelector('lightning-datatable');

        if(fieldsTable)
        {
            const selectedRows = fieldsTable.getSelectedRows();

            if(selectedRows && selectedRows.length > 0)
            {
                const selectedFieldsString = Array.from(selectedRows.map(eachRow=> eachRow.fieldApiName)).join(',');
                console.log(` selectedFieldsString = ${selectedFieldsString}`);

                fetchRecords({sObjectApiName:this.selectedObjectApiName, commaSeparatedFieldsList:selectedFieldsString, accessToken:this.accessToken, instanceUrl:this.instanceUrl}).then(response =>{
                    debugger;

                    this.fetchedRecords = response;
                    this.dynamicColumnsForFetchedRecords = selectedRows.map(eachRow => {
                        const label = eachRow.fieldLabel;
                        const fieldName = eachRow.fieldApiName;

                        return {label, fieldName};
                    })
                    this.isLoaded = true;
                }).catch(error =>{

                    Toast.show({
                        label:"Error",
                        message:`An error occurred while fetching records of selected object: ${error.body.message}`,
                        variant:"error",
                        mode:"sticky"
                    }, this);
                    this.isLoaded = true;
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
            }
        }
    }


}
