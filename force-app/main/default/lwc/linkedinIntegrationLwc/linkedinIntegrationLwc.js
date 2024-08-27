import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDetailsForAuthCodeFlow from '@salesforce/apex/LinkedinIntegrationLwcController.getDetailsForAuthCodeFlow';
import updateLinkedinUserIdAccessTokenInOAuthFlowDetails from '@salesforce/apex/LinkedinIntegrationLwcController.updateLinkedinUserIdAccessTokenInOAuthFlowDetails';
import sharePostOnLinkedIn from '@salesforce/apex/LinkedinIntegrationLwcController.sharePostOnLinkedIn';
import deleteOuthFlowDetailsRec from '@salesforce/apex/LinkedinIntegrationLwcController.deleteOuthFlowDetailsRec';
import Toast from 'lightning/toast';

export default class LinkedinIntegrationLwc extends LightningElement {

    linkedInConfigRec;
    clientId;
    stateVal;
    scopeVal;
    redirectUri;
    isLoaded = true;
    isUserLoggedIn = false;
    nameOfUser;

    //IMP: Stores the wired result for refreshing using refreshApex(this.wiredAccountsResult);
    wiredDetailsForAuthCodeFlowResult;


    // connectedCallback checks if the page is loaded as a result of redirect. if yes then gets the code and state to fetch the access token
    async connectedCallback(){
        console.log(`connectedCallback called`);
        debugger;

        
        // Adding an eventlistener on page load so as to automatically call the log out button when the user closes the TAB/WINDOW.
        window.addEventListener('beforeunload', (event) => {
            console.log('beforeunload event listener called');
            //alert('beforeunload event listener');
            debugger;

            // Perform your cleanup or state-saving tasks here
            if(this.isUserLoggedIn)
            {
                this.doLogOut('beforeunload event listener');        
            }
        });
        

        // this returns code and state i.e. url params in string like 'c__code=12312&c__state=123456789'
        const urlParamsString = window.location.search; 

        if(urlParamsString)
        {
            // converting the string into object
            const urlParamsObj = new URLSearchParams(urlParamsString);

            const code = urlParamsObj.get('c__code');
            const stateInRedirect = urlParamsObj.get('c__state');            

            // if code and state are having values then call apex method the fetch access token
            if(code && stateInRedirect)
            {
                // After retrieving code and state, remove these parameters from URL for security purpose without even reloading the page
                window.history.replaceState(null, null, window.location.href.split('?')[0]);

                this.isLoaded = false;
                try
                {
                    const response = await updateLinkedinUserIdAccessTokenInOAuthFlowDetails({code, stateInRedirect}); // IMP: Obj Destructuring this is same  as await updateLinkedinUserIdAccessTokenInOAuthFlowDetails({code : code, stateInRedirect : stateInRedirect}); 
                    debugger;
                    if(response && response.isSuccess)
                    {
                        this.isLoaded           = true;
                        this.isUserLoggedIn     = true;
                        this.nameOfUser         = response.userName;

                        Toast.show({
                            label:'Success',
                            message:`Hey ${this.nameOfUser}, you have successfully authorized your LinkedIn account.`,
                            variant: 'success',
                            mode: 'dismissible',
                        }, this);
                    }
                }
                catch(error)
                {
                    this.isLoaded = true;
                    console.log(`Error occurred while calling updateLinkedinUserIdAccessTokenInOAuthFlowDetails: ${error.body.message}`);
                    Toast.show({
                        label:'Error',
                        message:`Error occurred while calling updateLinkedinUserIdAccessTokenInOAuthFlowDetails: ${error.body.message}`,
                        variant: 'error',
                        mode: 'sticky'
                    }, this);
                }
            }
        }
        
        
    }


    // GETTER To dynamcially generate page title
    get pageTopTitle(){

        if(!this.isUserLoggedIn)
        {
            return `Please login to your LinkedIn account to continue.`;
        }
        else 
        {
            if(this.nameOfUser)
            {
                const now = new Date(); // Get the current date and time
                const hour = now.getHours(); // Extract the hour (0-23)

                let greeting;

                if (hour < 12) {
                    greeting = "Good Morning";
                } else if (hour < 18) {
                    greeting = "Good Afternoon";
                } else {
                    greeting = "Good Evening";
                }
                return `${greeting}, ${this.nameOfUser}!`;
            }
            else
            {
                return `Hi there!`;
            }
            
        }
    }



    // GETTER To dynamcially generate page title class for differenct CSS
    get titleClass(){

        if(this.isUserLoggedIn)
            return 'page-title-loggedin';
        return 'page-title-not-loggedin slds-align_absolute-center';
    }



    @wire(getDetailsForAuthCodeFlow, {})
    wiredDetailsForAuthCodeFlow(result){
        this.wiredDetailsForAuthCodeFlowResult = result;
        if(result.data)
        {
            this.clientId    = result.data.ClientID__c;
            this.stateVal    = result.data.State__c;
            this.redirectUri = result.data.Redirect_URL__c; 
            this.scopeVal    = result.data.Scope__c;
        }
        else if(result.error)
        {
            this.linkedInConfigRec = undefined;
        }
    }    


