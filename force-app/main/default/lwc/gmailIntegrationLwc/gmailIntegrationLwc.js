import { LightningElement, wire } from 'lwc';
import getAuthUrl from '@salesforce/apex/GoogleIntegrationController.getAuthUrl';
import exchangeTokenForAccessToken from '@salesforce/apex/GoogleIntegrationController.exchangeTokenForAccessToken';
import sendEmailViaGmail from '@salesforce/apex/GoogleIntegrationController.sendEmailViaGmail';
import { showToastMessage } from 'c/lwcUtils';

export default class GmailIntegrationLwc extends LightningElement {

    // Variables to track the loading state and user login status
    isLoaded = true;
    isUserLoggedIn = false;
    wiredAuthUrlResult;
    authUrl;
    namedCredentialsToggleVal = false;

    // Lifecycle hook that runs when the component is inserted into the DOM
    async connectedCallback() {
        debugger; // Debugger statement to help in inspecting during debugging
        const urlparams = window.location.search; // Get query parameters from the URL

        // Check if the URL contains the authentication code (c__code)
        if (urlparams && urlparams.includes('c__code')) {
            const urlParamsMap = new URLSearchParams(urlparams); // Parse the URL parameters
            const authCode = urlParamsMap.get('c__code'); // Get the authorization code from the URL
            const stateReceived = urlParamsMap.get('c__state'); // Get the state parameter from the URL

            try {
                this.isLoaded = false; // Show loading spinner while processing the token exchange

                // Exchange the authorization code for an access token by calling Apex method
                const accessTokenResponse = await exchangeTokenForAccessToken({ authCode, stateReceived });
                debugger; // Debugger statement to inspect the accessTokenResponse during debugging

                // Once the token is received, set the component state to reflect the logged-in user
                this.isLoaded = true;
                this.isUserLoggedIn = true;

                // Clean up the URL by removing the query parameters after successful login
                window.history.replaceState(null, null, window.location.href.split('?')[0]);

                // Show a success toast message to the user
                showToastMessage(this, 'Success', 'User logged in successfully', 'success', 'dismissible');
            } catch (error) {
                // Show an error toast message if something goes wrong during the token exchange
                showToastMessage(this, 'Error', `Error occurred: ${error.body.message}`, 'error', 'sticky');
            }
        }
    }

    // Wire service to get the Google Authentication URL from Apex
    @wire(getAuthUrl, {})
    wiredAuthUrl(result) {
        this.wiredAuthUrlResult = result; // Store the result of the wire call

        // If the auth URL is successfully retrieved
        if (result.data && result.data.isSuccess) {
            this.authUrl = result.data.authUrl; // Set the authUrl variable to the retrieved URL
            console.log(this.authUrl); // Log the URL for debugging purposes
        }

        // If an error occurred while retrieving the auth URL
        if (result.error) {
            this.isLoaded = false; // Disable the login button if an error occurs
            console.error('Some error occurred while fetching auth URL: ', result.error); // Log the error
        }
    }

    // Method to initiate the Google authentication flow
    initiateAuthCodeFlow(event) {
        // If the auth URL is available, redirect the user to start the Google authentication process
        if (this.authUrl) {
            window.location.href = this.authUrl; // Navigate the user to the auth URL
        }
    }


    handleToggle(event){
        //alert(`this.namedCredentialsToggleVal is ${this.namedCredentialsToggleVal}  and event.target.checked is ${event.target.checked}`);
        
        this.namedCredentialsToggleVal = event.target.checked;

        if(this.namedCredentialsToggleVal === true)
        {
            this.isUserLoggedIn = true;
        }
        else
        {
            this.isUserLoggedIn = false;
        }
        
    }


    async handleSendEmail(event){

        debugger;
        let isAllInputValid = true;

        // We cannot have this method reportValidity() on rich txt 
        //isAllInputValid = this.template.querySelector('lightning-input-rich-text').reportValidity();
       
        this.template.querySelectorAll('lightning-input').forEach( inputElem => {
            if(!inputElem.reportValidity())
            {
                isAllInputValid = false;
            }
        });

        if(!isAllInputValid)
        {
            return;
        }

        const shouldUseNamedCredentials = this.namedCredentialsToggleVal;
        const toVal         = this.template.querySelector('lightning-input[data-id="to"]').value;
        const ccVal         = this.template.querySelector('lightning-input[data-id="cc"]').value;
        const bccVal        = this.template.querySelector('lightning-input[data-id="bcc"]').value;
        const subjectVal    = this.template.querySelector('lightning-input[data-id="subject"]').value;
        const bodyVal       = this.template.querySelector('lightning-input-rich-text').value;

        if(toVal?.trim()?.length > 0 && subjectVal?.trim()?.length > 0 && bodyVal?.trim()?.length > 0)
        {
            try
            {
                const response = await sendEmailViaGmail({shouldUseNamedCredentials, toVal, ccVal, bccVal, subjectVal, bodyVal});
                debugger;
                if(response.isSuccess)
                {
                    showToastMessage(this, 'Success', 'Email sent successfully', 'success', 'dismissible');
                }
                else
                {
                    showToastMessage(this, 'Error', response.errorMessage, 'error', 'sticky');
                }
            }
            catch(error)
            {
                showToastMessage(this, 'Error', error.body.message, 'error', 'sticky');
            }
        }
        else
        {
            showToastMessage(this, 'Error', 'Please fill all the required fields', 'error', 'sticky');
        }
    }
}
