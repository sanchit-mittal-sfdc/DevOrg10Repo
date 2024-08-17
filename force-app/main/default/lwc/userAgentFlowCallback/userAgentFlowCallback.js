import { LightningElement } from 'lwc';

export default class UserAgentFlowCallback extends LightningElement {
    accessToken = null;
    accounts = [];  // Array to store account records
    randomJoke;

    columns = [
        { label: 'Account Name', fieldName: 'Name' },
        { label: 'Account Type', fieldName: 'Type' },
        { label: 'Industry', fieldName: 'Industry' }
    ];

    connectedCallback() {
        this.fetchRandomJoke();
        this.handleRedirect();
        
    }

    handleRedirect() {
        // Get the URL fragment containing the access token
        const urlFragment = window.location.hash.substring(1);

        // Parse the fragment to extract the access token
        const params = new URLSearchParams(urlFragment);
        this.accessToken = params.get('access_token');
        alert('this.accessToken = '+this.accessToken);

        if (this.accessToken) {
            console.log('Access Token:', this.accessToken);

            // To secure the token, replace the current URL to remove the token from the history
           // window.location.replace(window.location.href.split('#')[0]);

            // Fetch account records after token is retrieved
            this.fetchAccounts();
        } else {
            console.error('Access Token not found.');
        }
    }

    
    fetchRandomJoke(){

        const endpointUrl = 'https://icanhazdadjoke.com';
        
        fetch( endpointUrl, {
            method : "GET",
            headers:{
                Accept:"application/json"
            }
        }).then(response => {
            debugger;
            if(response.ok)
            {
                return response.json();
                
            }
        }).then(responseJson => {
            this.randomJoke = responseJson.joke;
        }).catch(error =>{
            debugger
            console.error('Error in fetching random joke:', error);
            alert('inside catch error occured'+error.getMessage());
        })
    }
        

    fetchAccounts() {
        alert('fetchAcc called');
        console.log('fetchAccounts called');
        const baseUrl = 'https://sanchitmittal-dev-ed.my.salesforce.com/services/data/v57.0/query?q=SELECT+Name,Type,Industry+FROM+Account';
        
        try 
        {
            fetch(baseUrl, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${this.accessToken}`,
                    'Accept': 'application/json',
                    'Content-Type': 'application/json'
                }
            }).then( response => {

                if (response.ok) 
                {
                    console.log('response is ok');
                    return response.json();
                }
                else {
                    console.error('Failed to fetch accounts:', response.status, response.statusText);
                    alert('inside else');
                }
            }).then(responseJson => {

                debugger;
                this.accounts = responseJson.records;
                alert('account='+this.accounts[0]);
            }).catch(error => {
                console.error('Error during fetch:', error);
                alert('inside catch error occured');
            })

        }
        catch(error)
        {
            console.error('Error in fetching accounts:', error);
        }
    }


    get isDataAvailable(){
        return this.accounts && this.accounts.length > 0;
    }
}