    // called on clicking the "log in to LinkedIn" button
    initiateLinkedInAuthCodeFlow(event){

        /* 
        
        - This will also work but its actually replacinf spaces with + and not %20 as mentioned in the linkedin doc.
        - new URLSearchParams() automatically encodes the value.
        - but since we dont need + sign for space , so using encodeURIComponent function to explicity encode


        console.log(`initiateLinkedInAuthCodeFlow is called`);
        debugger;
        const redirect_uri    = `https://wonton-deploy-6437-dev-ed.scratch.my.salesforce.com/apex/LinkedinIntegrationRedirectHelperVF`;
        const client_id       = '86deog7dopsds9';
        const response_type   = 'code';
        const state           = '123456789';
        const scope           = 'openid profile email w_member_social';

        const urlParams       = new URLSearchParams({redirect_uri, client_id, response_type, state, scope});
        const urlParamsString = urlParams.toString();
        
        console.log(`urlParamsString: ${urlParamsString}`);

        window.location.href = `https://www.linkedin.com/oauth/v2/authorization?${urlParamsString}`;
        */

        
        console.log(`initiateLinkedInAuthCodeFlow is called`);
        debugger;

        if(this.clientId && this.stateVal && this.scopeVal && this.redirectUri)
        {
            /**
             * Imp: the redirect_uri has to be exactly the same for both access token request and the audt code request.
             * Earlier I was using  encodeURIComponent(`${window.location.origin}/apex/LinkedinIntegrationRedirectHelperVF`); in JS
             * and EncodingUtil.urlEncode() in apex to get the access token. And this was throwing error due to mismatch.
             */
            
            const redirect_uri      = this.redirectUri;
            const client_id         = this.clientId;
            const response_type     = 'code';
            const state             = this.stateVal;
            const scope             = this.scopeVal;

            const urlParamsString = `redirect_uri=${redirect_uri}&client_id=${client_id}&response_type=${response_type}&state=${state}&scope=${scope}`;
            
            // Dont use the below approach otherwise it will again url encode the already encode params
            //const urlParams         = new URLSearchParams({redirect_uri, client_id, response_type, state, scope});
            //const urlParamsString   = urlParams.toString();
            const finalAuthCodeUrl  = `https://www.linkedin.com/oauth/v2/authorization?${urlParamsString}`;

            console.log(`urlParamsString: ${urlParamsString}`);
            console.log(`finalAuthCodeUrl: ${finalAuthCodeUrl}`);

            window.location.href = finalAuthCodeUrl;
        }
        else
        {
            Toast.show({
                label: 'Error',
                message:'LinkedIn config is missing or donot have all required fields populated in custom metadata.',
                variant: 'error',
                mode: 'sticky',
            }, this);
        }
    }


    // to be called when user clicks the Post on linkedIn button
    async doPostOnLinkedIn(event){

        console.log(`doPostOnLinkedIn is called`);
        debugger;
        
        const textAreaComp = this.template.querySelector('lightning-textarea[data-name = "postContent"]');
        let postContent = '';


        if(textAreaComp)
        {
            if(textAreaComp.value && textAreaComp.value.trim() != '')
            {
                postContent = textAreaComp.value?.trim();
                
                console.log(`postContent: `);
                debugger;
                try
                {
                    this.isLoaded = false;
                    const response = await sharePostOnLinkedIn({body:postContent});
                    this.isLoaded = true;
                    if(response)
                    {
                        if(response.isSuccess)
                        {  
                            Toast.show({
                                label: 'Success',
                                message: 'Post has been shared on LinkedIn.',
                                variant: 'success',
                                mode: 'dismissible',
                            }, this);
                        }
                        else
                        {
                            Toast.show({
                                label: 'Error',
                                message: response.errorMessage,
                                variant: 'error',
                                mode: 'sticky',
                            }, this);
                        }
                        
                    }
                    
                }
                catch(error)
                {
                    console.log(`Error while posting on LinkedIn. Details: ${error.body.message}`);
                    this.isLoaded = true;
                    Toast.show({
                        label: 'Error',
                        message:`Error while posting on LinkedIn. Details: ${error.body.message}`,
                        variant: 'error',
                        mode: 'sticky',
                    }, this);
                }
            }
            else
            {
                Toast.show({
                    label: 'Error',
                    message: 'Please enter something to share on LinkedIn.',
                    variant: 'error',
                }, this);
            }
        }
    }


    // automtically delete all OAuthflowDetails custom object records of the current user if he closes the tab i.e same as when user explicitly clicks the Log out button
    doLogOut(event){

        console.log(`doLogOut is called from ${event}`);
        debugger;
        this.deleteAccessTokenRecordOfCurrentUser('disconnectedCallback');
    }


    // calls apex method to delete current user records responsible for holding sensitive information
    async deleteAccessTokenRecordOfCurrentUser(calledFrom){
        console.log(`deleteAccessTokenRecordOfCurrentUser called from ${calledFrom}`);
        this.isLoaded = false;
        try
        {
            const response = await deleteOuthFlowDetailsRec();
            debugger;
            this.isLoaded = true;
            if(response && response.isSuccess)
            {
                console.log(`deleteAccessTokenRecordOfCurrentUser is successful`);
                this.isUserLoggedIn = false;

                Toast.show({
                    label:'Success',
                    message:'You have successfully logged out.',
                    variant: 'success',
                    mode: 'dismissible'
                }, this);
            }
            else
            {

                console.log(`deleteAccessTokenRecordOfCurrentUser is unsuccessful`);
                this.isUserLoggedIn = true;
                Toast.show({
                    label:'Error',
                    message:'Error occurred while logging out.',
                    variant: 'error',
                    mode: 'sticky'
                }, this);
            }
        }
        catch(error)
        {
            console.log(`deleteAccessTokenRecordOfCurrentUser is unsuccessful`);
            this.isLoaded = true;
        }
        
    }


}